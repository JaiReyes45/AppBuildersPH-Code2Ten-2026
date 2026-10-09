# Gallery Helpdesk front-end preview

An interactive Flutter front-end using four fictional examples. Includes submitted keyword searches, an animated robot rummaging through a box, a “Ta-da!” result state, category filters, source details/highlights, copying a sample field, cancellation, manual browsing when a match is uncertain, and a reminder preview. The robot is drawn in Flutter, requiring no remote images or animation assets. Reduced-motion settings disable its continuous movement.

Gallery access, OCR, ObjectBox, AI inference, persistence, and notifications are not connected. Source previews are recreated text, not real screenshots. No internet is required to interact with the installed preview.

## Run in VS Code

Open this repository, run `flutter pub get`, choose a device, and press F5.

```sh
flutter run -d chrome
```

For an Android phone, enable USB debugging, connect it, run `flutter devices`, and then `flutter run -d <device-id>`.

Try “GCash 500”, “headphones”, or “proposal deadline” and submit with the arrow or keyboard search action. “GCash 9999” demonstrates uncertain results with a receipt collection for manual browsing. Switch categories to browse other samples. Cancel an active search or start again. Open a result to inspect its source. Use the information button for demo limitations.

```sh
flutter analyze
flutter test
```
