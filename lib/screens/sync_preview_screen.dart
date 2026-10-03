import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/immich_asset.dart';
import '../models/sync_preview.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../services/thumbnail_cache.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo_distance.dart';
import '../widgets/location_map.dart';
import '../widgets/error_message.dart';
import '../widgets/match_timeline.dart';
import '../widgets/photo_location_widgets.dart';

class SyncPreviewScreen extends StatefulWidget {
  const SyncPreviewScreen({required this.preview, super.key});

  final SyncPreview preview;

  @override
  State<SyncPreviewScreen> createState() => _SyncPreviewScreenState();
}

class _SyncPreviewScreenState extends State<SyncPreviewScreen>
    with SingleTickerProviderStateMixin {
  static const _clusterToleranceMeters = 20.0;

  final _settings = SettingsService();
  final _immich = ImmichService();
  final _sync = SyncService();
  ThumbnailCache? _thumbnails;

  late final Set<String> _selected =
      widget.preview.candidates.map((candidate) => candidate.asset.id).toSet();

  late final _candidates = [...widget.preview.candidates]
    ..sort((a, b) => b.asset.takenAt.compareTo(a.asset.takenAt));
  late final _unmatched = [...widget.preview.unmatched]
    ..sort((a, b) => b.asset.takenAt.compareTo(a.asset.takenAt));
  late final _groups = _groupCandidates(widget.preview.candidates);
  bool _applying = false;
  late final TabController _tabController;
  bool _mapActivated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, initialIndex: 1, vsync: this)
      ..addListener(_handleTabChange);
    _loadSettings();
  }

  void _handleTabChange() {
    if (!_mapActivated && _tabController.index == 0) {
      setState(() => _mapActivated = true);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settings.load();
    if (!mounted) return;
    setState(() => _thumbnails = ThumbnailCache(settings, _immich));
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(widget.preview.candidates.map((e) => e.asset.id));
    });
  }

  void _selectNone() {
    setState(_selected.clear);
  }

  Future<void> _apply() async {
    if (_selected.isEmpty || _applying) return;

    setState(() => _applying = true);
    try {
      final selected = widget.preview.candidates.where(
        (candidate) => _selected.contains(candidate.asset.id),
      );
      final result = await _sync.applySync(widget.preview, selected);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(immichErrorMessage(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('syncPreviewTitle'))),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _summaryCard(),
                ),
                TabBar(
                  controller: _tabController,
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(height: 52, child: _tabLabel(l.t('syncTabMap'))),
                    Tab(
                      height: 52,
                      child: _tabLabel(
                        l.t('syncAssignable'),
                        count: widget.preview.candidates.length,
                      ),
                    ),
                    Tab(
                      height: 52,
                      child: _tabLabel(
                        l.t('syncUnmatched'),
                        count: widget.preview.unmatched.length,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _mapActivated ? _mapTab() : const SizedBox.expand(),
                _assignableTab(),
                _unmatchedTab(),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _applying ? null : _apply,
            icon: _applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.location_on_outlined),
            label: Text(
              l.t('applySelectedLocations', {'count': _selected.length}),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final l = context.l10n;
    final imagesWithoutTimeZone = [
      ...widget.preview.candidates.map((item) => item.asset),
      ...widget.preview.unmatched.map((item) => item.asset),
    ]
        .where(
          (asset) =>
              asset.type == ImmichAssetType.image && !asset.hasExplicitTimeZone,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('syncOverview'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryNumber(widget.preview.scanned, l.t('syncFound')),
              _summaryNumber(
                widget.preview.candidates.length,
                l.t('syncAssignable'),
              ),
              _summaryNumber(
                widget.preview.unmatched.length,
                l.t('syncUnmatched'),
              ),
              _summaryNumber(
                widget.preview.skippedWithLocation,
                l.t('syncAlreadyLocated'),
              ),
            ],
          ),
          if (imagesWithoutTimeZone > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6DD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6C96A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF8A6200),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.t('missingTimeZoneWarning', {
                        'count': imagesWithoutTimeZone,
                      }),
                      style: const TextStyle(
                        color: Color(0xFF6F5200),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryNumber(int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabLabel(String label, {int? count}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        if (count != null) ...[
          const SizedBox(height: 2),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _mapTab() {
    if (widget.preview.candidates.isEmpty) {
      return _emptyTab(context.l10n.t('noSyncCandidates'));
    }
    return _overviewMapCard();
  }

  Widget _assignableTab() {
    final l = context.l10n;
    if (widget.preview.candidates.isEmpty) {
      return _emptyTab(l.t('noSyncCandidates'));
    }

    final allSelected = _selected.length == widget.preview.candidates.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          children: [
            Text(
              l.t('selectedCount', {'count': _selected.length}),
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: allSelected ? l.t('selectNone') : l.t('selectAll'),
              onPressed: allSelected ? _selectNone : _selectAll,
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final candidate in _candidates) _candidateCard(candidate),
      ],
    );
  }

  Widget _unmatchedTab() {
    if (widget.preview.unmatched.isEmpty) {
      return _emptyTab(context.l10n.t('noUnmatchedPhotos'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [for (final item in _unmatched) _unmatchedPhotoCard(item)],
    );
  }

  Widget _emptyTab(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted, height: 1.4),
        ),
      ),
    );
  }

  Widget _overviewMapCard() {
    final candidates = widget.preview.candidates;
    return LocationMap(
      center: LatLng(candidates.first.latitude, candidates.first.longitude),
      cameraFit: candidates.length > 1
          ? CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(
                candidates
                    .map(
                      (candidate) =>
                          LatLng(candidate.latitude, candidate.longitude),
                    )
                    .toList(),
              ),
              padding: const EdgeInsets.all(40),
              maxZoom: 16,
            )
          : null,
      markers: [
        for (final group in _groups)
          Marker(
            point: LatLng(group.first.latitude, group.first.longitude),
            width: group.length > 1 ? 52 : 42,
            height: group.length > 1 ? 52 : 42,
            child: GestureDetector(
              onTap: () => _showCandidateGroup(group),
              child: group.length == 1
                  ? PhotoLocationMarker(
                      selected: _selected.contains(group.first.asset.id),
                    )
                  : _groupMapMarker(group),
            ),
          ),
      ],
    );
  }

  Widget _candidateCard(SyncCandidate candidate) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: _candidateContent(
          candidate,
          footer: TextButton.icon(
            onPressed: () => _showCandidateGroup([candidate]),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(l.t('showOnMap')),
          ),
        ),
      ),
    );
  }

  Widget _candidateContent(
    SyncCandidate candidate, {
    bool detail = false,
    Widget? footer,
    VoidCallback? onSelectionChanged,
  }) =>
      Row(
        crossAxisAlignment:
            detail ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _thumbnailView(candidate.asset),
              Positioned(
                top: 0,
                right: 0,
                child: Checkbox(
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                  checkColor: Colors.white,
                  fillColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppTheme.primary
                          : Colors.white),
                  value: _selected.contains(candidate.asset.id),
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        _selected.add(candidate.asset.id);
                      } else {
                        _selected.remove(candidate.asset.id);
                      }
                    });
                    onSelectionChanged?.call();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  detail ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Text(
                  candidate.asset.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                MatchTimeline(
                  photoTime: candidate.asset.takenAt,
                  before: candidate.before,
                  after:
                      candidate.usedLastKnownLocation ? null : candidate.after,
                ),
                if (!detail) const SizedBox(height: 8),
                _reliabilityChip(candidate.reliability),
                if (footer != null) ...[
                  SizedBox(height: detail ? 6 : 4),
                  footer
                ],
              ],
            ),
          ),
        ],
      );

  Widget _unmatchedPhotoCard(SyncUnmatched item) {
    final l = context.l10n;

    String reason() {
      return switch (item.reason) {
        UnmatchedReason.noTrackData => l.t('unmatchedNoTrackData'),
        UnmatchedReason.beforeTrack => l.t('unmatchedBeforeTrack'),
        UnmatchedReason.afterTrack => l.t('unmatchedAfterTrack'),
        UnmatchedReason.unsafeGap => l.t('unmatchedUnsafeGap'),
        UnmatchedReason.noSegment => l.t('unmatchedNoSegment'),
      };
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_thumbnails != null) ...[
              _thumbnailView(item.asset, size: 64),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.asset.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  MatchTimeline(
                    photoTime: item.asset.takenAt,
                    before: item.before,
                    after: item.after,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reason(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reliabilityChip(MatchReliability reliability) {
    final l = context.l10n;
    final (label, color, background) = switch (reliability) {
      MatchReliability.high => (
          l.t('reliabilityHigh'),
          const Color(0xFF157A4A),
          const Color(0xFFEAF7F0),
        ),
      MatchReliability.medium => (
          l.t('reliabilityMedium'),
          const Color(0xFF9A6700),
          const Color(0xFFFFF6DD),
        ),
      MatchReliability.low => (
          l.t('reliabilityLow'),
          const Color(0xFFA13A2E),
          const Color(0xFFFFECE9),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        l.t('reliabilityLabel', {'value': label}),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<List<SyncCandidate>> _groupCandidates(List<SyncCandidate> candidates) {
    final groups = <List<SyncCandidate>>[];

    for (final candidate in candidates) {
      List<SyncCandidate>? matchingGroup;
      for (final group in groups) {
        if (distanceMeters(
              candidate.latitude,
              candidate.longitude,
              group.first.latitude,
              group.first.longitude,
            ) <=
            _clusterToleranceMeters) {
          matchingGroup = group;
          break;
        }
      }

      if (matchingGroup == null) {
        groups.add([candidate]);
      } else {
        matchingGroup.add(candidate);
      }
    }

    return groups;
  }

  Widget _groupMapMarker(List<SyncCandidate> group) => PhotoLocationMarker(
        selected: group.any((item) => _selected.contains(item.asset.id)),
        count: group.length,
      );

  Future<void> _showCandidateGroup(List<SyncCandidate> group) async {
    final pageController = PageController();
    final mapController = MapController();
    var activeIndex = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final active = group[activeIndex];

            return FractionallySizedBox(
              heightFactor: 0.84,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.t('photosAtLocation', {
                              'count': group.length,
                            }),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: LocationMap(
                          controller: mapController,
                          center: LatLng(active.latitude, active.longitude),
                          zoom: 17,
                          markers: [
                            for (var i = 0; i < group.length; i++)
                              Marker(
                                point: LatLng(
                                  group[i].latitude,
                                  group[i].longitude,
                                ),
                                width: i == activeIndex ? 48 : 38,
                                height: i == activeIndex ? 48 : 38,
                                child: PhotoLocationMarker(
                                  selected: i == activeIndex ||
                                      _selected.contains(group[i].asset.id),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: group.length,
                        onPageChanged: (index) {
                          setSheetState(() => activeIndex = index);
                          final candidate = group[index];
                          mapController.move(
                            LatLng(candidate.latitude, candidate.longitude),
                            mapController.camera.zoom,
                          );
                        },
                        itemBuilder: (context, index) {
                          final candidate = group[index];
                          return AppSurface(
                            padding: const EdgeInsets.all(10),
                            child: _candidateContent(
                              candidate,
                              detail: true,
                              onSelectionChanged: () => setSheetState(() {}),
                              footer: group.length > 1
                                  ? Text(
                                      context.l10n.t('photoPosition', {
                                        'current': index + 1,
                                        'total': group.length,
                                      }),
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        );
      },
    );

    pageController.dispose();
  }

  ThumbnailLoader? get _thumbnailLoader => _thumbnails?.load;

  Widget _thumbnailView(ImmichAsset asset, {double size = 84}) {
    return PhotoThumbnail(
      assetId: asset.id,
      loader: _thumbnailLoader,
      size: size,
      isVideo: asset.isVideo,
      duration: asset.duration,
    );
  }
}
