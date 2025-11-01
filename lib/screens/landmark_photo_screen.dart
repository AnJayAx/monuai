import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'recapture_screen.dart';

class LandmarkPhotoScreen extends StatefulWidget {
  final String landmark;
  final String imagePath;

  const LandmarkPhotoScreen({
    super.key,
    required this.landmark,
    required this.imagePath,
  });

  @override
  State<LandmarkPhotoScreen> createState() => _LandmarkPhotoScreenState();
}

class _LandmarkPhotoScreenState extends State<LandmarkPhotoScreen> {
  static const String _kDiscoveredKey = 'discovered_landmarks';
  static const String _kPhotosKey = 'landmark_photos';
  static const String _kConfirmedKey = 'confirmed_landmarks';
  static const String _kCapturedAtKey = 'landmark_captured_at';

  bool _working = false;
  bool _isConfirmed = false;
  String _description = '';
  late String _imagePath;
  Map<String, String> _assetDescriptions = const {};

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _loadConfirmedState();
  _loadDescriptions();
  }

  Future<void> _loadConfirmedState() async {
    final prefs = await SharedPreferences.getInstance();
    final confirmed = prefs.getStringList(_kConfirmedKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _isConfirmed = confirmed.contains(widget.landmark);
    });
  }

  Future<void> _loadDescriptions() async {
    try {
      // Load asset defaults once
      if (_assetDescriptions.isEmpty) {
        try {
          final assetStr = await rootBundle.loadString('assets/landmark_descriptions.json');
          final Map<String, dynamic> assetMap = jsonDecode(assetStr);
          _assetDescriptions = assetMap.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        } catch (_) {
          _assetDescriptions = const {};
        }
      }
      if (!mounted) return;
      setState(() {
        _description = _assetDescriptions[widget.landmark] ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _description = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.landmark),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Fixed-size image area
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Subtle blurred backdrop using the same image
                        Positioned.fill(
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Image.file(
                              File(_imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Foreground image fills box so small detections aren't tiny
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(_imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const Center(
                                  child: Text('Unable to load image'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isConfirmed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Landmark Confirmed',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                ),
              ),
            if (!_isConfirmed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working ? null : _onWrongPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _working
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Incorrect'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _working ? null : _onConfirmPressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _working
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Confirm'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _working ? null : _onRecapturePressed,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Recapture'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _buildDescriptionWidget(),
                ],
              ),
            ),
            // Spacer to push buttons to bottom if content is short
            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: null,
    );
  }

  Future<void> _onConfirmPressed() async {
    setState(() => _working = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure landmark is in discovered list
      final list = prefs.getStringList(_kDiscoveredKey) ?? <String>[];
      if (!list.contains(widget.landmark)) {
        list.add(widget.landmark);
        await prefs.setStringList(_kDiscoveredKey, list);
      }
      // Mark as confirmed
      final confirmed = prefs.getStringList(_kConfirmedKey) ?? <String>[];
      if (!confirmed.contains(widget.landmark)) {
        confirmed.add(widget.landmark);
        await prefs.setStringList(_kConfirmedKey, confirmed);
      }
      // Ensure photo mapping is saved
  final photoMap = await _readPhotoMap(prefs);
  photoMap[widget.landmark] = _imagePath;
      await prefs.setString(_kPhotosKey, jsonEncode(photoMap));

      // Save/Update captured timestamp
      final capturedMap = await _readCapturedMap(prefs);
      capturedMap[widget.landmark] = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_kCapturedAtKey, jsonEncode(capturedMap));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Landmark confirmed')),
        );
        setState(() {
          _isConfirmed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _onWrongPressed() async {
    // Ask for confirmation first
    final confirmedChoice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this progress?'),
        content: const Text('This will remove the detected landmark and delete the image.'),
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

    if (confirmedChoice != true) return;

    setState(() => _working = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove from discovered list
      final list = prefs.getStringList(_kDiscoveredKey) ?? <String>[];
      list.remove(widget.landmark);
      await prefs.setStringList(_kDiscoveredKey, list);

      // Remove from confirmed list as well
      final confirmed = prefs.getStringList(_kConfirmedKey) ?? <String>[];
      confirmed.remove(widget.landmark);
      await prefs.setStringList(_kConfirmedKey, confirmed);

      // Remove photo mapping and delete file if it matches
      final photoMap = await _readPhotoMap(prefs);
      final storedPath = photoMap[widget.landmark];
      photoMap.remove(widget.landmark);
      await prefs.setString(_kPhotosKey, jsonEncode(photoMap));

  // Remove captured timestamp
  final capturedMap = await _readCapturedMap(prefs);
  capturedMap.remove(widget.landmark);
  await prefs.setString(_kCapturedAtKey, jsonEncode(capturedMap));

      // Best-effort delete file
      try {
        final toDelete = storedPath ?? _imagePath;
        if (toDelete.isNotEmpty) {
          final f = File(toDelete);
          if (await f.exists()) {
            await f.delete();
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as wrong and removed')),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Map<String, String>> _readPhotoMap(SharedPreferences prefs) async {
    try {
      final photosJson = prefs.getString(_kPhotosKey);
      if (photosJson == null) return <String, String>{};
      final decoded = jsonDecode(photosJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  // Editing of description is disabled by request; only asset text is shown.

  Future<void> _onRecapturePressed() async {
    if (_working) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecaptureScreen(landmark: widget.landmark),
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _working = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final photoMap = await _readPhotoMap(prefs);
      final prev = photoMap[widget.landmark];
      photoMap[widget.landmark] = result;
      await prefs.setString(_kPhotosKey, jsonEncode(photoMap));

  // Update captured timestamp on recapture
  final capturedMap = await _readCapturedMap(prefs);
  capturedMap[widget.landmark] = DateTime.now().toUtc().toIso8601String();
  await prefs.setString(_kCapturedAtKey, jsonEncode(capturedMap));

      if (prev != null && prev.isNotEmpty && prev != result) {
        try {
          final f = File(prev);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _imagePath = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Map<String, String>> _readCapturedMap(SharedPreferences prefs) async {
    try {
      final jsonStr = prefs.getString(_kCapturedAtKey);
      if (jsonStr == null) return <String, String>{};
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  Widget _buildDescriptionWidget() {
    final text = _description.isNotEmpty
        ? _description
        : 'No description available for ${widget.landmark}.';

    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
        );
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);

    // Simple markdown-like parser for **bold** segments
    final spans = <TextSpan>[];
    final pattern = RegExp(r"\*\*(.+?)\*\*");
    int start = 0;
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    for (final m in matches) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: baseStyle));
      }
      spans.add(TextSpan(text: m.group(1) ?? '', style: boldStyle));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans, style: baseStyle));
  }
}
