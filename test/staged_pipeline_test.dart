import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';
import 'package:gallery_helpdesk/scan_timings.dart';
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:photo_manager/photo_manager.dart';

import 'search_test_fakes.dart';

class _CountingStorage extends SearchMemoryStorage {
  int copies = 0;

  @override
  Future<String> saveImage(String assetId, String sourcePath) async {
    copies++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return 'saved/$assetId.png';
  }
}

class _StagedScanner extends GalleryScanner {
  _StagedScanner(
    _CountingStorage storage,
    FakeAssetSource source, {
    this.thumbnailTexts = const {},
    this.fullTexts = const {},
  }) : super(initialStorage: storage, assetSource: source);

  final Map<String, String> thumbnailTexts;
  final Map<String, String> fullTexts;

  int thumbnailCalls = 0;
  int fullResCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<String?> imagePathForAsset(AssetEntity asset) async => asset.id;

  @override
  Future<GalleryOcrResult> ocrThumbnail(String imagePath) async {
    thumbnailCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return GalleryOcrResult([
      GalleryScanBlock(
        id: 'thumbnail',
        text:
            thumbnailTexts[imagePath] ??
            (imagePath == 'match'
                ? 'Diancie card collection'
                : 'ordinary unrelated screenshot'),
      ),
    ]);
  }

  @override
  Future<GalleryOcrResult> ocrFull(String imagePath) async {
    fullResCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 8));
    return GalleryOcrResult([
      GalleryScanBlock(
        id: 'full',
        text:
            fullTexts[imagePath] ??
            (imagePath == 'match'
                ? 'Diancie card collection full resolution'
                : 'ordinary unrelated screenshot full resolution'),
        left: 10,
        top: 20,
        width: 100,
        height: 30,
      ),
    ]);
  }
}

double _timedMilliseconds(Iterable<String> stages) => stages.fold(
  0,
  (total, stage) =>
      total + (ScanTimings.snapshot[stage]?['totalMs'] ?? 0).toDouble(),
);

