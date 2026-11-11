import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('unconfigured builds show setup instructions', (tester) async {
    await tester.pumpWidget(const GrowthApp(configured: false));
    expect(find.textContaining('Supabase is not configured'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Freelan Space',
    );
  });
  testWidgets('task notice is shown in Malayalam', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ml'),
        supportedLocales: [Locale('en'), Locale('ml')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: Notice()),
      ),
    );
    expect(find.text(words['disclaimer']![1]), findsOneWidget);
  });
}
