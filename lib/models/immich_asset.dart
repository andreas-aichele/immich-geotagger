class ImmichAsset {
  const ImmichAsset({
    required this.id,
    required this.fileName,
    required this.takenAt,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String fileName;
  final DateTime takenAt;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

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

    return ImmichAsset(
      id: json['id'] as String,
      fileName: (json['originalFileName'] as String?) ?? 'unknown',
      takenAt: DateTime.parse(dateValue as String).toUtc(),
      latitude: (exif?['latitude'] as num?)?.toDouble(),
      longitude: (exif?['longitude'] as num?)?.toDouble(),
    );
  }
}
