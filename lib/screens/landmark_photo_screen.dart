import 'dart:io';
import 'package:flutter/material.dart';

class LandmarkPhotoScreen extends StatelessWidget {
  final String landmark;
  final String imagePath;

  const LandmarkPhotoScreen({
    super.key,
    required this.landmark,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(landmark),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) {
                      return const Center(
                        child: Text('Unable to load image'),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
