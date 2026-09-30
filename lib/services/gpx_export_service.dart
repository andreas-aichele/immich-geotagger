import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class GpxExportService {
  GpxExportService({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;

  Future<bool> export({Rect? sharePositionOrigin}) async {
    final points = await _database.allLocations();
    if (points.isEmpty) return false;

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Immich GeoTagger" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <time>${DateTime.now().toUtc().toIso8601String()}</time>')
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>Immich GeoTagger</name>')
      ..writeln('    <trkseg>');

    for (final point in points) {
      buffer
        ..writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">',
        )
        ..writeln(
          '        <time>${point.timestamp.toUtc().toIso8601String()}</time>',
        )
        ..writeln('      </trkpt>');
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(p.join(directory.path, 'immich-geotagger-$stamp.gpx'));
    await file.writeAsString(buffer.toString(), flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/gpx+xml')],
      subject: 'Immich GeoTagger GPX',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }
}
