import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/tracking_service.dart';
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
    setState(() { _busy = true; _error = null; });
    try {
      if (_tracking) {
        await _tracker.stop();
      } else {
        await _tracker.start();
      }
      setState(() => _tracking = !_tracking);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSync() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _sync.sync();
      await _refreshStats();
      setState(() => _lastSync = result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immich GeoTagger'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_tracking ? 'Tracking active' : 'Tracking stopped', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Stored location points: $_points'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _toggleTracking,
                    icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                    label: Text(_tracking ? 'Stop tracking' : 'Start tracking'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Immich sync', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Only image assets without GPS coordinates are changed. A position is calculated only between two recorded points.'),
                  if (_lastSync != null) ...[
                    const SizedBox(height: 12),
                    Text('Last sync: ${_lastSync!.updated} updated, ${_lastSync!.skippedWithLocation} already located, ${_lastSync!.skippedWithoutTrack} without safe match.'),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(onPressed: _busy ? null : _runSync, icon: const Icon(Icons.sync), label: const Text('Sync now')),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Updated photos'),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
