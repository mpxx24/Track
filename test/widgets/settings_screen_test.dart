import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track/screens/settings_screen.dart';
import 'package:track/theme.dart';
import 'package:track/widgets/settings_row.dart';

Widget _app() => MaterialApp(
      theme: trackLightTheme(),
      darkTheme: trackDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const SettingsScreen(),
    );

void main() {
  testWidgets('loads persisted values and renders grouped sections',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'https://journal.local/api',
      'api_key': 'secret',
      'upload_to_strava': true,
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Section headers present.
    expect(find.text('SERVER'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);

    // Persisted URL loaded into its field.
    expect(find.text('https://journal.local/api'), findsOneWidget);

    // Strava row rendered via the shared SettingsRow with a Switch that
    // reflects the persisted value.
    final stravaSwitch = find.descendant(
      of: find.widgetWithText(SettingsRow, 'Also upload to Strava'),
      matching: find.byType(Switch),
    );
    expect(stravaSwitch, findsOneWidget);
    expect(tester.widget<Switch>(stravaSwitch).value, isTrue);
  });

  testWidgets('toggling the switch and saving persists all fields',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'https://old.example',
      'api_key': 'old',
      'upload_to_strava': false,
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Flip the Strava switch on.
    await tester.tap(find.descendant(
      of: find.widgetWithText(SettingsRow, 'Also upload to Strava'),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();

    // Save (scroll it into view first — the list can exceed the test viewport).
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Settings saved'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('upload_to_strava'), isTrue);
    expect(prefs.getString('api_base_url'), 'https://old.example');
    expect(prefs.getString('api_key'), 'old');
  });
}
