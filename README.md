# AppBuildersPH-Code2Ten-2026

**Gallery Helpdesk** — an offline Android assistant that scans the user's permitted local gallery to find order numbers, GCash receipt details, and student announcements, and answers requests with linked screenshot evidence.

> Status: an interactive Flutter front-end and a standalone Dart helpdesk core are implemented. The front-end uses fictional sample data and does not yet call the core. Gallery scanning, OCR, ObjectBox, embedding/LLM inference, persistence, and real notifications remain pending. The product requirements farther below are planned acceptance criteria, not completed functionality.

**Deadline:** Saturday, October 10, 2026, 10:00 AM, Asia/Manila (UTC+8).

## Run the current app

### Prerequisites

- Flutter with Dart compatible with `sdk: ^3.13.5`; development verification used Flutter 3.47.7 / Dart 3.13.5.
- Git and Chrome for the easiest preview. Android Studio/SDK plus an emulator or USB-debugging-enabled phone for Android.
- Initial checkout and dependency installation require internet. No cloud service/API key is used by the sample UI.

Clone the private repository using an account with access, then run commands **from the project root containing pubspec.yaml**, not from the Flutter SDK folder:

```sh
git clone https://github.com/JaiReyes45/AppBuildersPH-Code2Ten-2026.git
cd AppBuildersPH-Code2Ten-2026
flutter doctor
flutter pub get
flutter run -d chrome
```

For the original developer's existing Windows checkout:

```powershell
cd "C:\Users\Guienne Jairo Reyes\OneDrive\Documents\ChatGPT\AppBuilderPh-Hackathon"
flutter pub get
flutter run -d chrome
```

To preview mobile dimensions in Chrome, open Developer Tools with F12, toggle device mode with Ctrl+Shift+M, choose a phone or 390 x 844, and refresh. Browser device mode previews layout; it does not verify Android permissions/native AI.

For Android:

```sh
flutter emulators
flutter emulators --launch <emulator-id>
flutter devices
flutter run -d <device-id>
```

Replace placeholders with the listed IDs. The original workstation has an emulator named `flutter_android`; other contributors may need to create one. A physical phone needs USB debugging and authorization of the connected computer. First Android builds may download Gradle/build artifacts; an Android release APK has not yet been verified.

In VS Code, open this repository folder, open `lib/main.dart`, select Chrome or Android in the device selector, and press F5. If `flutter` is not recognized, restart VS Code after adding the SDK's `bin` folder to PATH. `Target file lib/main.dart not found` means the terminal is in the wrong directory.

### Try the current interactions

1. Submit **headphones**, **GCash 500**, or **proposal deadline** using the arrow or keyboard search action.
2. The robot rummages through a box during a simulated search, then presents a “Ta-da!” result.
3. Open a result to view recreated source text, highlighted details, and a copy action.
4. Submit **GCash 9999** to see uncertain results with receipt samples for manual browsing; switch categories to browse other examples.
5. Cancel a running search or start again. Announcement details include a reminder preview; it does not schedule a notification.

Four fictional records are built into `lib/main.dart`. The UI performs simple keyword matching after a simulated delay; the animation is not proof of real AI processing. There are no actual gallery screenshots in the demo, and changes are not persisted. Reduced-motion settings stop continuous robot movement.

![Mobile result-state preview](preview/found.png)

See [PREVIEW.md](PREVIEW.md) for the focused front-end guide.

## Current progress

| Area | Implemented | Still needed |
| --- | --- | --- |
| Flutter UI | Android/web scaffold, search and category browsing, loading/cancel/success/uncertain states, animated robot, source detail/highlights, copy field, reminder preview | Connect service interfaces, actual screenshot thumbnails/full images, permission and indexing screens |
| Dart core | Heuristic classification, candidate extraction, query parsing, ranking, deterministic answers and source IDs in `packages/gallery_helpdesk_ai` | Fix reviewed retrieval/extraction bugs; connect to UI and OCR/storage adapters |
| Gallery/OCR | Planned | photo_manager permissions, paged/resumable scan, bundled ML Kit Latin OCR, source boxes and image copies |
| Local database | ObjectBox selected | Entities, generated bindings/model IDs, persistence, incremental indexing, deletion, optional vector indexes |
| Local models | MiniLM and optional Gemma selected as candidates | Compatible bundled weights/tokenizer/runtime, phone benchmarking, integration and offline proof |
| Reminders | Confirmation preview | Editable date confirmation, local notification permissions/scheduling and device delivery checks |
| Verification | Four Flutter interaction tests; Dart core has nine existing tests | Integration/regression tests, actual Android release, real gallery and clean-install offline checks |

