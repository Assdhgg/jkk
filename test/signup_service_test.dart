import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalSignupActions extends AuthActions {
  LocalSignupActions(this.url);
  final String url;
  @override
  GoTrueClient signupClient() => GoTrueClient(
    url: url,
    autoRefreshToken: false,
    flowType: AuthFlowType.implicit,
  );
}

void main() {
  test('signup and verification use signup OTP endpoints without the app session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final user = {
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'email': 'synthetic@example.test',
      'created_at': '2026-11-07T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    };
    final subscription = server.listen((request) async {
      final body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      requests.add({'path': request.uri.path, ...body});
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(switch (request.uri.path) {
          '/signup' => user,
          '/verify' => {
            'access_token': 'synthetic-token',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          },
          _ => <String, dynamic>{},
        }),
      );
      await request.response.close();
    });
    try {
      // Supabase.instance is intentionally uninitialized. Neither operation may
      // authenticate through the main application client or persistent storage.
      final actions = LocalSignupActions('http://127.0.0.1:${server.port}');
      await actions.signup(
        'synthetic@example.test',
        'synthetic-password',
        name: '  Test User  ',
      );
      await actions.resend('synthetic@example.test');
      await actions.verify('synthetic@example.test', '123456');
      expect(requests.map((r) => r['path']), ['/signup', '/resend', '/verify']);
      expect(requests[0]['password'], 'synthetic-password');
      expect(requests[0]['data'], {'full_name': 'Test User'});
      expect(requests[1]['type'], 'signup');
      expect(requests[2]['type'], 'signup');
      expect(requests[2]['token'], '123456');
      expect(requests[2]['email'], 'synthetic@example.test');
    } finally {
      await server.close(force: true);
      await subscription.cancel();
    }
  });
}
