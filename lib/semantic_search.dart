import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

import 'local_embedder.dart';
import 'semantic_store.dart';

String textFingerprint(String text) =>
    sha256.convert(utf8.encode(text)).toString();

/// Semantic expansion must not turn a total unstructured OCR miss into an
/// unrelated result. Structured filters are safe anchors; otherwise require
/// at least one whole query keyword to occur in the indexed OCR corpus.
bool hasSemanticSearchAnchor(
  HelpdeskQuery query,
  Iterable<AnalyzedScreenshot> documents,
) {
  if (query.category != null ||
      query.amount != null ||
      query.exactIdentifier != null ||
      query.requiredPhrases.isNotEmpty) {
    return true;
  }
  for (final keyword in query.keywords) {
    final pattern = RegExp(
      '(?<![a-z0-9])${RegExp.escape(keyword)}(?![a-z0-9])',
    );
    if (documents.any(
      (document) => pattern.hasMatch(document.recognizedText.toLowerCase()),
    )) {
      return true;
    }
  }
  return false;
}

/// Local inference and explicit relevance feedback. OCR is untrusted evidence.
class SemanticSearch {
  final TextEmbedder embedder;
  final SemanticStore store;
  SemanticSearch(this.embedder, this.store);
  String? unavailableReason;
  final _queryVectors = <String, List<double>>{};
  bool _closed = false;
  int pendingDocuments = 0;
  int _epoch = 0;
  Future<void> close() async {
    _closed = true;
    await embedder.close();
  }

  Future<List<double>> _queryVector(String text) async {
    final key = text.trim().toLowerCase();
    if (_queryVectors.containsKey(key)) return _queryVectors[key]!;
    final vectors = await embedder.chunks(key);
    if (vectors.isEmpty) return [];
    final result = List<double>.filled(vectors.first.length, 0);
    for (final vector in vectors) {
      for (var i = 0; i < vector.length; i++) {
        result[i] += vector[i] / vectors.length;
      }
    }
    if (_queryVectors.length >= 50) {
      _queryVectors.remove(_queryVectors.keys.first);
    }
    return _queryVectors[key] = result;
  }

