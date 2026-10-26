import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/l10n/app_localizations.dart';
import 'package:immich_geotagger/services/logging_service.dart';
import 'package:immich_geotagger/widgets/diagnostics_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var developer = false;
  var level = 'INFO';
  var crashReportCount = 0;
  final exports = <bool>[];
  setUp(() {
    developer = false;
    level = 'INFO';
    crashReportCount = 0;
    exports.clear();
    PackageInfo.setMockInitialValues(
      appName: 'Immich GeoTagger',
      packageName: 'immich',
      version: '1.1.0',
      buildNumber: '1010000',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, (call) async {
          if (call.method == 'export') {
            exports.add((call.arguments as Map)['includeCrashReports'] as bool);
            return '/private/logs.zip';
          }
          if (call.method == 'configure') {
            final args = call.arguments as Map;
            developer = args['developerMode'] as bool? ?? developer;
            level = args['level'] as String? ?? level;
          }
          return {
            'developerMode': developer,
            'level': level,
            'enabled': true,
            'sizeMb': 10,
            'containsTrace': false,
            'crashReportCount': crashReportCount,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => 'dev.fluttercommunity.plus/share/unavailable',
        );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, null);
  });

  Widget app() => MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(
      body: SingleChildScrollView(child: DiagnosticsSettings()),
    ),
  );

  testWidgets('seven taps unlock, survives rebuilding, hide restores INFO', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Entwickleroptionen'), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('Build-Nummer: 1010000'));
        await tester.pump();
      }
      expect(developer, false);
      await tester.tap(find.text('Build-Nummer: 1010000'));
      await tester.pumpAndSettle();
      expect(developer, true);
      expect(find.text('Entwickleroptionen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      level = 'DEBUG';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Entwickleroptionen'), findsOneWidget);
      final hide = find.text(
        'Entwickleroptionen ausblenden (INFO wiederherstellen)',
      );
      await tester.ensureVisible(hide);
      await tester.tap(hide);
      await tester.pumpAndSettle();
      expect(developer, false);
      expect(level, 'INFO');
      expect(find.text('Entwickleroptionen'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  for (final include in [false, true]) {
    testWidgets(
      'crash report dialog exports raw attachments only with consent: $include',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          developer = true;
          crashReportCount = 1;
          tester.view.physicalSize = const Size(360, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Logs teilen (ZIP)'));
          await tester.tap(find.text('Logs teilen (ZIP)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Absturzberichte beifügen?'), findsOneWidget);
          expect(find.textContaining('Zugangsdaten'), findsOneWidget);
          expect(exports, isEmpty);
          await tester.tap(
            find.text(include ? 'Berichte beifügen' : 'Nur Logs'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(AlertDialog), findsNothing);
          expect(exports, [include]);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
