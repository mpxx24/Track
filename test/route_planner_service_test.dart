import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track/services/route_planner_service.dart';

void main() {
  const baseUrl = 'http://localhost:5010';
  const apiKey = 'test-key';

  group('RoutePlannerService.fetchRoutes', () {
    test('parsesListCorrectly', () async {
      final mockRoutes = [
        {
          'id': 'r1',
          'name': 'Morning Ride',
          'distanceKm': 12.5,
          'createdAt': '2026-03-01T08:00:00Z',
          'waypointCount': 5,
        },
        {
          'id': 'r2',
          'name': 'Evening Walk',
          'distanceKm': 3.2,
          'createdAt': '2026-03-02T18:00:00Z',
          'waypointCount': 3,
        },
      ];

      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/RoutePlanner/ApiList');
        expect(request.headers['X-Api-Key'], apiKey);
        return http.Response(jsonEncode(mockRoutes), 200);
      });

      final service = RoutePlannerService(client: client);
      final routes = await service.fetchRoutes(baseUrl, apiKey);

      expect(routes.length, 2);
      expect(routes[0].id, 'r1');
      expect(routes[0].name, 'Morning Ride');
      expect(routes[0].distanceKm, 12.5);
      expect(routes[0].waypointCount, 5);
      expect(routes[1].id, 'r2');
    });

    test('trailingSlashInBaseUrl_stillBuildsCorrectUri', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/RoutePlanner/ApiList');
        return http.Response('[]', 200);
      });

      final service = RoutePlannerService(client: client);
      final routes = await service.fetchRoutes('$baseUrl/', apiKey);
      expect(routes, isEmpty);
    });

    test('on401_throwsRoutePlannerException', () async {
      final client = MockClient((_) async => http.Response('Unauthorized', 401));
      final service = RoutePlannerService(client: client);

      expect(
        () => service.fetchRoutes(baseUrl, 'wrong-key'),
        throwsA(isA<RoutePlannerException>()),
      );
    });

    test('onNon200_throwsRoutePlannerException', () async {
      final client = MockClient((_) async => http.Response('Server Error', 500));
      final service = RoutePlannerService(client: client);

      expect(
        () => service.fetchRoutes(baseUrl, apiKey),
        throwsA(isA<RoutePlannerException>()),
      );
    });
  });

  group('RoutePlannerService.fetchPoints', () {
    test('returnsLatLngList', () async {
      final mockPoints = [
        {'lat': 51.5, 'lon': -0.1},
        {'lat': 51.6, 'lon': -0.2},
        {'lat': 51.7, 'lon': -0.3},
      ];

      final client = MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/RoutePlanner/ApiPoints/r1');
        expect(request.headers['X-Api-Key'], apiKey);
        return http.Response(jsonEncode(mockPoints), 200);
      });

      final service = RoutePlannerService(client: client);
      final points = await service.fetchPoints('r1', baseUrl, apiKey);

      expect(points.length, 3);
      expect(points[0].latitude, 51.5);
      expect(points[0].longitude, -0.1);
      expect(points[2].latitude, 51.7);
    });

    test('on404_throwsRoutePlannerException', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      final service = RoutePlannerService(client: client);

      expect(
        () => service.fetchPoints('missing', baseUrl, apiKey),
        throwsA(isA<RoutePlannerException>()),
      );
    });

    test('on401_throwsRoutePlannerException', () async {
      final client = MockClient((_) async => http.Response('Unauthorized', 401));
      final service = RoutePlannerService(client: client);

      expect(
        () => service.fetchPoints('r1', baseUrl, 'bad-key'),
        throwsA(isA<RoutePlannerException>()),
      );
    });
  });
}
