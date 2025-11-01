import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class RecaptureScreen extends StatefulWidget {
  final String landmark;
  const RecaptureScreen({super.key, required this.landmark});

  @override
  State<RecaptureScreen> createState() => _RecaptureScreenState();
}

class _RecaptureScreenState extends State<RecaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found')),
        );
        Navigator.of(context).pop();
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      _initFuture = controller.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() => _busy = true);
    try {
      await _initFuture; // ensure initialized
      final picture = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<String>(picture.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recapture: ${widget.landmark}'),
        centerTitle: true,
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      color: Colors.black,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _capture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_busy ? 'Capturing…' : 'Capture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
