# Offline Gallery Helpdesk — initial implementation plan

Status: planned behavior; no application code is implemented in this documentation update.

## Supported requests

| User request | Retrieval and response |
| --- | --- |
| “Find my GCash receipt for PHP 500 yesterday” | Filter GCash-like candidates by extracted amount and transaction date; resolve yesterday against query time in Asia/Manila; show alternatives if dates/amounts are unclear. |
| “What is the reference number on this receipt?” | Return the preserved OCR field with source blocks and screenshot. Do not generate missing digits. |
| “Find the order number for my headphones” | Retrieve order/item text, prioritize matching order fields, show multiple orders if needed. |
| “When is the research proposal due?” | Retrieve announcement text, present supported dates and screenshot evidence; ask if multiple/revised announcements conflict. |
| “Show my student announcements” | Category filter with transparent heuristic classification; include a way to correct categories. |

## Build sequence

1. Agree ObjectBox entities and service contracts, then scaffold Android Flutter app.
2. Obtain gallery permission; support limited selection; enumerate accessible local images with photo_manager. Ask before the first scan.
3. Queue image IDs in bounded batches. Mark pending/processing/indexed/no-text/failed. Keep resumable per-asset progress.
4. Read accessible local bytes and create app-owned evidence copies for indexed images. Avoid full-resolution images in memory concurrently.
5. Run bundled ML Kit Latin OCR. Persist original-coordinate text boxes and original recognized strings.
6. Classify candidate records using multiple text clues. Extract labels such as Order ID, Reference No., Amount, transaction date, subject/title, and deadline. Store ambiguous candidates instead of inventing fields.
7. Add exact fields and token search. Generate MiniLM vectors for short OCR chunks if the local embedding spike passes; store 384-dimensional float vectors in ObjectBox HNSW indexes. Long OCR text must be chunked because MiniLM truncates after its model input limit.
8. Implement a helpdesk chat-like input: detect intent, apply field/category filters, retrieve evidence, return source cards. For exact IDs/numbers, exact filtering outranks semantic similarity.
9. Optionally enable local Gemma 3 1B summaries from retrieved text. Require source IDs and supported facts; unsupported output falls back to deterministic templates. UI conversation history is local and deletable.
10. Add source highlights, copy-field action, category correction, rescan, index deletion, and optional user-confirmed reminders.
11. Verify clean-install airplane-mode gallery scanning, all three domains, persistence, limited access, ambiguous matches, and honest no-result responses. Package release and update documentation with actual behavior.

## Model responsibility matrix

| Component | Actual role | Limits |
| --- | --- | --- |
| ML Kit Text Recognition v2 Latin | Image -> recognized printed text + locations | No person identity, no payment authenticity check, no visual semantic search. |
| all-MiniLM-L6-v2 ONNX | OCR/query text -> 384-dimensional vectors | Text-only; English-first; correct tokenizer/pooling/normalization required. |
| ObjectBox | Local entities and vector nearest-neighbor retrieval | Database, not an AI model or accuracy validator. |
| Gemma 3 1B IT, optional quantized local model | Retrieved text -> concise summary/answer | Text-only; cannot inspect pixels or guarantee facts. Compatible conversion/runtime and phone benchmark required. |

No face scans are needed. Visual embeddings and multimodal LLMs remain future work. Model/tokenizer assets and bundled OCR must be present at install time; first launch must not download them.

## Evidence and reliability

- Distinguish OCR uncertainty, retrieval relevance, and answer support. Do not display similarity as “percent accurate.”
- Confidence is used only if exposed by the chosen SDK/plugin; missing confidence is unknown, not zero accuracy.
- Link all returned fields to the relevant screenshot and OCR blocks. Validate dates/numeric formats in Dart; preserve raw strings.
- Receipt labels are suggestions. A screenshot may be edited, outdated, or show a pending/failed transfer. Never describe it as verified proof of payment.
- Query-time “yesterday” is different from “tomorrow” inside an old announcement. The latter requires the announcement's date or user clarification.
- Gallery capture timestamps do not establish transaction dates or announcement authority.
- Use a labeled synthetic test set across receipts, orders, announcements, unrelated photos, duplicates, and blurry images. Measure OCR identifier accuracy, correct results in the top 3, unsupported answer rate, and phone latency/memory.
- Save model/version metadata so embedding model changes trigger reindexing. Keep separate vector spaces if visual search is added later.

## Definition of the helpdesk

The helpdesk answers questions from local evidence. It does not connect to GCash/shopping services, check live order status, certify transactions, read other apps' private data, or perform autonomous actions. Any reminders require user confirmation.
