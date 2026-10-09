## SSeeker scan scheduling update

The persistent media catalog replaces repeated page-zero enumeration. Screenshot-like filenames take priority. Media modification timestamps/dimensions trigger rescanning; daily full metadata refresh and full reconciliation under selected access cover changes not discoverable by the normal delta query. Completion checkpoints are saved per batch. The catalog is app-private and Clear scan resets it.

Reduced-resolution OCR includes original-image retry for sparse/tiny results and coordinate remapping. Debug `SSeeker timings` reports stage totals/counts without personal content. Initial timings and limitations are in the README. No blanket speedup is claimed: encoding reduced images has a measurable cost.

New document embedding backfill is deferred out of the OCR scan loop; existing vectors remain searchable. First-use semantic preparation may therefore happen after OCR scanning, and the explicit preparation control can continue bounded backfill.

## Current query flow

The purple arrow requests gallery access and searches saved records first. On a miss, it scans 40 new images per pass until a candidate is found, the accessible gallery is exhausted, permission fails, or the user cancels. The previous automatic 120-image limit has been removed. Startup no longer starts a competing full scan. The optional Scan gallery button still indexes the full library. No photo picker is exposed or installed. Legacy picker queue metadata no longer blocks gallery queries.

# Offline retrieval: implemented changes and remaining validation

## Implemented

- Keyword and exact-field retrieval runs before semantic fallback.
- MiniLM ONNX weights/tokenizer are bundled; no runtime download/cloud call.
- ObjectBox HNSW indexes 384-dimensional normalized text chunks. OCR
  fingerprints and model versions guard reuse. Backfill is resumable and
  limited to 40 documents per semantic pass; the UI exposes continuation.
- Existing vector hits and user-confirmed similar queries are checked before
  backfill. A similar confirmed request can avoid gallery OCR entirely.
- Query scanning continues in 40-image passes until a candidate or exhaustion. Manual deepening adds 120 images. Full-library pre-indexing is optional through Scan gallery; pause/resume, retries, and date filtering remain.
- Removed per-image database retrieval of the whole indexed-ID set; native
  success accounting uses the scanner's in-memory record map.
- Structured, compact extracted fields replace raw OCR as the primary answer.
  Source details retain expandable OCR and original images for verification.
- Explicit **This is the one** confirmation creates local memory; no automatic
  training on unverified results. Memory is capped at 100 entries. Reset
  search learning clears vectors/memories; clear scan clears all local data.

## Validation and limits

The quantized model was run on Windows using Python ONNX Runtime. Synthetic
paper-deadline and payment paraphrases ranked above unrelated content. The
Dart tokenizer matches independent Hugging Face token IDs including accented
text. This validates the artifact/input path, not Android plugin execution.
Native ObjectBox persistence/vector retrieval, fake-embedder constraints,
cache invalidation, backfill budgets, cancellation and UI regressions are
covered by automated tests: 56 Flutter tests and 14 standalone core tests pass.
Flutter analysis passes. An ARM64 Android debug APK builds successfully; its
ZIP contents were checked for the model hash, tokenizer and native ONNX runtime.
The artifact is `build/app/outputs/flutter-apk/app-debug.apk` (debug build,
not a signed release).

No Android device is connected. Measure cold scan, time to first result,
repeat-query latency, p50/p95, peak memory and battery cost on the target
phone. No speed percentage or sub-second guarantee has been established.

Semantic similarity is not proof: scores are not probabilities; current
.32/.90 cutoffs need calibration. Candidates must retain exact constraints.
The embedding model searches OCR text, not faces or visual objects. English
and some Taglish queries may work; evaluate multilingual quality explicitly.
Keyword-only web fallback does not load a remote runtime.

A native semantic pass can embed up to 40 documents, including multiple
chunks per long screenshot; cancellation takes effect between documents.
Persisted hits can return without completing the rest of the semantic index.
Existing OCR remains searchable while semantic coverage is partial. Global
HNSW top-200 post-filtering can miss heavily filtered matches; test recall
with large, date-constrained galleries before increasing the candidate budget.

## Next work

1. ARM64 fresh-install airplane-mode test, model memory/latency measurements.
2. Labeled exact/paraphrase/Taglish dataset; tune thresholds and recall@10.
3. Detect edited/deleted gallery assets and reconcile OCR/vector records;
   current invalidation occurs when changed OCR enters the local repository.
4. Profile copying/decoding/OCR separately; consider durable batched writes
   and throttled progress updates. Keep inference concurrency bounded.
5. Improve chunk-level source highlighting: semantic candidates currently
   cite their whole source document; they do not claim a specific OCR line
   proves the semantic match.

## Model provenance

[MiniLM model card](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
contains model/license details. `assets/models/manifest.json` pins the revision,
filenames and SHA-256 digests. Runtime:
[flutter_onnxruntime](https://pub.dev/packages/flutter_onnxruntime/versions/1.8.5).
Storage: [ObjectBox vector search](https://docs.objectbox.io/on-device-vector-search).
