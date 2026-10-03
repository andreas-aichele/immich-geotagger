import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/models/immich_asset.dart';

void main() {
  test('recognizes only complete motion photo cover filename segments', () {
    const cases = {
      'PXL_XXXXX.RAW-01.MP.COVER.jpg': true,
      'PXL_XXXXX.MP.COVER': true,
      'pxl_xxxxx.raw-01.mp.cover.jpeg': true,
      'PXL_XXXXX.RAW-01.dng': false,
      'PXL_XXXXX.MP.jpg': false,
      'PXL_XXXXX.MP.mp4': false,
      'cover.jpg': false,
      'holiday.COVER.jpg': false,
      'PXL_XXXXX.MP.COVERAGE.jpg': false,
    };
    for (final entry in cases.entries) {
      final asset = ImmichAsset.fromJson({
        'id': 'asset-1',
        'originalFileName': entry.key,
        'fileCreatedAt': '2026-09-30T12:00:00Z',
      });
      expect(asset.isMotionPhotoCover, entry.value, reason: entry.key);
    }
  });

  group('ImmichAsset.fromJson', () {
    test('prefers absolute fileCreatedAt and converts it to UTC', () {
      final asset = ImmichAsset.fromJson({
        'id': 'asset-1',
        'originalFileName': 'photo.jpg',
        'type': 'IMAGE',
        'fileCreatedAt': '2026-09-30T12:34:56+02:00',
        'localDateTime': '2026-09-30T12:34:56',
        'exifInfo': {
          'timeZone': 'Europe/Berlin',
          'latitude': 48.1,
          'longitude': 11.5,
        },
      });

      expect(asset.takenAt, DateTime.utc(2026, 9, 30, 10, 34, 56));
      expect(asset.hasExplicitTimeZone, isTrue);
      expect(asset.hasLocation, isTrue);
      expect(asset.type, ImmichAssetType.image);
    });

    test('marks images without EXIF timezone as lacking explicit timezone', () {
      final asset = ImmichAsset.fromJson({
        'id': 'asset-2',
        'originalFileName': 'photo.jpg',
        'type': 'IMAGE',
        'fileCreatedAt': '2026-09-30T10:34:56Z',
        'exifInfo': {
          'timeZone': '   ',
        },
      });

      expect(asset.hasExplicitTimeZone, isFalse);
    });

    test('parses video type and millisecond duration', () {
      final asset = ImmichAsset.fromJson({
        'id': 'video-1',
        'originalFileName': 'clip.mp4',
        'type': 'VIDEO',
        'fileCreatedAt': '2026-09-30T10:34:56Z',
        'duration': 12500,
      });

      expect(asset.isVideo, isTrue);
      expect(asset.duration, const Duration(milliseconds: 12500));
    });

    test('parses legacy HH:MM:SS duration', () {
      final asset = ImmichAsset.fromJson({
        'id': 'video-2',
        'type': 'VIDEO',
        'fileCreatedAt': '2026-09-30T10:34:56Z',
        'duration': '01:02:03.500',
      });

      expect(
        asset.duration,
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500),
      );
    });

    test('rejects assets without a usable capture timestamp', () {
      expect(
        () => ImmichAsset.fromJson({'id': 'broken'}),
        throwsFormatException,
      );
    });
  });
}
