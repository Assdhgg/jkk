import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'review calls use the same submission ID for evidence and decision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        final data = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        requests.add({'path': request.uri.path, ...data});
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/get_claim_evidence')) {
          request.response.write(
            jsonEncode({'mime': 'image/png', 'data': 'aW1hZ2U='}),
          );
        } else {
          request.response.write('null');
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-key',
      );
      try {
        final api = ReviewApi(client);
        final proof = ClaimProof(Uint8List.fromList([1, 2, 3]), 'image/png');
        await api.submit('campaign-id', 'person', proof);
        final evidence = await api.evidence(
          'campaign-id',
          'participant-id',
          'submission-id',
        );
        await api.decide(
          'campaign-id',
          'participant-id',
          'submission-id',
          true,
        );
        await api.withdraw('campaign-id');
        expect(evidence['data'], 'aW1hZ2U=');
        expect(requests.map((r) => r['path']), [
          '/rest/v1/rpc/submit_claim',
          '/rest/v1/rpc/get_claim_evidence',
          '/rest/v1/rpc/review_claim',
          '/rest/v1/rpc/withdraw_claim',
        ]);
        expect(requests[0]['p_evidence'], 'AQID');
        expect(requests[0]['p_instagram_handle'], 'person');
        expect(requests[1]['p_submission_id'], 'submission-id');
        expect(requests[2]['p_submission_id'], 'submission-id');
        expect(requests[2]['p_approve'], true);
      } finally {
        await client.dispose();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
}
