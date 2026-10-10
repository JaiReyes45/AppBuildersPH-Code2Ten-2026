import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  test('unicorn dragon does not match unrelated card OCR', () {
    final ai = GalleryHelpdeskAi();
    final screenshot = ai.analyze(
      const OcrScreenshot(
        screenshotId: 'whitecloak-card',
        blocks: [
          OcrBlock(id: 'b1', text: 'WHITECLOAK'),
          OcrBlock(id: 'b2', text: 'WHITECLOA'),
          OcrBlock(id: 'b3', text: 'charizard'),
        ],
      ),
    );
    final query = ai.parseQuery('unicorn dragon');

    expect(SearchService().search(query, [screenshot]), isEmpty);
  });

  test('charizard typo tolerance still finds the intended card', () {
    final ai = GalleryHelpdeskAi();
    final screenshot = ai.analyze(
      const OcrScreenshot(
        screenshotId: 'charizard-card',
        blocks: [OcrBlock(id: 'name', text: 'Charizard HP 180 Flame Tail')],
      ),
    );

    expect(
      SearchService().search(ai.parseQuery('charziard'), [screenshot]),
      hasLength(1),
    );
    expect(
      SearchService().search(ai.parseQuery('screenshit of charizard card'), [
        screenshot,
      ]),
      hasLength(1),
    );
  });
}
