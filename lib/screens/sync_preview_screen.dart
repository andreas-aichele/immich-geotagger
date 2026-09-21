import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
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
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'io.github.andreasaichele.immichgeotagger';
  static const _minMapZoom = 2.0;

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [_overviewMapCard()],
    );
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
    final l = context.l10n;
    final candidates = widget.preview.candidates;
    final center = _centerOf(candidates);
    final zoom = _zoomFor(candidates);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('mapOverview'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t('mapOverviewHint'),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                _tileLayer(),
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
                          onTap: () => group.length == 1
                              ? _showCandidateMap(group.first)
                              : _showCandidateGroup(group),
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
                _attribution(),
              ],
            ),
          ),
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
            _thumbnailView(candidate.asset.id),
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
                    onPressed: () => _showCandidateMap(candidate),
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
              _thumbnailView(item.asset.id, size: 64),
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
    const precision = 100000.0;
    final groups = <String, List<SyncCandidate>>{};

    for (final candidate in candidates) {
      final lat = (candidate.latitude * precision).round();
      final lon = (candidate.longitude * precision).round();
      final key = '${lat}:${lon}';
      groups.putIfAbsent(key, () => []).add(candidate);
    }
    return groups.values.toList();
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
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              context.l10n.t(
                'photosAtLocation',
                {'count': group.length},
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final candidate in group)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _thumbnailView(candidate.asset.id, size: 52),
                title: Text(
                  candidate.asset.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showCandidateMap(candidate);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCandidateMap(SyncCandidate candidate) {
    return showPhotoLocationSheet(
      context,
      assetId: candidate.asset.id,
      fileName: candidate.asset.fileName,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      subtitle: context.l10n.t('proposedLocation'),
      thumbnailLoader: _thumbnailLoader,
    );
  }

  TileLayer _tileLayer() {
    return TileLayer(
      urlTemplate: _tileUrl,
      userAgentPackageName: _userAgent,
      maxNativeZoom: 19,
    );
  }

  Widget _attribution() {
    return const Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: Color(0xCCFFFFFF),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
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

  Widget _thumbnailView(String assetId, {double size = 84}) {
    return PhotoThumbnail(
      assetId: assetId,
      loader: _thumbnailLoader,
      size: size,
    );
  }
}
