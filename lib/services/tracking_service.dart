import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:libre_location/libre_location.dart';

import 'background_location_callback.dart';
import 'settings_service.dart';

class TrackingService {
  TrackingService({SettingsService? settings})
      : _settings = settings ?? SettingsService();

  final SettingsService _settings;

  bool _initialized = false;
  StreamSubscription<Position>? _positionSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    await LibreLocation.registerHeadlessDispatcher(
      libreLocationHeadlessDispatcher,
      libreLocationHeadlessCallback,
    );

    _initialized = true;

    if (await LibreLocation.isTracking) {
      _ensureForegroundListener();
    }
  }

  Future<bool> get isTracking async {
    await initialize();
    return LibreLocation.isTracking;
  }

  Future<bool> requestForegroundLocationPermission() async {
    final enabled = await LibreLocation.isLocationServiceEnabled();
    if (!enabled) {
      await LibreLocation.openLocationSettings();
      return false;
    }

    var permission = await LibreLocation.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await LibreLocation.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<bool> isBackgroundLocationGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return await LibreLocation.checkPermission() == LocationPermission.always;
  }

  Future<void> requestRequiredPermissions() async {
    final foreground = await requestForegroundLocationPermission();
    if (!foreground) {
      throw StateError(
        'Precise location permission is required before background access can be enabled.',
      );
    }

    var permission = await LibreLocation.checkPermission();
    if (permission != LocationPermission.always) {
      permission = await LibreLocation.requestAlwaysPermission();
    }

    if (permission != LocationPermission.always) {
      throw StateError(
        'Background location is not enabled. Open the app settings and choose “Allow all the time”.',
      );
    }

    if (Platform.isAndroid &&
        !await LibreLocation.checkNotificationPermission()) {
      await LibreLocation.requestNotificationPermission();
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    final optimized = await LibreLocation.checkBatteryOptimization();
    return !optimized;
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;

    if (!await LibreLocation.checkBatteryOptimization()) return true;

    await LibreLocation.requestBatteryOptimizationExemption();
    return !await LibreLocation.checkBatteryOptimization();
  }

  Future<bool> isBackgroundModeEnabled() async {
    await initialize();
    return LibreLocation.isTracking;
  }

  Future<void> openSystemSettings() async {
    await LibreLocation.openAppSettings();
  }

  Future<bool> resumeIfNeeded() async {
    await initialize();
    if (!await _settings.isTrackingDesired()) return false;

    if (await LibreLocation.isTracking) {
      _ensureForegroundListener();
      return true;
    }

    await start(persistDesiredState: false);
    return true;
  }

  Future<void> start({bool persistDesiredState = true}) async {
    await initialize();
    await requestRequiredPermissions();

    if (await LibreLocation.isTracking) {
      _ensureForegroundListener();
      if (persistDesiredState) {
        await _settings.setTrackingDesired(true);
      }
      return;
    }

    final settings = await _settings.load();
    final notification = _notificationCopy();

    await LibreLocation.start(
      preset: _presetForInterval(settings.trackingIntervalSeconds),
      config: LocationConfig(
        notification: NotificationConfig(
          title: notification.title,
          text: notification.subtitle,
          sticky: true,
        ),
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
      ),
    );

    _ensureForegroundListener();

    if (persistDesiredState) {
      await _settings.setTrackingDesired(true);
    }
  }

  Future<void> stop() async {
    await initialize();
    await LibreLocation.stop();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _settings.setTrackingDesired(false);
  }

  void _ensureForegroundListener() {
    _positionSubscription ??= LibreLocation.onLocation.listen(
      saveLibreLocationPosition,
    );
  }

  TrackingPreset _presetForInterval(int seconds) {
    if (seconds <= 120) return TrackingPreset.high;
    if (seconds <= 300) return TrackingPreset.balanced;
    return TrackingPreset.low;
  }

  _NotificationCopy _notificationCopy() {
    final language =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();

    switch (language) {
      case 'de':
        return const _NotificationCopy(
          title: 'Immich GeoTagger zeichnet auf',
          subtitle: 'Standort-Tracking ist im Hintergrund aktiv',
        );
      case 'fr':
        return const _NotificationCopy(
          title: 'Immich GeoTagger enregistre',
          subtitle: 'Le suivi de localisation est actif en arrière-plan',
        );
      case 'es':
        return const _NotificationCopy(
          title: 'Immich GeoTagger está registrando',
          subtitle: 'El seguimiento de ubicación está activo en segundo plano',
        );
      case 'nl':
        return const _NotificationCopy(
          title: 'Immich GeoTagger registreert',
          subtitle: 'Locatietracking is actief op de achtergrond',
        );
      default:
        return const _NotificationCopy(
          title: 'Immich GeoTagger is recording',
          subtitle: 'Location tracking is active in the background',
        );
    }
  }
}

class _NotificationCopy {
  const _NotificationCopy({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}
