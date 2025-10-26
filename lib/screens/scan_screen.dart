import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  int _frameCount = 0;
  String _notificationText = '';

  List<Detection> _detections = [];

  double _confidenceThreshold = 0.7;
  static const String _kConfidenceThresholdKey = 'confidence_threshold';

  Interpreter? _interpreter;

  final List<String> _landmarkNames = [
    'Art Science Museum',
    'Esplanade',
    'Marina Bay Sands',
    'Merlion',
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initializeCamera();
    _loadConfidenceThreshold();
  }

  Future<void> _loadConfidenceThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getDouble(_kConfidenceThresholdKey);
      if (val != null && mounted) {
        setState(() {
          _confidenceThreshold = val;
        });
        debugPrint('Loaded confidence threshold: $_confidenceThreshold');
      }
    } catch (e) {
      debugPrint('Failed to load confidence threshold: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      final gpuOptions = InterpreterOptions()..addDelegate(GpuDelegateV2());

      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32_640.tflite',
        options: gpuOptions,
      );

      setState(() {
        _modelLoaded = true;
        debugPrint('✓ Model loaded with GPU acceleration');
      });
      debugPrint('✓ Model loaded with GPU acceleration');
    } catch (e) {
      debugPrint('GPU failed, trying CPU: $e');
      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/best_float32_640.tflite',
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
        ResolutionPreset.low,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        _cameraController.startImageStream((CameraImage cameraImage) {
          if (!_isProcessing && _modelLoaded) {
            _isProcessing = true;
            _runInference(cameraImage);
          }
        });
      }
    } catch (e) {
      setState(() {
        debugPrint('Camera error: $e');
      });
    }
  }

  Future<void> _runInference(CameraImage cameraImage) async {
    final stopwatchTotal = Stopwatch()..start();

    try {
      if (_frameCount++ % 15 != 0) {
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
      _interpreter?.run(inputBuffer, outputBuffer);
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

  void _updateNotification(List<Detection> detections) {
    if (detections.isEmpty) {
      _notificationText = '';
      return;
    }

    // Find landmark with highest confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final topDetection = detections.first;

    _notificationText =
        '${topDetection.label} ${(topDetection.confidence * 100).toStringAsFixed(0)}% confidence detected';
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

      if (maxConfidence >= _confidenceThreshold) {
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
      _updateNotification(filteredDetections);

      setState(() {
        _detections = filteredDetections;
        if (filteredDetections.isNotEmpty) {
          debugPrint('${filteredDetections.length} landmark(s) detected');
        } else {
          debugPrint('No landmark detected');
        }
      });
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
    _cameraController.dispose();
    _interpreter?.close();
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
          ? Stack(
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
                          CustomPaint(
                            painter: BoundingBoxPainter(
                              detections: _detections,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _notificationText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;

  BoundingBoxPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

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

      canvas.drawRect(rect, paint);

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

      canvas.drawRect(labelRect, Paint()..color = Colors.greenAccent);
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, math.max(0, rect.top - 18)),
      );
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) => true;
}
