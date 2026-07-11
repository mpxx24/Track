import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/upload_service.dart';

void main() {
  late File gpxFile;

  setUp(() async {
    gpxFile = File(
        '${Directory.systemTemp.path}/upload_service_test_${DateTime.now().microsecondsSinceEpoch}.gpx');
    await gpxFile.writeAsString('<gpx></gpx>');
  });

  tearDown(() async {
    if (await gpxFile.exists()) await gpxFile.delete();
  });

  group('UploadService.buildRequest', () {
    test('sets activity type, api key and target URL', () async {
      final request = await UploadService().buildRequest(
          gpxFile, 'Run', 'https://example.com/', 'secret');

      expect(request.url.toString(), 'https://example.com/Tracks/Upload');
      expect(request.headers['X-Api-Key'], 'secret');
      expect(request.fields['activityType'], 'Run');
    });

    test('uploadToStrava defaults to false', () async {
      final request = await UploadService()
          .buildRequest(gpxFile, 'Ride', 'https://example.com', 'k');

      expect(request.fields['uploadToStrava'], 'false');
    });

    test('uploadToStrava true is sent as form field', () async {
      final request = await UploadService().buildRequest(
          gpxFile, 'Ride', 'https://example.com', 'k',
          uploadToStrava: true);

      expect(request.fields['uploadToStrava'], 'true');
    });
  });

  group('UploadService.parseStravaStatus', () {
    test('reads stravaUploadStatus from response JSON', () {
      const body =
          '{"id":"abc","stravaActivityId":456,"stravaUploadStatus":"uploaded"}';
      expect(UploadService.parseStravaStatus(body), 'uploaded');
    });

    test('returns null when field is absent', () {
      expect(UploadService.parseStravaStatus('{"id":"abc"}'), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(UploadService.parseStravaStatus('not json'), isNull);
    });
  });
}
