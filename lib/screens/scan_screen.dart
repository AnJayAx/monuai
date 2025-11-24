import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gamification_service.dart';

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
  static const String _kPrefShowDescriptions = 'show_descriptions';
  static const String _kPrefNotify = 'notify_on_detection';
  bool _useGpu = true;
  bool _showBoxes = true;
  bool _showDescriptions = true;
  bool _notifyOnDetection = true;
  final int _frameStride = 15;

  String? _lastDetectedLandmark;
  DateTime? _lastDetectionTime;

  List<Detection> _detections = [];
  // Overlay threshold controls what boxes are drawn; discovery requires higher confidence
  static const double _overlayThreshold = 0.85;
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
  Map<String, String> _landmarkDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _loadModel());
    _imageStreamHandler = _onImageFromStream;
    _initializeCamera();
    _loadDiscovered();
    _loadLandmarkDescriptions();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useGpu = prefs.getBool(_kPrefUseGpu) ?? true;
      _showBoxes = prefs.getBool(_kPrefShowBoxes) ?? true;
      _showDescriptions = prefs.getBool(_kPrefShowDescriptions) ?? true;
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

  Future<void> _loadLandmarkDescriptions() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/landmark_descriptions.json');
      final Map<String, dynamic> decoded = json.decode(jsonString);
      setState(() {
        _landmarkDescriptions = decoded.map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      debugPrint('Failed to load landmark descriptions: $e');
    }
  }

  // Confidence threshold is fixed via constants; no user-configurable threshold.

  Future<void> _loadModel() async {
    try {
      if (_useGpu) {
        final gpuOptions = InterpreterOptions()
          ..addDelegate(GpuDelegateV2(
            options: GpuDelegateOptionsV2(
              isPrecisionLossAllowed: true, // Allow FP16 for faster inference
            ),
          ))
          ..threads = 4; // Use multiple threads for CPU fallback
        _interpreter = await Interpreter.fromAsset(
          'assets/models/model_fp32_student.tflite',
          options: gpuOptions,
        );
        setState(() {
          _modelLoaded = true;
        });
        debugPrint('✓ Model loaded with GPU acceleration (optimized)');
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
      
      // Award points for discovering landmarks
      final userStats = await GamificationService.loadUserStats();
      var updatedStats = userStats;
      for (int i = 0; i < newlyFound.length; i++) {
        updatedStats = await GamificationService.recordLandmarkVisit(updatedStats);
      }
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
      setState(() {
        _lastDetectedLandmark = firstNew;
        _lastDetectionTime = DateTime.now();
      });
      // Auto-hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _lastDetectionTime != null) {
          final elapsed = DateTime.now().difference(_lastDetectionTime!);
          if (elapsed.inSeconds >= 3) {
            setState(() {
              _lastDetectedLandmark = null;
              _lastDetectionTime = null;
            });
          }
        }
      });
    }

    // Capture once and save original image (no bounding boxes) for all newly found labels
    if (!_isCapturing) {
      await _captureAndSaveOriginal(newlyFound);
    }
  }

  Future<void> _captureAndSaveOriginal(List<String> newLabels) async {
    if (!_isCameraInitialized) return;
    if (_isCapturing) return;

    _isCapturing = true;
    try {
      await _cameraController.stopImageStream();
      final picture = await _cameraController.takePicture();
      final photoPath = picture.path;

      // Save path into map in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPhotosKey);
      Map<String, dynamic> map = <String, dynamic>{};
      if (jsonStr != null) {
        try {
          map = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      // Save same original photo path for all newly detected landmarks
      for (final label in newLabels) {
        map[label] = photoPath;
      }

      await prefs.setString(_kPhotosKey, jsonEncode(map));

      // Auto-confirm the landmarks and save capture timestamps
      final confirmed = prefs.getStringList('confirmed_landmarks') ?? <String>[];
      final capturedAtJson = prefs.getString('landmark_captured_at');
      Map<String, dynamic> capturedMap = {};
      if (capturedAtJson != null) {
        try {
          capturedMap = jsonDecode(capturedAtJson) as Map<String, dynamic>;
        } catch (_) {}
      }

      for (final label in newLabels) {
        if (!confirmed.contains(label)) {
          confirmed.add(label);
        }
        capturedMap[label] = DateTime.now().toUtc().toIso8601String();
      }

      await prefs.setStringList('confirmed_landmarks', confirmed);
      await prefs.setString('landmark_captured_at', jsonEncode(capturedMap));
      
      debugPrint('Saved original photo for ${newLabels.length} landmark(s)');
    } catch (e) {
      debugPrint('Failed to capture/save photo: $e');
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
                                      descriptions: _showDescriptions ? _landmarkDescriptions : {},
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                // Notification banner for new detections
                                if (_lastDetectedLandmark != null)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'New landmark detected: $_lastDetectedLandmark',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Guidance chip
                                Positioned(
                                  top: _lastDetectedLandmark != null ? 76 : 12,
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
                    child: SwitchListTile.adaptive(
                      dense: true,
                      title: const Text('Show Descriptions'),
                      subtitle: const Text('Display landmark info beside bounding boxes'),
                      value: _showDescriptions,
                      onChanged: (v) async {
                        setState(() => _showDescriptions = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_kPrefShowDescriptions, v);
                      },
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
  final Map<String, String> descriptions;

  BoundingBoxPainter({
    required this.detections,
    this.color,
    this.descriptions = const {},
  });

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
    
    // Track occupied regions to avoid overlaps
    final List<Rect> occupiedRegions = [];

    for (var detection in detections) {
      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scale,
        detection.boundingBox.top * scale,
        detection.boundingBox.right * scale,
        detection.boundingBox.bottom * scale,
      );

      // Add bounding box to occupied regions
      occupiedRegions.add(rect);

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

    // Second pass: draw descriptions with smart positioning
    for (var detection in detections) {
      final description = descriptions[detection.label];
      if (description == null || description.isEmpty) continue;

      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scale,
        detection.boundingBox.top * scale,
        detection.boundingBox.right * scale,
        detection.boundingBox.bottom * scale,
      );

      // Extract and format description text
      String shortDesc = description;
      if (description.contains('**Description:**')) {
        final parts = description.split('**Description:**');
        if (parts.length > 1) {
          shortDesc = parts[1].trim();
        }
      }
      if (shortDesc.length > 100) {
        shortDesc = '${shortDesc.substring(0, 97)}...';
      }

      final descTextPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        maxLines: 3,
      );

      descTextPainter.text = TextSpan(
        text: shortDesc,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.normal,
          height: 1.2,
        ),
      );
      descTextPainter.layout(maxWidth: 200);

      final descWidth = descTextPainter.width + 12;
      final descHeight = descTextPainter.height + 8;

      // Try different positions in order of preference
      final positions = [
        // Right of box
        Offset(rect.right + 8, rect.top),
        // Left of box
        Offset(rect.left - descWidth - 8, rect.top),
        // Below box
        Offset(rect.left, rect.bottom + 8),
        // Above box
        Offset(rect.left, rect.top - descHeight - 8),
        // Right-bottom
        Offset(rect.right + 8, rect.bottom - descHeight),
        // Left-bottom
        Offset(rect.left - descWidth - 8, rect.bottom - descHeight),
      ];

      Rect? descRect;
      for (final pos in positions) {
        final candidateRect = Rect.fromLTWH(
          pos.dx,
          pos.dy,
          descWidth,
          descHeight,
        );

        // Check if within bounds
        if (candidateRect.left < 0 || candidateRect.right > size.width ||
            candidateRect.top < 0 || candidateRect.bottom > size.height) {
          continue;
        }

        // Check for overlaps with occupied regions
        bool hasOverlap = false;
        for (final occupied in occupiedRegions) {
          if (candidateRect.overlaps(occupied)) {
            hasOverlap = true;
            break;
          }
        }

        if (!hasOverlap) {
          descRect = candidateRect;
          break;
        }
      }

      // If no position found, place it anyway at the least bad position
      descRect ??= Rect.fromLTWH(
        (rect.right + 8).clamp(0, size.width - descWidth),
        rect.top.clamp(0, size.height - descHeight),
        descWidth,
        descHeight,
      );

      // Mark this region as occupied
      occupiedRegions.add(descRect);

      // Draw description background
      canvas.drawRRect(
        RRect.fromRectXY(descRect, 8, 8),
        Paint()..color = Colors.black.withValues(alpha: 0.75),
      );

      // Draw description text
      descTextPainter.paint(
        canvas,
        Offset(descRect.left + 6, descRect.top + 4),
      );
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) => true;
}
