import 'package:flutter/foundation.dart';

/// Aggregate timings only: never logs OCR text, filenames or image contents.
class ScanTimings {
  static final Map<String, int> _micros = {};
  static final Map<String, int> _counts = {};
  static void add(String stage, int microseconds) {
    _micros.update(
      stage,
      (v) => v + microseconds,
      ifAbsent: () => microseconds,
    );
    _counts.update(stage, (v) => v + 1, ifAbsent: () => 1);
  }

  static Map<String, Map<String, num>> get snapshot => {
    for (final stage in _micros.keys)
      stage: {
        'calls': _counts[stage]!,
        'totalMs': _micros[stage]! / 1000,
        'averageMs': _micros[stage]! / _counts[stage]! / 1000,
      },
  };
  static void reset() {
    _micros.clear();
    _counts.clear();
  }

  static void report() {
    if (kDebugMode) debugPrint('SSeeker timings: $snapshot');
  }
}
