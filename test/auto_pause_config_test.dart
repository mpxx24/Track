import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/auto_pause_config.dart';

void main() {
  group('AutoPauseConfig.maxRecordAccuracyMeters', () {
    test('Walk uses 20 m threshold', () {
      expect(AutoPauseConfig.forActivity('Walk').maxRecordAccuracyMeters, 20.0);
    });

    test('Ride uses 20 m threshold', () {
      expect(AutoPauseConfig.forActivity('Ride').maxRecordAccuracyMeters, 20.0);
    });

    test('Football has no threshold (null)', () {
      expect(
          AutoPauseConfig.forActivity('Football').maxRecordAccuracyMeters,
          isNull);
    });

    test('unknown activity type falls back to null (no filter)', () {
      expect(
          AutoPauseConfig.forActivity('Unknown').maxRecordAccuracyMeters,
          isNull);
    });
  });
}
