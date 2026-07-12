import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeService.load();
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
