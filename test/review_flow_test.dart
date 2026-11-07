import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const imageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==';

void main() {
  testWidgets(
    'submission requires username and screenshot, then sends them once',
    (tester) async {
      String? submittedHandle;
      ClaimProof? submittedProof;
      final proof = ClaimProof(base64Decode(imageBase64), 'image/png');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => ClaimSubmissionDialog(
                    picker: () async => proof,
                    onSubmit: (handle, value) async {
                      submittedHandle = handle;
                      submittedProof = value;
                    },
                  ),
                ),
                child: const Text('Open submit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for review'));
      await tester.pump();
      expect(find.text(words['proofBadHandle']![0]), findsOneWidget);
      await tester.enterText(find.byKey(const Key('proof_handle')), '@person');
      await tester.tap(find.text('Submit for review'));
      await tester.pump();
      expect(find.text(words['proofRequired']![0]), findsOneWidget);
      await tester.tap(find.text('Choose screenshot'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(submittedHandle, 'person');
      expect(submittedProof, same(proof));
      expect(find.byType(ClaimSubmissionDialog), findsNothing);
    },
  );

  testWidgets(
    'owner cannot approve until evidence loads and errors remain visible',
    (tester) async {
      bool? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => ClaimReviewDialog(
                    handle: 'person',
                    loadEvidence: () async => {'data': imageBase64},
                    onDecision: (approve) async {
                      choice = approve;
                      throw const PostgrestException(
                        message: 'Campaign is no longer active.',
                      );
                    },
                  ),
                ),
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text('@person'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Enlarge screenshot'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(choice, isTrue);
      expect(find.text(words['inactive']![0]), findsOneWidget);
      expect(find.byType(ClaimReviewDialog), findsOneWidget);
    },
  );

  testWidgets('missing evidence cannot be approved but can be rejected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ClaimReviewDialog(
                  handle: 'person',
                  loadEvidence: () async => {},
                  onDecision: (_) async {},
                ),
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.text(words['reviewEmpty']![0]), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reject'))
          .onPressed,
      isNotNull,
    );
  });
}
