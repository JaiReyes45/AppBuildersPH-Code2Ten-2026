import 'package:gallery_helpdesk/gallery_asset_source.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';
import 'package:gallery_helpdesk/gallery_storage_api.dart';
import 'package:photo_manager/photo_manager.dart';

class SearchMemoryStorage implements GalleryStorage {
  final Map<String, Map<String, dynamic>> data = {};
  final Map<DateTimeRange, int> coverage = {};
  Map<String, dynamic>? progress;
  @override
  Future<int> count() async => (await allAssetIds()).length;
  @override
  Future<Set<String>> allAssetIds() async => data.values
      .where((r) => r['status'] != 'failed')
      .map((r) => r['assetId'] as String)
      .toSet();
  @override
  Future<void> upsertCoverage(DateTimeRange range, int addedCount) async {
    coverage.update(
      range,
      (count) => count + addedCount,
      ifAbsent: () => addedCount,
    );
  }

  @override
  Future<int> coverageCount(DateTimeRange? range) async =>
      range == null ? await count() : coverage[range] ?? 0;
  @override
  Future<List<Map<String, dynamic>>> loadRecords() async =>
      data.values.toList();
  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    data[record['assetId'] as String] = Map.from(record);
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() async => progress;
  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    this.progress = Map.from(progress);
  }

  @override
  Future<String> saveImage(String assetId, String sourcePath) async =>
      sourcePath;
  @override
  Future<String?> savedImageForId(String assetId) async => null;
  @override
  Future<bool> imageExists(String imagePath) async => false;
  @override
  Future<void> clear() async {
    data.clear();
    coverage.clear();
    progress = null;
  }
}

class FakeAssetSource extends GalleryAssetSource {
  FakeAssetSource(this.assets);
  final List<AssetEntity> assets;
  bool granted = true;
  int permissionRequests = 0;
  int pages = 0;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<List<AssetEntity>> page({
    required int page,
    required int size,
    DateTimeRange? range,
  }) async {
    pages++;
    final filtered =
        assets
            .where(
              (asset) =>
                  range == null ||
                  (!asset.createDateTime.isBefore(range.start) &&
                      !asset.createDateTime.isAfter(range.end)),
            )
            .toList()
          ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return filtered.skip(page * size).take(size).toList();
  }
}

AssetEntity fakeAsset(String id, DateTime created) => AssetEntity(
  id: id,
  typeInt: 1,
  width: 100,
  height: 100,
  title: 'synthetic.png',
  createDateSecond: created.millisecondsSinceEpoch ~/ 1000,
);

GalleryScanRecord fakeRecord(
  String id,
  DateTime created, {
  bool fails = false,
  String? text,
}) => GalleryScanRecord(
  assetId: id,
  displayName: 'synthetic.png',
  status: fails ? 'failed' : 'complete',
  scannedAt: DateTime(2026, 10, 10),
  assetCreatedAt: created,
  blocks: fails
      ? []
      : [
          GalleryScanBlock(
            id: 'gallery-$id-block-0',
            text:
                text ??
                'GCash payment successful\nPHP 1000\nReference No. TEST-1234',
          ),
        ],
);

class FakeOcrScanner extends GalleryScanner {
  FakeOcrScanner(this.memory, this.source)
    : super(initialStorage: memory, assetSource: source);
  final SearchMemoryStorage memory;
  final FakeAssetSource source;
  final Set<String> failures = {};
  final List<String> processedIds = [];
  final List<int> batchSizes = [];
  final Map<String, String> texts = {};
  Future<void> Function()? beforeOcr;
  @override
  bool get isSupported => true;
  @override
  List<GalleryScanRecord> get records =>
      memory.data.values.map(GalleryScanRecord.fromJson).toList();
  @override
  int get failedCount => records.where((record) => record.isFailed).length;
  @override
  Future<void> scanSingleAsset(AssetEntity asset) async {
    await beforeOcr?.call();
    processedIds.add(asset.id);
    final record = fakeRecord(
      asset.id,
      asset.createDateTime,
      fails: failures.contains(asset.id),
      text: texts[asset.id],
    );
    await memory.saveRecord(record.toJson());
    onRecord?.call(record);
  }

  @override
  Stream<GalleryScanProgress> scanUpTo({
    required int additionalCount,
    DateTimeRange? dateFilter,
    Set<String>? attemptedAssetIds,
  }) {
    batchSizes.add(additionalCount);
    return super.scanUpTo(
      additionalCount: additionalCount,
      dateFilter: dateFilter,
      attemptedAssetIds: attemptedAssetIds,
    );
  }
}
