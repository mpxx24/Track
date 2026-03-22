/// Position-only Kalman filter for GPS smoothing.
///
/// Weights each incoming reading by its reported accuracy — high-accuracy
/// fixes shift the estimate more; low-accuracy fixes shift it less.
/// This reduces route jitter and prevents GPS noise from inflating distance.
class KalmanFilter {
  double _lat = 0;
  double _lng = 0;
  double _variance = -1; // negative = uninitialised

  static const double _minAccuracy = 1.0; // clamp to avoid division issues

  /// Feed a raw GPS reading. Returns the smoothed (lat, lng).
  (double lat, double lng) update(
      double lat, double lng, double accuracyMeters) {
    final accuracy =
        accuracyMeters < _minAccuracy ? _minAccuracy : accuracyMeters;

    if (_variance < 0) {
      // First fix — accept as-is
      _lat = lat;
      _lng = lng;
      _variance = accuracy * accuracy;
    } else {
      final measurementVariance = accuracy * accuracy;
      final k = _variance / (_variance + measurementVariance);
      _lat += k * (lat - _lat);
      _lng += k * (lng - _lng);
      _variance = (1 - k) * _variance;
    }

    return (_lat, _lng);
  }

  void reset() => _variance = -1;
}
