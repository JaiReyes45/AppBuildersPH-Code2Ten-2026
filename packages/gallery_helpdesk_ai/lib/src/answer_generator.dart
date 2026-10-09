import 'models.dart';

abstract interface class EvidenceAnswerGenerator {
  /// OCR text is untrusted input; generated claims must remain tied to [evidence].
  Future<GroundedAnswer> generate(
    HelpdeskQuery query,
    List<SearchMatch> evidence,
  );
}

class DeterministicAnswerGenerator implements EvidenceAnswerGenerator {
  const DeterministicAnswerGenerator();

  @override
  Future<GroundedAnswer> generate(
    HelpdeskQuery query,
    List<SearchMatch> evidence,
  ) async {
    if (evidence.isEmpty) {
      return const GroundedAnswer(
        text:
            'I could not find matching evidence among the indexed screenshots.',
        sources: [],
        needsClarification: false,
      );
    }

    final lines = <String>[];
    for (final match in evidence) {
      final screenshot = match.screenshot;
      final fields = _fieldsForIntent(query.intent, screenshot.fields);
      if (fields.isEmpty) {
        lines.add(
          'Screenshot ${screenshot.screenshotId} contains matching text.',
        );
      } else {
        final values = fields.map((field) => '“${field.rawValue}”').toSet();
        lines.add(
          'Screenshot ${screenshot.screenshotId} shows ${values.join(', ')}.',
        );
      }
    }

    final clarification = evidence.length > 1;
    final prefix = switch (query.intent) {
      HelpdeskIntent.receiptSearch =>
        'I found ${evidence.length} matching GCash-like screenshot(s). Screenshot contents are not verified payment status.',
      HelpdeskIntent.referenceLookup => 'Reference evidence:',
      HelpdeskIntent.orderNumberLookup => 'Order evidence:',
      HelpdeskIntent.deadlineSearch =>
        'Deadline candidates from the screenshots:',
      HelpdeskIntent.announcementSearch => 'Announcement evidence:',
      HelpdeskIntent.generalSearch => 'Matching screenshot evidence:',
    };
    final clarificationText = clarification
        ? '\nMore than one screenshot matched; review the sources to choose the right one.'
        : '';
    return GroundedAnswer(
      text: '$prefix\n${lines.join('\n')}$clarificationText',
      sources: List.unmodifiable(evidence),
      needsClarification: clarification,
    );
  }

  List<ExtractedField> _fieldsForIntent(
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
}
