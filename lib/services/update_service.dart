import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRelease {
  const AppRelease(this.version);

  final Version version;

  Uri get url => Uri.https(
        'github.com',
        '/andreas-aichele/immich-geotagger/releases/tag/v$version',
      );
}

class UpdateService {
  UpdateService({
    http.Client? client,
    Future<String> Function()? installedVersion,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _installedVersion =
            installedVersion ?? (() async => (await PackageInfo.fromPlatform()).version),
        _now = now ?? DateTime.now;

  final http.Client _client;
  final Future<String> Function() _installedVersion;
  final DateTime Function() _now;

  static const _enabled = 'update_check_enabled';
  static const _checkedAt = 'update_checked_at';
  static const _release = 'update_release';
  static const _dismissed = 'update_dismissed';

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabled) ?? true;

  static Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_enabled, value);
  }

  Future<void> dismiss(AppRelease release) async {
    await (await SharedPreferences.getInstance())
        .setString(_dismissed, release.version.toString());
  }

  Future<AppRelease?> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_enabled) == false) return null;
      // Beta builds share the base release's versionCode. Do not offer that
      // same stable version as an update to a newer beta installation.
      final installed = Version.parse((await _installedVersion()).split('-').first);
      final now = _now().toUtc();
      final lastCheck = prefs.getInt(_checkedAt);
      if (lastCheck == null ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastCheck, isUtc: true)) >=
              const Duration(days: 1)) {
        // Count failed attempts too, so offline/rate-limited starts do not
        // repeatedly contact GitHub.
        await prefs.setInt(_checkedAt, now.millisecondsSinceEpoch);
        final response = await _client.get(
          Uri.https('api.github.com',
              '/repos/andreas-aichele/immich-geotagger/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final tag = data['tag_name'];
          if (data['draft'] != true && data['prerelease'] != true &&
              tag is String && RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
            await prefs.setString(_release, tag.substring(1));
          } else {
            await prefs.remove(_release);
          }
        }
      }
      if (prefs.getBool(_enabled) == false) return null;
      final cached = prefs.getString(_release);
      if (cached == null || cached == prefs.getString(_dismissed)) return null;
      final version = Version.parse(cached);
      return version > installed ? AppRelease(version) : null;
    } catch (_) {
      // Update availability is optional; never interrupt GPS tracking or sync.
      return null;
    }
  }

  void dispose() => _client.close();
}
