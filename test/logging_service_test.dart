import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/services/logging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, (call) async {
          calls.add(call);
          if (call.method == 'export') return '/private/logs.zip';
          if (call.method == 'configuration' || call.method == 'configure') {
            return {
              'level': 'DEBUG',
              'enabled': true,
              'sizeMb': 5,
              'developerMode': true,
              'containsTrace': true,
            };
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, null);
  });

  test('exports after pending writes, preserves ordering and clear', () async {
    final first = LoggingService.log(LogLevel.info, 'tracking', 'started');
    final second = LoggingService.log(LogLevel.warn, 'tracking', 'interrupted');
    expect(await LoggingService.export(), '/private/logs.zip');
    await Future.wait([first, second]);
    await LoggingService.clear();
    expect(calls.map((call) => call.method), [
      'write',
      'write',
      'export',
      'clear',
    ]);
  });

  test('error records type and frames without exception message', () async {
    await LoggingService.error(
      'sync',
      'Apply failed',
      StateError('secret-api-key and private response body'),
      StackTrace.fromString(
        '#0 SyncService.applySync (sync_service.dart:42:3)',
      ),
    );
    final message = (calls.single.arguments as Map)['message'] as String;
    expect(message, contains('StateError'));
    expect(message, contains('SyncService.applySync'));
    expect(message, isNot(contains('secret-api-key')));
    expect(message, isNot(contains('private response body')));
  });

  test('logging failure does not propagate or poison later writes', () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, (call) async {
          calls.add(call);
          if (fail) {
            fail = false;
            throw PlatformException(code: 'disk_full');
          }
          return null;
        });
    await LoggingService.log(LogLevel.error, 'test', 'first');
    await LoggingService.log(LogLevel.info, 'test', 'second');
    expect(calls.length, 2);
  });

  test('configuration is persistent and carries TRACE history', () async {
    final config = await LoggingService.configure(
      level: LogLevel.debug,
      sizeMb: 5,
      developerMode: true,
    );
    expect(config.level, LogLevel.debug);
    expect(config.containsTrace, true);
    expect(config.developerMode, true);
    expect(calls.single.arguments, {
      'level': 'DEBUG',
      'sizeMb': 5,
      'developerMode': true,
    });
  });
}
