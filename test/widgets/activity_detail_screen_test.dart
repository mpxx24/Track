import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track/models/activity_record.dart';
import 'package:track/screens/activity_detail_screen.dart';
import 'package:track/theme.dart';
import 'package:track/widgets/upload_status_chip.dart';

void main() {
  late Directory tmpDir;
  late String gpxPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmpDir = await Directory.systemTemp.createTemp('track_detail_test');
    gpxPath = '${tmpDir.path}/activity.gpx';
    await File(gpxPath).writeAsString(
      '<gpx><trk><trkseg>'
      '<trkpt lat="51.5" lon="-0.09"></trkpt>'
      '<trkpt lat="51.51" lon="-0.08"></trkpt>'
      '</trkseg></trk></gpx>',
    );
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  ActivityRecord record({bool uploaded = false}) => ActivityRecord(
        id: 'a1',
        startedAt: DateTime(2026, 7, 11, 7, 12),
        distanceKm: 24.6,
        duration: const Duration(hours: 1, minutes: 2, seconds: 14),
        movingDuration: const Duration(hours: 1, minutes: 0, seconds: 20),
        avgSpeedKmh: 24.1,
        activityType: 'Ride',
        gpxFilePath: gpxPath,
        uploaded: uploaded,
      );

  Widget wrap(ActivityRecord r) => MaterialApp(
        theme: trackLightTheme(),
        darkTheme: trackDarkTheme(),
        themeMode: ThemeMode.dark,
        home: ActivityDetailScreen(record: r),
      );

  testWidgets('renders title, stat grid and upload controls', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(record()));
    await tester.pump(); // resolve _loadPoints / _loadStravaPref futures
    await tester.pump(const Duration(milliseconds: 100));

    // Derived title (Morning + type) and stat labels from the shared StatTile.
    expect(find.text('Morning Ride'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('MOVING'), findsOneWidget);
    expect(find.text('AVG'), findsOneWidget);

    // Upload controls + export action.
    expect(find.text('ActivitiesJournal'), findsOneWidget);
    expect(find.text('Strava'), findsOneWidget);
    expect(find.text('UPLOAD'), findsWidgets); // section label + button
    expect(find.text('EXPORT GPX'), findsOneWidget);

    // Not-yet-uploaded => LOCAL status chip.
    expect(find.byType(UploadStatusChip), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
  });

  testWidgets('uploaded record shows UPLOADED chip and RE-UPLOAD action',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(record(uploaded: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Both the status chip and the ActivitiesJournal row read "UPLOADED".
    expect(find.text('UPLOADED'), findsNWidgets(2));
    expect(find.text('RE-UPLOAD'), findsOneWidget);
    expect(find.text('LOCAL'), findsNothing);
  });
}
