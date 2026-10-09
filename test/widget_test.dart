import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/main.dart';

import 'search_test_fakes.dart';

Widget testApp() => GalleryHelpdeskApp(
  showDemoContent: true,
  autoScanGallery: false,
  scanner: FakeOcrScanner(SearchMemoryStorage(), FakeAssetSource([])),
);

Finder get pageScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
Future<void> submit(WidgetTester tester, String text) async {
  await tester.pump(const Duration(milliseconds: 2300));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byType(TextField),
    150,
    scrollable: pageScroll,
  );
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home folders open a compact gallery without expanding home cards',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('folder-Orders')),
        200,
        scrollable: pageScroll,
      );
      expect(find.byType(EvidenceCard), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('folder-Orders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('folder-Orders')));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.textContaining('Orders ('), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Most Frequently Searched'),
        150,
        scrollable: pageScroll,
      );
      expect(find.textContaining('Your repeated searches'), findsOneWidget);
    },
  );

  testWidgets('information sheet scrolls on small phones with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('About SSeeker'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.textContaining('Clear scan removes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SSeeker information sheet explains purpose and credits the team',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(find.text('SSeeker'), findsOneWidget);
      await tester.tap(find.byTooltip('About SSeeker'));
      await tester.pumpAndSettle();
      expect(find.text('SSeeker by Code2Ten'), findsOneWidget);
      for (final name in [
        'Ralph Abaya',
        'Kyle Israel Concepcion',
        'Patrick Gengania',
        'Guienne Jairo Reyes',
      ]) {
        expect(find.textContaining(name), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vague sentence asks for details without scanning', (
    tester,
  ) async {
    final source = FakeAssetSource([fakeAsset('one', DateTime(2026))]);
    final scanner = FakeOcrScanner(SearchMemoryStorage(), source);
    await tester.pumpWidget(GalleryHelpdeskApp(scanner: scanner));
    await submit(tester, 'Could you help me please?');
    expect(source.permissionRequests, 0);
    expect(scanner.processedIds, isEmpty);
  });
  testWidgets('date-only sentence still returns gallery records', (
    tester,
  ) async {
    final scanner = FakeOcrScanner(
      SearchMemoryStorage(),
      FakeAssetSource([fakeAsset('one', DateTime(2026, 10, 8))]),
    );
    await tester.pumpWidget(GalleryHelpdeskApp(scanner: scanner));
    await submit(tester, 'Show me screenshots from October 2026');
    expect(scanner.processedIds, ['one']);
    expect(find.textContaining('Ta-da!'), findsOneWidget);
  });
  testWidgets(
    'startup requests gallery access and indexes without user selecting photos',
    (tester) async {
      final source = FakeAssetSource([fakeAsset('one', DateTime(2026))]);
      final scanner = FakeOcrScanner(SearchMemoryStorage(), source);
      await tester.pumpWidget(
        GalleryHelpdeskApp(scanner: scanner, autoScanGallery: true),
      );
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(source.permissionRequests, 1);
      expect(scanner.processedIds, ['one']);
      expect(find.text('Device gallery'), findsOneWidget);
      expect(
        find.textContaining('1 new or changed photos checked'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'purple arrow scans beyond 120 photos and returns real evidence',
    (tester) async {
      final source = FakeAssetSource(
        List.generate(
          145,
          (i) => fakeAsset('$i', DateTime(2026, 10, 10, 0, 0, 145 - i)),
        ),
      );
      final scanner = FakeOcrScanner(SearchMemoryStorage(), source);
      scanner.texts['140'] =
          'Order confirmation\nItem: purple backpack\nOrder No. BAG-1234';
      await tester.pumpWidget(GalleryHelpdeskApp(scanner: scanner));
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(source.permissionRequests, 0);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: pageScroll,
      );
      await tester.enterText(find.byType(TextField), 'purple backpack');
      await tester.ensureVisible(find.byTooltip('Find screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find screenshot'));
      await tester.pumpAndSettle();
      expect(scanner.processedIds, contains('140'));
      expect(scanner.batchSizes.length, 4);
      expect(find.textContaining('Ta-da!'), findsOneWidget);
      expect(find.textContaining('Pick photos'), findsNothing);
      expect(find.text('Demo content'), findsNothing);
    },
  );

  testWidgets('Scan gallery requests permission and can retry after denial', (
    tester,
  ) async {
    final source = FakeAssetSource([fakeAsset('one', DateTime(2026))])
      ..granted = false;
    final scanner = FakeOcrScanner(SearchMemoryStorage(), source);
    await tester.pumpWidget(GalleryHelpdeskApp(scanner: scanner));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan gallery'));
    await tester.pumpAndSettle();
    expect(source.permissionRequests, 1);
    expect(find.text('Photo permissions'), findsOneWidget);
    source.granted = true;
    await tester.tap(find.text('Scan gallery'));
    await tester.pumpAndSettle();
    expect(scanner.processedIds, ['one']);
  });

  testWidgets('first gallery result stops after the small scan batch', (
    tester,
  ) async {
    final scanner = FakeOcrScanner(
      SearchMemoryStorage(),
      FakeAssetSource(
        List.generate(
          150,
          (i) => fakeAsset('$i', DateTime(2026, 10, 10, 0, 0, 150 - i)),
        ),
      ),
    );
    scanner.texts['0'] =
        'Order confirmation\nItem: wireless headphones\nOrder No. TEST-1234';
    await tester.pumpWidget(
      GalleryHelpdeskApp(scanner: scanner, autoScanGallery: false),
    );
    await submit(tester, 'headphones');
    expect(scanner.batchSizes, [40]);
    expect(scanner.processedIds.length, 40);
  });

  testWidgets('welcome completes with reduced motion and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: StartupReveal(child: Scaffold(body: Text('Ready to search'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Skip intro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ready to search'), findsOneWidget);
    expect(find.text('Skip intro'), findsNothing);
  });

  testWidgets('welcome can be skipped and greeting controls are removed', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    expect(find.text('Skip intro'), findsOneWidget);
    await tester.tap(find.text('Skip intro'));
    await tester.pumpAndSettle();
    expect(find.byType(BotBox), findsOneWidget);
    expect(find.text('How are you doing today?'), findsNothing);
    expect(find.text('Doing great'), findsNothing);
    expect(find.text('Need a hand'), findsNothing);
  });

  testWidgets(
    'found history reopens a source and clears without removing samples',
    (tester) async {
      await tester.pumpWidget(testApp());
      await submit(tester, 'headphones');
      await tester.tap(find.byTooltip('Recently found'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wireless headphones').last);
      await tester.pumpAndSettle();
      expect(find.text('Source preview'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear session history'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your next find starts here.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('AI core search presents source evidence', (tester) async {
    await tester.pumpWidget(testApp());
    await submit(tester, 'headphones');
    expect(find.text('Ta-da! Here’s what I found.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Wireless headphones'),
      150,
      scrollable: pageScroll,
    );
    await tester.ensureVisible(find.text('Wireless headphones'));
    await tester.pumpAndSettle();
    expect(find.text('GCash · Lunch payment'), findsNothing);
    await tester.tap(find.text('Wireless headphones'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-ORDER-1028'), findsOneWidget);
    expect(find.text('Source preview'), findsOneWidget);
  });
  testWidgets('uncertain query offers category-based manual browsing', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
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
  testWidgets('AI response is shown with source-backed details', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await submit(tester, 'headphones');
    await tester.scrollUntilVisible(
      find.text('Evidence-based answer'),
      150,
      scrollable: pageScroll,
    );
    expect(find.text('Evidence-based answer'), findsOneWidget);
    expect(find.textContaining('DEMO-ORDER-1028'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Wireless headphones'),
      150,
      scrollable: pageScroll,
    );
    expect(find.text('Wireless headphones'), findsOneWidget);
  });
  testWidgets('narrow screen and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(1.5),
          disableAnimations: true,
        ),
        child: testApp(),
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
