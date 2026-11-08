import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'admin API sends search pagination and block decision to server RPCs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      final sub = server.listen((r) async {
        final raw = await utf8.decoder.bind(r).join();
        final decoded = raw.isEmpty ? null : jsonDecode(raw);
        final body = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        requests.add({'path': r.uri.path, ...body});
        r.response.headers.contentType = ContentType.json;
        r.response.write(
          r.uri.path.endsWith('/admin_list_campaigns')
              ? jsonEncode([
                  {
                    'id': 'campaign',
                    'owner_id': 'owner',
                    'owner_email': 'owner@example.test',
                    'type': 'like',
                    'link': 'https://instagram.com/p/A/',
                    'status': 'active',
                    'requested': 2,
                    'remaining': 1,
                  },
                ])
              : r.uri.path.endsWith('/action_controls')
              ? jsonEncode([
                  {'action_type': 'like', 'enabled': true},
                ])
              : r.uri.path.endsWith('/admin_is_admin')
              ? 'true'
              : r.uri.path.endsWith('/admin_list_users')
              ? jsonEncode([
                  {
                    'id': '1',
                    'email': 'a@example.test',
                    'display_name': 'A',
                    'created_at': '2026-01-01',
                    'coins': 10,
                    'blocked': false,
                    'is_admin': false,
                  },
                ])
              : 'null',
        );
        await r.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-key',
      );
      final api = SupabaseAdminGateway(client);
      try {
        expect(await api.isAdmin(), isTrue);
        expect((await api.users('person', 50, 50)).single.coins, 10);
        await api.setBlocked('target-id', true);
        expect((await api.actions())['like'], isTrue);
        await api.setActionEnabled('like', false);
        final campaigns = await api.campaigns('like', 'active', 30, 30);
        expect(campaigns.single.ownerEmail, 'owner@example.test');
        expect(requests[1]['p_query'], 'person');
        expect(requests[1]['p_offset'], 50);
        expect(requests[2]['p_user_id'], 'target-id');
        expect(requests[2]['p_blocked'], true);
        expect(requests[4]['path'], '/rest/v1/rpc/admin_set_action_enabled');
        expect(requests[4]['p_type'], 'like');
        expect(requests[4]['p_enabled'], false);
        expect(requests[5]['path'], '/rest/v1/rpc/admin_list_campaigns');
        expect(requests[5]['p_type'], 'like');
        expect(requests[5]['p_status'], 'active');
        expect(requests[5]['p_offset'], 30);
        expect(requests[5]['p_limit'], 30);
      } finally {
        await api.dispose();
        await server.close(force: true);
        await sub.cancel();
      }
    },
  );
  test('inspection RPCs keep the campaign, claimant, submission and session together', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add({'path': request.uri.path, ...body});
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('admin_pending_submissions')) {
        request.response.write(
          jsonEncode([
            {
              'campaign_id': 'c',
              'user_id': 'u',
              'submission_id': 's',
              'action_type': 'like',
              'campaign_link': 'https://instagram.com/p/ABC/',
            },
          ]),
        );
      } else if (request.uri.path.endsWith('admin_begin_submission_review')) {
        request.response.write(
          jsonEncode({
            'session_id': 'lease',
            'username': 'person',
            'data': 'AA==',
          }),
        );
      } else if (request.uri.path.endsWith('admin_renew_submission_review')) {
        request.response.write('true');
      } else {
        request.response.write('null');
      }
      await request.response.close();
    });
    final api = SupabaseAdminGateway(
      SupabaseClient('http://127.0.0.1:${server.port}', 'synthetic-key'),
    );
    try {
      final submission = (await api.submissions(0, 30)).single;
      final review = await api.beginReview(submission);
      expect(review['username'], 'person');
      expect(await api.renewReview('lease'), isTrue);
      await api.endReview('lease');
      expect(requests[1]['p_campaign_id'], 'c');
      expect(requests[1]['p_user_id'], 'u');
      expect(requests[1]['p_submission_id'], 's');
      expect(requests[2]['p_session_id'], 'lease');
      expect(requests[3]['p_session_id'], 'lease');
    } finally {
      await api.dispose();
      await server.close(force: true);
      await subscription.cancel();
    }
  });
  test(
    'admin RPC uses authenticated user session rather than service key',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        final raw = await utf8.decoder.bind(request).join();
        requests.add({
          'path': request.uri.path,
          'authorization': request.headers.value('authorization'),
          'body': raw,
        });
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/auth/v1/token') {
          request.response.write(
            jsonEncode({
              'access_token': 'synthetic-session-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'synthetic-refresh-token',
              'user': {
                'id': '11111111-1111-4111-8111-111111111111',
                'aud': 'authenticated',
                'email': 'admin@example.test',
                'created_at': '2026-11-07T00:00:00Z',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
              },
            }),
          );
        } else if (request.uri.path.endsWith('/admin_is_admin')) {
          request.response.write('true');
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public-key',
      );
      final api = SupabaseAdminGateway(client);
      try {
        await api.signIn('admin@example.test', 'synthetic-password');
        expect(await api.isAdmin(), isTrue);
        expect(requests[1]['path'], '/rest/v1/rpc/admin_is_admin');
        expect(requests[1]['authorization'], 'Bearer synthetic-session-token');
        await api.signOut();
        expect(client.auth.currentSession, isNull);
      } finally {
        await api.dispose();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
}
