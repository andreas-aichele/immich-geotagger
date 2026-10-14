import 'package:flutter/services.dart';
import 'package:libre_location/libre_location.dart' hide LogLevel;

import 'logging_service.dart';

const headlessLocationChannel = MethodChannel('libre_location/headless');

/// Installs the protocol expected by libre_location 0.4.3's native dispatcher.
/// The native in-flight counter is released by this handler's async reply, so
/// await persistence before acknowledging the event (including heartbeats).
Future<void> initializeHeadlessLocationChannel({
  required Future<void> Function(Position position) savePosition,
}) async {
  headlessLocationChannel.setMethodCallHandler((call) async {
    if (call.method != 'onLocationUpdate' && call.method != 'onHeartbeat') {
      throw MissingPluginException('Unknown headless event');
    }
    try {
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final Map<String, dynamic> data;
      if (call.method == 'onHeartbeat') {
        // BootReceiver also emits a heartbeat without a position. Do not save
        // a synthetic location or treat a successful boot wake-up as a failure.
        if (arguments['event'] == 'boot' && arguments['position'] == null) {
          await LoggingService.log(
            LogLevel.info,
            'tracking',
            'Headless boot callback received',
          );
          return;
        }
        data = Map<String, dynamic>.from(arguments['position'] as Map);
      } else {
        data = arguments;
      }
      final position = Position.fromMap(data);
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        throw const FormatException('Invalid headless coordinates');
      }
      await savePosition(position);
    } catch (error, stack) {
      await LoggingService.error(
        'tracking',
        'Headless event failed',
        error,
        stack,
      );
      rethrow;
    }
  });
  await headlessLocationChannel.invokeMethod<void>('initialized');
}
