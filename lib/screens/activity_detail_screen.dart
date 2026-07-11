import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_record.dart';
import '../services/gpx_parser_service.dart';
import '../services/history_service.dart';
import '../services/upload_service.dart';
import '../theme.dart';
import '../widgets/map_overlay_panel.dart';
import '../widgets/settings_row.dart';
import '../widgets/stat_tile.dart';
import '../widgets/upload_status_chip.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityRecord record;

  const ActivityDetailScreen({super.key, required this.record});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final HistoryService _historyService = HistoryService();
  final UploadService _uploadService = UploadService();

  List<LatLng> _points = [];
  bool _loading = true;
  String? _error;

  late bool _uploaded = widget.record.uploaded;
  bool _uploading = false;
  bool _uploadFailed = false;
  bool _stravaEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadStravaPref();
  }

  Future<void> _loadPoints() async {
    try {
      final points =
          await GpxParserService.parseGpxFile(widget.record.gpxFilePath);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load route';
        _loading = false;
      });
    }
  }

  Future<void> _loadStravaPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _stravaEnabled = prefs.getBool('upload_to_strava') ?? false);
  }

  Future<void> _setStrava(bool value) async {
    setState(() => _stravaEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('upload_to_strava', value);
  }

  UploadStatus get _status {
    if (_uploading) return UploadStatus.uploading;
    if (_uploaded) return UploadStatus.uploaded;
    if (_uploadFailed) return UploadStatus.failed;
    return UploadStatus.local;
  }

  MapOptions _buildMapOptions() {
    if (_points.isEmpty) {
      return const MapOptions(
          initialCenter: LatLng(51.5, -0.09), initialZoom: 13);
    }
    if (_points.length == 1) {
      return MapOptions(initialCenter: _points.first, initialZoom: 15);
    }
    final bounds = LatLngBounds.fromPoints(_points);
    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  /// Clock-style duration (`1:02:14` or `12:04`) to match the design mock.
  String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  String _partOfDay(int hour) {
    if (hour < 5) return 'Night';
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  Future<void> _upload() async {
    if (_uploading) return;

    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('api_base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configure API URL and key in Settings first')),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadFailed = false;
    });
    try {
      final file = File(widget.record.gpxFilePath);
      final result = await _uploadService.uploadTrack(
        file,
        widget.record.activityType,
        baseUrl,
        apiKey,
        uploadToStrava: _stravaEnabled,
      );

      if (result.success) {
        final updated = widget.record.copyWith(uploaded: true);
        await _historyService.updateRecord(updated);
        if (!mounted) return;
        setState(() => _uploaded = true);
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
        setState(() => _uploadFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// No share plugin is bundled (offline-first app), so "export" copies the raw
  /// GPX to the clipboard — the offline-safe equivalent of the mock's button.
  Future<void> _exportGpx() async {
    try {
      final file = File(widget.record.gpxFilePath);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPX file not found')),
        );
        return;
      }
      final content = await file.readAsString();
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPX copied to clipboard')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export GPX')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final mapHeight =
        (MediaQuery.sizeOf(context).height * 0.42).clamp(220.0, 460.0);

    return Scaffold(
      backgroundColor: ext.bg,
      body: Column(
        children: [
          SizedBox(height: mapHeight, child: _buildMapArea(ext)),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                decoration: BoxDecoration(
                  color: ext.bg,
                  border: Border(top: BorderSide(color: ext.line)),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.xl),
                  child: _buildSheet(ext),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------
  Widget _buildMapArea(TrackTheme ext) {
    final tint = ext.typeTint(widget.record.activityType);
    final Widget content;
    if (_loading) {
      content = ColoredBox(
        color: ext.s1,
        child: Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary)),
      );
    } else if (_error != null) {
      content = ColoredBox(
        color: ext.s1,
        child: Center(
          child: Text(_error!,
              style: TextStyle(color: ext.txt2, fontFamily: kFontUi)),
        ),
      );
    } else {
      content = _buildMap(tint);
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(TrackSpacing.md),
            child: Align(
              alignment: Alignment.topLeft,
              child: _BackButton(onTap: () => Navigator.of(context).maybePop()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(Color tint) {
    return FlutterMap(
      options: _buildMapOptions(),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mariusz.track',
        ),
        if (_points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: _points, color: tint, strokeWidth: 4.0),
            ],
          ),
        if (_points.isNotEmpty)
          MarkerLayer(
            markers: [
              _endpoint(_points.first, fill: Colors.white, ring: tint),
              if (_points.length > 1)
                _endpoint(_points.last, fill: tint, ring: Colors.white),
            ],
          ),
      ],
    );
  }

  Marker _endpoint(LatLng point, {required Color fill, required Color ring}) {
    return Marker(
      point: point,
      width: 16,
      height: 16,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 3),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sheet
  // ---------------------------------------------------------------------------
  Widget _buildSheet(TrackTheme ext) {
    final record = widget.record;
    final start = record.startedAt;
    final end = start.add(record.duration);
    final dateLine =
        '${DateFormat('MMM d').format(start)} · ${DateFormat('HH:mm').format(start)} → ${DateFormat('HH:mm').format(end)}';
    final tint = ext.typeTint(record.activityType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _typeChip(ext, tint),
            UploadStatusChip(status: _status),
          ],
        ),
        const SizedBox(height: TrackSpacing.md),
        Text(
          '${_partOfDay(start.hour)} ${record.activityType}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: TrackSpacing.xs),
        Text(
          dateLine,
          style: TextStyle(
            fontFamily: kFontNum,
            fontSize: 12,
            color: ext.txt3,
          ),
        ),
        const SizedBox(height: TrackSpacing.lg),
        _statGrid(ext, tint),
        const SizedBox(height: TrackSpacing.xl),
        _sectionLabel(ext, 'UPLOAD'),
        const SizedBox(height: TrackSpacing.sm),
        SettingsRow(
          title: 'ActivitiesJournal',
          value: _uploaded ? 'UPLOADED' : 'READY',
        ),
        const SizedBox(height: TrackSpacing.sm),
        SettingsRow(
          title: 'Strava',
          trailing: Switch(value: _stravaEnabled, onChanged: _setStrava),
        ),
        const SizedBox(height: TrackSpacing.md),
        _uploadButton(ext),
        const SizedBox(height: TrackSpacing.sm),
        _exportButton(ext),
      ],
    );
  }

  Widget _typeChip(TrackTheme ext, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: ext.s2,
        borderRadius: BorderRadius.circular(ext.radiusChip),
        border: Border.all(color: ext.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            widget.record.activityType.toUpperCase(),
            style: TextStyle(
              fontFamily: kFontNum,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.5,
              color: ext.txt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(TrackTheme ext, Color tint) {
    final record = widget.record;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(ext,
                  label: 'DISTANCE',
                  unit: 'KM',
                  value: record.distanceKm.toStringAsFixed(2)),
            ),
            const SizedBox(width: TrackSpacing.sm),
            Expanded(
              child: _statCard(ext,
                  label: 'MOVING', value: _clock(record.movingDuration)),
            ),
          ],
        ),
        const SizedBox(height: TrackSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _statCard(ext,
                  label: 'AVG',
                  unit: 'km/h',
                  value: record.avgSpeedKmh.toStringAsFixed(1),
                  valueColor: tint),
            ),
            const SizedBox(width: TrackSpacing.sm),
            Expanded(
              child: _statCard(ext,
                  label: 'TOTAL', value: _clock(record.duration)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(TrackTheme ext,
      {required String label,
      required String value,
      String? unit,
      Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: ext.s1,
        borderRadius: BorderRadius.circular(ext.radiusSm),
        border: Border.all(color: ext.line),
      ),
      child: StatTile(
        label: label,
        value: value,
        unit: unit,
        size: StatTileSize.secondary,
        valueColor: valueColor,
      ),
    );
  }

  Widget _sectionLabel(TrackTheme ext, String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kFontNum,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 2,
        color: ext.txt3,
      ),
    );
  }

  Widget _uploadButton(TrackTheme ext) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _uploading ? null : _upload,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: ext.s3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
        ),
        child: _uploading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.onPrimary),
              )
            : Text(
                _uploaded ? 'RE-UPLOAD' : 'UPLOAD',
                style: const TextStyle(
                  fontFamily: kFontNum,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _exportButton(TrackTheme ext) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _exportGpx,
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.txt,
          side: BorderSide(color: ext.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
        ),
        child: const Text(
          'EXPORT GPX',
          style: TextStyle(
            fontFamily: kFontNum,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Floating back control over the map — uses [MapOverlayPanel] so it stays
/// legible on any map tile.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return MapOverlayPanel(
      opacity: 0.92,
      borderRadius: BorderRadius.circular(ext.radiusSm),
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ext.radiusSm),
            onTap: onTap,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: ext.txt),
          ),
        ),
      ),
    );
  }
}
