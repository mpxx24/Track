import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class GpxService {
  String generateGpx(
      List<Position> points, DateTime startTime, String activityType) {
    final formatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="Track." xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$activityType ${formatter.format(startTime)}</name>');
    buffer.writeln('    <time>${formatter.format(startTime)}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>$activityType</name>');
    buffer.writeln('    <trkseg>');

    for (final point in points) {
      buffer.writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      if (point.altitude != 0.0) {
        buffer.writeln('        <ele>${point.altitude.toStringAsFixed(1)}</ele>');
      }
      buffer.writeln(
          '        <time>${formatter.format(DateTime.fromMillisecondsSinceEpoch(point.timestamp.millisecondsSinceEpoch, isUtc: true))}</time>');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  Future<File> saveGpx(String gpxContent, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    return file.writeAsString(gpxContent);
  }
}
