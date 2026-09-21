import 'dart:typed_data';

import 'package:flutter/material.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('syncPreviewTitle')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: widget.preview.candidates.isEmpty
            ? 2
            : widget.preview.candidates.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
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
              ),
            );
          }

          if (widget.preview.candidates.isEmpty) {
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

          return _candidateCard(widget.preview.candidates[index - 1]);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (selected) {
              _selected.remove(candidate.asset.id);
            } else {
              _selected.add(candidate.asset.id);
            }
          });
        },
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
                      '${candidate.latitude.toStringAsFixed(5)}, '
                      '${candidate.longitude.toStringAsFixed(5)}',
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
      ),
    );
  }

  Widget _thumbnailView(String assetId) {
    if (_appSettings == null) {
      return _thumbnailPlaceholder(
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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
              width: 84,
              height: 84,
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
          );
        }

        return _thumbnailPlaceholder(
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _thumbnailPlaceholder(Widget child) {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
