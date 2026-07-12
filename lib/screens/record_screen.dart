import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';
import '../models/planned_route.dart';
import '../services/auto_pause_config.dart';
import '../services/gpx_service.dart';
import '../services/history_service.dart';
import '../services/kalman_filter.dart';
import '../services/location_service.dart';
import '../services/live_activity_service.dart';
import '../services/route_planner_service.dart';
import '../services/speed_calculator.dart';
import '../services/watch_session_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme.dart';
import '../widgets/activity_type_picker.dart';
import '../widgets/map_overlay_panel.dart';
import '../widgets/record_controls.dart';
import '../widgets/stat_tile.dart';

class RecordScreen extends StatefulWidget {
  final PlannedRoute? plannedRoute;

  /// When set (start-from-watch), recording begins immediately with this
  /// type instead of showing the type picker.
  final String? initialActivityType;

  const RecordScreen({super.key, this.plannedRoute, this.initialActivityType});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();
  final HistoryService _historyService = HistoryService();
  final LiveActivityService _liveActivityService = LiveActivityService();
  final MapController _mapController = MapController();
  final KalmanFilter _kalmanFilter = KalmanFilter();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<WatchCommand>? _watchCommandSubscription;
  Timer? _elapsedTimer;

  // Guards against a second save dialog when stop arrives from both the
  // watch and the phone button.
  bool _stopping = false;

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

  bool _keepScreenOn = false;

  // Planned route ghost overlay
  List<LatLng> _ghostRoutePoints = [];

