import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'data/objectbox_gallery_storage.dart';
import 'data/objectbox_store.dart';
import 'gallery_storage_api.dart';

Future<GalleryStorage>? _openingStorage;
Future<GalleryStorage> createGalleryStorage() => _openingStorage ??=
    _createGalleryStorage().catchError((Object error, StackTrace stack) {
      _openingStorage = null;
      Error.throwWithStackTrace(error, stack);
    });

Future<GalleryStorage> _createGalleryStorage() async {
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(
    '${documents.path}${Platform.pathSeparator}gallery_helpdesk',
  );
  await root.create(recursive: true);
  await Directory('${root.path}${Platform.pathSeparator}images')
      .create(recursive: true);
  final store = await ObjectBoxStore.open();
  try {
    final storage = ObjectBoxGalleryStorage(store, root);
    await storage.migrateLegacyData();
    return storage;
  } catch (_) {
    await store.close();
    rethrow;
  }
}

// Retained unchanged as the legacy storage implementation.
// ignore: unused_element
class _FileGalleryStorage implements GalleryStorage {
  _FileGalleryStorage(this.root);

  @override
  Future<int> count() async => (await allAssetIds()).length;

  @override
  Future<Set<String>> allAssetIds() async => (await loadRecords())
      .where((record) => record['status'] != 'failed')
      .map((record) => record['assetId'] as String)
      .toSet();

  // This legacy implementation is no longer selected by the factory.
  @override
  Future<void> upsertCoverage(DateTimeRange range, int addedCount) async {}

  @override
  Future<int> coverageCount(DateTimeRange? range) async =>
      range == null ? await count() : 0;

  final Directory root;

  Directory get _records =>
      Directory('${root.path}${Platform.pathSeparator}records');

  Directory get _images =>
      Directory('${root.path}${Platform.pathSeparator}images');

  File get _progress =>
      File('${root.path}${Platform.pathSeparator}scan_progress.json');

  Future<void> initialize() async {
    await _records.create(recursive: true);
    await _images.create(recursive: true);
  }

  String _recordPath(String assetId) {
    final key = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
    return '${_records.path}${Platform.pathSeparator}$key.json';
  }

  @override
  Future<void> clear() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await initialize();
  }

  @override
  Future<bool> imageExists(String imagePath) => File(imagePath).exists();

  @override
  Future<List<Map<String, dynamic>>> loadRecords() async {
    await initialize();
    final files = await _records
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    final records = <Map<String, dynamic>>[];
    for (final file in files) {
      final decoded = jsonDecode(await file.readAsString());
      records.add(Map<String, dynamic>.from(decoded as Map));
    }
    return records;
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    if (!await _progress.exists()) return null;
    final decoded = jsonDecode(await _progress.readAsString());
    return Map<String, dynamic>.from(decoded as Map);
  }

  @override
  Future<String> saveImage(String assetId, String sourcePath) async {
    await initialize();
    final source = File(sourcePath);
    final sourceName = sourcePath.split(RegExp(r'[/\\]')).last;
    final extension = sourceName.contains('.')
        ? '.${sourceName.split('.').last.toLowerCase()}'
        : '.img';
    final key = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
    final destination = File(
      '${_images.path}${Platform.pathSeparator}$key$extension',
    );
    if (source.absolute.path == destination.absolute.path) {
      return destination.path;
    }
    await source.copy(destination.path);
    return destination.path;
  }

  @override
  Future<String?> savedImageForId(String assetId) async {
    await initialize();
    final key = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
    await for (final entity in _images.list()) {
      if (entity is File && entity.uri.pathSegments.last.startsWith('$key.')) {
        return entity.path;
      }
    }
    return null;
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    await initialize();
    await _progress.writeAsString(jsonEncode(progress), flush: true);
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    await initialize();
    await File(_recordPath(record['assetId'] as String))
        .writeAsString(jsonEncode(record), flush: true);
  }
}
