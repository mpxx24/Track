import 'dart:io';
import 'package:http/http.dart' as http;

class UploadService {
  Future<bool> uploadTrack(
      File gpxFile, String activityType, String baseUrl, String apiKey) async {
    try {
      final uri = Uri.parse('$baseUrl/Tracks/Upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['X-Api-Key'] = apiKey;
      request.fields['activityType'] = activityType;
      request.files.add(
        await http.MultipartFile.fromPath('gpxFile', gpxFile.path),
      );

      final response = await request.send();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