  Future<List<SearchMatch>> search(
    HelpdeskQuery query,
    List<AnalyzedScreenshot> documents, {
    bool Function()? cancelled,
    bool indexMore = false,
    bool prepareMissing = true,
    void Function(int, int)? onProgress,
  }) async {
    if (unavailableReason != null || _closed) return [];
    if (query.keywords.isEmpty &&
        query.category == null &&
        query.amount == null &&
        query.exactIdentifier == null &&
        query.requiredPhrases.isEmpty) {
      return [];
    }
    final epoch = _epoch;
    bool stopped() =>
        _closed || epoch != _epoch || (cancelled?.call() ?? false);
    try {
      final queryVector = await _queryVector(query.originalText);
      if (queryVector.isEmpty) return [];
      final byId = {for (final d in documents) d.screenshotId: d};
      final fingerprints = <String, String>{};
      for (final doc in documents) {
        fingerprints[doc.screenshotId] = textFingerprint(doc.recognizedText);
      }
      Future<List<SearchMatch>> rankCandidates() async {
        final scores = <String, double>{};
        // Conservative initial cutoff: requires target-device/query-set calibration.
        for (final row in await store.nearestSemantic(
          queryVector,
          'chunk',
          embedder.version,
          limit: 200,
        )) {
          final id = row.payload['id'] as String;
          if (fingerprints[id] != row.payload['fingerprint']) continue;
          final score = cosine(queryVector, row.vector);
          if (score >= .32 && score > (scores[id] ?? 0)) scores[id] = score;
        }
        for (final row in await store.nearestSemantic(
          queryVector,
          'memory',
          embedder.version,
          limit: 100,
        )) {
          if (cosine(queryVector, row.vector) < .90) continue;
          final id = row.payload['id'] as String;
          if (fingerprints[id] != row.payload['fingerprint']) continue;
          scores[id] = .99;
        }
        final constraints = HelpdeskQuery(
          originalText: query.originalText,
          intent: query.intent,
          keywords: const [],
          category: query.category,
          amount: query.amount,
          exactIdentifier: query.exactIdentifier,
          exactIdentifierType: query.exactIdentifierType,
          requiredPhrases: query.requiredPhrases,
        );
        final allowed = SearchService()
            .search(constraints, documents, allowUnconstrained: true)
            .map((m) => m.screenshot.screenshotId)
            .toSet();
        final ranked =
            scores.entries
                .where(
                  (e) =>
                      allowed.contains(e.key) &&
                      byId.containsKey(e.key) &&
                      literalDetailsMatch(query, byId[e.key]!),
                )
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        return ranked
            .where((e) => e.value >= ranked.first.value - .08)
            .take(5)
            .map(
              (e) => SearchMatch(
                screenshot: byId[e.key]!,
                rank: (e.value * 100).round(),
                // Semantic similarity is document-level, not proof that every OCR line matched.
                matchingBlockIds: const [],
              ),
            )
            .toList();
      }

      final cached = await rankCandidates();
      if (stopped()) return [];
      if (cached.isNotEmpty && !indexMore) return cached;
      if (!prepareMissing) return cached;
      pendingDocuments = 0;
      var newlyIndexed = 0;
      var processed = 0;
      for (final doc in documents) {
        if (stopped()) return [];
        final fingerprint = textFingerprint(doc.recognizedText);
        fingerprints[doc.screenshotId] = fingerprint;
        final key = 'doc:${embedder.version}:${doc.screenshotId}';
        final marker = await store.readSemantic(key);
        if (marker?.payload['fingerprint'] != fingerprint) {
          if (newlyIndexed >= 40) {
            pendingDocuments++;
            continue;
          }
          newlyIndexed++;
          final chunks = await embedder.chunks(doc.recognizedText);
          if (stopped()) return [];
          for (var i = 0; i < chunks.length; i++) {
            if (stopped()) return [];
            await store.writeSemantic(
              SemanticRecord('$key:$i', 'chunk', embedder.version, {
                'id': doc.screenshotId,
                'fingerprint': fingerprint,
              }, chunks[i]),
            );
          }
          // Marker is written last so interrupted indexing resumes safely.
          await store.writeSemantic(
            SemanticRecord(key, 'document', embedder.version, {
              'fingerprint': fingerprint,
            }, []),
          );
        }
        onProgress?.call(++processed, documents.length);
      }
      if (stopped()) return [];
      return await rankCandidates();
    } catch (e) {
      unavailableReason =
          'Semantic search unavailable; keyword search remains active.';
      return [];
    }
  }

  Future<void> remember(String query, AnalyzedScreenshot screenshot) async {
    if (_closed) return;
    final vector = await _queryVector(query);
    if (vector.isEmpty) return;
    final key =
        'memory:${embedder.version}:${textFingerprint(query.trim().toLowerCase())}:${screenshot.screenshotId}';
    await store.writeSemantic(
      SemanticRecord(key, 'memory', embedder.version, {
        'id': screenshot.screenshotId,
        'fingerprint': textFingerprint(screenshot.recognizedText),
      }, vector),
    );
  }

  Future<void> forget() async {
    _epoch++;
    pendingDocuments = 0;
    await store.clearSemantic();
    _queryVectors.clear();
    unavailableReason = null;
  }
}

/// Numbers and mixed letter/digit identifiers are never relaxed by semantics.
bool literalDetailsMatch(HelpdeskQuery query, AnalyzedScreenshot doc) {
  final text = [
    doc.recognizedText,
    ...doc.fields.map((f) => f.normalizedValue ?? f.rawValue),
  ].join('\n').toLowerCase().replaceAll(',', '');
  return query.keywords
      .where((word) => RegExp(r'\d').hasMatch(word))
      .every(
        (word) =>
            RegExp('(?<![a-z0-9])${RegExp.escape(word)}(?![a-z0-9])')
                .hasMatch(text),
      );
}
