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
  });
}
