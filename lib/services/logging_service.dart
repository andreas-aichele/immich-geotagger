import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

enum LogLevel { error, warn, info, debug, trace }

class LogConfiguration {
  const LogConfiguration({
    this.enabled = true,
    this.level = LogLevel.info,
    this.sizeMb = 10,
    this.developerMode = false,
    this.containsTrace = false,
  });
  final bool enabled;
  final LogLevel level;
  final int sizeMb;
  final bool developerMode;
  final bool containsTrace;

  factory LogConfiguration.fromMap(Map<dynamic, dynamic> map) {
    return LogConfiguration(
      enabled: map['enabled'] as bool? ?? true,
      level: LogLevel.values.firstWhere(
        (level) => level.name.toUpperCase() == map['level'],
        orElse: () => LogLevel.info,
      ),
      sizeMb: map['sizeMb'] as int? ?? 10,
      developerMode: map['developerMode'] as bool? ?? false,
      containsTrace: map['containsTrace'] as bool? ?? false,
    );
  }
}

/// A single native writer handles every Flutter engine and Android callbacks.
/// Messages must be structured diagnostics, never keys, URLs, API bodies or EXIF.
class LoggingService {
  static const channel = MethodChannel('immich_geotagger/diagnostics');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> _pending = Future<void>.value();
  static bool _handlersInstalled = false;

  static Future<void> initialize() async {
    if (_handlersInstalled) return;
    await log(LogLevel.info, 'app', 'Flutter engine started');
    _handlersInstalled = true;
    WidgetsBinding.instance.addObserver(_LogLifecycleObserver());
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        error(
          'flutter',
          'Framework exception',
          details.exception,
          details.stack,
        ),
      );
      previous?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (exception, stack) {
      unawaited(
        error('flutter', 'Unhandled asynchronous exception', exception, stack),
      );
      return previousPlatform?.call(exception, stack) ?? false;
    };
  }

  static Future<LogConfiguration> configuration() async {
    if (!supported) return const LogConfiguration();
    return LogConfiguration.fromMap(
      await channel.invokeMapMethod<dynamic, dynamic>('configuration') ?? {},
    );
  }

  static Future<LogConfiguration> configure({
    bool? enabled,
    LogLevel? level,
    int? sizeMb,
    bool? developerMode,
  }) async {
    if (!supported) return const LogConfiguration();
    return LogConfiguration.fromMap(
      await channel.invokeMapMethod<dynamic, dynamic>('configure', {
            'enabled': ?enabled,
            'level': ?level?.name.toUpperCase(),
            'sizeMb': ?sizeMb,
            'developerMode': ?developerMode,
          }) ??
          {},
    );
  }

  static Future<void> log(LogLevel level, String source, String message) {
    if (!supported) return Future<void>.value();
    // Preserve order and let export drain outstanding writes. Logger failures
    // must never break tracking, startup or the original exception handler.
    _pending = _pending.then((_) async {
      try {
        await channel.invokeMethod<void>('write', {
          'level': level.name.toUpperCase(),
          'source': source,
          'message': message,
        });
      } catch (_) {
        /* Best effort if storage is full or the plugin is absent. */
      }
    });
    return _pending;
  }

  static Future<void> error(
    String source,
    String event,
    Object error, [
    StackTrace? stack,
  ]) {
    // Exception.toString() often embeds HTTP bodies, filenames or credentials.
    // Keep the type and stack frames, which explain the failure without them.
    return log(
      LogLevel.error,
      source,
      '$event: ${error.runtimeType}${stack == null ? '' : '\n$stack'}',
    );
  }

  static Future<String> export() async {
    await _pending;
    final path = await channel.invokeMethod<String>('export');
    if (path == null) throw StateError('Log export unavailable');
    return path;
  }

  static Future<void> clear() async {
    await _pending;
    await channel.invokeMethod<void>('clear');
  }
}

class _LogLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      LoggingService.log(LogLevel.info, 'app', 'Lifecycle: ${state.name}'),
    );
  }
}
