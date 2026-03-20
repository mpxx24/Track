import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const TrackApp());
}

class TrackApp extends StatelessWidget {
  const TrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Track.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        colorScheme: ColorScheme.dark(
          surface: Colors.grey[900]!,
          primary: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/record': (context) => const RecordScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
