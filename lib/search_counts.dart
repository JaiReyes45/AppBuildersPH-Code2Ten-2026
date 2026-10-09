/// Local submitted-query frequency, independent of OCR and semantic ranking.
class SearchCounts {
  final Map<String, int> counts = {};
  void replace(Map<String, int> saved) {
    counts.clear();
    counts.addAll(saved);
  }

  void record(String query) {
    final key = query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (key.isEmpty) return;
    counts[key] = (counts[key] ?? 0) + 1;
    if (counts.length > 100) {
      final retained = top(100);
      replace(Map.fromEntries(retained));
    }
  }

  List<MapEntry<String, int>> top([int limit = 5]) {
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final frequency = b.value.compareTo(a.value);
        return frequency != 0 ? frequency : a.key.compareTo(b.key);
      });
    return sorted.take(limit).toList();
  }
}
