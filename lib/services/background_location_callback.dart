import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:libre_location/libre_location.dart' hide LogLevel;

import '../models/location_point.dart';
import 'database_service.dart';
import 'logging_service.dart';

@pragma('vm:entry-point')
void libreLocationHeadlessDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
}

@pragma('vm:entry-point')
void libreLocationHeadlessCallback(Map<String, dynamic> data) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await LoggingService.initialize();
  try {
    final position = Position.fromMap(data);
    await _savePosition(position);
  } catch (error, stack) {
    await LoggingService.error(
      'tracking',
      'Headless location callback failed',
      error,
      stack,
    );
  }
}

Future<void> saveLibreLocationPosition(Position position) async {
  await _savePosition(position);
}

Future<void> _savePosition(Position position) async {
  await LoggingService.log(
    LogLevel.debug,
    'tracking',
    'GPS received: accuracy=${position.accuracy}m',
  );
  await LoggingService.log(
    LogLevel.trace,
    'tracking',
    'GPS latitude=${position.latitude} longitude=${position.longitude} '
        'timestamp=${position.timestamp.toUtc().toIso8601String()}',
  );
  await DatabaseService.instance.insertLocation(
    LocationPoint(
      timestamp: position.timestamp.toUtc(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    ),
  );
}
