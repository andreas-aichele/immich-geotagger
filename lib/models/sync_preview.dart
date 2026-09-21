import 'immich_asset.dart';

enum MatchReliability {
  high,
  medium,
  low,
}

class SyncCandidate {
  const SyncCandidate({
    required this.asset,
    required this.latitude,
    required this.longitude,
    required this.before,
    required this.after,
    required this.reliability,
  });

  final ImmichAsset asset;
  final double latitude;
  final double longitude;
  final DateTime before;
  final DateTime after;
  final MatchReliability reliability;
}

class SyncPreview {
  const SyncPreview({
    required this.candidates,
    required this.scanned,
    required this.skippedWithLocation,
    required this.skippedWithoutTrack,
  });

  final List<SyncCandidate> candidates;
  final int scanned;
  final int skippedWithLocation;
  final int skippedWithoutTrack;
}
