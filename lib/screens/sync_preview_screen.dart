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

class _SyncPreviewScreenState extends State<SyncPreviewScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
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
                children: [
                  _mapTab(),
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
      ),
    );
  }

  Widget _summaryCard() {
    final l = context.l10n;

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
        for (final candidate in widget.preview.candidates)
          _candidateCard(candidate),
      ],
    );
  }

  Widget _unmatchedTab() {
    if (widget.preview.unmatched.isEmpty) {
      return _emptyTab(context.l10n.t('noUnmatchedPhotos'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        for (final item in widget.preview.unmatched)
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
    final localTime = candidate.asset.takenAt.toLocal();
    final before = candidate.before.toLocal();
    final after = candidate.after.toLocal();
    final material = MaterialLocalizations.of(context);

    String time(DateTime value) => material.formatTimeOfDay(
          TimeOfDay.fromDateTime(value),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );

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
                  const SizedBox(height: 5),
                  Text(
                    l.t(
                      'capturedAt',
                      {'time': time(localTime)},
                    ),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    candidate.usedLastKnownLocation
                        ? l.t(
                            'usingLastKnownLocation',
                            {'time': time(before)},
                          )
                        : l.t(
                            'interpolatedBetween',
                            {
                              'before': time(before),
                              'after': time(after),
                            },
                          ),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                    ),
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

    final deviation = _relativeDeviation(item);

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
                  Text(
                    _formatPhotoDate(item.asset.takenAt),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (deviation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.t(
                        'unmatchedDeviation',
                        {'value': deviation},
                      ),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

  String _formatPhotoDate(DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return context.l10n.t(
      'unmatchedPhotoDateTime',
      {'date': date, 'time': time},
    );
  }

  String? _relativeDeviation(SyncUnmatched item) {
    final photo = item.asset.takenAt.toUtc();
    final references = <DateTime>[
      if (item.before != null) item.before!.toUtc(),
      if (item.after != null) item.after!.toUtc(),
    ];
    if (references.isEmpty) return null;

    var difference = references.first.difference(photo).abs();
    for (final reference in references.skip(1)) {
      final candidate = reference.difference(photo).abs();
      if (candidate < difference) difference = candidate;
    }

    final l = context.l10n;
    if (difference.inDays >= 1) {
      final days = difference.inHours / 24;
      final rounded = days >= 10 ? days.round().toString() : days.toStringAsFixed(1);
      return l.t('durationDays', {'count': rounded});
    }
    if (difference.inHours >= 1) {
      final hours = difference.inMinutes / 60;
      final rounded =
          hours >= 10 ? hours.round().toString() : hours.toStringAsFixed(1);
      return l.t('durationHours', {'count': rounded});
    }
    if (difference.inMinutes >= 1) {
      return l.t(
        'durationMinutes',
        {'count': math.max(1, difference.inMinutes)},
      );
    }
    return l.t('durationLessThanMinute');
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
    final pageController = PageController(viewportFraction: 0.9);
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
                    height: 150,
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

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: AppSurface(
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
                                      const SizedBox(height: 6),
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
                          ),
                        );
                      },
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
