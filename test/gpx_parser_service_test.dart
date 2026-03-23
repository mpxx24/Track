import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/gpx_parser_service.dart';

void main() {
  group('GpxParserService.parseGpxContent', () {
    test('returns correct points from valid GPX', () {
      const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Track." xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <trkseg>
      <trkpt lat="51.5" lon="-0.09">
        <ele>10.0</ele>
        <time>2024-01-01T10:00:00Z</time>
      </trkpt>
      <trkpt lat="51.501" lon="-0.091">
        <ele>11.0</ele>
        <time>2024-01-01T10:00:05Z</time>
      </trkpt>
      <trkpt lat="51.502" lon="-0.092">
        <time>2024-01-01T10:00:10Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final points = GpxParserService.parseGpxContent(gpx);

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(51.5, 0.000001));
      expect(points[0].longitude, closeTo(-0.09, 0.000001));
      expect(points[1].latitude, closeTo(51.501, 0.000001));
      expect(points[1].longitude, closeTo(-0.091, 0.000001));
      expect(points[2].latitude, closeTo(51.502, 0.000001));
      expect(points[2].longitude, closeTo(-0.092, 0.000001));
    });

    test('returns empty list for GPX with no trkpt elements', () {
      const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
    </trkseg>
  </trk>
</gpx>''';

      final points = GpxParserService.parseGpxContent(gpx);

      expect(points, isEmpty);
    });

    test('returns empty list for empty string', () {
      final points = GpxParserService.parseGpxContent('');
      expect(points, isEmpty);
    });

    test('skips trkpt elements with malformed lat/lon', () {
      const gpx = '''<gpx>
  <trk><trkseg>
    <trkpt lat="not-a-number" lon="-0.09"></trkpt>
    <trkpt lat="51.5" lon="also-bad"></trkpt>
    <trkpt lat="51.5" lon="-0.09"></trkpt>
  </trkseg></trk>
</gpx>''';

      final points = GpxParserService.parseGpxContent(gpx);

      expect(points.length, 1);
      expect(points[0].latitude, closeTo(51.5, 0.000001));
    });

    test('handles single point', () {
      const gpx = '<gpx><trk><trkseg>'
          '<trkpt lat="48.8566" lon="2.3522"></trkpt>'
          '</trkseg></trk></gpx>';

      final points = GpxParserService.parseGpxContent(gpx);

      expect(points.length, 1);
      expect(points[0].latitude, closeTo(48.8566, 0.000001));
      expect(points[0].longitude, closeTo(2.3522, 0.000001));
    });
  });
}
