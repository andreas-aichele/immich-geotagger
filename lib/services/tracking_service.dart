import 'dart:async';
import 'dart:io';

import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

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

  Future<void> requestRequiredPermissions() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) enabled = await _location.requestService();
    if (!enabled) {
      throw StateError('Location services are disabled on this device.');
    }

    if (Platform.isAndroid) {
      final foreground = await ph.Permission.locationWhenInUse.request();
      if (!foreground.isGranted) {
        throw StateError(
          'Precise location permission is required before background access can be requested.',
        );
      }

      final background = await ph.Permission.locationAlways.request();
      if (!background.isGranted) {
        throw StateError(
          'Background location permission is required. In Android settings, choose “Allow all the time”.',
        );
      }

      await ph.Permission.notification.request();
      return;
    }

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw StateError('Location permission is required.');
    }
  }

  Future<void> openSystemSettings() async {
    await ph.openAppSettings();
  }

  Future<void> start() async {
    await requestRequiredPermissions();

    final settings = await _settings.load();
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: settings.trackingIntervalSeconds * 1000,
      distanceFilter: 0,
    );

    final backgroundEnabled =
        await _location.enableBackgroundMode(enable: true);
    if (!backgroundEnabled) {
      throw StateError(
        'Background tracking could not be enabled. Check the app location permissions.',
      );
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
