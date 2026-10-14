import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import '../l10n/app_localizations.dart';
import '../services/logging_service.dart';
import '../theme/app_theme.dart';

class DiagnosticsSettings extends StatefulWidget {
  const DiagnosticsSettings({super.key});
  @override
  State<DiagnosticsSettings> createState() => _DiagnosticsSettingsState();
}

class _DiagnosticsSettingsState extends State<DiagnosticsSettings> {
  LogConfiguration? _configuration;
  PackageInfo? _package;
  int _taps = 0;
  DateTime? _lastTap;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await LoggingService.configuration();
      final package = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _configuration = config;
          _package = package;
        });
      }
    } catch (error, stack) {
      await LoggingService.error(
        'diagnostics',
        'Loading options failed',
        error,
        stack,
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      await LoggingService.error(
        'diagnostics',
        'Diagnostic operation failed',
        error,
        stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.t('logsFailed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configure({
    bool? enabled,
    LogLevel? level,
    int? sizeMb,
    bool? developerMode,
  }) async {
    final config = await LoggingService.configure(
      enabled: enabled,
      level: level,
      sizeMb: sizeMb,
      developerMode: developerMode,
    );
    if (mounted) setState(() => _configuration = config);
  }

  void _tapBuild() {
    if (_busy || _configuration!.developerMode) return;
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 3)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    if (_taps >= 7) {
      _taps = 0;
      _run(() async {
        await _configure(developerMode: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('developerEnabled'))),
          );
        }
      });
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.t('logsCancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.t('logsContinue')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _export({required bool share, Rect? origin}) async {
    // TRACE may remain in a rotated file even after switching back to INFO.
    final config = await LoggingService.configuration();
    if (!mounted) return;
    if ((config.containsTrace || config.level == LogLevel.trace) &&
        !await _confirm(
          context.l10n.t('logsExport'),
          context.l10n.t('logsTraceExportWarning'),
        )) {
      return;
    }
    var includeCrashReports = false;
    if (config.crashReportCount > 0) {
      if (!mounted) return;
      final include = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.t('crashReportsExportTitle')),
          content: Text(context.l10n.t('crashReportsExportWarning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.t('crashReportsLogsOnly')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.t('crashReportsInclude')),
            ),
          ],
        ),
      );
      if (include == null) return;
      includeCrashReports = include;
    }
    final path = await LoggingService.export(
      includeCrashReports: includeCrashReports,
    );
    if (share) {
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/zip')],
        subject: 'Immich GeoTagger diagnostics',
        sharePositionOrigin: origin,
      );
    } else {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Immich GeoTagger logs',
        fileName: path.split(Platform.pathSeparator).last,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: await File(path).readAsBytes(),
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.t('logsSaved'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LoggingService.supported ||
        _configuration == null ||
        _package == null) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final config = _configuration!;
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('aboutApp'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Immich GeoTagger ${_package!.version}'),
              subtitle: Text('${l.t('buildNumber')}: ${_package!.buildNumber}'),
              onTap: _tapBuild,
            ),
            if (config.developerMode) ...[
              const Divider(),
              Text(
                l.t('developerOptions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(l.t('logsDescription')),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.t('logsEnabled')),
                value: config.enabled,
                onChanged: _busy
                    ? null
                    : (value) => _run(() => _configure(enabled: value)),
              ),
              DropdownButtonFormField<LogLevel>(
                key: ValueKey('level-${config.level}-$_busy'),
                initialValue: config.level,
                decoration: InputDecoration(labelText: l.t('logsLevel')),
                items: LogLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(level.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => _run(() async {
                        if (value == null) return;
                        if (value == LogLevel.trace &&
                            !await _confirm('TRACE', l.t('logsTraceWarning'))) {
                          return;
                        }
                        await _configure(level: value);
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('size-${config.sizeMb}-$_busy'),
                initialValue: config.sizeMb,
                decoration: InputDecoration(labelText: l.t('logsSize')),
                items: [5, 10, 20]
                    .map(
                      (size) => DropdownMenuItem(
                        value: size,
                        child: Text('$size MB'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => _run(() => _configure(sizeMb: value)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              final box =
                                  buttonContext.findRenderObject()
                                      as RenderBox?;
                              final origin = box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size;
                              _run(() => _export(share: true, origin: origin));
                            },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l.t('logsExport')),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _export(share: false)),
                    icon: const Icon(Icons.save_alt),
                    label: Text(l.t('gpxSaveButton')),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (!await _confirm(
                              l.t('logsClear'),
                              l.t('logsClearConfirm'),
                            )) {
                              return;
                            }
                            await LoggingService.clear();
                            await _load();
                          }),
                    child: Text(l.t('logsClear')),
                  ),
                ],
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _configure(
                          developerMode: false,
                          enabled: true,
                          level: LogLevel.info,
                        ),
                      ),
                child: Text(l.t('developerDisable')),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
