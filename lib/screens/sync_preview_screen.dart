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
    final hasCandidates = widget.preview.candidates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('syncPreviewTitle')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: hasCandidates ? widget.preview.candidates.length + 2 : 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _summaryCard(),
            );
          }

          if (!hasCandidates) {
            return AppSurface(
              child: Text(
                l.t('noSyncCandidates'),
                style: const TextStyle(
                  color: AppTheme.muted,
                  height: 1.4,
                ),
              ),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _overviewMapCard(),
            );
          }

          return _candidateCard(widget.preview.candidates[index - 2]);
        },
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

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionEyebrow(l.t('syncPreview')),
          const SizedBox(height: 8),
          Text(
            l.t(
              'syncPreviewSummary',
              {
                'ready': widget.preview.candidates.length,
                'located': widget.preview.skippedWithLocation,
                'unmatched': widget.preview.skippedWithoutTrack,
              },
            ),
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: _selectAll,
                child: Text(l.t('selectAll')),
              ),
              TextButton(
                onPressed: _selectNone,
                child: Text(l.t('selectNone')),
              ),
              const Spacer(),
              Text(
                l.t(
                  'selectedCount',
                  {'count': _selected.length},
                ),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMapCard() {
    final l = context.l10n;
    final candidates = widget.preview.candidates;
    final center = _centerOf(candidates);
    final zoom = _zoomFor(candidates);

    return AppSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
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
              height: 270,
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
                      for (final candidate in candidates)
                        Marker(
                          point: LatLng(
                            candidate.latitude,
                            candidate.longitude,
                          ),
                          width: 42,
                          height: 42,
                          child: GestureDetector(
                            onTap: () => _showCandidateMap(candidate),
                            child: _mapMarker(
                              selected:
                                  _selected.contains(candidate.asset.id),
                            ),
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
      ),
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
                    l.t(
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

  Future<void> _showCandidateMap(SyncCandidate candidate) async {
    final l = context.l10n;
    final point = LatLng(candidate.latitude, candidate.longitude);
    final selected = _selected.contains(candidate.asset.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_appSettings != null) ...[
                      _thumbnailView(candidate.asset.id, size: 58),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.asset.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.t('proposedLocation'),
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
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
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        _tileLayer(),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 48,
                              height: 48,
                              child: _mapMarker(selected: selected),
                            ),
                          ],
                        ),
                        _attribution(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${candidate.latitude.toStringAsFixed(6)}, '
                  '${candidate.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : const Color(0xFF8A8A8A),
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
      child: const Icon(
        Icons.photo_camera_outlined,
        color: Colors.white,
        size: 20,
      ),
    );
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

  Widget _thumbnailView(String assetId, {double size = 84}) {
    if (_appSettings == null) {
      return _thumbnailPlaceholder(
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        size: size,
      );
    }

    return FutureBuilder<Uint8List>(
      future: _thumbnail(assetId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        }

        if (snapshot.hasError) {
          return _thumbnailPlaceholder(
            const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.muted,
            ),
            size: size,
          );
        }

        return _thumbnailPlaceholder(
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          size: size,
        );
      },
    );
  }

  Widget _thumbnailPlaceholder(Widget child, {double size = 84}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
