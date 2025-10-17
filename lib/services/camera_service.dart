import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreaming = false;
  Timer? _streamTimer;

  // Callback for sending frames
  Function(String base64Frame)? onFrameReady;

  // Frame rate control (default: 2 FPS to reduce load)
  final int framesPerSecond;

  CameraService({this.framesPerSecond = 2});

  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  CameraController? get controller => _controller;

  /// Initialize camera
  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint("❌ No cameras available");
        return false;
      }

      // Use back camera for object detection
      final camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium, // Balance between quality and performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      debugPrint("✅ Camera initialized");
      return true;
    } catch (e) {
      debugPrint("❌ Camera initialization failed: $e");
      return false;
    }
  }

  /// Start streaming frames
  void startStreaming() {
    if (!_isInitialized || _isStreaming) return;

    _isStreaming = true;
    final intervalMs = (1000 / framesPerSecond).round();

    _streamTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _captureAndSendFrame();
    });

    debugPrint("✅ Camera streaming started at $framesPerSecond FPS");
  }

  /// Stop streaming frames
  void stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _isStreaming = false;
    debugPrint("⏸️ Camera streaming stopped");
  }

  /// Capture single frame and encode to base64
  Future<void> _captureAndSendFrame() async {
    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      final XFile imageFile = await _controller!.takePicture();
      final Uint8List bytes = await imageFile.readAsBytes();

      // Resize image to reduce payload (optional but recommended)
      final resizedBytes = await _resizeImage(bytes, maxWidth: 640);

      // Convert to base64
      final base64Frame = base64Encode(resizedBytes);

      // Send via callback
      onFrameReady?.call(base64Frame);
    } catch (e) {
      debugPrint("⚠️ Frame capture error: $e");
    }
  }

  /// Resize image to reduce network load
  Future<Uint8List> _resizeImage(Uint8List bytes, {int maxWidth = 640}) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Only resize if image is larger than maxWidth
    if (image.width <= maxWidth) {
      return bytes;
    }

    final resized = img.copyResize(image, width: maxWidth);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  /// Dispose camera resources
  Future<void> dispose() async {
    stopStreaming();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    debugPrint("🧹 Camera disposed");
  }

  /// Toggle flash (if available)
  Future<void> toggleFlash() async {
    if (!_isInitialized) return;

    final currentMode = _controller!.value.flashMode;
    final newMode =
        currentMode == FlashMode.off ? FlashMode.torch : FlashMode.off;

    try {
      await _controller!.setFlashMode(newMode);
      debugPrint("💡 Flash toggled: $newMode");
    } catch (e) {
      debugPrint("⚠️ Flash toggle failed: $e");
    }
  }
}
