import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/activity_record.dart';
import '../services/auto_pause_config.dart';
import '../services/gpx_service.dart';
import '../services/history_service.dart';
import '../services/kalman_filter.dart';
import '../services/location_service.dart';
import '../services/live_activity_service.dart';
import '../services/speed_calculator.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();
  final HistoryService _historyService = HistoryService();
  final LiveActivityService _liveActivityService = LiveActivityService();
  final MapController _mapController = MapController();
  final KalmanFilter _kalmanFilter = KalmanFilter();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;

  // Raw positions kept for GPX export; route points are Kalman-filtered
  final List<Position> _positions = [];
  final List<LatLng> _routePoints = [];

  String? _activityType;
  AutoPauseConfig _autoPauseConfig = const AutoPauseConfig(enabled: false);

  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Duration _movingDuration = Duration.zero;
  double _distanceKm = 0.0;
  double _currentSpeedKmh = 0.0;

  // Previous smooth position and timestamp for position-derived speed fallback
  LatLng? _prevSmoothLatLng;
  DateTime? _prevPositionTimestamp;

  // Auto-pause state
  bool _autoPaused = false;
  bool _manuallyPaused = false;
  bool get _isPaused => _autoPaused || _manuallyPaused;
  int _pauseDebounceCount = 0;
  int _resumeDebounceCount = 0;

  int _timerTick = 0;
  LatLng _currentLocation = const LatLng(51.5, -0.09);
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRecording();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    // Only act if recording is active (startTime set, subscription exists).
    if (_startTime == null || _positionSubscription == null) return;

    // Resubscribe to the position stream — iOS may have silently stopped
    // delivering events while the app was suspended.
    _positionSubscription?.cancel();
    _positionSubscription =
        _locationService.positionStream().listen(_onPosition);

    // Fetch current position immediately so the map jumps to where the
    // user actually is, rather than waiting for the next stream event.
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _onPosition(current);
    } catch (_) {}
  }

  Future<void> _startRecording() async {
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

    // Centre map on current position before showing the picker
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(current.latitude, current.longitude);
      setState(() => _currentLocation = latLng);
      if (_mapReady) _mapController.move(latLng, 15);
    } catch (_) {}

    // Ask activity type before recording begins
    if (!mounted) return;
    final activityType = await _showActivityTypePicker(buttonLabel: 'Start');
    if (activityType == null) {
      // User dismissed — go back to home
      if (mounted) Navigator.pop(context);
      return;
    }

    _activityType = activityType;
    _autoPauseConfig = AutoPauseConfig.forActivity(activityType);

    _startTime = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
        _tickAutoPause();
        if (!_isPaused) {
          _movingDuration += const Duration(seconds: 1);
        }
      });
      _timerTick++;
      if (_timerTick % 10 == 0) _updateLiveActivity();
    });

    _positionSubscription =
        _locationService.positionStream().listen(_onPosition);

    await _liveActivityService.start(activityType: activityType);
  }

  void _tickAutoPause() {
    if (!_autoPauseConfig.enabled) return;

    final abovePause = _currentSpeedKmh > _autoPauseConfig.pauseSpeedKmh;
    final aboveResume = _currentSpeedKmh > _autoPauseConfig.resumeSpeedKmh;

    if (!_autoPaused) {
      if (abovePause) {
        _pauseDebounceCount = 0;
      } else {
        _pauseDebounceCount++;
        if (_pauseDebounceCount >= _autoPauseConfig.pauseDebounceSeconds) {
          _autoPaused = true;
          _pauseDebounceCount = 0;
          _resumeDebounceCount = 0;
        }
      }
    } else {
      if (aboveResume) {
        _resumeDebounceCount++;
        if (_resumeDebounceCount >= _autoPauseConfig.resumeDebounceSeconds) {
          _autoPaused = false;
          _resumeDebounceCount = 0;
          _pauseDebounceCount = 0;
        }
      } else {
        _resumeDebounceCount = 0;
      }
    }
  }

  void _onPosition(Position position) {
    // Apply Kalman filter for smoothed display and distance
    final (smoothLat, smoothLng) = _kalmanFilter.update(
      position.latitude,
      position.longitude,
      position.accuracy,
    );
    final smoothLatLng = LatLng(smoothLat, smoothLng);

    _currentSpeedKmh = SpeedCalculator.computeKmh(
      positionSpeed: position.speed,
      currSmooth: smoothLatLng,
      prevSmooth: _prevSmoothLatLng,
      prevTimestamp: _prevPositionTimestamp,
      currTimestamp: position.timestamp,
    );
    _prevSmoothLatLng = smoothLatLng;
    _prevPositionTimestamp = position.timestamp;

    final maxAccuracy = _autoPauseConfig.maxRecordAccuracyMeters;
    final goodAccuracy =
        maxAccuracy == null || position.accuracy <= maxAccuracy;

    // Accumulate distance from filtered coords when active and moving
    if (_routePoints.isNotEmpty && goodAccuracy && !_isPaused) {
      final last = _routePoints.last;
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        smoothLat,
        smoothLng,
      );
      _distanceKm += meters / 1000.0;
    }

    // Only record when accuracy is good (≤20 m) — drops cold-start noise
    if (goodAccuracy) {
      _positions.add(position);
      _routePoints.add(smoothLatLng);
    }
    _currentLocation = smoothLatLng;

    if (mounted) {
      setState(() {});
      if (_mapReady) {
        _mapController.move(smoothLatLng, _mapController.camera.zoom);
      }
    }
  }

  void _updateLiveActivity() {
    _liveActivityService.update(
      distance: _distanceKm.toStringAsFixed(2),
      movingTime: _formatDuration(_movingDuration),
      avgSpeed: _formatAvgSpeed(),
      isPaused: _isPaused,
    );
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

  void _toggleManualPause() {
    setState(() => _manuallyPaused = !_manuallyPaused);
  }

  Future<void> _stopRecording() async {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    await _liveActivityService.stop();

    if (!mounted) return;

    final choice = await _showSaveConfirmation();
    if (choice == 'discard') {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (choice != 'save') {
      // Resume recording
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
          _tickAutoPause();
          if (!_isPaused) {
            _movingDuration += const Duration(seconds: 1);
          }
        });
        _timerTick++;
        if (_timerTick % 10 == 0) _updateLiveActivity();
      });
      _positionSubscription =
          _locationService.positionStream().listen(_onPosition);
      await _liveActivityService.start(activityType: _activityType!);
      _updateLiveActivity();
      return;
    }

    final start = _startTime ?? DateTime.now();
    final activityType = _activityType!;
    final gpxContent =
        _gpxService.generateGpx(_positions, start, activityType);
    final filename =
        '${activityType.toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(start)}.gpx';
    final File gpxFile = await _gpxService.saveGpx(gpxContent, filename);

    final movingSeconds = _movingDuration.inSeconds;
    final avgSpeedKmh =
        movingSeconds > 0 ? _distanceKm / (movingSeconds / 3600.0) : 0.0;

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

  Future<String?> _showSaveConfirmation() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(
          'Save $_activityType?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '${_distanceKm.toStringAsFixed(2)} km  •  ${_formatDuration(_movingDuration)}',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('Resume',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child:
                const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showActivityTypePicker({required String buttonLabel}) async {
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
                    child: Text(buttonLabel,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
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
    WidgetsBinding.instance.removeObserver(this);
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
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
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
                  if (_isPaused)
                    const Text(
                      '⏸ PAUSED',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    )
                  else
                    Text(
                      'total ${_formatDuration(_elapsed)}',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _startTime != null ? _toggleManualPause : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _manuallyPaused ? 'RESUME' : 'PAUSE',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
