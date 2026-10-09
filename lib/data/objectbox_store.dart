import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';
import 'objectbox_entities.dart';

class ObjectBoxStore {
  ObjectBoxStore(this.store);

  final Store store;

  static final Map<String, Future<ObjectBoxStore>> _opening = {};
  static Future<ObjectBoxStore> open({String? directoryPath}) async {
    final path =
        directoryPath ??
        '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}objectbox';
    final directory = Directory(path).absolute;
    final key = directory.path;
    final existing = _opening[key];
    if (existing != null) {
      final instance = await existing;
      if (!instance.store.isClosed()) return instance;
      if (!identical(_opening[key], existing)) return open(directoryPath: key);
      _opening.remove(key);
    }
    final future = _openDirectory(directory);
    _opening[key] = future;
    try {
      return await future;
    } catch (_) {
      _opening.remove(key);
      rethrow;
    }
  }

  static Future<ObjectBoxStore> _openDirectory(Directory directory) async {
    await directory.create(recursive: true);
    // Hot restart can leave a native store alive after Dart statics reset.
    final store = Store.isOpen(directory.path)
        ? Store.attach(getObjectBoxModel(), directory.path)
        : await openStore(directory: directory.path);
    return ObjectBoxStore(store);
  }

  Box<IndexedScreenshot> get screenshots => store.box<IndexedScreenshot>();
  Box<ScanProgressRow> get progress => store.box<ScanProgressRow>();
  Box<ScanCoverage> get coverage => store.box<ScanCoverage>();

  Future<void> close() async => store.close();
}
