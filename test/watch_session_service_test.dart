import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/watch_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mariusz.track/watch');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late WatchSessionService service;
  late List<MethodCall> sentCalls;

  setUp(() {
    sentCalls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      sentCalls.add(call);
      return null;
    });
    service = WatchSessionService(supported: true);
    service.init();
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// Simulates a call arriving from the native side (watch → phone).
  Future<void> simulateNativeCall(String method, dynamic arguments) async {
    await messenger.handlePlatformMessage(
      'com.mariusz.track/watch',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  group('outgoing state updates', () {
    test('update sends full recording state', () async {
      await service.update(
        activityType: 'Ride',
        distanceKm: 4.217,
        elapsed: '00:20:11',
        movingTime: '00:18:02',
        currentSpeedKmh: 18.44,
        isPaused: false,
      );

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'updateState');
      expect(sentCalls.single.arguments, {
        'isRecording': true,
        'isPaused': false,
        'activityType': 'Ride',
        'distanceKm': 4.217,
        'elapsed': '00:20:11',
        'movingTime': '00:18:02',
        'currentSpeedKmh': 18.44,
      });
    });

    test('setIdle sends isRecording=false', () async {
      await service.setIdle();

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'updateState');
      expect(sentCalls.single.arguments['isRecording'], false);
    });

    test('unsupported platform sends nothing', () async {
      final unsupported = WatchSessionService(supported: false);
      await unsupported.update(
        activityType: 'Run',
        distanceKm: 1,
        elapsed: '00:01:00',
        movingTime: '00:01:00',
        currentSpeedKmh: 10,
        isPaused: false,
      );
      await unsupported.setIdle();
      expect(sentCalls, isEmpty);
    });
  });

  group('incoming watch commands', () {
    test('start command carries the activity type', () async {
      final commands = <WatchCommand>[];
      final sub = service.commands.listen(commands.add);

      await simulateNativeCall(
          'watchCommand', {'command': 'start', 'activityType': 'Run'});
      await Future<void>.delayed(Duration.zero);

      expect(commands, hasLength(1));
      expect(commands.single.kind, WatchCommandKind.start);
      expect(commands.single.activityType, 'Run');
      await sub.cancel();
    });

    test('pause, resume and stop commands are dispatched', () async {
      final commands = <WatchCommand>[];
      final sub = service.commands.listen(commands.add);

      await simulateNativeCall('watchCommand', {'command': 'pause'});
      await simulateNativeCall('watchCommand', {'command': 'resume'});
      await simulateNativeCall('watchCommand', {'command': 'stop'});
      await Future<void>.delayed(Duration.zero);

      expect(commands.map((c) => c.kind), [
        WatchCommandKind.pause,
        WatchCommandKind.resume,
        WatchCommandKind.stop,
      ]);
      await sub.cancel();
    });

    test('unknown or malformed commands are ignored', () async {
      final commands = <WatchCommand>[];
      final sub = service.commands.listen(commands.add);

      await simulateNativeCall('watchCommand', {'command': 'selfDestruct'});
      await simulateNativeCall('watchCommand', null);
      await simulateNativeCall('somethingElse', {'command': 'pause'});
      await Future<void>.delayed(Duration.zero);

      expect(commands, isEmpty);
      await sub.cancel();
    });

    test('start command without a type defaults to Ride', () async {
      final commands = <WatchCommand>[];
      final sub = service.commands.listen(commands.add);

      await simulateNativeCall('watchCommand', {'command': 'start'});
      await Future<void>.delayed(Duration.zero);

      expect(commands.single.activityType, 'Ride');
      await sub.cancel();
    });
  });
}
