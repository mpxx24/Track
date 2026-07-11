import 'package:flutter/material.dart';
import '../theme.dart';

/// A settings list row: a [title] on the left and either a [value] text (with a
/// chevron) or a custom [trailing] widget (e.g. a [Switch]) on the right.
///
/// If [trailing] is supplied it replaces the value/chevron entirely.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  /// Left-hand label.
  final String title;

  /// Right-hand value text (mono). Ignored when [trailing] is set.
  final String? value;

  /// Custom trailing widget; replaces [value] + chevron.
  final Widget? trailing;

  /// Tapped when the row is pressed (navigation rows).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;

    Widget right;
    if (trailing != null) {
      right = trailing!;
    } else {
      right = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                fontFamily: kFontNum,
                fontSize: 13,
                color: ext.txt2,
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: ext.txt3),
          ],
        ],
      );
    }

    return Material(
      color: ext.s1,
      borderRadius: BorderRadius.circular(ext.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ext.radiusSm),
            border: Border.all(color: ext.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: ext.txt,
                  ),
                ),
              ),
              right,
            ],
          ),
        ),
      ),
    );
  }
}
