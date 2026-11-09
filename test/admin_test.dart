import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';

class FakeAdmin implements AdminGateway {
  FakeAdmin({this.allowed = true});
  final bool allowed;
  final amounts = {
    'registration': 10,
    'follow': 1,
    'invite': 0,
    'milestone_5': 0,
  };
  @override
  Future<List<Map<String, dynamic>>> coinSettings() async => [
    for (final e in amounts.entries) {'key': e.key, 'amount': e.value},
  ];
  @override
  Future<void> setCoinSetting(String key, int amount) async {
    amounts[key] = amount;
  }

  int signOuts = 0;
  String search = '';
  final changes = <String>[];
  bool blocked = false;
  final actionStates = {
    for (final type in ['follow', 'like', 'share', 'comment']) type: true,
  };
  final actionChanges = <String>[];
  String? campaignType, campaignStatus;
  Completer<List<AdminCampaign>>? nextCampaigns;
  Completer<Map<String, bool>>? nextActions;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<bool> isAdmin() async => allowed;
  @override
  Future<List<AdminUser>> users(String query, int offset, int limit) async {
    search = query;
    return [
          AdminUser(
            id: 'user',
            email: 'person@example.test',
            name: 'Person',
            joined: '2026-11-07T00:00:00Z',
            coins: 10,
            blocked: blocked,
            isAdmin: false,
          ),
          const AdminUser(
            id: 'admin',
            email: 'admin@example.test',
            name: 'Admin',
            joined: '2026-11-07T00:00:00Z',
            coins: 10,
            blocked: false,
            isAdmin: true,
          ),
        ]
        .where(
          (u) =>
              u.email.contains(query) ||
              u.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  final endedReviews = <String>[];
  int startedReviews = 0;
  bool renewResult = true;
  @override
  Future<List<AdminSubmission>> submissions(int offset, int limit) async =>
      offset == 0
      ? [
          const AdminSubmission(
            campaignId: 'c',
            userId: 'u',
            submissionId: 's',
            type: 'like',
            link: 'https://instagram.com/p/ABC/',
          ),
        ]
      : [];
  @override
  Future<Map<String, dynamic>> beginReview(AdminSubmission submission) async {
    startedReviews++;
    return {
      'session_id': 'session',
      'username': 'sample',
      'data': 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==',
    };
  }

  @override
  Future<bool> renewReview(String sessionId) async => renewResult;
  @override
  Future<void> endReview(String sessionId) async {
    endedReviews.add(sessionId);
  }

  @override
  Future<void> setBlocked(String userId, bool value) async {
    changes.add('$userId:$value');
    blocked = value;
  }

  @override
  Future<List<AdminCampaign>> campaigns(
    String? type,
    String? status,
    int offset,
    int limit,
  ) async {
    campaignType = type;
    campaignStatus = status;
    final pending = nextCampaigns;
    nextCampaigns = null;
    if (pending != null) return pending.future;
    return [
          const AdminCampaign(
            id: '1',
            ownerId: 'owner1',
            ownerEmail: 'owner@example.test',
            type: 'like',
            link: 'https://instagram.com/p/ABC/',
            status: 'active',
            requested: 5,
            remaining: 2,
          ),
          const AdminCampaign(
            id: '2',
            ownerId: 'owner2',
            ownerEmail: 'other@example.test',
            type: 'share',
            link: 'https://instagram.com/p/DEF/',
            status: 'completed',
            requested: 1,
            remaining: 0,
          ),
        ]
        .where(
          (c) =>
              (type == null || c.type == type) &&
              (status == null || c.status == status),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<Map<String, bool>> actions() async {
    final pending = nextActions;
    nextActions = null;
    if (pending != null) return pending.future;
    return Map.of(actionStates);
  }

  @override
  Future<void> setActionEnabled(String type, bool enabled) async {
    actionChanges.add('$type:$enabled');
    actionStates[type] = enabled;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  Future<void> dispose() async {}
}

String jwt(String role) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';
Future<void> login(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('admin_email')),
    'admin@example.test',
  );
  await tester.enterText(
    find.byKey(const Key('admin_password')),
    'synthetic-password',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  test('configuration accepts only HTTPS and public client credentials', () {
    expect(
      validAdminConfig(
        'https://project.supabase.co',
        'sb_publishable_1234567890',
      ),
      isTrue,
    );
    expect(
      validAdminConfig('https://project.supabase.co', jwt('anon')),
      isTrue,
    );
    expect(
      validAdminConfig('https://project.supabase.co', jwt('service_role')),
      isFalse,
    );
    expect(
      validAdminConfig('https://project.supabase.co', 'sb_secret_1234567890'),
      isFalse,
    );
    expect(
      validAdminConfig(
        'http://project.supabase.co',
        'sb_publishable_1234567890',
      ),
      isFalse,
    );
    expect(
      validAdminConfig(
        'https://user@project.supabase.co',
        'sb_publishable_1234567890',
      ),
      isFalse,
    );
  });
  testWidgets('non-admin credentials cannot enter dashboard', (tester) async {
    final fake = FakeAdmin(allowed: false);
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    expect(find.text(labels['unauthorized']![0]), findsOneWidget);
    expect(find.text('Users'), findsNothing);
    expect(fake.signOuts, 1);
  });
  testWidgets('admin searches and confirms block and unblock', (tester) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Block app access'), findsOneWidget);
    await tester.tap(find.text('Block app access'));
    await tester.pumpAndSettle();
    expect(fake.changes, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(fake.changes, ['user:true']);
    expect(find.text('Blocked'), findsOneWidget);
    await tester.tap(find.text('Restore app access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(fake.changes, ['user:true', 'user:false']);
    await tester.enterText(find.byKey(const Key('admin_search')), 'person');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(fake.search, 'person');
    expect(find.text('Administrator'), findsNothing);
  });
  testWidgets('admin can disable and re-enable each action', (tester) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    await tester.tap(find.byTooltip('Action controls'));
    await tester.pumpAndSettle();
    for (final type in ['follow', 'like', 'share', 'comment']) {
      final toggle = find.byKey(Key('action_$type'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(fake.actionStates[type], isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(fake.actionStates[type], isTrue);
    }
    expect(fake.actionChanges.length, 8);
  });
  testWidgets('admin can browse campaigns by type and status', (tester) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    await tester.tap(find.byTooltip('Campaigns'));
    await tester.pumpAndSettle();
    expect(find.text('Like · Active'), findsOneWidget);
    expect(find.text('Share · Completed'), findsOneWidget);
    expect(find.text('Owner: owner@example.test'), findsOneWidget);
    expect(find.text('Tasks completed: 3/5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('campaign_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like').last);
    await tester.pumpAndSettle();
    expect(fake.campaignType, 'like');
    expect(find.text('Share · Completed'), findsNothing);
    await tester.tap(find.byKey(const Key('campaign_status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();
    expect(fake.campaignStatus, 'completed');
    expect(find.text('No campaigns found.'), findsOneWidget);
  });
  testWidgets('refreshing action controls does not display stale switches', (
    tester,
  ) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(
      MaterialApp(home: AdminActionControls(gateway: fake)),
    );
    await tester.pumpAndSettle();
    final pending = Completer<Map<String, bool>>();
    fake.nextActions = pending;
    await tester.tap(find.byKey(const Key('action_like')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('action_like')), findsNothing);
    pending.complete(Map.of(fake.actionStates));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('action_like'))).value,
      isFalse,
    );
  });
  testWidgets('filtering campaigns hides stale results while loading', (
    tester,
  ) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(MaterialApp(home: AdminCampaigns(gateway: fake)));
    await tester.pumpAndSettle();
    expect(find.text('Share · Completed'), findsOneWidget);
    final pending = Completer<List<AdminCampaign>>();
    fake.nextCampaigns = pending;
    await tester.tap(find.byKey(const Key('campaign_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like').last);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Share · Completed'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No campaigns found.'), findsOneWidget);
  });
  testWidgets('admin inspection starts and ends review presence', (
    tester,
  ) async {
    final fake = FakeAdmin();
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    await tester.tap(find.byTooltip('Pending submissions'));
    await tester.pumpAndSettle();
    expect(fake.startedReviews, 0);
    await tester.tap(find.text('Inspect'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(fake.startedReviews, 1);
    expect(find.text('Instagram username: @sample'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(fake.endedReviews, ['session']);
  });
  testWidgets('inspection hides evidence when presence renewal fails', (
    tester,
  ) async {
    final fake = FakeAdmin()..renewResult = false;
    const submission = AdminSubmission(
      campaignId: 'c',
      userId: 'u',
      submissionId: 's',
      type: 'like',
      link: 'https://instagram.com/p/ABC/',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminInspectionDialog(gateway: fake, submission: submission),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text(labels['submissionFailure']![0]), findsOneWidget);
    expect(fake.endedReviews, ['session']);
  });
  testWidgets('user controls remain usable in a narrow window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AdminApp(gateway: FakeAdmin()));
    await login(tester);
    expect(find.text('person@example.test'), findsOneWidget);
    expect(find.text('Block app access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
