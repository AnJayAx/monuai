import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Pref keys
  static const String _kPrefUseGpu = 'use_gpu_delegate';
  static const String _kPrefStartOnScan = 'start_on_scan';

  bool _useGpu = true;
  bool _startOnScan = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useGpu = prefs.getBool(_kPrefUseGpu) ?? true;
      _startOnScan = prefs.getBool(_kPrefStartOnScan) ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // No integer prefs currently used.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Detection Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Use GPU Acceleration'),
            subtitle: const Text('Faster inference when supported'),
            value: _useGpu,
            onChanged: (v) {
              setState(() => _useGpu = v);
              _saveBool(_kPrefUseGpu, v);
            },
          ),
          // Moved Show Boxes and Notify toggles to Scan page controls
          const SizedBox(height: 24),
          const Text(
            'App Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Start on Scan tab'),
            value: _startOnScan,
            onChanged: (v) {
              setState(() => _startOnScan = v);
              _saveBool(_kPrefStartOnScan, v);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'App Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
          const ListTile(
            title: Text('Model Version'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  // Reset action moved to Home screen AppBar.
}
