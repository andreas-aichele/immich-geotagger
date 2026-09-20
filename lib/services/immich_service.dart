import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/immich_asset.dart';

class ImmichService {
  ImmichService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri _uri(String baseUrl, String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/api$path');
  }

  Map<String, String> _headers(String apiKey) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  Future<void> verifyConnection(String baseUrl, String apiKey) async {
    final response = await _client.get(_uri(baseUrl, '/server/ping'), headers: _headers(apiKey));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Immich returned HTTP ${response.statusCode}');
    }
  }

  Future<List<ImmichAsset>> assetsTakenBetween({
    required String baseUrl,
    required String apiKey,
    required DateTime from,
    required DateTime to,
  }) async {
    final assets = <ImmichAsset>[];
    var page = 1;
    while (true) {
      final response = await _client.post(
        _uri(baseUrl, '/search/metadata'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'takenAfter': from.toUtc().toIso8601String(),
          'takenBefore': to.toUtc().toIso8601String(),
          'type': 'IMAGE',
          'withExif': true,
          'page': page,
          'size': 500,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Immich search failed with HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final assetsNode = decoded['assets'] as Map<String, dynamic>? ?? decoded;
      final items = (assetsNode['items'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
      for (final item in items) {
        try {
          assets.add(ImmichAsset.fromJson(item));
        } on FormatException {
          // Ignore assets without a reliable timestamp.
        }
      }
      final nextPage = assetsNode['nextPage'];
      if (nextPage == null) break;
      page = nextPage is int ? nextPage : int.tryParse('$nextPage') ?? (page + 1);
    }
    return assets;
  }

  Future<void> updateLocation({
    required String baseUrl,
    required String apiKey,
    required String assetId,
    required double latitude,
    required double longitude,
  }) async {
    final body = jsonEncode({'latitude': latitude, 'longitude': longitude});
    var response = await _client.put(_uri(baseUrl, '/assets/$assetId'), headers: _headers(apiKey), body: body);
    if (response.statusCode == 404 || response.statusCode == 405) {
      response = await _client.patch(_uri(baseUrl, '/assets/$assetId'), headers: _headers(apiKey), body: body);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Updating asset $assetId failed with HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
