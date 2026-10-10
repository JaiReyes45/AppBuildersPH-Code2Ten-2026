final RegExp amountWithCurrencyPattern = RegExp(
  r'(?:\bPHP\b|(?<![A-Za-z])P(?=\s*[\d,])|₱)\s*([\d,]+(?:\.\d{1,2})?)|\b([\d,]+(?:\.\d{1,2})?)\s*(?:\bPHP\b|₱)',
  caseSensitive: false,
);

String normalizeAmount(String value) {
  var amount = value.trim();
  amount = amount.replaceAll(RegExp(r'\bPHP\b', caseSensitive: false), '');
  amount = amount.replaceAll('₱', '');
  amount = amount.replaceFirst(
    RegExp(r'^\s*P(?=\s*[\d,])', caseSensitive: false),
    '',
  );
  amount = amount.replaceFirst(RegExp(r'P\s*$', caseSensitive: false), '');
  amount = amount.replaceAll(',', '').replaceAll(RegExp(r'\s+'), '');

  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(amount);
  if (match == null) return amount;

  final whole = match.group(1)!;
  var decimals = match.group(2) ?? '';
  if (decimals.length > 2) decimals = decimals.substring(0, 2);
  decimals = decimals.replaceFirst(RegExp(r'0+$'), '');
  return decimals.isEmpty ? whole : '$whole.$decimals';
}
