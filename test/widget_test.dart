import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/main.dart';

Finder get pageScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
Future<void> submit(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.byType(TextField),
    150,
    scrollable: pageScroll,
  );
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(
    find.text('Let me look in the box…'),
    -150,
    scrollable: pageScroll,
  );
  expect(find.text('Let me look in the box…'), findsOneWidget);
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search animates then presents source evidence', (tester) async {
    await tester.pumpWidget(const GalleryHelpdeskApp());
    await submit(tester, 'headphones');
    expect(find.text('Ta-da! Here’s what I found.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Wireless headphones'),
      150,
      scrollable: pageScroll,
    );
    expect(find.text('GCash · Lunch payment'), findsNothing);
    await tester.tap(find.text('Wireless headphones'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-ORDER-1028'), findsOneWidget);
    expect(find.text('Source preview'), findsOneWidget);
  });
  testWidgets('uncertain query offers category-based manual browsing', (
    tester,
  ) async {
    await tester.pumpWidget(const GalleryHelpdeskApp());
    await submit(tester, 'GCash 9999');
    expect(find.text('Let’s look together.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GCash · Lunch payment'),
      150,
      scrollable: pageScroll,
    );
    expect(find.text('Wireless headphones'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Orders'),
      -100,
      scrollable: pageScroll,
    );
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Wireless headphones'),
      100,
      scrollable: pageScroll,
    );
    expect(find.text('Wireless headphones'), findsOneWidget);
  });
  testWidgets('cancel ignores late search completion', (tester) async {
    await tester.pumpWidget(const GalleryHelpdeskApp());
    await tester.enterText(find.byType(TextField), 'headphones');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Cancel search'),
      100,
      scrollable: pageScroll,
    );
    await tester.tap(find.text('Cancel search'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ta-da! Here’s what I found.'), findsNothing);
    expect(find.text('A little help finding\nwhat you saved.'), findsOneWidget);
  });
  testWidgets('narrow screen and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(1.5),
          disableAnimations: true,
        ),
        child: GalleryHelpdeskApp(),
      ),
    );
    await submit(tester, 'proposal deadline');
    await tester.scrollUntilVisible(
      find.text('Research proposal submission'),
      150,
      scrollable: pageScroll,
    );
    expect(tester.takeException(), isNull);
  });
}
