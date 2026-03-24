import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Derives a speed value (km/h) from a GPS position fix.
///
/// Uses [positionSpeed] (m/s from geolocator) when iOS has measured it
/// (value ≥ 0). Falls back to computing speed from the distance between
/// consecutive Kalman-filtered positions when iOS reports −1 (unknown),
/// which happens frequently at walking speeds.
class SpeedCalculator {
  SpeedCalculator._();

  static double computeKmh({
    required double positionSpeed,
    required LatLng currSmooth,
    LatLng? prevSmooth,
    DateTime? prevTimestamp,
    required DateTime currTimestamp,
  }) {
    if (positionSpeed >= 0) return positionSpeed * 3.6;
    if (prevSmooth == null || prevTimestamp == null) return 0.0;
    final elapsedSec =
        currTimestamp.difference(prevTimestamp).inMilliseconds / 1000.0;
    if (elapsedSec <= 0) return 0.0;
    final distMeters = Geolocator.distanceBetween(
      prevSmooth.latitude,
      prevSmooth.longitude,
      currSmooth.latitude,
      currSmooth.longitude,
    );
    return (distMeters / elapsedSec) * 3.6;
  }
}
