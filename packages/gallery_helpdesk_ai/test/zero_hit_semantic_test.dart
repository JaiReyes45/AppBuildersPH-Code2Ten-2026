import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  final pipeline = GalleryHelpdeskAi();
  final diancie = pipeline.analyze(
    const OcrScreenshot(
      screenshotId: 'diancie',
      blocks: [OcrBlock(id: 'd1', text: 'Diancie EX trading card')],
    ),
  );
  final unrelated = pipeline.analyze(
    const OcrScreenshot(
      screenshotId: 'receipt',
      blocks: [OcrBlock(id: 'r1', text: 'GCash receipt PHP 1000')],
    ),
  );

  test('reports pokemon as zero-hit while Diancie has a corpus hit', () {
    final query = pipeline.parseQuery('pokemon card called Diancie');
    final zeroHits = SearchService().zeroHitTokens(query, [diancie]);

    expect(query.keywords, containsAll(['card', 'diancie', 'pokemon']));
    expect(zeroHits, contains('pokemon'));
    expect(zeroHits, isNot(contains('diancie')));
  });

  test('a semantic-style fallback can keep the Diancie candidate', () {
    final query = pipeline.parseQuery('pokemon card called Diancie');
    final zeroHits = SearchService().zeroHitTokens(query, [diancie]);
    final relaxed = HelpdeskQuery(
      originalText: query.originalText,
      intent: query.intent,
      keywords: query.keywords
          .where((word) => !zeroHits.contains(word))
          .toList(),
      category: query.category,
      amount: query.amount,
      exactIdentifier: query.exactIdentifier,
      exactIdentifierType: query.exactIdentifierType,
      requiredPhrases: query.requiredPhrases,
    );

    expect(SearchService().search(relaxed, [diancie]), hasLength(1));
    expect(
      SearchService().search(relaxed, [diancie]).single.screenshot.screenshotId,
      'diancie',
    );
  });

  test('all-zero-hit content produces no keyword matches without looping', () {
    final query = pipeline.parseQuery('unicorn dragon');
    final service = SearchService();

    expect(
      service.zeroHitTokens(query, [diancie, unrelated]),
      containsAll(['dragon', 'unicorn']),
    );
    expect(service.search(query, [diancie, unrelated]), isEmpty);
  });

  test('a context-word hit cannot satisfy a missing content token', () {
    final query = pipeline.parseQuery('diancie card');
    final cardOnly = pipeline.analyze(
      const OcrScreenshot(
        screenshotId: 'card-only',
        blocks: [OcrBlock(id: 'c1', text: 'Credit card declined')],
      ),
    );

    expect(SearchService().search(query, [cardOnly]), isEmpty);
  });
}
