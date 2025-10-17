import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/material.dart';

class WebSocketService {
  final Uri uri;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;

  // Callbacks
  void Function(String message)? onMessage;
  void Function(List<String> objects)? onDetection;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  WebSocketService(this.uri);

  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  void connect() {
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        (event) {
          _handleMessage(event.toString());
        },
        onDone: () {
          _isConnected = false;
          onDisconnected?.call();
        },
        onError: (err) {
          _isConnected = false;
          onError?.call(err);
        },
      );
      _isConnected = true;
      onConnected?.call();
      debugPrint("✅ WebSocket connected to $uri");
    } catch (e) {
      _isConnected = false;
      onError?.call(e);
      debugPrint("❌ WebSocket connection failed: $e");
    }
  }

  /// Handle incoming messages from server
  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message);

      // Handle different message types
      if (data is Map) {
        if (data.containsKey('objects')) {
          // Detection results
          final objects = List<String>.from(data['objects'] ?? []);
          onDetection?.call(objects);
          debugPrint("📦 Detected objects: $objects");
        } else if (data.containsKey('message')) {
          // General message
          onMessage?.call(data['message']);
        } else {
          // Raw data
          onMessage?.call(message);
        }
      } else {
        onMessage?.call(message);
      }
    } catch (e) {
      // If not JSON, treat as plain text
      onMessage?.call(message);
    }
  }

  /// Send text message
  void send(String message) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send - not connected");
      return;
    }
    _channel?.sink.add(message);
  }

  /// Send frame for object detection
  void sendFrame(String base64Frame) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send frame - not connected");
      return;
    }

    final payload = jsonEncode({
      'frame': base64Frame,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _channel?.sink.add(payload);
  }

  /// Send JSON data
  void sendJson(Map<String, dynamic> data) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send JSON - not connected");
      return;
    }
    _channel?.sink.add(jsonEncode(data));
  }

  /// Reconnect with exponential backoff
  Future<void> reconnect({int maxAttempts = 5}) async {
    int attempt = 0;
    while (attempt < maxAttempts && !_isConnected) {
      attempt++;
      final delaySeconds = attempt * 2; // 2, 4, 6, 8, 10 seconds
      debugPrint(
          "🔄 Reconnection attempt $attempt/$maxAttempts in ${delaySeconds}s");

      await Future.delayed(Duration(seconds: delaySeconds));
      connect();

      if (_isConnected) {
        debugPrint("✅ Reconnected successfully");
        return;
      }
    }
    debugPrint("❌ Failed to reconnect after $maxAttempts attempts");
  }

  /// Disconnect and cleanup
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    _isConnected = false;
    debugPrint("🔌 WebSocket disconnected");
  }
}
