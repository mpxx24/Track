import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/widgets/stat_tile.dart';
import '_harness.dart';

void main() {
  testWidgets('StatTile renders label, value and unit', (tester) async {
    await tester.pumpWidget(wrapThemed(
      const StatTile(label: 'DISTANCE', value: '24.6', unit: 'KM'),
    ));
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('24.6'), findsOneWidget);
    expect(find.text('KM'), findsOneWidget);
  });

  testWidgets('StatTile primary value is larger than secondary', (tester) async {
    await tester.pumpWidget(wrapThemed(
      const Column(children: [
        StatTile(label: 'A', value: '10', size: StatTileSize.primary),
        StatTile(label: 'B', value: '20', size: StatTileSize.secondary),
      ]),
    ));
    final primary = tester.widget<Text>(find.text('10'));
    final secondary = tester.widget<Text>(find.text('20'));
    expect(primary.style!.fontSize! > secondary.style!.fontSize!, isTrue);
    expect(primary.style!.fontFamily, 'SpaceMono');
  });

  testWidgets('StatTile applies valueColor override', (tester) async {
    await tester.pumpWidget(wrapThemed(
      const StatTile(label: 'NOW', value: '31.2', valueColor: Color(0xFF22D3EE)),
    ));
    final value = tester.widget<Text>(find.text('31.2'));
    expect(value.style!.color, const Color(0xFF22D3EE));
  });
}