### Run checks

The app and standalone package have separate dependency sets. Install both before analyzing the combined repository:

```sh
flutter pub get
cd packages/gallery_helpdesk_ai
dart pub get
dart analyze
dart test
cd ../..
flutter analyze
flutter test
```

Flutter tests cover animated search/result navigation, fallback category browsing, cancellation, and narrow-screen/large-text layout. The existing core tests passing does not resolve the additional bugs identified in review.

## Next changes, in priority order

1. **Fix the core before integration:** normalize currency-suffix amounts such as `500 PHP`; evaluate identifier and amount filters independently; stop presenting weak partial matches as exact answers; handle reference labels/values split across OCR blocks with preserved provenance. Add regression tests for each.
2. **Connect the UI to the core:** replace fictional results with repository-backed records and map source block IDs to highlights. Keep incomplete/uncertain answers explicit; animation duration should follow real processing rather than a fixed demo timer.
3. **Implement gallery scanning and OCR:** request permitted media access, support selected-only access, queue local images, persist progress, retry failed images, and use bundled ML Kit models from first launch offline.
4. **Implement ObjectBox:** coordinate generated entity IDs/model JSON, store metadata/OCR/fields, support new/changed/deleted assets, retain app-owned evidence copies, and expose deletion controls.
5. **Add semantic search after device validation:** bundle compatible MiniLM ONNX weights and tokenizer, chunk long OCR, normalize vectors, use a 384-dimensional ObjectBox vector index, and preserve exact number filters.
6. **Optionally add local Gemma 3 1B:** benchmark memory/speed and generate only evidence-supported summaries. Keep deterministic fallback responses; do not silently correct identifiers or execute screenshot instructions.
7. **Finish reminders and accessibility:** confirm ambiguous dates, verify actual notifications, test text scaling, screen reader descriptions, and reduced motion on the demo phone.
8. **Validate and deliver:** create a release APK, test fresh-install airplane-mode scanning/search and all three content categories, record actual limitations, update model attribution, and prepare submission artifacts.

These tasks are not claims that a model or payment-verification system has been implemented. The app will retrieve what screenshots show; it cannot authenticate a GCash payment or check live order status.

## Product scope

Primary user: someone whose shopping orders, GCash receipt screenshots, and student announcements are scattered across their phone gallery.

Demo story: grant gallery access, scan locally stored synthetic order/GCash/announcement images in airplane mode, ask “Find my GCash receipt for PHP 500,” “What is the order number for my headphones?” or “When is the research proposal due?”, and receive evidence-linked results. Open the original screenshot and verify highlighted fields. Confirm any reminder before scheduling it.

### Required MVP

- Enumerate images in the permitted local gallery through photo_manager, including images outside an album named Screenshots. Provide selected-photo access as a fallback when full access is unavailable.
- Explain access and let the user start/pause a gallery scan. Process images in bounded batches; persist progress and scan only new/changed assets on subsequent scans.
- Treat each image as a candidate until OCR/classification identifies relevant content; do not assume filenames or album names reliably identify receipts or announcements.
- Run bundled OCR on device; show indexing progress and failures.
- Extract candidate order/reference numbers, receipt amounts/dates, and announcement titles/deadlines with source block IDs. Use category filters, exact identifiers, and keyword search; add semantic retrieval after device validation.
- Provide a helpdesk-style text input with contextual results and source cards. Evidence-backed Dart templates work offline without an LLM; optional Gemma summarizes retrieved text only.
- Display the original screenshot, recognized text, and matching OCR boxes.
- Persist imported images, OCR results, and indexing state locally.
- Suggest deadline candidates; require date/time confirmation before scheduling a reminder.
- Schedule local notifications and expose saved reminders in the app.
- Delete an imported screenshot and its associated index; separately confirm removal of linked reminders.
- Work after a fresh installation in airplane mode, including the first OCR run.

### Conditional feature: semantic search

