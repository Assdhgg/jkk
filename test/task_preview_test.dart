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
    await tester.tap(find.widgetWithText(ChoiceChip, 'Follow'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial action filter shows only matching tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: TaskList(
            uid: 'preview',
            initialType: 'follow',
            controlsStream: Stream.value([
              {'action_type': 'follow', 'enabled': true},
              {'action_type': 'like', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            claimsStream: Stream.value([]),
            campaignsStream: Stream.value([
              {
                'id': 'a',
                'ownerId': 'other',
                'status': 'active',
                'type': 'follow',
                'link': 'https://instagram.com/follow',
                'reward_per_task': 2,
              },
              {
                'id': 'b',
                'ownerId': 'other',
                'status': 'active',
                'type': 'like',
                'link': 'https://instagram.com/like',
                'reward_per_task': 3,
              },
            ]),
            loadSavedIds: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/follow'), findsOneWidget);
    expect(find.text('https://instagram.com/like'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Like'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Like'));
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/like'), findsOneWidget);
    expect(find.text('https://instagram.com/follow'), findsNothing);
  });
}
