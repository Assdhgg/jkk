import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  test('accepts R2 releases and rejects unsafe or inconsistent locations', () {
    const url = 'https://releases.example.test/releases/file.apk';
    expect(
      AppRelease.fromJson({
        ...release(8),
        'storage_provider': 'r2',
        'download_url': url,
      }).downloadUrl,
      url,
    );
    expect(AppRelease.fromJson(release(8)).downloadUrl, isNull);
    for (final row in [
      {
        ...release(8),
        'storage_provider': 'r2',
        'download_url': 'http://example.test/file.apk',
      },
      {
        ...release(8),
        'storage_provider': 'r2',
        'download_url': 'https://user@example.test/file.apk',
      },
      {...release(8), 'storage_provider': 'r2'},
      {...release(8), 'storage_provider': 'unknown', 'download_url': url},
      {...release(8), 'storage_provider': 'supabase', 'download_url': url},
    ]) {
      expect(() => AppRelease.fromJson(row), throwsFormatException);
    }
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
      expect(
        find.textContaining('Allow installation from Freelan Space'),
        findsOneWidget,
      );
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
  testWidgets('installer receives the right R2 or legacy download URL', (
    tester,
  ) async {
    final client = SupabaseClient('https://project.example.test', 'public-key');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          calls.add(call);
          return 'installer_opened';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null),
    );
    for (final row in [
      {
        ...release(8),
        'storage_provider': 'r2',
        'download_url': 'https://updates.example.test/releases/file.apk',
      },
      release(8),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateView(
              key: ValueKey(row['storage_provider'] ?? 'legacy'),
              client: client,
              releaseLoader: () => Stream.value([row]),
              versionLoader: () async => 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update app'));
      await tester.pumpAndSettle();
    }
    expect(
      calls[0].arguments['url'],
      'https://updates.example.test/releases/file.apk',
    );
    expect(
      calls[1].arguments['url'],
      'https://project.example.test/storage/v1/object/public/app-releases/12345678-1234-1234-1234-123456789abc.apk',
    );
    expect(calls[0].arguments['sha256'], 'a' * 64);
    expect(calls[0].arguments['sizeBytes'], 100);
    client.auth.stopAutoRefresh();
  });
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
