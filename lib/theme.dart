import 'package:flutter/material.dart';

/// Lume design system — theme, tokens and semantic styling for Track.
///
/// The source of truth is the "Lume" HTML design export (dark = 1B/2B,
/// light = 2A). Screen widgets should read colours and styles from
/// [ThemeData.colorScheme], [ThemeData.textTheme] and the [TrackTheme]
/// extension rather than hard-coding hex values.

// ---------------------------------------------------------------------------
// Font families (bundled as assets — see pubspec.yaml). Do not use the
// google_fonts runtime-fetch package: the app is used outdoors and offline.
// ---------------------------------------------------------------------------
const String kFontUi = 'Archivo';
const String kFontNum = 'SpaceMono';

// ---------------------------------------------------------------------------
// Spacing scale
// ---------------------------------------------------------------------------
/// Simple 4-based spacing scale used across Track screens.
abstract final class TrackSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;
}

// ---------------------------------------------------------------------------
// Radii
// ---------------------------------------------------------------------------
/// Corner radii tokens (`--radius`, `--radius-sm`, `--radius-chip`).
abstract final class TrackRadii {
  static const double radius = 20;
  static const double radiusSm = 14;
  static const double radiusChip = 999;
}

// ---------------------------------------------------------------------------
// Raw token palettes
// ---------------------------------------------------------------------------
class _Tokens {
  const _Tokens({
    required this.bg,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.line,
    required this.txt,
    required this.txt2,
    required this.txt3,
    required this.accent,
    required this.accent2,
    required this.pause,
    required this.stop,
    required this.up,
    required this.uploading,
    required this.failed,
    required this.tRide,
    required this.tWalk,
    required this.tRun,
    required this.tFb,
    required this.tSwim,
  });

  final Color bg, s1, s2, s3, line, txt, txt2, txt3;
  final Color accent, accent2, pause, stop, up, uploading, failed;
  final Color tRide, tWalk, tRun, tFb, tSwim;
}

const _Tokens _dark = _Tokens(
  bg: Color(0xFF0A0C0D),
  s1: Color(0xFF10161A),
  s2: Color(0xFF182228),
  s3: Color(0xFF22303A),
  line: Color(0xFF2A3A44),
  txt: Color(0xFFEAF2F5),
  txt2: Color(0xFF9FB2BC),
  txt3: Color(0xFF5F727C),
  accent: Color(0xFF22D3EE),
  accent2: Color(0xFF0FB6D4),
  pause: Color(0xFFF5B833),
  stop: Color(0xFFFF5A52),
  up: Color(0xFF34D399),
  uploading: Color(0xFF58C6F0),
  failed: Color(0xFFFF5A52),
  tRide: Color(0xFF38BDF8),
  tWalk: Color(0xFF34D399),
  tRun: Color(0xFFFBBF6B),
  tFb: Color(0xFFC084FC),
  tSwim: Color(0xFF22D3EE),
);

const _Tokens _light = _Tokens(
  bg: Color(0xFFF3F5F6),
  s1: Color(0xFFFFFFFF),
  s2: Color(0xFFEDF1F3),
  s3: Color(0xFFDFE7EA),
  line: Color(0xFFD3DCE0),
  txt: Color(0xFF0D191E),
  txt2: Color(0xFF47575F),
  txt3: Color(0xFF7C8D95),
  accent: Color(0xFF0891B2),
  accent2: Color(0xFF0E7490),
  pause: Color(0xFFB45309),
  stop: Color(0xFFDC2626),
  up: Color(0xFF059669),
  uploading: Color(0xFF0284C7),
  failed: Color(0xFFDC2626),
  tRide: Color(0xFF0284C7),
  tWalk: Color(0xFF059669),
  tRun: Color(0xFFC2600C),
  tFb: Color(0xFF9333EA),
  tSwim: Color(0xFF0891B2),
);

