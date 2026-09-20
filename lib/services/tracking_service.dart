import 'dart:async';

import 'package:location/location.dart';

import '../models/location_point.dart';
import 'database_service.dart';
import 'settings_service.dart';

class TrackingService {
  TrackingService({
    DatabaseService? database,
    SettingsService? settings,
    Location? location,
  })  : _database = database ?? DatabaseService.instance,
        _settings = settings ?? SettingsService(),
        _location = location ?? Location();

  final DatabaseService _database;
  final SettingsService _settings;
  final Location _location;
  StreamSubscription<LocationData>? _subscription;

  bool get isTracking => _subscription != null;

  Future<void> start() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) enabled = await _location.requestService();
    if (!enabled) throw StateError('Location services are disabled');

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw StateError('Location permission not granted');
    }

    final settings = await _settings.load();
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: settings.trackingIntervalSeconds * 1000,
      distanceFilter: 0,
    );

    final backgroundEnabled =
        await _location.enableBackgroundMode(enable: true);
    if (!backgroundEnabled) {
      throw StateError('Background location mode could not be enabled');
    }

    await _subscription?.cancel();
    _subscription = _location.onLocationChanged.listen((data) async {
      final timestamp = data.time == null
          ? DateTime.now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(
              data.time!.round(),
              isUtc: true,
            );

      await _database.insertLocation(
        LocationPoint(
          timestamp: timestamp,
          latitude: data.latitude,
          longitude: data.longitude,
          accuracy: data.accuracy,
        ),
      );
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _location.enableBackgroundMode(enable: false);
  }
}
