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
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(48.05, 0.000001));
    expect(result.longitude, closeTo(11.05, 0.000001));
  });

  test('does not interpolate across a gap larger than the limit', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 30)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 1)),
          latitude: 49.0,
          longitude: 12.0,
        ),
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
        LocationPoint(
          timestamp: start,
          latitude: 48.400000,
          longitude: 10.950000,
        ),
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
        maxGap: const Duration(minutes: 15),
      ),
      isNull,
    );
    expect(
      service.interpolate(
        timestamp: start.add(const Duration(minutes: 11)),
        points: points,
        maxGap: const Duration(minutes: 15),
      ),
      isNull,
    );
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
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNull);
  });

  test('allows a stationary gap exactly at 90 minutes within 100 meters', () {
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
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNotNull);
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
      timestamp: start.add(
        const Duration(minutes: 5, milliseconds: 1),
      ),
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

  test('allows high-speed interpolation between manual anchors', () {
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
          latitude: 35.55,
          longitude: 139.78,
          isManual: true,
        ),
      ],
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNotNull);
  });

  test('allows manual anchors exactly 12 hours apart', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(hours: 6)),
      points: [
        LocationPoint(
          timestamp: start,
          latitude: 48.35,
          longitude: 11.79,
          isManual: true,
        ),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 12)),
          latitude: 35.55,
          longitude: 139.78,
          isManual: true,
        ),
      ],
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNotNull);
  });

  test('rejects manual anchors beyond the 12-hour maximum gap', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(hours: 6)),
      points: [
        LocationPoint(
          timestamp: start,
          latitude: 48.35,
          longitude: 11.79,
          isManual: true,
        ),
        LocationPoint(
          timestamp: start.add(const Duration(hours: 13)),
          latitude: 35.55,
          longitude: 139.78,
          isManual: true,
        ),
      ],
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNull);
  });

  test('rejects implausibly fast automatic segments', () {
    final start = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: start.add(const Duration(minutes: 1)),
      points: [
        LocationPoint(timestamp: start, latitude: 48.0, longitude: 11.0),
        LocationPoint(
          timestamp: start.add(const Duration(minutes: 2)),
          latitude: 49.0,
          longitude: 12.0,
        ),
      ],
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNull);
  });

  test('rejects duplicate timestamps instead of dividing by zero', () {
    final instant = DateTime.utc(2026, 9, 19, 10, 0);
    final result = service.interpolate(
      timestamp: instant,
      points: [
        LocationPoint(timestamp: instant, latitude: 48.0, longitude: 11.0),
        LocationPoint(timestamp: instant, latitude: 48.1, longitude: 11.1),
      ],
      maxGap: const Duration(minutes: 15),
    );

    expect(result, isNull);
  });
}
