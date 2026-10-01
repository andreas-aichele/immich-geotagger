import 'dart:math' as math;

import '../models/location_point.dart';

class InterpolationResult {
  const InterpolationResult({
    required this.latitude,
    required this.longitude,
    required this.before,
    required this.after,
  });

  final double latitude;
  final double longitude;
  final LocationPoint before;
  final LocationPoint after;
}

class InterpolationService {
  const InterpolationService();

  static const maxInterpolationGap = Duration(minutes: 15);
  static const stationaryDistanceMeters = 100.0;
  static const stationaryMaxGap = Duration(minutes: 90);
  static const nearestPointMaxGap = Duration(minutes: 5);

  // Only very obvious single-point excursions are removed. The ratio-based
  // check deliberately allows sustained high-speed travel (for example an
  // aircraft), because consecutive points continue along the route instead of
  // immediately returning close to the previous position.
  static const outlierMinExcursionMeters = 10000.0;
  static const outlierBaselineFloorMeters = 1000.0;
  static const outlierDetourRatio = 5.0;

  List<LocationPoint> withoutIsolatedOutliers(List<LocationPoint> points) {
    if (points.length < 3) return List<LocationPoint>.of(points);

    final filtered = <LocationPoint>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final next = points[i + 1];

      if (!_isIsolatedOutlier(previous, current, next)) {
        filtered.add(current);
      }
    }
    filtered.add(points.last);
    return filtered;
  }

  bool _isIsolatedOutlier(
    LocationPoint previous,
    LocationPoint current,
    LocationPoint next,
  ) {
    final previousTime = previous.timestamp.toUtc();
    final currentTime = current.timestamp.toUtc();
    final nextTime = next.timestamp.toUtc();
    if (!currentTime.isAfter(previousTime) || !nextTime.isAfter(currentTime)) {
      return false;
    }

    final intoExcursion = distanceMeters(previous, current);
    final outOfExcursion = distanceMeters(current, next);
    if (intoExcursion < outlierMinExcursionMeters ||
        outOfExcursion < outlierMinExcursionMeters) {
      return false;
    }

    final direct = distanceMeters(previous, next);
    final baseline = math.max(direct, outlierBaselineFloorMeters);
    final detour = intoExcursion + outOfExcursion;
    return detour >= baseline * outlierDetourRatio;
  }

  InterpolationResult? interpolate({
    required DateTime timestamp,
    required List<LocationPoint> points,
  }) {
    if (points.length < 2) return null;
    final target = timestamp.toUtc();

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final at = a.timestamp.toUtc();
      final bt = b.timestamp.toUtc();

      if (target.isBefore(at) || target.isAfter(bt)) continue;
      final gap = bt.difference(at);
      if (gap <= Duration.zero) return null;

      final distance = distanceMeters(a, b);
      final stationary =
          distance <= stationaryDistanceMeters && gap <= stationaryMaxGap;

      // Moving segments are intentionally capped at 15 minutes. Stationary
      // periods may be bridged for longer because Android can suppress fixes
      // while the device is not moving.
      if (gap > maxInterpolationGap && !stationary) return null;

      final elapsedMs = target.difference(at).inMilliseconds;
      final ratio = elapsedMs / gap.inMilliseconds;

      return InterpolationResult(
        latitude: a.latitude + (b.latitude - a.latitude) * ratio,
        longitude: a.longitude + (b.longitude - a.longitude) * ratio,
        before: a,
        after: b,
      );
    }
    return null;
  }

  LocationPoint? nearestPoint({
    required DateTime timestamp,
    required List<LocationPoint> points,
    Duration maxGap = nearestPointMaxGap,
  }) {
    if (points.isEmpty) return null;
    final target = timestamp.toUtc();
    LocationPoint? nearest;
    Duration? nearestGap;

    for (final point in points) {
      final delta = point.timestamp.toUtc().difference(target).abs();
      if (delta > maxGap) continue;
      if (nearestGap == null || delta < nearestGap) {
        nearest = point;
        nearestGap = delta;
      }
    }
    return nearest;
  }

  double distanceMeters(LocationPoint a, LocationPoint b) {
    const earthRadius = 6371000.0;
    final phi1 = a.latitude * math.pi / 180;
    final phi2 = b.latitude * math.pi / 180;
    final deltaPhi = (b.latitude - a.latitude) * math.pi / 180;
    final deltaLambda = (b.longitude - a.longitude) * math.pi / 180;

    final h = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final angle = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * angle;
  }

  double averageSpeedKmh(double distanceMeters, Duration duration) {
    if (duration <= Duration.zero) return double.infinity;
    return (distanceMeters / 1000) / (duration.inMilliseconds / 3600000);
  }
}
