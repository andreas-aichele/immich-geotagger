import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:libre_location/libre_location.dart';

import '../models/location_point.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
void libreLocationHeadlessDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
}

@pragma('vm:entry-point')
void libreLocationHeadlessCallback(Map<String, dynamic> data) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    final position = Position.fromMap(data);
    await _savePosition(position);
  } catch (_) {
    // Ignore malformed headless payloads instead of terminating the service.
  }
}

Future<void> saveLibreLocationPosition(Position position) async {
  await _savePosition(position);
}

Future<void> _savePosition(Position position) async {
  await DatabaseService.instance.insertLocation(
    LocationPoint(
      timestamp: position.timestamp.toUtc(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    ),
  );
}
