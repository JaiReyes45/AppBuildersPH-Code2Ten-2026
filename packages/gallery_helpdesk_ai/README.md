# Gallery Helpdesk AI core

Pure Dart, offline-first logic for the Gallery Helpdesk feature. The package is
designed to sit between the app's OCR/storage adapters and its helpdesk UI.

## Current pipeline

1. Accept OCR blocks with stable, per-screenshot IDs and optional bounding
   boxes in original-image coordinates.
2. Conservatively classify candidates as GCash-like receipts, orders,
   announcements, other text, or unknown.
3. Extract literal candidate amounts, reference/order numbers, labeled dates,
   titles, and item names. Each field retains its OCR source block ID.
4. Parse the basic helpdesk intent and category, amount, exact identifier, and
   keyword terms.
5. Filter and rank only supplied indexed screenshots. Exact identifiers and
   amounts are matched literally; when both are supplied, both must match.
   Keyword-only queries need at least two-thirds of their distinct query terms
   to occur in OCR text. The integer rank is not a confidence score.
6. Format a deterministic answer with source screenshot IDs and OCR block IDs.

```dart
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

Future<void> main() async {
  final ai = GalleryHelpdeskAi();
  final screenshot = ai.analyze(
    const OcrScreenshot(
      screenshotId: 'receipt-1',
      blocks: [
        OcrBlock(id: 'block-1', text: 'GCash'),
        OcrBlock(id: 'block-2', text: 'Amount: PHP 500'),
        OcrBlock(id: 'block-3', text: 'Reference No: R-123456'),
      ],
    ),
  );

  final answer = await ai.answer(
    'Find my GCash receipt for PHP 500',
    [screenshot],
  );
  print(answer.text);
  print(answer.sources.single.matchingBlockIds);
}
```

## Scope and integration notes

- This package does not access the gallery, run OCR, persist records, schedule
  reminders, or include an on-device language/embedding model. The Flutter app
  provides those adapters.
- `EvidenceAnswerGenerator` is the extension point for a future local Gemma
  adapter. The current implementation is deterministic; no claim is made that
  Gemma has been benchmarked or integrated.
- Any future LLM adapter must treat OCR as untrusted data, answer only from
  supplied evidence, preserve exact identifiers, and leave actions such as
  reminders to the app and its confirmation flow.
- Relative dates are not resolved in this core. The app must resolve them with
  its Asia/Manila-aware date/time layer and ask when ambiguous.
- Classification and extraction are heuristic candidate generation, not proof
  of payment or an authoritative interpretation of an announcement.
- If OCR splits an identifier label and value into immediately adjacent blocks
  (for example, `Reference No.` followed by `R-123456`), the candidate field
  cites both block IDs. Input ordering should follow the OCR reading order.
- Amount normalization removes commas and standardizes to two decimals while
  preserving the raw OCR string for display.

## Local model status

No embedding or generative model is integrated or advertised as available.
The connected validation device is Samsung model `SM-X210` on Android 16
(Qualcomm platform `SM6375`, approximately 7.2 GiB reported system memory).
This hardware identification is not a performance benchmark.

The plan's proposed `flutter_gemma` and `flutter_gemma_onnx` package names now
refer to final legacy releases; their maintained successor is `flutter_edge_ai`
with `flutter_edge_ai_onnx`. Renaming/upgrading the runtime does not establish
compatibility with the proposed Gemma/MiniLM assets. No compatible model and
tokenizer bundle, cold-start/offline run, latency, or peak-memory measurement
has been verified on this tablet, so both optional model features remain gated
off. Exact/keyword retrieval and deterministic evidence templates remain the
supported behavior.

## Run checks

```sh
dart analyze
dart test
```
