import 'package:flutter/material.dart';

import '../services/immich_service.dart';
import '../services/settings_service.dart';

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
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (mounted) setState(() => _status = 'Saved');
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _status = 'Testing…');
    try {
      final value = _value();
      await _immich.verifyConnection(value.immichUrl, value.apiKey);
      if (mounted) setState(() => _status = 'Immich connection successful');
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _url,
                    decoration: const InputDecoration(labelText: 'Immich URL', hintText: 'https://immich.example.com'),
                    keyboardType: TextInputType.url,
                    validator: (v) => (v == null || !v.startsWith('http')) ? 'Enter a valid http(s) URL' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _key,
                    decoration: const InputDecoration(labelText: 'Immich API key'),
                    obscureText: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'API key is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(controller: _retention, decoration: const InputDecoration(labelText: 'Keep location history (days)'), keyboardType: TextInputType.number, validator: _positiveInt),
                  const SizedBox(height: 12),
                  TextFormField(controller: _interval, decoration: const InputDecoration(labelText: 'Tracking interval (seconds)'), keyboardType: TextInputType.number, validator: _positiveInt),
                  const SizedBox(height: 12),
                  TextFormField(controller: _maxGap, decoration: const InputDecoration(labelText: 'Maximum interpolation gap (minutes)'), keyboardType: TextInputType.number, validator: _positiveInt),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                  TextButton(onPressed: _test, child: const Text('Test connection')),
                  if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
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