Include semantic search only if a bundled embedding model runs on the actual target Android phone by 4:30 PM on October 9. Otherwise ship real OCR plus keyword search and clearly describe semantic search as future work. If judging specifically requires embeddings or generative AI, resolve that requirement during kickoff; do not claim a missing feature.

### Stretch features

Visual similarity, automatic related screenshot grouping, share-to-app import, multilingual semantic search, and perceptual duplicate detection. A conversational helpdesk UI is required; generative answers are conditional on a proven local LLM. Full-gallery scanning means permitted local assets, not cloud-only images or access to other apps' private databases.

## Proposed technology stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Mobile app | Flutter + Dart; Android first | Existing developer setup has Flutter 3.47.7 / Dart 3.13.5. Pin compatible package versions after testing. |
| State | flutter_riverpod | Represent import/index/search/reminder states explicitly. |
| Gallery access | photo_manager; image_picker optional | Enumerate permitted on-device assets, page batches, handle selected access and revoked permissions. |
| OCR | google_mlkit_text_recognition -> ML Kit Text Recognition v2 Latin-script model | Bundled native OCR dependencies; recognizes printed Latin text, not scene meaning or face identity. Verify fresh offline use. |
| Storage | objectbox + objectbox_flutter_libs, objectbox_generator + build_runner; path_provider | Local entities, OCR boxes, extracted fields, scan state, reminders, and vectors. Commit objectbox-model.json and coordinate entity IDs. |
| Exact search | ObjectBox indexed fields/string queries + Dart token ranking | Preserve literal order/reference number matches; string contains is not a full-text ranking engine. |
| Semantic search, conditional | flutter_gemma_onnx embedding backend + compatible all-MiniLM-L6-v2 ONNX model | Bundle weights and matching tokenizer; implement required pooling/normalization. English-first. Benchmark before integrating. |
| Vector retrieval | ObjectBox HNSW float-vector index with 384 dimensions for MiniLM | Use a compatible cosine distance setup and consistent normalized embeddings; reindex after model changes. |
| Ranking | Category/structured-field filters + exact match + keyword score + optional vector similarity | Text embeddings search OCR text, not visual content. Similarity scores are not probabilities of correctness. |
| Local LLM, optional | Quantized google/gemma-3-1b-it through flutter_gemma and a compatible local inference engine | Text-only summaries/answers from retrieved OCR; bundle supported model format. Never repairs identifiers silently or triggers actions itself. |
| Classification/extraction | Dart label/regex rules; optional LLM suggestions | GCash-like receipt, order, announcement, other/unknown. Preserve raw text and uncertain candidates. |
| Reminders | flutter_local_notifications + timezone | Use Asia/Manila; choose ordinary local scheduling for the MVP, validate notification permissions and platform requirements. |
| Dates | Dart parsing rules + confirmation UI | Support explicit formats first. Relative dates require user clarification. |
| Verification | flutter analyze, targeted flutter test, physical Android testing | Emulator can support UI work; validate native AI and notifications on a phone. |

No server, API key, Firebase, hosted vector database, or runtime inference request is part of this architecture. Development/package downloads require connectivity; installed product use must not.

## Architecture and data contract

Permission -> paged gallery enumeration -> bounded scan queue -> app-owned local copy for indexed evidence -> OCR -> category/field candidates -> ObjectBox -> optional embeddings -> helpdesk query -> filtered/ranked retrieval -> source-linked response -> source view -> optional confirmed reminder.

The app reads OS-authorized media assets; it does not automate the gallery application's UI. See [HELPDESK_PLAN.md](HELPDESK_PLAN.md) for query handling, field extraction, reliability checks, and model responsibilities. The initial pure-Dart AI core is in [packages/gallery_helpdesk_ai/](packages/gallery_helpdesk_ai/README.md); it handles candidate classification/extraction, basic query parsing, evidence retrieval, and deterministic source-linked responses. It does not yet run OCR or integrate Gemma/embeddings.

Keep native plugin work in its supported execution context. Run CPU ranking off the UI thread when needed; do not assume every native plugin can run in an arbitrary Dart isolate.

