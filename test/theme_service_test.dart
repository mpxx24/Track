import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService.decode', () {
    test('defaults to dark when the stored value is missing', () {
      expect(ThemeService.decode(null), ThemeMode.dark);
    });

    test('maps the stored strings to the matching mode', () {
      expect(ThemeService.decode('light'), ThemeMode.light);
      expect(ThemeService.decode('dark'), ThemeMode.dark);
    });

    test('falls back to dark for an unrecognised value', () {
      expect(ThemeService.decode('purple'), ThemeMode.dark);
    });
  });

  group('ThemeService persistence', () {
    test('load() starts dark with no stored preference', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.load();
      expect(service.mode.value, ThemeMode.dark);
    });

    test('load() honours a persisted light preference', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final service = ThemeService();
      await service.load();
      expect(service.mode.value, ThemeMode.light);
    });

    test('setDarkMode(false) updates the notifier and persists light', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.load();

      await service.setDarkMode(false);
      expect(service.mode.value, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('setDarkMode(true) round-trips back to dark', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final service = ThemeService();
      await service.load();
      expect(service.mode.value, ThemeMode.light);

      await service.setDarkMode(true);
      expect(service.mode.value, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });
}
