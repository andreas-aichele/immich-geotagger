import 'dart:typed_data';

import 'immich_service.dart';
import 'settings_service.dart';

class ThumbnailCache {
  ThumbnailCache(this.settings, this.immich);

  final AppSettings settings;
  final ImmichService immich;
  final _futures = <String, Future<Uint8List>>{};

  Future<Uint8List> load(String assetId) => _futures.putIfAbsent(
        assetId,
        () => immich.thumbnail(
          baseUrl: settings.immichUrl,
          apiKey: settings.apiKey,
          assetId: assetId,
        ),
      );
}
