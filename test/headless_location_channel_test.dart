import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/services/headless_location_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final location = {
    'latitude': 7.1,
    'longitude': 80.2,
    'accuracy': 5.0,
    'timestamp': 1791962891399,
  };

  Future<Object?> nativeEvent(String method, Map<String, dynamic> arguments) {
    final response = Completer<Object?>();
    messenger.handlePlatformMessage(
      headlessLocationChannel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (bytes) {
        try {
          response.complete(codec.decodeEnvelope(bytes!));
        } catch (error, stack) {
          response.completeError(error, stack);
        }
      },
    );
    return response.future;
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(headlessLocationChannel, null);
    headlessLocationChannel.setMethodCallHandler(null);
  });

  test(
    'handler is installed before readiness and acknowledgement waits for persistence',
    () async {
      final saved = Completer<void>();
      final received = Completer<void>();
      Future<Object?>? pending;
      var acknowledged = false;
      messenger.setMockMethodCallHandler(headlessLocationChannel, (call) async {
        expect(call.method, 'initialized');
        // Native dispatches synchronously upon readiness, before initialization returns.
        pending = nativeEvent('onLocationUpdate', location).then((value) {
          acknowledged = true;
          return value;
        });
        return null;
      });
      await initializeHeadlessLocationChannel(
        savePosition: (position) async {
          expect(position.latitude, 7.1);
          expect(position.longitude, 80.2);
          received.complete();
          await saved.future;
        },
      );
      await received.future;
      expect(acknowledged, false);
      saved.complete();
      await pending;
      expect(acknowledged, true);
    },
  );

  test(
    'heartbeat persists its nested position and boot event creates no GPS point',
    () async {
      messenger.setMockMethodCallHandler(
        headlessLocationChannel,
        (_) async => null,
      );
      var count = 0;
      await initializeHeadlessLocationChannel(
        savePosition: (_) async {
          count++;
        },
      );
      await nativeEvent('onHeartbeat', {'position': location});
      expect(count, 1);
      await nativeEvent('onHeartbeat', {
        'event': 'boot',
        'timestamp': 1791962891399,
      });
      expect(count, 1);
    },
  );

  test(
    'invalid payload and database errors return failure and later events still work',
    () async {
      messenger.setMockMethodCallHandler(
        headlessLocationChannel,
        (_) async => null,
      );
      var fail = true;
      var count = 0;
      await initializeHeadlessLocationChannel(
        savePosition: (_) async {
          if (fail) throw StateError('database unavailable');
          count++;
        },
      );
      await expectLater(
        nativeEvent('onLocationUpdate', location),
        throwsA(isA<PlatformException>()),
      );
      fail = false;
      await expectLater(
        nativeEvent('onLocationUpdate', {...location, 'latitude': 91}),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        nativeEvent('onHeartbeat', {}),
        throwsA(isA<PlatformException>()),
      );
      expect(count, 0);
      await nativeEvent('onLocationUpdate', location);
      expect(count, 1);
    },
  );
}
