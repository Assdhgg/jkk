import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/design.dart';

void main() {
  tearDown(() => language.value = const Locale('en'));
  testWidgets('all task categories share one row at reference phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: TaskTypePicker(
              selected: 'all',
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(5));
    final y = tester.getCenter(chips.first).dy;
    for (var i = 1; i < 5; i++) {
      expect((tester.getCenter(chips.at(i)).dy - y).abs(), lessThan(1));
    }
    await tester.tap(chips.last);
    expect(selected, 'share');
    expect(tester.takeException(), isNull);
  });
  testWidgets('rounded navigation remains usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => GrowthNavigation(
              selected: selected,
              labels: const ['Home', 'Earn', 'Campaigns', 'Profile'],
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Campaigns'));
    await tester.pump();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['en', 'ml']) {
    testWidgets('home actions remain reachable at narrow width in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      language.value = Locale(locale);
      var browse = false, create = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Dashboard(
              uid: 'sample',
              balanceStream: Stream.value([
                {'balance': 128},
              ]),
              onBrowse: () => browse = true,
              onCreate: () => create = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('128'), findsNothing);
      await tester.tap(
        find.byTooltip(
          locale == 'en' ? 'Check balance' : 'Balance പരിശോധിക്കുക',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('128'), findsOneWidget);
      final menus = find.byType(ProfileMenuTile);
      await tester.scrollUntilVisible(find.byIcon(Icons.explore_outlined), 200);
      await tester.ensureVisible(menus.at(0));
      await tester.pumpAndSettle();
      await tester.tap(menus.at(0));
      await tester.ensureVisible(menus.at(1));
      await tester.pumpAndSettle();
      await tester.tap(menus.at(1));
      expect(browse, isTrue);
      expect(create, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home action selects its matching task category', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Dashboard(
            uid: 'sample',
            balanceStream: Stream.value([
              {'balance': 1},
            ]),
            onBrowse: () {},
            onCreate: () {},
            onBrowseType: (type) => selected = type,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like').first);
    expect(selected, 'like');
  });

  testWidgets('shared page content stays centered on a wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(body: AppListView(children: const [Text('Content')])),
      ),
    );
    expect(tester.getSize(find.byType(ListView)).width, 560);
    expect(tester.getTopLeft(find.byType(ListView)).dx, 320);
    expect(tester.takeException(), isNull);
  });
}
