import '../models/geotagged_asset.dart';
import '../models/immich_asset.dart';
import '../models/location_point.dart';
import '../models/sync_preview.dart';
import '../utils/geo_distance.dart';
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
    final trackingActive = await _tracking.isTracking;
    if (trackingActive) {
      // A fresh point closes the currently active route. Keep this best-effort
      // and short so opening the preview never waits for the full 20-second
      // location timeout.
      await _tracking.captureCurrentPoint(timeoutSeconds: 5);
    }

    final now = DateTime.now().toUtc();
    final retentionStart = now.subtract(retention);
    final rawPoints = await _database.locationsBetween(retentionStart, now);
    final points = _interpolation.withoutIsolatedOutliers(rawPoints);

    // The retention setting defines the Immich review window as well as the
    // local GPS retention window. This keeps the preview transparent: every
    // image in Immich from the configured period is classified, even when no
    // matching GPS track exists for it.
    final assets = await _immich.assetsTakenBetween(
      baseUrl: settings.immichUrl,
      apiKey: settings.apiKey,
      from: retentionStart,
      to: now,
    );

    final candidates = <SyncCandidate>[];
    final unmatched = <SyncUnmatched>[];
    var existing = 0;

    for (final asset in assets) {
      if (asset.hasLocation) {
        existing++;
        continue;
      }

      final match = _interpolation.interpolate(
        timestamp: asset.takenAt,
        points: points,
      );

      if (match == null) {
        final nearest = _interpolation.nearestPoint(
          timestamp: asset.takenAt,
          points: points,
        );
        final fallback = nearest ??
            _lastKnownLocationFallback(
              assetTime: asset.takenAt,
              points: points,
              trackingActive: trackingActive,
            );

        if (fallback != null) {
          candidates.add(
            SyncCandidate(
              asset: asset,
              latitude: fallback.latitude,
              longitude: fallback.longitude,
              before: fallback.timestamp,
              after: fallback.timestamp,
              reliability: nearest != null
                  ? MatchReliability.medium
                  : MatchReliability.low,
              usedLastKnownLocation: true,
            ),
          );
          continue;
        }

        unmatched.add(_diagnoseUnmatched(asset, points));
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
      skippedWithoutTrack: unmatched.length,
      unmatched: unmatched,
      maxInterpolationGapMinutes:
          InterpolationService.maxInterpolationGap.inMinutes,
    );
  }

  LocationPoint? _lastKnownLocationFallback({
    required DateTime assetTime,
    required List<LocationPoint> points,
    required bool trackingActive,
  }) {
    if (!trackingActive || points.length < 2) return null;

    final target = assetTime.toUtc();
    final last = points.last;
    final previous = points[points.length - 2];
    final lastTime = last.timestamp.toUtc();

    if (!target.isAfter(lastTime)) return null;
    if (target.difference(lastTime) > const Duration(minutes: 15)) return null;

    final movement = distanceMeters(
      previous.latitude,
      previous.longitude,
      last.latitude,
      last.longitude,
    );
    if (movement > InterpolationService.stationaryDistanceMeters) return null;

    return last;
  }

  SyncUnmatched _diagnoseUnmatched(
    ImmichAsset asset,
    List<LocationPoint> points,
  ) {
    if (points.isEmpty) {
      return SyncUnmatched(asset: asset, reason: UnmatchedReason.noTrackData);
    }

    final target = asset.takenAt.toUtc();
    final first = points.first.timestamp.toUtc();
    final last = points.last.timestamp.toUtc();

    if (target.isBefore(first)) {
      return SyncUnmatched(
        asset: asset,
        reason: UnmatchedReason.beforeTrack,
        after: points.first.timestamp,
      );
    }

    if (target.isAfter(last)) {
      return SyncUnmatched(
        asset: asset,
        reason: UnmatchedReason.afterTrack,
        before: points.last.timestamp,
      );
    }

    if (points.length < 2) {
      return SyncUnmatched(
        asset: asset,
        reason: UnmatchedReason.noTrackData,
        before: points.first.timestamp,
      );
    }

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final at = a.timestamp.toUtc();
      final bt = b.timestamp.toUtc();
      if (target.isBefore(at) || target.isAfter(bt)) continue;

      final gap = bt.difference(at);
      final movement = distanceMeters(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      final stationary =
          movement <= InterpolationService.stationaryDistanceMeters &&
              gap <= InterpolationService.stationaryMaxGap;
      if (gap > InterpolationService.maxInterpolationGap && !stationary) {
        return SyncUnmatched(
          asset: asset,
          reason: UnmatchedReason.unsafeGap,
          before: a.timestamp,
          after: b.timestamp,
        );
      }
    }

    return SyncUnmatched(asset: asset, reason: UnmatchedReason.noSegment);
  }

  MatchReliability _reliabilityFor(InterpolationResult match) {
    final gap = match.after.timestamp.difference(match.before.timestamp);
    final distance = distanceMeters(
      match.before.latitude,
      match.before.longitude,
      match.after.latitude,
      match.after.longitude,
    );
    if (gap <= const Duration(minutes: 2)) {
      return MatchReliability.high;
    }
    if (gap <= const Duration(minutes: 5)) {
      return MatchReliability.medium;
    }
    if (distance <= InterpolationService.stationaryDistanceMeters &&
        gap <= const Duration(minutes: 30)) {
      return MatchReliability.medium;
    }
    return MatchReliability.low;
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
