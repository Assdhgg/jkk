import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_operations.dart';
import 'package:growth_circle/support_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('support ticket opens conversation and sends reply', (
    tester,
  ) async {
    final seen = <String>[];
    final httpClient = MockClient((r) async {
      seen.add(r.url.path);
      final body = r.url.path.endsWith('support_my_tickets')
          ? [
              {
                'id': 'ticket',
                'subject': 'Help',
                'status': 'open',
                'updated_at': 'today',
              },
            ]
          : r.url.path.endsWith('support_messages')
          ? [
              {'body': 'Hello', 'is_admin': false, 'created_at': 'today'},
            ]
          : null;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(MaterialApp(home: SupportPage(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Help'), findsOneWidget);
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Need help');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(seen, contains('/rest/v1/rpc/support_reply'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('admin resolves a campaign report', (tester) async {
    final received = <Map<String, dynamic>>[];
    final httpClient = MockClient((r) async {
      final body = r.body.isEmpty ? null : jsonDecode(r.body);
      if (body is Map<String, dynamic>) {
        received.add({'path': r.url.path, ...body});
      }
      final response = r.url.path.endsWith('admin_campaign_reports')
          ? [
              {
                'id': 'report',
                'campaign_id': 'campaign',
                'reason': 'Problem',
                'status': 'open',
              },
            ]
          : [];
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: AdminOperationsPage(client: client, canEdit: true)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Campaign reports'));
    await tester.pumpAndSettle();
    expect(find.text('Problem'), findsOneWidget);
    await tester.tap(find.text('Cancel & refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
      received
          .where((r) => r['path'] == '/rest/v1/rpc/admin_resolve_report')
          .single['p_cancel'],
      true,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
