import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/models/location_point.dart';
import 'package:immich_geotagger/services/interpolation_service.dart';

void main() {
  const service = InterpolationService();

  test('linearly interpolates a point between two measurements', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
      LocationPoint(timestamp: start.add(const Duration(minutes: 10)), latitude: 49.0, longitude: 12.0),
    ];
    final result = service.interpolate(timestamp: start.add(const Duration(minutes: 5)), points: points, maxGap: const Duration(minutes: 15));
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(48.5, 0.000001));
    expect(result.longitude, closeTo(11.5, 0.000001));
  });

  test('does not interpolate across a gap larger than the limit', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 30)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
        LocationPoint(timestamp: start.add(const Duration(hours: 1)), latitude: 49.0, longitude: 12.0),
      ],
      maxGap: const Duration(minutes: 15),
    );
    expect(result, isNull);
  });

  test('allows a long gap when both points are at nearly the same place', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 30)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.400000, longitude: 10.950000),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 1)),
          latitude: 48.400100,
          longitude: 10.950100,
        ),
      ],
      maxGap: const Duration(minutes: 15),
    );
    expect(result, isNotNull);
  });

  test('does not extrapolate outside the track', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.subtract(const Duration(minutes: 1)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
        LocationPoint(timestamp: start.add(const Duration(minutes: 10)), latitude: 49.0, longitude: 12.0),
      ],
      maxGap: const Duration(minutes: 15),
    );
    expect(result, isNull);
  });
}
