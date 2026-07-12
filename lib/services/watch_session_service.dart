import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

enum WatchCommandKind { start, pause, resume, stop }

/// Remote-control command received from the Apple Watch.
class WatchCommand {
  final WatchCommandKind kind;
  final String activityType;

  const WatchCommand(this.kind, {this.activityType = 'Ride'});
}

/// Phone-side bridge to the TrackWatch app.
///
/// Outgoing: per-second recording state pushed over the
/// `com.mariusz.track/watch` MethodChannel (native side relays via WCSession).
/// Incoming: start/pause/resume/stop commands surfaced on [commands].
/// Field and command names must stay in sync with
/// `ios/TrackWatch/WatchState.swift` and `ios/Runner/WatchSessionService.swift`.
class WatchSessionService {
  static const _channel = MethodChannel('com.mariusz.track/watch');

  final bool _supported;
  final _commandController = StreamController<WatchCommand>.broadcast();

  bool _isRecording = false;

  WatchSessionService({bool? supported})
      : _supported = supported ?? Platform.isIOS;

  Stream<WatchCommand> get commands => _commandController.stream;

  /// Whether the phone is currently recording, as last reported to the watch.
  /// Used to ignore a watch "start" while a recording is already running.
  bool get isRecording => _isRecording;

  void init() {
    if (!_supported) return;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> update({
    required String activityType,
    required double distanceKm,
    required String elapsed,
    required String movingTime,
    required double currentSpeedKmh,
    required bool isPaused,
  }) async {
    if (!_supported) return;
    _isRecording = true;
    try {
      await _channel.invokeMethod('updateState', {
        'isRecording': true,
        'isPaused': isPaused,
        'activityType': activityType,
        'distanceKm': distanceKm,
        'elapsed': elapsed,
        'movingTime': movingTime,
        'currentSpeedKmh': currentSpeedKmh,
      });
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  Future<void> setIdle() async {
    if (!_supported) return;
    _isRecording = false;
    try {
      await _channel.invokeMethod('updateState', {'isRecording': false});
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'watchCommand') return;
    final args = call.arguments;
    if (args is! Map) return;

    switch (args['command']) {
      case 'start':
        _commandController.add(WatchCommand(
          WatchCommandKind.start,
          activityType: args['activityType'] as String? ?? 'Ride',
        ));
      case 'pause':
        _commandController.add(const WatchCommand(WatchCommandKind.pause));
      case 'resume':
        _commandController.add(const WatchCommand(WatchCommandKind.resume));
      case 'stop':
        _commandController.add(const WatchCommand(WatchCommandKind.stop));
    }
  }

  void dispose() {
    _commandController.close();
    if (_supported) _channel.setMethodCallHandler(null);
  }
}

/// App-wide instance — screens push state through this, `main.dart` listens
/// for start commands.
final watchSessionService = WatchSessionService();
