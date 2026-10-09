import 'dart:io';

import 'package:gallery_helpdesk/gallery_storage.dart';

import 'package:gallery_helpdesk/scan_timings.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gallery_helpdesk/gallery_asset_source.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';
import 'package:gallery_helpdesk/local_embedder.dart';
import 'package:gallery_helpdesk/main.dart';
import 'package:gallery_helpdesk/semantic_search.dart';
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

// Native diagnostic entry point. Reports counts/errors, never image/OCR content.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Checking local gallery services…')),
      ),
    ),
  );
  final scanner = GalleryScanner();
  try {
    final storage = await Future.wait([
      createGalleryStorage(),
      createGalleryStorage(),
    ]);
    if (!identical(storage[0], storage[1])) {
      throw StateError('Storage startup was not shared');
    }
    debugPrint('CHECK concurrent storage reuse OK');
    await scanner.initialize();
    debugPrint(
      'CHECK storage OK records=${scanner.records.length} failed=${scanner.failedCount}',
    );
    final source = GalleryAssetSource();
    final allowed = await source.requestPermission();
    debugPrint('CHECK permission=$allowed limited=${source.limitedAccess}');
    if (allowed) {
      final assets = await source.page(page: 0, size: 2);
      debugPrint('CHECK gallery page=${assets.length}');
      for (final asset in assets) {
        await scanner.scanSingleAsset(asset);
        final record = scanner.records.firstWhere((r) => r.assetId == asset.id);
        debugPrint(
          'CHECK OCR status=${record.status} blocks=${record.blocks.length}',
        );
        if (record.isFailed) {
          debugPrint('CHECK OCR error=${record.toJson()['error']}');
          throw StateError('Native OCR failed');
        }
        final codec = await ui.instantiateImageCodec(
          await File(record.imagePath!).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        debugPrint('CHECK saved image decodes=${frame.image.width > 0}');
        frame.image.dispose();
        codec.dispose();
      }
    }
    await for (final progress in scanner.scanUpTo(additionalCount: 2)) {
      debugPrint(
        'CHECK query scan status=${progress.status} processed=${progress.processed} failed=${progress.failed}',
      );
      if (progress.status == 'error') throw StateError(progress.message);
    }
    final model = MiniLmEmbedder();
    final vectors = await model.chunks('GCash receipt for PHP 300');
    debugPrint('CHECK model dimensions=${vectors.first.length}');
    final ai = GalleryHelpdeskAi();
    final documents = scanner.records
        .where((r) => !r.isFailed)
        .map(
          (r) => ai.analyze(
            OcrScreenshot(
              screenshotId: 'gallery-${r.assetId}',
              blocks: r.blocks
                  .map((b) => OcrBlock(id: b.id, text: b.text))
                  .toList(),
            ),
          ),
        )
        .toList();
    String? testQuery;
    for (final doc in documents) {
      for (final word in RegExp(
        r'[a-zA-Z]{5,}',
      ).allMatches(doc.recognizedText).map((m) => m.group(0)!)) {
        if (ai.parseQuery(word).keywords.isEmpty) continue;
        final answer = await ai.answer(word, documents);
        if (answer.sources.isNotEmpty) {
          testQuery = word;
          break;
        }
      }
      if (testQuery != null) break;
    }
    if (testQuery == null) {
      throw StateError('No searchable OCR token in diagnostic images');
    }
    debugPrint('CHECK keyword retrieval OK');
    final semantic = SemanticSearch(model, (await scanner.semanticStore())!);
    final related = await semantic.search(ai.parseQuery(testQuery), documents);
    if (semantic.unavailableReason != null) {
      throw StateError(semantic.unavailableReason!);
    }
    debugPrint(
      'CHECK ObjectBox semantic query completed candidates=${related.length}',
    );
    final selfVector = (await model.chunks(
      documents
          .firstWhere((d) => d.recognizedText.trim().isNotEmpty)
          .recognizedText,
    )).first;
    final neighbors = await (await scanner.semanticStore())!.nearestSemantic(
      selfVector,
      'chunk',
      model.version,
    );
    if (neighbors.isEmpty) {
      throw StateError('Native vector index returned no stored chunks');
    }
    debugPrint('CHECK native vector index self-retrieval OK');
    await semantic.close();
    ScanTimings.report();
    debugPrint('CHECK DONE');
    runApp(GalleryHelpdeskApp(scanner: scanner));
  } catch (error, stack) {
    debugPrint('CHECK FAILED $error\n$stack');
  }
}
