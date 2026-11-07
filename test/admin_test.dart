import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';

class FakeAdmin implements AdminGateway {
  FakeAdmin({this.allowed = true});
  final bool allowed;
  int signOuts = 0;
  String search = '';
  final changes = <String>[];
  bool blocked = false;
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

  @override
  Future<void> setBlocked(String userId, bool value) async {
    changes.add('$userId:$value');
    blocked = value;
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
