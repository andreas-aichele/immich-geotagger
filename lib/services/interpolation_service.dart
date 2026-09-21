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

      // Balanced background tracking may intentionally produce sparse points
      // while the device is stationary. A long time gap is still safe when
      // both measurements are effectively at the same place.
      if (gap > maxGap && _distanceMeters(a, b) > 50) return null;

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

  double _distanceMeters(LocationPoint a, LocationPoint b) {
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
}
