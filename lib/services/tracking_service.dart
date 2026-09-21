import 'dart:async';
import 'dart:io';
import 'dart:ui';

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
          'Precise location permission is required before background access can be enabled.',
        );
      }

      if (!await isBackgroundLocationGranted()) {
        throw StateError(
          'Background location is not enabled. Open the app settings and choose “Allow all the time”.',
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

  Future<bool> requestForegroundLocationPermission() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) enabled = await _location.requestService();
    if (!enabled) return false;

    if (!Platform.isAndroid) {
      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      return permission == PermissionStatus.granted ||
          permission == PermissionStatus.grantedLimited;
    }

    final status = await ph.Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> isBackgroundLocationGranted() async {
    if (!Platform.isAndroid) return true;
    return ph.Permission.locationAlways.isGranted;
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    return ph.Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    final status = await ph.Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> isBackgroundModeEnabled() async {
    if (!Platform.isAndroid && !Platform.isIOS) return isTracking;
    return _location.isBackgroundModeEnabled();
  }

  Future<void> openSystemSettings() async {
    await ph.openAppSettings();
  }

  Future<bool> resumeIfNeeded() async {
    if (!await _settings.isTrackingDesired()) return false;
    await start(persistDesiredState: false);
    return true;
  }

  Future<void> start({bool persistDesiredState = true}) async {
    await requestRequiredPermissions();

    final settings = await _settings.load();
    final intervalMs = settings.trackingIntervalSeconds * 1000;

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: intervalMs,
      backgroundInterval: intervalMs,
      distanceFilter: 0,
      pausesLocationUpdatesAutomatically: false,
    );

    if (Platform.isAndroid) {
      final notification = _notificationCopy();
      await _location.changeNotificationOptions(
        channelName: notification.channel,
        title: notification.title,
        subtitle: notification.subtitle,
        description: notification.description,
        iconName: 'ic_launcher_geotagger',
        onTapBringToFront: true,
      );
    }

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

    if (persistDesiredState) {
      await _settings.setTrackingDesired(true);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _location.enableBackgroundMode(enable: false);
    await _settings.setTrackingDesired(false);
  }

  _NotificationCopy _notificationCopy() {
    final language =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();

    switch (language) {
      case 'de':
        return const _NotificationCopy(
          channel: 'Standortaufzeichnung',
          title: 'Immich GeoTagger zeichnet auf',
          subtitle: 'Standort-Tracking aktiv',
          description:
              'Dein Standort wird im Hintergrund für die spätere Foto-Zuordnung aufgezeichnet.',
        );
      case 'fr':
        return const _NotificationCopy(
          channel: 'Suivi de localisation',
          title: 'Immich GeoTagger enregistre',
          subtitle: 'Suivi de localisation actif',
          description:
              'Votre position est enregistrée en arrière-plan pour associer vos photos.',
        );
      case 'es':
        return const _NotificationCopy(
          channel: 'Seguimiento de ubicación',
          title: 'Immich GeoTagger está registrando',
          subtitle: 'Seguimiento de ubicación activo',
          description:
              'Tu ubicación se registra en segundo plano para relacionarla con tus fotos.',
        );
      case 'nl':
        return const _NotificationCopy(
          channel: 'Locatietracking',
          title: 'Immich GeoTagger registreert',
          subtitle: 'Locatietracking actief',
          description:
              'Je locatie wordt op de achtergrond geregistreerd om foto’s te koppelen.',
        );
      default:
        return const _NotificationCopy(
          channel: 'Location tracking',
          title: 'Immich GeoTagger is recording',
          subtitle: 'Location tracking active',
          description:
              'Your location is recorded in the background for photo matching.',
        );
    }
  }
}

class _NotificationCopy {
  const _NotificationCopy({
    required this.channel,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String channel;
  final String title;
  final String subtitle;
  final String description;
}
