import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immich_geotagger/services/immich_service.dart';
import 'package:immich_geotagger/services/settings_service.dart';
import 'package:immich_geotagger/services/thumbnail_cache.dart';

AppSettings settings(String url, String key) => AppSettings(
      immichUrl: url,
      apiKey: key,
      retentionDays: 14,
      trackingQuality: TrackingQuality.balanced,
    );

void main() {
  test('list and detail requests reuse a pending and completed thumbnail',
      () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      requests++;
      return response.future;
    });
    addTearDown(client.close);
    final cache = ThumbnailCache(
      settings('https://immich.example', 'key'),
      ImmichService(client: client),
    );

    final list = cache.load('photo');
    final detail = cache.load('photo');
    response.complete(http.Response.bytes([1, 2, 3], 200));
    expect(await list, [1, 2, 3]);
    expect(await detail, [1, 2, 3]);
    expect(await cache.load('photo'), [1, 2, 3]);
    expect(requests, 1);
  });

  test('different photos and connections never share cached thumbnails',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes([requests.length], 200);
    });
    addTearDown(client.close);
    final service = ImmichService(client: client);
    final first =
        ThumbnailCache(settings('https://one.example', 'one'), service);
    final second =
        ThumbnailCache(settings('https://two.example', 'two'), service);

    expect(await first.load('photo'), [1]);
    expect(await first.load('other'), [2]);
    expect(await second.load('photo'), [3]);
    expect(await first.load('photo'), [1]);
    expect(requests.map((request) => request.url.host),
        ['one.example', 'one.example', 'two.example']);
    expect(requests.map((request) => request.headers['x-api-key']),
        ['one', 'one', 'two']);
  });
}
