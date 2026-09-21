import '../models/geotagged_asset.dart';
import '../models/sync_preview.dart';
import 'database_service.dart';
import 'immich_service.dart';
import 'interpolation_service.dart';
import 'settings_service.dart';
import 'tracking_service.dart';

class SyncResult {
  const SyncResult({
    required this.scanned,
    required this.updated,
    required this.skippedWithLocation,
    required this.skippedWithoutTrack,
  });

  final int scanned;
  final int updated;
  final int skippedWithLocation;
  final int skippedWithoutTrack;
}

class SyncService {
  SyncService({
    DatabaseService? database,
    SettingsService? settings,
    ImmichService? immich,
    InterpolationService? interpolation,
    TrackingService? tracking,
  })  : _database = database ?? DatabaseService.instance,
        _settings = settings ?? SettingsService(),
        _immich = immich ?? ImmichService(),
        _interpolation = interpolation ?? const InterpolationService(),
        _tracking = tracking ?? TrackingService();

  final DatabaseService _database;
  final SettingsService _settings;
  final ImmichService _immich;
  final InterpolationService _interpolation;
  final TrackingService _tracking;

  Future<SyncPreview> prepareSync() async {
    final settings = await _settings.load();
    if (settings.immichUrl.isEmpty || settings.apiKey.isEmpty) {
      throw StateError('Immich URL and API key are required');
    }

    final retention = Duration(days: settings.retentionDays);
    await _database.purgeLocationsOlderThan(retention);

    // Close the current route with a fresh point before matching. This is
    // especially important while stationary, where Android may suppress normal
    // movement-based location callbacks.
    if (await _tracking.isTracking) {
      await _tracking.captureCurrentPoint();
    }

    final to = DateTime.now().toUtc();
    final from = to.subtract(retention);
    final points = await _database.locationsBetween(from, to);

    // Search the whole configured retention window. Previously this search
    // ended at the last GPS point, which could hide newer Immich assets while
    // the phone was stationary.
    final assets = await _immich.assetsTakenBetween(
      baseUrl: settings.immichUrl,
      apiKey: settings.apiKey,
      from: from,
      to: to,
    );

    if (points.length < 2) {
      final existing = assets.where((asset) => asset.hasLocation).length;
      return SyncPreview(
        candidates: const [],
        scanned: assets.length,
        skippedWithLocation: existing,
        skippedWithoutTrack: assets.length - existing,
      );
    }

    final candidates = <SyncCandidate>[];
    var existing = 0;
    var noTrack = 0;

    for (final asset in assets) {
      if (asset.hasLocation) {
        existing++;
        continue;
      }

      final match = _interpolation.interpolate(
        timestamp: asset.takenAt,
        points: points,
        maxGap: Duration(minutes: settings.maxInterpolationGapMinutes),
      );

      if (match == null) {
        noTrack++;
        continue;
      }

      candidates.add(
        SyncCandidate(
          asset: asset,
          latitude: match.latitude,
          longitude: match.longitude,
          before: match.before.timestamp,
          after: match.after.timestamp,
        ),
      );
    }

    return SyncPreview(
      candidates: candidates,
      scanned: assets.length,
      skippedWithLocation: existing,
      skippedWithoutTrack: noTrack,
    );
  }

  Future<SyncResult> applySync(
    SyncPreview preview,
    Iterable<SyncCandidate> selected,
  ) async {
    final settings = await _settings.load();
    if (settings.immichUrl.isEmpty || settings.apiKey.isEmpty) {
      throw StateError('Immich URL and API key are required');
    }

    var updated = 0;

    for (final candidate in selected) {
      await _immich.updateLocation(
        baseUrl: settings.immichUrl,
        apiKey: settings.apiKey,
        assetId: candidate.asset.id,
        latitude: candidate.latitude,
        longitude: candidate.longitude,
      );

      await _database.saveUpdatedAsset(
        GeotaggedAsset(
          assetId: candidate.asset.id,
          fileName: candidate.asset.fileName,
          captureTime: candidate.asset.takenAt,
          latitude: candidate.latitude,
          longitude: candidate.longitude,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      updated++;
    }

    return SyncResult(
      scanned: preview.scanned,
      updated: updated,
      skippedWithLocation: preview.skippedWithLocation,
      skippedWithoutTrack: preview.skippedWithoutTrack,
    );
  }
}
