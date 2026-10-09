import 'gallery_storage_api.dart';

Future<GalleryStorage> createGalleryStorage() async => _MemoryGalleryStorage();

class _MemoryGalleryStorage implements GalleryStorage {
  @override
  Future<int> count() async => 0;

  @override
  Future<Set<String>> allAssetIds() async => {};

  @override
  Future<void> upsertCoverage(DateTimeRange range, int addedCount) async {}

  @override
  Future<int> coverageCount(DateTimeRange? range) async => 0;

  final Map<String, Map<String, dynamic>> _records = {};
  Map<String, dynamic>? _progress;

  @override
  Future<void> clear() async {
    _records.clear();
    _progress = null;
  }

  @override
  Future<bool> imageExists(String imagePath) async => false;

  @override
  Future<List<Map<String, dynamic>>> loadRecords() async =>
      _records.values.toList(growable: false);

  @override
  Future<Map<String, dynamic>?> loadProgress() async => _progress;

  @override
  Future<String> saveImage(String assetId, String sourcePath) =>
      Future.error(UnsupportedError('Gallery image storage is unavailable.'));

  @override
  Future<String?> savedImageForId(String assetId) async => null;

  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    _progress = Map<String, dynamic>.from(progress);
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    _records[record['assetId'] as String] = Map<String, dynamic>.from(record);
  }
}
