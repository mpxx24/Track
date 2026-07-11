import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';
import '../models/planned_route.dart';
import '../services/history_service.dart';
import '../services/upload_service.dart';
import '../theme.dart';
import 'activity_detail_screen.dart';
import 'planned_routes_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HistoryService _historyService = HistoryService();
  final UploadService _uploadService = UploadService();

  List<ActivityRecord> _history = [];
  bool _loading = true;
  final Set<String> _uploading = {};
  PlannedRoute? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(ActivityRecord record) async {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ext.s2,
        title: Text('Delete activity?', style: TextStyle(color: ext.txt)),
        content: Text('This cannot be undone.', style: TextStyle(color: ext.txt2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ext.txt3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: ext.failed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _historyService.deleteRecord(record.id);
      await _loadHistory();
    }
  }

  Future<void> _uploadRecord(ActivityRecord record) async {
    if (_uploading.contains(record.id)) return;

    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('api_base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';
    final uploadToStrava = prefs.getBool('upload_to_strava') ?? false;

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configure API URL and key in Settings first')),
      );
      return;
    }

    setState(() => _uploading.add(record.id));
    try {
      final file = File(record.gpxFilePath);
      final result = await _uploadService.uploadTrack(
          file, record.activityType, baseUrl, apiKey,
          uploadToStrava: uploadToStrava);

      if (result.success) {
        final updated = record.copyWith(uploaded: true);
        await _historyService.updateRecord(updated);
        await _loadHistory();
        if (!mounted) return;
        final stravaSuffix = switch (result.stravaStatus) {
          null => '',
          'uploaded' => ' · Strava ✓',
          'duplicate' => ' · already on Strava',
          _ => ' · Strava failed',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded successfully$stravaSuffix')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(record.id));
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'Ride':
        return Icons.directions_bike;
      case 'Walk':
        return Icons.directions_walk;
      case 'Football':
        return Icons.sports_soccer;
      case 'Run':
        return Icons.directions_run;
      case 'Swim':
        return Icons.pool;
      default:
        return Icons.fitness_center;
    }
  }

  Future<void> _openRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordScreen(plannedRoute: _selectedRoute),
      ),
    );
    _loadHistory();
  }

  Future<void> _openPlannedRoutes() async {
    final route = await Navigator.push<PlannedRoute>(
      context,
      MaterialPageRoute(builder: (_) => const PlannedRoutesScreen()),
    );
    if (route != null) {
      setState(() => _selectedRoute = route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Scaffold(
      backgroundColor: ext.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: brand + settings.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TrackSpacing.lg, TrackSpacing.sm, TrackSpacing.lg, 0),
              child: Row(
                children: [
                  Text('Track.', style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  _IconSquareButton(
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
            // Prominent start-recording entry point.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg, 0),
              child: _RecordButton(onTap: _openRecord),
            ),
            // Selected planned route pill (kept from prior behaviour).
            if (_selectedRoute != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    TrackSpacing.lg, TrackSpacing.sm, TrackSpacing.lg, 0),
                child: _SelectedRouteChip(
                  name: _selectedRoute!.name,
                  onClear: () => setState(() => _selectedRoute = null),
                ),
              ),
            // Section header: RECENT + Routes link.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TrackSpacing.lg, TrackSpacing.xl, TrackSpacing.lg, TrackSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'RECENT',
                    style: TextStyle(
                      fontFamily: kFontNum,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2,
                      color: ext.txt3,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _openPlannedRoutes,
                    borderRadius: BorderRadius.circular(ext.radiusChip),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        _selectedRoute == null ? 'Routes ›' : 'Change route ›',
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: ext.txt2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: ext.record))
                  : _history.isEmpty
                      ? Center(
                          child: Text(
                            'No activities yet',
                            style: TextStyle(
                                fontFamily: kFontUi, color: ext.txt3),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              TrackSpacing.md, 0, TrackSpacing.md, TrackSpacing.lg),
                          itemCount: _history.length,
                          separatorBuilder: (_, i) =>
                              const SizedBox(height: TrackSpacing.sm),
                          itemBuilder: (context, index) {
                            final record = _history[index];
                            return _HomeActivityCard(
                              record: record,
                              icon: _activityIcon(record.activityType),
                              isUploading: _uploading.contains(record.id),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ActivityDetailScreen(record: record),
                                ),
                              ),
                              onUpload: () => _uploadRecord(record),
                              onDelete: () => _deleteRecord(record),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded-square icon button matching the Lume header affordance
/// (s2 surface, hairline border, muted icon).
class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Material(
      color: ext.s2,
      borderRadius: BorderRadius.circular(ext.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusSm),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ext.radiusSm),
            border: Border.all(color: ext.line),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: ext.txt2),
        ),
      ),
    );
  }
}

/// Full-width accent "RECORD" call-to-action with a leading dot.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Material(
      color: ext.record,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radius),
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ext.bg,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RECORD',
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.5,
                  color: ext.bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Themed pill showing the currently selected planned route with a clear
/// affordance (preserves the pre-restyle route-selection behaviour).
class _SelectedRouteChip extends StatelessWidget {
  const _SelectedRouteChip({required this.name, required this.onClear});

  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ext.s2,
        borderRadius: BorderRadius.circular(ext.radiusChip),
        border: Border.all(color: ext.line),
      ),
      child: Row(
        children: [
          Icon(Icons.map_outlined, color: ext.txt2, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                  fontFamily: kFontUi, color: ext.txt2, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, color: ext.txt3, size: 16),
          ),
        ],
      ),
    );
  }
}

/// Recent-activity card. Mirrors the shared [ActivityCard] visual language
/// (tinted icon box, name/date, right-aligned distance + `duration · avg`
/// sub-line, status dot) but adds the Home-only affordances the shared widget
/// lacks: an inline upload trigger, an uploading spinner, and long-press delete.
class _HomeActivityCard extends StatelessWidget {
  const _HomeActivityCard({
    required this.record,
    required this.icon,
    required this.isUploading,
    required this.onTap,
    required this.onUpload,
    required this.onDelete,
  });

  final ActivityRecord record;
  final IconData icon;
  final bool isUploading;
  final VoidCallback onTap;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  String _compactDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final tint = ext.typeTint(record.activityType);
    final mono = TextStyle(fontFamily: kFontNum, color: ext.txt3);
    final avgLabel =
        record.avgSpeedKmh > 0 ? record.avgSpeedKmh.toStringAsFixed(1) : '—';

    return Material(
      color: ext.s1,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
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
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.activityType,
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
                    Text(
                      DateFormat('MMM d · HH:mm').format(record.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.distanceKm.toStringAsFixed(1),
                    style: ext.statNumeralSecondary.copyWith(
                      fontSize: 17,
                      color: ext.txt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_compactDuration(record.movingDuration)} · $avgLabel',
                    style: mono.copyWith(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              _trailing(ext),
            ],
          ),
        ),
      ),
    );
  }

  /// Upload status / trigger. Uploaded -> filled badge dot; uploading ->
  /// spinner; local -> tappable upload icon (the preserved upload trigger).
  Widget _trailing(TrackTheme ext) {
    if (record.uploaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ext.uploaded,
          ),
        ),
      );
    }
    if (isUploading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: ext.uploading),
        ),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(Icons.cloud_upload_outlined, size: 20, color: ext.txt2),
      onPressed: onUpload,
    );
  }
}
