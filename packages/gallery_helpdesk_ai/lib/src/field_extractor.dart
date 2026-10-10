import 'models.dart';
import 'normalization.dart';

class FieldExtractor {
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
    '\\b(?:due(?:\\s+date)?|deadline|submit\\b.{0,80}?\\bby|submission\\s+date)'
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
  static final RegExp _referenceLabelOnlyPattern = RegExp(
    r'^\s*(?:reference|ref)(?:\s*(?:no\.?|number|#))?\s*[:#-]?\s*$',
    caseSensitive: false,
  );
  static final RegExp _orderLabelOnlyPattern = RegExp(
    r'^\s*order\s*(?:id|no\.?|number|#)\s*[:#-]?\s*$',
    caseSensitive: false,
  );
  static final RegExp _identifierValuePattern = RegExp(
    r'^\s*([A-Z0-9][A-Z0-9-]{3,})\s*$',
    caseSensitive: false,
  );

  List<ExtractedField> extract(List<OcrBlock> blocks) {
    final fields = <ExtractedField>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      _addMatches(
        fields,
        block,
        amountWithCurrencyPattern,
        ExtractedFieldType.amount,
        normalize: normalizeAmount,
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
      if (index + 1 < blocks.length) {
        _addSplitIdentifier(
          fields,
          block,
          blocks[index + 1],
          _referenceLabelOnlyPattern,
          ExtractedFieldType.referenceNumber,
        );
        _addSplitIdentifier(
          fields,
          block,
          blocks[index + 1],
          _orderLabelOnlyPattern,
          ExtractedFieldType.orderNumber,
        );
      }
    }
    return List.unmodifiable(_deduplicate(fields));
  }

  void _addSplitIdentifier(
    List<ExtractedField> target,
    OcrBlock labelBlock,
    OcrBlock valueBlock,
    RegExp labelPattern,
    ExtractedFieldType type,
  ) {
    if (!labelPattern.hasMatch(labelBlock.text)) return;
    final labelBox = labelBlock.boundingBox;
    final valueBox = valueBlock.boundingBox;
    if (labelBox != null && valueBox != null) {
      final height = labelBox.height > valueBox.height
          ? labelBox.height
          : valueBox.height;
      final sameRow =
          (labelBox.top - valueBox.top).abs() <= height &&
          valueBox.left >= labelBox.left &&
          valueBox.left - (labelBox.left + labelBox.width) <= height * 8;
      final nextRow =
          valueBox.top >= labelBox.top &&
          valueBox.top - (labelBox.top + labelBox.height) <= height * 3 &&
          valueBox.left < labelBox.left + labelBox.width &&
          valueBox.left + valueBox.width > labelBox.left;
      if (!sameRow && !nextRow) return;
    }
    final match = _identifierValuePattern.firstMatch(valueBlock.text);
    final value = match?.group(1);
    if (value == null) return;
    target.add(
      ExtractedField(
        type: type,
        rawValue: value,
        normalizedValue: value.toLowerCase(),
        sourceBlockIds: [labelBlock.id, valueBlock.id],
      ),
    );
  }

  void _addMatches(
    List<ExtractedField> target,
    OcrBlock block,
    RegExp pattern,
    ExtractedFieldType type, {
    String Function(String value)? normalize,
  }) {
    for (final match in pattern.allMatches(block.text)) {
      final value = _firstCapturedValue(match) ?? match.group(0)!.trim();
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

  String? _firstCapturedValue(RegExpMatch match) {
    for (var group = 1; group <= match.groupCount; group++) {
      final value = match.group(group)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
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
}
