import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  tearDown(() => language.value = const Locale('en'));
  testWidgets(
    'settings disables and enables push, preserving state on failure',
    (tester) async {
      final changes = <bool>[];
      bool fail = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          home: UserSettingsPage(
            enabledLoader: () async => true,
            pushUpdater: (value) async {
              if (fail) throw StateError('offline');
              changes.add(value);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      fail = true;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      fail = false;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, [false, true]);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('മലയാളം').last);
      await tester.pumpAndSettle();
      expect(language.value.languageCode, 'ml');
    },
  );
}
