import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_app_releases.dart';
import 'package:growth_circle/admin_operations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('refresh displays a link changed by a release publication', (
    tester,
  ) async {
    var link = 'https://updates.example.test/old.apk';
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('referral_download_link')
              ? jsonEncode([
                  {'url': link},
                ])
              : '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminAppReleasesPage(client: client, canEdit: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text(link), findsOneWidget);
    link = 'https://updates.example.test/freelan-space-v1.2.3-21.apk';
    await tester.tap(find.byTooltip('Refresh releases'));
    await tester.pumpAndSettle();
    expect(find.text(link), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  for (final width in [1100.0, 1536.0]) {
    testWidgets('desktop operations navigation works at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.test',
        'synthetic',
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              const SizedBox(width: 230),
              Expanded(
                child: AdminOperationsPage(client: client, canEdit: true),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Campaign reports'));
      await tester.pumpAndSettle();
      expect(calls, contains('/rest/v1/rpc/admin_campaign_reports'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    });

    for (final canEdit in [true, false]) {
      testWidgets(
        'desktop release form follows edit permission at $width: $canEdit',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = SupabaseClient(
            'https://example.test',
            'synthetic',
            httpClient: MockClient(
              (request) async => http.Response(
                '[]',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
            ),
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Row(
                children: [
                  const SizedBox(width: 230),
                  Expanded(
                    child: AdminAppReleasesPage(
                      client: client,
                      canEdit: canEdit,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('No releases published yet.'), findsOneWidget);
          expect(
            find.text('Publish update'),
            canEdit ? findsOneWidget : findsNothing,
          );
          if (canEdit) {
            await tester.tap(find.text('Publish update'));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Choose a signed APK and enter'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          client.dispose();
        },
      );
    }
  }
}
