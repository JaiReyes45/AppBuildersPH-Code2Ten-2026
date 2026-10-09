import 'models.dart';
import 'typo_matching.dart';

class SearchService {
  List<SearchMatch> search(
    HelpdeskQuery query,
    Iterable<AnalyzedScreenshot> screenshots, {
    bool allowUnconstrained = false,
  }) {
    if (!allowUnconstrained &&
        query.keywords.isEmpty &&
        query.category == null &&
        query.amount == null &&
        query.exactIdentifier == null &&
        query.requiredPhrases.isEmpty) {
      return [];
    }
    final matches = <SearchMatch>[];
    for (final screenshot in screenshots) {
      if (query.category != null && screenshot.category != query.category) {
        continue;
      }

      final normalizedText = screenshot.recognizedText.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (!query.requiredPhrases.every(
        (phrase) =>
            RegExp('(?<![a-z0-9])${RegExp.escape(phrase)}(?![a-z0-9])')
                .hasMatch(normalizedText),
      )) {
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
      var approximate = false;
      for (final keyword in query.keywords) {
        var blocks = screenshot.blocks
            .where(
              (block) =>
                  RegExp('(?<![a-z0-9])${RegExp.escape(keyword)}(?![a-z0-9])')
                      .hasMatch(block.text.toLowerCase()),
            )
            .toList();
        if (blocks.isEmpty) {
          blocks = screenshot.blocks
              .where(
                (block) =>
                    RegExp(r'[a-z0-9]+')
                        .allMatches(block.text.toLowerCase())
                        .any((m) => nearWord(keyword, m[0]!)),
              )
              .toList();
          if (blocks.isNotEmpty) approximate = true;
        }
        if (blocks.isNotEmpty) {
          keywordHits++;
          matchingBlocks.addAll(blocks.map((block) => block.id));
        }
      }

      // Exact amounts/IDs do not cancel the remaining request details.
      if (query.keywords.isNotEmpty && keywordHits < query.keywords.length) {
        continue;
      }

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
          keywordHits -
          (approximate ? 1 : 0);
      matches.add(
        SearchMatch(
          screenshot: screenshot,
          rank: rank,
          isApproximate: approximate,
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
    final matching = <ExtractedField>[];
    if (query.exactIdentifier != null) {
      final requiredType =
          query.exactIdentifierType == ExactIdentifierType.orderNumber
          ? ExtractedFieldType.orderNumber
          : ExtractedFieldType.referenceNumber;
      final exact = _normalizeIdentifier(query.exactIdentifier!);
      final exactMatches = screenshot.fields.where((field) {
        final value = field.normalizedValue ?? field.rawValue;
        return field.type == requiredType &&
            _normalizeIdentifier(value) == exact;
      }).toList();
      if (exactMatches.isEmpty) return const [];
      matching.addAll(exactMatches);
    }

    if (query.amount != null) {
      final amountMatches = screenshot.fields.where((field) {
        if (field.type != ExtractedFieldType.amount) return false;
        final value = field.normalizedValue;
        return value != null && value == query.amount;
      }).toList();
      if (amountMatches.isEmpty) return const [];
      matching.addAll(amountMatches);
    }
    return matching;
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
