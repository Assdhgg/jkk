import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeProfileGateway implements ProfileGateway {
  final usernames = <String>['first'];
  int referralCount = 2;
  bool joined = false, signedOut = false, failLoad = false, pinSet = false;
  @override
  Future<ProfileInfo> load(String uid) async {
    if (failLoad) throw StateError('offline');
    return ProfileInfo(
      usernames: List.of(usernames),
      referralCode: 'invite-code',
      referralCount: referralCount,
      referralJoined: joined,
      pinSet: pinSet,
    );
  }

  @override
  Stream<int?> balance(String uid) => Stream.value(42);
  @override
  Stream<List<Map<String, dynamic>>> history(String uid) => Stream.value([
    {
      'id': 'one',
      'amount': 10,
      'reason': 'welcome',
      'createdAt': '2026-03-01T00:00:00Z',
    },
  ]);
  @override
  Future<void> addAccount(String username) async {
    usernames.add(username.replaceFirst('@', ''));
  }

  @override
  Future<String> searchInstagram(String username) async {
    if (username == 'business') return 'business';
    throw const InstagramLookupException('not_found_or_unsupported');
  }

  @override
  Future<void> removeAccount(String username) async {
    usernames.remove(username);
  }

  @override
  Future<void> applyReferral(String code) async {
    if (code == 'other-code') joined = true;
  }

  @override
  Future<void> sendPinOtp() async {}
  @override
  Future<String> setPin(String pin, String? currentPin) async {
    pinSet = true;
    return 'ok';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

const user = User(
  id: 'user',
  appMetadata: {},
  userMetadata: {'full_name': 'Diana Larussa'},
  aud: 'authenticated',
  email: 'diana@example.test',
  createdAt: '2026-03-01T00:00:00Z',
);

Future<void> showProfile(
  WidgetTester tester,
  FakeProfileGateway gateway,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: growthTheme(),
      home: Scaffold(
        body: Profile(user: user, gateway: gateway, authorizeChange: () async => true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'profile shows real summary and keeps coin history and PIN accessible',
    (tester) async {
      final gateway = FakeProfileGateway();
      await showProfile(tester, gateway);
      expect(find.text('DL'), findsOneWidget);
      expect(find.text('Diana Larussa'), findsOneWidget);
      expect(find.text('diana@example.test'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.ensureVisible(find.text('Coin history'));
      await tester.tap(find.text('Coin history'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome coins'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Security PIN'));
      await tester.tap(find.text('Security PIN'));
      await tester.pumpAndSettle();
      expect(find.text('New 4-digit PIN'), findsOneWidget);
      await tester.tap(find.text('Send email OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '123456');
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.enterText(find.byType(TextField).at(2), '1234');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(gateway.pinSet, isTrue);
      expect(find.text('Change / reset PIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accounts and referral pages preserve existing actions', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    await showProfile(tester, gateway);
    await tester.ensureVisible(find.text('Instagram accounts'));
    await tester.tap(find.text('Instagram accounts'));
    await tester.pumpAndSettle();
    expect(find.text('@first'), findsOneWidget);
    await tester.tap(find.text('Add Instagram username manually'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@second');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('@second'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(gateway.usernames, ['second']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_referral_banner')));
    await tester.pumpAndSettle();
    expect(find.text('invite-code'), findsOneWidget);
    expect(find.text('People referred: 2'), findsOneWidget);
    await tester.tap(find.text('Enter a referral code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'other-code');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Referral code already applied.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings sign out and load errors can be retried', (
    tester,
  ) async {
    final gateway = FakeProfileGateway()..failLoad = true;
    await showProfile(tester, gateway);
    await tester.ensureVisible(find.text('Could not load profile details.'));
    gateway.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load profile details.'), findsNothing);
    await tester.tap(find.byTooltip('Profile settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(gateway.signedOut, isTrue);
  });
  testWidgets('profile fits a narrow screen in Malayalam', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        locale: const Locale('ml'),
        supportedLocales: const [Locale('en'), Locale('ml')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: Scaffold(
          body: Profile(user: user, gateway: FakeProfileGateway()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(words['profile']![1]), findsOneWidget);
    await tester.ensureVisible(find.text(words['releasePin']![1]));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'in-app lookup adds only a selected real result and preserves manual entry',
    (tester) async {
      final gateway = FakeProfileGateway();
      await showProfile(tester, gateway);
      await tester.ensureVisible(find.text('Instagram accounts'));
      await tester.tap(find.text('Instagram accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search Instagram username'));
      await tester.pumpAndSettle();
      expect(find.text(words['instagramSearchHelp']![0]), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add account'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'unknown');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text(words['instagramSearchNotFound']![0]), findsOneWidget);
      await tester.enterText(find.byType(TextField), '@business');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '@business'), findsOneWidget);
      expect(find.text(words['instagramSearchOwnership']![0]), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'other');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add account'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'business');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(gateway.usernames, ['first', 'business']);
      expect(find.text('@business'), findsOneWidget);
      expect(find.text('Add Instagram username manually'), findsOneWidget);
    },
  );
}
