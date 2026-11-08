import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'profile gateway uses existing account, referral and PIN APIs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        final raw = await utf8.decoder.bind(request).join();
        requests.add({
          'path': request.uri.path,
          'query': request.uri.queryParameters,
          'body': raw.isEmpty ? null : jsonDecode(raw),
        });
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/functions/v1/instagram-lookup':
            final body = jsonDecode(raw) as Map<String, dynamic>;
            if (body['username'] == 'missing') {
              request.response.statusCode = 404;
              request.response.write(
                jsonEncode({'error': 'not_found_or_unsupported'}),
              );
            } else if (body['username'] == 'limited') {
              request.response.statusCode = 429;
              request.response.write(jsonEncode({'error': 'rate_limited'}));
            } else if (body['username'] == 'mismatch') {
              request.response.write(jsonEncode({'username': 'other'}));
            } else {
              request.response.write(jsonEncode({'username': 'Example'}));
            }
          case '/rest/v1/instagram_accounts':
            request.response.write(
              jsonEncode([
                {'username': 'first'},
                {'username': 'second'},
              ]),
            );
          case '/rest/v1/rpc/referral_info':
            request.response.write(
              jsonEncode({'code': 'invite', 'count': 3, 'joined': false}),
            );
          case '/rest/v1/rpc/release_pin_is_set':
            request.response.write('true');
          case '/rest/v1/rpc/set_release_pin':
            request.response.write(jsonEncode('ok'));
          default:
            request.response.write('null');
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-key',
      );
      final api = SupabaseProfileGateway(client);
      try {
        final info = await api.load('user-id');
        expect(info.usernames, ['first', 'second']);
        expect(info.referralCode, 'invite');
        expect(info.referralCount, 3);
        expect(info.pinSet, isTrue);
        expect(await api.searchInstagram('example'), 'Example');
        await expectLater(
          api.searchInstagram('missing'),
          throwsA(
            isA<InstagramLookupException>().having(
              (e) => e.code,
              'code',
              'not_found_or_unsupported',
            ),
          ),
        );
        await expectLater(
          api.searchInstagram('limited'),
          throwsA(
            isA<InstagramLookupException>().having(
              (e) => e.code,
              'code',
              'rate_limited',
            ),
          ),
        );
        await expectLater(
          api.searchInstagram('mismatch'),
          throwsA(
            isA<InstagramLookupException>().having(
              (e) => e.code,
              'code',
              'lookup_unavailable',
            ),
          ),
        );

        expect(
          requests.firstWhere(
            (r) => r['path'] == '/functions/v1/instagram-lookup',
          )['body'],
          {'username': 'example'},
        );
        await api.addAccount('@third');
        await api.removeAccount('first');
        await api.applyReferral('code');
        expect(await api.setPin('1234', '4567'), 'ok');
        expect(
          requests.singleWhere(
            (r) => r['path'] == '/rest/v1/rpc/set_release_pin',
          )['body'],
          {'p_pin': '1234', 'p_current_pin': '4567'},
        );
        final accountRequest = requests.singleWhere(
          (r) => r['path'] == '/rest/v1/instagram_accounts',
        );
        expect((accountRequest['query'] as Map)['user_id'], 'eq.user-id');
        expect(
          requests.singleWhere(
            (r) => r['path'] == '/rest/v1/rpc/add_instagram_account',
          )['body'],
          {'p_username': '@third'},
        );
        expect(
          requests.singleWhere(
            (r) => r['path'] == '/rest/v1/rpc/remove_instagram_account',
          )['body'],
          {'p_username': 'first'},
        );
        expect(
          requests.singleWhere(
            (r) => r['path'] == '/rest/v1/rpc/apply_referral',
          )['body'],
          {'p_code': 'code'},
        );
      } finally {
        await client.dispose();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
}
