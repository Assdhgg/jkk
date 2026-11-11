import 'dart:async';

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
  testWidgets(
    'mandatory gate covers pushed pages, retains lock on errors and cancelled install, unlocks only on installed version',
    (tester) async {
      final stream = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(stream.close);
      final nav = GlobalKey<NavigatorState>();
      var installed = 7, installs = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: (_, child) => AppUpdateGate(
            signedIn: true,
            releaseLoader: () => stream.stream,
            versionLoader: () async => installed,
            installer: (_) async {
              installs++;
              return 'installer_opened';
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('Home access')),
        ),
      );
      await tester.pump();
      expect(find.text('Home access'), findsNothing);
      stream.add([release(7)]);
      await tester.pumpAndSettle();
      expect(find.text('Home access'), findsOneWidget);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private page')),
        ),
      );
      await tester.pumpAndSettle();
      stream.add([release(8)]);
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Private page'), findsNothing);
      await tester.tap(find.text('Update app'));
      await tester.pumpAndSettle();
      expect(installs, 1);
      expect(find.text('Private page'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      stream.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      stream.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      stream.add([release(8)]);
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      installed = 8;
      await tester.tap(find.text('Check again'));
      await tester.pump();
      stream.add([release(8)]);
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsNothing);
      expect(find.text('Home access'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mandatory check fails closed, retries, polls and checks on sign-in',
    (tester) async {
      var fail = true, loads = 0;
      final auth = StreamController<bool>.broadcast();
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppUpdateGate(
            signedIn: false,
            authChanges: auth.stream,
            pollInterval: const Duration(seconds: 10),
            versionLoader: () async => 7,
            releaseLoader: () {
              loads++;
              return fail
                  ? Stream.error(StateError('offline'))
                  : Stream.value([release(loads > 2 ? 8 : 7)]);
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('App access')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('App access'), findsOneWidget);
      expect(loads, 0);
      auth.add(true);
      await tester.pumpAndSettle();
      expect(find.text('App access'), findsNothing);
      expect(find.textContaining('Connect to the internet'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('App access'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      auth.add(false);
      await tester.pumpAndSettle();
      expect(find.text('App access'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
