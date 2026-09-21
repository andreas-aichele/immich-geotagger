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
  StreamSubscription<HeartbeatEvent>? _heartbeatSubscription;
  Timer? _samplingTimer;

  Future<void> initialize() async {
    if (_initialized) return;

    await LibreLocation.registerHeadlessDispatcher(
      libreLocationHeadlessDispatcher,
      libreLocationHeadlessCallback,
    );

    _initialized = true;

    if (await LibreLocation.isTracking) {
      await _ensureForegroundListeners();
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
      await _ensureForegroundListeners();
      return true;
    }

    await start(persistDesiredState: false);
    return true;
  }

  Future<void> start({bool persistDesiredState = true}) async {
    await initialize();
    await requestRequiredPermissions();

    if (await LibreLocation.isTracking) {
      await _ensureForegroundListeners();
      if (persistDesiredState) {
        await _settings.setTrackingDesired(true);
      }
      return;
    }

    final notification = _notificationCopy();

    await LibreLocation.start(
      preset: TrackingPreset.high,
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

    await captureCurrentPoint();
    await _ensureForegroundListeners();

    if (persistDesiredState) {
      await _settings.setTrackingDesired(true);
    }
  }

  Future<Position?> captureCurrentPoint() async {
    await initialize();

    try {
      final position = await LibreLocation.getCurrentPosition(
        accuracy: Accuracy.high,
        samples: 1,
        timeout: 20,
        maximumAge: 30,
        persist: false,
      );
      await saveLibreLocationPosition(position);
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {
    await initialize();
    _samplingTimer?.cancel();
    _samplingTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _heartbeatSubscription?.cancel();
    _heartbeatSubscription = null;
    await LibreLocation.stop();
    await _settings.setTrackingDesired(false);
  }

  Future<void> _ensureForegroundListeners() async {
    _positionSubscription ??= LibreLocation.onLocation.listen(
      saveLibreLocationPosition,
    );

    _heartbeatSubscription ??= LibreLocation.onHeartbeat.listen(
      (event) => saveLibreLocationPosition(event.position),
    );

    if (_samplingTimer != null) return;

    final settings = await _settings.load();
    final seconds = settings.trackingIntervalSeconds.clamp(15, 3600);

    _samplingTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => captureCurrentPoint(),
    );
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
