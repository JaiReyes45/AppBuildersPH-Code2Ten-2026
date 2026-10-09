import 'package:flutter/material.dart' show DateTimeRange;

const _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
final _monthNames = _months
    .expand((month) => {month, month.substring(0, 3)})
    .join('|');
final _hint = RegExp(
  r'(?<![a-z0-9_-])(?:(today|yesterday|this\s+week|last\s+week|this\s+month|last\s+month)'
  r'|(\d{1,2})/(\d{1,2})(?:/(\d{4}))?'
  '|($_monthNames)(?:\\s+(?:(\\d{4})|(\\d{1,2})(?:,?\\s+(\\d{4}))?))?)'
  r'(?![a-z0-9_/-])',
  caseSensitive: false,
);

/// Calendar ranges use local time, Monday-start weeks, MM/DD numeric dates,
/// and an inclusive end at millisecond precision (matching native metadata).
DateTimeRange? parseDateHint(String query, {DateTime? now}) {
  final match = _hint.firstMatch(query);
  if (match == null) return null;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final relative = match[1]?.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (relative != null) {
    return switch (relative) {
      'today' => _days(today, 1),
      'yesterday' => _days(DateTime(today.year, today.month, today.day - 1), 1),
      'this week' => _days(
        DateTime(today.year, today.month, today.day - today.weekday + 1),
        7,
      ),
      'last week' => _days(
        DateTime(today.year, today.month, today.day - today.weekday - 6),
        7,
      ),
      'this month' => _month(current.year, current.month),
      'last month' => _month(current.year, current.month - 1),
      _ => null,
    };
  }
  if (match[2] != null) {
    return _day(
      int.parse(match[4] ?? '${current.year}'),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }
  final month =
      _months.indexWhere((name) => name.startsWith(match[5]!.toLowerCase())) +
      1;
  final year = int.parse(match[6] ?? match[8] ?? '${current.year}');
  return match[7] == null
      ? _month(year, month)
      : _day(year, month, int.parse(match[7]!));
}

/// Remove the metadata hint before keyword retrieval. The same first hint is
/// used for both filtering and removal; invalid dates remain ordinary text.
String queryWithoutDateHint(String query, {DateTime? now}) {
  if (parseDateHint(query, now: now) == null) return query;
  final match = _hint.firstMatch(query)!;
  return query.replaceRange(match.start, match.end, ' ').trim();
}

DateTimeRange _days(DateTime start, int days) => DateTimeRange(
  start: start,
  end: DateTime(
    start.year,
    start.month,
    start.day + days,
  ).subtract(const Duration(milliseconds: 1)),
);

DateTimeRange _month(int year, int month) => DateTimeRange(
  start: DateTime(year, month),
  end: DateTime(year, month + 1).subtract(const Duration(milliseconds: 1)),
);

DateTimeRange? _day(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return _days(date, 1);
}
