import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immich_geotagger/services/immich_service.dart';

void main() {
  group('ImmichService.assetById', () {
    test('loads current metadata for a saved asset ID', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/assets/asset-1');
        expect(request.headers['x-api-key'], 'secret');
        return http.Response(
            jsonEncode({
              'id': 'asset-1',
              'originalFileName': 'current.jpg',
              'fileCreatedAt': '2026-09-30T12:00:00Z',
              'exifInfo': {'latitude': 48.1, 'longitude': 11.5},
            }),
            200);
      });

      final asset = await ImmichService(client: client).assetById(
        baseUrl: 'https://immich.example',
        apiKey: 'secret',
        assetId: 'asset-1',
      );

      expect(asset?.fileName, 'current.jpg');
      expect(asset?.latitude, 48.1);
    });

    test('omits deleted and trashed assets', () async {
      for (final statusCode in [404, 410]) {
        final client = MockClient((_) async => http.Response('', statusCode));
        expect(
          await ImmichService(client: client).assetById(
            baseUrl: 'https://immich.example',
            apiKey: 'secret',
            assetId: 'asset-1',
          ),
          isNull,
        );
      }
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'id': 'asset-1',
            'isTrashed': true,
          }),
          200));
      expect(
        await ImmichService(client: client).assetById(
          baseUrl: 'https://immich.example',
          apiKey: 'secret',
          assetId: 'asset-1',
        ),
        isNull,
      );
    });

    test('reports access errors instead of treating assets as deleted',
        () async {
      final client = MockClient((_) async => http.Response('', 403));
      expect(
        () => ImmichService(client: client).assetById(
          baseUrl: 'https://immich.example',
          apiKey: 'secret',
          assetId: 'asset-1',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ImmichService.assetsTakenBetween', () {
    test(
        'queries images and videos, paginates, ignores invalid assets, and sorts by capture time',
        () async {
      final requests = <Map<String, dynamic>>[];

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/search/metadata');
        expect(request.headers['x-api-key'], 'secret');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);

        if (body['type'] == 'IMAGE' && body['page'] == 1) {
          return http.Response(
            jsonEncode({
              'assets': {
                'items': [
                  {
                    'id': 'img-late',
                    'originalFileName': 'late.jpg',
                    'type': 'IMAGE',
                    'fileCreatedAt': '2026-09-30T12:00:00Z',
                  },
                  {
                    'id': 'invalid',
                    'originalFileName': 'invalid.jpg',
                    'type': 'IMAGE',
                  },
                ],
                'nextPage': 2,
              },
            }),
            200,
          );
        }

        if (body['type'] == 'IMAGE' && body['page'] == 2) {
          return http.Response(
            jsonEncode({
              'assets': {
                'items': [
                  {
                    'id': 'img-early',
                    'originalFileName': 'early.jpg',
                    'type': 'IMAGE',
                    'fileCreatedAt': '2026-09-30T08:00:00Z',
                  },
                ],
                'nextPage': null,
              },
            }),
            200,
          );
        }

        if (body['type'] == 'VIDEO' && body['page'] == 1) {
          return http.Response(
            jsonEncode({
              'assets': {
                'items': [
                  {
                    'id': 'video-middle',
                    'originalFileName': 'middle.mp4',
                    'type': 'VIDEO',
                    'fileCreatedAt': '2026-09-30T10:00:00Z',
                  },
                ],
                'nextPage': null,
              },
            }),
            200,
          );
        }

        fail('Unexpected request body: $body');
      });

      final service = ImmichService(client: client);
      final assets = await service.assetsTakenBetween(
        baseUrl: 'https://immich.example/',
        apiKey: 'secret',
        from: DateTime.utc(2026, 9, 30),
        to: DateTime.utc(2026, 10, 1),
      );

      expect(
        assets.map((asset) => asset.id),
        ['img-early', 'video-middle', 'img-late'],
      );
      expect(requests, hasLength(3));
      expect(
        requests.every((request) => request['withExif'] == true),
        isTrue,
      );
      expect(
        requests.every((request) => request['size'] == 500),
        isTrue,
      );
    });

    test('deduplicates assets returned more than once', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'assets': {
              'items': [
                {
                  'id': 'same-id',
                  'originalFileName':
                      body['type'] == 'IMAGE' ? 'first.jpg' : 'second.mp4',
                  'type': body['type'],
                  'fileCreatedAt': '2026-09-30T10:00:00Z',
                },
              ],
              'nextPage': null,
            },
          }),
          200,
        );
      });

      final assets = await ImmichService(client: client).assetsTakenBetween(
        baseUrl: 'https://immich.example',
        apiKey: 'secret',
        from: DateTime.utc(2026, 9, 30),
        to: DateTime.utc(2026, 10, 1),
      );

      expect(assets, hasLength(1));
      expect(assets.single.id, 'same-id');
    });
  });

  group('ImmichService.updateLocation', () {
    test('falls back from PUT to PATCH when PUT is unsupported', () async {
      final methods = <String>[];
      final bodies = <Map<String, dynamic>>[];

      final client = MockClient((request) async {
        methods.add(request.method);
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (request.method == 'PUT') {
          return http.Response('', 405);
        }
        if (request.method == 'PATCH') {
          return http.Response('', 200);
        }
        fail('Unexpected method ${request.method}');
      });

      await ImmichService(client: client).updateLocation(
        baseUrl: 'https://immich.example',
        apiKey: 'secret',
        assetId: 'asset-1',
        latitude: 48.123,
        longitude: 11.456,
      );

      expect(methods, ['PUT', 'PATCH']);
      expect(bodies, [
        {'latitude': 48.123, 'longitude': 11.456},
        {'latitude': 48.123, 'longitude': 11.456},
      ]);
    });

    test('reports unsuccessful update responses', () async {
      final client = MockClient((request) async => http.Response('nope', 400));

      expect(
        () => ImmichService(client: client).updateLocation(
          baseUrl: 'https://immich.example',
          apiKey: 'secret',
          assetId: 'asset-1',
          latitude: 48,
          longitude: 11,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ImmichService connection errors', () {
    test('maps HTTP client failures to unreachable', () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline', request.url);
      });

      expect(
        () => ImmichService(client: client).thumbnail(
          baseUrl: 'https://immich.example',
          apiKey: 'secret',
          assetId: 'asset-1',
        ),
        throwsA(
          isA<ImmichConnectionException>().having(
            (error) => error.error,
            'error',
            ImmichConnectionError.unreachable,
          ),
        ),
      );
    });

    test('maps 5xx responses to server errors', () async {
      final client = MockClient((request) async => http.Response('', 503));

      expect(
        () => ImmichService(client: client).thumbnail(
          baseUrl: 'https://immich.example',
          apiKey: 'secret',
          assetId: 'asset-1',
        ),
        throwsA(
          isA<ImmichConnectionException>()
              .having(
                (error) => error.error,
                'error',
                ImmichConnectionError.server,
              )
              .having((error) => error.statusCode, 'statusCode', 503),
        ),
      );
    });
  });
}
