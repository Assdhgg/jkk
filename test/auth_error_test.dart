import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('known authentication error codes are actionable', () {
    const examples = {
      'email_address_not_authorized': 'emailNotAuthorized',
      'email_not_confirmed': 'emailNotConfirmed',
      'over_email_send_rate_limit': 'tooManyRequests',
      'over_request_rate_limit': 'tooManyRequests',
      'user_already_exists': 'emailInUse',
      'email_exists': 'emailInUse',
      'signup_disabled': 'signupUnavailable',
      'weak_password': 'passwordRequirements',
      'invalid_credentials': 'invalidLogin',
    };
    for (final entry in examples.entries) {
      expect(
        authErrorKey(AuthException('message', code: entry.key)),
        entry.value,
      );
    }
    expect(authErrorKey(AuthRetryableFetchException()), 'connectionError');
    expect(
      authErrorKey(AuthRetryableFetchException(statusCode: '503')),
      'serviceUnavailable',
    );
  });

  test('5xx email and database errors retain their actionable category', () {
    expect(
      authErrorKey(
        AuthRetryableFetchException(
          message: '{"msg":"Error sending reauthentication email"}',
          statusCode: '500',
        ),
      ),
      'confirmationEmailFailed',
    );
    expect(
      authErrorKey(
        AuthRetryableFetchException(
          message: '{"code":"unexpected_failure","msg":"Error sending confirmation email"}',
          statusCode: '500',
        ),
      ),
      'confirmationEmailFailed',
    );
    expect(
      authErrorKey(
        AuthRetryableFetchException(
          message: '{"code":"unexpected_failure","msg":"Database error saving new user"}',
          statusCode: '500',
        ),
      ),
      'accountCreationFailed',
    );
    expect(
      authErrorKey(
        AuthRetryableFetchException(
          message: '<html>upstream error</html>',
          statusCode: '502',
        ),
      ),
      'serviceUnavailable',
    );
  });

  testWidgets('5xx errors show HTTP status without exposing server details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Text(
              friendlyError(
                context,
                AuthRetryableFetchException(
                  message: '{"msg":"Error sending confirmation email","detail":"private@example.test smtp password"}',
                  statusCode: '500',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    expect(find.textContaining('verification email'), findsOneWidget);
    expect(find.textContaining('private@example.test'), findsNothing);
    expect(find.textContaining('smtp password'), findsNothing);
  });

  testWidgets('blocked app access explains the restriction', (tester) async {
    const error = PostgrestException(message: 'Account access is blocked.');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Text(friendlyError(context, error)),
          ),
        ),
      ),
    );
    expect(find.text(words['accountBlocked']![0]), findsOneWidget);
  });

  testWidgets('unknown errors show safe code without server message', (
    tester,
  ) async {
    const error = AuthException(
      'private@example.test',
      code: 'unexpected_failure',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Text(friendlyError(context, error)),
          ),
        ),
      ),
    );
    expect(find.textContaining('unexpected_failure'), findsOneWidget);
    expect(find.textContaining('private@example.test'), findsNothing);
  });

  testWidgets('email delivery errors explain the problem in Malayalam', (
    tester,
  ) async {
    const error = AuthException(
      'server text',
      code: 'email_address_not_authorized',
    );
    await tester.pumpWidget(const GrowthApp(configured: false));
    toggleLanguage();
    await tester.pump();
    final context = tester.element(find.byType(SetupScreen));
    expect(friendlyError(context, error), words['emailNotAuthorized']![1]);
    toggleLanguage();
  });
  testWidgets('unknown HTTP errors show status without private details', (
    tester,
  ) async {
    const error = AuthException('private@example.test', statusCode: '400');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Text(friendlyError(context, error)),
          ),
        ),
      ),
    );
    expect(find.textContaining('HTTP 400'), findsOneWidget);
    expect(find.textContaining('private@example.test'), findsNothing);
  });
}
