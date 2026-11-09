import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/user_features.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('history searches and filters on the server', (tester) async {
    final calls = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode([
            {
              'action_type': 'like',
              'status': 'rejected',
              'campaign_link': 'https://instagram.com/p/example',
              'submitted_at': '2026-01-01',
              'rejection_reason': 'Try again',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: SubmissionHistoryPage(client: client)),
    );
    await tester.pumpAndSettle();
    expect(find.text('like · Rejected'), findsOneWidget);
    expect(find.textContaining('Reason: Try again'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'example');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(calls.last['p_query'], 'example');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved').last);
    await tester.pumpAndSettle();
    expect(calls.last['p_status'], 'approved');
    expect(calls.last['p_offset'], 0);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('rejection sends the optional explanation', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ClaimReviewDialog(
                  handle: 'person',
                  loadEvidence: () async => {},
                  onDecision: (_, _) async =>
                      fail('expected feedback callback'),
                  onRejectWithReason: (reason) async {
                    submitted = reason;
                  },
                ),
              ),
              child: const Text('Review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Try again  ');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(submitted, 'Try again');
    expect(find.byType(ClaimReviewDialog), findsNothing);
  });

  testWidgets('coin filters distinguish earned, spent and refunds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoinHistoryPage(
          uid: 'user',
          historyStream: Stream.value([
            {'amount': 2, 'reason': 'task', 'createdAt': '2026-01-03'},
            {'amount': -1, 'reason': 'campaign', 'createdAt': '2026-01-02'},
            {'amount': 1, 'reason': 'refund', 'createdAt': '2026-01-01'},
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refunds'));
    await tester.pumpAndSettle();
    expect(find.text('Campaign refund'), findsOneWidget);
    expect(find.text('Task claim'), findsNothing);
    await tester.tap(find.text('Spent'));
    await tester.pumpAndSettle();
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
  });
}
