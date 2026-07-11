import 'package:flutter/material.dart';
import '../theme.dart';

/// A high-opacity rounded panel for overlaying content on top of map tiles
/// (stat readouts, control clusters). Uses the surface-1 colour at high opacity
/// with a hairline outline and soft shadow so it stays legible over any map.
class MapOverlayPanel extends StatelessWidget {
  const MapOverlayPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.opacity = 0.96,
    this.borderRadius,
  });

  /// Panel contents.
  final Widget child;

  /// Inner padding around [child].
  final EdgeInsetsGeometry padding;

  /// Background opacity applied to the surface colour (0–1).
  final double opacity;

  /// Optional corner radius override (defaults to the top-rounded sheet shape).
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final radius = borderRadius ??
        BorderRadius.vertical(top: Radius.circular(ext.radius));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.s1.withValues(alpha: opacity),
        borderRadius: radius,
        border: Border.all(color: ext.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
