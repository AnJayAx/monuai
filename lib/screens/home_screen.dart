import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Sample data - replace with actual detection history
  final List<DetectionHistory> _detectionHistory = [
    DetectionHistory(landmark: 'Big Ben', timestamp: DateTime.now(), confidence: 0.95),
    DetectionHistory(landmark: 'Eiffel Tower', timestamp: DateTime.now().subtract(const Duration(hours: 1)), confidence: 0.87),
    DetectionHistory(landmark: 'Statue of Liberty', timestamp: DateTime.now().subtract(const Duration(hours: 2)), confidence: 0.92),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection History'),
        centerTitle: true,
      ),
      body: _detectionHistory.isEmpty
          ? const Center(
              child: Text('No detections yet. Start scanning!'),
            )
          : ListView.builder(
              itemCount: _detectionHistory.length,
              itemBuilder: (context, index) {
                final detection = _detectionHistory[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(detection.landmark),
                    subtitle: Text(
                      '${detection.timestamp.hour}:${detection.timestamp.minute.toString().padLeft(2, '0')} - Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DetectionHistory {
  final String landmark;
  final DateTime timestamp;
  final double confidence;

  DetectionHistory({
    required this.landmark,
    required this.timestamp,
    required this.confidence,
  });
}
