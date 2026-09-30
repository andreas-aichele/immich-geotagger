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

  static const stationaryDistanceMeters = 100.0;
  static const stationaryMaxGap = Duration(minutes: 90);
  static const manualAnchorMaxGap = Duration(hours: 12);
  static const nearestPointMaxGap = Duration(minutes: 5);

  InterpolationResult? interpolate({
    required DateTime timestamp,
    required List<LocationPoint> points,
    required Duration maxGap,
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
      final speed = averageSpeedKmh(distance, gap);
      final stationary =
          distance <= stationaryDistanceMeters && gap <= stationaryMaxGap;
      final manualAnchored =
          a.isManual && b.isManual && gap <= manualAnchorMaxGap;

      // Normal movement is bounded by the configured time gap. Stationary
      // periods may be bridged for longer because Android can suppress fixes.
      // Two explicit manual anchors are also allowed to span a longer segment:
      // their measured speed is intentional input (e.g. an aircraft route),
      // rather than a reason to discard the segment.
      if (gap > maxGap && !stationary && !manualAnchored) return null;

      // Guard corrupt/teleported automatic fixes. Deliberately do not impose
      // this ceiling on two manual anchors: aircraft speeds are valid there.
      if (!manualAnchored && speed > 300) return null;

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
