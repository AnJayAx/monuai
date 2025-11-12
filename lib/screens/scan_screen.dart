import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// Converts a CameraImage to a float32 Uint8List buffer for model input
Uint8List cameraImageToFloat32List(
  CameraImage image,
  int outHeight,
  int outWidth,
) {
  final int inputSize = outHeight * outWidth * 3;
  final Float32List floatList = Float32List(inputSize);

  // Camera image size
  final int inHeight = image.height;
  final int inWidth = image.width;

  int index = 0;
  for (int y = 0; y < outHeight; y++) {
    for (int x = 0; x < outWidth; x++) {
      int srcX, srcY;

      // If source image is landscape but output is portrait, swap axes.
      if (inWidth > inHeight) {
        // Portrait output, camera in landscape: rotate left!
        srcX = (y * inWidth ~/ outHeight); // <- swapped!
        srcY =
            (outWidth - x - 1) *
            inHeight ~/
            outWidth; // y axis flip for clockwise rotation
      } else {
        // No rotation needed, normal mapping
        srcX = x * inWidth ~/ outWidth;
        srcY = y * inHeight ~/ outHeight;
      }

      final int pxIdx = srcY * inWidth + srcX;
      final yByte = image.planes[0].bytes[pxIdx];
      final val = yByte / 255.0;
      floatList[index++] = val; // R
      floatList[index++] = val; // G
      floatList[index++] = val; // B
    }
  }

  return floatList.buffer.asUint8List();
}

class Detection {
  final Rect boundingBox;
  final String label;
  final double confidence;

  Detection({
    required this.boundingBox,
    required this.label,
    required this.confidence,
  });
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _modelLoaded = false;
  bool _isProcessing = false;
  bool _isDisposed = false;
  int _frameCount = 0;
  // Preferences
  static const String _kPrefUseGpu = 'use_gpu_delegate';
  static const String _kPrefShowBoxes = 'show_boxes';
  static const String _kPrefNotify = 'notify_on_detection';
  bool _useGpu = true;
  bool _showBoxes = true;
  bool _notifyOnDetection = true;
  final int _frameStride = 15;

  List<Detection> _detections = [];
  // Overlay threshold controls what boxes are drawn; discovery requires higher confidence
  static const double _overlayThreshold = 0.7;
  static const double _discoveryThreshold = 0.8;
  static const String _kDiscoveredKey = 'discovered_landmarks';
  static const String _kPhotosKey = 'landmark_photos';

  Interpreter? _interpreter;

  final List<String> _landmarkNames = [
    'Art Science Museum',
    'Esplanade',
    'Marina Bay Sands',
    'Merlion',
  ];

