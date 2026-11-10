import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/app_updates.dart';

Map<String, dynamic> release(int code) => {
  'version_code': code,
  'version_name': '1.2.0',
  'apk_path': '12345678-1234-1234-1234-123456789abc.apk',
  'sha256': List.filled(64, 'a').join(),
  'size_bytes': 100,
  'notes': 'New features',
};
void main() {
  test('release rejects invalid hashes, paths and unbounded downloads', () {
    expect(
      () => AppRelease.fromJson({...release(8), 'apk_path': '../../bad.apk'}),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({...release(8), 'sha256': 'bad'}),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({...release(8), 'size_bytes': maxApkBytes + 1}),
      throwsFormatException,
    );
  });
  testWidgets(
    'only newer builds offer install and permission instructions allow retry',
    (tester) async {
      int calls = 0;
      int installed = 7;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateView(
              releaseLoader: () => Stream.value([release(8)]),
              versionLoader: () async => installed,
              installer: (_) async {
                calls++;
                return calls == 1 ? 'permission_required' : 'installer_opened';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update app'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow installation'), findsOneWidget);
      await tester.tap(find.text('Update app'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('Complete installation'), findsOneWidget);
      installed = 8;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Your app is up to date.'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateView(
              key: const ValueKey('current'),
              releaseLoader: () => Stream.value([release(7)]),
              versionLoader: () async => 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update app'), findsNothing);
      expect(find.text('Your app is up to date.'), findsOneWidget);
    },
  );
  testWidgets('failed install can retry and never reports success', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUpdateView(
            releaseLoader: () => Stream.value([release(8)]),
            versionLoader: () async => 7,
            installer: (_) async => throw StateError('bad APK'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update app'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Update failed'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Update app'))
          .onPressed,
      isNotNull,
    );
  });
}
