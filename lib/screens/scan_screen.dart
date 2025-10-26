import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

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
        'assets/models/best_float32_640.tflite',
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
          'assets/models/best_float32_640.tflite',
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
    final stopwatchTotal = Stopwatch()..start();

    try {
      if (_frameCount++ % 5 != 0) {
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

      var output = List.generate(
        1,
        (_) => List.generate(8, (_) => List.filled(8400, 0.0)),
      );

      final stopwatchInference = Stopwatch()..start();
      _interpreter?.run(inputBuffer, output);
      stopwatchInference.stop();
      debugPrint('Inference: ${stopwatchInference.elapsedMilliseconds} ms');

      _processOutput(output);

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

  void _processOutput(List<List<List<double>>> output) {
    List<Detection> newDetections = [];

    for (int i = 0; i < 8400; i++) {
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
