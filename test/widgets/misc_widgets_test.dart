import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/widgets/activity_card.dart';
import 'package:track/widgets/settings_row.dart';
import 'package:track/widgets/map_overlay_panel.dart';
import '_harness.dart';

void main() {
  group('ActivityCard', () {
    testWidgets('renders name, date, distance and speed', (tester) async {
      await tester.pumpWidget(wrapThemed(
        const ActivityCard(
          type: 'Ride',
          name: 'Evening Ride',
          dateLabel: 'Jul 9 · 18:24',
          distance: '24.6',
          duration: '1:02',
          avgSpeed: '24.1',
          uploaded: true,
        ),
      ));
      expect(find.text('Evening Ride'), findsOneWidget);
      expect(find.text('Jul 9 · 18:24'), findsOneWidget);
      expect(find.text('24.6'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('tap invokes onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapThemed(
        ActivityCard(
          type: 'Run',
          name: 'Riverside Run',
          dateLabel: 'Jul 8',
          distance: '8.4',
          duration: '0:44',
          avgSpeed: '11.4',
          onTap: () => taps++,
        ),
      ));
      await tester.tap(find.byType(ActivityCard));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('SettingsRow', () {
    testWidgets('renders title and value', (tester) async {
      await tester.pumpWidget(wrapThemed(
        const SettingsRow(title: 'Units', value: 'Kilometres'),
      ));
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Kilometres'), findsOneWidget);
    });

    testWidgets('custom trailing widget replaces value', (tester) async {
      await tester.pumpWidget(wrapThemed(
        SettingsRow(
          title: 'Auto-pause',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      ));
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('MapOverlayPanel', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(wrapThemed(
        const MapOverlayPanel(child: Text('overlay')),
      ));
      expect(find.text('overlay'), findsOneWidget);
    });
  });
}
