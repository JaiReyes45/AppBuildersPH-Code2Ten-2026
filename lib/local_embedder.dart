import 'dart:math' as math;

import 'scan_timings.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

abstract interface class TextEmbedder {
  String get version;
  Future<List<List<double>>> chunks(String text);
  Future<void> close();
}

class MiniLmEmbedder implements TextEmbedder {
  @override
  String get version => 'minilm-1110a243-arm64-int8-hf-tokenizer-v2';
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;
  Future<void> _load() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Semantic inference is native-only; web uses keyword search.',
      );
    }
    _tokenizer ??=
        WordPieceTokenizer.fromTokenizerJsonString(
            await rootBundle.loadString('assets/models/tokenizer.json'),
          )
          ..noPadding()
          ..noTruncation();
    _session ??= await OnnxRuntime().createSessionFromAsset(
      'assets/models/minilm.onnx',
      options: OrtSessionOptions(intraOpNumThreads: 2, interOpNumThreads: 1),
    );
  }

  Future<void> _queue = Future.value();
  bool _closed = false;
  @override
  Future<List<List<double>>> chunks(String text) {
    final result = _queue.then((_) async {
      if (_closed) throw StateError('Embedder closed');
      final timer = Stopwatch()..start();
      try {
        return await _chunks(text);
      } finally {
        ScanTimings.add('embedding', timer.elapsedMicroseconds);
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<List<double>>> _chunks(String text) async {
    await _load();
    final tokens = _tokenizer!.encode(text, addSpecialTokens: false).ids;
    if (tokens.isEmpty) return [];
    final result = <List<double>>[];
    for (var start = 0; start < tokens.length; start += 168) {
      final end = math.min(start + 200, tokens.length);
      final special = _tokenizer!.encode('').ids;
      final inputIds = [
        special.first,
        ...tokens.sublist(start, end),
        special.last,
      ];
      final mask = List<int>.filled(inputIds.length, 1);
      final tensors = <String, OrtValue>{};
      Map<String, OrtValue> outputs = {};
      try {
        for (final name in _session!.inputNames) {
          final data = switch (name) {
            'input_ids' => inputIds,
            'attention_mask' => mask,
            'token_type_ids' => List<int>.filled(inputIds.length, 0),
            _ => throw StateError('Unexpected model input: $name'),
          };
          tensors[name] = await OrtValue.fromList(Int64List.fromList(data), [
            1,
            data.length,
          ]);
        }
        outputs = await _session!.run(tensors);
        final output = outputs['last_hidden_state'] ?? outputs.values.first;
        final flat = await output.asFlattenedList();
        result.add(poolTokenEmbeddings(flat.cast<num>(), mask));
      } finally {
        for (final value in [...tensors.values, ...outputs.values]) {
          await value.dispose();
        }
      }
      if (end == tokens.length) break;
    }
    return result;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _queue;
    await _session?.close();
    _session = null;
  }
}

List<double> poolTokenEmbeddings(
  List<num> flat,
  List<int> mask, {
  int dimensions = 384,
}) {
  if (flat.length != mask.length * dimensions) {
    throw StateError('Unexpected embedding shape');
  }
  final pooled = List<double>.filled(dimensions, 0);
  var count = 0;
  for (var t = 0; t < mask.length; t++) {
    if (mask[t] == 0) continue;
    count++;
    for (var d = 0; d < dimensions; d++) {
      pooled[d] += flat[t * dimensions + d].toDouble();
    }
  }
  if (count == 0) throw StateError('Empty embedding mask');
  var norm = 0.0;
  for (var d = 0; d < dimensions; d++) {
    pooled[d] /= count;
    norm += pooled[d] * pooled[d];
  }
  norm = math.sqrt(norm);
  if (!norm.isFinite || norm == 0) throw StateError('Invalid embedding');
  return pooled.map((v) => v / norm).toList();
}
