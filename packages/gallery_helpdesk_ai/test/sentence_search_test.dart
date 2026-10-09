import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  final ai = GalleryHelpdeskAi();
  AnalyzedScreenshot receipt(String id, String name) => ai.analyze(
    OcrScreenshot(
      screenshotId: id,
      blocks: [
        OcrBlock(
          id: '$id-text',
          text:
              'GCash\nPayment successful\nSent to $name\nAmount PHP 300.00\nReference No. ABC-12345',
        ),
      ],
    ),
  );
  test('conversational request preserves amount and recipient', () async {
    final query =
        'Could you show me the screenshot where I sent 300 pesos to Maria?';
    final parsed = ai.parseQuery(query);
    expect(parsed.amount, '300.00');
    expect(parsed.requiredPhrases, ['maria']);
    final answer = await ai.answer(query, [
      receipt('right', 'Maria'),
      receipt('wrong', 'Ana'),
    ]);
    expect(answer.sources.map((m) => m.screenshot.screenshotId), ['right']);
  });
  test('amount never overrides other requested details', () async {
    final answer = await ai.answer('GCash PHP 300 Maria', [
      receipt('wrong', 'Ana'),
    ]);
    expect(answer.sources, isEmpty);
  });
  test('whole words avoid matching Ana inside another name', () async {
    expect(
      (await ai.answer('GCash PHP 300 Ana', [
        receipt('wrong', 'Diana'),
      ])).sources,
      isEmpty,
    );
  });
  test('quoted phrases must be present', () async {
    expect(
      (await ai.answer('Find GCash PHP 300 "Maria Santos"', [
        receipt('wrong', 'Maria Cruz'),
      ])).sources,
      isEmpty,
    );
  });
  test('sentence scaffolding is not interpreted as an identifier', () {
    expect(
      ai
          .parseQuery('Could you find the order number for my headphones?')
          .exactIdentifier,
      isNull,
    );
  });
  test(
    'vague request does not return the entire gallery as an answer',
    () async {
      expect(
        (await ai.answer('Could you help me please?', [
          receipt('one', 'Maria'),
        ])).sources,
        isEmpty,
      );
    },
  );
  test('distant OCR label and value are not combined', () {
    final result = ai.analyze(
      const OcrScreenshot(
        screenshotId: 'one',
        blocks: [
          OcrBlock(
            id: 'label',
            text: 'Reference No.',
            boundingBox: OcrBoundingBox(
              left: 0,
              top: 0,
              width: 120,
              height: 20,
            ),
          ),
          OcrBlock(
            id: 'unrelated',
            text: '12345678',
            boundingBox: OcrBoundingBox(
              left: 0,
              top: 800,
              width: 120,
              height: 20,
            ),
          ),
        ],
      ),
    );
    expect(
      result.fields.where((f) => f.type == ExtractedFieldType.referenceNumber),
      isEmpty,
    );
  });
}
