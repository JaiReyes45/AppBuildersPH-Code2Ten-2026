import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/search_counts.dart';

void main() {
  test('normalizes repeated queries and restores counts', () {
    final counts = SearchCounts()
      ..record('  GCash   receipt ')
      ..record('gcash receipt')
      ..record('orders');
    expect(counts.top().first.key, 'gcash receipt');
    expect(counts.top().first.value, 2);
    final restored = SearchCounts()
      ..replace(counts.counts)
      ..record('orders')
      ..record('orders');
    expect(restored.top().first.key, 'orders');
    expect(restored.top().first.value, 3);
  });
  test('retains at most 100 queries and returns five shortcuts', () {
    final counts = SearchCounts();
    for (var i = 0; i < 120; i++) {
      counts.record('query $i');
    }
    expect(counts.counts.length, 100);
    expect(counts.top().length, 5);
  });
}
