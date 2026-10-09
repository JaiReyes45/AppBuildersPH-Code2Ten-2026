import 'models.dart';

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
    'deadline',
    'due',
    'announcement',
    'announcements',
    'student',
    'students',
  };

  HelpdeskQuery parse(String text) {
    final lower = text.toLowerCase();
    final identifierMatch =
        _referencePattern.firstMatch(text) ??
        _transactionIdPattern.firstMatch(text);
    final orderMatch = _orderPattern.firstMatch(text);
    final amountMatch = _amountPattern.firstMatch(text);
    final amountValue = amountMatch?.group(1) ?? amountMatch?.group(2);
    final amount = amountValue == null ? null : _normalizeAmount(amountValue);

    final exactIdentifier = identifierMatch?.group(1) ?? orderMatch?.group(1);
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
            .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 1 && !_ignoredWords.contains(word))
            .toSet()
            .toList()
          ..sort();

    return HelpdeskQuery(
      originalText: text,
      intent: intent,
      keywords: List.unmodifiable(keywords),
      category: category,
      amount: amount,
      exactIdentifier: exactIdentifier,
      exactIdentifierType: exactIdentifierType,
    );
  }

  static String _normalizeAmount(String value) {
    final amount = value.replaceAll(',', '');
    if (!amount.contains('.')) return '$amount.00';
    final decimalDigits = amount.length - amount.lastIndexOf('.') - 1;
    return decimalDigits == 1 ? '${amount}0' : amount;
  }
}
