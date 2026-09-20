import 'package:flutter/material.dart';

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

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _settings = SettingsService();
  final _tracker = TrackingService();
  final _immich = ImmichService();
  final _url = TextEditingController();
  final _key = TextEditingController();

  int _page = 0;
  bool _permissionBusy = false;
  bool _permissionReady = false;
  bool _testBusy = false;
  bool _connectionReady = false;
  String? _message;

  @override
  void dispose() {
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

  Future<void> _requestPermissions() async {
    setState(() {
      _permissionBusy = true;
      _message = null;
    });
    try {
      await _tracker.requestRequiredPermissions();
      if (!mounted) return;
      setState(() {
        _permissionReady = true;
        _message = 'Background location access is ready.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _permissionBusy = false);
    }
  }

  Future<void> _testConnection() async {
    if (_url.text.trim().isEmpty || _key.text.trim().isEmpty) {
      setState(() => _message = 'Enter your Immich URL and API key first.');
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
          trackingIntervalSeconds: current.trackingIntervalSeconds,
          maxInterpolationGapMinutes: current.maxInterpolationGapMinutes,
        ),
      );
      if (!mounted) return;
      setState(() {
        _connectionReady = true;
        _message = 'Connection and API permissions verified.';
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Immich GeoTagger',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                backgroundColor: const Color(0xFFE6E6EE),
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
              color: const Color(0xFFECECFB),
              borderRadius: BorderRadius.circular(20),
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
            color: Color(0xFF62626D),
          ),
        ),
        const SizedBox(height: 28),
        ...children,
      ],
    );
  }

  Widget _introPage(BuildContext context) => _pageShell(
        icon: Icon(
          Icons.route_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 30,
        ),
        title: 'GPS for cameras without GPS.',
        body:
            'Keep your camera workflow unchanged. GeoTagger records a private location timeline and matches it to photos in Immich by capture time.',
        children: [
          const AppSurface(
            child: Column(
              children: [
                _FeatureRow(
                  icon: Icons.my_location_rounded,
                  title: 'Background tracking',
                  subtitle: 'Location points stay on your device.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.timeline_rounded,
                  title: 'Safe interpolation',
                  subtitle: 'Photos between two points get an interpolated position.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.shield_outlined,
                  title: 'Existing GPS is preserved',
                  subtitle: 'Only assets without coordinates are changed.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _next, child: const Text('Continue')),
        ],
      );

  Widget _permissionPage(BuildContext context) => _pageShell(
        icon: Icon(
          Icons.location_searching_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 30,
        ),
        title: 'Allow location in the background.',
        body:
            'GeoTagger needs precise location while the app is not visible. Android may show two separate steps: location access first, then “Allow all the time”.',
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionEyebrow('Required'),
                const SizedBox(height: 12),
                const _FeatureRow(
                  icon: Icons.location_on_outlined,
                  title: 'Precise location',
                  subtitle: 'Used to record each track point.',
                ),
                const SizedBox(height: 18),
                const _FeatureRow(
                  icon: Icons.phone_android_rounded,
                  title: 'Background location',
                  subtitle: 'Keeps recording while you use the camera.',
                ),
                if (_message != null) ...[
                  const SizedBox(height: 18),
                  _StatusMessage(text: _message!, success: _permissionReady),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _permissionBusy ? null : _requestPermissions,
            icon: _permissionBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(
              _permissionReady ? 'Permission granted' : 'Allow location access',
            ),
          ),
          if (!_permissionReady)
            TextButton(
              onPressed: _tracker.openSystemSettings,
              child: const Text('Open app settings'),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _permissionReady ? _next : null,
            child: const Text('Continue'),
          ),
        ],
      );

  Widget _immichPage(BuildContext context) => _pageShell(
        icon: Icon(
          Icons.photo_library_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 30,
        ),
        title: 'Connect your Immich library.',
        body:
            'Create a dedicated API key in Immich. For the smallest permission set, enable exactly the two permissions below.',
        children: [
          const AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow('API key permissions'),
                SizedBox(height: 12),
                _PermissionCode(
                  label: 'asset.read',
                  description: 'Search photos and read capture metadata.',
                ),
                SizedBox(height: 12),
                _PermissionCode(
                  label: 'asset.update',
                  description: 'Write latitude and longitude to matched photos.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Immich URL',
              hintText: 'https://immich.example.com',
              prefixIcon: Icon(Icons.language_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'API key',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            _StatusMessage(text: _message!, success: _connectionReady),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _testBusy ? null : _testConnection,
            icon: _testBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Test connection'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: _connectionReady ? _finish : null,
            child: const Text('Finish setup'),
          ),
        ],
      );
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
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6A6A75),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFECECFB),
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
            style: const TextStyle(color: Color(0xFF656570)),
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
        ? const Color(0xFF157A4A)
        : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.info_outline,
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
