import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avelo/features/settings/settings_page.dart';
import 'package:avelo/theme/avelo_theme.dart';

void main() {
  testWidgets('Settings renders theme options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AveloThemes.build(
          themeId: AveloThemeId.defaultTheme,
          defaultAccent: const Color(0xFF1DB954),
        ),
        home: Scaffold(
          body: SettingsPage(
            themeId: AveloThemeId.defaultTheme,
            onThemeChange: (_) {},
            defaultAccent: const Color(0xFF1DB954),
            onAccentChange: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(DropdownMenu<AveloThemeId>), findsOneWidget);
  });
}
