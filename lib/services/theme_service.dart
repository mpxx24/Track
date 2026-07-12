import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's [ThemeMode] and persists the choice in SharedPreferences.
///
/// A single shared instance ([themeService]) is created at the top of this file
/// so both `main` (which listens to [mode]) and the Settings screen (which calls
/// [setDarkMode]) reference the same state without threading it through routes.
class ThemeService {
  static const String prefKey = 'theme_mode';

  /// Current theme mode. Listen via [ValueListenableBuilder] to rebuild the app
  /// reactively when the preference changes.
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Maps a persisted string to a [ThemeMode]. Defaults to dark for a missing
  /// or unrecognised value.
  static ThemeMode decode(String? value) =>
      value == 'light' ? ThemeMode.light : ThemeMode.dark;

  /// Reads the persisted preference into [mode]. Call once during startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = decode(prefs.getString(prefKey));
  }

  /// Applies dark/light immediately (updating [mode]) and persists the choice.
  Future<void> setDarkMode(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, dark ? 'dark' : 'light');
  }
}

/// Shared instance used by `main` and the Settings screen.
final ThemeService themeService = ThemeService();
