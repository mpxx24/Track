import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track/screens/planned_routes_screen.dart';
import 'package:track/theme.dart';

void main() {
  testWidgets('shows themed config prompt when API is not configured',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: trackLightTheme(),
        darkTheme: trackDarkTheme(),
        themeMode: ThemeMode.dark,
        home: const PlannedRoutesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Title from the themed AppBar.
    expect(find.text('Planned Routes'), findsOneWidget);
    // Empty-config guidance is surfaced (no network call made).
    expect(
      find.text('Configure API URL and key in Settings first.'),
      findsOneWidget,
    );
    // No spinner left running.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
