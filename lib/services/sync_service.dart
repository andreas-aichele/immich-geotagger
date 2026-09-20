import '../models/geotagged_asset.dart';
import 'database_service.dart';
import 'immich_service.dart';
import 'interpolation_service.dart';
import 'settings_service.dart';

class SyncResult {
  const SyncResult({required this.scanned, required this.updated, required this.skippedWithLocation, required this.skippedWithoutTrack});
  final int scanned;
  final int updated;
  final int skippedWithLocation;
  final int skippedWithoutTrack;
}

class SyncService {
  SyncService({DatabaseService? database, SettingsService? settings, ImmichService? immich, InterpolationService? interpolation})
      : _database = database ?? DatabaseService.instance,
        _settings = settings ?? SettingsService(),
        _immich = immich ?? ImmichService(),
        _interpolation = interpolation ?? const InterpolationService();

  final DatabaseService _database;
  final SettingsService _settings;
  final ImmichService _immich;
  final InterpolationService _interpolation;

  Future<SyncResult> sync() async {
    final settings = await _settings.load();
    if (settings.immichUrl.isEmpty || settings.apiKey.isEmpty) throw StateError('Immich URL and API key are required');

    final retention = Duration(days: settings.retentionDays);
    await _database.purgeLocationsOlderThan(retention);
    final to = DateTime.now().toUtc();
    final from = to.subtract(retention);
    final points = await _database.locationsBetween(from, to);
    if (points.length < 2) return const SyncResult(scanned: 0, updated: 0, skippedWithLocation: 0, skippedWithoutTrack: 0);

    final assets = await _immich.assetsTakenBetween(baseUrl: settings.immichUrl, apiKey: settings.apiKey, from: points.first.timestamp, to: points.last.timestamp);
    var updated = 0;
    var existing = 0;
    var noTrack = 0;

    for (final asset in assets) {
      if (asset.hasLocation) {
        existing++;
        continue;
      }
      final match = _interpolation.interpolate(timestamp: asset.takenAt, points: points, maxGap: Duration(minutes: settings.maxInterpolationGapMinutes));
      if (match == null) {
        noTrack++;
        continue;
      }
      await _immich.updateLocation(baseUrl: settings.immichUrl, apiKey: settings.apiKey, assetId: asset.id, latitude: match.latitude, longitude: match.longitude);
      await _database.saveUpdatedAsset(GeotaggedAsset(assetId: asset.id, fileName: asset.fileName, captureTime: asset.takenAt, latitude: match.latitude, longitude: match.longitude, updatedAt: DateTime.now().toUtc()));
      updated++;
    }

    return SyncResult(scanned: assets.length, updated: updated, skippedWithLocation: existing, skippedWithoutTrack: noTrack);
  }
}
