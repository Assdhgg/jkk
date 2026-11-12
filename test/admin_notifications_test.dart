import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_notifications.dart';
import 'package:growth_circle/main.dart';

class FakeNotifications implements AdminNotificationGateway {
  final calls = <Map<String, dynamic>>[];
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> search(String query, int offset) async => [
    {
      'id': 'user-a',
      'email': 'a@example.test',
      'display_name': 'Alice',
      'public_id': '12345678',
    },
    {
      'id': 'user-b',
      'email': 'b@example.test',
      'display_name': 'Bob',
      'public_id': '87654321',
    },
  ];
  @override
  Future<Map<String, dynamic>> pushReadiness(String? target) async => {'devices': 1, 'users_with_devices': 1};
  @override
  Future<int> send(
    String requestId,
    String? target,
    String title,
    String body, {bool inApp = true, bool push = true,
  }) async {
    calls.add({
      'request': requestId,
      'target': target,
      'title': title,
      'body': body,
    });
    if (fail) throw StateError('response lost');
    return target == null ? 2 : 1;
  }
}

Future<void> confirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('submit_notification')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('submit_notification')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'selects a specific user and retries the same request without duplicates',
    (tester) async {
      final api = FakeNotifications()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSendNotificationPage(gateway: api, canEdit: true),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('notification_user_search')),
        'Alice',
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice').last);
      await tester.enterText(
        find.byKey(const Key('notification_title')),
        'News',
      );
      await tester.enterText(
        find.byKey(const Key('notification_body')),
        'Hello Alice',
      );
      await confirm(tester);
      expect(api.calls.single['target'], 'user-a');
      expect(find.textContaining('Could not confirm sending'), findsOneWidget);
      api.fail = false;
      await confirm(tester);
      expect(api.calls[1]['request'], api.calls[0]['request']);
      expect(api.calls[1]['body'], 'Hello Alice');
    },
  );

  testWidgets('broadcast and editor access are explicit', (tester) async {
    final api = FakeNotifications();
    await tester.pumpWidget(
      MaterialApp(home: AdminSendNotificationPage(gateway: api, canEdit: true)),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('notification_title')),
      'Notice',
    );
    await tester.enterText(
      find.byKey(const Key('notification_body')),
      'For everyone',
    );
    await confirm(tester);
    expect(api.calls.single['target'], isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminSendNotificationPage(gateway: api, canEdit: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('user can read the admin title and message and mark it read', (
    tester,
  ) async {
    String? readId;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(
          stream: Stream.value([
            {
              'id': 'n1',
              'kind': 'admin_message',
              'title': 'Notice',
              'body': 'Maintenance tonight',
              'created_at': '2026-11-11T10:00:00Z',
              'read_at': null,
            },
          ]),
          markRead: (id) async {
            readId = id;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notice'), findsOneWidget);
    expect(find.textContaining('Maintenance tonight'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    await tester.pumpAndSettle();
    expect(readId, 'n1');
  });
}