  // Persisted + session memory to avoid duplicate toasts
  Set<String> _discovered = <String>{};
  final Set<String> _sessionNotified = <String>{};
  bool _isCapturing = false;
  late void Function(CameraImage) _imageStreamHandler;

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _loadModel());
    _imageStreamHandler = _onImageFromStream;
    _initializeCamera();
    _loadDiscovered();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useGpu = prefs.getBool(_kPrefUseGpu) ?? true;
      _showBoxes = prefs.getBool(_kPrefShowBoxes) ?? true;
      _notifyOnDetection = prefs.getBool(_kPrefNotify) ?? true;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadDiscovered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDiscoveredKey) ?? <String>[];
      _discovered = list.toSet();
    } catch (e) {
      debugPrint('Failed to load discovered landmarks: $e');
    }
  }

  // Confidence threshold is fixed via constants; no user-configurable threshold.

  Future<void> _loadModel() async {
    try {
      if (_useGpu) {
        final gpuOptions = InterpreterOptions()..addDelegate(GpuDelegateV2());
        _interpreter = await Interpreter.fromAsset(
          'assets/models/model_fp32_student.tflite',
          options: gpuOptions,
        );
        setState(() {
          _modelLoaded = true;
          debugPrint('✓ Model loaded with GPU acceleration');
        });
        debugPrint('✓ Model loaded with GPU acceleration');
      } else {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/model_fp32_student.tflite',
        );
        setState(() {
          _modelLoaded = true;
          debugPrint('✓ Model loaded (CPU)');
        });
      }
    } catch (e) {
      debugPrint('GPU failed, trying CPU: $e');
      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/model_fp32_student.tflite',
        );
        setState(() {
          _modelLoaded = true;
          debugPrint('✓ Model loaded (CPU)\nPoint at landmark');
        });
      } catch (e2) {
        setState(() {
          debugPrint('Model load failed: $e2');
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          debugPrint('No camera found');
        });
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        _cameraController.startImageStream(_imageStreamHandler);
      }
    } catch (e) {
      setState(() {
        debugPrint('Camera error: $e');
      });
    }
  }

  void _onImageFromStream(CameraImage cameraImage) {
    if (_isDisposed) return;
    if (!_isProcessing &&
        _modelLoaded &&
        !_isCapturing &&
        _interpreter != null) {
      _isProcessing = true;
      _runInference(cameraImage);
    }
  }

  Future<void> _runInference(CameraImage cameraImage) async {
    if (_isDisposed || _interpreter == null) {
      _isProcessing = false;
      return;
    }
    final stopwatchTotal = Stopwatch()..start();

    try {
      if (_frameCount++ % _frameStride != 0) {
        _isProcessing = false;
        return;
      }

      final stopwatchPre = Stopwatch()..start();
      final Uint8List inputBuffer = cameraImageToFloat32List(
        cameraImage,
        640,
        640,
      );
      stopwatchPre.stop();
      debugPrint('Pre-processing: ${stopwatchPre.elapsedMilliseconds} ms');

      final Uint8List outputBuffer = Uint8List(1 * 8 * 8400 * 4);

      final stopwatchInference = Stopwatch()..start();
      // Double-check interpreter is still valid before running
      final localInterpreter = _interpreter;
      if (_isDisposed || localInterpreter == null) {
        _isProcessing = false;
        return;
      }
      localInterpreter.run(inputBuffer, outputBuffer);
      stopwatchInference.stop();
      debugPrint('Inference: ${stopwatchInference.elapsedMilliseconds} ms');

      _processOutput(outputBuffer);

      stopwatchTotal.stop();
      debugPrint(
        'Total predict: ${stopwatchPre.elapsedMilliseconds + stopwatchInference.elapsedMilliseconds} ms',
      );
      debugPrint('Total elapsed: ${stopwatchTotal.elapsedMilliseconds} ms');
    } catch (e) {
      debugPrint('Inference error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _processOutput(Uint8List outputBuffer) {
    // Convert Uint8List to Float32List
    final Float32List outputFloats = outputBuffer.buffer.asFloat32List();

    List<Detection> newDetections = [];

    // Parse the flat output: shape is [1, 8, 8400]
    // Flat index: cls * 8400 + i
    for (int i = 0; i < 8400; i++) {
      double maxConfidence = 0.0;
      int detectedClass = -1;

      // Check classes 4-7 (indices 4, 5, 6, 7)
      for (int cls = 4; cls < 8; cls++) {
        double confidence = outputFloats[cls * 8400 + i];
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedClass = cls - 4;
        }
      }

      if (maxConfidence >= _overlayThreshold) {
        // Extract bounding box coordinates
        double xCenter = outputFloats[0 * 8400 + i];
        double yCenter = outputFloats[1 * 8400 + i];
        double width = outputFloats[2 * 8400 + i];
        double height = outputFloats[3 * 8400 + i];

        double left = (xCenter - width / 2) * 640;
        double top = (yCenter - height / 2) * 640;
        double right = (xCenter + width / 2) * 640;
        double bottom = (yCenter + height / 2) * 640;

        newDetections.add(
          Detection(
            boundingBox: Rect.fromLTRB(
              left.clamp(0, 640),
              top.clamp(0, 640),
              right.clamp(0, 640),
              bottom.clamp(0, 640),
            ),
            label: _landmarkNames[detectedClass],
            confidence: maxConfidence,
          ),
        );
      }
    }

    // Apply Non-Maximum Suppression
    List<Detection> filteredDetections = nonMaximumSuppression(
      newDetections,
      0.5,
    );

    if (mounted) {
      setState(() {
        _detections = filteredDetections;
        if (filteredDetections.isNotEmpty) {
          debugPrint('${filteredDetections.length} landmark(s) detected');
        } else {
          debugPrint('No landmark detected');
        }
      });

      // Check for new landmarks and persist + notify once
      _handleNewLandmarks(filteredDetections);
    }
  }

  Future<void> _handleNewLandmarks(List<Detection> detections) async {
    if (detections.isEmpty) return;

    // Compute max confidence per label in this frame
    final Map<String, double> labelMax = {};
    for (final d in detections) {
      final cur = labelMax[d.label] ?? 0.0;
      if (d.confidence > cur) labelMax[d.label] = d.confidence;
    }
    final List<String> newlyFound = [];

    for (final e in labelMax.entries) {
      if (e.value >= _discoveryThreshold && !_discovered.contains(e.key)) {
        _discovered.add(e.key);
        newlyFound.add(e.key);
      }
    }

    if (newlyFound.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kDiscoveredKey, _discovered.toList());
    } catch (e) {
      debugPrint('Failed to persist discovered landmarks: $e');
    }

    // Notify user only once per label per session; show the first new label prominently
    final firstNew = newlyFound.firstWhere(
      (l) => !_sessionNotified.contains(l),
      orElse: () => newlyFound.first,
    );
    if (_notifyOnDetection && !_sessionNotified.contains(firstNew) && mounted) {
      _sessionNotified.add(firstNew);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New landmark detected: $firstNew'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Capture once and create per-landmark cropped images for all newly found labels in this frame
    if (!_isCapturing) {
      // Build best detection per newly found label (highest confidence)
      final Map<String, Detection> best = {};
      for (final d in detections) {
        if (!newlyFound.contains(d.label)) continue;
        final prev = best[d.label];
        if (prev == null || d.confidence > prev.confidence) {
          best[d.label] = d;
        }
      }
      await _captureAndStoreCropsForLabels(best);
    }
  }

  Future<void> _captureAndStoreCropsForLabels(
    Map<String, Detection> labelDetections,
  ) async {
    if (!_isCameraInitialized) return;
    if (_isCapturing) return;

    _isCapturing = true;
    try {
      await _cameraController.stopImageStream();
      final picture = await _cameraController.takePicture();
      final photoPath = picture.path;

      // Read image and prepare crops
      img.Image? source;
      try {
        final bytes = await File(photoPath).readAsBytes();
        source = img.decodeImage(bytes);
      } catch (e) {
        debugPrint('Failed to decode captured image: $e');
      }

      // Save path into map in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPhotosKey);
      Map<String, dynamic> map = <String, dynamic>{};
      if (jsonStr != null) {
        try {
          map = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (source != null) {
        final srcW = source.width.toDouble();
        final srcH = source.height.toDouble();
        const modelSize = 640.0;
        final sx = srcW / modelSize;
        final sy = srcH / modelSize;

        for (final entry in labelDetections.entries) {
          final label = entry.key;
          final det = entry.value;

          // Compute crop rect in photo coordinates with 10% padding
          double left = det.boundingBox.left * sx;
          double top = det.boundingBox.top * sy;
          double right = det.boundingBox.right * sx;
          double bottom = det.boundingBox.bottom * sy;

          final padX = ((right - left) * 0.1);
          final padY = ((bottom - top) * 0.1);
          left = (left - padX).clamp(0.0, srcW - 1);
          top = (top - padY).clamp(0.0, srcH - 1);
          right = (right + padX).clamp(1.0, srcW);
          bottom = (bottom + padY).clamp(1.0, srcH);

          int x = left.round();
          int y = top.round();
          int w = (right - left).round();
          int h = (bottom - top).round();

          // Ensure valid non-zero crop
          if (w <= 0 || h <= 0) {
            // Fallback to full photo for this label
            final existing = map[label]?.toString();
            if (existing == null || existing.isEmpty) {
              map[label] = photoPath;
            }
            continue;
          }

          img.Image cropped;
          try {
            cropped = img.copyCrop(source, x: x, y: y, width: w, height: h);
          } catch (e) {
            debugPrint('Crop failed for $label: $e');
            final existing = map[label]?.toString();
            if (existing == null || existing.isEmpty) {
              map[label] = photoPath;
            }
            continue;
          }

          final jpg = img.encodeJpg(cropped, quality: 90);
          final dir = File(photoPath).parent.path;
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final safe = _slugify(label);
          final outPath = '$dir/${safe}_$stamp.jpg';
          try {
            await File(outPath).writeAsBytes(jpg, flush: true);
            final existing = map[label]?.toString();
            if (existing == null || existing.isEmpty) {
              map[label] = outPath;
            }
          } catch (e) {
            debugPrint('Failed to write crop for $label: $e');
            final existing = map[label]?.toString();
            if (existing == null || existing.isEmpty) {
              map[label] = photoPath;
            }
          }
        }
      } else {
        // Fallback: associate full photo with all labels
        for (final label in labelDetections.keys) {
          final existing = map[label]?.toString();
          if (existing == null || existing.isEmpty) {
            map[label] = photoPath;
          }
        }
      }
      await prefs.setString(_kPhotosKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Failed to capture/store photo: $e');
    } finally {
      // Resume image stream
      try {
        await _cameraController.startImageStream(_imageStreamHandler);
      } catch (e) {
        debugPrint('Failed to restart image stream: $e');
      }
      _isCapturing = false;
    }
  }

  String _slugify(String input) {
    final lower = input.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  // Computes Intersection over Union between two Rects
  double _iou(Rect a, Rect b) {
    double intersectionLeft = math.max(a.left, b.left);
    double intersectionTop = math.max(a.top, b.top);
    double intersectionRight = math.min(a.right, b.right);
    double intersectionBottom = math.min(a.bottom, b.bottom);

    double intersectionArea =
        math.max(0, intersectionRight - intersectionLeft) *
        math.max(0, intersectionBottom - intersectionTop);
    double aArea = (a.right - a.left) * (a.bottom - a.top);
    double bArea = (b.right - b.left) * (b.bottom - b.top);

    return intersectionArea / (aArea + bArea - intersectionArea);
  }

  // Applies Non-Maximum Suppression on list of detections with IoU threshold
  List<Detection> nonMaximumSuppression(
    List<Detection> detections,
    double iouThreshold,
  ) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<Detection> filtered = [];

    for (var detection in detections) {
      bool shouldAdd = true;
      for (var kept in filtered) {
        if (_iou(detection.boundingBox, kept.boundingBox) > iouThreshold) {
          shouldAdd = false;
          break;
        }
      }
      if (shouldAdd) filtered.add(detection);
    }

    return filtered;
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Stop image stream before disposing camera to avoid callbacks after resources are gone
    try {
      _cameraController.stopImageStream();
    } catch (_) {}
    _isCapturing = false;
    _isProcessing = false;
    try {
      _cameraController.dispose();
    } catch (_) {}
    try {
      _interpreter?.close();
    } catch (_) {}
    _interpreter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmark Detection'),
        centerTitle: true,
      ),
      body: _isCameraInitialized
          ? Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: 640,
                                        height: 640,
                                        child: CameraPreview(_cameraController),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showBoxes)
                                  CustomPaint(
                                    painter: BoundingBoxPainter(
                                      detections: _detections,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                // Guidance chip
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  right: 12,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Text(
                                        'Align the landmark within the frame',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_modelLoaded)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 24.0,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Loading model...'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Controls below the camera
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: SwitchListTile.adaptive(
                              dense: true,
                              title: const Text('Show boxes'),
                              value: _showBoxes,
                              onChanged: (v) async {
                                setState(() => _showBoxes = v);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(_kPrefShowBoxes, v);
                              },
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              dense: true,
                              title: const Text('Notify New Detection'),
                              value: _notifyOnDetection,
                              onChanged: (v) async {
                                setState(() => _notifyOnDetection = v);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(_kPrefNotify, v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Center(child: CircularProgressIndicator()),
                SizedBox(height: 12),
                Text('Initializing camera...', style: TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final Color? color;

  BoundingBoxPainter({required this.detections, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = color ?? Colors.greenAccent;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = c;

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..color = Colors.black.withValues(alpha: 0.25);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final scale = size.width / 640.0;

    for (var detection in detections) {
      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scale,
        detection.boundingBox.top * scale,
        detection.boundingBox.right * scale,
        detection.boundingBox.bottom * scale,
      );

      // Shadow outline for readability
      final rrect = RRect.fromRectXY(rect, 8, 8);
      canvas.drawRRect(rrect, shadow);
      canvas.drawRRect(rrect, paint);

      final labelText =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        math.max(0, rect.top - 20),
        textPainter.width + 8,
        20,
      );

      canvas.drawRect(labelRect, Paint()..color = c);
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, math.max(0, rect.top - 18)),
      );
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) => true;
}
