import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/admin_main.dart';

import 'admin_test.dart' show FakeAdmin;

void main() {
  testWidgets(
    'admin edits rewards, rejects invalid action rate and accepts zero invite',
    (tester) async {
      final api = FakeAdmin();
      await tester.pumpWidget(
        MaterialApp(home: AdminCoinSettings(gateway: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(api.amounts['follow'], 1);
      await tester.enterText(find.byType(TextField), '40');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.amounts['follow'], 40);
      expect(find.text('40 coins'), findsOneWidget);
      await tester.tap(find.text('Each referral'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.amounts['invite'], 0);
    },
  );

  testWidgets(
    'PIN setup and forgotten PIN reset require OTP with resend cooldown',
    (tester) async {
      var sent = 0, saved = 0;
      String? submittedOtp;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) => ReleasePinDialog(
                    setup: true,
                    changing: true,
                    sendOtp: () async {
                      sent++;
                    },
                    savePin: (pin, otp) async {
                      saved++;
                      submittedOtp = otp;
                      return saved == 1 ? 'otp_required' : 'ok';
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.enterText(find.byType(TextField).at(2), '1234');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, 0);
      expect(find.text('Send and verify a fresh email OTP.'), findsOneWidget);
      await tester.tap(find.text('Send email OTP'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).at(0), '123456');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(submittedOtp, '123456');
      expect(find.byType(ReleasePinDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send email OTP'));
      await tester.pumpAndSettle();
      expect(sent, 2);
      await tester.enterText(find.byType(TextField).at(0), '654321');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, 2);
      expect(submittedOtp, '654321');
      expect(find.byType(ReleasePinDialog), findsNothing);
    },
  );

  testWidgets(
    'campaign displays configured total, sends rate and reloads on stale rate',
    (tester) async {
      var reward = 4, loads = 0, calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          home: CreateCampaign(
            loadRates: () async {
              loads++;
              return [
                {'key': 'follow', 'amount': reward},
              ];
            },
            controls: Stream.value([
              {'action_type': 'follow', 'enabled': true},
            ]),
            reserve: (type, link, count, rate) async {
              calls++;
              expect(
                [type, link, count, rate],
                ['follow', 'https://instagram.com/example/', 3, 4],
              );
              reward = 5;
              throw StateError('rate changed');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'https://instagram.com/example/',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pumpAndSettle();
      expect(find.text('Total cost: 12 coins'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create campaign'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create campaign'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(loads, 2);
      expect(find.text('Total cost: 15 coins'), findsOneWidget);
    },
  );
}
