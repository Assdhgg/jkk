import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  tearDown(() => language.value = const Locale('en'));
  for (final locale in ['en', 'ml']) {
    testWidgets('task category controls filter and restore all in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      language.value = Locale(locale);
      const tasks = [
        {'type': 'follow'},
        {'type': 'like'},
        {'type': 'comment'},
        {'type': 'share'},
      ];
      var selected = 'all';
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  TaskTypePicker(
                    selected: selected,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                  for (final task in filterTasks(tasks, selected))
                    Text('task-${task['type']}'),
                ],
              ),
            ),
          ),
        ),
      );
      for (final entry in {
        'follow': 1,
        'like': 2,
        'comment': 3,
        'share': 4,
      }.entries) {
        await tester.ensureVisible(find.byType(ChoiceChip).at(entry.value));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ChoiceChip).at(entry.value));
        await tester.pumpAndSettle();
        expect(find.text('task-${entry.key}'), findsOneWidget);
        expect(find.textContaining('task-'), findsOneWidget);
      }
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('task-'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('notifications show real events, unread badge and mark read', (
    tester,
  ) async {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(controller.close);
    String? marked;
    final items = <Map<String, dynamic>>[
      {
        'id': '1',
        'kind': 'approved',
        'read_at': null,
        'created_at': '2026-01-01T00:00:00Z',
      },
      {
        'id': '2',
        'kind': 'rejected',
        'read_at': '2026-01-02T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
      },
      {
        'id': '3',
        'kind': 'coins_received',
        'amount': 2,
        'read_at': '2026-01-02T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: [
                NotificationsButton(
                  stream: controller.stream,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationsPage(
                        stream: controller.stream,
                        markRead: (id) async {
                          marked = id;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.add(items);
    await tester.pump();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    controller.add(items);
    await tester.pumpAndSettle();
    expect(find.text('Your submission was approved.'), findsOneWidget);
    expect(find.text('Your submission was rejected.'), findsOneWidget);
    expect(find.text('Coins received: +2'), findsOneWidget);
    expect(find.byTooltip('Mark as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    await tester.pump();
    expect(marked, '1');
    items[0]['read_at'] = '2026-01-02T00:00:00Z';
    controller.add(items);
    await tester.pump();
    expect(find.byTooltip('Mark as read'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });
}
