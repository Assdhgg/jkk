import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/design.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/support_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const user = User(
    id: 'synthetic',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
  testWidgets('blocked account artwork and retry do not mask other errors', (
    tester,
  ) async {
    var calls = 0;
    Future<void> blocked() async {
      calls++;
      throw const PostgrestException(message: 'Account access is blocked.');
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: AccountGate(user: user, initializeWallet: blocked),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GrowthArt), findsOneWidget);
    expect(find.text('Freelan\nSpace'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountGate(
          key: const ValueKey('offline'),
          user: user,
          initializeWallet: () async => throw StateError('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GrowthArt), findsNothing);
  });
  testWidgets('support empty state can refresh', (tester) async {
    var loads = 0;
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: SupportPage(
          client: client,
          loadTickets: () async {
            loads++;
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No support tickets yet.'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    client.dispose();
  });
}
