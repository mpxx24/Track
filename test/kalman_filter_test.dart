import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/kalman_filter.dart';

void main() {
  group('KalmanFilter', () {
    test('first fix is accepted as-is', () {
      final filter = KalmanFilter();
      final (lat, lng) = filter.update(51.5, -0.1, 10.0);
      expect(lat, 51.5);
      expect(lng, -0.1);
    });

    test('high-accuracy second fix moves estimate close to new reading', () {
      final filter = KalmanFilter();
      filter.update(51.5, -0.1, 10.0); // first fix
      final (lat, lng) = filter.update(51.501, -0.101, 5.0); // high accuracy
      // Estimate should shift meaningfully toward the new reading
      expect(lat, greaterThan(51.5));
      expect(lat, lessThanOrEqualTo(51.501));
      expect(lng, lessThan(-0.1));
      expect(lng, greaterThanOrEqualTo(-0.101));
    });

    test('low-accuracy fix shifts estimate less than high-accuracy fix', () {
      final filterHigh = KalmanFilter();
      filterHigh.update(51.5, -0.1, 10.0);
      final (latHigh, _) = filterHigh.update(51.6, -0.1, 5.0);

      final filterLow = KalmanFilter();
      filterLow.update(51.5, -0.1, 10.0);
      final (latLow, _) = filterLow.update(51.6, -0.1, 100.0);

      // High-accuracy update pulls estimate further from the prior
      expect(latHigh - 51.5, greaterThan(latLow - 51.5));
    });

    test('accuracy clamped at minimum — very small value does not cause error',
        () {
      final filter = KalmanFilter();
      expect(() => filter.update(51.5, -0.1, 0.0), returnsNormally);
      expect(() => filter.update(51.5, -0.1, -5.0), returnsNormally);
    });

    test('reset re-initialises filter — next fix accepted as-is', () {
      final filter = KalmanFilter();
      filter.update(51.5, -0.1, 10.0);
      filter.update(51.501, -0.101, 5.0);
      filter.reset();
      final (lat, lng) = filter.update(48.0, 2.0, 20.0);
      expect(lat, 48.0);
      expect(lng, 2.0);
    });

    test('successive identical fixes converge and stay stable', () {
      final filter = KalmanFilter();
      filter.update(51.5, -0.1, 15.0);
      for (var i = 0; i < 10; i++) {
        filter.update(51.5, -0.1, 15.0);
      }
      final (lat, lng) = filter.update(51.5, -0.1, 15.0);
      expect(lat, closeTo(51.5, 0.000001));
      expect(lng, closeTo(-0.1, 0.000001));
    });

    test('filter remains responsive after 200 updates — does not freeze', () {
      final filter = KalmanFilter();
      // Warm up at a fixed position
      for (var i = 0; i < 200; i++) {
        filter.update(51.5, -0.1, 15.0);
      }
      // New position ~11 m north (0.0001 deg ≈ 11 m)
      final (lat, _) = filter.update(51.5001, -0.1, 15.0);
      // Estimate must shift at least 10% of the way to the new reading
      expect(lat - 51.5, greaterThan(0.00001));
    });

    test('tracks continuous movement — accumulated distance not under-reported', () {
      final filter = KalmanFilter();
      // Simulate 50 GPS updates, each 5 m north (0.000045 deg ≈ 5 m)
      const step = 0.000045;
      var prevLat = 51.5;
      var distanceFiltered = 0.0;

      for (var i = 1; i <= 50; i++) {
        final trueLat = 51.5 + i * step;
        final (lat, _) = filter.update(trueLat, -0.1, 10.0);
        distanceFiltered += (lat - prevLat).abs();
        prevLat = lat;
      }

      final trueDistance = 50 * step;
      // Filter should capture at least 70% of true movement
      expect(distanceFiltered, greaterThan(trueDistance * 0.7));
    });
  });
}
