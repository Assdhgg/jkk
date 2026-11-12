import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:growth_circle/push_notifications.dart';

void main() {
  test('cached FCM token enables push without registration events; refresh, denial and failed writes preserve opt-in', () async {
    SharedPreferences.setMockInitialValues({});
    final events = StreamController<String>.broadcast();
    final writes = <String>[];
    var allowed = true, fail = false, loads = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handler = server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/token')) {
        request.response.write(
          jsonEncode({
            'access_token': 'synthetic-session',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'same-user',
              'aud': 'authenticated',
              'email': 'test@example.test',
              'created_at': '2026-11-11T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
        );
      } else if (request.uri.path.endsWith('/register_push_token')) {
        if (fail) {
          request.response.statusCode = 500;
          request.response.write('{"message":"offline"}');
        } else {
          writes.add(body['p_token'] as String);
          request.response.write('null');
        }
      } else {
        request.response.write('null');
      }
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final push = PushCoordinator.forTesting(
      initialize: () async {},
      permission: () async => allowed,
      tokenLoader: () async {
        loads++;
        return 'synthetic-cached-fcm-token';
      },
      tokenChanges: events.stream,
    );
    try {
      await client.auth.signInWithPassword(
        email: 'test@example.test',
        password: 'synthetic',
      );
      allowed = false;
      expect(await push.enable(client), false);
      expect(loads, 0);
      allowed = true;
      fail = true;
      await expectLater(
        push.enable(client),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_same-user',
        ),
        isNot(true),
      );
      fail = false;
      expect(await push.enable(client), true);
      expect(writes, ['synthetic-cached-fcm-token']);
      expect(await push.isEnabled(client), true);
      fail = true;
      await expectLater(push.isEnabled(client), throwsA(isA<PostgrestException>()));
      fail = false;
      await push.detach();
      await push.restore(client);
      expect(await push.isEnabled(client), true);
      allowed = false;
      expect(await push.isEnabled(client), false);
      allowed = true;
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_same-user',
        ),
        true,
      );
      events.add('synthetic-refreshed-fcm-token');
      // Wait for the synthetic local RPC rather than an arbitrary sleep.
      for (
        var i = 0;
        i < 100 && !writes.contains('synthetic-refreshed-fcm-token');
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(writes, contains('synthetic-refreshed-fcm-token'));
      // Simulate a new process after an app update: only saved opt-in remains.
      final restored = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => allowed,
        tokenLoader: () async => 'synthetic-token-after-update',
        tokenChanges: events.stream,
      );
      fail = true;
      await restored.restore(client);
      expect(writes, isNot(contains('synthetic-token-after-update')));
      fail = false;
      await Future.wait([restored.restore(client), restored.restore(client)]);
      expect(writes.where((v) => v == 'synthetic-token-after-update').length, 1);
      allowed = false;
      final beforeDenied = writes.length;
      await restored.restore(client);
      expect(writes.length, beforeDenied);
      allowed = true;
      await (await SharedPreferences.getInstance()).setBool(
        'push_opt_in_same-user', false,
      );
      await restored.restore(client);
      expect(writes.length, beforeDenied);
      await restored.stop(client);

    } finally {
      await push.stop(client);
      await events.close();
      await client.dispose();
      await server.close(force: true);
      await handler.cancel();
    }
  });
}
