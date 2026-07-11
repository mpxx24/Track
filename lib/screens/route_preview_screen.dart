import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/planned_route.dart';
import '../services/route_planner_service.dart';
import '../theme.dart';
import '../widgets/map_overlay_panel.dart';
import '../widgets/stat_tile.dart';

class RoutePreviewScreen extends StatefulWidget {
  final PlannedRoute route;
  final String baseUrl;
  final String apiKey;

  const RoutePreviewScreen({
    super.key,
    required this.route,
    required this.baseUrl,
    required this.apiKey,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
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
      final points = await RoutePlannerService().fetchPoints(
        widget.route.id,
        widget.baseUrl,
        widget.apiKey,
      );
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Scaffold(
      backgroundColor: ext.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.route.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${widget.route.distanceKm.toStringAsFixed(1)} km · ${widget.route.waypointCount} waypoints',
              style: TextStyle(
                fontFamily: kFontNum,
                fontSize: 11,
                color: ext.txt3,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(ext),
    );
  }

  Widget _buildBody(TrackTheme ext) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ext.record));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TrackSpacing.xl),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontUi,
              fontSize: 14,
              color: ext.failed,
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: _buildMap(ext)),
        Align(
          alignment: Alignment.bottomCenter,
          child: _buildBottomPanel(ext),
        ),
      ],
    );
  }

  Widget _buildMap(TrackTheme ext) {
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
                color: ext.record,
                strokeWidth: 4.0,
              ),
            ],
          ),
        if (_points.isNotEmpty)
          MarkerLayer(
            markers: [
              _endpointMarker(_points.first, ext.uploaded, ext),
              if (_points.length > 1)
                _endpointMarker(_points.last, ext.stop, ext),
            ],
          ),
      ],
    );
  }

  Marker _endpointMarker(LatLng point, Color fill, TrackTheme ext) {
    return Marker(
      point: point,
      width: 16,
      height: 16,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ext.s1, width: 2),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(TrackTheme ext) {
    return MapOverlayPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'DISTANCE',
                  value: widget.route.distanceKm.toStringAsFixed(1),
                  unit: 'KM',
                  size: StatTileSize.secondary,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'WAYPOINTS',
                  value: '${widget.route.waypointCount}',
                  size: StatTileSize.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: TrackSpacing.lg),
          _UseButton(
            onTap: () => Navigator.pop(context, widget.route),
          ),
        ],
      ),
    );
  }
}

/// Full-width accent primary action: select this route for recording.
class _UseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: ext.record,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radius),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text(
            'USE THIS ROUTE',
            style: TextStyle(
              fontFamily: kFontUi,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 1.5,
              color: onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
