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
    final dateValue = exif?['dateTimeOriginal'] ??
        json['localDateTime'] ??
        json['fileCreatedAt'];

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
