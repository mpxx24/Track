import 'package:intl/intl.dart';

class ActivityRecord {
  final String id;
  final DateTime startedAt;
  final double distanceKm;
  final Duration duration;        // total elapsed (wall clock)
  final Duration movingDuration;  // time actually moving
  final double avgSpeedKmh;       // distanceKm / movingDuration hours
  final String activityType;
  final String gpxFilePath;
  final bool uploaded;

  const ActivityRecord({
    required this.id,
    required this.startedAt,
    required this.distanceKm,
    required this.duration,
    required this.movingDuration,
    required this.avgSpeedKmh,
    required this.activityType,
    required this.gpxFilePath,
    required this.uploaded,
  });

  ActivityRecord copyWith({
    String? id,
    DateTime? startedAt,
    double? distanceKm,
    Duration? duration,
    Duration? movingDuration,
    double? avgSpeedKmh,
    String? activityType,
    String? gpxFilePath,
    bool? uploaded,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      duration: duration ?? this.duration,
      movingDuration: movingDuration ?? this.movingDuration,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      activityType: activityType ?? this.activityType,
      gpxFilePath: gpxFilePath ?? this.gpxFilePath,
      uploaded: uploaded ?? this.uploaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startedAt),
      'distanceKm': distanceKm,
      'durationSeconds': duration.inSeconds,
      'movingDurationSeconds': movingDuration.inSeconds,
      'avgSpeedKmh': avgSpeedKmh,
      'activityType': activityType,
      'gpxFilePath': gpxFilePath,
      'uploaded': uploaded,
    };
  }

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    final durationSeconds = json['durationSeconds'] as int;
    final movingSeconds = (json['movingDurationSeconds'] as int?) ?? durationSeconds;
    final movingDuration = Duration(seconds: movingSeconds);
    final distanceKm = (json['distanceKm'] as num).toDouble();

    // Compute avgSpeedKmh from stored value or derive from moving time if missing
    double avgSpeedKmh = (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    if (avgSpeedKmh == 0.0 && movingDuration.inSeconds > 0 && distanceKm > 0) {
      avgSpeedKmh = distanceKm / (movingDuration.inSeconds / 3600.0);
    }

    return ActivityRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      distanceKm: distanceKm,
      duration: Duration(seconds: durationSeconds),
      movingDuration: movingDuration,
      avgSpeedKmh: avgSpeedKmh,
      activityType: json['activityType'] as String,
      gpxFilePath: json['gpxFilePath'] as String,
      uploaded: json['uploaded'] as bool,
    );
  }
}
