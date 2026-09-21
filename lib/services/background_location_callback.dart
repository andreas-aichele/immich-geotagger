import 'dart:ui';

import 'package:background_locator_neo/location_dto.dart';
import '../models/location_point.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundLocationCallback(LocationDto location) async {
  DartPluginRegistrant.ensureInitialized();

  await DatabaseService.instance.insertLocation(
    LocationPoint(
      timestamp: DateTime.now().toUtc(),
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
    ),
  );
}

@pragma('vm:entry-point')
void backgroundLocationInitCallback(Map<dynamic, dynamic> params) {
  DartPluginRegistrant.ensureInitialized();
}

@pragma('vm:entry-point')
void backgroundLocationDisposeCallback() {}

@pragma('vm:entry-point')
void backgroundNotificationTapCallback() {}
