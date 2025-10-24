import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableNotifications = true;
  bool _enableRealTimeDetection = true;
  double _confidenceThreshold = 0.7;

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
            title: const Text('Enable Real-Time Detection'),
            value: _enableRealTimeDetection,
            onChanged: (value) {
              setState(() {
                _enableRealTimeDetection = value;
              });
            },
          ),
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
          const Text(
            'Confidence Threshold',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _confidenceThreshold,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(_confidenceThreshold * 100).toStringAsFixed(0)}%',
            onChanged: (value) {
              setState(() {
                _confidenceThreshold = value;
              });
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
}
