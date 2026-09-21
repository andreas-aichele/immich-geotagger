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
    this.usedLastKnownLocation = false,
  });

  final ImmichAsset asset;
  final double latitude;
  final double longitude;
  final DateTime before;
  final DateTime after;
  final MatchReliability reliability;
  final bool usedLastKnownLocation;
}

enum UnmatchedReason {
  noTrackData,
  beforeTrack,
  afterTrack,
  unsafeGap,
  noSegment,
}

class SyncUnmatched {
  const SyncUnmatched({
    required this.asset,
    required this.reason,
    this.before,
    this.after,
  });

  final ImmichAsset asset;
  final UnmatchedReason reason;
  final DateTime? before;
  final DateTime? after;
}

class SyncPreview {
  const SyncPreview({
    required this.candidates,
    required this.scanned,
    required this.skippedWithLocation,
    required this.skippedWithoutTrack,
    this.unmatched = const [],
  });

  final List<SyncCandidate> candidates;
  final int scanned;
  final int skippedWithLocation;
  final int skippedWithoutTrack;
  final List<SyncUnmatched> unmatched;
}
