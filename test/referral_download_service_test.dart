import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/referral_download.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'admin link mutations use the secured RPC, including deletion',
    () async {
      final bodies = <dynamic>[];
      final client = SupabaseClient(
        'https://example.test',
        'synthetic',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/admin_set_referral_download_link',
          );
          bodies.add(jsonDecode(request.body));
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      try {
        final gateway = ReferralDownloadGateway(client);
        await gateway.save('https://updates.example.test/app.apk');
        await gateway.save(null);
        expect(bodies, [
          {'p_url': 'https://updates.example.test/app.apk'},
          {'p_url': null},
        ]);
      } finally {
        await client.dispose();
      }
    },
  );
}
