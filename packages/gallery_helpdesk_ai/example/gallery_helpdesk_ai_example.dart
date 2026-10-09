import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

Future<void> main() async {
  final ai = GalleryHelpdeskAi();
  final screenshot = ai.analyze(
    const OcrScreenshot(
      screenshotId: 'receipt-1',
      blocks: [
        OcrBlock(id: 'block-1', text: 'GCash'),
        OcrBlock(id: 'block-2', text: 'Amount: PHP 500'),
        OcrBlock(id: 'block-3', text: 'Reference No: R-123456'),
        OcrBlock(id: 'block-4', text: 'Transaction successful'),
      ],
    ),
  );
  final answer = await ai.answer('Find my GCash receipt for PHP 500', [
    screenshot,
  ]);
  print(answer.text);
}
