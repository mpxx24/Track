import 'dart:io';
import 'package:flutter/services.dart';

class LiveActivityService {
  static const _channel = MethodChannel('com.mariusz.track/liveActivity');

  bool get _supported => Platform.isIOS;

  Future<void> start({required String activityType}) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('startActivity', {
        'activityType': activityType,
      });
    } on PlatformException catch (_) {
      // Live Activities not available (iOS < 16.1 or disabled in settings)
    }
  }

  Future<void> update({
    required String distance,
    required String movingTime,
    required String avgSpeed,
    required bool isPaused,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('updateActivity', {
        'distance': distance,
        'movingTime': movingTime,
        'avgSpeed': avgSpeed,
        'isPaused': isPaused,
      });
    } on PlatformException catch (_) {}
  }

  Future<void> stop() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('stopActivity');
    } on PlatformException catch (_) {}
  }
}
