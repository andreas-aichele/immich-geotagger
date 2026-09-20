import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImmichGeoTaggerApp());
}

class ImmichGeoTaggerApp extends StatelessWidget {
  const ImmichGeoTaggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.t('appName'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) return candidate;
        }
        return const Locale('en');
      },
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<bool> _ready =
      SettingsService().isOnboardingComplete();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}
