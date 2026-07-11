import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planned_route.dart';
import '../services/route_planner_service.dart';
import '../theme.dart';
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
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Scaffold(
      backgroundColor: ext.bg,
      appBar: AppBar(title: const Text('Planned Routes')),
      body: _buildBody(ext),
    );
  }

  Widget _buildBody(TrackTheme ext) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ext.record),
      );
    }

    if (_error != null) {
      return _CenteredMessage(text: _error!, color: ext.txt2);
    }

    if (_routes.isEmpty) {
      return _CenteredMessage(
        text: 'No planned routes yet.\nDraw one in the web app.',
        color: ext.txt3,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.lg, TrackSpacing.sm),
          child: Text(
            'SAVED · ${_routes.length}',
            style: TextStyle(
              fontFamily: kFontNum,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 2,
              color: ext.txt3,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                TrackSpacing.md, 0, TrackSpacing.md, TrackSpacing.lg),
            itemCount: _routes.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: TrackSpacing.sm),
            itemBuilder: (context, index) {
              final route = _routes[index];
              return _RouteCard(
                route: route,
                onPreview: () => _openPreview(route),
                onSelect: () => Navigator.pop(context, route),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;
  final Color color;

  const _CenteredMessage({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TrackSpacing.xl),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: kFontUi,
            fontSize: 14,
            height: 1.4,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
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
    final ext = Theme.of(context).extension<TrackTheme>()!;
    // Planned routes carry no activity type, so tint the glyph with the
    // primary accent (the same colour used for the route polyline).
    final tint = ext.record;

    return Material(
      color: ext.s1,
      borderRadius: BorderRadius.circular(ext.radius),
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(ext.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                child: Icon(Icons.route, size: 20, color: tint),
              ),
              const SizedBox(width: TrackSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: ext.txt,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${route.distanceKm.toStringAsFixed(1)} km · ${route.waypointCount} pts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontNum,
                        fontSize: 11,
                        color: ext.txt3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy').format(route.createdAt.toLocal()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontNum,
                        fontSize: 10,
                        color: ext.txt3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TrackSpacing.md),
              _UsePill(onTap: onSelect),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact accent "USE" pill that selects this route without opening preview.
class _UsePill extends StatelessWidget {
  final VoidCallback onTap;

  const _UsePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: ext.record,
      borderRadius: BorderRadius.circular(ext.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusChip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            'USE',
            style: TextStyle(
              fontFamily: kFontNum,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.5,
              color: onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
