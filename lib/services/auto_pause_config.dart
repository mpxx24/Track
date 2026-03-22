/// Auto-pause thresholds for a given activity type.
///
/// Hysteresis (different pause / resume thresholds) prevents flickering at
/// the boundary. Debounce seconds prevent momentary slowdowns from triggering
/// a pause unnecessarily.
class AutoPauseConfig {
  final bool enabled;
  final double pauseSpeedKmh;
  final double resumeSpeedKmh;
  final int pauseDebounceSeconds;
  final int resumeDebounceSeconds;

  /// Maximum GPS accuracy (in metres) required to record a point.
  /// null means no filter — all points are recorded regardless of accuracy.
  final double? maxRecordAccuracyMeters;

  const AutoPauseConfig({
    required this.enabled,
    this.pauseSpeedKmh = 0,
    this.resumeSpeedKmh = 0,
    this.pauseDebounceSeconds = 0,
    this.resumeDebounceSeconds = 0,
    this.maxRecordAccuracyMeters,
  });

  static AutoPauseConfig forActivity(String activityType) {
    switch (activityType) {
      case 'Ride':
        // Bike stops are deliberate (red lights); resume needs a clear push
        return const AutoPauseConfig(
          enabled: true,
          pauseSpeedKmh: 2.0,
          resumeSpeedKmh: 4.0,
          pauseDebounceSeconds: 5,
          resumeDebounceSeconds: 3,
          maxRecordAccuracyMeters: 20.0,
        );
      case 'Walk':
        // Walkers slow down naturally; use lower thresholds and a longer
        // pause debounce to avoid false triggers at slow pace
        return const AutoPauseConfig(
          enabled: true,
          pauseSpeedKmh: 0.8,
          resumeSpeedKmh: 2.0,
          pauseDebounceSeconds: 8,
          resumeDebounceSeconds: 3,
          maxRecordAccuracyMeters: 20.0,
        );
      case 'Football':
      default:
        // Constant stopping/starting makes auto-pause meaningless for football;
        // no accuracy filter — capture all movement on the pitch
        return const AutoPauseConfig(enabled: false);
    }
  }
}
