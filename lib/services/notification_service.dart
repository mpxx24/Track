import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const int _recordingNotificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: false);
  }

  Future<void> showRecordingNotification({
    required String distance,
    required String movingTime,
    required String avgSpeed,
    required bool paused,
  }) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );
    final title =
        paused ? 'Track. — Paused' : 'Track. — Recording';
    final body = paused
        ? '⏸  $distance km  •  $movingTime'
        : '$distance km  •  $movingTime  •  $avgSpeed km/h';
    await _plugin.show(_recordingNotificationId, title, body, details);
  }

  Future<void> cancelRecordingNotification() async {
    await _plugin.cancel(_recordingNotificationId);
  }
}
