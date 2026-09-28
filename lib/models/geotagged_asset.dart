class GeotaggedAsset {
  const GeotaggedAsset({
    this.id,
    required this.assetId,
    required this.fileName,
    required this.captureTime,
    this.trackBeforeTime,
    this.trackAfterTime,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final int? id;
  final String assetId;
  final String fileName;
  final DateTime captureTime;
  final DateTime? trackBeforeTime;
  final DateTime? trackAfterTime;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'asset_id': assetId,
        'file_name': fileName,
        'capture_time_ms': captureTime.toUtc().millisecondsSinceEpoch,
        'track_before_ms': trackBeforeTime?.toUtc().millisecondsSinceEpoch,
        'track_after_ms': trackAfterTime?.toUtc().millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at_ms': updatedAt.toUtc().millisecondsSinceEpoch,
      };

  factory GeotaggedAsset.fromMap(Map<String, Object?> map) => GeotaggedAsset(
        id: map['id'] as int?,
        assetId: map['asset_id'] as String,
        fileName: map['file_name'] as String,
        captureTime: DateTime.fromMillisecondsSinceEpoch(
          map['capture_time_ms'] as int,
          isUtc: true,
        ),
        trackBeforeTime: map['track_before_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                map['track_before_ms'] as int,
                isUtc: true,
              ),
        trackAfterTime: map['track_after_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                map['track_after_ms'] as int,
                isUtc: true,
              ),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['updated_at_ms'] as int,
          isUtc: true,
        ),
      );
}
