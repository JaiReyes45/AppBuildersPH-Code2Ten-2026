import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/query_date_hint.dart';

void main() {
  final now = DateTime(2026, 10, 10, 14);
  final cases = <String, (DateTime, DateTime)>{
    'today': (DateTime(2026, 10, 10), DateTime(2026, 10, 11)),
    'YESTERDAY': (DateTime(2026, 10, 9), DateTime(2026, 10, 10)),
    'this week': (DateTime(2026, 10, 5), DateTime(2026, 10, 12)),
    'last week': (DateTime(2026, 9, 28), DateTime(2026, 10, 5)),
    'this month': (DateTime(2026, 10), DateTime(2026, 11)),
    'last month': (DateTime(2026, 9), DateTime(2026, 10)),
    'january': (DateTime(2026, 1), DateTime(2026, 2)),
    'DEC': (DateTime(2026, 12), DateTime(2027, 1)),
    'october 2025': (DateTime(2025, 10), DateTime(2025, 11)),
    'oct 2026': (DateTime(2026, 10), DateTime(2026, 11)),
    '10/8': (DateTime(2026, 10, 8), DateTime(2026, 10, 9)),
    '10/8/2025': (DateTime(2025, 10, 8), DateTime(2025, 10, 9)),
    'oct 8': (DateTime(2026, 10, 8), DateTime(2026, 10, 9)),
    'oct 8 2025': (DateTime(2025, 10, 8), DateTime(2025, 10, 9)),
    'February 29, 2024': (DateTime(2024, 2, 29), DateTime(2024, 3, 1)),
    'yesterday and october 2025': (
      DateTime(2026, 10, 9),
      DateTime(2026, 10, 10),
    ),
    'oct 8 2025 or yesterday': (DateTime(2025, 10, 8), DateTime(2025, 10, 9)),
  };
  for (final entry in cases.entries) {
    test(
      entry.key,
      () => expect(
        parseDateHint(entry.key, now: now),
        DateTimeRange(
          start: entry.value.$1,
          end: entry.value.$2.subtract(const Duration(milliseconds: 1)),
        ),
      ),
    );
  }
  test('last month crosses the year boundary', () {
    expect(
      parseDateHint('last month', now: DateTime(2026, 1, 2))!.start,
      DateTime(2025, 12),
    );
  });
  test('unknown and invalid dates are not invented or rolled forward', () {
    for (final query in [
      'receipt PHP 1000',
      '13/8',
      '2/30/2026',
      'feb 29 2025',
      'REF-OCT-1234',
      'octopus',
    ]) {
      expect(parseDateHint(query, now: now), isNull, reason: query);
    }
  });
  test('date words do not become retrieval keywords', () {
    expect(
      queryWithoutDateHint('headphones yesterday', now: now),
      'headphones',
    );
    expect(
      queryWithoutDateHint('receipt 2/30/2026', now: now),
      'receipt 2/30/2026',
    );
  });
}
