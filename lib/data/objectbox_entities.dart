import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

/// The README Screenshot contract, with the scanner's OCR payload retained.
@Entity()
class IndexedScreenshot {
  @Id()
  int id = 0;

  @Unique()
  @Index()
  String galleryAssetId = '';

  String originalName = '';
  String? localPath;
  String status = '';
  String? error;

  @Property(type: PropertyType.date)
  DateTime importedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? assetModifiedAt;

  @Property(type: PropertyType.date)
  DateTime? assetCreatedAt;

  String? contentHash;
  String? category;
  int? imageWidth;
  int? imageHeight;

  @Index()
  @Property(type: PropertyType.date)
  DateTime scannedAt = DateTime.now();

  // ObjectBox dates have millisecond precision. Keep the scanner's complete
  // timestamp as well, including microseconds and the UTC/local distinction.
  String scannedAtIso = '';
  String blocksJson = '[]';

  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  Float32List? embedding;
}

/// Singleton row; progressJson preserves the scanner's full queue contract.
@Entity()
class ScanProgressRow {
  @Id(assignable: true)
  int id = 0;

  String progressJson = '{}';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? scanStartedAt;

  // The current scanner does not expose a persistent gallery cursor.
  String? currentCursor;
  int processedCount = 0;
  int failedCount = 0;
  String status = 'idle';
}

@Entity()
class ScanCoverage {
  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime rangeStart = DateTime(1970);

  @Property(type: PropertyType.date)
  DateTime rangeEnd = DateTime(2100);

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  int scannedCount = 0;
}

/// Versioned local semantic chunks and explicitly confirmed query memories.
@Entity()
class SemanticEntry {
  @Id()
  int id = 0;
  @Unique()
  String key = '';
  @Index()
  String kind = '';
  String version = '';
  String payload = '{}';
  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  Float32List? vector;
}
