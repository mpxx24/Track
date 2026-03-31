import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planned_route.dart';
import '../services/route_planner_service.dart';
import 'route_preview_screen.dart';

class PlannedRoutesScreen extends StatefulWidget {
  const PlannedRoutesScreen({super.key});

  @override
  State<PlannedRoutesScreen> createState() => _PlannedRoutesScreenState();
}

class _PlannedRoutesScreenState extends State<PlannedRoutesScreen> {
  final RoutePlannerService _service = RoutePlannerService();

  List<PlannedRoute> _routes = [];
  bool _loading = true;
  String? _error;
  String _baseUrl = '';
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('api_base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      setState(() {
        _error = 'Configure API URL and key in Settings first.';
        _loading = false;
      });
      return;
    }

    _baseUrl = baseUrl;
    _apiKey = apiKey;

    try {
      final routes = await _service.fetchRoutes(baseUrl, apiKey);
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openPreview(PlannedRoute route) async {
    final result = await Navigator.push<PlannedRoute>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutePreviewScreen(
          route: route,
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Planned Routes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Text(
          'No planned routes yet.\nDraw one in the web app.',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        return _RouteCard(
          route: route,
          onPreview: () => _openPreview(route),
          onSelect: () => Navigator.pop(context, route),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  final PlannedRoute route;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const _RouteCard({
    required this.route,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPreview,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: Colors.white70, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${route.distanceKm.toStringAsFixed(2)} km  •  ${route.waypointCount} waypoints',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy').format(route.createdAt.toLocal()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Use', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
