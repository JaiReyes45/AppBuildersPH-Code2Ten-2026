import 'models.dart';
import 'typo_matching.dart';

class HelpdeskQueryParser {
  static final RegExp _amountPattern = RegExp(
    r'(?:\bPHP\b|\bP\b|₱)\s*([\d,]+(?:\.\d{1,2})?)|\b([\d,]+(?:\.\d{1,2})?)\s*(?:PHP\b|₱)',
    caseSensitive: false,
  );
  static final RegExp _referencePattern = RegExp(
    r'\b(?:reference|ref)(?:\s*(?:no\.?|number|#)\s*[:#-]?\s*|[:#-]\s*)([A-Z0-9][A-Z0-9-]{3,})\b',
    caseSensitive: false,
  );
  static final RegExp _transactionIdPattern = RegExp(
    r'\btransaction\s*(?:id|no\.?|number)\s*[:#-]?\s*([A-Z0-9][A-Z0-9-]{3,})\b',
    caseSensitive: false,
  );
  static final RegExp _orderPattern = RegExp(
    r'\border\s*(?:id|no\.?|number|#)\s*[:#-]?\s*([A-Z0-9][A-Z0-9-]{3,})\b',
    caseSensitive: false,
  );

  static const _ignoredWords = {
    'can',
    'could',
    'would',
    'you',
    'your',
    'have',
    'has',
    'had',
    'was',
    'were',
    'that',
    'there',
    'then',
    'need',
    'want',
    'looking',
    'look',
    'get',
    'locate',
    'screenshot',
    'screenshots',
    'photo',
    'photos',
    'image',
    'images',
    'picture',
    'pictures',
    'saved',
    'screenshotted',
    'sent',
    'send',
    'paid',
    'pay',
    'transferred',
    'using',
    'via',
    'through',
    'pesos',
    'peso',
    'php',
    'called',
    'a',
    'an',
    'and',
    'for',
    'find',
    'from',
    'give',
    'help',
    'i',
    'is',
    'it',
    'me',
    'my',
    'of',
    'on',
    'please',
    'show',
    'the',
    'this',
    'to',
    'what',
    'when',
    'where',
    'which',
    'who',
    'with',
    'about',
    'gcash',
    'receipt',
    'receipts',
    'order',
    'orders',
    'number',
    'reference',
    'ref',
    'no',
    'id',
    'transaction',
    'deadline',
    'due',
    'announcement',
    'announcements',
    'student',
    'students',
  };

  HelpdeskQuery parse(String text) {
    text = normalizeRequestTypos(text);
    text = text.replaceAll(
      RegExp(r'\b(pesos?)\b', caseSensitive: false),
      'PHP',
    );
    final lower = text.toLowerCase();
    final phrases = RegExp(r'"([^"\n]+)"')
        .allMatches(text)
        .map((m) => m[1]!.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final recipient = RegExp(
      r'\b(?:sent|send|paid|pay|transferred|transfer)\b.*?\bto\s+([a-z]+(?:\s+[a-z]+)?)(?=\s+(?:for|via|using|on|through)|[?.!]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (recipient != null) phrases.add(recipient[1]!.toLowerCase().trim());
    final identifierMatch =
        _referencePattern.firstMatch(text) ??
        _transactionIdPattern.firstMatch(text);
    final orderMatch = _orderPattern.firstMatch(text);
    final amountMatch = _amountPattern.firstMatch(text);
    final amountValue = amountMatch?.group(1) ?? amountMatch?.group(2);
    final amount = amountValue == null ? null : _normalizeAmount(amountValue);

    final candidate = identifierMatch?.group(1) ?? orderMatch?.group(1);
    final exactIdentifier =
        candidate != null && !_ignoredWords.contains(candidate.toLowerCase())
        ? candidate
        : null;
    final exactIdentifierType = identifierMatch != null
        ? ExactIdentifierType.referenceNumber
        : orderMatch != null
        ? ExactIdentifierType.orderNumber
        : null;

    final isReferenceLookup =
        lower.contains('reference') || RegExp(r'\bref\b').hasMatch(lower);
    final isOrderLookup =
        lower.contains('order') ||
        lower.contains('headphone') ||
        lower.contains('product') ||
        lower.contains('item');
    final isDeadlineSearch =
        lower.contains('deadline') ||
        lower.contains('due date') ||
        lower.contains('when is') ||
        lower.contains('submit by');
    final isAnnouncementSearch =
        lower.contains('announcement') || lower.contains('student notice');
    final isReceiptSearch =
        lower.contains('gcash') ||
        lower.contains('receipt') ||
        amount != null && lower.contains('php');

    final intent = isReferenceLookup
        ? HelpdeskIntent.referenceLookup
        : isOrderLookup
        ? HelpdeskIntent.orderNumberLookup
        : isDeadlineSearch
        ? HelpdeskIntent.deadlineSearch
        : isAnnouncementSearch
        ? HelpdeskIntent.announcementSearch
        : isReceiptSearch
        ? HelpdeskIntent.receiptSearch
        : HelpdeskIntent.generalSearch;
    final category = switch (intent) {
      HelpdeskIntent.referenceLookup ||
      HelpdeskIntent.receiptSearch => HelpdeskCategory.gcashReceipt,
      HelpdeskIntent.orderNumberLookup => HelpdeskCategory.order,
      HelpdeskIntent.deadlineSearch ||
      HelpdeskIntent.announcementSearch => HelpdeskCategory.announcement,
      HelpdeskIntent.generalSearch => null,
    };

    final keywords =
        text
            .toLowerCase()
            .replaceAll(_amountPattern, ' ')
            .replaceAll(
              exactIdentifier == null ? RegExp(r'(?!)') : _referencePattern,
              ' ',
            )
            .replaceAll(
              exactIdentifier == null ? RegExp(r'(?!)') : _transactionIdPattern,
              ' ',
            )
            .replaceAll(
              exactIdentifier == null ? RegExp(r'(?!)') : _orderPattern,
              ' ',
            )
            .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 1 && !_ignoredWords.contains(word))
            .toSet()
            .toList()
          ..sort();

    if (keywords.length > 1) {
      keywords.removeWhere((w) => w == 'card' || w == 'cards');
    }
    return HelpdeskQuery(
      originalText: text,
      intent: intent,
      keywords: List.unmodifiable(keywords),
      category: category,
      amount: amount,
      exactIdentifier: exactIdentifier,
      exactIdentifierType: exactIdentifierType,
      requiredPhrases: List.unmodifiable(phrases),
    );
  }

  static String _normalizeAmount(String value) {
    final amount = value.replaceAll(',', '');
    if (!amount.contains('.')) return '$amount.00';
    final decimalDigits = amount.length - amount.lastIndexOf('.') - 1;
    return decimalDigits == 1 ? '${amount}0' : amount;
  }
}
