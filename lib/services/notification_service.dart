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
  }) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );
    await _plugin.show(
      _recordingNotificationId,
      'Track. — Recording',
      '$distance km  •  $movingTime  •  $avgSpeed km/h',
      details,
    );
  }

  Future<void> cancelRecordingNotification() async {
    await _plugin.cancel(_recordingNotificationId);
  }
}
