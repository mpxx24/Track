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
import '../services/notification_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();
  final HistoryService _historyService = HistoryService();
  final NotificationService _notificationService = NotificationService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;

  final List<Position> _positions = [];
  final List<LatLng> _routePoints = [];
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Duration _movingDuration = Duration.zero;
  double _distanceKm = 0.0;
  bool _isMoving = false;
  int _timerTick = 0;
  LatLng _currentLocation = const LatLng(51.5, -0.09);
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    await _notificationService.initialize();
    await _notificationService.requestPermission();

    final status = await _locationService.requestPermission();

    if (status == LocationPermissionStatus.deniedForever ||
        status == LocationPermissionStatus.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      Navigator.pop(context);
      return;
    }

    if (status == LocationPermissionStatus.whileInUse) {
      if (!mounted) return;
      final openSettings = await _showAlwaysPermissionDialog();
      if (openSettings == true) {
        await _locationService.openSettings();
        // Re-check after returning from settings
        final newStatus = await _locationService.requestPermission();
        if (newStatus != LocationPermissionStatus.always) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Background location not granted — GPS will pause when screen locks'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }

    // Center map on current position before stream starts
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(current.latitude, current.longitude);
      setState(() => _currentLocation = latLng);
      if (_mapReady) _mapController.move(latLng, 15);
    } catch (_) {}

    _startTime = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
        if (_isMoving) {
          _movingDuration += const Duration(seconds: 1);
        }
      });
      _timerTick++;
      if (_timerTick % 10 == 0) {
        _notificationService.showRecordingNotification(
          distance: _distanceKm.toStringAsFixed(2),
          movingTime: _formatDuration(_movingDuration),
          avgSpeed: _formatAvgSpeed(),
        );
      }
    });

    _positionSubscription =
        _locationService.positionStream().listen(_onPosition);

    // Initial notification
    await _notificationService.showRecordingNotification(
      distance: '0.00',
      movingTime: '00:00:00',
      avgSpeed: '--.-',
    );
  }

  void _onPosition(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    final goodAccuracy = position.accuracy <= 20.0;
    // speed < 0 means unavailable on iOS; > 0.3 m/s ≈ 1 km/h
    final moving = position.speed >= 0 && position.speed > 0.3;

    if (_positions.isNotEmpty && goodAccuracy && moving) {
      final last = _positions.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      _distanceKm += meters / 1000.0;
    }

    _isMoving = moving;
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

  Future<bool?> _showAlwaysPermissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Background location needed',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Set location access to "Always" so Track. keeps recording when your screen is locked.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Skip', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRecording() async {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    await _notificationService.cancelRecordingNotification();

    if (!mounted) return;

    final activityType = await _showActivityTypePicker();
    if (activityType == null) {
      // User dismissed — restart
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
          if (_isMoving) _movingDuration += const Duration(seconds: 1);
        });
      });
      _positionSubscription =
          _locationService.positionStream().listen(_onPosition);
      await _notificationService.showRecordingNotification(
        distance: _distanceKm.toStringAsFixed(2),
        movingTime: _formatDuration(_movingDuration),
        avgSpeed: _formatAvgSpeed(),
      );
      return;
    }

    final start = _startTime ?? DateTime.now();
    final gpxContent =
        _gpxService.generateGpx(_positions, start, activityType);
    final filename =
        '${activityType.toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(start)}.gpx';
    final File gpxFile = await _gpxService.saveGpx(gpxContent, filename);

    final movingSeconds = _movingDuration.inSeconds;
    final avgSpeedKmh = movingSeconds > 0
        ? _distanceKm / (movingSeconds / 3600.0)
        : 0.0;

    final record = ActivityRecord(
      id: '${start.millisecondsSinceEpoch}',
      startedAt: start,
      distanceKm: _distanceKm,
      duration: _elapsed,
      movingDuration: _movingDuration,
      avgSpeedKmh: avgSpeedKmh,
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

  String _formatAvgSpeed() {
    if (_movingDuration.inSeconds < 1 || _distanceKm < 0.01) return '--.-';
    final kmh = _distanceKm / (_movingDuration.inSeconds / 3600.0);
    return kmh.toStringAsFixed(1);
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
                        label: 'MOVING TIME',
                        value: _formatDuration(_movingDuration),
                      ),
                      _StatItem(
                        label: 'DISTANCE',
                        value: '${_distanceKm.toStringAsFixed(2)} km',
                      ),
                      _StatItem(
                        label: 'AVG SPEED',
                        value: '${_formatAvgSpeed()} km/h',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'total ${_formatDuration(_elapsed)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
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
