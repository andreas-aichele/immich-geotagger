import 'dart:async';

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
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _retention = TextEditingController();
  final _maxGap = TextEditingController();
  final _settings = SettingsService();
  final _immich = ImmichService();
  final _tracker = TrackingService();

  Timer? _autoSaveTimer;

  bool _loading = true;
  bool _testing = false;
  bool _savingConnection = false;
  bool _connectionVerified = false;
  bool _batteryProtected = true;
  bool _batteryBusy = false;
  bool _serverStatusSuccess = false;
  String? _serverStatus;
  String? _testedUrl;
  String? _testedKey;

  TrackingQuality _trackingQuality = TrackingQuality.balanced;
  int _retentionDays = 14;
  int _maxGapMinutes = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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
    _retentionDays = value.retentionDays;
    _retention.text = _retentionDays.toString();
    _trackingQuality = value.trackingQuality;
    _maxGapMinutes = value.maxInterpolationGapMinutes;
    _maxGap.text = _maxGapMinutes.toString();

    final batteryProtected = await _tracker.isBatteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _batteryProtected = batteryProtected;
      _loading = false;
    });
  }

  void _connectionChanged(String _) {
    if (!_connectionVerified && _serverStatus == null) return;
    setState(() {
      _connectionVerified = false;
      _testedUrl = null;
      _testedKey = null;
      _serverStatus = null;
    });
  }

  bool get _testedConnectionStillMatches =>
      _connectionVerified &&
      _testedUrl == _url.text.trim() &&
      _testedKey == _key.text.trim();

  Future<void> _testConnection() async {
    final l = context.l10n;
    final url = _url.text.trim();
    final key = _key.text.trim();

    if (!url.startsWith('http')) {
      setState(() {
        _serverStatusSuccess = false;
        _serverStatus = l.t('validUrl');
      });
      return;
    }
    if (key.isEmpty) {
      setState(() {
        _serverStatusSuccess = false;
        _serverStatus = l.t('apiKeyRequired');
      });
      return;
    }

    setState(() {
      _testing = true;
      _connectionVerified = false;
      _serverStatus = null;
      _testedUrl = null;
      _testedKey = null;
    });

    try {
      await _immich.verifyConnection(url, key);
      if (!mounted) return;
      setState(() {
        _connectionVerified = true;
        _testedUrl = url;
        _testedKey = key;
        _serverStatusSuccess = true;
        _serverStatus = l.t('connectionVerifiedSaveHint');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverStatusSuccess = false;
        _serverStatus = e.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveConnection() async {
    if (!_testedConnectionStillMatches || _savingConnection) return;

    setState(() => _savingConnection = true);
    await _settings.saveConnection(
      immichUrl: _url.text.trim(),
      apiKey: _key.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _savingConnection = false;
      _serverStatusSuccess = true;
      _serverStatus = context.l10n.t('connectionSaved');
    });
  }

  Future<void> _saveTrackingPreferences({bool applyPreset = false}) async {
    await _settings.saveTrackingPreferences(
      retentionDays: _retentionDays,
      trackingQuality: _trackingQuality,
      maxInterpolationGapMinutes: _maxGapMinutes,
    );
    if (applyPreset) {
      await _tracker.applyConfiguredPreset();
    }
  }

  void _scheduleTrackingSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _saveTrackingPreferences();
      },
    );
  }

  void _retentionChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _retentionDays = parsed;
    _scheduleTrackingSave();
  }

  void _maxGapChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _maxGapMinutes = parsed;
    _scheduleTrackingSave();
  }

  Future<void> _trackingQualityChanged(TrackingQuality quality) async {
    setState(() => _trackingQuality = quality);
    await _saveTrackingPreferences(applyPreset: true);
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
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
                      const SizedBox(height: 8),
                      Text(
                        l.t('serverConnectionSaveHint'),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _url,
                        onChanged: _connectionChanged,
                        decoration: InputDecoration(
                          labelText: l.t('immichUrl'),
                          hintText: 'https://immich.example.com',
                          prefixIcon: const Icon(Icons.language_rounded),
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _key,
                        onChanged: _connectionChanged,
                        decoration: InputDecoration(
                          labelText: l.t('apiKey'),
                          prefixIcon: const Icon(Icons.key_rounded),
                        ),
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      const SizedBox(height: 14),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ScopeChip('asset.read'),
                          _ScopeChip('asset.view'),
                          _ScopeChip('asset.update'),
                        ],
                      ),
                      if (_serverStatus != null) ...[
                        const SizedBox(height: 16),
                        _StatusBox(
                          text: _serverStatus!,
                          success: _serverStatusSuccess,
                        ),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _testing ? null : _testConnection,
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
                      if (_connectionVerified) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _testedConnectionStillMatches &&
                                  !_savingConnection
                              ? _saveConnection
                              : null,
                          icon: _savingConnection
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(l.t('saveConnection')),
                        ),
                      ],
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
                      const SizedBox(height: 8),
                      Text(
                        l.t('trackingAutoSaveHint'),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          height: 1.4,
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
                          _trackingQualityChanged(selection.first);
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
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _maxGap,
                        onChanged: _maxGapChanged,
                        decoration: InputDecoration(
                          labelText: l.t('maximumInterpolationGap'),
                          suffixText: l.t('minutes'),
                          prefixIcon: const Icon(Icons.timeline_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        validator: _positiveInt,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _retention,
                        onChanged: _retentionChanged,
                        decoration: InputDecoration(
                          labelText: l.t('keepLocationHistory'),
                          suffixText: l.t('days'),
                          prefixIcon: const Icon(Icons.history_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
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
              ],
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
