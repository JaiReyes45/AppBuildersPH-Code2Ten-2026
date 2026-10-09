enum HelpdeskCategory { gcashReceipt, order, announcement, other, unknown }

enum ExtractedFieldType {
  amount,
  referenceNumber,
  orderNumber,
  transactionDate,
  deadline,
  title,
  itemName,
}

enum HelpdeskIntent {
  receiptSearch,
  referenceLookup,
  orderNumberLookup,
  deadlineSearch,
  announcementSearch,
  generalSearch,
}

enum ExactIdentifierType { referenceNumber, orderNumber }

class OcrBoundingBox {
  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class OcrBlock {
  const OcrBlock({required this.id, required this.text, this.boundingBox});

  final String id;
  final String text;
  final OcrBoundingBox? boundingBox;
}

class OcrScreenshot {
  const OcrScreenshot({required this.screenshotId, required this.blocks});

  final String screenshotId;
  final List<OcrBlock> blocks;
}

class ExtractedField {
  const ExtractedField({
    required this.type,
    required this.rawValue,
    required this.sourceBlockIds,
    this.normalizedValue,
  });

  final ExtractedFieldType type;
  final String rawValue;
  final String? normalizedValue;
  final List<String> sourceBlockIds;
}

class AnalyzedScreenshot {
  const AnalyzedScreenshot({
    required this.screenshotId,
    required this.category,
    required this.blocks,
    required this.fields,
  });

  final String screenshotId;
  final HelpdeskCategory category;
  final List<OcrBlock> blocks;
  final List<ExtractedField> fields;

  String get recognizedText => blocks.map((block) => block.text).join('\n');
}

class HelpdeskQuery {
  const HelpdeskQuery({
    required this.originalText,
    required this.intent,
    required this.keywords,
    this.category,
    this.amount,
    this.exactIdentifier,
    this.exactIdentifierType,
  });

  final String originalText;
  final HelpdeskIntent intent;
  final List<String> keywords;
  final HelpdeskCategory? category;
  final String? amount;
  final String? exactIdentifier;
  final ExactIdentifierType? exactIdentifierType;
}

class SearchMatch {
  const SearchMatch({
    required this.screenshot,
    required this.rank,
    required this.matchingBlockIds,
  });

  final AnalyzedScreenshot screenshot;

  /// An internal ordering value, not a probability or confidence estimate.
  final int rank;
  final List<String> matchingBlockIds;
}

class GroundedAnswer {
  const GroundedAnswer({
    required this.text,
    required this.sources,
    required this.needsClarification,
  });

  final String text;
  final List<SearchMatch> sources;
  final bool needsClarification;
}
