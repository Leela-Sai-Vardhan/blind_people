import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/websocket_service.dart';
import '../services/tts_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  late CameraService _cameraService;
  late WebSocketService _detectionWS;
  late TTSService _tts;

  bool _isInitializing = true;
  bool _isDetecting = false;
  List<String> _detectedObjects = [];
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize TTS
      _tts = TTSService();
      await _tts.initialize();

      // Initialize WebSocket for object detection
      _detectionWS = WebSocketService(Uri.parse('ws://10.0.10.210:5001/ws'));

      _detectionWS.onConnected = () {
        setState(() => _statusMessage = "Connected to detection server");
        _tts.speak("Detection service connected");
      };

      _detectionWS.onDetection = (objects) {
        setState(() {
          _detectedObjects = objects;
        });
        if (objects.isNotEmpty) {
          _tts.speak("Detected: ${objects.join(', ')}");
        }
      };

      _detectionWS.onDisconnected = () {
        setState(() => _statusMessage = "Disconnected from server");
      };

      _detectionWS.onError = (error) {
        setState(() => _statusMessage = "Connection error");
        debugPrint("❌ WebSocket error: $error");
      };

      _detectionWS.connect();

      // Initialize Camera
      _cameraService = CameraService(framesPerSecond: 2);
      final cameraReady = await _cameraService.initialize();

      if (!cameraReady) {
        setState(() {
          _statusMessage = "Camera not available";
          _isInitializing = false;
        });
        _tts.speak("Camera initialization failed");
        return;
      }

      // Setup frame callback
      _cameraService.onFrameReady = (base64Frame) {
        if (_isDetecting && _detectionWS.isConnected) {
          _detectionWS.sendFrame(base64Frame);
        }
      };

      setState(() {
        _isInitializing = false;
        _statusMessage = "Ready to detect";
      });

      await _tts.speak("Camera ready. Tap to start detection.");
    } catch (e) {
      setState(() {
        _statusMessage = "Initialization failed";
        _isInitializing = false;
      });
      debugPrint("❌ Initialization error: $e");
    }
  }

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
    });

    if (_isDetecting) {
      _cameraService.startStreaming();
      _tts.speak("Detection started");
      setState(() => _statusMessage = "Detecting objects...");
    } else {
      _cameraService.stopStreaming();
      _tts.speak("Detection stopped");
      setState(() => _statusMessage = "Detection paused");
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _detectionWS.disconnect();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Object Detection'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: Icon(_isDetecting ? Icons.pause : Icons.play_arrow),
            onPressed: _isInitializing ? null : _toggleDetection,
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Camera Preview
                Expanded(
                  flex: 3,
                  child: _cameraService.isInitialized
                      ? CameraPreview(_cameraService.controller!)
                      : const Center(
                          child: Text(
                            'Camera unavailable',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                ),

                // Detection Results Panel
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade900,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: $_statusMessage',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Detected Objects:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _detectedObjects.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No objects detected',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _detectedObjects.length,
                                  itemBuilder: (context, index) {
                                    return Card(
                                      color: Colors.blue.shade800,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.check_circle,
                                          color: Colors.greenAccent,
                                        ),
                                        title: Text(
                                          _detectedObjects[index],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _isInitializing
          ? null
          : FloatingActionButton.extended(
              onPressed: _toggleDetection,
              backgroundColor: _isDetecting ? Colors.red : Colors.green,
              icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
              label: Text(_isDetecting ? 'STOP' : 'START'),
            ),
    );
  }
}
