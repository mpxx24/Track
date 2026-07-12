import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/theme_service.dart';
import 'services/watch_session_service.dart';

/// Lets the watch bridge push the record screen without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

StreamSubscription<WatchCommand>? _watchStartSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeService.load();
  watchSessionService.init();
  // Sync the watch to idle at launch — clears a stale "recording" mirror
  // left behind if the app was killed mid-recording.
  watchSessionService.setIdle();
  // Start-from-watch: only when nothing is recording — pause/resume/stop are
  // handled by the active RecordScreen itself.
  _watchStartSubscription ??= watchSessionService.commands.listen((command) {
    if (command.kind != WatchCommandKind.start) return;
    if (watchSessionService.isRecording) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => RecordScreen(initialActivityType: command.activityType),
      ),
    );
  });
  runApp(const TrackApp());
}

class TrackApp extends StatelessWidget {
  const TrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Track.',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: trackLightTheme(),
          darkTheme: trackDarkTheme(),
          themeMode: mode,
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/record': (context) => const RecordScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
