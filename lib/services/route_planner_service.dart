import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/planned_route.dart';

class RoutePlannerException implements Exception {
  final String message;
  const RoutePlannerException(this.message);
  @override
  String toString() => 'RoutePlannerException: $message';
}

class RoutePlannerService {
  final http.Client _client;

  RoutePlannerService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlannedRoute>> fetchRoutes(String baseUrl, String apiKey) async {
    final cleanBase = baseUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanBase/RoutePlanner/ApiList');
    final response = await _client.get(uri, headers: {'X-Api-Key': apiKey});

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RoutePlannerException('Invalid API key');
    }
    if (response.statusCode != 200) {
      throw RoutePlannerException('HTTP ${response.statusCode}');
    }

    final List<dynamic> json = jsonDecode(response.body);
    return json.map((e) => PlannedRoute.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LatLng>> fetchPoints(String routeId, String baseUrl, String apiKey) async {
    final cleanBase = baseUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanBase/RoutePlanner/ApiPoints/$routeId');
    final response = await _client.get(uri, headers: {'X-Api-Key': apiKey});

    if (response.statusCode == 404) {
      throw RoutePlannerException('Route $routeId not found');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RoutePlannerException('Invalid API key');
    }
    if (response.statusCode != 200) {
      throw RoutePlannerException('HTTP ${response.statusCode}');
    }

    final List<dynamic> json = jsonDecode(response.body);
    return json
        .map((e) => LatLng(
              (e['lat'] as num).toDouble(),
              (e['lon'] as num).toDouble(),
            ))
        .toList();
  }
}
