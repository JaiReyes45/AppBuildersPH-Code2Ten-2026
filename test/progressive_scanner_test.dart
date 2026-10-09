import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'search_test_fakes.dart';

void main() {
  test(
    'newest assets first; successful IDs skipped; failed assets retryable',
    () async {
      final memory = SearchMemoryStorage();
      await memory.saveRecord(
        fakeRecord('done', DateTime(2026, 10, 9)).toJson(),
      );
      await memory.saveRecord(
        fakeRecord('failed', DateTime(2026, 10, 8), fails: true).toJson(),
      );
      final scanner = FakeOcrScanner(
        memory,
        FakeAssetSource([
          fakeAsset('old', DateTime(2026, 9, 1)),
          fakeAsset('failed', DateTime(2026, 10, 8)),
          fakeAsset('done', DateTime(2026, 10, 9)),
          fakeAsset('new', DateTime(2026, 10, 10)),
        ]),
      );
      expect(await scanner.countIndexed(), 1);
      expect(await scanner.indexedAssetIds(), {'done'});
      expect((await scanner.fetchUnindexedAssets(limit: 2)).map((a) => a.id), [
        'new',
        'failed',
      ]);
      final events = await scanner.scanUpTo(additionalCount: 2).toList();
      expect(scanner.processedIds, ['new', 'failed']);
      expect(events.last.status, 'ready');
      expect(events.last.processed, 2);
      expect(events.last.hasMore, isTrue);
      expect(await scanner.countIndexed(), 3);
    },
  );

  test(
    'range coverage ignores other months and includes both boundary dates',
    () async {
      final memory = SearchMemoryStorage();
      for (var i = 0; i < 300; i++) {
        await memory.saveRecord(
          fakeRecord('sep-$i', DateTime(2026, 9, 15)).toJson(),
        );
      }
      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31, 23, 59, 59),
      );
      final scanner = FakeOcrScanner(
        memory,
        FakeAssetSource([
          fakeAsset('start', range.start),
          fakeAsset('end', range.end),
          fakeAsset('nov', DateTime(2026, 11)),
        ]),
      );
      expect(await scanner.coverageForRange(range), 0);
      await scanner.scanUpTo(additionalCount: 300, dateFilter: range).toList();
      expect(scanner.processedIds, ['end', 'start']);
      expect(await scanner.coverageForRange(range), 2);
      await scanner.scanUpTo(additionalCount: 300, dateFilter: range).toList();
      expect(await scanner.coverageForRange(range), 2);
    },
  );

  test(
    'paging continues past indexed metadata and exhaustion terminates',
    () async {
      final memory = SearchMemoryStorage();
      final assets = List.generate(
        105,
        (i) => fakeAsset('$i', DateTime(2026, 10, 10, 0, 0, 105 - i)),
      );
      for (final asset in assets.take(100)) {
        await memory.saveRecord(
          fakeRecord(asset.id, asset.createDateTime).toJson(),
        );
      }
      final source = FakeAssetSource(assets);
      final scanner = FakeOcrScanner(memory, source);
      final events = await scanner.scanUpTo(additionalCount: 300).toList();
      expect(scanner.processedIds.length, 5);
      expect(source.pages, 2);
      expect(events.last.hasMore, isFalse);
      expect(events.last.total, 5);
    },
  );

  test(
    'failed OCR is excluded from coverage and not retried in the same search',
    () async {
      final memory = SearchMemoryStorage();
      final range = DateTimeRange(
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
      );
      final scanner = FakeOcrScanner(
        memory,
        FakeAssetSource([
          fakeAsset('bad', DateTime(2026, 10, 10)),
          fakeAsset('good', DateTime(2026, 10, 9)),
        ]),
      )..failures.add('bad');
      final attempted = <String>{};
      await scanner
          .scanUpTo(
            additionalCount: 1,
            dateFilter: range,
            attemptedAssetIds: attempted,
          )
          .toList();
      await scanner
          .scanUpTo(
            additionalCount: 1,
            dateFilter: range,
            attemptedAssetIds: attempted,
          )
          .toList();
      expect(scanner.processedIds, ['bad', 'good']);
      expect(await scanner.coverageForRange(range), 1);
      scanner.failures.clear();
      await scanner.scanUpTo(additionalCount: 1, dateFilter: range).toList();
      expect(scanner.processedIds, ['bad', 'good', 'bad']);
      expect(await scanner.coverageForRange(range), 2);
    },
  );

  test('permission denial exits without OCR', () async {
    final source = FakeAssetSource([fakeAsset('one', DateTime(2026))])
      ..granted = false;
    final scanner = FakeOcrScanner(SearchMemoryStorage(), source);
    final events = await scanner.scanUpTo(additionalCount: 300).toList();
    expect(events.single.status, 'permissionDenied');
    expect(scanner.processedIds, isEmpty);
    expect(scanner.isRunning, isFalse);
  });

  test('cancellation retains completed work and releases scan lock', () async {
    final memory = SearchMemoryStorage();
    final scanner = FakeOcrScanner(
      memory,
      FakeAssetSource([
        fakeAsset('one', DateTime(2026, 10, 10)),
        fakeAsset('two', DateTime(2026, 10, 9)),
      ]),
    );
    await for (final event in scanner.scanUpTo(additionalCount: 300)) {
      if (event.processed == 1) scanner.cancelScan();
    }
    expect(scanner.processedIds, ['one']);
    expect(scanner.isRunning, isFalse);
    expect(await scanner.countIndexed(), 1);
    await scanner.scanUpTo(additionalCount: 300).toList();
    expect(scanner.processedIds, ['one', 'two']);
  });
}
