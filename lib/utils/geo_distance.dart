import 'dart:math' as math;

/// Great-circle distance in metres, shared by matching and map clustering.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final deltaPhi = (lat2 - lat1) * math.pi / 180;
  final deltaLambda = (lon2 - lon1) * math.pi / 180;
  final h = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
