import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/immich_asset.dart';
import '../models/sync_preview.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/match_timeline.dart';
import '../widgets/photo_location_widgets.dart';

class SyncPreviewScreen extends StatefulWidget {
  const SyncPreviewScreen({
    required this.preview,
    super.key,
  });

  final SyncPreview preview;

  @override
  State<SyncPreviewScreen> createState() => _SyncPreviewScreenState();
}

class _SyncPreviewScreenState extends State<SyncPreviewScreen>
    with SingleTickerProviderStateMixin {
  static const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const _minMapZoom = 0.0;
  static const _maxMapZoom = 20.0;
  static const _clusterToleranceMeters = 20.0;

  final _settings = SettingsService();
  final _immich = ImmichService();
  final _sync = SyncService();
  final _thumbnailFutures = <String, Future<Uint8List>>{};

  late final Set<String> _selected = widget.preview.candidates
      .map((candidate) => candidate.asset.id)
      .toSet();

  AppSettings? _appSettings;
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
    setState(() => _appSettings = settings);
  }

  Future<Uint8List> _thumbnail(String assetId) {
    final settings = _appSettings!;
    return _thumbnailFutures.putIfAbsent(
      assetId,
      () => _immich.thumbnail(
        baseUrl: settings.immichUrl,
        apiKey: settings.apiKey,
        assetId: assetId,
      ),
    );
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
      final selected = widget.preview.candidates
          .where((candidate) => _selected.contains(candidate.asset.id));
      final result = await _sync.applySync(widget.preview, selected);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_immichErrorMessage(e)),
        ),
      );
    }
  }

  String _immichErrorMessage(Object error) {
    final l = context.l10n;
    if (error is ImmichConnectionException) {
      return switch (error.error) {
        ImmichConnectionError.unreachable => l.t('immichUnreachable'),
        ImmichConnectionError.timeout => l.t('immichTimeout'),
        ImmichConnectionError.server => l.t(
            'immichServerError',
            {'code': error.statusCode ?? 500},
          ),
      };
    }
    return error.toString().replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
        appBar: AppBar(
          title: Text(l.t('syncPreviewTitle')),
        ),
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
                      Tab(
                        height: 52,
                        child: _tabLabel(l.t('syncTabMap')),
                      ),
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
              border: Border(
                top: BorderSide(color: AppTheme.border),
              ),
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
                l.t(
                  'applySelectedLocations',
                  {'count': _selected.length},
                ),
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
    ].where(
      (asset) =>
          asset.type == ImmichAssetType.image &&
          !asset.hasExplicitTimeZone,
    ).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('syncOverview'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryNumber(
                widget.preview.scanned,
                l.t('syncFound'),
              ),
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
                      l.t(
                        'missingTimeZoneWarning',
                        {'count': imagesWithoutTimeZone},
                      ),
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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

    final allSelected =
        _selected.length == widget.preview.candidates.length;
    final candidates = [...widget.preview.candidates]
      ..sort((a, b) => b.asset.takenAt.compareTo(a.asset.takenAt));

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
                allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final candidate in candidates)
          _candidateCard(candidate),
      ],
    );
  }

  Widget _unmatchedTab() {
    if (widget.preview.unmatched.isEmpty) {
      return _emptyTab(context.l10n.t('noUnmatchedPhotos'));
    }

    final unmatched = [...widget.preview.unmatched]
      ..sort((a, b) => b.asset.takenAt.compareTo(a.asset.takenAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        for (final item in unmatched)
          _unmatchedPhotoCard(item),
      ],
    );
  }

  Widget _emptyTab(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _overviewMapCard() {
    final candidates = widget.preview.candidates;
    final center = _centerOf(candidates);
    final zoom = _zoomFor(candidates);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom.clamp(_minMapZoom, _maxMapZoom),
        initialCameraFit: candidates.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(
                  candidates
                      .map(
                        (candidate) => LatLng(
                          candidate.latitude,
                          candidate.longitude,
                        ),
                      )
                      .toList(),
                ),
                padding: const EdgeInsets.all(40),
                maxZoom: 16,
              )
            : null,
        minZoom: _minMapZoom,
        maxZoom: _maxMapZoom,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            const LatLng(-85.05112878, -180),
            const LatLng(85.05112878, 180),
          ),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const MapLibreLayer(
          initStyle: _mapStyle,
        ),
        MarkerLayer(
          markers: [
            for (final group in _groupCandidates(candidates))
              Marker(
                point: LatLng(
                  group.first.latitude,
                  group.first.longitude,
                ),
                width: group.length > 1 ? 52 : 42,
                height: group.length > 1 ? 52 : 42,
                child: GestureDetector(
                  onTap: () => _showCandidateGroup(group),
                  child: group.length == 1
                      ? _mapMarker(
                          selected: _selected.contains(
                            group.first.asset.id,
                          ),
                        )
                      : _groupMapMarker(group),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _candidateCard(SyncCandidate candidate) {
    final l = context.l10n;
    final selected = _selected.contains(candidate.asset.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumbnailView(candidate.asset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.asset.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  MatchTimeline(
                    photoTime: candidate.asset.takenAt,
                    before: candidate.before,
                    after: candidate.usedLastKnownLocation
                        ? null
                        : candidate.after,
                  ),
                  const SizedBox(height: 8),
                  _reliabilityChip(candidate.reliability),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _showCandidateGroup([candidate]),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(l.t('showOnMap')),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (value) {
                setState(() {
                  if (value ?? false) {
                    _selected.add(candidate.asset.id);
                  } else {
                    _selected.remove(candidate.asset.id);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

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
            if (_appSettings != null) ...[
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

  List<List<SyncCandidate>> _groupCandidates(
    List<SyncCandidate> candidates,
  ) {
    final groups = <List<SyncCandidate>>[];

    for (final candidate in candidates) {
      List<SyncCandidate>? matchingGroup;
      for (final group in groups) {
        if (_distanceMeters(
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

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radius = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _groupMapMarker(List<SyncCandidate> group) {
    final selected = group.where(
      (candidate) => _selected.contains(candidate.asset.id),
    ).length;

    return Container(
      decoration: BoxDecoration(
        color: selected > 0 ? AppTheme.primary : const Color(0xFF8A8A8A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x33000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${group.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

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
                            context.l10n.t(
                              'photosAtLocation',
                              {'count': group.length},
                            ),
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
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            initialCenter: LatLng(
                              active.latitude,
                              active.longitude,
                            ),
                            initialZoom: 17,
                            minZoom: _minMapZoom,
                            maxZoom: _maxMapZoom,
                            cameraConstraint: CameraConstraint.containCenter(
                              bounds: LatLngBounds(
                                const LatLng(-85.05112878, -180),
                                const LatLng(85.05112878, 180),
                              ),
                            ),
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all &
                                  ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            const MapLibreLayer(
                              initStyle: _mapStyle,
                            ),
                            MarkerLayer(
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
                                          _selected.contains(
                                            group[i].asset.id,
                                          ),
                                    ),
                                  ),
                              ],
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
                          LatLng(
                            candidate.latitude,
                            candidate.longitude,
                          ),
                          mapController.camera.zoom,
                        );
                      },
                      itemBuilder: (context, index) {
                        final candidate = group[index];
                        final selected =
                            _selected.contains(candidate.asset.id);

                        return AppSurface(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                              children: [
                                _thumbnailView(
                                  candidate.asset,
                                  size: 84,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        candidate.asset.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      MatchTimeline(
                                        photoTime: candidate.asset.takenAt,
                                        before: candidate.before,
                                        after: candidate.usedLastKnownLocation
                                            ? null
                                            : candidate.after,
                                      ),
                                      _reliabilityChip(
                                        candidate.reliability,
                                      ),
                                      if (group.length > 1) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          context.l10n.t(
                                            'photoPosition',
                                            {
                                              'current': index + 1,
                                              'total': group.length,
                                            },
                                          ),
                                          style: const TextStyle(
                                            color: AppTheme.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: selected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value ?? false) {
                                        _selected.add(candidate.asset.id);
                                      } else {
                                        _selected.remove(candidate.asset.id);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                ),
                              ],
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

  Widget _mapMarker({required bool selected}) {
    return PhotoLocationMarker(selected: selected);
  }

  LatLng _centerOf(List<SyncCandidate> candidates) {
    final latitude = candidates
            .map((candidate) => candidate.latitude)
            .reduce((a, b) => a + b) /
        candidates.length;
    final longitude = candidates
            .map((candidate) => candidate.longitude)
            .reduce((a, b) => a + b) /
        candidates.length;
    return LatLng(latitude, longitude);
  }

  double _zoomFor(List<SyncCandidate> candidates) {
    if (candidates.length <= 1) return 16;

    final latitudes = candidates.map((e) => e.latitude);
    final longitudes = candidates.map((e) => e.longitude);
    final latSpan = latitudes.reduce(math.max) - latitudes.reduce(math.min);
    final lonSpan = longitudes.reduce(math.max) - longitudes.reduce(math.min);
    final span = math.max(latSpan, lonSpan);

    if (span > 10) return 4;
    if (span > 5) return 5;
    if (span > 2) return 6;
    if (span > 1) return 7;
    if (span > 0.5) return 8;
    if (span > 0.2) return 9;
    if (span > 0.1) return 10;
    if (span > 0.05) return 11;
    if (span > 0.02) return 12;
    if (span > 0.01) return 13;
    if (span > 0.005) return 14;
    return 15;
  }

  ThumbnailLoader? get _thumbnailLoader =>
      _appSettings == null ? null : _thumbnail;

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
