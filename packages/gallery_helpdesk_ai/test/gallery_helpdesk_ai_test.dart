import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';
import 'package:test/test.dart';

void main() {
  group('GalleryHelpdeskAi', () {
    final pipeline = GalleryHelpdeskAi();

    test('classifies a receipt and extracts source-linked literal fields', () {
      final result = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'receipt-1',
          blocks: [
            OcrBlock(id: 'b1', text: 'GCash'),
            OcrBlock(id: 'b2', text: 'Amount: PHP 500.00'),
            OcrBlock(id: 'b3', text: 'Reference No: R-123456'),
            OcrBlock(id: 'b4', text: 'Transaction date: Oct 8, 2026'),
            OcrBlock(id: 'b5', text: 'Transaction successful'),
          ],
        ),
      );

      expect(result.category, HelpdeskCategory.gcashReceipt);
      final amount = result.fields.singleWhere(
        (field) => field.type == ExtractedFieldType.amount,
      );
      expect(amount.rawValue, 'PHP 500.00');
      expect(amount.normalizedValue, '500');
      expect(amount.sourceBlockIds, ['b2']);

      final reference = result.fields.singleWhere(
        (field) => field.type == ExtractedFieldType.referenceNumber,
      );
      expect(reference.rawValue, 'R-123456');
      expect(reference.sourceBlockIds, ['b3']);

      final date = result.fields.singleWhere(
        (field) => field.type == ExtractedFieldType.transactionDate,
      );
      expect(date.rawValue, 'Oct 8, 2026');
      expect(date.sourceBlockIds, ['b4']);
    });

    test(
      'normalizes currency suffix amounts without changing raw OCR text',
      () {
        final receipt = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'receipt-suffix',
            blocks: [
              OcrBlock(id: 's1', text: 'GCash payment successful'),
              OcrBlock(id: 's2', text: '500 PHP'),
            ],
          ),
        );
        final amount = receipt.fields.singleWhere(
          (field) => field.type == ExtractedFieldType.amount,
        );
        expect(amount.rawValue, '500 PHP');
        expect(amount.normalizedValue, '500');
        expect(pipeline.parseQuery('GCash receipt 500 PHP').amount, '500');
      },
    );

    test(
      'preserves provenance when an identifier label and value are split',
      () {
        final receipt = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'receipt-split',
            blocks: [
              OcrBlock(id: 'label', text: 'Reference No.'),
              OcrBlock(id: 'value', text: 'R-123456'),
            ],
          ),
        );
        final reference = receipt.fields.singleWhere(
          (field) => field.type == ExtractedFieldType.referenceNumber,
        );
        expect(reference.rawValue, 'R-123456');
        expect(reference.sourceBlockIds, ['label', 'value']);
      },
    );

    test('searching a split identifier cites both OCR blocks', () async {
      final receipt = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'receipt-split',
          blocks: [
            OcrBlock(id: 'g1', text: 'GCash transaction successful'),
            OcrBlock(id: 'g2', text: 'Reference No.'),
            OcrBlock(id: 'g3', text: 'R-123456'),
          ],
        ),
      );

      final answer = await pipeline.answer('What is the reference number?', [
        receipt,
      ]);

      expect(answer.sources, hasLength(1));
      expect(answer.sources.single.matchingBlockIds, containsAll(['g2', 'g3']));
    });

    test(
      'classifies order and announcement candidates without inventing data',
      () {
        final order = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'order-1',
            blocks: [
              OcrBlock(id: 'o1', text: 'Order No: ORD-90817'),
              OcrBlock(id: 'o2', text: 'Item: Headphones'),
              OcrBlock(id: 'o3', text: 'Delivery expected soon'),
            ],
          ),
        );
        expect(order.category, HelpdeskCategory.order);
        expect(
          order.fields
              .singleWhere(
                (field) => field.type == ExtractedFieldType.orderNumber,
              )
              .rawValue,
          'ORD-90817',
        );

        final announcement = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'announcement-1',
            blocks: [
              OcrBlock(id: 'a1', text: 'Title: Research Proposal'),
              OcrBlock(
                id: 'a2',
                text: 'Please submit your research proposal by October 15, 2026 at 5 PM.',
              ),
              OcrBlock(id: 'a3', text: 'Announcement for students'),
            ],
          ),
        );
        expect(announcement.category, HelpdeskCategory.announcement);
        expect(
          announcement.fields
              .singleWhere((field) => field.type == ExtractedFieldType.title)
              .rawValue,
          'Research Proposal',
        );
        expect(
          announcement.fields
              .singleWhere((field) => field.type == ExtractedFieldType.deadline)
              .rawValue,
          'October 15, 2026',
        );
      },
    );

    test('marks unreadable and unrelated content conservatively', () {
      expect(
        pipeline
            .analyze(const OcrScreenshot(screenshotId: 'empty', blocks: []))
            .category,
        HelpdeskCategory.unknown,
      );
      expect(
        pipeline
            .analyze(
              const OcrScreenshot(
                screenshotId: 'other',
                blocks: [OcrBlock(id: 'x1', text: 'A cat sitting on a chair')],
              ),
            )
            .category,
        HelpdeskCategory.other,
      );
    });

    test('does not interpret a field-name question as an exact identifier', () {
      final query = pipeline.parseQuery(
        'What is the reference number on this receipt?',
      );

      expect(query.intent, HelpdeskIntent.referenceLookup);
      expect(query.exactIdentifier, isNull);
    });

    test('promotes only standalone numeric queries to amount filters', () {
      for (final text in ['500', 'P500', '₱500']) {
        final query = pipeline.parseQuery(text);
        expect(query.amount, '500', reason: text);
        expect(query.keywords, isEmpty, reason: text);
      }

      final order = pipeline.parseQuery('order 500');
      expect(order.amount, isNull);
      expect(order.keywords, containsAll(['order', '500']));

      final gcash = pipeline.parseQuery('gcash 500');
      expect(gcash.amount, '500');
      expect(gcash.keywords, ['gcash']);
    });

    test('retrieves amount matches and cites the matching OCR block', () async {
      final receipt = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'receipt-1',
          blocks: [
            OcrBlock(id: 'r1', text: 'GCash'),
            OcrBlock(id: 'r2', text: 'Amount: PHP 500'),
            OcrBlock(id: 'r3', text: 'Reference No: R-123456'),
          ],
        ),
      );
      final otherReceipt = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'receipt-2',
          blocks: [
            OcrBlock(id: 's1', text: 'GCash'),
            OcrBlock(id: 's2', text: 'Amount: PHP 200'),
          ],
        ),
      );

      final answer = await pipeline.answer(
        'Find my GCash receipt for PHP 500',
        [otherReceipt, receipt],
      );

      expect(answer.sources, hasLength(1));
      expect(answer.sources.single.screenshot.screenshotId, 'receipt-1');
      expect(answer.sources.single.matchingBlockIds, contains('r2'));
      expect(answer.text, contains('not verified payment status'));
      expect(answer.text, contains('PHP 500'));
    });

    test('requires amount and identifier filters to both match', () async {
      final rightReceipt = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'right',
          blocks: [
            OcrBlock(id: 'r1', text: 'GCash payment successful'),
            OcrBlock(id: 'r2', text: '500 PHP'),
            OcrBlock(id: 'r3', text: 'Reference No: REF-55555'),
          ],
        ),
      );
      final amountOnly = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'amount-only',
          blocks: [
            OcrBlock(id: 'a1', text: 'GCash payment successful'),
            OcrBlock(id: 'a2', text: '500 PHP'),
            OcrBlock(id: 'a3', text: 'Reference No: REF-99999'),
          ],
        ),
      );
      final identifierOnly = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'identifier-only',
          blocks: [
            OcrBlock(id: 'i1', text: 'GCash payment successful'),
            OcrBlock(id: 'i2', text: '800 PHP'),
            OcrBlock(id: 'i3', text: 'Reference No: REF-55555'),
          ],
        ),
      );

      final answer = await pipeline.answer(
        'Find GCash reference number REF-55555 for PHP 500',
        [amountOnly, identifierOnly, rightReceipt],
      );

      expect(answer.sources, hasLength(1));
      expect(answer.sources.single.screenshot.screenshotId, 'right');
      expect(answer.sources.single.matchingBlockIds, containsAll(['r2', 'r3']));
    });

    test('rejects weak partial keyword matches', () async {
      final partial = pipeline.analyze(
        const OcrScreenshot(
          screenshotId: 'partial',
          blocks: [
            OcrBlock(id: 'p1', text: 'Class announcement'),
            OcrBlock(id: 'p2', text: 'Research deadline is October 15, 2026'),
          ],
        ),
      );

      final answer = await pipeline.answer(
        'When is the research proposal due?',
        [partial],
      );

      expect(answer.sources, isEmpty);
      expect(answer.text, contains('could not find matching evidence'));
    });

    test(
      'matches exact identifiers only and reports the supporting source',
      () async {
        final matching = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'order-1',
            blocks: [
              OcrBlock(id: 'o1', text: 'Order No: ORD-90817'),
              OcrBlock(id: 'o2', text: 'Item: Headphones'),
              OcrBlock(id: 'o3', text: 'Delivery expected'),
            ],
          ),
        );
        final different = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'order-2',
            blocks: [
              OcrBlock(id: 'd1', text: 'Order No: ORD-90818'),
              OcrBlock(id: 'd2', text: 'Item: Headphones'),
            ],
          ),
        );

        final answer = await pipeline.answer('Find order number: ORD-90817', [
          different,
          matching,
        ]);

        expect(answer.sources, hasLength(1));
        expect(answer.sources.single.screenshot.screenshotId, 'order-1');
        expect(answer.sources.single.matchingBlockIds, contains('o1'));
        expect(answer.text, contains('ORD-90817'));
      },
    );

    test(
      'retrieves an order by item text and cites its extracted number',
      () async {
        final order = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'order-1',
            blocks: [
              OcrBlock(id: 'o1', text: 'Order No: ORD-90817'),
              OcrBlock(id: 'o2', text: 'Item: Headphones'),
              OcrBlock(id: 'o3', text: 'Delivery expected soon'),
            ],
          ),
        );

        final answer = await pipeline.answer(
          'What is the order number for my headphones?',
          [order],
        );

        expect(answer.sources, hasLength(1));
        expect(
          answer.sources.single.matchingBlockIds,
          containsAll(['o1', 'o2']),
        );
        expect(answer.text, contains('ORD-90817'));
      },
    );

    test(
      'returns deadline candidates with title and deadline evidence',
      () async {
        final announcement = pipeline.analyze(
          const OcrScreenshot(
            screenshotId: 'announcement-1',
            blocks: [
              OcrBlock(id: 'a1', text: 'Title: Research Proposal'),
              OcrBlock(id: 'a2', text: 'Deadline: October 15, 2026'),
              OcrBlock(id: 'a3', text: 'Announcement for students'),
            ],
          ),
        );

        final answer = await pipeline.answer(
          'When is the research proposal due?',
          [announcement],
        );

        expect(answer.sources, hasLength(1));
        expect(
          answer.sources.single.matchingBlockIds,
          containsAll(['a1', 'a2']),
        );
        expect(answer.text, contains('October 15, 2026'));
        expect(answer.text, contains('Research Proposal'));
      },
    );

    test('returns a transparent no-evidence answer', () async {
      final answer = await pipeline.answer('Find my GCash receipt', const []);

      expect(answer.sources, isEmpty);
      expect(answer.needsClarification, isFalse);
      expect(answer.text, contains('could not find matching evidence'));
    });
  });
}
