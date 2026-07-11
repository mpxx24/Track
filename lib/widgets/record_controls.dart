import 'package:flutter/material.dart';
import '../theme.dart';

/// The record-screen control cluster: an optional secondary button (left), the
/// large primary pause/resume button (centre), and the stop button (right).
///
/// All targets are at least 48pt. Callbacks are passed in — this widget holds
/// no recording state beyond [isPaused], which flips the primary button between
/// a pause and a resume glyph.
class RecordControls extends StatelessWidget {
  const RecordControls({
    super.key,
    required this.isPaused,
    required this.onPauseResume,
    required this.onStop,
    this.onSecondary,
    this.secondaryIcon = Icons.my_location,
  });

  /// When true the primary button shows a resume (play) glyph; otherwise pause.
  final bool isPaused;

  /// Tapped for the centre pause/resume button.
  final VoidCallback onPauseResume;

  /// Tapped for the stop button.
  final VoidCallback onStop;

  /// Optional left-hand secondary action (e.g. recentre map / mark lap). The
  /// button is omitted entirely when null.
  final VoidCallback? onSecondary;

  /// Icon for the secondary button.
  final IconData secondaryIcon;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;

    Widget squareButton({
      required Key key,
      required VoidCallback onTap,
      required Widget child,
      Color? borderColor,
    }) {
      return SizedBox(
        key: key,
        width: 54,
        height: 54,
        child: Material(
          color: ext.s2,
          borderRadius: BorderRadius.circular(ext.radiusSm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ext.radiusSm),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ext.radiusSm),
                border: Border.all(color: borderColor ?? ext.line),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSecondary != null) ...[
          squareButton(
            key: const ValueKey('record_controls_secondary'),
            onTap: onSecondary!,
            child: Icon(secondaryIcon, size: 20, color: ext.txt2),
          ),
          const SizedBox(width: 22),
        ],
        // Primary pause/resume.
        SizedBox(
          key: const ValueKey('record_controls_primary'),
          width: 74,
          height: 74,
          child: Material(
            color: ext.record,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: onPauseResume,
              customBorder: const CircleBorder(),
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        squareButton(
          key: const ValueKey('record_controls_stop'),
          onTap: onStop,
          borderColor: ext.stop,
          child: Icon(Icons.stop_rounded, size: 22, color: ext.stop),
        ),
      ],
    );
  }
}
