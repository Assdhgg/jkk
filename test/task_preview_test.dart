import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('task view renders injected data and filters without a backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: TaskList(
            uid: 'preview',
            controlsStream: Stream.value([
              {'action_type': 'follow', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            campaignsStream: Stream.value([]),
            claimsStream: Stream.value([]),
            loadSavedIds: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View all submissions'), findsOneWidget);
    expect(find.text('No tasks available yet.'), findsOneWidget);
    await tester.tap(find.text('Follow').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
