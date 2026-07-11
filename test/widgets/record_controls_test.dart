import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/widgets/record_controls.dart';
import '_harness.dart';

void main() {
  Size sizeOfKey(WidgetTester tester, String key) =>
      tester.getSize(find.byKey(ValueKey(key)));

  testWidgets('primary and stop targets are at least 48pt', (tester) async {
    await tester.pumpWidget(wrapThemed(
      RecordControls(
        isPaused: false,
        onPauseResume: () {},
        onStop: () {},
        onSecondary: () {},
      ),
    ));
    for (final key in const [
      'record_controls_primary',
      'record_controls_stop',
      'record_controls_secondary',
    ]) {
      final s = sizeOfKey(tester, key);
      expect(s.width >= 48, isTrue, reason: '$key width ${s.width} < 48');
      expect(s.height >= 48, isTrue, reason: '$key height ${s.height} < 48');
    }
  });

  testWidgets('pause/resume and stop callbacks fire', (tester) async {
    var paused = 0;
    var stopped = 0;
    await tester.pumpWidget(wrapThemed(
      RecordControls(
        isPaused: false,
        onPauseResume: () => paused++,
        onStop: () => stopped++,
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('record_controls_primary')));
    await tester.tap(find.byKey(const ValueKey('record_controls_stop')));
    await tester.pump();
    expect(paused, 1);
    expect(stopped, 1);
  });

  testWidgets('secondary button omitted when no callback provided',
      (tester) async {
    await tester.pumpWidget(wrapThemed(
      RecordControls(isPaused: true, onPauseResume: () {}, onStop: () {}),
    ));
    expect(find.byKey(const ValueKey('record_controls_secondary')),
        findsNothing);
  });
}
