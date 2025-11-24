import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/upload_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'recapture_screen.dart';
import '../services/gamification_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

// Detection class for model output
class _Detection {
  final Rect boundingBox;
  final String label;
  final double confidence;

  _Detection({
    required this.boundingBox,
    required this.label,
    required this.confidence,
  });
}

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
  String? _annotatedImagePath;
  Map<String, String> _assetDescriptions = const {};
  bool _isProcessing = false;
  Interpreter? _interpreter;
  List<String> _landmarkNames = [];

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _loadConfirmedState();
    _loadDescriptions();
    _loadModelAndPredict();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
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
          final assetStr = await rootBundle.loadString(
            'assets/landmark_descriptions.json',
          );
          final Map<String, dynamic> assetMap = jsonDecode(assetStr);
          _assetDescriptions = assetMap.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
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

  Future<void> _loadModelAndPredict() async {
    setState(() => _isProcessing = true);
    
    try {
      // Load landmark names
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _landmarkNames = labelsData.split('\n').where((l) => l.isNotEmpty).toList();
      
      // Load TFLite model with GPU
      final gpuOptions = InterpreterOptions()
        ..addDelegate(GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: true,
          ),
        ));
      _interpreter = await Interpreter.fromAsset(
        'assets/models/model_fp32_student.tflite',
        options: gpuOptions,
      );
      
      debugPrint('Model loaded in landmark_photo_screen');
      
      // Run prediction on the original image
      await _predictAndDrawBoundingBox();
    } catch (e) {
      debugPrint('Failed to load model or predict: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _predictAndDrawBoundingBox() async {
    if (_interpreter == null) return;
    
    try {
      // Load and decode the original image
      final bytes = await File(_imagePath).readAsBytes();
      final source = img.decodeImage(bytes);
      if (source == null) {
        debugPrint('Failed to decode image');
        return;
      }
      
      // Resize image to 640x640 for model input
      final resized = img.copyResize(source, width: 640, height: 640);
      
      // Convert to Float32List (grayscale)
      final inputBuffer = Float32List(640 * 640 * 3);
      int index = 0;
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = resized.getPixel(x, y);
          final gray = (pixel.r + pixel.g + pixel.b) / 3.0 / 255.0;
          inputBuffer[index++] = gray;
          inputBuffer[index++] = gray;
          inputBuffer[index++] = gray;
        }
      }
      
      // Run inference
      final outputBuffer = Uint8List(1 * 8 * 8400 * 4);
      _interpreter!.run(inputBuffer.buffer.asUint8List(), outputBuffer);
      
      // Parse output
      final outputFloats = Float32List.view(outputBuffer.buffer);
      final detections = <_Detection>[];
      
      for (int i = 0; i < 8400; i++) {
        double maxConfidence = 0.0;
        int detectedClass = 0;
        
        for (int cls = 4; cls < 8; cls++) {
          final confidence = outputFloats[cls * 8400 + i];
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            detectedClass = cls - 4;
          }
        }
        
        if (maxConfidence >= 0.5) {
          final xCenter = outputFloats[0 * 8400 + i];
          final yCenter = outputFloats[1 * 8400 + i];
          final width = outputFloats[2 * 8400 + i];
          final height = outputFloats[3 * 8400 + i];
          
          final left = (xCenter - width / 2) * 640;
          final top = (yCenter - height / 2) * 640;
          final right = (xCenter + width / 2) * 640;
          final bottom = (yCenter + height / 2) * 640;
          
          detections.add(_Detection(
            boundingBox: Rect.fromLTRB(
              left.clamp(0, 640),
              top.clamp(0, 640),
              right.clamp(0, 640),
              bottom.clamp(0, 640),
            ),
            label: _landmarkNames[detectedClass],
            confidence: maxConfidence,
          ));
        }
      }
      
      // Find detection for this landmark
      final targetDetection = detections.firstWhere(
        (d) => d.label == widget.landmark,
        orElse: () => detections.isNotEmpty ? detections.first : _Detection(
          boundingBox: const Rect.fromLTRB(100, 100, 540, 540),
          label: widget.landmark,
          confidence: 0.0,
        ),
      );
      
      // Draw bounding box on the image
      await _drawBoundingBoxOnImage(source, targetDetection);
    } catch (e) {
      debugPrint('Prediction error: $e');
    }
  }

  Future<void> _drawBoundingBoxOnImage(img.Image source, _Detection detection) async {
    try {
      final annotated = img.Image.from(source);
      
      // Scale coordinates from 640x640 to actual image size
      final srcW = source.width.toDouble();
      final srcH = source.height.toDouble();
      const modelSize = 640.0;
      final sx = srcW / modelSize;
      final sy = srcH / modelSize;
      
      final left = (detection.boundingBox.left * sx).round();
      final top = (detection.boundingBox.top * sy).round();
      final right = (detection.boundingBox.right * sx).round();
      final bottom = (detection.boundingBox.bottom * sy).round();
      
      // Draw green bounding box
      final boxColor = img.ColorRgb8(76, 175, 80);
      img.drawRect(
        annotated,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: boxColor,
        thickness: 4,
      );
      
      // Draw label
      final labelText = '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final labelHeight = 30;
      final labelWidth = labelText.length * 12;
      
      img.fillRect(
        annotated,
        x1: left,
        y1: math.max(0, top - labelHeight),
        x2: left + labelWidth,
        y2: top,
        color: boxColor,
      );
      
      img.drawString(
        annotated,
        labelText,
        font: img.arial24,
        x: left + 5,
        y: math.max(0, top - labelHeight + 5),
        color: img.ColorRgb8(255, 255, 255),
      );
      
      // Save annotated image to temp location
      final jpg = img.encodeJpg(annotated, quality: 95);
      final dir = File(_imagePath).parent.path;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final annotatedPath = '$dir/temp_annotated_$stamp.jpg';
      await File(annotatedPath).writeAsBytes(jpg, flush: true);
      
      if (mounted) {
        setState(() {
          _annotatedImagePath = annotatedPath;
        });
        debugPrint('Bounding box drawn and saved to: $annotatedPath');
      }
    } catch (e) {
      debugPrint('Failed to draw bounding box: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.landmark), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Fixed-size image area
              Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
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
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 8,
                                sigmaY: 8,
                              ),
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
                                child: _isProcessing
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 12),
                                          Text(
                                            'Detecting landmark...',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Image.file(
                                      File(_annotatedImagePath ?? _imagePath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const Center(
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
              // Status display - show auto-confirmation message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Landmark Auto-Captured & Confirmed',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildDescriptionWidget(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Landmark confirmed')));
        // Log to terminal for debugging confirmation step
        debugPrint('[Confirm] landmark="${widget.landmark}" path="$_imagePath"');
        setState(() {
          _isConfirmed = true;
        });
      }

      // Fire-and-forget upload to admin if configured
      unawaited(_uploadConfirmedImageIfConfigured());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to confirm: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _uploadConfirmedImageIfConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var url = prefs.getString('server_upload_url');
      if (url == null || url.trim().isEmpty) {
        // Provide a sensible default: Android emulator uses 10.0.2.2
        if (Platform.isAndroid) {
          url = 'http://10.0.2.2:5000/upload';
        } else {
          url = 'http://127.0.0.1:5000/upload';
        }
        debugPrint('[Upload] server_upload_url not set, using default: $url');
      }

      final uri = Uri.parse(url);
      final file = File(_imagePath);

      // Use capturedAt saved in prefs if present
      final capturedMap = await _readCapturedMap(prefs);
      final capturedStr = capturedMap[widget.landmark];
      final capturedAt = capturedStr != null
          ? DateTime.tryParse(capturedStr) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();

      // Pre-upload log with file size best-effort
      int? size;
      try { size = await file.length(); } catch (_) {}
      debugPrint('[Upload] start url=$uri landmark="${widget.landmark}" capturedAt=$capturedAt fileSize=${size ?? 'unknown'}');

      final result = await UploadService.uploadImage(
        uploadUrl: uri,
        file: file,
        landmark: widget.landmark,
        capturedAt: capturedAt,
      );

      if (!mounted) return;
      final bodyPreview = (result.body ?? '').trim();
      final shortened = bodyPreview.length > 300 ? '${bodyPreview.substring(0, 300)}…' : bodyPreview;
      debugPrint('[Upload] done ok=${result.ok} status=${result.statusCode} bodyPreview="$shortened"');
      if (result.ok) {
        // Award points for photo upload
        try {
          final userStats = await GamificationService.loadUserStats();
          await GamificationService.recordPhotoUpload(userStats);
        } catch (_) {}
        
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploaded to admin +25 points!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed (${result.statusCode}): ${result.body ?? ''}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Upload] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  Future<void> _onWrongPressed() async {
    // Ask for confirmation first
    final confirmedChoice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this progress?'),
        content: const Text(
          'This will remove the detected landmark and delete the image.',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
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
      color: Theme.of(
        context,
      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
        spans.add(
          TextSpan(text: text.substring(start, m.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: m.group(1) ?? '', style: boldStyle));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }
}
