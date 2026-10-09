/// Normalize currency words without rewriting hyphenated/underscored IDs.
String normalizeAmountWords(String query) => query.replaceAllMapped(
  RegExp(
    r'(^|[^a-z0-9_-])(pesos?|piso)(?=$|[^a-z0-9_-])',
    caseSensitive: false,
  ),
  (match) => '${match[1]}PHP',
);
