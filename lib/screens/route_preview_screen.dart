import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/planned_route.dart';
import '../services/route_planner_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.route.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.route.distanceKm.toStringAsFixed(2)} km  •  ${widget.route.waypointCount} waypoints',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                )
              : Column(
                  children: [
                    Expanded(child: _buildMap()),
                    _buildUseButton(),
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
                color: Colors.cyan,
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

  Widget _buildUseButton() {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, widget.route),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Use this Route',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
