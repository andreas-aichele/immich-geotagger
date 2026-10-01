class GeotaggedAsset {
  const GeotaggedAsset({required this.assetId, required this.updatedAt});

  final String assetId;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'asset_id': assetId,
        'updated_at_ms': updatedAt.toUtc().millisecondsSinceEpoch,
      };

  factory GeotaggedAsset.fromMap(Map<String, Object?> map) => GeotaggedAsset(
        assetId: map['asset_id'] as String,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['updated_at_ms'] as int,
          isUtc: true,
        ),
      );
}