| Entity | Minimum fields |
| --- | --- |
| Screenshot | id, galleryAssetId, assetModifiedAt, localPath, originalName, importedAt, contentHash, category, status, error, imageWidth, imageHeight |
| OCR block | id, screenshotId, text, boundingBox in original image coordinates |
| Optional text chunk | id, screenshotId, text, embedding, modelVersion |
| Search result | screenshotId, score, matchingBlockIds, matchReason |
| Extracted field | id, screenshotId, fieldType, rawValue, normalizedValue, sourceBlockIds, validationStatus |
| Scan state | id, scanStartedAt, currentCursor, processedCount, failedCount, status; per-asset state remains authoritative |
| Reminder | id, screenshotId, title, confirmedDueAt, scheduledAt, notificationId, status |

Suggested service boundaries: GalleryService, ScanQueue, OcrService, FieldExtractor, ScreenshotRepository, SearchService, HelpdeskService, DeadlineParser, ReminderService. Agree on interfaces before parallel implementation. Store candidate deadline separately from the user's confirmed deadline. Store source image files on disk; ObjectBox stores paths/metadata rather than full-resolution image blobs.

## Release build (after Android verification)

The scaffold now exists. Use the run/check instructions above for the current preview; the release command below is a next verification step, not evidence of an already tested APK.

