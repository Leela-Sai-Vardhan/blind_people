// lib/screens/detection_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/websocket_service.dart';
import '../services/tts_service.dart';
import 'dart:async';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  late CameraService _cameraService;
  late WebSocketService _detectionWS;
  late TTSService _tts;

  bool _isInitializing = true;
  bool _isDetecting = false;
  List<String> _detectedObjects = [];
  String _statusMessage = "Initializing...";
  String _connectionStatus = "🔴 Disconnected";
  Timer? _statusUpdateTimer;
  int _framesSent = 0;
  DateTime? _lastDetectionTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseDetection();
    } else if (state == AppLifecycleState.resumed) {
      _resumeDetection();
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize TTS
      _tts = TTSService();
      await _tts.initialize();

      // IMPORTANT: Change this to your PC's IP address
      // For USB debugging, use your PC's local IP (not 127.0.0.1)
      // Example: 'http://192.168.1.100:5001'
      const serverUrl = 'http://10.0.11.239:5001'; // This is a String

      debugPrint("🔗 Connecting to: $serverUrl");

      // Initialize WebSocket for object detection (pass String directly)
      _detectionWS = WebSocketService(serverUrl);

      _detectionWS.onConnected = () {
        setState(() {
          _connectionStatus = "🟢 Connected";
          _statusMessage = "Connected to detection server";
        });
        _tts.speak("Detection service connected");
      };

      _detectionWS.onDetection = (objects) {
        setState(() {
          _detectedObjects = objects;
          _lastDetectionTime = DateTime.now();
        });

        if (objects.isNotEmpty) {
          final objectList = objects.join(', ');
          debugPrint("🎯 Detected: $objectList");
          _tts.speak("Detected: $objectList");
        }
      };

      _detectionWS.onDisconnected = () {
        setState(() {
          _connectionStatus = "🔴 Disconnected";
          _statusMessage = "Disconnected from server";
        });
      };

      _detectionWS.onError = (error) {
        setState(() {
          _connectionStatus = "⚠️ Error";
          _statusMessage = "Connection error";
        });
        debugPrint("❌ WebSocket error: $error");
      };

      // Connect to server
      _detectionWS.connect();

      // Initialize Camera
      _cameraService = CameraService(framesPerSecond: 1); // Reduced to 1 FPS
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
          setState(() {
            _framesSent++;
          });
        }
      };

      setState(() {
        _isInitializing = false;
        _statusMessage = "Ready to detect";
      });

      await _tts.speak("Camera ready. Tap start to begin detection.");

      // Start status update timer
      _startStatusTimer();
    } catch (e) {
      setState(() {
        _statusMessage = "Initialization failed: $e";
        _isInitializing = false;
      });
      debugPrint("❌ Initialization error: $e");
    }
  }

  void _startStatusTimer() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _connectionStatus = _detectionWS.getStatus();
        });
      }
    });
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

  void _pauseDetection() {
    if (_isDetecting) {
      _cameraService.stopStreaming();
    }
  }

  void _resumeDetection() {
    if (_isDetecting && _cameraService.isInitialized) {
      _cameraService.startStreaming();
    }
  }

  void _reconnectServer() {
    _tts.speak("Reconnecting to server");
    _detectionWS.reconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusUpdateTimer?.cancel();
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
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _connectionStatus,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          // Reconnect button
          if (!_detectionWS.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reconnectServer,
              tooltip: 'Reconnect',
            ),
          // Toggle detection button
          IconButton(
            icon: Icon(_isDetecting ? Icons.pause : Icons.play_arrow),
            onPressed: _isInitializing ? null : _toggleDetection,
            tooltip: _isDetecting ? 'Pause' : 'Start',
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
                    'Initializing camera and server...',
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
                      ? Stack(
                          children: [
                            CameraPreview(_cameraService.controller!),
                            // Detection overlay
                            if (_isDetecting)
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🎥 DETECTING...',
                                        style: TextStyle(
                                          color: Colors.green.shade400,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Frames sent: $_framesSent',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
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
                        // Status
                        Row(
                          children: [
                            Icon(
                              _detectionWS.isConnected
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _detectionWS.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _detectionWS.isConnected
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Detected Objects Header
                        const Text(
                          'Detected Objects:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Objects List
                        Expanded(
                          child: _detectedObjects.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search,
                                        size: 48,
                                        color: Colors.white30,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isDetecting
                                            ? 'Scanning for objects...'
                                            : 'Tap start to begin detection',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
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
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        trailing: _lastDetectionTime != null
                                            ? Text(
                                                '${DateTime.now().difference(_lastDetectionTime!).inSeconds}s ago',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              )
                                            : null,
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
