import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/l10n/app_localizations.dart';
import 'package:immich_geotagger/screens/settings_screen.dart';
import 'package:immich_geotagger/services/logging_service.dart';
import 'package:immich_geotagger/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = Platform.environment['SETTINGS_SCREENSHOT_FONT_DIR'];
    if (directory == null) return;
    for (final family in ['Roboto', 'Ahem']) {
      final loader = FontLoader(family);
      for (final name in ['Regular', 'Medium', 'Bold']) {
        loader.addFont(
          File('$directory/Roboto-$name.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File('$directory/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await icons.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'immich_url': 'https://immich.example.com',
      'retention_days': 30,
      'tracking_quality': 'precise',
    });
    FlutterSecureStorage.setMockInitialValues({'immich_api_key': 'test-key'});
    PackageInfo.setMockInitialValues(
      appName: 'Immich GeoTagger',
      packageName: 'immich',
      version: '1.1.0',
      buildNumber: '1010000',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          LoggingService.channel,
          (call) async => {
            'developerMode': false,
            'level': 'INFO',
            'enabled': true,
            'sizeMb': 10,
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('libre_location'), (
          call,
        ) async {
          if (call.method == 'isTracking') return false;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('libre_location'), null);
  });

  ThemeData qaTheme() {
    final theme = AppTheme.light();
    if (Platform.environment['SETTINGS_SCREENSHOT_FONT_DIR'] == null) {
      return theme;
    }
    TextStyle style(TextStyle? original) =>
        (original ?? const TextStyle()).copyWith(fontFamily: 'Roboto');
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: style(theme.appBarTheme.titleTextStyle),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: theme.filledButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            style(theme.filledButtonTheme.style?.textStyle?.resolve({})),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: theme.outlinedButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            style(theme.outlinedButtonTheme.style?.textStyle?.resolve({})),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: theme.textButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            style(theme.textButtonTheme.style?.textStyle?.resolve({})),
          ),
        ),
      ),
    );
  }

  Widget app(double scale) => MaterialApp(
    theme: qaTheme(),
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: const ValueKey('screen'), child: child!),
    ),
    home: const SettingsScreen(),
  );

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['SETTINGS_SCREENSHOT_DIR'];
    if (output == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('original sections keep inline guidance and save retention', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'settings-top');
      expect(find.text('asset.read'), findsOneWidget);
      expect(find.byTooltip('Weitere Informationen'), findsNothing);
      final retention = find.byType(TextFormField);
      await tester.ensureVisible(retention);
      await tester.enterText(retention, '45');
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        (await SharedPreferences.getInstance()).getInt('retention_days'),
        45,
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('Über die App'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'settings-bottom');
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('narrow screen and larger text keep actions reachable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Teilen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'settings-large-text');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Nach Updates suchen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
