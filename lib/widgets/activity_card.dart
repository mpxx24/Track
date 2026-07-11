import 'package:flutter/material.dart';
import '../theme.dart';
import 'activity_type_picker.dart';

/// A recent-activity list card: type icon (tinted), name + date, and a
/// right-aligned distance with a `duration · avgSpeed` sub-line. An optional
/// [uploaded] badge dot marks synced activities.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.type,
    required this.name,
    required this.dateLabel,
    required this.distance,
    required this.duration,
    required this.avgSpeed,
    this.uploaded = false,
    this.onTap,
  });

  /// Activity type string (drives the icon + tint).
  final String type;

  /// Activity title (e.g. `Evening Ride`).
  final String name;

  /// Pre-formatted date/time label (e.g. `Jul 9 · 18:24`).
  final String dateLabel;

  /// Pre-formatted distance value (e.g. `24.6`), unit-less.
  final String distance;

  /// Pre-formatted duration (e.g. `1:02`).
  final String duration;

  /// Pre-formatted average speed (e.g. `24.1`); pass `—` when not applicable.
  final String avgSpeed;

  /// Shows the uploaded badge dot when true.
  final bool uploaded;

  /// Tapped when the card is pressed.
  final VoidCallback? onTap;

  IconData get _icon {
    for (final o in ActivityTypePicker.defaultOptions) {
      if (o.type.toLowerCase() == type.toLowerCase()) return o.icon;
    }
    return Icons.timeline;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final tint = ext.typeTint(type);
    final mono = TextStyle(fontFamily: kFontNum, color: ext.txt3);

    return Material(
      color: ext.s1,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ext.radius),
            border: Border.all(color: ext.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ext.s2,
                  borderRadius: BorderRadius.circular(ext.radiusSm),
                  border: Border.all(color: tint),
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: ext.txt,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distance,
                    style: ext.statNumeralSecondary.copyWith(
                      fontSize: 17,
                      color: ext.txt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('$duration · $avgSpeed',
                      style: mono.copyWith(fontSize: 10)),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: uploaded ? ext.uploaded : Colors.transparent,
                  border: uploaded ? null : Border.all(color: ext.txt3, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
