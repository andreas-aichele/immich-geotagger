import 'dart:io';
import 'dart:ui';

import 'package:background_locator_neo/background_locator.dart';
import 'package:background_locator_neo/settings/android_settings.dart';
import 'package:background_locator_neo/settings/ios_settings.dart';
import 'package:background_locator_neo/settings/locator_settings.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'background_location_callback.dart';
import 'settings_service.dart';

class TrackingService {
  TrackingService({SettingsService? settings})
      : _settings = settings ?? SettingsService();

  final SettingsService _settings;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await BackgroundLocator.initialize();
    _initialized = true;
  }

  Future<bool> get isTracking async {
    await initialize();
    return BackgroundLocator.isServiceRunning();
  }

  Future<bool> requestForegroundLocationPermission() async {
    final foreground = await ph.Permission.locationWhenInUse.request();
    return foreground.isGranted;
  }

  Future<bool> isBackgroundLocationGranted() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return ph.Permission.locationAlways.isGranted;
    }
    return true;
  }

  Future<void> requestRequiredPermissions() async {
    final foreground = await ph.Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      throw StateError(
        'Precise location permission is required before background access can be enabled.',
      );
    }

    if (Platform.isAndroid) {
      if (!await isBackgroundLocationGranted()) {
        throw StateError(
          'Background location is not enabled. Open the app settings and choose “Allow all the time”.',
        );
      }
      await ph.Permission.notification.request();
      return;
    }

    if (Platform.isIOS) {
      var always = await ph.Permission.locationAlways.status;
      if (!always.isGranted) {
        always = await ph.Permission.locationAlways.request();
      }
      if (!always.isGranted) {
        throw StateError('Background location permission is required.');
      }
    }
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
    await initialize();
    return BackgroundLocator.isServiceRunning();
  }

  Future<void> openSystemSettings() async {
    await ph.openAppSettings();
  }

  Future<bool> resumeIfNeeded() async {
    await initialize();
    if (!await _settings.isTrackingDesired()) return false;
    if (await BackgroundLocator.isServiceRunning()) return true;
    await start(persistDesiredState: false);
    return true;
  }

  Future<void> start({bool persistDesiredState = true}) async {
    await initialize();
    await requestRequiredPermissions();

    if (await BackgroundLocator.isServiceRunning()) {
      if (persistDesiredState) {
        await _settings.setTrackingDesired(true);
      }
      return;
    }

    final settings = await _settings.load();
    final notification = _notificationCopy();

    await BackgroundLocator.registerLocationUpdate(
      backgroundLocationCallback,
      initCallback: backgroundLocationInitCallback,
      disposeCallback: backgroundLocationDisposeCallback,
      iosSettings: IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 0,
        stopWithTerminate: false,
        pausesLocationUpdatesAutomatically: false,
        showsBackgroundLocationIndicator: true,
        activityType: LocationActivityType.other,
      ),
      androidSettings: AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: settings.trackingIntervalSeconds,
        distanceFilter: 0,
        client: LocationClient.android,
        wakeLockTime: 60,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: notification.channel,
          notificationTitle: notification.title,
          notificationMsg: notification.subtitle,
          notificationBigMsg: notification.description,
          notificationTapCallback: backgroundNotificationTapCallback,
        ),
      ),
    );

    if (persistDesiredState) {
      await _settings.setTrackingDesired(true);
    }
  }

  Future<void> stop() async {
    await initialize();
    await BackgroundLocator.unRegisterLocationUpdate();
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