```sh
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

On Windows, use a physical Android device with USB debugging for native model verification. Do not assume the x86 emulator supports the chosen embedding runtime. Verify model redistribution terms, keep attribution, and bundle required model/tokenizer files. Do not commit personal screenshots, credentials, or generated APKs.

## Happy paths and acceptance checks

| ID | Scenario and steps | Expected result |
| --- | --- | --- |
| HP-01 | Fresh install offline; grant gallery access and scan synthetic images from several local albums | OCR runs without a first-use network download; permitted images are enumerated, indexing completes, and results persist after restart. |
| HP-02 | Search an exact assignment title or reference number | Matching screenshot ranks prominently; source opens; relevant text is highlighted. |
| HP-03 | Search “research proposal deadline” | Keyword results work. If semantic feature ships, paraphrases retrieve relevant OCR text with model-based ranking. |
| HP-04 | Open an announcement with an explicit date and time | App proposes a candidate; user confirms/edits date and time; original screenshot remains visible. |
| HP-05 | Create a reminder a few minutes ahead with notification permission granted | Reminder is listed locally and the notification appears on the target phone within the documented scheduling tolerance. |
| HP-06 | Close/reopen app and repeat search in airplane mode | Images, index, and reminders persist; no cloud request is required. |
| HP-07 | Import the identical file again | Hash check avoids duplicate index records and reports the duplicate clearly. |
| HP-08 | Delete an imported screenshot | App-owned copy/index disappear; original gallery image stays intact; linked reminder handling is confirmed explicitly. |
| HP-09 | Ask for a GCash receipt by amount and date | Show matching receipt candidates and highlight amount/date/reference text; do not claim bank verification. |
| HP-10 | Ask for the order number for an item | Return the exact OCR-supported candidate number with its source; ambiguous orders produce choices. |
| HP-11 | Add a new gallery image and rescan | Process new/changed assets without reprocessing unchanged indexed assets; handle exact duplicates. |
| HP-12 | Ask a question with no supporting screenshot | Say no matching evidence was found; disclose incomplete scan coverage when applicable. |

## Edge cases and required behavior

| ID | Situation | Required behavior / test |
| --- | --- | --- |
| EC-01 | Picker canceled or permission denied | Return to the current screen; explain how to retry; do not crash or silently scan other photos. |
| EC-02 | Android grants access to selected photos only | Use permitted images; allow the user to select more; no assumption of full-gallery access. |
| EC-03 | Gallery image exists only in a cloud library | Explain that a local copy is needed. Do not claim it can be imported offline. |
| EC-04 | Blurry, tiny, rotated, or low-contrast text | Show recognized text and a usable source preview; offer manual correction/re-import; never invent missing words. |
| EC-05 | Meme or image without text | Mark as “No readable text”; retain preview; keyword search cannot find visual content. |
| EC-06 | Filipino/Taglish, handwriting, unsupported script | Show actual OCR output; disclose limitations; English semantic model may rank poorly. |
| EC-07 | Search has no match or irrelevant results | Show an honest empty state and suggest exact keywords; never fabricate a screenshot. |
| EC-08 | Embedding model/tokenizer missing, incompatible, or too slow | Fall back to working keyword search; label semantic mode unavailable. |
| EC-09 | App interrupted while indexing | Persist item status; resume/retry unfinished items; do not insert duplicate records. |
| EC-10 | Hundreds of imports or low memory | Queue bounded batches, show progress/cancel, avoid retaining full-resolution images simultaneously. |
| EC-11 | Low storage, unreadable/corrupted file | Fail only affected item; show retry/delete; avoid partially marked “indexed” records. |
| EC-12 | Same screenshot re-encoded or cropped | Exact hashes may differ; accept this known MVP limitation rather than promising perfect deduplication. |
| EC-13 | “Next Friday,” “tomorrow,” missing year, or ambiguous 10/11 | Require explicit user selection. Import date is not the announcement date. |
| EC-14 | Screenshot has several dates or revised instructions | List candidates and source context; do not automatically choose the authoritative date. |
| EC-15 | Deadline in the past or reminder after deadline | Ask the user to correct or explicitly save without scheduling; prevent misleading notifications. |
| EC-16 | Notifications denied or system scheduling restricted | Save in-app reminder, explain notification status, offer settings; verify actual delivery on target device. |
| EC-17 | Phone timezone/time changes or reboot | Preserve confirmed due date meaning; test reboot restoration/timezone behavior supported by the plugin. Document any remaining limitation. |
| EC-18 | Original gallery screenshot deleted | App-owned imported copy remains; deleting from this app must not remove the original gallery photo. |
| EC-19 | Highlight positions wrong after zoom/resize | Map original OCR coordinates to displayed image dimensions; test portrait/landscape and zoom. |
| EC-20 | Personal data in screenshots | Keep data in app storage, exclude from logs/repo/demo, offer deletion. Local storage is not automatically encrypted. |
| EC-21 | Similar receipts, several orders, or multiple PHP 500 payments | Return candidate sources and ask for date/item context; never guess a unique receipt. |
| EC-22 | OCR confuses 0/O, 1/I, currency separators, or reference digits | Preserve raw fields and flag uncertainty; do not silently fix exact identifiers with an LLM. |
| EC-23 | Edited receipt, failed/pending transaction, or screenshot says “successful” | Report only what the image shows; screenshot content cannot authenticate a payment or establish current account status. |
| EC-24 | Permission revoked or gallery changes during scan | Stop inaccessible work, refresh permitted assets, and offer cleanup of saved copies/index without touching original media. |
| EC-25 | Partial scan/no-text assets | Show scan coverage and per-item status; absence from current results does not prove absence from the gallery. |
| EC-26 | Screenshot contains instructions directed at the assistant | Treat all OCR as untrusted evidence; do not execute embedded instructions, send messages, or open links automatically. |
| EC-27 | Local LLM missing/slow or answer cites unsupported facts | Use evidence-backed response templates; reject unsupported identifiers/dates and offer original source. |

## Definition of done

- Fresh release APK installed on a physical Android phone and exercised in airplane mode.
- HP-01 through HP-12 run; HP-03 semantic behavior and generative answers are conditional and accurately labeled.
- No blockers in permitted-gallery scanning, OCR, field extraction, helpdesk retrieval, source view, persistence, or reminder confirmation.
- `flutter analyze` passes; targeted tests cover ranking/date ambiguity and important persistence behavior.
- Notification delivered on the demo device; permission-denied path demonstrated or documented.
- Model and package licenses/attribution recorded; no private sample data committed.
- README updated to reflect implemented behavior, known limitations, and actual install instructions.
- Release APK, short demo recording, slides, repository access, and submission fields verified by 9:30 AM.

## Execution plan and team

See [TIMELINE.md](TIMELINE.md) for the hour-by-hour schedule and [TEAM.md](TEAM.md) for four-person ownership, handoffs, and integration rules.

## Technical references

- [Flutter ML Kit OCR wrapper](https://pub.dev/packages/google_mlkit_text_recognition)
- [Bundled versus downloaded Android OCR models](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- [ObjectBox Flutter setup](https://docs.objectbox.io/getting-started)
- [ObjectBox vector search](https://objectbox.io/on-device-vector-database-for-dart-flutter/)
- [Gallery access](https://pub.dev/packages/photo_manager)
- [Gemma model inputs](https://ai.google.dev/gemma/docs/get_started)
- [Flutter Gemma ONNX embedding runtime](https://pub.dev/documentation/flutter_gemma_onnx/latest/index.html)
- [MiniLM model card](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
- [Local notifications](https://pub.dev/packages/flutter_local_notifications)
