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
      if (gap <= Duration.zero || gap > maxGap) return null;

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
}
