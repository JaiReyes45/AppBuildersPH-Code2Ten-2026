import 'dart:math' as math;

class SemanticRecord {
  final String key, kind, version;
  final Map<String, dynamic> payload;
  final List<double> vector;
  const SemanticRecord(
    this.key,
    this.kind,
    this.version,
    this.payload,
    this.vector,
  );
}

abstract interface class SemanticStore {
  Future<SemanticRecord?> readSemantic(String key);
  Future<void> writeSemantic(SemanticRecord record);
  Future<List<SemanticRecord>> nearestSemantic(
    List<double> vector,
    String kind,
    String version, {
    int limit = 80,
  });
  Future<void> clearSemantic();
}

double cosine(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0;
  double dot = 0, aa = 0, bb = 0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  return aa == 0 || bb == 0 ? 0 : dot / math.sqrt(aa * bb);
}

class MemorySemanticStore implements SemanticStore {
  final records = <String, SemanticRecord>{};
  @override
  Future<SemanticRecord?> readSemantic(String key) async => records[key];
  @override
  Future<void> writeSemantic(SemanticRecord record) async {
    records[record.key] = record;
  }

  @override
  Future<List<SemanticRecord>> nearestSemantic(
    List<double> vector,
    String kind,
    String version, {
    int limit = 80,
  }) async {
    final rows =
        records.values
            .where((r) => r.kind == kind && r.version == version)
            .toList()
          ..sort(
            (a, b) =>
                cosine(vector, b.vector).compareTo(cosine(vector, a.vector)),
          );
    return rows.take(limit).toList();
  }

  @override
  Future<void> clearSemantic() async => records.clear();
}
