import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/l10n/app_localizations.dart';
import 'package:immich_geotagger/services/update_service.dart';
import 'package:immich_geotagger/widgets/update_banner.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  testWidgets('shows release and manager hint, and supports dismissing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: UpdateBanner(
          release: AppRelease(Version(1, 0, 9)),
          onDismiss: () => dismissed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.9 ist verfügbar'), findsOneWidget);
    expect(tester.getSize(find.byType(UpdateBanner)).height, lessThan(140));
    expect(find.text('Du kannst auch über Obtainium oder F-Droid aktualisieren.'),
        findsOneWidget);
    expect(find.byTooltip('Release öffnen'), findsOneWidget);
    await tester.tap(find.byTooltip('Diese Version ausblenden'));
    expect(dismissed, isTrue);
  });

  testWidgets('marks the temporary preview as a test', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: UpdateBanner(
          release: AppRelease(Version(99, 0, 0)),
          preview: true,
          onDismiss: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update-Hinweis testen'), findsOneWidget);
    expect(find.textContaining('99.0.0'), findsNothing);
  });
}
