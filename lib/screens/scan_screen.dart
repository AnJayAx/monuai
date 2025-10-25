import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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

  Interpreter? _interpreter;

  // Landmark class names (update based on your training)
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
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
      );
      setState(() {
        _modelLoaded = true;
        _detectedLandmark = '✓ Model loaded\nPoint camera at landmark';
      });
      debugPrint('✓ Model loaded successfully');
    } catch (e) {
      setState(() {
        _detectedLandmark = 'Model load failed: $e';
      });
      debugPrint('✗ Model load error: $e');
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
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        // Start image stream for real-time detection
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
      // Skip every other frame to reduce load
      if (_frameCount++ % 4 != 0) {
        _isProcessing = false;
        return;
      }

      // Simplified preprocessing - much faster
      final inputImage = _preprocessImage(cameraImage);

      // Output tensor
      var output = List.generate(
        1,
        (_) => List.generate(8, (_) => List.filled(8400, 0.0)),
      );

      // Run inference
      _interpreter?.run(inputImage, output);

      // Process output
      _processOutput(output);
    } catch (e) {
      debugPrint('Inference error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  List<List<List<List<double>>>> _preprocessImage(CameraImage image) {
    // Downsample and convert in one pass - much faster
    final input = List.generate(
      1,
      (_) => List.generate(
        640,
        (y) => List.generate(640, (x) {
          // Sample from original image with downsampling
          final srcY = (y * image.height / 640).floor();
          final srcX = (x * image.width / 640).floor();
          final pixelIndex = srcY * image.width + srcX;

          // Get Y value (grayscale approximation for speed)
          final yValue = image.planes[0].bytes[pixelIndex].toDouble() / 255.0;

          return [yValue, yValue, yValue]; // RGB from grayscale
        }),
      ),
    );

    return input;
  }

  void _processOutput(List<List<List<double>>> output) {
    // YOLOv8 output format: [1, 8, 8400]
    // 8 = 4 box coordinates + 4 classes

    double maxConfidence = 0.0;
    int detectedClass = -1;

    // Find highest confidence detection
    for (int i = 0; i < 8400; i++) {
      // Classes are at indices 4-7
      for (int cls = 4; cls < 8; cls++) {
        double confidence = output[0][cls][i];
        if (confidence > maxConfidence && confidence > 0.3) {
          // 30% confidence threshold
          maxConfidence = confidence;
          detectedClass = cls - 4; // Subtract 4 to get class index (0-3)
        }
      }
    }

    if (detectedClass != -1 && mounted) {
      setState(() {
        _detectedLandmark = '${_landmarkNames[detectedClass]}\n'
            'Confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%';
      });
    } else if (mounted) {
      setState(() {
        _detectedLandmark = 'No landmark detected\nPoint at a landmark';
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
                CameraPreview(_cameraController),
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
