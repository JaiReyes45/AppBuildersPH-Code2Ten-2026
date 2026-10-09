# Balik / Gallery Helpdesk preview

The UI follows the supplied Balik reference with ivory, violet and lavender,
serif headings, a shuffled photo-card welcome and a moving magnifying glass.
The welcome is decorative and skippable; it does not indicate scan coverage.
All decorative photos are bundled AI-generated assets. No remote image or
font service is used. The existing bot still searches inside its box and
presents a found screenshot.

## Run

Open this repository (the directory with `pubspec.yaml`) in VS Code:

```sh
flutter pub get
flutter run -d chrome
```

For a phone, enable USB debugging, connect it, run `flutter devices`, then
`flutter run -d <device-id>`. Restart the app to replay the opening animation.

Web is the sample/UI preview. Android supports gallery scanning, on-device
ML Kit OCR and persisted ObjectBox records. Native MiniLM embeddings and confirmed-query memory are integrated. Generative
LLM answers and notifications remain unimplemented. See README for native
setup and device-test limitations.

## Try the interactions

1. Skip the welcome or let it finish; tap **Need a hand** for a scripted tip.
2. Search **headphones**, **GCash 500**, or **proposal deadline**. These can
   return labeled fictional examples. Native gallery scanning may also run.
3. Search **GCash 9999** to explore manual category browsing.
4. Open the history icon or **Pick up where you left off**, reopen a source,
   then clear history. It retains up to 50 unique fetched screenshots during
   this session, not across restarts. Clearing it does not delete photos.
5. Test system reduced-motion and enlarged text settings. Real scan progress
   and cancel/retry controls remain available on supported phones.

## Rendered mobile previews

- [Opening](preview/balik-opening.png)
- [Home](preview/balik-home.png)
- [History](preview/balik-history.png)

Captured at 390 x 844 with desktop fonts. Platform serif rendering can differ
on Android. The native photo-permission and OCR workflows require device QA.
