import 'dart:io';
import 'package:http/http.dart' as http;

class UploadService {
  Future<UploadResult> uploadTrack(
      File gpxFile, String activityType, String baseUrl, String apiKey) async {
    try {
      final cleanBase = baseUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$cleanBase/Tracks/Upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['X-Api-Key'] = apiKey;
      request.fields['activityType'] = activityType;
      request.files.add(
        await http.MultipartFile.fromPath('gpxFile', gpxFile.path),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) return UploadResult.success();
      return UploadResult.failure('HTTP ${response.statusCode}: $body');
    } catch (e) {
      return UploadResult.failure(e.toString());
    }
  }
}

class UploadResult {
  final bool success;
  final String? error;
  UploadResult._(this.success, this.error);
  factory UploadResult.success() => UploadResult._(true, null);
  factory UploadResult.failure(String error) => UploadResult._(false, error);
}
