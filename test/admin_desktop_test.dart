import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';

import 'admin_workspace_test.dart' show WorkspaceFake;

void main() {
  testWidgets(
    'desktop sidebar persists through reports and user detail routes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: adminTheme(),
          home: AdminDesktopConsole(
            gateway: WorkspaceFake(),
            onLogout: () async {},
            onLanguage: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      await tester.tap(find.text('Details').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Reports & CSV'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Reports & CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Export CSV'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Overview'));
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop viewer cannot change access from directory table', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: adminTheme(),
        home: AdminDesktopConsole(
          gateway: WorkspaceFake(role: 'viewer'),
          onLogout: () async {},
          onLanguage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Block app access'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
