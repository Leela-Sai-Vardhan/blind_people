import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/object_detection_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _controller;
  ObjectDetectionService? _detectionService;
  bool _isStreaming = false;
  String _status = 'Initializing...';
  Timer? _timer;
  List<String> _detectedObjects = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera found');
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();

      _detectionService =
          ObjectDetectionService(serverUrl: 'http://127.0.0.1:5001');
      _detectionService!.onConnect =
          () => setState(() => _status = '🟢 Connected');
      _detectionService!.onDisconnect =
          () => setState(() => _status = '🔴 Disconnected');
      _detectionService!.onError = () => setState(() => _status = '⚠️ Error');
      _detectionService!.onDetection = (objs) {
        setState(() => _detectedObjects = objs);
      };
      _detectionService!.connect();

      setState(() => _status = 'Ready');
    } catch (e) {
      print('Camera init error: $e');
      setState(() => _status = 'Error initializing camera');
    }
  }

  void _startStreaming() {
    if (_controller == null || _isStreaming) return;
    _isStreaming = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final file = await _controller!.takePicture();
        final bytes = await File(file.path).readAsBytes();
        _detectionService?.sendFrameBytes(bytes);

        // delete temp file
        final tmpDir = await getTemporaryDirectory();
        if (p.isWithin(tmpDir.path, file.path)) {
          final f = File(file.path);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        print('Capture error: $e');
      }
    });
    setState(() {});
  }

  void _stopStreaming() {
    _timer?.cancel();
    _isStreaming = false;
    setState(() {});
  }

  @override
  void dispose() {
    _stopStreaming();
    _controller?.dispose();
    _detectionService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Object Detection')),
        body: Center(child: Text(_status)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection')),
      body: Column(
        children: [
          Expanded(child: CameraPreview(_controller!)),
          const SizedBox(height: 10),
          Text(_status, style: const TextStyle(fontSize: 16)),
          if (_detectedObjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Detected: ${_detectedObjects.join(', ')}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isStreaming ? null : _startStreaming,
                child: const Text('Start'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isStreaming ? _stopStreaming : null,
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
