import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_record.dart';
import '../services/gpx_parser_service.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityRecord record;

  const ActivityDetailScreen({super.key, required this.record});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  List<LatLng> _points = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final points =
          await GpxParserService.parseGpxFile(widget.record.gpxFilePath);
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load route: $e';
        _loading = false;
      });
    }
  }

  MapOptions _buildMapOptions() {
    if (_points.isEmpty) {
      return const MapOptions(initialCenter: LatLng(51.5, -0.09), initialZoom: 13);
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

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.activityType,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('MMM d, yyyy  HH:mm').format(record.startedAt),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)))
              : Column(
                  children: [
                    Expanded(child: _buildMap()),
                    _buildStatsPanel(),
                  ],
                ),
    );
  }

  Widget _buildMap() {
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
              Polyline(
                points: _points,
                color: Colors.redAccent,
                strokeWidth: 4.0,
              ),
            ],
          ),
        if (_points.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: _points.first,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              if (_points.length > 1)
                Marker(
                  point: _points.last,
                  width: 16,
                  height: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatsPanel() {
    final record = widget.record;
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            label: 'Distance',
            value: '${record.distanceKm.toStringAsFixed(2)} km',
          ),
          _Stat(
            label: 'Moving time',
            value: _formatDuration(record.movingDuration),
          ),
          _Stat(
            label: 'Avg speed',
            value: '${record.avgSpeedKmh.toStringAsFixed(1)} km/h',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }
}
