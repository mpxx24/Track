import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class UploadService {
  Future<UploadResult> uploadTrack(
      File gpxFile, String activityType, String baseUrl, String apiKey,
      {bool uploadToStrava = false}) async {
    try {
      final request = await buildRequest(gpxFile, activityType, baseUrl, apiKey,
          uploadToStrava: uploadToStrava);

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return UploadResult.success(stravaStatus: parseStravaStatus(body));
      }
      return UploadResult.failure('HTTP ${response.statusCode}: $body');
    } catch (e) {
      return UploadResult.failure(e.toString());
    }
  }

  Future<http.MultipartRequest> buildRequest(
      File gpxFile, String activityType, String baseUrl, String apiKey,
      {bool uploadToStrava = false}) async {
    final cleanBase = baseUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanBase/Tracks/Upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers['X-Api-Key'] = apiKey;
    request.fields['activityType'] = activityType;
    request.fields['uploadToStrava'] = uploadToStrava.toString();
    request.files.add(
      await http.MultipartFile.fromPath('gpxFile', gpxFile.path),
    );
    return request;
  }

  static String? parseStravaStatus(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json['stravaUploadStatus'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class UploadResult {
  final bool success;
  final String? error;

  /// Server-reported Strava result: "uploaded", "duplicate" or "failed: ...".
  /// Null when Strava upload was not requested or the response had no body.
  final String? stravaStatus;

  UploadResult._(this.success, this.error, this.stravaStatus);
  factory UploadResult.success({String? stravaStatus}) =>
      UploadResult._(true, null, stravaStatus);
  factory UploadResult.failure(String error) =>
      UploadResult._(false, error, null);
}
