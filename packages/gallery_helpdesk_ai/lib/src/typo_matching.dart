/// One insertion, deletion, substitution or adjacent transposition.
/// Never relax digits, IDs, short words, quoted phrases or recipient constraints.
bool nearWord(String a, String b) {
  if (a == b) return true;
  if (a.length < 5 ||
      b.length < 5 ||
      !RegExp(r'^[a-z]+$').hasMatch(a) ||
      !RegExp(r'^[a-z]+$').hasMatch(b)) {
    return false;
  }
  if ((a.length - b.length).abs() > 1) return false;
  if (a.length == b.length) {
    final differences = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) differences.add(i);
    }
    if (differences.length == 1) return true;
    return differences.length == 2 &&
        differences[1] == differences[0] + 1 &&
        a[differences[0]] == b[differences[1]] &&
        a[differences[1]] == b[differences[0]];
  }
  final longer = a.length > b.length ? a : b;
  final shorter = a.length > b.length ? b : a;
  for (var i = 0; i < longer.length; i++) {
    if (longer.substring(0, i) + longer.substring(i + 1) == shorter) {
      return true;
    }
  }
  return false;
}

String normalizeRequestTypos(String text) => text.replaceAllMapped(
  RegExp(
    r'"[^"]*"|\b(?:reference|ref|order)\s*(?:(?:no\.?|number|id)\s*)?[:#-]?\s+[a-z0-9-]+|\bto\s+[a-z]+(?:\s+[a-z]+)?|[a-z0-9_-]+',
    caseSensitive: false,
  ),
  (match) {
    final raw = match[0]!;
    if (raw.startsWith('"') || RegExp(r'[^a-zA-Z]').hasMatch(raw)) return raw;
    const words = [
      'screenshot',
      'screenshots',
      'receipt',
      'receipts',
      'gcash',
      'announcement',
      'deadline',
    ];
    final word = raw.toLowerCase();
    if (words.contains(word)) return raw;
    final candidates = words.where((w) => nearWord(word, w)).toList();
    return candidates.length == 1 ? candidates.single : raw;
  },
);
