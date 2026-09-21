import 'dart:math' as math;

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
      // A fresh point closes the currently active route. Keep this best-effort
      // and short so opening the preview never waits for the full 20-second
      // location timeout.
      await _tracking.captureCurrentPoint(timeoutSeconds: 5);
    }

    final now = DateTime.now().toUtc();
    final retentionStart = now.subtract(retention);
    final points = await _database.locationsBetween(retentionStart, now);

    if (points.length < 2) {
      return const SyncPreview(
        candidates: [],
        scanned: 0,
        skippedWithLocation: 0,
        skippedWithoutTrack: 0,
      );
    }

    // Only assets inside the recorded route can ever be interpolated. Searching
    // the complete retention period made preview generation unnecessarily slow
    // on larger Immich libraries.
    // Give Immich's date filter a generous margin. Camera metadata can carry
    // incomplete timezone information, and Immich versions have had date/time
    // conversion differences. Final acceptance is still done strictly against
    // the recorded GPS points below.
    final searchFrom =
        points.first.timestamp.toUtc().subtract(const Duration(hours: 12));
    final searchTo =
        points.last.timestamp.toUtc().add(const Duration(hours: 12));
    final assets = await _immich.assetsTakenBetween(
      baseUrl: settings.immichUrl,
      apiKey: settings.apiKey,
      from: searchFrom,
      to: searchTo,
    );

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
          reliability: _reliabilityFor(match),
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

  MatchReliability _reliabilityFor(InterpolationResult match) {
    final gap = match.after.timestamp.difference(match.before.timestamp);
    final distance = _distanceMeters(
      match.before.latitude,
      match.before.longitude,
      match.after.latitude,
      match.after.longitude,
    );

    if (distance <= 25 || gap <= const Duration(minutes: 2)) {
      return MatchReliability.high;
    }
    if (distance <= 100 || gap <= const Duration(minutes: 5)) {
      return MatchReliability.medium;
    }
    return MatchReliability.low;
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final angle = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * angle;
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
