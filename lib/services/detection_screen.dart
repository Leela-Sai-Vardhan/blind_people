import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  late CameraController _controller;
  bool _isDetecting = false;
  late IOWebSocketChannel _channel;
  String _detectedObjects = "";

  @override
  void initState() {
    super.initState();
    _initSocket();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint("Camera permission not granted");
      return;
    }

    final cameras = await availableCameras();
    final camera = cameras.first;

    _controller = CameraController(camera, ResolutionPreset.medium);
    await _controller.initialize();

    setState(() {});

    _controller.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        // Convert first plane bytes to base64
        final bytes = image.planes[0].bytes;
        final base64Image = base64Encode(bytes);

        _channel.sink.add(jsonEncode({'image': base64Image}));
      } catch (e) {
        debugPrint("Error sending frame: $e");
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _isDetecting = false;
    });
  }

  void _initSocket() {
    // ⚠️ Update IP to match your backend machine
    _channel = IOWebSocketChannel.connect("ws://10.0.11.239:5001/ws");

    _channel.stream.listen((event) {
      try {
        final data = jsonDecode(event);
        if (data["objects"] != null) {
          setState(() {
            _detectedObjects = data["objects"].join(", ");
          });
        }
      } catch (e) {
        debugPrint("Socket message parse error: $e");
      }
    }, onError: (error) {
      debugPrint("WebSocket error: $error");
    }, onDone: () {
      debugPrint("WebSocket closed");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!(_controller.value.isInitialized)) {
      return const Scaffold(
        body: Center(child: Text("Initializing camera...")),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _detectedObjects.isEmpty
                    ? "No objects detected"
                    : "Detected: $_detectedObjects",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _channel.sink.close();
    super.dispose();
  }
}
