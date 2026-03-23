import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class GpxParserService {
  static final RegExp _trkptRegex =
      RegExp(r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"');

  /// Parses GPX XML content and returns the list of track points.
  static List<LatLng> parseGpxContent(String content) {
    final points = <LatLng>[];
    for (final match in _trkptRegex.allMatches(content)) {
      final lat = double.tryParse(match.group(1)!);
      final lon = double.tryParse(match.group(2)!);
      if (lat != null && lon != null) {
        points.add(LatLng(lat, lon));
      }
    }
    return points;
  }

  /// Reads a GPX file from [filePath] and returns the list of track points.
  ///
  /// If the file is not found at the stored path (e.g. after an app reinstall
  /// the documents directory UUID changes), falls back to resolving the
  /// filename against the current documents directory.
  static Future<List<LatLng>> parseGpxFile(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      final docsDir = await getApplicationDocumentsDirectory();
      final filename = filePath.split('/').last;
      final fallback = File('${docsDir.path}/$filename');
      if (!await fallback.exists()) return [];
      file = fallback;
    }
    final content = await file.readAsString();
    return parseGpxContent(content);
  }
}
