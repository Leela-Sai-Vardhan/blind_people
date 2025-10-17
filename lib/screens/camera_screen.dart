// lib/screens/camera_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/detection_screen.dart';

class CameraScreen extends StatefulWidget {
  final String backendUrl;
  const CameraScreen({super.key, required this.backendUrl});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  String _status = 'Initializing camera...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _status = 'Camera permission denied');
      return;
    }

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

      setState(() {
        _status = 'Camera ready';
      });
    } catch (e) {
      setState(() => _status = 'Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Object Detection')),
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _status,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection')),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DetectionScreen(),
                ),
              );
            },
            child: const Text('Start Object Detection'),
          ),
        ],
      ),
    );
  }
}
