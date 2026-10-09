import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/data/objectbox_store.dart';
import 'package:gallery_helpdesk/data/objectbox_entities.dart';

void main() {
  test(
    'concurrent startup shares a store and reopening preserves records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sseeker-store-test',
      );
      try {
        final stores = await Future.wait(
          List.generate(
            5,
            (_) => ObjectBoxStore.open(directoryPath: directory.path),
          ),
        );
        expect(stores.every((s) => identical(s, stores.first)), isTrue);
        final row = IndexedScreenshot()..galleryAssetId = 'test-asset';
        stores.first.screenshots.put(row);
        await stores.first.close();
        final reopened = await Future.wait(
          List.generate(
            3,
            (_) => ObjectBoxStore.open(directoryPath: directory.path),
          ),
        );
        expect(reopened.every((s) => identical(s, reopened.first)), isTrue);
        expect(
          reopened.first.screenshots.get(row.id)?.galleryAssetId,
          'test-asset',
        );
        await reopened.first.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
