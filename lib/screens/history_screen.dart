import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/geotagged_asset.dart';
import '../services/database_service.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_location_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _settings = SettingsService();
  final _immich = ImmichService();
  final _thumbnailFutures = <String, Future<Uint8List>>{};

  AppSettings? _appSettings;

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

  ThumbnailLoader? get _thumbnailLoader =>
      _appSettings == null ? null : _thumbnail;

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
      body: FutureBuilder<List<GeotaggedAsset>>(
        future: DatabaseService.instance.updatedAssets(),
        builder: (context, snapshot) {
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

  Widget _assetCard(GeotaggedAsset item) {
    final l = context.l10n;
    final material = MaterialLocalizations.of(context);
    final local = item.captureTime.toLocal();
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoThumbnail(
              assetId: item.assetId,
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
                  const SizedBox(height: 5),
                  Text(
                    l.t('capturedAt', {'time': time}),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
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
                      assetId: item.assetId,
                      fileName: item.fileName,
                      latitude: item.latitude,
                      longitude: item.longitude,
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
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
