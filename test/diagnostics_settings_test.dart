import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  setUp(() {
    developer = false;
    level = 'INFO';
    PackageInfo.setMockInitialValues(
      appName: 'Immich GeoTagger',
      packageName: 'immich',
      version: '1.1.0',
      buildNumber: '1010000',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LoggingService.channel, (call) async {
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
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
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
      await tester.tap(find.text('Entwickleroptionen'));
      await tester.pumpAndSettle();
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
}
