# SSeeker by Code2Ten

**AppBuildersPH-Code2Ten-2026** is an offline Android screenshot helpdesk. Search your permitted gallery for receipts, order details, student announcements, and other readable screenshot text, then open the supporting image.

Created by **Ralph Abaya, Kyle Israel Concepcion, Patrick Gengania, and Guienne Jairo Reyes**.

## Current build ? October 10, 2026

- SSeeker branding, cream/purple visual theme, skippable photo/magnifier opening, and the original searching-box/ta-da chatbot animation.
- Purple-arrow searches request Android photo access only when a real gallery search needs it, check cached records first, then scan up to 300 additional images per pass. If no real gallery match is found, the search deepens automatically up to three more passes (1200 attempted images maximum); **Search deeper (add 300 more)** continues manually after that. Demo examples never stop a real-gallery search. No upload or photo picker. Optional **Scan gallery** indexes the accessible library, with pause and retry controls.
- Screenshot filenames are prioritized. A saved metadata catalog resumes completed work; unchanged indexed assets skip OCR. New/edited timestamp or dimension changes are checked incrementally, with daily full reconciliation.
- Bundled ML Kit Text Recognition v2 (Latin) extracts text. Reduced-size OCR retries at original resolution on sparse/tiny-text results or failure; source copies and OCR coordinates retain original dimensions.
- Sentence parsing, amounts/date hints, whole-word search, exact identifiers/quoted constraints, and cautious spelling tolerance. Structured evidence responses keep raw OCR in the detail view.
- Bundled **all-MiniLM-L6-v2 quantized ARM64 ONNX** supplies 384-dimensional semantic vectors stored in ObjectBox HNSW. Semantic preparation is bounded and deferred from the OCR scan loop. Approximate/semantic results are labeled as possible matches.
- Confirmed-search semantic memory can help later similar requests. It does not retrain the model. Frequent-search counts are separate usage history.
- **Explore your box** uses All, Receipts, Orders, and Announcements folders with lazy thumbnail grids. All includes uncategorized records. These virtual folders do not move gallery originals.
- **Most Frequently Searched** shows five query shortcuts with counts; up to 100 distinct normalized queries are saved privately on Android. Clear this history independently. Recently found screenshot history is session-only.
- Shared ObjectBox initialization prevents duplicate-store errors, supports hot restart, and preserves existing indexed data. Failed scanner startup can retry.

Chrome is a UI/demo preview with fictional examples; Android results use real permitted local images. No generative LLM or cloud API is used. Downloads are needed to set up Flutter/dependencies; bundled models support local runtime. Fresh-install release airplane-mode acceptance remains pending.

## Run from a fresh checkout

Use Flutter/Dart compatible with `sdk: ^3.13.3` (verified locally with Flutter 3.47.3 / Dart 3.13.3), Git, and Android SDK tools. Run commands from the folder containing **pubspec.yaml**, not your Flutter SDK directory.

```sh
git clone https://github.com/JaiReyes45/AppBuildersPH-Code2Ten-2026.git
cd AppBuildersPH-Code2Ten-2026
flutter doctor
flutter pub get
flutter devices
flutter run -d <android-device-id> -t lib/main.dart
```

Enable USB debugging on your phone, authorize the computer, and substitute its listed device ID. Grant **Allow all photos** when prompted for full gallery search. Selected-only permission limits the accessible images. Keep the app open during indexing; it currently runs in the foreground.

For a UI preview:

```sh
flutter run -d chrome
```

Chrome DevTools: F12, then Ctrl+Shift+M for phone dimensions. Web preview does not test Android gallery/OCR or native semantic inference. In VS Code, open the repository folder, select your Android device, and press F5.

For an existing checkout, pull the latest changes before installing dependencies. Preserve your local work before pulling.

## Try the app

