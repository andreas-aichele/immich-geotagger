import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immich_geotagger/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('checks once per day, caches results and remembers dismissed versions',
      () async {
    var now = DateTime.utc(2026, 10, 3);
    var requests = 0;
    var tag = 'v1.0.9';
    final service = UpdateService(
      installedVersion: () async => '1.0.8',
      now: () => now,
      client: MockClient((request) async {
        requests++;
        expect(request.url.host, 'api.github.com');
        expect(request.url.path,
            '/repos/andreas-aichele/immich-geotagger/releases/latest');
        return http.Response(jsonEncode({'tag_name': tag}), 200);
      }),
    );
    addTearDown(service.dispose);

    final release = await service.check();
    expect(release?.version.toString(), '1.0.9');
    expect(release?.url.toString(),
        'https://github.com/andreas-aichele/immich-geotagger/releases/tag/v1.0.9');
    expect((await service.check())?.version.toString(), '1.0.9');
    expect(requests, 1);

    await service.dismiss(release!);
    expect(await service.check(), isNull);
    now = now.add(const Duration(days: 1));
    tag = 'v1.0.10';
    expect((await service.check())?.version.toString(), '1.0.10');
    expect(requests, 2);
  });

  test('disabled checks make no network or package metadata requests', () async {
    await UpdateService.setEnabled(false);
    final service = UpdateService(
      installedVersion: () async => fail('Must not read package metadata'),
      client: MockClient((_) async => fail('Must not contact GitHub')),
    );
    addTearDown(service.dispose);
    expect(await UpdateService.isEnabled(), isFalse);
    expect(await service.check(), isNull);
  });

  test('compares numeric versions and never offers an older or equal release',
      () async {
    for (final installed in ['1.0.9', '1.0.10', '1.0.9-beta.4+abc']) {
      SharedPreferences.setMockInitialValues({});
      final service = UpdateService(
        installedVersion: () async => installed,
        client: MockClient((_) async =>
            http.Response(jsonEncode({'tag_name': 'v1.0.9'}), 200)),
      );
      expect(await service.check(), isNull, reason: installed);
      service.dispose();
    }
  });

  test('ignores drafts, prereleases and malformed tags', () async {
    for (final release in [
      {'tag_name': 'v1.0.9', 'draft': true},
      {'tag_name': 'v1.0.9', 'prerelease': true},
      {'tag_name': 'v1.0.9-beta.1'},
      {'tag_name': 'not-a-version'},
    ]) {
      SharedPreferences.setMockInitialValues({});
      final service = UpdateService(
        installedVersion: () async => '1.0.8',
        client: MockClient((_) async =>
            http.Response(jsonEncode(release), 200)),
      );
      expect(await service.check(), isNull);
      service.dispose();
    }
  });

  test('network failures, rate limits and invalid JSON are silent and throttled',
      () async {
    for (final response in [null, http.Response('', 403), http.Response('{', 200)]) {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final service = UpdateService(
        installedVersion: () async => '1.0.8',
        client: MockClient((_) async {
          requests++;
          if (response == null) throw http.ClientException('offline');
          return response;
        }),
      );
      expect(await service.check(), isNull);
      expect(await service.check(), isNull);
      expect(requests, 1);
      service.dispose();
    }
  });

  test('disabling checks also hides a cached available release', () async {
    final service = UpdateService(
      installedVersion: () async => '1.0.8',
      client: MockClient((_) async =>
          http.Response(jsonEncode({'tag_name': 'v1.0.9'}), 200)),
    );
    addTearDown(service.dispose);
    expect(await service.check(), isNotNull);
    await UpdateService.setEnabled(false);
    expect(await service.check(), isNull);
  });
}
