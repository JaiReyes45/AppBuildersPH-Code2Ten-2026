import 'semantic_store.dart';
import 'scan_timings.dart';
import 'ocr_input.dart';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_storage.dart';
import 'gallery_asset_source.dart';

const _pageSize = 24;

bool get isGalleryScanningSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class GalleryScanBlock {
  const GalleryScanBlock({
    required this.id,
    required this.text,
    this.left,
    this.top,
    this.width,
    this.height,
  });

  final String id;
  final String text;
  final double? left;
  final double? top;
  final double? width;
  final double? height;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory GalleryScanBlock.fromJson(Map<String, dynamic> json) =>
      GalleryScanBlock(
        id: json['id'] as String,
        text: json['text'] as String,
        left: (json['left'] as num?)?.toDouble(),
        top: (json['top'] as num?)?.toDouble(),
        width: (json['width'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
      );
}

class GalleryScanRecord {
  const GalleryScanRecord({
    required this.assetId,
    required this.displayName,
    required this.status,
    required this.scannedAt,
    required this.blocks,
    this.imagePath,
    this.error,
    this.assetCreatedAt,
  });

  final String assetId;
  final String displayName;
  final String status;
  final DateTime scannedAt;
  final List<GalleryScanBlock> blocks;
  final String? imagePath;
  final String? error;
  final DateTime? assetCreatedAt;

  bool get isFailed => status == 'failed';

  String get recognizedText => blocks.map((block) => block.text).join('\n');

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'displayName': displayName,
    'status': status,
    'scannedAt': scannedAt.toIso8601String(),
    'imagePath': imagePath,
    'error': error,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    if (assetCreatedAt != null)
      'assetCreatedAt': assetCreatedAt!.toIso8601String(),
  };

  factory GalleryScanRecord.fromJson(Map<String, dynamic> json) =>
      GalleryScanRecord(
        assetId: json['assetId'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        imagePath: json['imagePath'] as String?,
        error: json['error'] as String?,
        assetCreatedAt: json['assetCreatedAt'] == null
            ? null
            : DateTime.parse(json['assetCreatedAt'] as String),
        blocks: (json['blocks'] as List<dynamic>)
            .map(
              (block) => GalleryScanBlock.fromJson(
                Map<String, dynamic>.from(block as Map),
              ),
            )
            .toList(growable: false),
      );
}

class GalleryScanProgress {
  const GalleryScanProgress({
    this.status = 'idle',
    this.message = 'No gallery photos scanned yet.',
    this.total = 0,
    this.processed = 0,
    this.failed = 0,
    this.pendingPickedPhotos = const [],
    this.hasMore = false,
  });

  final String status;
  final String message;
  final int total;
  final int processed;
  final int failed;
  final List<PendingPickedPhoto> pendingPickedPhotos;

  /// Whether this bounded pass observed another eligible asset.
  final bool hasMore;

  bool get isScanning => status == 'scanning';
  double? get fraction => total == 0 ? null : (processed / total).clamp(0, 1);

  Map<String, Object?> toJson() => {
    'status': status,
    'message': message,
    'total': total,
    'processed': processed,
    'failed': failed,
    'pendingPickedPhotos': pendingPickedPhotos
        .map((photo) => photo.toJson())
        .toList(),
  };

  factory GalleryScanProgress.fromJson(
    Map<String, dynamic> json, {
    required int failed,
  }) {
    final pending = (json['pendingPickedPhotos'] as List<dynamic>? ?? [])
        .map(
          (photo) => PendingPickedPhoto.fromJson(
            Map<String, dynamic>.from(photo as Map),
          ),
        )
        .toList(growable: false);
    return GalleryScanProgress(
      status: json['status'] as String? ?? 'idle',
      message: json['message'] as String? ?? 'No gallery photos scanned yet.',
      total: (json['total'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      failed: failed,
      pendingPickedPhotos: pending,
    );
  }
}

class PendingPickedPhoto {
  const PendingPickedPhoto({
    required this.assetId,
    required this.displayName,
    required this.sourcePath,
  });

  final String assetId;
  final String displayName;
  final String sourcePath;

  Map<String, String> toJson() => {
    'assetId': assetId,
    'displayName': displayName,
    'sourcePath': sourcePath,
  };

  factory PendingPickedPhoto.fromJson(Map<String, dynamic> json) =>
      PendingPickedPhoto(
        assetId: json['assetId'] as String,
        displayName: json['displayName'] as String,
        sourcePath: json['sourcePath'] as String,
      );

  PendingPickedPhoto copyWith({String? sourcePath}) => PendingPickedPhoto(
    assetId: assetId,
    displayName: displayName,
    sourcePath: sourcePath ?? this.sourcePath,
  );
}

class GalleryScanner {
  GalleryScanner({
    GalleryStorage? initialStorage,
    GalleryAssetSource? assetSource,
  }) : _storage = initialStorage,
       _assetSource = assetSource ?? GalleryAssetSource();

  final GalleryAssetSource _assetSource;
  Future<void>? _initialization;
  bool _cancelRequested = false;
  bool get isSupported => isGalleryScanningSupported;
  bool get isRunning => _running;

  void cancelScan() => _cancelRequested = true;

  Future<SemanticStore?> semanticStore() async {
    await initialize();
    return _storage is SemanticStore ? _storage as SemanticStore : null;
  }

  Future<SearchHistoryStorage?> searchHistoryStorage() async {
    await initialize();
    return _storage is SearchHistoryStorage
        ? _storage as SearchHistoryStorage
        : null;
  }

  Future<int> countIndexed() async {
    await initialize();
    return _storage!.count();
  }

  Future<Set<String>> indexedAssetIds() async {
    await initialize();
    return _storage!.allAssetIds();
  }

  Future<int> coverageForRange(DateTimeRange? range) async {
    await initialize();
    return _storage!.coverageCount(range);
  }

  final Map<String, AssetEntity> _catalog = {};
  final Map<String, String> _versions = {};
  bool _catalogLoaded = false;
  bool _refreshCatalog = true;
  DateTime? _catalogWatermark;
  DateTime? _fullCatalogAt;
  bool? _catalogLimited;
  void refreshCatalog() => _refreshCatalog = true;
  String _version(AssetEntity a) =>
      '${a.modifiedDateSecond}:${a.width}:${a.height}';

  Future<void> _saveCatalog() async {
    final storage = _storage;
    if (storage is! ScanCatalogStorage) return;
    await (storage as ScanCatalogStorage).saveCatalog({
      'watermark': _catalogWatermark?.toIso8601String(),
      'fullAt': _fullCatalogAt?.toIso8601String(),
      'limited': _catalogLimited,
      'versions': _versions,
      'assets': _catalog.values
          .map(
            (a) => {
              'id': a.id,
              'title': a.title,
              'width': a.width,
              'height': a.height,
              'created': a.createDateSecond,
              'modified': a.modifiedDateSecond,
            },
          )
          .toList(),
    });
  }

  Future<List<AssetEntity>> fetchUnindexedAssets({
    required int limit,
    DateTimeRange? dateFilter,
    Set<String> excludeAssetIds = const {},
  }) async {
    if (limit <= 0) return [];
    await initialize();
    if (!_catalogLoaded) {
      final storage = _storage;
      final state = storage is ScanCatalogStorage
          ? await (storage as ScanCatalogStorage).loadCatalog()
          : null;
      if (state != null) {
        _catalogWatermark = DateTime.tryParse(
          state['watermark'] as String? ?? '',
        );
        _fullCatalogAt = DateTime.tryParse(state['fullAt'] as String? ?? '');
        _catalogLimited = state['limited'] as bool?;
        _versions.addAll(
          Map<String, String>.from(state['versions'] as Map? ?? {}),
        );
        for (final row in state['assets'] as List? ?? []) {
          final a = AssetEntity(
            id: row['id'] as String,
            typeInt: 1,
            width: row['width'] as int,
            height: row['height'] as int,
            title: row['title'] as String?,
            createDateSecond: row['created'] as int?,
            modifiedDateSecond: row['modified'] as int?,
          );
          _catalog[a.id] = a;
        }
      }
      _catalogLoaded = true;
    }
    if (_refreshCatalog) {
      final timer = Stopwatch()..start();
      final started = DateTime.now();
      final full =
          _fullCatalogAt == null ||
          started.difference(_fullCatalogAt!).inHours >= 24 ||
          _catalogLimited != limitedGalleryAccess ||
          limitedGalleryAccess;
      final updates = <String, AssetEntity>{};
      for (var page = 0; !_cancelRequested; page++) {
        final assets = await _assetSource.page(
          page: page,
          size: 100,
          modifiedSince: full
              ? null
              : _catalogWatermark?.subtract(const Duration(seconds: 2)),
        );
        for (final a in assets) {
          if (a.type == AssetType.image) updates[a.id] = a;
        }
        if (assets.length < 100) break;
      }
      if (!_cancelRequested) {
        if (full) {
          _catalog.clear();
          _fullCatalogAt = started;
        }
        _catalog.addAll(updates);
        _catalogWatermark = started;
        _catalogLimited = limitedGalleryAccess;
        _refreshCatalog = false;
        await _saveCatalog();
      }
      ScanTimings.add('metadata', timer.elapsedMicroseconds);
    }
    final indexed = await indexedAssetIds();
    final stored = {for (final r in records) r.assetId: r};
    final candidates = _catalog.values.where((a) {
      if (excludeAssetIds.contains(a.id)) return false;
      if (dateFilter != null &&
          (a.createDateTime.isBefore(dateFilter.start) ||
              a.createDateTime.isAfter(dateFilter.end))) {
        return false;
      }
      if (!indexed.contains(a.id)) return true;
      final version = _versions[a.id];
      if (version != null) return version != _version(a);
      final record = stored[a.id];
      return record == null || a.modifiedDateTime.isAfter(record.scannedAt);
    }).toList();
    bool screenshot(AssetEntity a) => RegExp(
      r'screen[ _-]?(shot|capture)',
      caseSensitive: false,
    ).hasMatch(a.title ?? '');
    candidates.sort((a, b) {
      final priority = (screenshot(b) ? 1 : 0) - (screenshot(a) ? 1 : 0);
      return priority != 0
          ? priority
          : b.createDateTime.compareTo(a.createDateTime);
    });
    return candidates.take(limit).toList();
  }

  Future<void> scanSingleAsset(AssetEntity asset) async {
    try {
      final loading = Stopwatch()..start();
      final image = await asset.file;
      ScanTimings.add('image_load', loading.elapsedMicroseconds);
      if (image == null) {
        await _saveFailed(
          asset.id,
          asset.title ?? 'Gallery image',
          'The gallery did not provide an image file.',
          null,
          assetCreatedAt: asset.createDateTime,
        );
      } else {
        await _processImage(
          asset.id,
          asset.title ?? 'Gallery image',
          image.path,
          assetCreatedAt: asset.createDateTime,
        );
      }
    } catch (error) {
      await _saveFailed(
        asset.id,
        asset.title ?? 'Gallery image',
        error.toString(),
        null,
        assetCreatedAt: asset.createDateTime,
      );
    }
  }

  Stream<GalleryScanProgress> scanUpTo({
    required int additionalCount,
    DateTimeRange? dateFilter,
    Set<String>? attemptedAssetIds,
  }) async* {
    if (additionalCount <= 0) throw ArgumentError.value(additionalCount);
    await initialize();
    if (_running) {
      yield GalleryScanProgress(
        status: 'busy',
        message: 'Another scan is running. Try again when it finishes.',
        failed: failedCount,
      );
      return;
    }
    if (!isSupported) {
      yield const GalleryScanProgress(
        status: 'unsupported',
        message: 'Gallery scanning is available on Android/iOS.',
      );
      return;
    }
    _running = true;
    _cancelRequested = false;
    var processed = 0;
    var added = 0;
    var hasMore = false;
    final attempted = attemptedAssetIds ?? <String>{};
    try {
      if (!await _assetSource.requestPermission()) {
        await _publish(
          GalleryScanProgress(
            status: 'permissionDenied',
            message: 'Gallery access was not granted. Open Photo permissions, allow all photos, then search again.',
            failed: failedCount,
          ),
        );
        yield _progress;
        return;
      }
      // Coverage is informational: a global count must never suppress a
      // different date range, or an explicit request to scan more images.
      await coverageForRange(dateFilter);
      final before = await indexedAssetIds();
      final candidates = await fetchUnindexedAssets(
        limit: additionalCount + 1,
        dateFilter: dateFilter,
        excludeAssetIds: attempted,
      );
      hasMore = candidates.length > additionalCount;
      final assets = candidates.take(additionalCount).toList();
      await _publish(
        GalleryScanProgress(
          status: 'scanning',
          message: 'Scanning on this device...',
          total: assets.length,
          failed: failedCount,
          hasMore: hasMore,
        ),
      );
      yield _progress;
      for (final asset in assets) {
        if (_cancelRequested) break;
        attempted.add(asset.id);
        await scanSingleAsset(asset);
        processed++;
        final succeeded = _records.containsKey(asset.id)
            ? !_records[asset.id]!.isFailed
            : records.any((r) => r.assetId == asset.id && !r.isFailed);
        if (succeeded) _versions[asset.id] = _version(asset);
        if (!before.contains(asset.id) && succeeded) {
          added++;
        }
        await _publish(
          GalleryScanProgress(
            status: 'scanning',
            message: 'Scanning on this device...',
            total: assets.length,
            processed: processed,
            failed: failedCount,
            hasMore: hasMore,
          ),
        );
        yield _progress;
      }
      await _publish(
        GalleryScanProgress(
          status: _cancelRequested ? 'cancelled' : 'ready',
          message: _cancelRequested
              ? 'Search cancelled. Indexed photos are saved.'
              : assets.isEmpty
              ? 'No more unindexed photos in this range.'
              : 'Ready',
          total: assets.length,
          processed: processed,
          failed: failedCount,
          hasMore: hasMore || processed < assets.length,
        ),
      );
      yield _progress;
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Gallery scan stopped: $error',
          processed: processed,
          failed: failedCount,
        ),
      );
      yield _progress;
    } finally {
      try {
        await _saveCatalog();
        ScanTimings.report();
        if (dateFilter != null && added > 0) {
          await _storage!.upsertCoverage(dateFilter, added);
        }
      } finally {
        try {
          await _closeRecognizer();
        } finally {
          _running = false;
        }
      }
    }
  }

  GalleryStorage? _storage;
  final Map<String, GalleryScanRecord> _records = {};
  TextRecognizer? _recognizer;
  bool _running = false;
  GalleryScanProgress _progress = const GalleryScanProgress();

  void Function(GalleryScanProgress progress)? onProgress;
  void Function(GalleryScanRecord record)? onRecord;

  List<GalleryScanRecord> get records {
    final result = _records.values.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return List.unmodifiable(result);
  }

  GalleryScanProgress get progress => _progress;
  int get failedCount =>
      _records.values.where((record) => record.isFailed).length;

  Future<void> initialize() => _initialization ??= _initialize().catchError((
    Object error,
    StackTrace stack,
  ) {
    // A failed startup must not permanently poison every subsequent scan.
    _initialization = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _initialize() async {
    _storage ??= await createGalleryStorage();
    final savedRecords = await _storage!.loadRecords();
    for (final json in savedRecords) {
      final record = GalleryScanRecord.fromJson(json);
      _records[record.assetId] = record;
    }
    final savedProgress = await _storage!.loadProgress();
    if (savedProgress == null) {
      await _publish(const GalleryScanProgress(failed: 0), persist: false);
      return;
    }
    final restored = GalleryScanProgress.fromJson(
      savedProgress,
      failed: failedCount,
    );
    if (restored.isScanning) {
      _progress = GalleryScanProgress(
        status: 'interrupted',
        message:
            'The previous scan stopped. Resume to continue where it left off.',
        total: restored.total,
        processed: restored.processed,
        failed: failedCount,
        pendingPickedPhotos: restored.pendingPickedPhotos,
      );
      await _saveProgress();
      return;
    }
    await _publish(restored.copyWith(failed: failedCount), persist: false);
  }

  bool get limitedGalleryAccess => _assetSource.limitedAccess;
  Future<void> openGallerySettings() => _assetSource.openSettings();

  /// Walk Android's permitted local media library, with no picker/upload step.
  Future<bool> scanGallery() async {
    await initialize();
    if (!isSupported) {
      throw UnsupportedError('Gallery scanning requires Android/iOS.');
    }
    if (_running) return false;
    _running = true;
    _cancelRequested = false;
    var checked = 0;
    try {
      if (!await _assetSource.requestPermission()) {
        await _publish(
          GalleryScanProgress(
            status: 'permissionDenied',
            message: 'Gallery access is off. Allow photos in Android settings, then tap Scan gallery.',
            failed: failedCount,
          ),
        );
        return false;
      }
      refreshCatalog();
      final seen = <String>{};
      await _publish(
        GalleryScanProgress(
          status: 'scanning',
          message: limitedGalleryAccess
              ? 'Limited access: scanning only the photos Android permits.'
              : 'Scanning your device gallery. No upload needed.',
          failed: failedCount,
        ),
      );
      while (!_cancelRequested) {
        final assets = await fetchUnindexedAssets(
          limit: _pageSize,
          excludeAssetIds: seen,
        );
        if (assets.isEmpty) break;
        for (final asset in assets) {
          if (_cancelRequested) break;
          seen.add(asset.id);
          await scanSingleAsset(asset);
          if (records.any((r) => r.assetId == asset.id && !r.isFailed)) {
            _versions[asset.id] = _version(asset);
          }
          checked++;
          await _publish(
            GalleryScanProgress(
              status: 'scanning',
              message:
                  '$checked new or changed photos checked. You can search now or pause.',
              processed: checked,
              failed: failedCount,
            ),
          );
        }
        await _saveCatalog();
      }
      await _publish(
        GalleryScanProgress(
          status: _cancelRequested ? 'cancelled' : 'complete',
          message: _cancelRequested
              ? 'Gallery scan paused. Indexed photos are saved.'
              : '$checked new or changed photos checked; $failedCount need retry.${limitedGalleryAccess ? ' Android has granted selected-photo access only.' : ''}',
          processed: checked,
          total: checked,
          failed: failedCount,
        ),
      );
      return !_cancelRequested;
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Gallery scan stopped: $error',
          processed: checked,
          failed: failedCount,
        ),
      );
      rethrow;
    } finally {
      _running = false;
      await _closeRecognizer();
    }
  }

  Future<void> resumeInterruptedScan() async {
    if (_progress.pendingPickedPhotos.isEmpty) {
      await scanGallery();
      return;
    }
    if (_running) return;
    _running = true;
    try {
      final total = _progress.total;
      await _processPickedQueue(
        List.of(_progress.pendingPickedPhotos),
        total: total,
        initialProcessed: _progress.processed,
      );
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Selected-photo resume stopped: $error',
          total: _progress.total,
          processed: _progress.processed,
          failed: failedCount,
          pendingPickedPhotos: _progress.pendingPickedPhotos,
        ),
      );
      rethrow;
    } finally {
      _running = false;
      await _closeRecognizer();
    }
  }

  Future<void> _processPickedQueue(
    List<PendingPickedPhoto> queue, {
    required int total,
    int initialProcessed = 0,
  }) async {
    var processed = initialProcessed;
    final pending = List<PendingPickedPhoto>.of(queue);
    await _publish(
      GalleryScanProgress(
        status: 'scanning',
        message: 'Scanning selected photos…',
        total: total,
        processed: processed,
        failed: failedCount,
        pendingPickedPhotos: pending,
      ),
    );
    while (pending.isNotEmpty) {
      final photo = pending.first;
      final existing = _records[photo.assetId];
      if (existing == null || existing.isFailed) {
        try {
          final reusablePath = await _storage!.savedImageForId(photo.assetId);
          final imagePath = await _storage!.saveImage(
            photo.assetId,
            reusablePath ?? photo.sourcePath,
          );
          pending[0] = photo.copyWith(sourcePath: imagePath);
          await _publish(
            GalleryScanProgress(
              status: 'scanning',
              message: 'Processing selected photo ${processed + 1} of $total.',
              total: total,
              processed: processed,
              failed: failedCount,
              pendingPickedPhotos: pending,
            ),
          );
          await _processImage(photo.assetId, photo.displayName, imagePath);
        } catch (error) {
          await _saveFailed(
            photo.assetId,
            photo.displayName,
            error.toString(),
            await _storage!.savedImageForId(photo.assetId),
          );
        }
      }
      pending.removeAt(0);
      processed++;
      await _publish(
        GalleryScanProgress(
          status: 'scanning',
          message: 'Scanned $processed of $total selected photos.',
          total: total,
          processed: processed,
          failed: failedCount,
          pendingPickedPhotos: pending,
        ),
      );
    }
    await _publish(
      GalleryScanProgress(
        status: 'complete',
        message: 'Selected-photo scan complete. $failedCount need retry.',
        total: total,
        processed: processed,
        failed: failedCount,
      ),
    );
  }

  Future<void> retryFailed() async {
    if (_running) return;
    _running = true;
    final failed = records.where((record) => record.isFailed).toList();
    var processed = 0;
    try {
      await _publish(
        GalleryScanProgress(
          status: 'scanning',
          message: 'Retrying failed photos…',
          total: failed.length,
          failed: failedCount,
        ),
      );
      for (final record in failed) {
        var path = record.imagePath;
        try {
          if (path == null || !await _storage!.imageExists(path)) {
            final asset = await AssetEntity.fromId(record.assetId);
            path = (await asset?.file)?.path;
          }
        } catch (error) {
          await _saveFailed(
            record.assetId,
            record.displayName,
            error.toString(),
            record.imagePath,
          );
        }
        if (path == null) {
          await _saveFailed(
            record.assetId,
            record.displayName,
            'The original photo is no longer available. Grant gallery access again in Android settings.',
            record.imagePath,
          );
        } else {
          await _processImage(
            record.assetId,
            record.displayName,
            path,
            assetCreatedAt: record.assetCreatedAt,
          );
        }
        processed++;
        await _publish(
          GalleryScanProgress(
            status: 'scanning',
            message: 'Retried $processed of ${failed.length} photos.',
            total: failed.length,
            processed: processed,
            failed: failedCount,
          ),
        );
      }
      await _publish(
        GalleryScanProgress(
          status: 'complete',
          message: 'Retry complete. $failedCount photos still need attention.',
          total: failed.length,
          processed: processed,
          failed: failedCount,
        ),
      );
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Retry stopped: $error',
          total: failed.length,
          processed: processed,
          failed: failedCount,
        ),
      );
      rethrow;
    } finally {
      _running = false;
      await _closeRecognizer();
    }
  }

  Future<void> clear() async {
    if (_running) {
      throw StateError(
        'Wait for the current scan to finish before clearing it.',
      );
    }
    await _closeRecognizer();
    await _storage!.clear();
    _records.clear();
    _versions.clear();
    _catalog.clear();
    _fullCatalogAt = null;
    refreshCatalog();
    await _saveCatalog();
    await _publish(const GalleryScanProgress(failed: 0), persist: false);
  }

  Future<void> _processImage(
    String assetId,
    String displayName,
    String sourcePath, {
    DateTime? assetCreatedAt,
  }) async {
    String? imagePath;
    try {
      final copying = Stopwatch()..start();
      imagePath = await _storage!.saveImage(assetId, sourcePath);
      ScanTimings.add('copy', copying.elapsedMicroseconds);
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final resizing = Stopwatch()..start();
      OcrInput? input;
      try {
        input = await OcrInput.prepare(imagePath);
      } catch (_) {
        /* Original remains usable. */
      }
      ScanTimings.add('resize', resizing.elapsedMicroseconds);
      late RecognizedText result;
      var scaleX = input?.scaleX ?? 1.0;
      var scaleY = input?.scaleY ?? 1.0;
      final ocr = Stopwatch()..start();
      try {
        try {
          result = await recognizer.processImage(
            InputImage.fromFilePath(input?.path ?? imagePath),
          );
        } catch (_) {
          if (input?.resized != true) rethrow;
          result = await recognizer.processImage(
            InputImage.fromFilePath(imagePath),
          );
          scaleX = scaleY = 1;
          ScanTimings.add('ocr_full_retry', ocr.elapsedMicroseconds);
        }
        final lines = result.blocks.expand((b) => b.lines).toList();
        if (input?.resized == true &&
            scaleX != 1 &&
            (result.text.trim().length < 24 ||
                lines.length < 2 ||
                lines.any((l) => l.boundingBox.height < 10))) {
          final retry = Stopwatch()..start();
          result = await recognizer.processImage(
            InputImage.fromFilePath(imagePath),
          );
          scaleX = scaleY = 1;
          ScanTimings.add('ocr_full_retry', retry.elapsedMicroseconds);
        }
      } finally {
        await input?.close();
      }
      ScanTimings.add('ocr', ocr.elapsedMicroseconds);
      final screenshotId = 'gallery-$assetId';
      final blocks = <GalleryScanBlock>[];
      for (final textBlock in result.blocks) {
        for (final line in textBlock.lines) {
          if (line.text.trim().isEmpty) continue;
          blocks.add(
            GalleryScanBlock(
              id: '$screenshotId-block-${blocks.length}',
              text: line.text.trim(),
              left: line.boundingBox.left * scaleX,
              top: line.boundingBox.top * scaleY,
              width: line.boundingBox.width * scaleX,
              height: line.boundingBox.height * scaleY,
            ),
          );
        }
      }
      final record = GalleryScanRecord(
        assetId: assetId,
        displayName: displayName,
        status: 'complete',
        scannedAt: DateTime.now(),
        imagePath: imagePath,
        blocks: List.unmodifiable(blocks),
        assetCreatedAt: assetCreatedAt,
      );
      _records[assetId] = record;
      await _storage!.saveRecord(record.toJson());
      onRecord?.call(record);
    } catch (error) {
      await _saveFailed(
        assetId,
        displayName,
        error.toString(),
        imagePath,
        assetCreatedAt: assetCreatedAt,
      );
    }
  }

  Future<void> _saveFailed(
    String assetId,
    String displayName,
    String error,
    String? imagePath, {
    DateTime? assetCreatedAt,
  }) async {
    final record = GalleryScanRecord(
      assetId: assetId,
      displayName: displayName,
      status: 'failed',
      scannedAt: DateTime.now(),
      imagePath: imagePath,
      error: error,
      blocks: const [],
      assetCreatedAt: assetCreatedAt,
    );
    _records[assetId] = record;
    await _storage!.saveRecord(record.toJson());
    onRecord?.call(record);
  }

  Future<void> _publish(
    GalleryScanProgress progress, {
    bool persist = true,
  }) async {
    _progress = progress.copyWith(failed: failedCount);
    if (persist) await _saveProgress();
    onProgress?.call(_progress);
  }

  Future<void> _saveProgress() => _storage!.saveProgress(_progress.toJson());

  Future<void> _closeRecognizer() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}

extension on GalleryScanProgress {
  GalleryScanProgress copyWith({
    String? status,
    String? message,
    int? total,
    int? processed,
    int? failed,
    List<PendingPickedPhoto>? pendingPickedPhotos,
    bool? hasMore,
  }) => GalleryScanProgress(
    status: status ?? this.status,
    message: message ?? this.message,
    total: total ?? this.total,
    processed: processed ?? this.processed,
    failed: failed ?? this.failed,
    pendingPickedPhotos: pendingPickedPhotos ?? this.pendingPickedPhotos,
    hasMore: hasMore ?? this.hasMore,
  );
}
