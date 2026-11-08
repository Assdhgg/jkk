import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/evidence_image.dart';
import 'package:growth_circle/main.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==';

// Synthetic static 2x2 JPEG generated in a local browser canvas.
const jpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAj/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCbgKIH/9k=';

void main() {
  testWidgets('image validation rejects oversized input before rendering', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await decodeEvidenceImage(png), base64Decode(png));
      expect(await decodeEvidenceImage(jpeg), base64Decode(jpeg));
      final huge = Uint8List.fromList(base64Decode(png));
      ByteData.sublistView(huge).setUint32(16, 60000);
      ByteData.sublistView(huge).setUint32(20, 60000);
      await expectLater(validateEvidenceImage(huge), throwsA(anything));
      await expectLater(
        decodeEvidenceImage('A' * 699053),
        throwsFormatException,
      );
      await expectLater(
        decodeEvidenceImage('not-base64!'),
        throwsFormatException,
      );
      await expectLater(
        validateEvidenceImage(Uint8List(524289)),
        throwsFormatException,
      );
    });
  });

  testWidgets(
    'malformed historical evidence can be rejected but never approved',
    (tester) async {
      bool? decision;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClaimReviewDialog(
              handle: 'participant',
              loadEvidence: () async => {'data': 'A' * 699053},
              onDecision: (approve, pin) async {
                decision = approve;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(decision, false);
    },
  );
}
