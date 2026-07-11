import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track/screens/home_screen.dart';
import 'package:track/theme.dart';

Widget _wrapHome() => MaterialApp(
      theme: trackLightTheme(),
      darkTheme: trackDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );

Map<String, dynamic> _record({
  required String id,
  required String type,
  required bool uploaded,
}) =>
    {
      'id': id,
      'startedAt': '2026-07-09T18:24:00',
      'distanceKm': 24.6,
      'durationSeconds': 3900,
      'movingDurationSeconds': 3734,
      'avgSpeedKmh': 24.1,
      'activityType': type,
      'gpxFilePath': '/tmp/$id.gpx',
      'uploaded': uploaded,
    };

void main() {
  testWidgets('renders header, RECORD CTA, RECENT section and Routes link',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrapHome());
    await tester.pumpAndSettle();

    expect(find.text('Track.'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Routes ›'), findsOneWidget);
    // Empty state when there is no history.
    expect(find.text('No activities yet'), findsOneWidget);
  });

  testWidgets('renders an activity card with the per-type tinted icon',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'activity_history': jsonEncode([
        _record(id: 'a', type: 'Ride', uploaded: true),
      ]),
    });
    await tester.pumpWidget(_wrapHome());
    await tester.pumpAndSettle();

    expect(find.text('No activities yet'), findsNothing);
    expect(find.text('Ride'), findsOneWidget);
    // Distance numeral (1 decimal) from the seeded record.
    expect(find.text('24.6'), findsOneWidget);

    // The type icon is tinted with the theme's Ride tint.
    final ext = TrackTheme.dark;
    final iconWidget = tester.widget<Icon>(find.byIcon(Icons.directions_bike));
    expect(iconWidget.color, ext.typeTint('Ride'));

    // Uploaded record shows no inline upload trigger.
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('local (not uploaded) activity shows the upload trigger',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'activity_history': jsonEncode([
        _record(id: 'b', type: 'Run', uploaded: false),
      ]),
    });
    await tester.pumpWidget(_wrapHome());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });
}
