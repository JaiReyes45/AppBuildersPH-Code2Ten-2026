import 'models.dart';

class FieldExtractor {
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
  static final RegExp _orderNumberPattern = RegExp(
    r'\border\s*(?:id|no\.?|number|#)\s*[:#-]?\s*([A-Z0-9][A-Z0-9-]{3,})\b',
    caseSensitive: false,
  );
  static const _date =
      r'(?:'
      r'\d{4}-\d{1,2}-\d{1,2}'
      r'|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'
      r'|(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
      r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|'
      r'Dec(?:ember)?)\s+\d{1,2}(?:,?\s+\d{4})?'
      r'|\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|'
      r'Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|'
      r'Nov(?:ember)?|Dec(?:ember)?)(?:\s+\d{4})?)';
  static final RegExp _deadlinePattern = RegExp(
    '\\b(?:due(?:\\s+date)?|deadline|submit\\s+by|submission\\s+date)'
    '\\s*(?::|-|is|on|by)?\\s*($_date)',
    caseSensitive: false,
  );
  static final RegExp _transactionDatePattern = RegExp(
    '\\b(?:transaction\\s+date|date\\s+paid|paid\\s+on|date)'
    '\\s*:?\\s*($_date)',
    caseSensitive: false,
  );
  static final RegExp _titlePattern = RegExp(
    r'^\s*(?:subject|title)\s*:\s*(.+?)\s*$',
    caseSensitive: false,
  );
  static final RegExp _itemPattern = RegExp(
    r'^\s*(?:item|product)\s*:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  List<ExtractedField> extract(List<OcrBlock> blocks) {
    final fields = <ExtractedField>[];
    for (final block in blocks) {
      _addMatches(
        fields,
        block,
        _amountPattern,
        ExtractedFieldType.amount,
        normalize: _normalizeAmount,
      );
      _addMatches(
        fields,
        block,
        _referencePattern,
        ExtractedFieldType.referenceNumber,
      );
      _addMatches(
        fields,
        block,
        _transactionIdPattern,
        ExtractedFieldType.referenceNumber,
      );
      _addMatches(
        fields,
        block,
        _orderNumberPattern,
        ExtractedFieldType.orderNumber,
      );
      _addMatches(fields, block, _deadlinePattern, ExtractedFieldType.deadline);
      _addMatches(
        fields,
        block,
        _transactionDatePattern,
        ExtractedFieldType.transactionDate,
      );
      _addLabeledValue(fields, block, _titlePattern, ExtractedFieldType.title);
      _addLabeledValue(
        fields,
        block,
        _itemPattern,
        ExtractedFieldType.itemName,
      );
    }
    return List.unmodifiable(_deduplicate(fields));
  }

  void _addMatches(
    List<ExtractedField> target,
    OcrBlock block,
    RegExp pattern,
    ExtractedFieldType type, {
    String Function(String value)? normalize,
  }) {
    for (final match in pattern.allMatches(block.text)) {
      final value = match.groupCount > 0 && match.group(1) != null
          ? match.group(1)!.trim()
          : match.group(0)!.trim();
      target.add(
        ExtractedField(
          type: type,
          rawValue: type == ExtractedFieldType.amount
              ? match.group(0)!.trim()
              : value,
          normalizedValue: normalize?.call(value),
          sourceBlockIds: [block.id],
        ),
      );
    }
  }

  void _addLabeledValue(
    List<ExtractedField> target,
    OcrBlock block,
    RegExp pattern,
    ExtractedFieldType type,
  ) {
    final match = pattern.firstMatch(block.text);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      target.add(
        ExtractedField(
          type: type,
          rawValue: value,
          normalizedValue: value.toLowerCase(),
          sourceBlockIds: [block.id],
        ),
      );
    }
  }

  List<ExtractedField> _deduplicate(List<ExtractedField> fields) {
    final seen = <String>{};
    return fields.where((field) {
      final key = '${field.type.name}:${field.rawValue.toLowerCase()}';
      return seen.add(key);
    }).toList();
  }

  static String _normalizeAmount(String value) {
    final amount = value.replaceAll(',', '');
    if (!amount.contains('.')) return '$amount.00';
    final decimalDigits = amount.length - amount.lastIndexOf('.') - 1;
    return decimalDigits == 1 ? '${amount}0' : amount;
  }
}
