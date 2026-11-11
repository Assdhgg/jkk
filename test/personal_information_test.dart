import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/personal_information.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==';
const user = User(
  id: 'u',
  appMetadata: {},
  userMetadata: {'full_name': 'Test User'},
  aud: 'authenticated',
  email: 'old@example.test',
  createdAt: '2026-01-02T00:00:00Z',
);

class FakePersonalGateway implements PersonalInformationGateway {
  Uint8List? photo;
  String? mime;
  final calls = <String>[];
  bool oldFails = false;
  @override
  Future<Uint8List?> loadPhoto() async => photo;
  @override
  Future<void> savePhoto(Uint8List data, String type) async {
    photo = data;
    mime = type;
  }

  @override
  Future<void> requestEmailChange(String email) async {
    calls.add('send:$email');
  }

  @override
  Future<void> verifyOldEmail(String code) async {
    calls.add('old:$code');
    if (oldFails) throw StateError('bad code');
  }

  @override
  Future<void> verifyNewEmail(String email, String code) async {
    calls.add('new:$email:$code');
  }
}

void main() {
  testWidgets('shows personal data, copies the public ID and saves a photo', (
    tester,
  ) async {
    final api = FakePersonalGateway();
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalInformationPage(
          user: user,
          publicId: '12345678',
          gateway: api,
          picker: () async => XFile.fromData(
            base64Decode(png),
            mimeType: 'image/png',
            name: 'photo.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('old@example.test'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
    await tester.ensureVisible(find.text('Join date'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Copy user ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy user ID'));
    await tester.pumpAndSettle();
    expect(clipboard, '12345678');
    await tester.ensureVisible(find.text('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change photo'));
    await tester.runAsync(() async {
      for (var i = 0; i < 30 && api.photo == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(api.photo, base64Decode(png));
    expect(api.mime, 'image/png');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'email change can be disabled when secure configuration is unavailable',
    (tester) async {
      final api = FakePersonalGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInformationPage(
            user: user,
            publicId: null,
            gateway: api,
            emailChangeEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Change'))
            .onPressed,
        isNull,
      );
      expect(find.text('Email change is not configured yet.'), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets('old code must succeed before new code is accepted', (
    tester,
  ) async {
    final api = FakePersonalGateway()..oldFails = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalInformationPage(
          user: user,
          publicId: '12345678',
          gateway: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Change'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new_email')),
      'new@example.test',
    );
    await tester.tap(find.text('Send codes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('old_email_code')), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new_email_code')), findsNothing);
    expect(api.calls, ['send:new@example.test', 'old:123456']);
    api.oldFails = false;
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new_email_code')), '654321');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(api.calls, [
      'send:new@example.test',
      'old:123456',
      'old:123456',
      'new:new@example.test:654321',
    ]);
  });
}
