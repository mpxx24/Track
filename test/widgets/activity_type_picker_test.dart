import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/widgets/activity_type_picker.dart';
import '_harness.dart';

void main() {
  testWidgets('renders all five default activity types', (tester) async {
    await tester.pumpWidget(wrapThemed(
      ActivityTypePicker(selectedType: 'Ride', onSelected: (_) {}),
    ));
    for (final label in ['Ride', 'Walk', 'Run', 'Football', 'Swim']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }
    // Default option set is exactly five.
    expect(ActivityTypePicker.defaultOptions.length, 5);
  });

  testWidgets('renders the expected icons for each type', (tester) async {
    await tester.pumpWidget(wrapThemed(
      ActivityTypePicker(selectedType: 'Ride', onSelected: (_) {}),
    ));
    expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    expect(find.byIcon(Icons.directions_run), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.byIcon(Icons.pool), findsOneWidget);
  });

  testWidgets('tapping a type invokes onSelected with its type string',
      (tester) async {
    String? picked;
    await tester.pumpWidget(wrapThemed(
      ActivityTypePicker(
        selectedType: 'Ride',
        onSelected: (t) => picked = t,
      ),
    ));
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(picked, 'Run');
  });
}
