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

    // Persisted URL loaded into its field.
    expect(find.text('https://journal.local/api'), findsOneWidget);

    // Strava row rendered via the shared SettingsRow with a Switch that
    // reflects the persisted value.
    expect(find.byType(SettingsRow), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
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
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Save.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Settings saved'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('upload_to_strava'), isTrue);
    expect(prefs.getString('api_base_url'), 'https://old.example');
    expect(prefs.getString('api_key'), 'old');
  });
}
