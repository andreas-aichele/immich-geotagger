import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/tracking_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tracker = TrackingService();
  final _sync = SyncService();

  bool _busy = false;
  bool _tracking = false;
  int _points = 0;
  SyncResult? _lastSync;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final count = await DatabaseService.instance.locationCount();
    if (mounted) setState(() => _points = count);
  }

  Future<void> _toggleTracking() async {
    setState(() {
      _busy = true;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSync() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _sync.sync();
      await _refreshStats();
      if (!mounted) return;
      setState(() => _lastSync = result);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Immich GeoTagger',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Camera location timeline',
                style: TextStyle(color: Color(0xFF73737D), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }

  Widget _trackingHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _tracking
              ? const [Color(0xFF4E4ECD), Color(0xFF7777E8)]
              : const [Color(0xFF20202B), Color(0xFF363646)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A20202B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(active: _tracking),
              const Spacer(),
              Text(
                '${_points.toString()} points',
                style: const TextStyle(
                  color: Color(0xFFD8D8E3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _tracking ? 'Your route is being recorded.' : 'Ready for your next photo walk.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tracking
                ? 'GeoTagger keeps recording while the app is in the background.'
                : 'Start tracking before you begin shooting. You can leave the app afterwards.',
            style: const TextStyle(
              color: Color(0xFFD1D1DC),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF262632),
              ),
              onPressed: _busy ? null : _toggleTracking,
              icon: Icon(
                _tracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _tracking ? 'Stop tracking' : 'Start tracking',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncCard(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionEyebrow('Immich'),
          const SizedBox(height: 10),
          const Text(
            'Match & sync',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Photos without GPS are matched to your recorded timeline. Existing locations are never overwritten.',
            style: TextStyle(
              color: Color(0xFF686873),
              height: 1.45,
            ),
          ),
          if (_lastSync != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_lastSync!.updated} updated · '
                      '${_lastSync!.skippedWithLocation} already located · '
                      '${_lastSync!.skippedWithoutTrack} without safe match',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _runSync,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: const Text('Sync with Immich'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Updated photos'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF75E5AA) : const Color(0xFFB9B9C6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            active ? 'Tracking active' : 'Tracking stopped',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
