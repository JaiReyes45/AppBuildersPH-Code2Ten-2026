import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  final ai = GalleryHelpdeskAi();
  final card = ai.analyze(
    const OcrScreenshot(
      screenshotId: 'card',
      blocks: [OcrBlock(id: 'name', text: 'Charizard HP 180 Flame Tail')],
    ),
  );
  test('screenshit request ignores misspelled scaffolding and generic card context', () async {
    expect(
      (await ai.answer('screenshit of charizard card', [
        card,
      ])).sources.single.screenshot.screenshotId,
      'card',
    );
  });
  test('transposed name returns a labeled possible match', () async {
    final result = await ai.answer('screenshot of charziard card', [card]);
    expect(result.sources.single.isApproximate, isTrue);
    expect(result.needsClarification, isTrue);
    expect(result.sources.single.matchingBlockIds, ['name']);
  });
  test('unrelated words and altered numbers are not fuzzy matches', () async {
    expect((await ai.answer('Blastoise', [card])).sources, isEmpty);
    expect((await ai.answer('Charizard 181', [card])).sources, isEmpty);
  });
  test('quoted spelling and alpha numeric identifiers stay exact', () {
    expect(ai.parseQuery('find "screenshit"').requiredPhrases, ['screenshit']);
    expect(
      ai.parseQuery('reference number RECIEPT123').exactIdentifier,
      'RECIEPT123',
    );
  });
}