  // Drives the pulsing REC status dot (presentation only).
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    _watchCommandSubscription =
        watchSessionService.commands.listen(_onWatchCommand);
    _startRecording();
    if (widget.plannedRoute != null) {
      _loadGhostRoute(widget.plannedRoute!);
    }
  }

  Future<void> _loadGhostRoute(PlannedRoute route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('api_base_url') ?? '';
      final apiKey = prefs.getString('api_key') ?? '';
      if (baseUrl.isEmpty || apiKey.isEmpty) return;

      final points = await RoutePlannerService().fetchPoints(route.id, baseUrl, apiKey);
      if (mounted) setState(() => _ghostRoutePoints = points);
    } catch (_) {
      // Ghost route is decorative — silently ignore failures
    }
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

    // Ask activity type before recording begins (skipped when the watch
    // already chose one)
    if (!mounted) return;
    final activityType = widget.initialActivityType ??
        await _showActivityTypePicker(buttonLabel: 'Start');
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
      _updateWatch();
    });

    _positionSubscription =
        _locationService.positionStream().listen(_onPosition);

    await _liveActivityService.start(activityType: activityType);
    _updateWatch();
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

  void _updateWatch() {
    watchSessionService.update(
      activityType: _activityType ?? '',
      distanceKm: _distanceKm,
      elapsed: _formatDuration(_elapsed),
      movingTime: _formatDuration(_movingDuration),
      currentSpeedKmh: _currentSpeedKmh,
      isPaused: _isPaused,
    );
  }

  void _onWatchCommand(WatchCommand command) {
    if (_startTime == null) return;
    switch (command.kind) {
      case WatchCommandKind.pause:
        if (!_manuallyPaused) setState(() => _manuallyPaused = true);
      case WatchCommandKind.resume:
        if (_manuallyPaused) setState(() => _manuallyPaused = false);
      case WatchCommandKind.stop:
        _stopRecording();
      case WatchCommandKind.start:
        break; // handled in main.dart
    }
  }

  Future<bool?> _showAlwaysPermissionDialog() {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ext.s2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
        ),
        title: Text('Background location needed',
            style: TextStyle(color: ext.txt)),
        content: Text(
          'Set location access to "Always" so Track. keeps recording when your screen is locked.',
          style: TextStyle(color: ext.txt2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Skip', style: TextStyle(color: ext.txt3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Open Settings', style: TextStyle(color: ext.record)),
          ),
        ],
      ),
    );
  }

  void _toggleManualPause() {
    setState(() => _manuallyPaused = !_manuallyPaused);
  }

  void _toggleKeepScreenOn() {
    setState(() => _keepScreenOn = !_keepScreenOn);
    if (_keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<void> _stopRecording() async {
    if (_stopping) return;
    _stopping = true;
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    await _liveActivityService.stop();
    await watchSessionService.setIdle();

    if (!mounted) return;

    final choice = await _showSaveConfirmation();
    if (choice == 'discard') {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (choice != 'save') {
      // Resume recording
      _stopping = false;
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
        _updateWatch();
      });
      _positionSubscription =
          _locationService.positionStream().listen(_onPosition);
      await _liveActivityService.start(activityType: _activityType!);
      _updateLiveActivity();
      _updateWatch();
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
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ext.s2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
        ),
        title: Text(
          'Save $_activityType?',
          style: TextStyle(color: ext.txt),
        ),
        content: Text(
          '${_distanceKm.toStringAsFixed(2)} km  •  ${_formatDuration(_movingDuration)}',
          style: TextStyle(color: ext.txt2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: Text('Resume', style: TextStyle(color: ext.txt2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Discard', style: TextStyle(color: ext.stop)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text('Save', style: TextStyle(color: ext.record)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showActivityTypePicker({required String buttonLabel}) async {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ext.bg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ext.radius)),
      ),
      builder: (ctx) {
        String selected = 'Ride';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ext.line,
                          borderRadius: BorderRadius.circular(ext.radiusChip),
                        ),
                      ),
                    ),
                    const SizedBox(height: TrackSpacing.lg),
                    Text('Start activity',
                        style: Theme.of(ctx).textTheme.headlineMedium),
                    const SizedBox(height: TrackSpacing.xs),
                    Text(
                      'SELECT A TYPE',
                      style: TextStyle(
                        fontFamily: kFontNum,
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        letterSpacing: 2,
                        color: ext.txt3,
                      ),
                    ),
                    const SizedBox(height: TrackSpacing.lg),
                    ActivityTypePicker(
                      selectedType: selected,
                      onSelected: (t) => setModalState(() => selected = t),
                    ),
                    const SizedBox(height: TrackSpacing.lg),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, selected),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ext.record,
                          foregroundColor:
                              Theme.of(ctx).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ext.radius),
                          ),
                        ),
                        child: Text(
                          '${buttonLabel.toUpperCase()} ${selected.toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: kFontUi,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _watchCommandSubscription?.cancel();
    watchSessionService.setIdle();
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
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
              if (_ghostRoutePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _ghostRoutePoints,
                      color: ext.txt3.withValues(alpha: 0.85),
                      strokeWidth: 3.5,
                    ),
                  ],
                ),
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: ext.record,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_ghostRoutePoints.isNotEmpty)
                    Marker(
                      point: _ghostRoutePoints.first,
                      width: 12,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ext.txt3,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (_ghostRoutePoints.length > 1)
                    Marker(
                      point: _ghostRoutePoints.last,
                      width: 12,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ext.txt3,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Marker(
                    point: _currentLocation,
                    width: 18,
                    height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ext.record,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Scrim so the status chips stay legible over bright map imagery.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          // Top overlay chips: activity type (left) + REC/PAUSE status (right).
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TrackSpacing.md,
                vertical: TrackSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_activityType != null)
                    _buildTypeChip(ext, _activityType!)
                  else
                    const SizedBox.shrink(),
                  _buildStatusChip(ext),
                ],
              ),
            ),
          ),
          // Bottom stat + control overlay panel.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MapOverlayPanel(
              padding: EdgeInsets.fromLTRB(
                  TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero distance readout.
                  StatTile(
                    label: 'DISTANCE · KM',
                    value: _distanceKm.toStringAsFixed(2),
                  ),
                  const SizedBox(height: TrackSpacing.md),
                  Divider(height: 1, thickness: 1, color: ext.line),
                  const SizedBox(height: TrackSpacing.md),
                  // Secondary stat row: moving time · live speed · avg speed.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'MOVING',
                          value: _formatDuration(_movingDuration),
                          size: StatTileSize.secondary,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: 'NOW km/h',
                          value: _currentSpeedKmh.toStringAsFixed(1),
                          size: StatTileSize.secondary,
                          valueColor: ext.record,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: 'AVG km/h',
                          value: _formatAvgSpeed(),
                          size: StatTileSize.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TrackSpacing.lg),
                  RecordControls(
                    isPaused: _isPaused,
                    onPauseResume: () {
                      if (_startTime != null) _toggleManualPause();
                    },
                    onStop: _stopRecording,
                    onSecondary: _toggleKeepScreenOn,
                    secondaryIcon: _keepScreenOn
                        ? Icons.brightness_high
                        : Icons.brightness_2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small pill floating over the map (uses [MapOverlayPanel] for legibility).
  Widget _mapChip({
    required TrackTheme ext,
    required Widget dot,
    required String label,
    required Color labelColor,
  }) {
    return MapOverlayPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: BorderRadius.circular(ext.radiusChip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: kFontNum,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.5,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(TrackTheme ext, String type) {
    return _mapChip(
      ext: ext,
      dot: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ext.typeTint(type),
        ),
      ),
      label: type.toUpperCase(),
      labelColor: ext.txt,
    );
  }

  Widget _buildStatusChip(TrackTheme ext) {
    if (_isPaused) {
      return _mapChip(
        ext: ext,
        dot: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: ext.pause),
        ),
        label: _autoPaused ? 'AUTO-PAUSE' : 'PAUSED',
        labelColor: ext.pause,
      );
    }
    return _mapChip(
      ext: ext,
      dot: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.82).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.35).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ext.stop),
          ),
        ),
      ),
      label: 'REC',
      labelColor: ext.txt,
    );
  }
}
