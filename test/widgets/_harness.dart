import 'package:flutter/material.dart';
import 'package:track/theme.dart';

/// Wraps [child] in a themed MaterialApp/Scaffold for widget tests.
Widget wrapThemed(Widget child, {bool dark = true}) {
  return MaterialApp(
    theme: trackLightTheme(),
    darkTheme: trackDarkTheme(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(body: Center(child: child)),
  );
}
