import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gpx_export_service.dart';
import '../services/immich_service.dart';
import '../services/logging_service.dart';
import '../services/settings_service.dart';
import '../services/tracking_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_message.dart';
import '../widgets/diagnostics_settings.dart';
import '../widgets/settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _retention = TextEditingController();
  final _settings = SettingsService();
  final _immich = ImmichService();
  final _tracker = TrackingService();
  final _gpxExport = GpxExportService();

  Timer? _autoSaveTimer;

  bool _loading = true;
  bool _updateCheckEnabled = true;
  bool _testing = false;
  bool _savingConnection = false;
  bool _connectionVerified = false;
  bool _batteryProtected = true;
  bool _batteryBusy = false;
  bool _gpxExportBusy = false;
  bool _serverStatusSuccess = false;
  bool _apiKeyVisible = false;
  String? _serverStatus;
  String? _testedUrl;
  String? _testedKey;

  TrackingQuality _trackingQuality = TrackingQuality.balanced;
  int _retentionDays = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Persist the latest debounced tracking preferences when leaving.
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer!.cancel();
      _saveTrackingPreferences();
    }
    _url.dispose();
    _key.dispose();
    _retention.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await _settings.load();
    _updateCheckEnabled = await UpdateService.isEnabled();
    _url.text = value.immichUrl;
    _key.text = value.apiKey;
    _retentionDays = value.retentionDays;
    _retention.text = _retentionDays.toString();
    _trackingQuality = value.trackingQuality;

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
    } catch (e, stack) {
      await LoggingService.error('ui', 'settings action failed', e, stack);
      if (!mounted) return;
      setState(() {
        _serverStatusSuccess = false;
        _serverStatus = immichErrorMessage(context, e);
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
    );
    if (applyPreset) {
      await _tracker.applyConfiguredPreset();
    }
  }

  void _scheduleTrackingSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveTrackingPreferences();
    });
  }

  void _retentionChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _retentionDays = parsed;
    _scheduleTrackingSave();
  }

  Future<void> _trackingQualityChanged(TrackingQuality quality) async {
    setState(() => _trackingQuality = quality);
    await _saveTrackingPreferences(applyPreset: true);
  }

  Future<void> _requestBatteryProtection() async {
    setState(() => _batteryBusy = true);
    final protected = await _tracker.requestBatteryOptimizationExemption();
    if (!mounted) return;
    setState(() {
      _batteryProtected = protected;
      _batteryBusy = false;
    });
  }

  Future<void> _saveGpx() async {
    if (_gpxExportBusy) return;
    setState(() => _gpxExportBusy = true);
    try {
      final result = await _gpxExport.save();
      if (!mounted) return;
      switch (result) {
        case GpxExportResult.empty:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('gpxExportEmpty'))),
          );
        case GpxExportResult.completed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('gpxExportSaved'))),
          );
        case GpxExportResult.cancelled:
          break;
      }
    } catch (error, stack) {
      await LoggingService.error('ui', 'settings action failed', error, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('gpxExportFailed'))),
      );
    } finally {
      if (mounted) setState(() => _gpxExportBusy = false);
    }
  }

  Future<void> _shareGpx(BuildContext buttonContext) async {
    if (_gpxExportBusy) return;
    setState(() => _gpxExportBusy = true);
    try {
      final renderBox = buttonContext.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await _gpxExport.share(sharePositionOrigin: origin);
      if (!mounted) return;
      if (result == GpxExportResult.empty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('gpxExportEmpty'))),
        );
      }
    } catch (error, stack) {
      await LoggingService.error('ui', 'settings action failed', error, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('gpxExportFailed'))),
      );
    } finally {
      if (mounted) setState(() => _gpxExportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    const compactButtons = Size(0, 44);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Theme(
              data: theme.copyWith(
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: theme.filledButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(compactButtons),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: theme.outlinedButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(compactButtons),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SettingsSection(
                    title: l.t('serverConnection'),
                    icon: Icons.dns_outlined,
                    help: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('serverConnectionSaveHint')),
                        const SizedBox(height: 16),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ScopeChip('asset.read'),
                            _ScopeChip('asset.view'),
                            _ScopeChip('asset.update'),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      TextField(
                        controller: _url,
                        onChanged: _connectionChanged,
                        decoration: InputDecoration(
                          labelText: l.t('immichUrl'),
                          hintText: 'https://immich.example.com',
                          prefixIcon: const Icon(
                            Icons.language_rounded,
                            size: 20,
                          ),
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
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          suffixIcon: IconButton(
                            tooltip: l.t(
                              _apiKeyVisible ? 'hideApiKey' : 'showApiKey',
                            ),
                            icon: Icon(
                              _apiKeyVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _apiKeyVisible = !_apiKeyVisible,
                            ),
                          ),
                        ),
                        obscureText: !_apiKeyVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      if (_serverStatus != null) ...[
                        const SizedBox(height: 12),
                        _StatusBox(
                          text: _serverStatus!,
                          success: _serverStatusSuccess,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? _busyIcon()
                                : const Icon(
                                    Icons.wifi_tethering_rounded,
                                    size: 18,
                                  ),
                            label: Text(l.t('testConnection')),
                          ),
                          if (_connectionVerified)
                            FilledButton.icon(
                              onPressed:
                                  _testedConnectionStillMatches &&
                                      !_savingConnection
                                  ? _saveConnection
                                  : null,
                              icon: _savingConnection
                                  ? _busyIcon()
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: Text(l.t('saveConnection')),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsSection(
                    title: l.t('timelineBehavior'),
                    icon: Icons.route_outlined,
                    help: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('trackingAutoSaveHint')),
                        const SizedBox(height: 12),
                        Text(l.t('trackingBalancedDesc')),
                        const SizedBox(height: 12),
                        Text(l.t('trackingPreciseDesc')),
                        const SizedBox(height: 12),
                        Text(l.t('trackingSamplingHint')),
                        const SizedBox(height: 12),
                        Text(l.t('batteryProtectionDesc')),
                        const SizedBox(height: 12),
                        Text(l.t('gpxExportDesc')),
                      ],
                    ),
                    children: [
                      Text(
                        l.t('trackingQuality'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (MediaQuery.textScalerOf(context).scale(14) > 18)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final quality in TrackingQuality.values)
                              ChoiceChip(
                                label: Text(
                                  l.t(
                                    quality == TrackingQuality.balanced
                                        ? 'trackingBalanced'
                                        : 'trackingPrecise',
                                  ),
                                ),
                                selected: _trackingQuality == quality,
                                selectedColor: AppTheme.primarySoftStrong,
                                showCheckmark: false,
                                onSelected: (_) =>
                                    _trackingQualityChanged(quality),
                              ),
                          ],
                        )
                      else
                        SegmentedButton<TrackingQuality>(
                          expandedInsets: EdgeInsets.zero,
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppTheme.primarySoftStrong,
                            selectedForegroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(0, 44),
                          ),
                          segments: [
                            ButtonSegment(
                              value: TrackingQuality.balanced,
                              icon: const Icon(
                                Icons.battery_saver_outlined,
                                size: 18,
                              ),
                              label: Text(l.t('trackingBalanced')),
                            ),
                            ButtonSegment(
                              value: TrackingQuality.precise,
                              icon: const Icon(
                                Icons.gps_fixed_rounded,
                                size: 18,
                              ),
                              label: Text(l.t('trackingPrecise')),
                            ),
                          ],
                          selected: {_trackingQuality},
                          onSelectionChanged: (selection) =>
                              _trackingQualityChanged(selection.first),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l.t(
                          _trackingQuality == TrackingQuality.balanced
                              ? 'settingsBalancedShort'
                              : 'settingsPreciseShort',
                        ),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _retention,
                        onChanged: _retentionChanged,
                        decoration: InputDecoration(
                          labelText: l.t('settingsRetention'),
                          suffixText: l.t('days'),
                          prefixIcon: const Icon(
                            Icons.history_rounded,
                            size: 20,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _positiveInt,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _batteryProtected
                                ? Icons.check_circle_outline
                                : Icons.battery_alert_outlined,
                            size: 20,
                            color: _batteryProtected
                                ? const Color(0xFF157A4A)
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.t(
                                _batteryProtected
                                    ? 'settingsBatteryReady'
                                    : 'settingsBatteryRestricted',
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (!_batteryProtected)
                            TextButton(
                              onPressed: _batteryBusy
                                  ? null
                                  : _requestBatteryProtection,
                              child: _batteryBusy
                                  ? _busyIcon()
                                  : Text(l.t('settingsConfigure')),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        l.t('gpxExportTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _gpxExportBusy ? null : _saveGpx,
                            icon: _gpxExportBusy
                                ? _busyIcon()
                                : const Icon(Icons.save_alt_rounded, size: 18),
                            label: Text(l.t('gpxSaveButton')),
                          ),
                          Builder(
                            builder: (buttonContext) => OutlinedButton.icon(
                              onPressed: _gpxExportBusy
                                  ? null
                                  : () => _shareGpx(buttonContext),
                              icon: const Icon(Icons.share_outlined, size: 18),
                              label: Text(l.t('gpxShareButton')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsSection(
                    title: l.t('settingsApp'),
                    icon: Icons.tune_rounded,
                    help: Text(l.t('updateCheckDescription')),
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l.t('updateCheckTitle'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          l.t('settingsUpdatesShort'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                        value: _updateCheckEnabled,
                        onChanged: (value) async {
                          setState(() => _updateCheckEnabled = value);
                          await UpdateService.setEnabled(value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const DiagnosticsSettings(),
                ],
              ),
            ),
    );
  }

  Widget _busyIcon() => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  String? _positiveInt(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n <= 0 ? context.l10n.t('positiveNumber') : null;
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.text, required this.success});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? const Color(0xFF157A4A)
        : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
