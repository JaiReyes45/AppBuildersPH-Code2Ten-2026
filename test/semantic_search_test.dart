import 'dart:convert';
import 'dart:io';

import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/local_embedder.dart';
import 'package:gallery_helpdesk/semantic_search.dart';
import 'package:gallery_helpdesk/semantic_store.dart';
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

class FakeEmbedder implements TextEmbedder {
  int calls = 0;
  bool fail = false;
  @override
  String get version => 'test-v1';
  @override
  Future<List<List<double>>> chunks(String text) async {
    calls++;
    if (fail) throw StateError('Unavailable model');
    return [
      text.contains('unrelated') ? [0.0, 1.0] : [1.0, 0.0],
    ];
  }

  @override
  Future<void> close() async {}
}

AnalyzedScreenshot doc(String id, String text) => GalleryHelpdeskAi().analyze(
  OcrScreenshot(
    screenshotId: id,
    blocks: [OcrBlock(id: '$id-block-0', text: text)],
  ),
);
void main() {
  test('semantic fallback requires a structured or literal OCR anchor', () {
    final ai = GalleryHelpdeskAi();
    final whitecloak = doc('whitecloak', 'WHITECLOAK WHITECLOA charizard');
    final diancie = doc('diancie', 'Diancie EX trading card');

    expect(
      hasSemanticSearchAnchor(ai.parseQuery('unicorn dragon'), [whitecloak]),
      isFalse,
    );
    expect(
      hasSemanticSearchAnchor(ai.parseQuery('pokemon card called Diancie'), [
        diancie,
      ]),
      isTrue,
    );
    expect(
      hasSemanticSearchAnchor(ai.parseQuery('GCash 500 PHP'), [whitecloak]),
      isTrue,
    );
  });

  test('scan-time retrieval does not backfill document embeddings', () async {
    final model = FakeEmbedder();
    final engine = SemanticSearch(model, MemorySemanticStore());
    final query = GalleryHelpdeskAi().parseQuery('academic work');
    final documents = [doc('one', 'Submit the thesis on Monday')];
    expect(
      await engine.search(query, documents, prepareMissing: false),
      isEmpty,
    );
    expect(
      model.calls,
      1,
      reason: 'Only the query is embedded during OCR scanning',
    );
    expect(await engine.search(query, documents), isNotEmpty);
    expect(model.calls, 2);
  });
  test('semantic similarity cannot override a named recipient', () async {
    final engine = SemanticSearch(FakeEmbedder(), MemorySemanticStore());
    final query = GalleryHelpdeskAi().parseQuery(
      'Could you find the screenshot where I sent 300 pesos to Maria?',
    );
    final found = await engine.search(query, [
      doc('right', 'GCash\nPayment successful\nSent to Maria\nPHP 300.00'),
      doc('wrong', 'GCash\nPayment successful\nSent to Ana\nPHP 300.00'),
    ]);
    expect(found.map((m) => m.screenshot.screenshotId), ['right']);
    expect(
      found.single.matchingBlockIds,
      isEmpty,
      reason: 'Document similarity must not claim every OCR line matched',
    );
  });
  test(
    'backfill is bounded and continues without repeating completed inference',
    () async {
      final model = FakeEmbedder();
      final engine = SemanticSearch(model, MemorySemanticStore());
      final docs = List.generate(45, (i) => doc('$i', 'unrelated picnic $i'));
      final query = GalleryHelpdeskAi().parseQuery('academic work');
      expect(await engine.search(query, docs), isEmpty);
      expect(model.calls, 41);
      expect(engine.pendingDocuments, 5);
      await engine.search(query, docs);
      expect(model.calls, 46);
      expect(engine.pendingDocuments, 0);
    },
  );

  test(
    'bundled tokenizer matches independently generated Hugging Face fixtures',
    () {
      final tokenizer =
          WordPieceTokenizer.fromTokenizerJsonString(
              File('assets/models/tokenizer.json').readAsStringSync(),
            )
            ..noPadding()
            ..noTruncation();
      final rows = jsonDecode(
        File('test/fixtures/minilm_reference.json').readAsStringSync(),
      ) as List;
      for (final row in rows) {
        expect(
          tokenizer.encode(row['text'] as String).ids,
          row['ids'],
          reason: row['text'] as String,
        );
      }
    },
  );
  test(
    'real quantized model vectors retrieve a paraphrase above unrelated text',
    () async {
      final rows = jsonDecode(
        File('test/fixtures/minilm_reference.json').readAsStringSync(),
      ) as List;
      final vectors = rows
          .map(
            (r) => (r['vector'] as List)
                .cast<num>()
                .map((n) => n.toDouble())
                .toList(),
          )
          .toList();
      expect(cosine(vectors[0], vectors[1]), greaterThan(.32));
      expect(cosine(vectors[0], vectors[3]), lessThan(.32));
      expect(cosine(vectors[4], vectors[2]), greaterThan(.32));
    },
  );

  test('masked mean pooling ignores padding and normalizes', () {
    expect(poolTokenEmbeddings([3, 4, 999, 999], [1, 0], dimensions: 2), [
      .6,
      .8,
    ]);
    expect(
      () => poolTokenEmbeddings([1], [1], dimensions: 2),
      throwsStateError,
    );
  });
  test('semantic candidates survive paraphrases; vectors persist and changed OCR reindexes', () async {
    final store = MemorySemanticStore();
    final model = FakeEmbedder();
    final engine = SemanticSearch(model, store);
    final docs = [
      doc('a', 'Submit the thesis on Monday'),
      doc('b', 'unrelated picnic'),
    ];
    final query = GalleryHelpdeskAi().parseQuery('academic work due');
    expect(
      (await engine.search(query, docs)).map((r) => r.screenshot.screenshotId),
      ['a'],
    );
    expect(model.calls, 3);
    await engine.search(query, docs);
    expect(model.calls, 3);
    final restartedModel = FakeEmbedder();
    final restarted = SemanticSearch(restartedModel, store);
    await restarted.search(query, docs);
    expect(restartedModel.calls, 1);
    await restarted.search(query, [
      doc('a', 'Updated submission instructions'),
    ]);
    expect(restartedModel.calls, 2);
  });
  test('learned preferences cannot override exact amount and reference constraints', () async {
    final engine = SemanticSearch(FakeEmbedder(), MemorySemanticStore());
    final receipt = doc(
      'a',
      'GCash payment successful\nPHP 500\nReference No. ABC12345',
    );
    await engine.remember('find my payment', receipt);
    final ai = GalleryHelpdeskAi();
    expect(
      await engine.search(ai.parseQuery('GCash PHP 500 ref XYZ99999'), [
        receipt,
      ]),
      isEmpty,
    );
    expect(
      await engine.search(ai.parseQuery('GCash 9999'), [receipt]),
      isEmpty,
    );
    expect(
      await engine.search(ai.parseQuery('reference XYZ99999'), [receipt]),
      isEmpty,
    );
    expect(
      await engine.search(ai.parseQuery('GCash 500'), [receipt]),
      isNotEmpty,
    );
    expect(await engine.search(ai.parseQuery('find my payment'), []), isEmpty);
  });
  test(
    'memory is opt-in, resettable, and invalidated when source changes',
    () async {
      final store = MemorySemanticStore();
      final engine = SemanticSearch(FakeEmbedder(), store);
      final item = doc('a', 'Meeting on Tuesday');
      await engine.search(GalleryHelpdeskAi().parseQuery('meeting'), [item]);
      expect(store.records.values.where((r) => r.kind == 'memory'), isEmpty);
      await engine.remember('meeting', item);
      expect(store.records.values.where((r) => r.kind == 'memory').length, 1);
      expect(
        await engine.search(GalleryHelpdeskAi().parseQuery('meeting'), [
          doc('a', 'unrelated picnic'),
        ]),
        isEmpty,
      );
      await engine.forget();
      expect(store.records, isEmpty);
    },
  );
  test(
    'cancelled backfill and missing model return no fabricated evidence',
    () async {
      final store = MemorySemanticStore();
      final model = FakeEmbedder();
      final engine = SemanticSearch(model, store);
      final query = GalleryHelpdeskAi().parseQuery('receipt');
      expect(
        await engine.search(query, [
          doc('a', 'payment'),
        ], cancelled: () => true),
        isEmpty,
      );
      expect(store.records, isEmpty);
      model.fail = true;
      expect(
        await engine.search(GalleryHelpdeskAi().parseQuery('another query'), [
          doc('a', 'payment'),
        ]),
        isEmpty,
      );
      expect(engine.unavailableReason, isNotNull);
    },
  );
}
