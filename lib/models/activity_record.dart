import 'package:intl/intl.dart';

class ActivityRecord {
  final String id;
  final DateTime startedAt;
  final double distanceKm;
  final Duration duration;
  final String activityType;
  final String gpxFilePath;
  final bool uploaded;

  const ActivityRecord({
    required this.id,
    required this.startedAt,
    required this.distanceKm,
    required this.duration,
    required this.activityType,
    required this.gpxFilePath,
    required this.uploaded,
  });

  ActivityRecord copyWith({
    String? id,
    DateTime? startedAt,
    double? distanceKm,
    Duration? duration,
    String? activityType,
    String? gpxFilePath,
    bool? uploaded,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      duration: duration ?? this.duration,
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
      'activityType': activityType,
      'gpxFilePath': gpxFilePath,
      'uploaded': uploaded,
    };
  }

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      duration: Duration(seconds: json['durationSeconds'] as int),
      activityType: json['activityType'] as String,
      gpxFilePath: json['gpxFilePath'] as String,
      uploaded: json['uploaded'] as bool,
    );
  }
}
