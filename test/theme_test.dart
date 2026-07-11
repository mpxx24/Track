import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/theme.dart';

void main() {
  group('ColorScheme tokens', () {
    test('dark theme maps Lume dark tokens', () {
      final theme = trackDarkTheme();
      final cs = theme.colorScheme;
      expect(cs.brightness, Brightness.dark);
      expect(cs.primary, const Color(0xFF22D3EE)); // accent
      expect(cs.surface, const Color(0xFF0A0C0D)); // bg
      expect(cs.onSurface, const Color(0xFFEAF2F5)); // txt
      expect(cs.outline, const Color(0xFF2A3A44)); // line
      // Surface container stack: s1/s2/s3
      expect(cs.surfaceContainer, const Color(0xFF10161A)); // s1
      expect(cs.surfaceContainerHigh, const Color(0xFF182228)); // s2
      expect(cs.surfaceContainerHighest, const Color(0xFF22303A)); // s3
    });

    test('light theme maps Lume light tokens', () {
      final theme = trackLightTheme();
      final cs = theme.colorScheme;
      expect(cs.brightness, Brightness.light);
      expect(cs.primary, const Color(0xFF0891B2)); // accent
      expect(cs.surface, const Color(0xFFF3F5F6)); // bg
      expect(cs.onSurface, const Color(0xFF0D191E)); // txt
      expect(cs.outline, const Color(0xFFD3DCE0)); // line
      expect(cs.surfaceContainer, const Color(0xFFFFFFFF)); // s1
      expect(cs.surfaceContainerHigh, const Color(0xFFEDF1F3)); // s2
      expect(cs.surfaceContainerHighest, const Color(0xFFDFE7EA)); // s3
    });
  });

  group('TrackTheme extension', () {
    TrackTheme darkExt() => trackDarkTheme().extension<TrackTheme>()!;
    TrackTheme lightExt() => trackLightTheme().extension<TrackTheme>()!;

    test('dark extension is present with semantic colors', () {
      final ext = darkExt();
      expect(ext.record, const Color(0xFF22D3EE));
      expect(ext.pause, const Color(0xFFF5B833));
      expect(ext.stop, const Color(0xFFFF5A52));
      expect(ext.uploaded, const Color(0xFF34D399));
      expect(ext.uploading, const Color(0xFF58C6F0));
      expect(ext.failed, const Color(0xFFFF5A52));
    });

    test('dark extension surface + text tokens', () {
      final ext = darkExt();
      expect(ext.bg, const Color(0xFF0A0C0D));
      expect(ext.s1, const Color(0xFF10161A));
      expect(ext.s2, const Color(0xFF182228));
      expect(ext.s3, const Color(0xFF22303A));
      expect(ext.line, const Color(0xFF2A3A44));
      expect(ext.txt, const Color(0xFFEAF2F5));
      expect(ext.txt2, const Color(0xFF9FB2BC));
      expect(ext.txt3, const Color(0xFF5F727C));
    });

    test('light extension semantic colors differ per theme', () {
      final ext = lightExt();
      expect(ext.pause, const Color(0xFFB45309));
      expect(ext.stop, const Color(0xFFDC2626));
      expect(ext.uploaded, const Color(0xFF059669));
      expect(ext.uploading, const Color(0xFF0284C7));
    });

    test('typeTint returns per-type dark tints, case-insensitive', () {
      final ext = darkExt();
      expect(ext.typeTint('Ride'), const Color(0xFF38BDF8));
      expect(ext.typeTint('walk'), const Color(0xFF34D399));
      expect(ext.typeTint('RUN'), const Color(0xFFFBBF6B));
      expect(ext.typeTint('Football'), const Color(0xFFC084FC));
      expect(ext.typeTint('Swim'), const Color(0xFF22D3EE));
    });

    test('typeTint returns light tints for light theme', () {
      final ext = lightExt();
      expect(ext.typeTint('Ride'), const Color(0xFF0284C7));
      expect(ext.typeTint('Run'), const Color(0xFFC2600C));
      expect(ext.typeTint('Football'), const Color(0xFF9333EA));
    });

    test('typeTint unknown type falls back to a neutral color', () {
      final ext = darkExt();
      expect(ext.typeTint('Kayak'), ext.txt2);
    });

    test('stat numeral styles use SpaceMono with tabular figures', () {
      final ext = darkExt();
      expect(ext.statNumeralPrimary.fontFamily, 'SpaceMono');
      expect(ext.statNumeralSecondary.fontFamily, 'SpaceMono');
      expect(
        ext.statNumeralPrimary.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // primary is larger than secondary
      expect(
        ext.statNumeralPrimary.fontSize! > ext.statNumeralSecondary.fontSize!,
        isTrue,
      );
    });

    test('radius constants match tokens', () {
      final ext = darkExt();
      expect(ext.radius, 20.0);
      expect(ext.radiusSm, 14.0);
      expect(ext.radiusChip, 999.0);
    });

    test('lerp returns a TrackTheme (ThemeExtension contract)', () {
      final a = darkExt();
      final b = lightExt();
      expect(a.lerp(b, 0.5), isA<TrackTheme>());
      expect(a.copyWith(), isA<TrackTheme>());
    });
  });

  group('TextTheme', () {
    test('uses Archivo family', () {
      final theme = trackDarkTheme();
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Archivo');
      expect(theme.useMaterial3, isTrue);
    });
  });

  group('Spacing + radii constants', () {
    test('spacing scale exposes ascending values', () {
      expect(TrackSpacing.sm < TrackSpacing.md, isTrue);
      expect(TrackSpacing.md < TrackSpacing.lg, isTrue);
    });
    test('radii constants exposed', () {
      expect(TrackRadii.radius, 20.0);
      expect(TrackRadii.radiusSm, 14.0);
      expect(TrackRadii.radiusChip, 999.0);
    });
  });
}
