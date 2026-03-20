import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/activity_record.dart';
import '../services/gpx_service.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();
  final HistoryService _historyService = HistoryService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;

  final List<Position> _positions = [];
  final List<LatLng> _routePoints = [];
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0.0;
  LatLng _currentLocation = const LatLng(51.5, -0.09);
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final granted = await _locationService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      Navigator.pop(context);
      return;
    }

    // Center map on current position immediately before stream starts
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(current.latitude, current.longitude);
      setState(() => _currentLocation = latLng);
      if (_mapReady) {
        _mapController.move(latLng, 15);
      }
    } catch (_) {}

    _startTime = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });

    _positionSubscription =
        _locationService.positionStream().listen(_onPosition);
  }

  void _onPosition(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);

    if (_positions.isNotEmpty) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      _distanceKm += meters / 1000.0;
    }

    _positions.add(position);
    _routePoints.add(latLng);
    _currentLocation = latLng;

    if (mounted) {
      setState(() {});
      if (_mapReady) {
        _mapController.move(latLng, _mapController.camera.zoom);
      }
    }
  }

  Future<void> _stopRecording() async {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();

    if (!mounted) return;

    final activityType = await _showActivityTypePicker();
    if (activityType == null) {
      // User dismissed without selecting — restart timer
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      });
      _positionSubscription =
          _locationService.positionStream().listen(_onPosition);
      return;
    }

    final start = _startTime ?? DateTime.now();
    final gpxContent =
        _gpxService.generateGpx(_positions, start, activityType);
    final filename =
        '${activityType.toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(start)}.gpx';
    final File gpxFile = await _gpxService.saveGpx(gpxContent, filename);

    final record = ActivityRecord(
      id: '${start.millisecondsSinceEpoch}',
      startedAt: start,
      distanceKm: _distanceKm,
      duration: _elapsed,
      activityType: activityType,
      gpxFilePath: gpxFile.path,
      uploaded: false,
    );

    await _historyService.saveRecord(record);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity saved')),
    );
    Navigator.pop(context);
  }

  Future<String?> _showActivityTypePicker() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String selected = 'Ride';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Activity Type',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Ride', 'Walk', 'Football'].map((type) {
                      final isSelected = selected == type;
                      return GestureDetector(
                        onTap: () => setModalState(() => selected = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save Activity',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatPace() {
    if (_distanceKm < 0.01 || _elapsed.inSeconds < 1) return '--:--';
    final secsPerKm = _elapsed.inSeconds / _distanceKm;
    final mins = (secsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (secsPerKm % 60).round().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15,
              onMapReady: () => setState(() => _mapReady = true),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mariusz.track',
              ),
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.redAccent,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              if (_routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _routePoints.last,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'TIME',
                        value: _formatDuration(_elapsed),
                      ),
                      _StatItem(
                        label: 'DISTANCE',
                        value: '${_distanceKm.toStringAsFixed(2)} km',
                      ),
                      _StatItem(
                        label: 'PACE',
                        value: '${_formatPace()} /km',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _stopRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'STOP',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
