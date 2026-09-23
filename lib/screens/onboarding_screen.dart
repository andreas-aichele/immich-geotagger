import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../services/tracking_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _controller = PageController();
  final _settings = SettingsService();
  final _tracker = TrackingService();
  final _immich = ImmichService();
  final _url = TextEditingController();
  final _key = TextEditingController();

  int _page = 0;
  bool _permissionBusy = false;
  bool _permissionReady = false;
  bool _foregroundReady = false;
  bool _needsBackgroundSettings = false;
  bool _testBusy = false;
  bool _connectionReady = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _foregroundReady &&
        !_permissionReady) {
      _checkBackgroundPermission();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _permissionBusy = true;
      _message = null;
    });

    try {
      final foreground =
          await _tracker.requestForegroundLocationPermission();
      if (!mounted) return;

      if (!foreground) {
        setState(() {
          _foregroundReady = false;
          _message = context.l10n.t('foregroundLocationDenied');
        });
        return;
      }

      _foregroundReady = true;
      await _checkBackgroundPermission();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _permissionBusy = false);
    }
  }

  Future<void> _checkBackgroundPermission() async {
    final backgroundGranted =
        await _tracker.isBackgroundLocationGranted();
    if (!mounted) return;

    if (!backgroundGranted) {
      setState(() {
        _needsBackgroundSettings = true;
        _permissionReady = false;
        _message = context.l10n.t('backgroundSettingsInstruction');
      });
      return;
    }

    final batteryProtected =
        await _tracker.requestBatteryOptimizationExemption();
    if (!mounted) return;

    setState(() {
      _needsBackgroundSettings = false;
      _permissionReady = true;
      _message = batteryProtected
          ? context.l10n.t('permissionReady')
          : context.l10n.t('batteryRestricted');
    });
  }

  Future<void> _openBackgroundSettings() async {
    await _tracker.openSystemSettings();
  }

  Future<void> _testConnection() async {
    if (_url.text.trim().isEmpty || _key.text.trim().isEmpty) {
      setState(() => _message = context.l10n.t('enterImmichCredentials'));
      return;
    }

    setState(() {
      _testBusy = true;
      _message = null;
      _connectionReady = false;
    });

    try {
      await _immich.verifyConnection(_url.text.trim(), _key.text.trim());
      final current = await _settings.load();
      await _settings.save(
        AppSettings(
          immichUrl: _url.text.trim(),
          apiKey: _key.text.trim(),
          retentionDays: current.retentionDays,
          trackingQuality: current.trackingQuality,
          maxInterpolationGapMinutes: current.maxInterpolationGapMinutes,
        ),
      );
      if (!mounted) return;
      setState(() {
        _connectionReady = true;
        _message = context.l10n.t('connectionVerified');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Future<void> _finish() async {
    await _settings.setOnboardingComplete(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.t('appName'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text('${_page + 1} / 3'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(
                value: (_page + 1) / 3,
                minHeight: 4,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppTheme.primarySoftStrong,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() {
                  _page = value;
                  _message = null;
                }),
                children: [
                  _introPage(context),
                  _permissionPage(context),
                  _immichPage(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageShell({
    required Widget icon,
    required String title,
    required String body,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.navySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: icon,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 28),
        ...children,
      ],
    );
  }

  Widget _introPage(BuildContext context) {
    final l = context.l10n;
    return _pageShell(
      icon: Icon(
        Icons.route_rounded,
        color: AppTheme.brandTeal,
        size: 30,
      ),
      title: l.t('introTitle'),
      body: l.t('introBody'),
      children: [
        AppSurface(
          child: Column(
            children: [
              _FeatureRow(
                icon: Icons.my_location_rounded,
                title: l.t('backgroundTracking'),
                subtitle: l.t('backgroundTrackingDesc'),
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.timeline_rounded,
                title: l.t('safeInterpolation'),
                subtitle: l.t('safeInterpolationDesc'),
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.shield_outlined,
                title: l.t('existingGpsPreserved'),
                subtitle: l.t('existingGpsPreservedDesc'),
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.schedule_rounded,
                title: l.t('cameraTimeTipTitle'),
                subtitle: l.t('cameraTimeTipBody'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _next,
            child: Text(l.t('continue')),
          ),
        ),
      ],
    );
  }

  Widget _permissionPage(BuildContext context) {
    final l = context.l10n;
    return _pageShell(
      icon: Icon(
        Icons.location_searching_rounded,
        color: AppTheme.brandCoral,
        size: 30,
      ),
      title: l.t('allowLocationTitle'),
      body: l.t('allowLocationBody'),
      children: [
        AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionEyebrow(l.t('required')),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.location_on_outlined,
                title: l.t('preciseLocation'),
                subtitle: l.t('preciseLocationDesc'),
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.phone_android_rounded,
                title: l.t('backgroundLocation'),
                subtitle: l.t('backgroundLocationDesc'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 18),
                _StatusMessage(
                  text: _message!,
                  success: _permissionReady,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _permissionBusy
                ? null
                : (_permissionReady
                    ? _next
                    : (_needsBackgroundSettings
                        ? _openBackgroundSettings
                        : _requestPermissions)),
            icon: _permissionBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _permissionReady
                        ? Icons.arrow_forward_rounded
                        : (_needsBackgroundSettings
                            ? Icons.settings_outlined
                            : Icons.lock_open_rounded),
                  ),
            label: Text(
              _permissionReady
                  ? l.t('continue')
                  : (_needsBackgroundSettings
                      ? l.t('openLocationSettings')
                      : l.t('allowLocationAccess')),
            ),
          ),
        ),
        if (_needsBackgroundSettings && !_permissionReady) ...[
          const SizedBox(height: 8),
          Text(
            l.t('backgroundSettingsHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _immichPage(BuildContext context) {
    final l = context.l10n;
    return _pageShell(
      icon: Icon(
        Icons.photo_library_outlined,
        color: AppTheme.primary,
        size: 30,
      ),
      title: l.t('connectImmichTitle'),
      body: l.t('connectImmichBody'),
      children: [
        AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionEyebrow(l.t('apiKeyPermissions')),
              const SizedBox(height: 12),
              _PermissionCode(
                label: 'asset.read',
                description: l.t('assetReadDesc'),
              ),
              const SizedBox(height: 12),
              _PermissionCode(
                label: 'asset.view',
                description: l.t('assetViewDesc'),
              ),
              const SizedBox(height: 12),
              _PermissionCode(
                label: 'asset.update',
                description: l.t('assetUpdateDesc'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l.t('immichUrl'),
            hintText: 'https://immich.example.com',
            prefixIcon: const Icon(Icons.language_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l.t('apiKey'),
            prefixIcon: const Icon(Icons.key_rounded),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _StatusMessage(
            text: _message!,
            success: _connectionReady,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _testBusy
                ? null
                : (_connectionReady ? _finish : _testConnection),
            icon: _testBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _connectionReady
                        ? Icons.check_rounded
                        : Icons.wifi_tethering_rounded,
                  ),
            label: Text(
              _connectionReady
                  ? l.t('finishSetup')
                  : l.t('testConnection'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: AppTheme.brandTeal,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionCode extends StatelessWidget {
  const _PermissionCode({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: AppTheme.tealSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: AppTheme.muted),
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.text,
    required this.success,
  });

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? AppTheme.success
        : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success
                ? Icons.check_circle_outline
                : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
