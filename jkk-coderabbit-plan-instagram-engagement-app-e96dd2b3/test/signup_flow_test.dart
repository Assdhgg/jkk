import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuth extends AuthActions {
  final calls = <String>[];
  Object? error;
  String? submittedName;
  @override
  Future<void> signup(String email, String password, {String? name}) async {
    submittedName = name;
    calls.add('signup:$email');
    if (error != null) throw error!;
  }

  @override
  Future<void> verify(String email, String code) async {
    calls.add('verify:$email:$code');
    if (error != null) throw error!;
  }

  @override
  Future<void> resend(String email) async {
    calls.add('resend:$email');
  }

  @override
  Future<void> login(String email, String password) async {
    calls.add('password:$email');
    if (error != null) throw error!;
  }
}

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('email')), 'person@example.test');
  await tester.enterText(find.byKey(const Key('password')), 'test-password');
}

Future<void> openSignup(WidgetTester tester, FakeAuth actions) async {
  await tester.pumpWidget(MaterialApp(home: AuthScreen(actions: actions)));
  await tester.tap(find.text(words['noAccount']![0]));
  await tester.pump();
  await enterCredentials(tester);
  await tester.enterText(find.byKey(const Key('name')), 'Sample Name');
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Create account'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'signup verifies six digits then requires explicit password login',
    (tester) async {
      final actions = FakeAuth();
      await openSignup(tester, actions);
      expect(actions.submittedName, 'Sample Name');
      expect(find.byKey(const Key('otp')), findsOneWidget);
      expect(find.byKey(const Key('password')), findsNothing);
      await tester.enterText(find.byKey(const Key('otp')), '12345');
      await tester.tap(find.text('Verify email'));
      await tester.pump();
      expect(actions.calls.length, 1);
      await tester.enterText(find.byKey(const Key('otp')), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'signup:person@example.test',
        'verify:person@example.test:123456',
      ]);
      expect(find.text(words['signupComplete']![0]), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('password')),
        'test-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(actions.calls.last, 'password:person@example.test');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('invalid OTP stays on verification and resend has a cooldown', (
    tester,
  ) async {
    final actions = FakeAuth();
    await openSignup(tester, actions);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Resend code (60)'),
          )
          .onPressed,
      isNull,
    );
    actions.error = const AuthException('Expired', code: 'otp_expired');
    await tester.enterText(find.byKey(const Key('otp')), '123456');
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp')), findsOneWidget);
    expect(find.text(words['expiredOtp']![0]), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(actions.calls.last, 'resend:person@example.test');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('password visibility toggle shows and hides the password', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: AuthScreen(actions: FakeAuth())));
    final field = find.byKey(const Key('password'));
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isTrue);
  });

  testWidgets(
    'Malayalam signup form presents translated name and OTP guidance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ml'),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AuthScreen(actions: FakeAuth()),
        ),
      );
      await tester.tap(find.text(words['noAccount']![1]));
      await tester.pump();
      expect(find.text(words['authName']![1]), findsOneWidget);
      expect(find.text(words['authSignupHelp']![1]), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('password failure offers signup and never requests OTP', (
    tester,
  ) async {
    final actions = FakeAuth()
      ..error = const AuthException('Invalid', code: 'invalid_credentials');
    await tester.pumpWidget(MaterialApp(home: AuthScreen(actions: actions)));
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(actions.calls, ['password:person@example.test']);
    expect(find.text(words['invalidLogin']![0]), findsOneWidget);
    expect(find.text(words['noAccount']![0]), findsOneWidget);
    expect(find.byKey(const Key('otp')), findsNothing);
  });

  testWidgets('rate limited signup waits before another email attempt', (
    tester,
  ) async {
    final actions = FakeAuth()
      ..error = const AuthException('Rate limited', statusCode: '429');
    await openSignup(tester, actions);
    expect(find.byKey(const Key('otp')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create account'),
          )
          .onPressed,
      isNull,
    );
    expect(actions.calls.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
