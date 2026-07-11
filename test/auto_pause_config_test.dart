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

    test('Run uses 20 m threshold', () {
      expect(AutoPauseConfig.forActivity('Run').maxRecordAccuracyMeters, 20.0);
    });

    test('Swim uses relaxed 50 m threshold', () {
      expect(AutoPauseConfig.forActivity('Swim').maxRecordAccuracyMeters, 50.0);
    });
  });

  group('AutoPauseConfig.forActivity Run', () {
    test('auto-pause enabled with walking breaks still counting as moving', () {
      final config = AutoPauseConfig.forActivity('Run');
      expect(config.enabled, isTrue);
      // Pause threshold must sit below walking pace (~4-5 km/h) so that
      // walk breaks during a run do not trigger auto-pause
      expect(config.pauseSpeedKmh, 2.0);
      expect(config.resumeSpeedKmh, 4.0);
      expect(config.pauseDebounceSeconds, 5);
      expect(config.resumeDebounceSeconds, 3);
    });
  });

  group('AutoPauseConfig.forActivity Swim', () {
    test('auto-pause disabled (GPS speed unreliable in water)', () {
      expect(AutoPauseConfig.forActivity('Swim').enabled, isFalse);
    });
  });
}
