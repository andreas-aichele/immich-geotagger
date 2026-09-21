import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.immichUrl,
    required this.apiKey,
    required this.retentionDays,
    required this.trackingIntervalSeconds,
    required this.maxInterpolationGapMinutes,
  });

  final String immichUrl;
  final String apiKey;
  final int retentionDays;
  final int trackingIntervalSeconds;
  final int maxInterpolationGapMinutes;
}

class SettingsService {
  static const _secure = FlutterSecureStorage();
  static const _apiKey = 'immich_api_key';
  static const _onboardingComplete = 'onboarding_complete';
  static const _trackingDesired = 'tracking_desired';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      immichUrl: prefs.getString('immich_url') ?? '',
      apiKey: await _secure.read(key: _apiKey) ?? '',
      retentionDays: prefs.getInt('retention_days') ?? 14,
      trackingIntervalSeconds: prefs.getInt('tracking_interval_seconds') ?? 60,
      maxInterpolationGapMinutes:
          prefs.getInt('max_interpolation_gap_minutes') ?? 15,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('immich_url', settings.immichUrl.trim());
    await prefs.setInt('retention_days', settings.retentionDays);
    await prefs.setInt(
      'tracking_interval_seconds',
      settings.trackingIntervalSeconds,
    );
    await prefs.setInt(
      'max_interpolation_gap_minutes',
      settings.maxInterpolationGapMinutes,
    );
    await _secure.write(key: _apiKey, value: settings.apiKey.trim());
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingComplete, value);
  }

  Future<bool> isTrackingDesired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingDesired) ?? false;
  }

  Future<void> setTrackingDesired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingDesired, value);
  }
}
