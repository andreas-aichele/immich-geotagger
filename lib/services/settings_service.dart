import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackingQuality {
  balanced,
  precise,
}

class AppSettings {
  const AppSettings({
    required this.immichUrl,
    required this.apiKey,
    required this.retentionDays,
    required this.trackingQuality,
  });

  final String immichUrl;
  final String apiKey;
  final int retentionDays;
  final TrackingQuality trackingQuality;
}

class SettingsService {
  static const _secure = FlutterSecureStorage();
  static const _apiKey = 'immich_api_key';
  static const _onboardingComplete = 'onboarding_complete';
  static const _trackingDesired = 'tracking_desired';
  static const _trackingQuality = 'tracking_quality';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final qualityName = prefs.getString(_trackingQuality);
    final quality = TrackingQuality.values.firstWhere(
      (value) => value.name == qualityName,
      orElse: () => TrackingQuality.balanced,
    );

    return AppSettings(
      immichUrl: prefs.getString('immich_url') ?? '',
      apiKey: await _secure.read(key: _apiKey) ?? '',
      retentionDays: prefs.getInt('retention_days') ?? 14,
      trackingQuality: quality,
    );
  }

  Future<void> saveConnection({
    required String immichUrl,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('immich_url', immichUrl.trim());
    await _secure.write(key: _apiKey, value: apiKey.trim());
  }

  Future<void> saveTrackingPreferences({
    required int retentionDays,
    required TrackingQuality trackingQuality,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('retention_days', retentionDays);
    await prefs.setString(_trackingQuality, trackingQuality.name);
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
