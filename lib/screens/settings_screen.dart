import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableNotifications = true;
  static const String _kDiscoveredKey = 'discovered_landmarks';
  static const String _kPhotosKey = 'landmark_photos';

  @override
  void initState() {
    super.initState();
  }

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
            title: const Text('Enable Notifications'),
            value: _enableNotifications,
            onChanged: (value) {
              setState(() {
                _enableNotifications = value;
              });
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Delete all detected landmarks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Clear visited progress and stored photos.'),
            onTap: _confirmResetProgress,
          ),
          const SizedBox(height: 16),
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

  Future<void> _confirmResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset detected progress?'),
        content: const Text(
          'This will delete all visited progress and any stored photos associated with detected landmarks. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Delete stored photo files if present
      final photosJson = prefs.getString(_kPhotosKey);
      if (photosJson != null) {
        try {
          final Map<String, dynamic> map = jsonDecode(photosJson);
          for (final entry in map.entries) {
            final path = entry.value?.toString();
            if (path != null && path.isNotEmpty) {
              try {
                final f = File(path);
                if (await f.exists()) {
                  await f.delete();
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      await prefs.remove(_kDiscoveredKey);
      await prefs.remove(_kPhotosKey);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All detected progress has been cleared.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset progress: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