// ---------------------------------------------------------------------------
// TrackTheme — ThemeExtension carrying the raw tokens + semantic styling.
// ---------------------------------------------------------------------------
/// Design-system tokens that don't map cleanly onto Material's [ColorScheme].
///
/// Read via `Theme.of(context).extension<TrackTheme>()!`.
@immutable
class TrackTheme extends ThemeExtension<TrackTheme> {
  const TrackTheme({
    // surfaces + text
    required this.bg,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.line,
    required this.txt,
    required this.txt2,
    required this.txt3,
    // semantic
    required this.record,
    required this.pause,
    required this.stop,
    required this.uploaded,
    required this.uploading,
    required this.failed,
    // per-type tints
    required this.tintRide,
    required this.tintWalk,
    required this.tintRun,
    required this.tintFootball,
    required this.tintSwim,
    // numeral styles
    required this.statNumeralPrimary,
    required this.statNumeralSecondary,
    // radii
    this.radius = TrackRadii.radius,
    this.radiusSm = TrackRadii.radiusSm,
    this.radiusChip = TrackRadii.radiusChip,
  });

  final Color bg, s1, s2, s3, line, txt, txt2, txt3;
  final Color record, pause, stop, uploaded, uploading, failed;
  final Color tintRide, tintWalk, tintRun, tintFootball, tintSwim;
  final TextStyle statNumeralPrimary;
  final TextStyle statNumeralSecondary;
  final double radius, radiusSm, radiusChip;

