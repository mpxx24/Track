import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:track/services/speed_calculator.dart';

void main() {
  group('SpeedCalculator.computeKmh', () {
    final base = DateTime(2026, 1, 1, 12, 0, 0);
    const london = LatLng(51.5, -0.1);
    // ~5 m north of london (1° lat ≈ 111 km → 0.000045° ≈ 5 m)
    const londonPlus5m = LatLng(51.500045, -0.1);

    test('uses GPS speed when position.speed >= 0', () {
      final speed = SpeedCalculator.computeKmh(
        positionSpeed: 2.0, // m/s
        currSmooth: london,
        currTimestamp: base,
      );
      expect(speed, closeTo(7.2, 0.001)); // 2.0 m/s × 3.6
    });

    test('GPS speed 0 is used as-is (not fallen back to position delta)', () {
      final speed = SpeedCalculator.computeKmh(
        positionSpeed: 0.0,
        currSmooth: londonPlus5m,
        prevSmooth: london,
        prevTimestamp: base,
        currTimestamp: base.add(const Duration(seconds: 5)),
      );
      expect(speed, 0.0);
    });

    test('falls back to position delta when GPS speed is -1', () {
      // 5 m in 5 s = 1 m/s = 3.6 km/h
      final speed = SpeedCalculator.computeKmh(
        positionSpeed: -1.0,
        currSmooth: londonPlus5m,
        prevSmooth: london,
        prevTimestamp: base,
        currTimestamp: base.add(const Duration(seconds: 5)),
      );
      expect(speed, closeTo(3.6, 0.1));
    });

    test('returns 0 when GPS speed is -1 and no previous fix available', () {
      final speed = SpeedCalculator.computeKmh(
        positionSpeed: -1.0,
        currSmooth: london,
        currTimestamp: base,
      );
      expect(speed, 0.0);
    });

    test('returns 0 when GPS speed is -1 and elapsed time is zero', () {
      final speed = SpeedCalculator.computeKmh(
        positionSpeed: -1.0,
        currSmooth: londonPlus5m,
        prevSmooth: london,
        prevTimestamp: base,
        currTimestamp: base, // same timestamp
      );
      expect(speed, 0.0);
    });
  });
}
