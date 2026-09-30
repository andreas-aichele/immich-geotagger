class LocationPoint {
  const LocationPoint({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.isManual = false,
  });

  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final bool isManual;

  Map<String, Object?> toMap() => {
        'id': id,
        'timestamp_ms': timestamp.toUtc().millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'is_manual': isManual ? 1 : 0,
      };

  factory LocationPoint.fromMap(Map<String, Object?> map) => LocationPoint(
        id: map['id'] as int?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp_ms'] as int,
          isUtc: true,
        ),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num?)?.toDouble(),
        isManual: ((map['is_manual'] as num?)?.toInt() ?? 0) == 1,
      );
}