void main() {
  test('thumbnail filter enforces keywords and structured constraints', () {
    final scanner = _StagedScanner(
      _CountingStorage(),
      FakeAssetSource(const []),
    );
    final ai = GalleryHelpdeskAi();

    expect(
      scanner.matchesQuery(
        'GCash payment successful\nP500\nReference No. ABC-12345',
        ai.parseQuery('GCash 500'),
      ),
      isTrue,
    );
    expect(
      scanner.matchesQuery(
        'GCash payment successful\nP1,500',
        ai.parseQuery('GCash 500'),
      ),
      isFalse,
    );
    expect(
      scanner.matchesQuery(
        'unicorn collection without the other requested word',
        ai.parseQuery('unicorn dragon'),
      ),
      isFalse,
    );
    expect(
      scanner.matchesQuery(
        'GCash receipt\nReference No. ABC-12345',
        ai.parseQuery('reference ABC-12345'),
      ),
      isTrue,
    );
  });

  test(
    'structured thumbnail filters use soft keywords and exact amounts',
    () async {
      final ai = GalleryHelpdeskAi();
      final matchingStorage = _CountingStorage();
      final matching = _StagedScanner(
        matchingStorage,
        FakeAssetSource([fakeAsset('receipt-500', DateTime(2026, 10, 10))]),
        thumbnailTexts: const {
          'receipt-500': 'Money Sent\nSent to Maria\n500.00',
        },
        fullTexts: const {'receipt-500': 'Money Sent\nSent to Maria\n500.00'},
      );

      await matching
          .scanUpTo(
            additionalCount: 1,
            currentQuery: ai.parseQuery('GCash 500'),
          )
          .toList();

      expect(matching.fullResCalls, 1);
      expect(matchingStorage.data['receipt-500']?['status'], 'complete');

      final wrongStorage = _CountingStorage();
      final wrong = _StagedScanner(
        wrongStorage,
        FakeAssetSource([fakeAsset('receipt-2500', DateTime(2026, 10, 10))]),
        thumbnailTexts: const {'receipt-2500': 'Money Sent\nP2,500'},
      );

      await wrong
          .scanUpTo(additionalCount: 1, currentQuery: ai.parseQuery('500'))
          .toList();

      expect(wrong.fullResCalls, 0);
      expect(wrongStorage.data['receipt-2500']?['status'], 'thumbnail');
    },
  );

  test('candidate callback runs only after the full-resolution gate', () async {
    final storage = _CountingStorage();
    final scanner = _StagedScanner(
      storage,
      FakeAssetSource([fakeAsset('candidate', DateTime(2026, 10, 10))]),
      thumbnailTexts: const {'candidate': 'Diancie card'},
      fullTexts: const {'candidate': 'unrelated full-resolution text'},
    );
    var candidateCalls = 0;

    await scanner
        .scanUpTo(
          additionalCount: 1,
          currentQuery: GalleryHelpdeskAi().parseQuery('Diancie'),
          onCandidate: (_) async {
            candidateCalls++;
            return CandidateAction.accept;
          },
        )
        .toList();

    expect(candidateCalls, 0);
    expect(storage.copies, 0);
    expect(storage.data['candidate']?['status'], 'thumbnail');
  });

  test(
    'query scan promotes only matching thumbnail and halves measured work',
    () async {
      final assets = [
        fakeAsset('match', DateTime(2026, 10, 10, 0, 0, 40)),
        ...List.generate(
          39,
          (index) => fakeAsset(
            'miss-$index',
            DateTime(2026, 10, 10, 0, 0, 39 - index),
          ),
        ),
      ];
      final query = GalleryHelpdeskAi().parseQuery('Diancie');

      ScanTimings.reset();
      final stagedStorage = _CountingStorage();
      final staged = _StagedScanner(
        stagedStorage,
        FakeAssetSource(List<AssetEntity>.of(assets)),
      );
      await staged.scanUpTo(additionalCount: 40, currentQuery: query).toList();
      final stagedTime = _timedMilliseconds([
        'thumbnailOcr',
        'fullResOcr',
        'copy',
      ]);

      expect(staged.thumbnailCalls, 40);
      expect(staged.fullResCalls, 1);
      expect(stagedStorage.copies, 1);
      expect(
        stagedStorage.data.values.where((row) => row['status'] == 'complete'),
        hasLength(1),
      );
      final thumbnailRows = stagedStorage.data.values.where(
        (row) => row['status'] == 'thumbnail',
      );
      expect(thumbnailRows, hasLength(39));
      expect(thumbnailRows.every((row) => row['imagePath'] == null), isTrue);
      expect(
        thumbnailRows.every(
          (row) =>
              (row['blocks'] as List).isNotEmpty &&
              ((row['blocks'] as List).first as Map)['left'] == null,
        ),
        isTrue,
      );
      expect(ScanTimings.snapshot['thumbnailOcr']?['calls'], 40);
      expect(ScanTimings.snapshot['fullResOcr']?['calls'], 1);
      expect(
        (await staged.fetchUnindexedAssets(limit: 40)).map((asset) => asset.id),
        hasLength(39),
        reason: 'Thumbnail-only rows must remain eligible for later promotion.',
      );

      ScanTimings.reset();
      final baselineStorage = _CountingStorage();
      final baseline = _StagedScanner(
        baselineStorage,
        FakeAssetSource(List<AssetEntity>.of(assets)),
      );
      await baseline.scanUpTo(additionalCount: 40).toList();
      final baselineTime = _timedMilliseconds(['fullResOcr', 'copy']);

      expect(baseline.thumbnailCalls, 0);
      expect(baseline.fullResCalls, 40);
      expect(baselineStorage.copies, 40);
      expect(
        stagedTime * 2,
        lessThan(baselineTime),
        reason: 'Fake timing aggregates should show at least a 2x speedup.',
      );
    },
  );
}
