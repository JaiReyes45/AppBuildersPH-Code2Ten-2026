import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/candidate_modal.dart';
import 'package:gallery_helpdesk/gallery_scanner.dart';

const candidate = GalleryCandidate(
  assetId: 'candidate-1',
  displayName: 'Screenshot.png',
  imagePath: null,
  blocks: [GalleryScanBlock(id: 'block-1', text: 'Diancie card')],
  assetCreatedAt: null,
);

Widget modalHarness({required ValueChanged<CandidateAction?> onResolved}) =>
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showDialog<CandidateAction>(
                  context: context,
                  builder: (dialogContext) => CandidateModal(
                    candidate: candidate,
                    onStopAsking: () =>
                        Navigator.of(dialogContext)
                            .pop(CandidateAction.stopAsking),
                  ),
                );
                onResolved(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Yes resolves with accept', (tester) async {
    CandidateAction? result;
    await tester.pumpWidget(
      modalHarness(onResolved: (value) => result = value),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text("Is this what you're looking for?"), findsOneWidget);
    await tester.tap(find.text("Yes, that's it"));
    await tester.pumpAndSettle();

    expect(result, CandidateAction.accept);
  });

  testWidgets('No resolves with reject', (tester) async {
    CandidateAction? result;
    await tester.pumpWidget(
      modalHarness(onResolved: (value) => result = value),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, keep looking'));
    await tester.pumpAndSettle();

    expect(result, CandidateAction.reject);
  });

  testWidgets('Stop asking invokes callback and resolves', (tester) async {
    CandidateAction? result;
    var stopCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<CandidateAction>(
                  context: context,
                  builder: (dialogContext) => CandidateModal(
                    candidate: candidate,
                    onStopAsking: () {
                      stopCalled = true;
                      Navigator.of(dialogContext)
                          .pop(CandidateAction.stopAsking);
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop asking for this query'));
    await tester.pumpAndSettle();

    expect(stopCalled, isTrue);
    expect(result, CandidateAction.stopAsking);
  });
}