  /// Per-activity-type accent tint. Case-insensitive; unknown types fall back
  /// to [txt2] (a neutral secondary colour).
  Color typeTint(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'ride':
        return tintRide;
      case 'walk':
        return tintWalk;
      case 'run':
        return tintRun;
      case 'football':
        return tintFootball;
      case 'swim':
        return tintSwim;
      default:
        return txt2;
    }
  }

  static TrackTheme _build(_Tokens t) {
    const numeralBase = TextStyle(
      fontFamily: kFontNum,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return TrackTheme(
      bg: t.bg,
      s1: t.s1,
      s2: t.s2,
      s3: t.s3,
      line: t.line,
      txt: t.txt,
      txt2: t.txt2,
      txt3: t.txt3,
      record: t.accent,
      pause: t.pause,
      stop: t.stop,
      uploaded: t.up,
      uploading: t.uploading,
      failed: t.failed,
      tintRide: t.tRide,
      tintWalk: t.tWalk,
      tintRun: t.tRun,
      tintFootball: t.tFb,
      tintSwim: t.tSwim,
      // Oversized live-stat numerals (record screen distance readout).
      statNumeralPrimary: numeralBase.copyWith(
        fontSize: 64,
        height: 0.92,
        letterSpacing: -2.5,
        color: t.txt,
      ),
      statNumeralSecondary: numeralBase.copyWith(
        fontSize: 20,
        letterSpacing: -0.5,
        color: t.txt,
      ),
    );
  }

  static final TrackTheme dark = _build(_dark);
  static final TrackTheme light = _build(_light);

  @override
  TrackTheme copyWith({
    Color? bg,
    Color? s1,
    Color? s2,
    Color? s3,
    Color? line,
    Color? txt,
    Color? txt2,
    Color? txt3,
    Color? record,
    Color? pause,
    Color? stop,
    Color? uploaded,
    Color? uploading,
    Color? failed,
    Color? tintRide,
    Color? tintWalk,
    Color? tintRun,
    Color? tintFootball,
    Color? tintSwim,
    TextStyle? statNumeralPrimary,
    TextStyle? statNumeralSecondary,
    double? radius,
    double? radiusSm,
    double? radiusChip,
  }) {
    return TrackTheme(
      bg: bg ?? this.bg,
      s1: s1 ?? this.s1,
      s2: s2 ?? this.s2,
      s3: s3 ?? this.s3,
      line: line ?? this.line,
      txt: txt ?? this.txt,
      txt2: txt2 ?? this.txt2,
      txt3: txt3 ?? this.txt3,
      record: record ?? this.record,
      pause: pause ?? this.pause,
      stop: stop ?? this.stop,
      uploaded: uploaded ?? this.uploaded,
      uploading: uploading ?? this.uploading,
      failed: failed ?? this.failed,
      tintRide: tintRide ?? this.tintRide,
      tintWalk: tintWalk ?? this.tintWalk,
      tintRun: tintRun ?? this.tintRun,
      tintFootball: tintFootball ?? this.tintFootball,
      tintSwim: tintSwim ?? this.tintSwim,
      statNumeralPrimary: statNumeralPrimary ?? this.statNumeralPrimary,
      statNumeralSecondary: statNumeralSecondary ?? this.statNumeralSecondary,
      radius: radius ?? this.radius,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusChip: radiusChip ?? this.radiusChip,
    );
  }

  @override
  TrackTheme lerp(covariant ThemeExtension<TrackTheme>? other, double t) {
    if (other is! TrackTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return TrackTheme(
      bg: c(bg, other.bg),
      s1: c(s1, other.s1),
      s2: c(s2, other.s2),
      s3: c(s3, other.s3),
      line: c(line, other.line),
      txt: c(txt, other.txt),
      txt2: c(txt2, other.txt2),
      txt3: c(txt3, other.txt3),
      record: c(record, other.record),
      pause: c(pause, other.pause),
      stop: c(stop, other.stop),
      uploaded: c(uploaded, other.uploaded),
      uploading: c(uploading, other.uploading),
      failed: c(failed, other.failed),
      tintRide: c(tintRide, other.tintRide),
      tintWalk: c(tintWalk, other.tintWalk),
      tintRun: c(tintRun, other.tintRun),
      tintFootball: c(tintFootball, other.tintFootball),
      tintSwim: c(tintSwim, other.tintSwim),
      statNumeralPrimary:
          TextStyle.lerp(statNumeralPrimary, other.statNumeralPrimary, t)!,
      statNumeralSecondary:
          TextStyle.lerp(statNumeralSecondary, other.statNumeralSecondary, t)!,
      radius: lerpDouble(radius, other.radius, t),
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t),
      radiusChip: lerpDouble(radiusChip, other.radiusChip, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

// ---------------------------------------------------------------------------
// ColorScheme + TextTheme + ThemeData factories
// ---------------------------------------------------------------------------
ColorScheme _colorScheme(_Tokens t, Brightness brightness) {
  final onAccent = brightness == Brightness.dark ? t.bg : Colors.white;
  return ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: onAccent,
    secondary: t.accent2,
    onSecondary: onAccent,
    error: t.failed,
    onError: Colors.white,
    surface: t.bg,
    onSurface: t.txt,
    onSurfaceVariant: t.txt2,
    surfaceContainerLowest: t.bg,
    surfaceContainerLow: t.s1,
    surfaceContainer: t.s1,
    surfaceContainerHigh: t.s2,
    surfaceContainerHighest: t.s3,
    outline: t.line,
    outlineVariant: t.line,
  );
}

TextTheme _textTheme(_Tokens t) {
  TextStyle ui(double size, FontWeight weight,
          {double? spacing, Color? color, double? height}) =>
      TextStyle(
        fontFamily: kFontUi,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: color ?? t.txt,
      );
  return TextTheme(
    // Display / headline — screen titles (Archivo 800, tight tracking).
    displaySmall: ui(26, FontWeight.w800, spacing: -0.6),
    headlineMedium: ui(24, FontWeight.w800, spacing: -0.6),
    headlineSmall: ui(22, FontWeight.w800, spacing: -0.5),
    titleLarge: ui(20, FontWeight.w800, spacing: -0.4),
    titleMedium: ui(16, FontWeight.w700),
    titleSmall: ui(15, FontWeight.w600),
    bodyLarge: ui(15, FontWeight.w400, color: t.txt2),
    bodyMedium: ui(14, FontWeight.w400, color: t.txt2),
    bodySmall: ui(12, FontWeight.w400, color: t.txt3),
    labelLarge: ui(14, FontWeight.w600),
    labelMedium: ui(12, FontWeight.w500, color: t.txt2),
    labelSmall: ui(11, FontWeight.w600, spacing: 1, color: t.txt3),
  );
}

ThemeData _themeData(_Tokens t, Brightness brightness, TrackTheme ext) {
  final cs = _colorScheme(t, brightness);
  final tt = _textTheme(t);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: t.bg,
    fontFamily: kFontUi,
    textTheme: tt,
    canvasColor: t.bg,
    dividerColor: t.line,
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.txt,
      elevation: 0,
      titleTextStyle: tt.headlineMedium,
    ),
    iconTheme: IconThemeData(color: t.txt2),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.s2,
      contentTextStyle: TextStyle(fontFamily: kFontUi, color: t.txt),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.onPrimary : t.txt2,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.accent : t.s3,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    extensions: [ext],
  );
}

/// Lume dark theme (design 1B/2B) — the app's default.
ThemeData trackDarkTheme() => _themeData(_dark, Brightness.dark, TrackTheme.dark);

/// Lume light theme (design 2A) — retuned for WCAG AA; wired for later use.
ThemeData trackLightTheme() =>
    _themeData(_light, Brightness.light, TrackTheme.light);
