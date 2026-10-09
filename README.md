# AppBuildersPH-Code2Ten-2026

**Screenshot Inbox** — an offline Android app that helps students find instructions in screenshots, verify the source, and turn confirmed deadlines into local reminders.

> Status: planning repository. The Flutter application has not been implemented yet. Features below are acceptance criteria, not claims of completed functionality.

**Deadline:** Saturday, October 10, 2026, 10:00 AM, Asia/Manila (UTC+8).

## Product scope

Primary user: a student whose assignment announcements, schedules, and payment references are scattered across screenshots.

Demo story: import a small set of synthetic school screenshots in airplane mode, search for a research proposal deadline, open the matching source with relevant text highlighted, confirm the extracted date, and save a local reminder.

### Required MVP

- Explicitly import selected, locally available screenshots. Full-gallery indexing is not required.
- Run bundled OCR on device; show indexing progress and failures.
- Search recognized text by keyword and exact reference number.
- Display the original screenshot, recognized text, and matching OCR boxes.
- Persist imported images, OCR results, and indexing state locally.
- Suggest deadline candidates; require date/time confirmation before scheduling a reminder.
- Schedule local notifications and expose saved reminders in the app.
- Delete an imported screenshot and its associated index; separately confirm removal of linked reminders.
- Work after a fresh installation in airplane mode, including the first OCR run.

### Conditional feature: semantic search

Include semantic search only if a bundled embedding model runs on the actual target Android phone by 4:30 PM on October 9. Otherwise ship real OCR plus keyword search and clearly describe semantic search as future work. If judging specifically requires embeddings or generative AI, resolve that requirement during kickoff; do not claim a missing feature.

### Stretch features

Visual similarity, automatic related screenshot grouping, whole-gallery scanning, share-to-app import, multilingual semantic search, and duplicate-content detection. Do not put these on the critical path. No chatbot or large vision language model is required for the MVP.

## Proposed technology stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Mobile app | Flutter + Dart; Android first | Existing developer setup has Flutter 3.47.7 / Dart 3.13.5. Pin compatible package versions after testing. |
| State | flutter_riverpod | Represent import/index/search/reminder states explicitly. |
| Imports | image_picker | Start with selected images; photo_manager is optional for album browsing later. |
| OCR | google_mlkit_text_recognition | Use bundled native OCR dependencies. Verify a clean offline installation. |
| Storage | drift + SQLite, path_provider | Store OCR boxes, local file paths, status, reminders, and optional vectors. |
| Exact search | SQLite full-text search or a simple token index | Preserve literal matches for IDs and dates; verify FTS support in the selected SQLite build. |
| Semantic search, conditional | flutter_gemma_onnx embedding backend + compatible all-MiniLM-L6-v2 ONNX model | Bundle weights and matching tokenizer; implement required pooling/normalization. English-first. Benchmark before integrating. |
| Ranking | Exact match + keyword score; optional cosine similarity | Text embeddings search OCR text, not visual content. |
| Reminders | flutter_local_notifications + timezone | Use Asia/Manila; choose ordinary local scheduling for the MVP, validate notification permissions and platform requirements. |
| Dates | Dart parsing rules + confirmation UI | Support explicit formats first. Relative dates require user clarification. |
| Verification | flutter analyze, targeted flutter test, physical Android testing | Emulator can support UI work; validate native AI and notifications on a phone. |

No server, API key, Firebase, hosted vector database, or runtime inference request is part of this architecture. Development/package downloads require connectivity; installed product use must not.

## Architecture and data contract

Import -> app-owned local copy -> OCR -> save index -> optional embedding -> search -> source view -> confirm deadline -> local reminder.

Keep native plugin work in its supported execution context. Run CPU ranking off the UI thread when needed; do not assume every native plugin can run in an arbitrary Dart isolate.

| Entity | Minimum fields |
| --- | --- |
| Screenshot | id, localPath, originalName, importedAt, contentHash, status, error, imageWidth, imageHeight |
| OCR block | id, screenshotId, text, boundingBox in original image coordinates |
| Optional text chunk | id, screenshotId, text, embedding, modelVersion |
| Search result | screenshotId, score, matchingBlockIds, matchReason |
| Reminder | id, screenshotId, title, confirmedDueAt, scheduledAt, notificationId, status |

Suggested service boundaries: ImportService, OcrService, ScreenshotRepository, SearchService, DeadlineParser, ReminderService. Agree on interfaces before parallel implementation. Store candidate deadline separately from the user's confirmed deadline.

## Build and run once the app exists

These commands apply after the Flutter scaffold is added; they are not executable project instructions yet.

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
| HP-01 | Fresh install offline; import 10 bundled/local synthetic screenshots | OCR runs without a first-use network download; progress completes; imports remain after restart. |
| HP-02 | Search an exact assignment title or reference number | Matching screenshot ranks prominently; source opens; relevant text is highlighted. |
| HP-03 | Search “research proposal deadline” | Keyword results work. If semantic feature ships, paraphrases retrieve relevant OCR text with model-based ranking. |
| HP-04 | Open an announcement with an explicit date and time | App proposes a candidate; user confirms/edits date and time; original screenshot remains visible. |
| HP-05 | Create a reminder a few minutes ahead with notification permission granted | Reminder is listed locally and the notification appears on the target phone within the documented scheduling tolerance. |
| HP-06 | Close/reopen app and repeat search in airplane mode | Images, index, and reminders persist; no cloud request is required. |
| HP-07 | Import the identical file again | Hash check avoids duplicate index records and reports the duplicate clearly. |
| HP-08 | Delete an imported screenshot | App-owned copy/index disappear; original gallery image stays intact; linked reminder handling is confirmed explicitly. |

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

## Definition of done

- Fresh release APK installed on a physical Android phone and exercised in airplane mode.
- HP-01 through HP-08 run; HP-03 semantic behavior is conditional and accurately labeled.
- No blockers in import, OCR, search, source view, persistence, or reminder confirmation.
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
- [Drift](https://pub.dev/packages/drift)
- [Flutter Gemma ONNX embedding runtime](https://pub.dev/documentation/flutter_gemma_onnx/latest/index.html)
- [MiniLM model card](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
- [Local notifications](https://pub.dev/packages/flutter_local_notifications)

