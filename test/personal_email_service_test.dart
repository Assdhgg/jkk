import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/personal_information.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('email change verifies current then new address without replacing the session early', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    Map<String, Object?> user(String email, {String id = 'same-user'}) => {
      'id': id,
      'aud': 'authenticated',
      'email': email,
      'created_at': '2026-11-08T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    };
    Map<String, Object?> session(
      String email,
      String access, {
      String id = 'same-user',
    }) => {
      'access_token': access,
      'refresh_token': 'synthetic-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': user(email, id: id),
    };
    final sub = server.listen((r) async {
      final raw = await utf8.decoder.bind(r).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add({
        'path': r.uri.path,
        'body': body,
        'auth': r.headers.value('authorization'),
      });
      r.response.headers.contentType = ContentType.json;
      if (r.uri.path == '/auth/v1/token') {
        r.response.write(
          jsonEncode(
            r.uri.queryParameters['grant_type'] == 'refresh_token'
                ? session('new@example.test', 'new-session')
                : session('old@example.test', 'old-session'),
          ),
        );
      } else if (r.uri.path == '/auth/v1/user') {
        r.response.write(jsonEncode(user('old@example.test')));
      } else if (r.uri.path == '/auth/v1/verify') {
        if (body['token'] == '000000') {
          r.response.statusCode = 403;
          r.response.write(
            jsonEncode({'msg': 'Invalid OTP', 'error_code': 'otp_expired'}),
          );
        } else if (body['token'] == '999999') {
          r.response.write(
            jsonEncode(
              session('new@example.test', 'wrong-session', id: 'other-user'),
            ),
          );
        } else if (body['email'] == 'old@example.test') {
          r.response.write('{}');
        } else {
          r.response.write(
            jsonEncode(session('new@example.test', 'verified-session')),
          );
        }
      } else {
        r.response.write('{}');
      }
      await r.response.close();
    });
    SupabaseClient newClient() => SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final primary = newClient();
    final api = SupabasePersonalInformationGateway(primary, newClient);
    try {
      await primary.auth.signInWithPassword(
        email: 'old@example.test',
        password: 'synthetic-password',
      );
      await api.requestEmailChange('new@example.test');
      expect(requests.last['body'], containsPair('email', 'new@example.test'));
      await expectLater(
        api.verifyOldEmail('000000'),
        throwsA(isA<AuthException>()),
      );
      expect(primary.auth.currentSession?.accessToken, 'old-session');
      await expectLater(
        api.verifyOldEmail('999999'),
        throwsA(isA<AuthException>()),
      );
      expect(primary.auth.currentSession?.accessToken, 'old-session');
      await api.verifyOldEmail('123456');
      expect(primary.auth.currentSession?.accessToken, 'old-session');
      expect(requests.last['body'], containsPair('type', 'email_change'));
      expect(requests.last['body'], containsPair('email', 'old@example.test'));
      await expectLater(
        api.verifyNewEmail('new@example.test', '999999'),
        throwsA(isA<AuthException>()),
      );
      expect(primary.auth.currentSession?.accessToken, 'old-session');
      await api.verifyNewEmail('new@example.test', '654321');
      final verifies = requests
          .where((r) => r['path'] == '/auth/v1/verify')
          .toList();
      expect(verifies.last['body'], containsPair('email', 'new@example.test'));
      expect(primary.auth.currentSession?.accessToken, 'new-session');
      expect(primary.auth.currentUser?.email, 'new@example.test');
    } finally {
      await primary.dispose();
      await server.close(force: true);
      await sub.cancel();
    }
  });
}
