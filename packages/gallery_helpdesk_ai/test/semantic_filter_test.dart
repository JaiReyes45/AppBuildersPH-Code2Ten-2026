import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  test('semantic constraints exclude receipts with a different amount', () {
    final ai = GalleryHelpdeskAi();
    AnalyzedScreenshot receipt(String id, String amount) => ai.analyze(
      OcrScreenshot(
        screenshotId: id,
        blocks: [
          const OcrBlock(id: 'context', text: 'GCash payment successful'),
          OcrBlock(id: 'amount', text: amount),
        ],
      ),
    );

    final parsed = ai.parseQuery('GCash 500');
    expect(parsed.amount, '500');
    final semanticConstraints = HelpdeskQuery(
      originalText: parsed.originalText,
      intent: parsed.intent,
      keywords: const [],
      category: parsed.category,
      amount: parsed.amount,
      exactIdentifier: parsed.exactIdentifier,
      exactIdentifierType: parsed.exactIdentifierType,
      requiredPhrases: parsed.requiredPhrases,
    );

    final matches = SearchService().search(semanticConstraints, [
      receipt('500', 'P500'),
      receipt('1500', '₱1,500'),
      receipt('2500', 'PHP 2,500.00'),
    ], allowUnconstrained: true);

    expect(matches.map((match) => match.screenshot.screenshotId), ['500']);
  });
}
