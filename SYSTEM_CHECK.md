# Android system check — October 10, 2026

## Reproduced failure

Samsung A54 (SM-A546E), Android 16, with full media permission granted:
`path_provider_android 2.3.1` threw `Failed to load dynamic library at path: libdartjni.so` from `getApplicationDocumentsDirectory`. This prevented storage initialization, before any gallery scan. No database wipe or permission reset was needed.

## Fix

- Pin `path_provider_android` to 2.2.23, using the pre-JNI platform-channel implementation. The package changelog records the JNI migration at 2.3.0: https://pub.dev/packages/path_provider_android/changelog.
- Clear failed scanner initialization futures so retry can recover.
- Retry startup from Scan gallery/search and show initialization failure in the existing gallery panel.
- Retain the existing Balik UI, bot animations, source previews and picker-free workflow.

## Verified on the connected phone

| Layer | Observed result |
| --- | --- |
| Storage startup | Opened successfully; persisted records loaded after restart |
| Permission | Granted, not limited |
| Gallery enumeration | Native media query returned two real assets |
| OCR | Two images produced 17 and 26 text blocks |
| Evidence copies | Both saved images decoded successfully |
| Query scan queue | Two additional images processed; `ready`, zero failures in that pass |
| Keyword search | Returned a source using a term from real OCR; no personal text logged |
| MiniLM | Bundled model returned a 384-dimensional vector |
| Native ObjectBox HNSW | Retrieved stored chunks using a document's own embedding |
| Semantic candidate filtering | Completed without native error; the diagnostic single-word query produced zero candidates, so this is not a relevance benchmark |

Automated verification: 63 Flutter tests, 14 standalone core tests, and Flutter static analysis passed. A new regression test verifies recovery after initialization failure. The normal Android debug APK builds successfully.

## Reproduce native checks

```sh
flutter run -d <android-device-id> -t tool/device_check.dart
```

This diagnostic uses the app's existing local database. It scans the two newest accessible images and up to two additional unindexed images, adds their normal local OCR/semantic records, tests saved-image decoding and retrieval, then opens the normal UI. It logs counts/status, not recognized text or images. It does not erase data. Use the normal target afterward:

```sh
flutter run -d <android-device-id> -t lib/main.dart
```

Full-library completion, battery/latency benchmarks, fresh-install airplane-mode behavior, release signing/build validation, and retrieval quality across varied Filipino/Taglish screenshots remain unverified. OCR text embeddings cannot identify visual content absent from the recognized text. No claim of perfect screenshot matching is made.


## SSeeker update verification

- Launcher/header/welcome/web naming updated; information sheet credits all four Code2Ten members and scrolls on small screens.
- 69 Flutter tests pass, including screenshot priority, persisted completion state across scanner restart, edited-image rescan, deferred semantic backfill, and the information sheet.
- Native diagnostic passes with reduced OCR input: two images retained 17 and 26 recognized text blocks, saved-image decoding and vector retrieval succeeded.
- First metadata refresh: 341.9 ms. Subsequent refresh after restart using the saved catalog: 40.5 ms. Both scan queues reported zero pending images because those assets were already indexed. The diagnostic separately re-OCRs its two sample assets by design; normal queue scanning skips them.
- These two runs are not a controlled full-library performance benchmark. Resize/encoding took roughly 350?366 ms per sampled image and needs broader comparison against original-size OCR.
- See README for timestamp-based change-detection limitations and the 24-hour metadata reconciliation policy. No data was wiped.


## Duplicate-store and typo-search fix

The reported OBX_ERROR 10001 is addressed through shared in-flight gallery-storage initialization, one ObjectBox wrapper per directory, and attaching to native stores retained across hot restart. No database was deleted. On the connected phone, concurrent storage reuse and a hot restart both completed; 1,343 records loaded with zero failed records, and OCR, image decoding, keyword retrieval and native vector checks passed.

71 Flutter tests and 25 core tests pass. Added tests cover concurrent open/reopen persistence, `screenshit of charizard card`, transposed `charziard`, unrelated-name rejection and protected literal identifiers. Fuzzy matches are tentative; OCR must still contain a recognizable word. No visual character/card identification model was added.

### Organized box and frequent searches

Explore your box now uses All, Receipts, Orders, and Announcements folders instead of expanding every image on the home screen. All also includes uncategorized images. Open a folder to browse a lazy thumbnail grid and tap an image to view its source. These are virtual collections; originals are not moved.

Most Frequently Searched shows the top five submitted queries, grouped by lowercase text and whitespace, with counts. Tap one to repeat the normal search. Counts are saved privately on Android (up to 100 distinct queries); web previews keep session counts. Deep-search continuation does not increase counts. These counts describe searches, not verified matches or model learning. Use Clear frequent searches to delete this history independently of scans. The chatbot animation and OCR/search pipeline remain in place.
