import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_operations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final cancel in [true, false]) {
    testWidgets(
      'unenrolled admin must ${cancel ? 'cancel' : 'verify'} MFA setup',
      (tester) async {
        final paths = <String>[];
        final session = {
          'access_token': 'synthetic-access',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'synthetic-admin',
            'aud': 'authenticated',
            'email': 'admin@example.test',
            'created_at': '2026-11-11T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
            'factors': [],
          },
        };
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.test',
            'synthetic',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((r) async {
              paths.add('${r.method} ${r.url.path}');
              Object body = session;
              if (r.url.path == '/auth/v1/factors') {
                body = {
                  'id': 'factor',
                  'type': 'totp',
                  'totp': {
                    'secret': 'SYNTHETICSETUP',
                    'qr_code': '<svg/>',
                    'uri': 'otpauth://synthetic',
                  },
                };
              } else if (r.url.path.endsWith('/challenge')) {
                body = {'id': 'challenge', 'expires_at': 2000000000};
              } else if (r.method == 'DELETE') {
                body = {'id': 'factor'};
              }
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ))!;
        await tester.runAsync(
          () => client.auth.signInWithPassword(
            email: 'admin@example.test',
            password: 'synthetic',
          ),
        );
        bool? verified;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    verified = await verifyAdminMfa(context, client);
                  },
                  child: const Text('Begin'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Begin'));
        await tester.pumpAndSettle();
        expect(find.text('Set up administrator MFA'), findsOneWidget);
        expect(verified, null);
        if (cancel) {
          await tester.tap(find.text('Cancel'));
        } else {
          await tester.enterText(find.byType(TextFormField), '123456');
          await tester.tap(find.text('Verify'));
        }
        await tester.pumpAndSettle();
        expect(verified, !cancel);
        expect(paths.contains('DELETE /auth/v1/factors/factor'), cancel);
        expect(paths.contains('POST /auth/v1/factors/factor/verify'), !cancel);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(client.dispose);
      },
    );
  }
}
