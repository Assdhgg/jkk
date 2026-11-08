import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('PIN email OTP is verified in an isolated session and cannot reset another account', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((r) async {
      final raw = await utf8.decoder.bind(r).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add({
        'path': r.uri.path,
        'auth': r.headers.value('authorization'),
        'body': body,
      });
      r.response.headers.contentType = ContentType.json;
      if (r.uri.path == '/auth/v1/token' || r.uri.path == '/auth/v1/verify') {
        final verifying = r.uri.path.endsWith('verify');
        if (body['token'] == '000000') {
          r.response.statusCode = 403;
          r.response.write(
            jsonEncode({'msg': 'OTP expired', 'error_code': 'otp_expired'}),
          );
        } else {
          r.response.write(
            jsonEncode({
              'access_token': verifying
                  ? 'verified-otp-session'
                  : 'primary-password-session',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': body['token'] == '999999' ? 'other-user' : 'same-user',
                'aud': 'authenticated',
                'email': 'person@example.test',
                'created_at': '2026-11-08T00:00:00Z',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
              },
            }),
          );
        }
      } else if (r.uri.path.endsWith('set_release_pin')) {
        r.response.write(jsonEncode('ok'));
      } else {
        r.response.write('{}');
      }
      await r.response.close();
    });
    SupabaseClient newClient() => SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final primary = newClient();
    final gateway = SupabaseProfileGateway(
      primary,
      otpClientFactory: newClient,
    );
    try {
      expect(await gateway.setPin('1234', '123456'), 'otp_required');
      await primary.auth.signInWithPassword(
        email: 'person@example.test',
        password: 'synthetic-password',
      );
      await gateway.sendPinOtp();
      expect(
        requests.singleWhere((r) => r['path'] == '/auth/v1/otp')['body'],
        containsPair('email', 'person@example.test'),
      );
      expect(
        requests.singleWhere((r) => r['path'] == '/auth/v1/otp')['body'],
        containsPair('create_user', false),
      );
      expect(await gateway.setPin('1234', '123456'), 'ok');
      final verification = requests.singleWhere(
        (r) => r['path'] == '/auth/v1/verify',
      );
      expect(verification['body'], containsPair('type', 'email'));
      expect(verification['body'], containsPair('token', '123456'));
      final rpc = requests.singleWhere(
        (r) => r['path'] == '/rest/v1/rpc/set_release_pin',
      );
      expect(rpc['auth'], 'Bearer verified-otp-session');
      expect(rpc['body'], {'p_pin': '1234', 'p_current_pin': null});
      expect(
        primary.auth.currentSession!.accessToken,
        'primary-password-session',
      );
      expect(await gateway.setPin('9999', '999999'), 'otp_required');
      await expectLater(
        gateway.setPin('9999', '000000'),
        throwsA(isA<AuthException>()),
      );
      expect(
        requests.where((r) => r['path'] == '/rest/v1/rpc/set_release_pin'),
        hasLength(1),
      );
      expect(
        primary.auth.currentSession!.accessToken,
        'primary-password-session',
      );
    } finally {
      await primary.dispose();
      await server.close(force: true);
      await subscription.cancel();
    }
  });
}
