class LocationPoint {
  const LocationPoint({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;

  Map<String, Object?> toMap() => {
        'id': id,
        'timestamp_ms': timestamp.toUtc().millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
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
      );
}
