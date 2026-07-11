import 'package:flutter/material.dart';
import '../theme.dart';

/// Size variant for [StatTile].
enum StatTileSize {
  /// Oversized hero readout (e.g. the record-screen distance numeral).
  primary,

  /// Compact readout used in a stat row / grid.
  secondary,
}

/// A live-stat tile: a small mono caps [label], an oversized Space Mono
/// [value] numeral, and an optional [unit] suffix.
///
/// The value numeral uses [TrackTheme.statNumeralPrimary] /
/// [statNumeralSecondary] (Space Mono, tabular figures) so digits don't jitter
/// as they update. Pass [valueColor] to tint the value (e.g. accent for the
/// live "NOW" speed).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.size = StatTileSize.primary,
    this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// Uppercase caption above the value (e.g. `DISTANCE`, `MOVING`).
  final String label;

  /// The numeric readout, pre-formatted by the caller (e.g. `24.6`).
  final String value;

  /// Optional unit shown next to the value (e.g. `KM`, `km/h`).
  final String? unit;

  /// Hero vs compact numeral sizing.
  final StatTileSize size;

  /// Overrides the value colour (defaults to primary text).
  final Color? valueColor;

  /// Horizontal alignment of the stacked label/value.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final isPrimary = size == StatTileSize.primary;
    final numeralStyle =
        (isPrimary ? ext.statNumeralPrimary : ext.statNumeralSecondary)
            .copyWith(color: valueColor ?? ext.txt);

    final labelStyle = TextStyle(
      fontFamily: kFontNum,
      fontWeight: FontWeight.w400,
      fontSize: isPrimary ? 10 : 9,
      letterSpacing: isPrimary ? 2 : 1.5,
      color: ext.txt3,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: labelStyle),
        SizedBox(height: isPrimary ? 2 : 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            Text(value, style: numeralStyle),
            if (unit != null) ...[
              const SizedBox(width: 5),
              Text(
                unit!,
                style: labelStyle.copyWith(color: ext.txt3),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
