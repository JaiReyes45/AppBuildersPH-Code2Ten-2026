import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'gallery_storage_api.dart';

Future<GalleryStorage> createGalleryStorage() async {
  final documents = await getApplicationDocumentsDirectory();
  final storage = _FileGalleryStorage(
    Directory('${documents.path}${Platform.pathSeparator}gallery_helpdesk'),
  );
  await storage.initialize();
  return storage;
}

class _FileGalleryStorage implements GalleryStorage {
  _FileGalleryStorage(this.root);

  final Directory root;

  Directory get _records => Directory(
    '${root.path}${Platform.pathSeparator}records',
  );

  Directory get _images => Directory(
    '${root.path}${Platform.pathSeparator}images',
  );

  File get _progress => File(
    '${root.path}${Platform.pathSeparator}scan_progress.json',
  );

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
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('$key.')) {
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
    await File(_recordPath(record['assetId'] as String)).writeAsString(
      jsonEncode(record),
      flush: true,
    );
  }
}
