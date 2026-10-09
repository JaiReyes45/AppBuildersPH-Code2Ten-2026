import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_storage.dart';

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
  });

  final String assetId;
  final String displayName;
  final String status;
  final DateTime scannedAt;
  final List<GalleryScanBlock> blocks;
  final String? imagePath;
  final String? error;

  bool get isFailed => status == 'failed';

  String get recognizedText =>
      blocks.map((block) => block.text).join('\n');

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'displayName': displayName,
    'status': status,
    'scannedAt': scannedAt.toIso8601String(),
    'imagePath': imagePath,
    'error': error,
    'blocks': blocks.map((block) => block.toJson()).toList(),
  };

  factory GalleryScanRecord.fromJson(Map<String, dynamic> json) =>
      GalleryScanRecord(
        assetId: json['assetId'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        imagePath: json['imagePath'] as String?,
        error: json['error'] as String?,
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
  });

  final String status;
  final String message;
  final int total;
  final int processed;
  final int failed;
  final List<PendingPickedPhoto> pendingPickedPhotos;

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
    message:
        json['message'] as String? ?? 'No gallery photos scanned yet.',
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
  GalleryScanner({GalleryStorage? initialStorage})
    : _storage = initialStorage;

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
  int get failedCount => _records.values.where((record) => record.isFailed).length;

  Future<void> initialize() async {
    _storage ??= await createGalleryStorage();
    final savedRecords = await _storage!.loadRecords();
    for (final json in savedRecords) {
      final record = GalleryScanRecord.fromJson(json);
      _records[record.assetId] = record;
    }
    final savedProgress = await _storage!.loadProgress();
    if (savedProgress == null) {
      await _publish(
        const GalleryScanProgress(failed: 0),
        persist: false,
      );
      return;
    }
    final restored = GalleryScanProgress.fromJson(
      savedProgress,
      failed: failedCount,
    );
    if (restored.isScanning) {
      _progress = GalleryScanProgress(
        status: 'interrupted',
        message: 'The previous scan stopped. Resume to continue where it left off.',
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

  Future<bool> scanGallery() async {
    if (!isGalleryScanningSupported) {
      throw UnsupportedError('Gallery scanning is available on Android/iOS.');
    }
    if (_running) return false;
    _running = true;
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!permission.hasAccess) {
        await _publish(
          GalleryScanProgress(
            status: 'permissionDenied',
            message: 'Photo access was not granted. Choose specific photos instead.',
            processed: 0,
            total: 0,
            failed: failedCount,
          ),
        );
        return false;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isEmpty) {
        await _publish(
          GalleryScanProgress(
            status: 'complete',
            message: 'No permitted photos were found.',
            failed: failedCount,
          ),
        );
        return true;
      }
      final path = paths.first;
      final total = await path.assetCountAsync;
      var processed = 0;
      await _publish(
        GalleryScanProgress(
          status: 'scanning',
          message: 'Scanning permitted gallery photos…',
          total: total,
          failed: failedCount,
        ),
      );
      for (var page = 0; ; page++) {
        final assets = await path.getAssetListPaged(
          page: page,
          size: _pageSize,
        );
        if (assets.isEmpty) break;
        for (final asset in assets) {
          final existing = _records[asset.id];
          if (existing == null) {
            try {
              final image = await asset.file;
              if (image == null) {
                await _saveFailed(
                  asset.id,
                  asset.title ?? 'Gallery image',
                  'The gallery did not provide an image file.',
                  null,
                );
              } else {
                await _processImage(
                  asset.id,
                  asset.title ?? 'Gallery image',
                  image.path,
                );
              }
            } catch (error) {
              await _saveFailed(
                asset.id,
                asset.title ?? 'Gallery image',
                error.toString(),
                null,
              );
            }
          }
          processed++;
          await _publish(
            GalleryScanProgress(
              status: 'scanning',
              message: 'Scanned $processed of $total photos.',
              total: total,
              processed: processed,
              failed: failedCount,
            ),
          );
        }
      }
      await _publish(
        GalleryScanProgress(
          status: 'complete',
          message: 'Scan complete. $processed photos checked; $failedCount need retry.',
          total: total,
          processed: processed,
          failed: failedCount,
        ),
      );
      return true;
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Gallery scan stopped: $error',
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

  Future<void> scanPickedImages(List<XFile> images) async {
    if (!isGalleryScanningSupported) {
      throw UnsupportedError('On-device OCR is available on Android/iOS.');
    }
    if (_running) return;
    _running = true;
    try {
      final batchId = DateTime.now().microsecondsSinceEpoch;
      final queue = images.indexed
          .map(
            (entry) => PendingPickedPhoto(
              assetId: 'picked-$batchId-${entry.$1}',
              displayName: entry.$2.name,
              sourcePath: entry.$2.path,
            ),
          )
          .toList(growable: true);
      await _processPickedQueue(queue, total: queue.length);
    } catch (error) {
      await _publish(
        GalleryScanProgress(
          status: 'error',
          message: 'Selected-photo scan stopped: $error',
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
            'The original photo is no longer available. Grant access again or choose it from the photo picker.',
            record.imagePath,
          );
        } else {
          await _processImage(
            record.assetId,
            record.displayName,
            path,
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
      throw StateError('Wait for the current scan to finish before clearing it.');
    }
    await _closeRecognizer();
    await _storage!.clear();
    _records.clear();
    await _publish(
      const GalleryScanProgress(failed: 0),
      persist: false,
    );
  }

  Future<void> _processImage(
    String assetId,
    String displayName,
    String sourcePath,
  ) async {
    String? imagePath;
    try {
      imagePath = await _storage!.saveImage(assetId, sourcePath);
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final screenshotId = 'gallery-$assetId';
      final blocks = <GalleryScanBlock>[];
      for (final textBlock in result.blocks) {
        for (final line in textBlock.lines) {
          if (line.text.trim().isEmpty) continue;
          blocks.add(
            GalleryScanBlock(
              id: '$screenshotId-block-${blocks.length}',
              text: line.text.trim(),
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              width: line.boundingBox.width,
              height: line.boundingBox.height,
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
      );
    }
  }

  Future<void> _saveFailed(
    String assetId,
    String displayName,
    String error,
    String? imagePath,
  ) async {
    final record = GalleryScanRecord(
      assetId: assetId,
      displayName: displayName,
      status: 'failed',
      scannedAt: DateTime.now(),
      imagePath: imagePath,
      error: error,
      blocks: const [],
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

  Future<void> _saveProgress() =>
      _storage!.saveProgress(_progress.toJson());

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
  }) => GalleryScanProgress(
    status: status ?? this.status,
    message: message ?? this.message,
    total: total ?? this.total,
    processed: processed ?? this.processed,
    failed: failed ?? this.failed,
    pendingPickedPhotos: pendingPickedPhotos ?? this.pendingPickedPhotos,
  );
}
