import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

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
  String _detectedLandmark = 'Loading...';
  bool _isCameraInitialized = false;
  bool _modelLoaded = false;
  bool _isProcessing = false;
  int _frameCount = 0;

  List<Detection> _detections = [];

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
  }

  Future<void> _loadModel() async {
    try {
      final gpuOptions = InterpreterOptions()..addDelegate(GpuDelegateV2());

      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
        options: gpuOptions,
      );

      setState(() {
        _modelLoaded = true;
        _detectedLandmark = '✓ Model loaded (GPU)\nPoint at landmark';
      });
      debugPrint('✓ Model loaded with GPU acceleration');
    } catch (e) {
      debugPrint('GPU failed, trying CPU: $e');
      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/best_float32.tflite',
        );
        setState(() {
          _modelLoaded = true;
          _detectedLandmark = '✓ Model loaded (CPU)\nPoint at landmark';
        });
      } catch (e2) {
        setState(() {
          _detectedLandmark = 'Model load failed: $e2';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _detectedLandmark = 'No camera found';
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
        _detectedLandmark = 'Camera error: $e';
      });
    }
  }

  Future<void> _runInference(CameraImage cameraImage) async {
    try {
      if (_frameCount++ % 5 != 0) {
        _isProcessing = false;
        return;
      }

      final inputImage = _preprocessImage(cameraImage);

      // Output for 320x320: [1, 8, 2100]
      var output = List.generate(
        1,
        (_) => List.generate(8, (_) => List.filled(2100, 0.0)),
      );

      _interpreter?.run(inputImage, output);

      _processOutput(output);
    } catch (e) {
      debugPrint('Inference error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  List<List<List<List<double>>>> _preprocessImage(CameraImage image) {
    // Camera gives us landscape (width > height), but we need portrait
    // Swap axes AND flip vertically to match screen orientation

    final input = List.generate(
      1,
      (_) => List.generate(
        320,
        (y) => List.generate(320, (x) {
          // Swap axes with vertical flip
          final srcY = ((320 - 1 - x) * image.height / 320).floor().clamp(
            0,
            image.height - 1,
          );
          final srcX = (y * image.width / 320).floor().clamp(
            0,
            image.width - 1,
          );
          final pixelIndex = (srcY * image.width + srcX).clamp(
            0,
            image.planes[0].bytes.length - 1,
          );

          final yValue = image.planes[0].bytes[pixelIndex].toDouble() / 255.0;

          return [yValue, yValue, yValue];
        }),
      ),
    );

    return input;
  }

  void _processOutput(List<List<List<double>>> output) {
    List<Detection> newDetections = [];

    for (int i = 0; i < 2100; i++) {
      double maxConfidence = 0.0;
      int detectedClass = -1;

      for (int cls = 4; cls < 8; cls++) {
        double confidence = output[0][cls][i];
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedClass = cls - 4;
        }
      }

      if (maxConfidence > 0.25) {
        double xCenter = output[0][0][i];
        double yCenter = output[0][1][i];
        double width = output[0][2][i];
        double height = output[0][3][i];

        double left = (xCenter - width / 2) * 320;
        double top = (yCenter - height / 2) * 320;
        double right = (xCenter + width / 2) * 320;
        double bottom = (yCenter + height / 2) * 320;

        newDetections.add(
          Detection(
            boundingBox: Rect.fromLTRB(
              left.clamp(0, 320),
              top.clamp(0, 320),
              right.clamp(0, 320),
              bottom.clamp(0, 320),
            ),
            label: _landmarkNames[detectedClass],
            confidence: maxConfidence,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _detections = newDetections;
        if (newDetections.isNotEmpty) {
          _detectedLandmark = '${newDetections.length} landmark(s) detected';
        } else {
          _detectedLandmark = 'No landmark detected';
        }
      });
    }
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
                                  width: 320,
                                  height: 320,
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
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _detectedLandmark,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

    final scale = size.width / 320.0;

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
