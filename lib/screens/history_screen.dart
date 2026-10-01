import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/immich_asset.dart';
import '../services/database_service.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_location_widgets.dart';
import '../widgets/match_timeline.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _settings = SettingsService();
  final _immich = ImmichService();
  final _thumbnailFutures = <String, Future<Uint8List>>{};
  final _timelineFutures = <String, Future<(DateTime?, DateTime?)>>{};

  AppSettings? _appSettings;
  late final Future<List<ImmichAsset>> _history;

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<List<ImmichAsset>> _loadHistory() async {
    final settings = await _settings.load();
    _appSettings = settings;
    final records = await DatabaseService.instance.updatedAssets(
      retention: Duration(days: settings.retentionDays),
    );
    final assets = <ImmichAsset>[];
    // Limit concurrent requests when a long history is opened.
    for (var start = 0; start < records.length; start += 8) {
      final end = (start + 8).clamp(0, records.length);
      final batch = await Future.wait(records.sublist(start, end).map(
            (record) => _immich.assetById(
              baseUrl: settings.immichUrl,
              apiKey: settings.apiKey,
              assetId: record.assetId,
            ),
          ));
      assets.addAll(batch.whereType<ImmichAsset>().where((asset) => asset.hasLocation));
    }
    return assets;
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

  ThumbnailLoader? get _thumbnailLoader =>
      _appSettings == null ? null : _thumbnail;

  Future<(DateTime?, DateTime?)> _timelineTimes(ImmichAsset item) {
    return _timelineFutures.putIfAbsent(
      item.id,
      () => DatabaseService.instance.locationTimesAround(item.takenAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('updatedPhotos'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<ImmichAsset>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l.t('historyLoadFailed')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(child: Text(l.t('noPhotosUpdated')));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, index) => _assetCard(items[index]),
          );
        },
      ),
    );
  }

  Widget _assetCard(ImmichAsset item) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoThumbnail(
              assetId: item.id,
              loader: _thumbnailLoader,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _matchTimeline(item),
                  const SizedBox(height: 3),
                  if (item.hasLocation) ...[
                    Text(
                      l.t('locationAlreadyApplied'),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => showPhotoLocationSheet(
                        context,
                        assetId: item.id,
                        fileName: item.fileName,
                        latitude: item.latitude!,
                        longitude: item.longitude!,
                        subtitle: l.t('appliedLocation'),
                        thumbnailLoader: _thumbnailLoader,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(l.t('showOnMap')),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF157A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchTimeline(ImmichAsset item) {
    return FutureBuilder<(DateTime?, DateTime?)>(
      future: _timelineTimes(item),
      builder: (context, snapshot) {
        final times = snapshot.data;
        return MatchTimeline(
          photoTime: item.takenAt,
          before: times?.$1,
          after: times?.$2,
        );
      },
    );
  }
}
