import 'dart:convert';
import 'dart:io';

import '../gallery_scanner.dart';
import '../gallery_storage_api.dart';
import '../objectbox.g.dart';
import 'objectbox_entities.dart';
import 'objectbox_store.dart';

class ObjectBoxGalleryStorage implements GalleryStorage {
  ObjectBoxGalleryStorage(this.store, this.root);

  final ObjectBoxStore store;
  final Directory root;
  final Set<String> _stagedImages = {};

  @override
  Future<int> count() async {
    final query = store.screenshots
        .query(IndexedScreenshot_.status.notEquals('failed'))
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  @override
  Future<Set<String>> allAssetIds() async {
    final query = store.screenshots
        .query(IndexedScreenshot_.status.notEquals('failed'))
        .build();
    try {
      return query.property(IndexedScreenshot_.galleryAssetId).find().toSet();
    } finally {
      query.close();
    }
  }

  Query<ScanCoverage> _coverageQuery(DateTimeRange range) => store.coverage
      .query(
        ScanCoverage_.rangeStart.equals(range.start.millisecondsSinceEpoch) &
            ScanCoverage_.rangeEnd.equals(range.end.millisecondsSinceEpoch),
      )
      .build();

  @override
  Future<void> upsertCoverage(DateTimeRange range, int addedCount) async {
    if (addedCount < 0) throw ArgumentError.value(addedCount, 'addedCount');
    store.store.runInTransaction(TxMode.write, () {
      final query = _coverageQuery(range);
      try {
        final row =
            query.findFirst() ??
            (ScanCoverage()
              ..rangeStart = range.start
              ..rangeEnd = range.end);
        row.scannedCount += addedCount;
        row.updatedAt = DateTime.now();
        store.coverage.put(row);
      } finally {
        query.close();
      }
    });
  }

  @override
  Future<int> coverageCount(DateTimeRange? range) async {
    if (range == null) return count();
    final query = _coverageQuery(range);
    try {
      return query.findFirst()?.scannedCount ?? 0;
    } finally {
      query.close();
    }
  }

  Directory get _images =>
      Directory('${root.path}${Platform.pathSeparator}images');

  IndexedScreenshot? _find(String assetId) {
    final query = store.screenshots
        .query(IndexedScreenshot_.galleryAssetId.equals(assetId))
        .build();
    try {
      return query.findUnique();
    } finally {
      query.close();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadRecords() async {
    final query = store.screenshots.query()
      ..order(IndexedScreenshot_.scannedAt, flags: Order.descending);
    final built = query.build();
    try {
      final rows = built.find();
      // Break sub-millisecond ties using the lossless timestamp.
      rows.sort((a, b) => _scanTime(b).compareTo(_scanTime(a)));
      return rows
          .map(
            (row) => <String, dynamic>{
              'assetId': row.galleryAssetId,
              'displayName': row.originalName,
              'status': row.status,
              'scannedAt': _scanTime(row).toIso8601String(),
              'imagePath': row.localPath,
              'error': row.error,
              'blocks': jsonDecode(row.blocksJson),
              if (row.assetCreatedAt != null)
                'assetCreatedAt': row.assetCreatedAt!.toIso8601String(),
            },
          )
          .toList(growable: false);
    } finally {
      built.close();
    }
  }

  DateTime _scanTime(IndexedScreenshot row) => row.scannedAtIso.isEmpty
      ? row.scannedAt
      : DateTime.parse(row.scannedAtIso);

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    final parsed = GalleryScanRecord.fromJson(record);
    store.store.runInTransaction(TxMode.write, () => _putRecord(parsed));
    if (parsed.imagePath != null) {
      _stagedImages.remove(File(parsed.imagePath!).absolute.path);
    }
  }

  void _putRecord(GalleryScanRecord record) {
    // Mutate the existing row so its ID, embedding and future metadata survive.
    final row = _find(record.assetId) ?? IndexedScreenshot();
    if (record.assetCreatedAt != null) {
      row.assetCreatedAt = record.assetCreatedAt;
    }
    row
      ..galleryAssetId = record.assetId
      ..originalName = record.displayName
      ..status = record.status
      ..scannedAt = record.scannedAt
      ..scannedAtIso = record.scannedAt.toIso8601String()
      ..localPath = record.imagePath
      ..error = record.error
      ..blocksJson = jsonEncode(
        record.blocks.map((block) => block.toJson()).toList(),
      );
    store.screenshots.put(row);
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    final row = store.progress.get(1);
    return row == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(row.progressJson) as Map);
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    store.store.runInTransaction(TxMode.write, () => _putProgress(progress));
  }

  void _putProgress(Map<String, dynamic> progress) {
    final failedQuery = store.screenshots
        .query(IndexedScreenshot_.status.equals('failed'))
        .build();
    late final int failed;
    try {
      failed = (progress['failed'] as num?)?.toInt() ?? failedQuery.count();
    } finally {
      failedQuery.close();
    }
    final payload = {...progress, 'failed': failed};
    final parsed = GalleryScanProgress.fromJson(payload, failed: failed);
    final row = store.progress.get(1) ?? ScanProgressRow();
    if (parsed.isScanning &&
        row.status != 'scanning' &&
        row.status != 'interrupted') {
      row.scanStartedAt = DateTime.now();
    }
    row
      ..id = 1
      ..progressJson = jsonEncode(payload)
      ..updatedAt = DateTime.now()
      ..processedCount = parsed.processed
      ..failedCount = failed
      ..status = parsed.status;
    store.progress.put(row);
  }

  @override
  Future<String> saveImage(String assetId, String sourcePath) async {
    await _images.create(recursive: true);
    final source = File(sourcePath);
    final sourceName = sourcePath.split(RegExp(r'[/\\]')).last;
    final extension = sourceName.contains('.')
        ? '.${sourceName.split('.').last.toLowerCase()}'
        : '.img';
    final key = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
    final destination = File(
      '${_images.path}${Platform.pathSeparator}$key$extension',
    );
    if (source.absolute.path != destination.absolute.path) {
      await source.copy(destination.path);
    } else if (!await source.exists()) {
      throw FileSystemException('Saved image no longer exists', sourcePath);
    }
    _stagedImages.add(destination.absolute.path);
    return destination.path;
  }

  @override
  Future<String?> savedImageForId(String assetId) async {
    final path = _find(assetId)?.localPath;
    return path != null && await imageExists(path) ? path : null;
  }

  @override
  Future<bool> imageExists(String imagePath) => File(imagePath).exists();

  @override
  Future<void> clear() async {
    store.store.runInTransaction(TxMode.write, () {
      store.screenshots.removeAll();
      store.progress.removeAll();
      store.coverage.removeAll();
    });
    _stagedImages.clear();
    if (await _images.exists()) await _images.delete(recursive: true);
    await _images.create(recursive: true);
  }

  /// Delete the index row and its private copy, never an original gallery file.
  Future<void> deleteById(int id) async {
    final path = store.screenshots.get(id)?.localPath;
    store.screenshots.remove(id);
    // Invalidate historical counts when an indexed image is deleted.
    store.coverage.removeAll();
    if (path == null) return;
    final file = File(path);
    if (!await _isOwnedFile(file)) return;
    if ((await _referencedImages()).contains(file.absolute.path)) return;
    if (await file.exists()) await file.delete();
  }

  /// Unreferenced files in images/, excluding queued and in-flight copies.
  Future<List<String>> listOrphans() async {
    if (!await _images.exists()) return [];
    final referenced = await _referencedImages();
    final orphans = <String>[];
    await for (final entry in _images.list(followLinks: false)) {
      if (entry is File && !referenced.contains(entry.absolute.path)) {
        orphans.add(entry.path);
      }
    }
    return orphans..sort();
  }

  Future<void> purgeOrphans() async {
    for (final path in await listOrphans()) {
      final file = File(path);
      if (!await _isOwnedFile(file)) continue;
      if ((await _referencedImages()).contains(file.absolute.path)) continue;
      if (await file.exists()) await file.delete();
    }
  }

  Future<Set<String>> _referencedImages() async {
    final paths = <String>{..._stagedImages};
    for (final row in store.screenshots.getAll()) {
      if (row.localPath != null) paths.add(File(row.localPath!).absolute.path);
    }
    final progress = await loadProgress();
    if (progress != null) {
      final restored = GalleryScanProgress.fromJson(progress, failed: 0);
      for (final photo in restored.pendingPickedPhotos) {
        paths.add(File(photo.sourcePath).absolute.path);
      }
    }
    return paths;
  }

  Future<bool> _isOwnedFile(File file) async {
    if (!await file.exists() || !await _images.exists()) return false;
    final resolved = File(await file.resolveSymbolicLinks());
    return resolved.parent.path == await _images.resolveSymbolicLinks();
  }

  /// Import the interim JSON index once. Only remove legacy metadata after the
  /// transaction commits; interrupted cleanup can safely run again on startup.
  Future<void> migrateLegacyData() async {
    final directory = Directory('${root.path}${Platform.pathSeparator}records');
    final files = <File>[];
    final records = <GalleryScanRecord>[];
    if (await directory.exists()) {
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File && entry.path.endsWith('.json')) {
          records.add(
            GalleryScanRecord.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(await entry.readAsString()) as Map,
              ),
            ),
          );
          files.add(entry);
        }
      }
    }
    final progressFile = File(
      '${root.path}${Platform.pathSeparator}scan_progress.json',
    );
    final progress = await progressFile.exists()
        ? Map<String, dynamic>.from(
            jsonDecode(await progressFile.readAsString()) as Map,
          )
        : null;
    store.store.runInTransaction(TxMode.write, () {
      for (final record in records) {
        if (_find(record.assetId) == null) _putRecord(record);
      }
      if (progress != null && store.progress.get(1) == null) {
        _putProgress(progress);
      }
    });
    for (final file in files) {
      await file.delete();
    }
    if (progress != null) await progressFile.delete();
  }
}
