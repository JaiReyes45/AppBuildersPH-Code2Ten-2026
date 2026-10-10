import 'package:gallery_helpdesk/semantic_store.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/data/objectbox_entities.dart';
import 'package:gallery_helpdesk/data/objectbox_gallery_storage.dart';
import 'package:gallery_helpdesk/data/objectbox_store.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';
import 'package:gallery_helpdesk/objectbox.g.dart';

void main() {
  late Directory temporary;
  late Directory root;
  late ObjectBoxStore store;
  late ObjectBoxGalleryStorage storage;

  Future<void> open() async {
    store = ObjectBoxStore(
      await openStore(directory: '${temporary.path}/objectbox'),
    );
    storage = ObjectBoxGalleryStorage(store, root);
  }

  Future<void> reopen() async {
    await store.close();
    await open();
  }

  Map<String, dynamic> record(
    String id, {
    String? imagePath,
    String status = 'complete',
    DateTime? scannedAt,
    DateTime? assetCreatedAt,
  }) => GalleryScanRecord(
    assetId: id,
    displayName: 'synthetic.png',
    status: status,
    scannedAt: scannedAt ?? DateTime.utc(2026, 10, 9, 12, 0, 0, 123, 456),
    assetCreatedAt: assetCreatedAt,
    imagePath: imagePath,
    error: status == 'failed' ? 'Synthetic failure' : null,
    blocks: const [
      GalleryScanBlock(
        id: 'block-0',
        text: 'Reference No. DEMO-1234',
        left: 1.25,
        top: 2,
        width: 40.5,
        height: 10,
      ),
      GalleryScanBlock(id: 'block-1', text: 'PHP 500'),
    ],
  ).toJson();

  test(
    'frequent searches survive reopen and can be cleared separately',
    () async {
      await storage.saveSearchCounts({'receipt': 3, 'orders': 1});
      await reopen();
      expect(await storage.loadSearchCounts(), {'receipt': 3, 'orders': 1});
      await storage.saveSearchCounts({});
      expect(await storage.loadSearchCounts(), isEmpty);
    },
  );

  test('semantic vectors and memory persist; clear removes both', () async {
    final vector = List<double>.filled(384, 0)..[0] = 1;
    await storage.writeSemantic(
      SemanticRecord('chunk:test', 'chunk', 'test', {'id': 'a'}, vector),
    );
    await storage.writeSemantic(
      const SemanticRecord('marker', 'document', 'test', {
        'fingerprint': 'abc',
      }, []),
    );
    await reopen();
    expect(
      (await storage.readSemantic('marker'))?.payload['fingerprint'],
      'abc',
    );
    expect(
      (await storage.nearestSemantic(vector, 'chunk', 'test')).single.key,
      'chunk:test',
    );
    expect(await storage.nearestSemantic(vector, 'memory', 'test'), isEmpty);
    await storage.clear();
    expect(await storage.readSemantic('chunk:test'), isNull);
  });

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('helpdesk-storage-test-');
    root = Directory('${temporary.path}/gallery_helpdesk');
    await root.create();
    await open();
  });

  tearDown(() async {
    await store.close();
    final parent = await Directory.systemTemp.resolveSymbolicLinks();
    final target = Directory(await temporary.resolveSymbolicLinks());
    if (target.parent.path != parent ||
        !target.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .startsWith('helpdesk-storage-test-')) {
      throw StateError('Refusing to remove an unexpected test directory');
    }
    await target.delete(recursive: true);
  });

  test(
    'real database survives reopen with exact maps and timestamp order',
    () async {
      final older = record('older');
      final newer = record(
        'newer',
        scannedAt: DateTime.utc(2026, 10, 9, 12, 0, 0, 123, 457),
      );
      await storage.saveRecord(newer);
      await storage.saveRecord(older);
      await reopen();
      expect(await storage.loadRecords(), [newer, older]);
      expect(
        store.screenshots.getAll().every((row) => row.embedding == null),
        isTrue,
      );
    },
  );

  test(
    'upsert preserves ID, vector, and metadata; invalid input is rejected',
    () async {
      await storage.saveRecord(record('asset'));
      final row = store.screenshots.getAll().single;
      final id = row.id;
      row.embedding = Float32List.fromList(List.filled(384, 0.25));
      row.category = 'receipt';
      row.contentHash = 'synthetic-hash';
      final importedAt = row.importedAt;
      store.screenshots.put(row);
      await storage.saveRecord({
        ...record('asset'),
        'displayName': 'updated.png',
      });
      await expectLater(
        storage.saveRecord({'assetId': 'asset'}),
        throwsA(isA<TypeError>()),
      );
      await reopen();
      final updated = store.screenshots.getAll().single;
      expect(updated.id, id);
      expect(updated.originalName, 'updated.png');
      expect(updated.category, 'receipt');
      expect(updated.contentHash, 'synthetic-hash');
      expect(updated.importedAt, importedAt);
      expect(updated.embedding, List.filled(384, 0.25));
      final duplicate = IndexedScreenshot()..galleryAssetId = 'asset';
      expect(
        () => store.screenshots.put(duplicate),
        throwsA(isA<UniqueViolationException>()),
      );
    },
  );

  test('counts and asset IDs exclude failed records', () async {
    await storage.saveRecord(record('complete'));
    await storage.saveRecord(record('failed', status: 'failed'));
    expect(await storage.count(), 1);
    expect(await storage.allAssetIds(), {'complete'});
  });

  test('coverage is exact-range additive and survives reopen', () async {
    final range = DateTimeRange(
      start: DateTime.utc(2026, 10, 1),
      end: DateTime.utc(2026, 10, 31, 23, 59, 59, 999),
    );
    await storage.upsertCoverage(range, 300);
    await storage.upsertCoverage(range, 12);
    expect(await storage.coverageCount(range), 312);
    expect(await storage.coverageCount(null), 0);
    await reopen();
    expect(await storage.coverageCount(range), 312);
    expect(
      await storage.coverageCount(
        DateTimeRange(
          start: range.start,
          end: range.end.subtract(const Duration(milliseconds: 1)),
        ),
      ),
      0,
    );
  });

  test(
    'asset creation timestamp persists and clear removes coverage',
    () async {
      final created = DateTime.utc(2026, 10, 8, 8, 7, 6);
      await storage.saveRecord(record('dated', assetCreatedAt: created));
      expect(
        DateTime.parse(
          (await storage.loadRecords()).single['assetCreatedAt'] as String,
        ).toUtc(),
        created,
      );
      await storage.upsertCoverage(
        DateTimeRange(
          start: created,
          end: created.add(const Duration(days: 1)),
        ),
        1,
      );
      await storage.clear();
      expect(
        await storage.coverageCount(
          DateTimeRange(
            start: created,
            end: created.add(const Duration(days: 1)),
          ),
        ),
        0,
      );
    },
  );

  test(
    'singleton progress retains queue and scanner recalculates failed count',
    () async {
      expect(await storage.loadProgress(), isNull);
      await storage.saveRecord(record('failed', status: 'failed'));
      final progress = {
        'status': 'scanning',
        'message': 'Scanning',
        'total': 5,
        'processed': 2,
        'pendingPickedPhotos': [
          {
            'assetId': 'picked',
            'displayName': 'image.png',
            'sourcePath': '/private/image.png',
          },
        ],
        'futureMetadata': 'retained',
      };
      await storage.saveProgress(progress);
      expect(await storage.loadProgress(), {...progress, 'failed': 1});
      await storage.saveProgress({...progress, 'failed': 9});
      await reopen();
      expect(store.progress.getAll().single.id, 1);
      expect((await storage.loadProgress())!['failed'], 9);
      final scanner = GalleryScanner(initialStorage: storage);
      await scanner.initialize();
      expect(scanner.progress.status, 'interrupted');
      expect(scanner.progress.failed, 1);
      expect(scanner.progress.pendingPickedPhotos.single.assetId, 'picked');
      expect((await storage.loadProgress())!['failed'], 1);
    },
  );

  test(
    'image copy encoding, lookup, missing files and self-copy work',
    () async {
      final original = File('${temporary.path}/source.JPG');
      await original.writeAsBytes([1, 2, 3]);
      const assetId = 'asset/with unicode Ω';
      final saved = await storage.saveImage(assetId, original.path);
      final key = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
      expect(File(saved).uri.pathSegments.last, '$key.jpg');
      expect(await File(saved).readAsBytes(), [1, 2, 3]);
      expect(await storage.savedImageForId(assetId), isNull);
      await storage.saveRecord(record(assetId, imagePath: saved));
      expect(await storage.savedImageForId(assetId), saved);
      expect(await storage.saveImage(assetId, saved), saved);
      await File(saved).delete();
      expect(await storage.imageExists(saved), isFalse);
      expect(await storage.savedImageForId(assetId), isNull);
      await expectLater(
        storage.saveImage(assetId, saved),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'orphan purge preserves records, pending queue and in-flight copies',
    () async {
      final original = File('${temporary.path}/source.png');
      await original.writeAsBytes([1]);
      final indexed = await storage.saveImage('indexed', original.path);
      await storage.saveRecord(record('indexed', imagePath: indexed));
      final pending = await storage.saveImage('pending', original.path);
      await storage.saveProgress({
        'status': 'scanning',
        'pendingPickedPhotos': [
          {
            'assetId': 'pending',
            'displayName': 'source.png',
            'sourcePath': pending,
          },
        ],
      });
      final orphan = await storage.saveImage('abandoned', original.path);
      await reopen();
      final inFlight = await storage.saveImage('in-flight', original.path);
      expect(await storage.listOrphans(), [orphan]);
      await storage.purgeOrphans();
      expect(await File(orphan).exists(), isFalse);
      for (final path in [indexed, pending, inFlight, original.path]) {
        expect(await File(path).exists(), isTrue);
      }
      expect(await storage.listOrphans(), isEmpty);
    },
  );

  test(
    'delete removes only unshared owned copies; clear resets singleton IDs',
    () async {
      final original = File('${temporary.path}/original.png');
      await original.writeAsBytes([1]);
      final copied = await storage.saveImage('one', original.path);
      await storage.saveRecord(record('one', imagePath: copied));
      await storage.saveRecord(record('two', imagePath: copied));
      final one = store.screenshots.getAll().firstWhere(
        (r) => r.galleryAssetId == 'one',
      );
      final two = store.screenshots.getAll().firstWhere(
        (r) => r.galleryAssetId == 'two',
      );
      await storage.deleteById(one.id);
      expect(await File(copied).exists(), isTrue);
      await storage.deleteById(two.id);
      expect(await File(copied).exists(), isFalse);
      await storage.saveRecord(record('external', imagePath: original.path));
      await storage.deleteById(store.screenshots.getAll().single.id);
      expect(await original.exists(), isTrue);
      await storage.saveProgress({'status': 'complete'});
      await storage.saveImage('extra', original.path);
      await storage.clear();
      expect(await storage.loadRecords(), isEmpty);
      expect(await storage.loadProgress(), isNull);
      expect(await Directory('${root.path}/images').list().toList(), isEmpty);
      await storage.saveProgress({'status': 'idle'});
      expect(store.progress.getAll().single.id, 1);
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'legacy migration is durable and does not resurrect cleared records',
    () async {
      final legacyDir = Directory('${root.path}/records');
      await legacyDir.create();
      final legacy = File('${legacyDir.path}/legacy.json');
      final expected = record('legacy');
      await legacy.writeAsString(jsonEncode(expected));
      final progressFile = File('${root.path}/scan_progress.json');
      await progressFile.writeAsString(
        jsonEncode({'status': 'scanning', 'failed': 0}),
      );
      await storage.migrateLegacyData();
      expect(await legacy.exists(), isFalse);
      expect(await progressFile.exists(), isFalse);
      await reopen();
      expect(await storage.loadRecords(), [expected]);
      expect((await storage.loadProgress())!['status'], 'scanning');
      // Simulate interrupted cleanup with an old JSON record left on disk.
      await legacy.writeAsString(jsonEncode(expected));
      await storage.saveRecord({...expected, 'displayName': 'newer.png'});
      await storage.migrateLegacyData();
      expect((await storage.loadRecords()).single['displayName'], 'newer.png');
      await storage.clear();
      await reopen();
      await storage.migrateLegacyData();
      expect(await storage.loadRecords(), isEmpty);
      expect(await storage.loadProgress(), isNull);
    },
  );

  test(
    'bad legacy progress rolls back migration and preserves source JSON',
    () async {
      final legacyDir = Directory('${root.path}/records');
      await legacyDir.create();
      final legacy = File('${legacyDir.path}/legacy.json');
      await legacy.writeAsString(jsonEncode(record('legacy')));
      final progressFile = File('${root.path}/scan_progress.json');
      await progressFile.writeAsString(
        jsonEncode({'pendingPickedPhotos': 'invalid'}),
      );
      await expectLater(storage.migrateLegacyData(), throwsA(isA<TypeError>()));
      expect(store.screenshots.count(), 0);
      expect(store.progress.count(), 0);
      expect(await legacy.exists(), isTrue);
      expect(await progressFile.exists(), isTrue);
    },
  );
}
