import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';

import 'admin_test.dart' show FakeAdmin, login;

class WorkspaceFake extends FakeAdmin implements AdminWorkspaceGateway {
  WorkspaceFake({this.role = 'editor'});
  final String role;
  String? selectedType;
  @override
  Future<String> workspaceRole() async => role;
  @override
  Future<Map<String, dynamic>> overview() async => {
    'users': 4,
    'active_campaigns': 2,
    'pending_submissions': 1,
    'coins_credited': 20,
  };
  @override
  Future<List<Map<String, dynamic>>> roles() async => [
    {'email': 'admin@example.test', 'role': role, 'created_at': '2026-11-09'},
  ];
  @override
  Future<Map<String, dynamic>> userDetails(String id) async => {
    'referrals': 1,
    'referred': false,
    'role': null,
    'campaigns': [],
    'submissions': [],
    'ledger': [],
  };
  @override
  Future<List<Map<String, dynamic>>> activity(int offset) async => [
    {
      'action': 'Access',
      'actor': 'admin@example.test',
      'details': 'restored',
      'event_at': 'today',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> dailyReport(
    DateTime from,
    DateTime to,
  ) async => [
    {
      'day': '2026-11-09',
      'registrations': 1,
      'campaigns': 2,
      'coin_transactions': 3,
      'coins_credited': 4,
      'coins_spent': 5,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> alerts() async => [
    {
      'kind': 'pending',
      'subject': 'campaign',
      'activity': 1,
      'observed_at': 'today',
    },
  ];
  @override
  Future<List<AdminSubmission>> filteredSubmissions(
    String? type,
    String? campaign,
    DateTime? from,
    DateTime? to,
    int offset,
    int limit,
  ) async {
    selectedType = type;
    return type == 'share' ? [] : submissions(offset, limit);
  }
}

void main() {
  test('report CSV includes the displayed UTC totals and escapes values', () {
    expect(
      adminReportCsv([
        {
          'day': '2026-11-09',
          'registrations': 1,
          'campaigns': 2,
          'coin_transactions': 3,
          'coins_credited': 4,
          'coins_spent': 5,
        },
      ]),
      'day,registrations,campaigns,coin_transactions,coins_credited,coins_spent\r\n"2026-11-09","1","2","3","4","5"',
    );
  });
  testWidgets('viewer can view workspace and cannot change controls', (
    tester,
  ) async {
    final fake = WorkspaceFake(role: 'viewer');
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Block app access'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Active campaigns'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });
  testWidgets('user details and server filtered submissions are accessible', (
    tester,
  ) async {
    final fake = WorkspaceFake();
    await tester.pumpWidget(AdminApp(gateway: fake));
    await login(tester);
    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Referrals: 1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pending submissions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter submissions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(fake.selectedType, 'share');
    expect(find.text('No pending submissions.'), findsOneWidget);
  });
}
