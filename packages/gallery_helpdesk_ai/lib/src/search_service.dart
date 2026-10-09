import 'models.dart';

class SearchService {
  List<SearchMatch> search(
    HelpdeskQuery query,
    Iterable<AnalyzedScreenshot> screenshots,
  ) {
    final matches = <SearchMatch>[];
    for (final screenshot in screenshots) {
      if (query.category != null && screenshot.category != query.category) {
        continue;
      }

      final fieldMatches = _matchingFields(query, screenshot);
      if (query.exactIdentifier != null && fieldMatches.isEmpty) continue;
      if (query.amount != null &&
          !fieldMatches.any(
            (field) => field.type == ExtractedFieldType.amount,
          )) {
        continue;
      }

      final matchingBlocks = <String>{};
      var keywordHits = 0;
      for (final keyword in query.keywords) {
        final blocks = screenshot.blocks
            .where((block) => block.text.toLowerCase().contains(keyword))
            .toList();
        if (blocks.isNotEmpty) {
          keywordHits++;
          matchingBlocks.addAll(blocks.map((block) => block.id));
        }
      }

      final requiresKeywordHit =
          query.keywords.isNotEmpty &&
          query.amount == null &&
          query.exactIdentifier == null;
      if (requiresKeywordHit && keywordHits == 0) continue;

      final citedFields = <ExtractedField>[
        ...fieldMatches,
        ..._fieldsForAnswer(query.intent, screenshot.fields),
      ];
      for (final field in citedFields) {
        matchingBlocks.addAll(field.sourceBlockIds);
      }
      final rank =
          (query.category == screenshot.category ? 8 : 0) +
          (query.amount != null ? 20 : 0) +
          (query.exactIdentifier != null ? 100 : 0) +
          keywordHits;
      matches.add(
        SearchMatch(
          screenshot: screenshot,
          rank: rank,
          matchingBlockIds: List.unmodifiable(matchingBlocks),
        ),
      );
    }

    matches.sort((a, b) {
      final rankOrder = b.rank.compareTo(a.rank);
      return rankOrder != 0
          ? rankOrder
          : a.screenshot.screenshotId.compareTo(b.screenshot.screenshotId);
    });
    return List.unmodifiable(matches);
  }

  List<ExtractedField> _matchingFields(
    HelpdeskQuery query,
    AnalyzedScreenshot screenshot,
  ) {
    if (query.exactIdentifier != null) {
      final requiredType =
          query.exactIdentifierType == ExactIdentifierType.orderNumber
          ? ExtractedFieldType.orderNumber
          : ExtractedFieldType.referenceNumber;
      final exact = _normalizeIdentifier(query.exactIdentifier!);
      return screenshot.fields.where((field) {
        final value = field.normalizedValue ?? field.rawValue;
        return field.type == requiredType &&
            _normalizeIdentifier(value) == exact;
      }).toList();
    }

    if (query.amount != null) {
      return screenshot.fields.where((field) {
        if (field.type != ExtractedFieldType.amount) return false;
        final value = field.normalizedValue;
        return value != null && value == query.amount;
      }).toList();
    }
    return const [];
  }

  List<ExtractedField> _fieldsForAnswer(
    HelpdeskIntent intent,
    List<ExtractedField> fields,
  ) {
    final types = switch (intent) {
      HelpdeskIntent.receiptSearch => {
        ExtractedFieldType.amount,
        ExtractedFieldType.transactionDate,
        ExtractedFieldType.referenceNumber,
      },
      HelpdeskIntent.referenceLookup => {ExtractedFieldType.referenceNumber},
      HelpdeskIntent.orderNumberLookup => {
        ExtractedFieldType.orderNumber,
        ExtractedFieldType.itemName,
      },
      HelpdeskIntent.deadlineSearch => {
        ExtractedFieldType.deadline,
        ExtractedFieldType.title,
      },
      HelpdeskIntent.announcementSearch => {
        ExtractedFieldType.title,
        ExtractedFieldType.deadline,
      },
      HelpdeskIntent.generalSearch => <ExtractedFieldType>{},
    };
    return fields.where((field) => types.contains(field.type)).toList();
  }

  String _normalizeIdentifier(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