1. Ask for text you know exists in a local screenshot, such as a receipt amount and recipient or an announcement topic.
2. Tap the purple arrow; grant photo permission if needed. Cached matches return quickly; otherwise watch scan progress. Cancel with Start again.
3. Open a candidate to inspect the actual image and extracted fields. Check approximate matches rather than treating similarity as verification.
4. Return to the home screen and open a folder under Explore your box. Repeat a query from Most Frequently Searched.
5. Use Scan gallery to check newly added images or pre-index the library. Clear scan deletes app-owned copies/index data, never gallery originals.

The first scan generally performs the most work. Metadata refresh, image preparation, and missing semantic vectors can still add latency later. Do not erase the index to update the app.

## Build an APK

```sh
flutter build apk --debug --target-platform android-arm64 -t lib/main.dart
flutter install -d <android-device-id>
```

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. This build has been built, installed, and launched on the connected Samsung A54. For distribution:

```sh
flutter build apk --release --target-platform android-arm64 -t lib/main.dart
```

Configure release signing for distribution and validate the release APK on a physical device. Release installation, cold offline startup, and signing are not yet verified. Do not commit signing keys or APKs.

## Checks and storage rules

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

Latest app verification: **75 Flutter tests passed**, static analysis clean, and Android ARM64 debug APK built and installed. The core suite was rerun and passed **25 Dart tests**. See [SYSTEM_CHECK.md](SYSTEM_CHECK.md) for native checks and [SEARCH_PERFORMANCE.md](SEARCH_PERFORMANCE.md) for timing observations and limits.

Windows ObjectBox tests need the matching ObjectBox C 5.3.2 native library on the test process PATH. Obtain it from the official ObjectBox C releases; do not commit desktop DLLs. Android libraries are bundled by the plugin.

Keep `lib/objectbox-model.json` and `lib/objectbox.g.dart` together in version control. Preserve entity/property IDs. Regenerate only when changing entities:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Keep **path_provider_android 2.2.23 pinned**: 2.3.1 failed native startup with `libdartjni.so` on the target build. ObjectBox dependencies are currently resolved to 5.3.2; commit the lockfile. Preserve namespace/application ID `com.example.gallery_helpdesk` to retain installed app data.

Model provenance, hashes, license, tokenizer, and weights are in `assets/models/`. Keep these assets bundled for offline inference; do not replace only the weights without validating tokenizer/pooling/vector compatibility.

## Known limits and next build

- OCR/text embeddings cannot recognize artwork or faces whose identifying text is absent. English-first sentence parsing and simple recipient patterns do not cover arbitrary negation, multi-clause requests, or all Taglish wording.
- Semantic thresholds are heuristic and have not been calibrated against a labeled gallery benchmark. Similarity is not proof of an exact screenshot or payment authenticity.
- Small/blurry text can still be missed. Resize/encoding cost needs measurement across varied images.
- Timestamp-based change detection can miss edits when metadata is unchanged; permission/deletion reconciliation and retained private copies need explicit product decisions.
- Search date hints filter by gallery asset creation time, not the transaction/event date printed inside a screenshot. Date matching uses the device's local calendar with Monday as the week start; legacy or picker records without asset timestamps are excluded from date-filtered real-gallery results.
- Automatic query scanning is capped at 1200 attempted images (four 300-image passes). Failed OCR assets are excluded from counts and coverage, retried on a later search, and not repeated in another pass of the same search. Coverage is recorded for exact requested date ranges; overlapping ranges are intentionally not merged.
- Reminder UI is a preview; notification scheduling/delivery is unfinished. Individual-record deletion has storage APIs but no final UI.
- Local storage is not automatically encrypted. No perfect relevance, full-library benchmark, device-specific OCR accuracy, or release airplane-mode acceptance is claimed.

Collaborators: read **[NEXT_BUILD.md](NEXT_BUILD.md)** for changes, suggested four-person ownership, priorities, and acceptance criteria. [TEAM.md](TEAM.md) preserves the original role plan; [PROJECT_HISTORY.md](PROJECT_HISTORY.md) preserves earlier planning and happy-path/edge-case targets. [PREVIEW.md](PREVIEW.md) contains the visual guide; older preview images may differ from the latest folders.
