enum ImmichAssetType {
  image,
  video,
}

class ImmichAsset {
  const ImmichAsset({
    required this.id,
    required this.fileName,
    required this.takenAt,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.duration,
  });

  final String id;
  final String fileName;
  final DateTime takenAt;
  final double? latitude;
  final double? longitude;
  final ImmichAssetType type;
  final Duration? duration;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isVideo => type == ImmichAssetType.video;

  factory ImmichAsset.fromJson(Map<String, dynamic> json) {
    final exif = json['exifInfo'] as Map<String, dynamic>?;

    // fileCreatedAt is Immich's absolute capture timestamp and is the same time
    // axis used by metadata search. localDateTime is a wall-clock value and
    // must not be compared directly with UTC GPS timestamps.
    final dateValue = json['fileCreatedAt'] ??
        exif?['dateTimeOriginal'] ??
        json['localDateTime'];

    if (dateValue == null) {
      throw const FormatException('Asset has no usable capture timestamp');
    }

    final typeValue = (json['type'] as String? ?? 'IMAGE').toUpperCase();

    return ImmichAsset(
      id: json['id'] as String,
      fileName: (json['originalFileName'] as String?) ?? 'unknown',
      takenAt: DateTime.parse(dateValue as String).toUtc(),
      latitude: (exif?['latitude'] as num?)?.toDouble(),
      longitude: (exif?['longitude'] as num?)?.toDouble(),
      type: typeValue == 'VIDEO'
          ? ImmichAssetType.video
          : ImmichAssetType.image,
      duration: _parseDuration(json['duration'] as String?),
    );
  }

  static Duration? _parseDuration(String? value) {
    if (value == null || value.isEmpty) return null;

    final parts = value.split(':');
    if (parts.length != 3) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;

    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }
}
