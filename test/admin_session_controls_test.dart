import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growth_circle/admin_main.dart';
import 'admin_test.dart' show FakeAdmin;

void main() {
  testWidgets('administrator can choose manual sign-out and keep session on minimize', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gateway = FakeAdmin();
    await tester.pumpWidget(AdminApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_email')), 'admin@example.test');
    await tester.enterText(find.byKey(const Key('admin_password')), 'synthetic-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Session settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out manually').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out when minimized'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getInt('admin_idle_minutes'), 0);
    await tester.pump(const Duration(minutes: 11));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gateway.signOuts, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
