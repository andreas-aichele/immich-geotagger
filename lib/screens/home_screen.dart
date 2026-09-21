import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/settings_service.dart';
import '../services/tracking_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'sync_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _tracker = TrackingService();
  final _sync = SyncService();
  final _settings = SettingsService();

  bool _trackingBusy = false;
  bool _syncBusy = false;
  bool _tracking = false;
  int _points = 0;
  SyncResult? _lastSync;
  String? _error;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStats();
    _restoreTracking();
    _statsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshStats(),
    );
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreTracking();
    }
  }

  Future<void> _restoreTracking() async {
    try {
      final desired = await _settings.isTrackingDesired();
      final backgroundActive = await _tracker.isBackgroundModeEnabled();

      if (desired && !backgroundActive) {
        await _tracker.resumeIfNeeded();
      }

      final active = desired &&
          (await _tracker.isBackgroundModeEnabled() || await _tracker.isTracking);

      if (mounted) {
        setState(() => _tracking = active);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _refreshStats() async {
    final count = await DatabaseService.instance.locationCount();
    if (mounted) setState(() => _points = count);
  }

  Future<void> _toggleTracking() async {
    setState(() {
      _trackingBusy = true;
      _error = null;
    });

    try {
      if (_tracking) {
        await _tracker.stop();
      } else {
        await _tracker.start();
      }
      if (!mounted) return;
      setState(() => _tracking = !_tracking);
      await _refreshStats();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _trackingBusy = false);
    }
  }

  Future<void> _runSync() async {
    setState(() {
      _syncBusy = true;
      _error = null;
    });

    try {
      final preview = await _sync.prepareSync();
      if (!mounted) return;

      setState(() => _syncBusy = false);

      final result = await Navigator.of(context).push<SyncResult>(
        MaterialPageRoute(
          builder: (_) => SyncPreviewScreen(preview: preview),
        ),
      );

      if (!mounted || result == null) return;
      await _refreshStats();
      if (!mounted) return;
      setState(() => _lastSync = result);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted && _syncBusy) setState(() => _syncBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              _header(context),
              const SizedBox(height: 28),
              _trackingHero(context),
              const SizedBox(height: 16),
              _cameraClockTip(context),
              const SizedBox(height: 16),
              _syncCard(context),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _errorCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('appName'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.t('appSubtitle'),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: l.t('settings'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }

  Widget _trackingHero(BuildContext context) {
    final l = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = _tracking ? Colors.white : AppTheme.ink;
    final secondary = _tracking
        ? Colors.white.withValues(alpha: 0.78)
        : AppTheme.muted;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _tracking ? primary : AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _tracking ? primary : const Color(0xFFDCEEFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(active: _tracking),
              const Spacer(),
              Text(
                l.t('points', {'count': _points}),
                style: TextStyle(
                  color: secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            _tracking
                ? l.t('trackingHeroActive')
                : l.t('trackingHeroStopped'),
            style: TextStyle(
              color: foreground,
              fontSize: 27,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tracking
                ? l.t('trackingHeroActiveDesc')
                : l.t('trackingHeroStoppedDesc'),
            style: TextStyle(
              color: secondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _tracking ? Colors.white : primary,
                foregroundColor: _tracking ? primary : Colors.white,
              ),
              onPressed: _trackingBusy ? null : _toggleTracking,
              icon: Icon(
                _tracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _tracking ? l.t('stopTracking') : l.t('startTracking'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraClockTip(BuildContext context) {
    final l = context.l10n;
    return AppSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showCameraClockSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('cameraTimeTipTitle'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.t('cameraTimeTipCompact'),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCameraClockSheet(BuildContext context) async {
    final l = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('cameraTimeTipTitle'),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.t('cameraTimeTipBody'),
              style: const TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const _PhoneClock(),
          ],
        ),
      ),
    );
  }

  Widget _syncCard(BuildContext context) {
    final l = context.l10n;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionEyebrow(l.t('immich')),
          const SizedBox(height: 10),
          Text(
            l.t('matchSync'),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.t('matchSyncDesc'),
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
            ),
          ),
          if (_lastSync != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.t(
                        'syncSummary',
                        {
                          'updated': _lastSync!.updated,
                          'located': _lastSync!.skippedWithLocation,
                          'unmatched': _lastSync!.skippedWithoutTrack,
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _syncBusy ? null : _runSync,
            icon: _syncBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(l.t('syncWithImmich')),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l.t('updatedPhotos')),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = active ? Colors.white : primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFCFE6FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF7ED9A7) : primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            active ? l.t('trackingActive') : l.t('trackingStopped'),
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _PhoneClock extends StatefulWidget {
  const _PhoneClock();

  @override
  State<_PhoneClock> createState() => _PhoneClockState();
}

class _PhoneClockState extends State<_PhoneClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _utcOffset(Duration offset) {
    final negative = offset.isNegative;
    final absolute = offset.abs();
    final hours = absolute.inHours;
    final minutes = absolute.inMinutes.remainder(60);
    return 'UTC${negative ? '-' : '+'}${_twoDigits(hours)}:${_twoDigits(minutes)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final time =
        '${_twoDigits(_now.hour)}:${_twoDigits(_now.minute)}:${_twoDigits(_now.second)}';
    final zone = _now.timeZoneName;
    final offset = _utcOffset(_now.timeZoneOffset);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCEEFF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_android_rounded,
            size: 20,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('phoneTime'),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$zone · $offset',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
