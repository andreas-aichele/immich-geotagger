import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/models/location_point.dart';
import 'package:immich_geotagger/services/interpolation_service.dart';

void main() {
  const service = InterpolationService();

  test('linearly interpolates a point between two measurements', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 10)),
        latitude: 48.1,
        longitude: 11.1,
      ),
    ];

    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 5)),
      points: points,
    );

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(48.05, 0.000001));
    expect(result.longitude, closeTo(11.05, 0.000001));
  });

  test('does not interpolate a moving gap larger than 15 minutes', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 10)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
        LocationPoint(
          timestamp: start.add(const Duration(minutes: 16)),
          latitude: 48.1,
          longitude: 11.1,
        ),
      ],
    );

    expect(result, isNull);
  });

  test('allows a stationary gap up to 90 minutes within 100 meters', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 45)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.4, longitude: 10.95),
        LocationPoint(
          timestamp: start.add(const Duration(minutes: 90)),
          latitude: 48.4004,
          longitude: 10.9504,
        ),
      ],
    );

    expect(result, isNotNull);
  });

  test('rejects a stationary-looking gap beyond 90 minutes', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(hours: 1)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.4, longitude: 10.95),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 2)),
          latitude: 48.4001,
          longitude: 10.9501,
        ),
      ],
    );

    expect(result, isNull);
  });

  test('manual points use the same 15-minute interpolation rules', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(hours: 1)),
      points: [
        LocationPoint(
          timestamp: start,
          latitude: 48.35,
          longitude: 11.79,
          isManual: true,
        ),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 2)),
          latitude: 53.55,
          longitude: 9.99,
          isManual: true,
        ),
      ],
    );

    expect(result, isNull);
  });

  test('allows sustained high-speed travel when points form a consistent route', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.3538, longitude: 11.7861),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 5)),
        latitude: 49.2,
        longitude: 11.7,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 10)),
        latitude: 50.0,
        longitude: 11.6,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 15)),
        latitude: 50.8,
        longitude: 11.5,
      ),
    ];

    final filtered = service.withoutIsolatedOutliers(points);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 7)),
      points: filtered,
    );

    expect(filtered, hasLength(4));
    expect(result, isNotNull);
    expect(
      service.averageSpeedKmh(
        service.distanceMeters(points[1], points[2]),
        const Duration(minutes: 5),
      ),
      greaterThan(300),
    );
  });

  test('removes an obvious single-point GPS excursion', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.1372, longitude: 11.5756),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 2)),
        latitude: 48.1373,
        longitude: 11.5757,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 4)),
        latitude: 53.5511,
        longitude: 9.9937,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 6)),
        latitude: 48.1374,
        longitude: 11.5758,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 8)),
        latitude: 48.1375,
        longitude: 11.5759,
      ),
    ];

    final filtered = service.withoutIsolatedOutliers(points);

    expect(filtered, hasLength(4));
    expect(filtered.any((point) => point.latitude > 53), isFalse);
  });

  test('uses the cleaned track for interpolation across a removed spike', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.1372, longitude: 11.5756),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 2)),
        latitude: 48.1373,
        longitude: 11.5757,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 4)),
        latitude: 53.5511,
        longitude: 9.9937,
      ),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 6)),
        latitude: 48.1374,
        longitude: 11.5758,
      ),
    ];

    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 4)),
      points: service.withoutIsolatedOutliers(points),
    );

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(48.13735, 0.00001));
  });

  test('uses a GPS point exactly five minutes away as nearest fallback', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final point = LocationPoint(
      timestamp: start,
      latitude: 48.4,
      longitude: 10.95,
    );

    final result = service.nearestPoint(
      timestamp: start.add(const Duration(minutes: 5)),
      points: [point],
    );

    expect(result, same(point));
  });

  test('does not use a GPS point beyond the five-minute fallback window', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final point = LocationPoint(
      timestamp: start,
      latitude: 48.4,
      longitude: 10.95,
    );

    final result = service.nearestPoint(
      timestamp: start.add(const Duration(minutes: 5, milliseconds: 1)),
      points: [point],
    );

    expect(result, isNull);
  });

  test('chooses the closest point within the fallback window', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final older = LocationPoint(
      timestamp: start,
      latitude: 48.4,
      longitude: 10.95,
    );
    final closer = LocationPoint(
      timestamp: start.add(const Duration(minutes: 3)),
      latitude: 48.5,
      longitude: 11.0,
    );

    final result = service.nearestPoint(
      timestamp: start.add(const Duration(minutes: 4)),
      points: [older, closer],
    );

    expect(result, same(closer));
  });

  test('does not extrapolate outside the track', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final points = [
      LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
      LocationPoint(
        timestamp: start.add(const Duration(minutes: 10)),
        latitude: 49.0,
        longitude: 12.0,
      ),
    ];

    expect(
      service.interpolate(
        timestamp: start.subtract(const Duration(minutes: 1)),
        points: points,
      ),
      isNull,
    );
    expect(
      service.interpolate(
        timestamp: start.add(const Duration(minutes: 11)),
        points: points,
      ),
      isNull,
    );
  });

  test('rejects duplicate timestamps instead of dividing by zero', () {
    final instant = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: instant,
      points: [
        LocationPoint(timestamp: instant, latitude: 48.0, longitude: 11.0),
        LocationPoint(timestamp: instant, latitude: 48.1, longitude: 11.1),
      ],
    );

    expect(result, isNull);
  });
}
