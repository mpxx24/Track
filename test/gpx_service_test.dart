import 'package:flutter_test/flutter_test.dart';
import 'package:track/services/gpx_service.dart';

void main() {
  group('GpxService.exportFilename', () {
    test('builds <type>_<date>.gpx with lowercase type', () {
      expect(
        GpxService.exportFilename('Ride', DateTime(2026, 7, 12)),
        'ride_2026-07-12.gpx',
      );
    });

    test('zero-pads month and day', () {
      expect(
        GpxService.exportFilename('Football', DateTime(2026, 1, 5)),
        'football_2026-01-05.gpx',
      );
    });

    test('collapses whitespace in the type to underscores', () {
      expect(
        GpxService.exportFilename('Trail Run', DateTime(2026, 3, 9)),
        'trail_run_2026-03-09.gpx',
      );
    });

    test('falls back to a generic name for an empty type', () {
      expect(
        GpxService.exportFilename('   ', DateTime(2026, 12, 31)),
        'activity_2026-12-31.gpx',
      );
    });
  });
}
