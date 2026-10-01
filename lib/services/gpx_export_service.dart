import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

enum GpxExportResult {
  completed,
  cancelled,
  empty,
}

class GpxExportService {
  GpxExportService({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;

  Future<GpxExportResult> save() async {
    final export = await _createExport();
    if (export == null) return GpxExportResult.empty;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save GPX',
      fileName: export.fileName,
      type: FileType.custom,
      allowedExtensions: const ['gpx'],
      bytes: export.bytes,
    );

    return path == null
        ? GpxExportResult.cancelled
        : GpxExportResult.completed;
  }

  Future<GpxExportResult> share({Rect? sharePositionOrigin}) async {
    final export = await _createExport();
    if (export == null) return GpxExportResult.empty;

    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, export.fileName));
    await file.writeAsBytes(export.bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/gpx+xml')],
      subject: 'Immich GeoTagger GPX',
      sharePositionOrigin: sharePositionOrigin,
    );
    return GpxExportResult.completed;
  }

  Future<_GpxExport?> _createExport() async {
    final points = await _database.allLocations();
    if (points.isEmpty) return null;

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

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return _GpxExport(
      fileName: 'immich-geotagger-$stamp.gpx',
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
    );
  }
}

class _GpxExport {
  const _GpxExport({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}
