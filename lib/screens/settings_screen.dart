import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/immich_service.dart';
import '../services/settings_service.dart';
import '../services/tracking_service.dart';
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
  final _maxGap = TextEditingController();
  final _settings = SettingsService();
  final _immich = ImmichService();
  final _tracker = TrackingService();

  bool _loading = true;
  bool _testing = false;
  bool _testSuccess = false;
  bool _batteryProtected = true;
  bool _batteryBusy = false;
  String? _status;
  TrackingQuality _trackingQuality = TrackingQuality.balanced;

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
    _maxGap.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await _settings.load();
    _url.text = value.immichUrl;
    _key.text = value.apiKey;
    _retention.text = value.retentionDays.toString();
    _trackingQuality = value.trackingQuality;
    _maxGap.text = value.maxInterpolationGapMinutes.toString();
    final batteryProtected = await _tracker.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _batteryProtected = batteryProtected;
        _loading = false;
      });
    }
  }

  AppSettings _value() => AppSettings(
        immichUrl: _url.text,
        apiKey: _key.text,
        retentionDays: int.parse(_retention.text),
        trackingQuality: _trackingQuality,
        maxInterpolationGapMinutes: int.parse(_maxGap.text),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _settings.save(_value());
    await _tracker.applyConfiguredPreset();
    if (!mounted) return;
    setState(() => _status = context.l10n.t('settingsSaved'));
  }

  Future<void> _requestBatteryProtection() async {
    setState(() => _batteryBusy = true);
    final protected =
        await _tracker.requestBatteryOptimizationExemption();
    if (!mounted) return;
    setState(() {
      _batteryProtected = protected;
      _batteryBusy = false;
    });
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
        _status = context.l10n.t('connectionVerified');
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('settings'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    l.t('settingsIntro'),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionEyebrow(l.t('immich')),
                        const SizedBox(height: 8),
                        Text(
                          l.t('serverConnection'),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _url,
                          decoration: InputDecoration(
                            labelText: l.t('immichUrl'),
                            hintText: 'https://immich.example.com',
                            prefixIcon: const Icon(Icons.language_rounded),
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          validator: (v) =>
                              (v == null || !v.startsWith('http'))
                                  ? l.t('validUrl')
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _key,
                          decoration: InputDecoration(
                            labelText: l.t('apiKey'),
                            prefixIcon: const Icon(Icons.key_rounded),
                          ),
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? l.t('apiKeyRequired')
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
                          label: Text(l.t('testConnection')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionEyebrow(l.t('tracking')),
                        const SizedBox(height: 8),
                        Text(
                          l.t('timelineBehavior'),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l.t('trackingQuality'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<TrackingQuality>(
                          segments: [
                            ButtonSegment(
                              value: TrackingQuality.balanced,
                              icon: const Icon(Icons.battery_saver_outlined),
                              label: Text(l.t('trackingBalanced')),
                            ),
                            ButtonSegment(
                              value: TrackingQuality.precise,
                              icon: const Icon(Icons.gps_fixed_rounded),
                              label: Text(l.t('trackingPrecise')),
                            ),
                          ],
                          selected: {_trackingQuality},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _trackingQuality = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _trackingQuality == TrackingQuality.balanced
                              ? l.t('trackingBalancedDesc')
                              : l.t('trackingPreciseDesc'),
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _maxGap,
                          decoration: InputDecoration(
                            labelText: l.t('maximumInterpolationGap'),
                            suffixText: l.t('minutes'),
                            prefixIcon: const Icon(Icons.timeline_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _retention,
                          decoration: InputDecoration(
                            labelText: l.t('keepLocationHistory'),
                            suffixText: l.t('days'),
                            prefixIcon: const Icon(Icons.history_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionEyebrow(l.t('batteryProtection')),
                        const SizedBox(height: 8),
                        Text(
                          l.t('batteryProtection'),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.t('batteryProtectionDesc'),
                          style: const TextStyle(
                            color: AppTheme.muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StatusBox(
                          text: _batteryProtected
                              ? l.t('batteryProtected')
                              : l.t('batteryRestricted'),
                          success: _batteryProtected,
                        ),
                        if (!_batteryProtected) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _batteryBusy
                                ? null
                                : _requestBatteryProtection,
                            icon: _batteryBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.battery_saver_outlined),
                            label: Text(
                              l.t('allowUnrestrictedBattery'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.t('saveSettings')),
                  ),
                ],
              ),
            ),
    );
  }

  String? _positiveInt(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n <= 0
        ? context.l10n.t('positiveNumber')
        : null;
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
        color: AppTheme.primarySoft,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success
                ? Icons.check_circle_outline
                : Icons.info_outline,
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
