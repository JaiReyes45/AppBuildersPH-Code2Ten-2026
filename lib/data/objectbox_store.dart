import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';
import 'objectbox_entities.dart';

class ObjectBoxStore {
  ObjectBoxStore(this.store);

  final Store store;

  static Future<ObjectBoxStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}objectbox',
    );
    await directory.create(recursive: true);
    return ObjectBoxStore(await openStore(directory: directory.path));
  }

  Box<IndexedScreenshot> get screenshots => store.box<IndexedScreenshot>();
  Box<ScanProgressRow> get progress => store.box<ScanProgressRow>();
  Box<ScanCoverage> get coverage => store.box<ScanCoverage>();

  Future<void> close() async => store.close();
}
