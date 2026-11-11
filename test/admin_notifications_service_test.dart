import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'search and send use the editor RPC and preserve audience and request ID',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        final data = await utf8.decoder.bind(request).join();
        requests.add({'path': request.uri.path, 'body': jsonDecode(data)});
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          request.uri.path.endsWith('admin_notification_users')
              ? jsonEncode([
                  {
                    'id': 'user-id',
                    'email': 'person@example.test',
                    'display_name': 'Person',
                    'public_id': '12345678',
                  },
                ])
              : '1',
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public-key',
      );
      final api = SupabaseAdminNotificationGateway(client);
      try {
        final users = await api.search('12345678', 25);
        expect(users.single['id'], 'user-id');
        expect(await api.send('request-id', 'user-id', 'News', 'Hello'), 1);
        expect(requests[0]['path'], '/rest/v1/rpc/admin_notification_users');
        expect(requests[0]['body'], {'p_query': '12345678', 'p_offset': 25});
        expect(requests[1]['path'], '/rest/v1/rpc/admin_send_notification');
        expect(requests[1]['body'], {
          'p_request_id': 'request-id',
          'p_target_user': 'user-id',
          'p_title': 'News',
          'p_body': 'Hello',
        });
      } finally {
        await client.dispose();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
}
