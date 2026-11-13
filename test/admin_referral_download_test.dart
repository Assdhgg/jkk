import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_referral_download.dart';
import 'package:growth_circle/referral_download.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeLinkGateway extends ReferralDownloadGateway {
  FakeLinkGateway(super.client);
  String? link;
  bool fail = false;
  final changes = <String?>[];
  @override
  Future<String?> load() async {
    if (fail) throw StateError('offline');
    return link;
  }

  @override
  Future<void> save(String? url) async {
    if (fail) throw StateError('offline');
    changes.add(url);
    link = url;
  }
}

void main() {
  testWidgets('editor adds, edits and deletes the shared link', (tester) async {
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final gateway = FakeLinkGateway(client);
    var confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminReferralDownloadCard(
            gateway: gateway,
            canEdit: true,
            verifyChange: () async {
              confirmations++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'http://invalid.test/app.apk',
    );
    await tester.tap(find.text('Save link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid HTTPS download link.'), findsOneWidget);
    expect(confirmations, 0);
    await tester.enterText(
      find.byType(TextField),
      'https://updates.test/first.apk',
    );
    await tester.tap(find.text('Save link'));
    await tester.pumpAndSettle();
    expect(gateway.link, 'https://updates.test/first.apk');
    await tester.enterText(
      find.byType(TextField),
      'https://updates.test/second.apk',
    );
    await tester.tap(find.text('Save link'));
    await tester.pumpAndSettle();
    expect(gateway.link, 'https://updates.test/second.apk');
    await tester.tap(find.text('Delete link'));
    await tester.pumpAndSettle();
    expect(gateway.changes, [
      'https://updates.test/first.apk',
      'https://updates.test/second.apk',
      null,
    ]);
    expect(confirmations, 3);
    expect(find.text('Delete link'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('viewer can read but cannot change the link', (tester) async {
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final gateway = FakeLinkGateway(client)
      ..link = 'https://updates.test/app.apk';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminReferralDownloadCard(gateway: gateway, canEdit: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://updates.test/app.apk'), findsOneWidget);
    expect(find.text('Save link'), findsNothing);
    expect(find.text('Delete link'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
