import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('participant sees only an active review of the same submission', (
    tester,
  ) async {
    final claim = {
      'campaign_id': 'c',
      'user_id': 'u',
      'submission_id': 's',
      'status': 'pending',
    };
    Widget screen(List<Map<String, dynamic>> presence) => MaterialApp(
      home: Scaffold(
        body: SubmissionStatus(claim: claim, presence: presence),
      ),
    );
    final active = {
      'campaign_id': 'c',
      'user_id': 'u',
      'submission_id': 's',
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 2))
          .toIso8601String(),
    };
    await tester.pumpWidget(screen([active]));
    expect(find.text(words['adminReviewing']![0]), findsOneWidget);
    await tester.pumpWidget(
      screen([
        {...active, 'submission_id': 'old'},
      ]),
    );
    expect(find.text(words['pending']![0]), findsOneWidget);
    await tester.pumpWidget(
      screen([
        {
          ...active,
          'expires_at': DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        },
      ]),
    );
    expect(find.text(words['pending']![0]), findsOneWidget);
    claim['status'] = 'approved';
    await tester.pumpWidget(screen([active]));
    expect(find.text(words['approved']![0]), findsOneWidget);
  });
}
