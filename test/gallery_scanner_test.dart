import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';
import 'package:gallery_helpdesk/gallery_storage.dart';

void main() {
  test('scan records round-trip OCR text and source bounding boxes', () {
    final record = GalleryScanRecord(
      assetId: 'asset-42',
      displayName: 'receipt.jpg',
      status: 'complete',
      scannedAt: DateTime.utc(2026, 10, 9),
      imagePath: '/private/receipt.jpg',
      blocks: const [
        GalleryScanBlock(
          id: 'gallery-asset-42-block-0',
          text: 'Reference No. 123456',
          left: 10,
          top: 20,
          width: 100,
          height: 18,
        ),
      ],
    );

    final restored = GalleryScanRecord.fromJson(record.toJson());

    expect(restored.assetId, record.assetId);
    expect(restored.recognizedText, 'Reference No. 123456');
    expect(restored.blocks.single.id, 'gallery-asset-42-block-0');
    expect(restored.blocks.single.left, 10);
    expect(restored.imagePath, '/private/receipt.jpg');
  });

  test('an interrupted scan resumes from persisted progress', () async {
    final storage = _MemoryGalleryStorage()
      ..records['asset-ok'] = GalleryScanRecord(
        assetId: 'asset-ok',
        displayName: 'order.png',
        status: 'complete',
        scannedAt: DateTime.utc(2026, 10, 9),
        blocks: const [],
      ).toJson()
      ..records['asset-failed'] = GalleryScanRecord(
        assetId: 'asset-failed',
        displayName: 'unreadable.png',
        status: 'failed',
        scannedAt: DateTime.utc(2026, 10, 9),
        error: 'Unreadable image',
        blocks: const [],
      ).toJson()
      ..progress = {
        'status': 'scanning',
        'message': 'Scanning',
        'total': 5,
        'processed': 2,
        'failed': 1,
        'pendingPickedPhotos': [
          {
            'assetId': 'picked-3',
            'displayName': 'announcement.png',
            'sourcePath': '/private/announcement.png',
          },
        ],
      };
    final scanner = GalleryScanner(initialStorage: storage);

    await scanner.initialize();

    expect(scanner.progress.status, 'interrupted');
    expect(scanner.progress.processed, 2);
    expect(scanner.failedCount, 1);
    expect(scanner.progress.pendingPickedPhotos.single.assetId, 'picked-3');
    expect(storage.progress?['status'], 'interrupted');
  });
}

class _MemoryGalleryStorage implements GalleryStorage {
  final Map<String, Map<String, dynamic>> records = {};
  Map<String, dynamic>? progress;

  @override
  Future<void> clear() async {
    records.clear();
    progress = null;
  }

  @override
  Future<bool> imageExists(String imagePath) async => false;

  @override
  Future<String?> savedImageForId(String assetId) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadRecords() async =>
      records.values.toList(growable: false);

  @override
  Future<Map<String, dynamic>?> loadProgress() async => progress;

  @override
  Future<String> saveImage(String assetId, String sourcePath) =>
      Future.error(UnsupportedError('No media file available in this test.'));

  @override
  Future<void> saveProgress(Map<String, dynamic> value) async {
    progress = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    records[record['assetId'] as String] = Map<String, dynamic>.from(record);
  }
}
