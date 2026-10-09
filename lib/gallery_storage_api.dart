import 'package:flutter/material.dart' show DateTimeRange;

export 'package:flutter/material.dart' show DateTimeRange;

abstract interface class GalleryStorage {
  Future<int> count();
  Future<Set<String>> allAssetIds();
  Future<void> upsertCoverage(DateTimeRange range, int addedCount);
  Future<int> coverageCount(DateTimeRange? range);
  Future<List<Map<String, dynamic>>> loadRecords();
  Future<void> saveRecord(Map<String, dynamic> record);
  Future<Map<String, dynamic>?> loadProgress();
  Future<void> saveProgress(Map<String, dynamic> progress);
  Future<String> saveImage(String assetId, String sourcePath);
  Future<String?> savedImageForId(String assetId);
  Future<bool> imageExists(String imagePath);
  Future<void> clear();
}
