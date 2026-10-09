import 'models.dart';

class ScreenshotClassifier {
  static final RegExp _gcashPattern = RegExp(
    r'\bg\s*cash\b',
    caseSensitive: false,
  );
  static final RegExp _receiptClues = RegExp(
    r'\b(reference\s*(?:no|number)|ref\s*(?:no|#)|transaction\s*(?:id|no|date)|'
    r'amount|cash\s*(?:in|out)|sent\s+to|received\s+from|payment\s+successful|'
    r'transaction\s+successful)\b',
    caseSensitive: false,
  );
  static final RegExp _orderClues = RegExp(
    r'\b(order\s*(?:id|no|number|#)|tracking\s*(?:id|no|number)|'
    r'order\s+placed|ship(?:ped|ping)?|delivery|deliver(?:ed|y))\b',
    caseSensitive: false,
  );
  static final RegExp _announcementClues = RegExp(
    r'\b(announcement|dear\s+students?|deadline|due\s+date|submit\s+by|'
    r'submission\s+date|subject|proposal|assignment|class\s+notice)\b',
    caseSensitive: false,
  );
  static final RegExp _explicitOrderId = RegExp(
    r'\border\s*(?:id|no\.?|number|#)\b',
    caseSensitive: false,
  );

  HelpdeskCategory classify(List<OcrBlock> blocks) {
    final text = blocks.map((block) => block.text).join('\n').trim();
    if (text.isEmpty) return HelpdeskCategory.unknown;

    final gcashScore =
        (_gcashPattern.hasMatch(text) ? 3 : 0) +
        _receiptClues.allMatches(text).length;
    final orderScore =
        (_explicitOrderId.hasMatch(text) ? 3 : 0) +
        _orderClues.allMatches(text).length;
    final announcementScore = _announcementClues
        .allMatches(text)
        .fold<int>(
          0,
          (score, match) =>
              score + (match.group(1)!.toLowerCase() == 'announcement' ? 3 : 1),
        );

    final scores = <HelpdeskCategory, int>{
      HelpdeskCategory.gcashReceipt: gcashScore,
      HelpdeskCategory.order: orderScore,
      HelpdeskCategory.announcement: announcementScore,
    };
    final topScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (topScore < 2) return HelpdeskCategory.other;

    final leaders = scores.entries
        .where((entry) => entry.value == topScore)
        .toList();
    if (leaders.length != 1) return HelpdeskCategory.unknown;
    return leaders.single.key;
  }
}
