import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('referral download uses the latest published release for both providers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Uri>[];
    const path = '12345678-1234-1234-1234-123456789abc.apk';
    Map<String, dynamic>? row = {
      'version_code': 15,
      'version_name': '1.1.7',
      'apk_path': path,
      'sha256': 'a' * 64,
      'size_bytes': 100,
      'notes': '',
      'storage_provider': 'r2',
      'download_url': 'https://updates.example.test/releases/$path',
    };
    final subscription = server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(row == null ? [] : [row]));
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
    );
    final gateway = SupabaseProfileGateway(client);
    try {
      expect(
        await gateway.latestAppDownloadUrl(),
        'https://updates.example.test/releases/$path',
      );
      expect(requests.last.path, '/rest/v1/app_releases');
      expect(
        requests.last.queryParameters['order'],
        startsWith('version_code.desc'),
      );
      expect(requests.last.queryParameters['limit'], '1');
      row = {...row, 'storage_provider': 'supabase', 'download_url': null};
      expect(
        await gateway.latestAppDownloadUrl(),
        'http://127.0.0.1:${server.port}/storage/v1/object/public/app-releases/$path',
      );
      row = null;
      expect(await gateway.latestAppDownloadUrl(), isNull);
      row = {
        'version_code': 15,
        'version_name': '1.1.7',
        'apk_path': path,
        'sha256': 'a' * 64,
        'size_bytes': 100,
        'storage_provider': 'r2',
        'download_url': 'http://invalid.example.test/app.apk',
      };
      await expectLater(gateway.latestAppDownloadUrl(), throwsFormatException);
    } finally {
      await client.dispose();
      await server.close(force: true);
      await subscription.cancel();
    }
  });

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
          case '/rest/v1/coin_settings':
            request.response.write(
              jsonEncode([
                {'key': 'invite', 'amount': 100},
              ]),
            );
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
        expect(info.referralRewards, {'invite': 100});
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
        expect(await api.setPin('1234', '123456'), 'otp_required');
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
