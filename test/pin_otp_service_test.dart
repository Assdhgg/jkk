import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('PIN uses authenticated Reauthentication template and nonce RPC without changing session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((r) async {
      final raw = await utf8.decoder.bind(r).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add({
        'method': r.method,
        'path': r.uri.path,
        'auth': r.headers.value('authorization'),
        'body': body,
      });
      r.response.headers.contentType = ContentType.json;
      if (r.uri.path == '/auth/v1/token') {
        r.response.write(
          jsonEncode({
            'access_token': 'primary-password-session',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'same-user',
              'aud': 'authenticated',
              'email': 'person@example.test',
              'created_at': '2026-11-08T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
        );
      } else if (r.uri.path.endsWith('set_release_pin_reauthenticated')) {
        r.response.write(
          jsonEncode(body['p_nonce'] == '123456' ? 'ok' : 'otp_required'),
        );
      } else {
        r.response.write('{}');
      }
      await r.response.close();
    });
    final primary = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final gateway = SupabaseProfileGateway(primary);
    try {
      expect(await gateway.setPin('1234', '123456'), 'otp_required');
      await expectLater(
        gateway.sendPinOtp(),
        throwsA(isA<AuthSessionMissingException>()),
      );
      await primary.auth.signInWithPassword(
        email: 'person@example.test',
        password: 'synthetic-password',
      );
      await gateway.sendPinOtp();
      final sent = requests.singleWhere(
        (r) => r['path'] == '/auth/v1/reauthenticate',
      );
      expect(sent['method'], 'GET');
      expect(sent['auth'], 'Bearer primary-password-session');
      expect(await gateway.setPin('1234', '123456'), 'ok');
      final rpc = requests.singleWhere(
        (r) => r['path'] == '/rest/v1/rpc/set_release_pin_reauthenticated',
      );
      expect(rpc['auth'], 'Bearer primary-password-session');
      expect(rpc['body'], {'p_pin': '1234', 'p_nonce': '123456'});
      expect(await gateway.setPin('9999', '000000'), 'otp_required');
      expect(
        requests.where(
          (r) => r['path'] == '/auth/v1/otp' || r['path'] == '/auth/v1/verify',
        ),
        isEmpty,
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
