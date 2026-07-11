import 'package:flutter/material.dart';
import '../theme.dart';

/// One selectable activity type in an [ActivityTypePicker].
class ActivityTypeOption {
  const ActivityTypeOption(this.type, this.label, this.icon);

  /// Canonical type string (e.g. `Ride`) — sent back via `onSelected` and used
  /// for [TrackTheme.typeTint] lookup.
  final String type;

  /// Human-readable label shown under the icon.
  final String label;

  /// Material icon representing the type.
  final IconData icon;
}

/// A grid of activity-type cells (icon + label + per-type tint). The selected
/// cell is highlighted with the accent colour.
class ActivityTypePicker extends StatelessWidget {
  const ActivityTypePicker({
    super.key,
    required this.selectedType,
    required this.onSelected,
    this.options = defaultOptions,
    this.crossAxisCount = 2,
  });

  /// Currently selected type string (matched against [ActivityTypeOption.type]).
  final String selectedType;

  /// Called with the [ActivityTypeOption.type] when a cell is tapped.
  final ValueChanged<String> onSelected;

  /// The types to display. Defaults to [defaultOptions] (the five Track types).
  final List<ActivityTypeOption> options;

  /// Number of columns in the grid.
  final int crossAxisCount;

  /// The five Track activity types, in display order.
  static const List<ActivityTypeOption> defaultOptions = [
    ActivityTypeOption('Ride', 'Ride', Icons.directions_bike),
    ActivityTypeOption('Run', 'Run', Icons.directions_run),
    ActivityTypeOption('Walk', 'Walk', Icons.directions_walk),
    ActivityTypeOption('Football', 'Football', Icons.sports_soccer),
    ActivityTypeOption('Swim', 'Swim', Icons.pool),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    // A non-scrolling manual grid (rows of [crossAxisCount]) so every cell is
    // always laid out — the picker sizes to its content and is embedded in the
    // caller's scroll view rather than scrolling itself.
    const gap = 10.0;
    final cells = [
      for (final opt in options)
        _TypeCell(
          option: opt,
          tint: ext.typeTint(opt.type),
          selected: opt.type == selectedType,
          onTap: () => onSelected(opt.type),
        ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += crossAxisCount) {
      final rowCells = <Widget>[];
      for (var c = 0; c < crossAxisCount; c++) {
        final idx = i + c;
        if (c > 0) rowCells.add(const SizedBox(width: gap));
        rowCells.add(Expanded(
          child: idx < cells.length ? cells[idx] : const SizedBox.shrink(),
        ));
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowCells),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _TypeCell extends StatelessWidget {
  const _TypeCell({
    required this.option,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final ActivityTypeOption option;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Material(
      color: selected ? ext.s2 : ext.s1,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radius),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ext.radius),
            border: Border.all(
              color: selected ? ext.record : ext.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ext.bg,
                  borderRadius: BorderRadius.circular(ext.radiusSm),
                  border: Border.all(color: tint),
                ),
                alignment: Alignment.center,
                child: Icon(option.icon, size: 20, color: tint),
              ),
              Text(
                option.label,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: selected ? ext.txt : ext.txt2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
