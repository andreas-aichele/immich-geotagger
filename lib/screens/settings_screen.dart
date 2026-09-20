import 'package:flutter/material.dart';

import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _retention = TextEditingController();
  final _interval = TextEditingController();
  final _maxGap = TextEditingController();
  final _settings = SettingsService();
  final _immich = ImmichService();

  bool _loading = true;
  bool _testing = false;
  bool _testSuccess = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _retention.dispose();
    _interval.dispose();
    _maxGap.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await _settings.load();
    _url.text = value.immichUrl;
    _key.text = value.apiKey;
    _retention.text = '${value.retentionDays}';
    _interval.text = '${value.trackingIntervalSeconds}';
    _maxGap.text = '${value.maxInterpolationGapMinutes}';
    if (mounted) setState(() => _loading = false);
  }

  AppSettings _value() => AppSettings(
        immichUrl: _url.text,
        apiKey: _key.text,
        retentionDays: int.parse(_retention.text),
        trackingIntervalSeconds: int.parse(_interval.text),
        maxInterpolationGapMinutes: int.parse(_maxGap.text),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _settings.save(_value());
    if (!mounted) return;
    setState(() => _status = 'Settings saved.');
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testSuccess = false;
      _status = null;
    });

    try {
      final value = _value();
      await _immich.verifyConnection(value.immichUrl, value.apiKey);
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _status = 'Connection and API permissions verified.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _status = e.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const Text(
                    'Connect GeoTagger to your Immich server and tune how the location timeline behaves.',
                    style: TextStyle(
                      color: Color(0xFF6A6A75),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionEyebrow('Immich'),
                        const SizedBox(height: 8),
                        const Text(
                          'Server connection',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _url,
                          decoration: const InputDecoration(
                            labelText: 'Immich URL',
                            hintText: 'https://immich.example.com',
                            prefixIcon: Icon(Icons.language_rounded),
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          validator: (v) =>
                              (v == null || !v.startsWith('http'))
                                  ? 'Enter a valid http(s) URL'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _key,
                          decoration: const InputDecoration(
                            labelText: 'API key',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'API key is required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ScopeChip('asset.read'),
                            _ScopeChip('asset.update'),
                          ],
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 16),
                          _StatusBox(
                            text: _status!,
                            success: _testSuccess,
                          ),
                        ],
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _testing ? null : _test,
                          icon: _testing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering_rounded),
                          label: const Text('Test connection'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionEyebrow('Tracking'),
                        const SizedBox(height: 8),
                        const Text(
                          'Timeline behavior',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _interval,
                          decoration: const InputDecoration(
                            labelText: 'Tracking interval',
                            suffixText: 'seconds',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _maxGap,
                          decoration: const InputDecoration(
                            labelText: 'Maximum interpolation gap',
                            suffixText: 'minutes',
                            prefixIcon: Icon(Icons.timeline_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _retention,
                          decoration: const InputDecoration(
                            labelText: 'Keep location history',
                            suffixText: 'days',
                            prefixIcon: Icon(Icons.history_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save settings'),
                  ),
                ],
              ),
            ),
    );
  }

  String? _positiveInt(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n <= 0 ? 'Enter a positive number' : null;
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
