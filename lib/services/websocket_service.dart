// lib/services/websocket_service.dart - FIXED VERSION
import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class WebSocketService {
  final String url; // Changed from Uri to String
  IO.Socket? _socket;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;
  static const int reconnectDelay = 3; // seconds

  // Callbacks
  void Function(String message)? onMessage;
  void Function(List<String> objects)? onDetection;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  WebSocketService(this.url); // Constructor accepts String directly

  bool get isConnected => _isConnected;

  /// Connect to WebSocket server with auto-reconnect
  void connect() {
    if (_socket != null && _isConnected) {
      debugPrint("⚠️ Already connected");
      return;
    }

    try {
      debugPrint("🔄 Connecting to: $url");

      _socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket']) // Use WebSocket only
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(maxReconnectAttempts)
            .setReconnectionDelay(reconnectDelay * 1000)
            .setTimeout(20000) // 20 second timeout
            .build(),
      );

      // Connection event handlers
      _socket!.onConnect((_) {
        _isConnected = true;
        _reconnectAttempts = 0;
        debugPrint("✅ Connected to server: $url");
        onConnected?.call();
        _startPingTimer();
      });

      _socket!.onDisconnect((reason) {
        _isConnected = false;
        debugPrint("❌ Disconnected: $reason");
        onDisconnected?.call();
        _stopPingTimer();

        // Auto-reconnect if not manually disconnected
        if (reason != 'io client disconnect') {
          _attemptReconnect();
        }
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        debugPrint("❌ Connection error: $error");
        onError?.call(error);
        _attemptReconnect();
      });

      _socket!.onError((error) {
        debugPrint("⚠️ Socket error: $error");
        onError?.call(error);
      });

      // Message handlers
      _socket!.on('connected', (data) {
        debugPrint("📨 Server connected message: $data");
      });

      _socket!.on('detection', (data) {
        debugPrint("📦 Detection event: $data");
        _handleDetectionMessage(data);
      });

      _socket!.on('error', (data) {
        debugPrint("⚠️ Server error: $data");
        onMessage?.call(data.toString());
      });

      _socket!.on('pong', (data) {
        debugPrint("🏓 Pong received");
      });

      _socket!.on('message', (data) {
        debugPrint("📨 Message: $data");
        onMessage?.call(data.toString());
      });

      // Attempt connection
      _socket!.connect();
    } catch (e) {
      _isConnected = false;
      debugPrint("❌ Socket initialization error: $e");
      onError?.call(e);
      _attemptReconnect();
    }
  }

  /// Handle detection messages
  void _handleDetectionMessage(dynamic data) {
    try {
      if (data is Map) {
        // Extract objects array
        if (data.containsKey('objects')) {
          final objects = List<String>.from(data['objects'] ?? []);
          onDetection?.call(objects);
          debugPrint("🎯 Detected objects: $objects");
        }
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded.containsKey('objects')) {
          final objects = List<String>.from(decoded['objects'] ?? []);
          onDetection?.call(objects);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error parsing detection data: $e");
    }
  }

  /// Start periodic ping to keep connection alive
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isConnected) {
        debugPrint("🏓 Sending ping");
        _socket?.emit('ping');
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Attempt to reconnect
  void _attemptReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > maxReconnectAttempts) {
      debugPrint("❌ Max reconnect attempts reached");
      return;
    }

    final delay = reconnectDelay * _reconnectAttempts;
    debugPrint("🔄 Reconnecting in ${delay}s (attempt $_reconnectAttempts)");

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_isConnected) {
        debugPrint("🔄 Attempting reconnection...");
        connect();
      }
    });
  }

  /// Send frame for object detection
  void sendFrame(String base64Frame) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send frame - not connected");
      return;
    }

    try {
      // Send frame data
      _socket?.emit('frame', {
        'image': base64Frame,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint("📤 Frame sent (${base64Frame.length} bytes)");
    } catch (e) {
      debugPrint("❌ Error sending frame: $e");
      onError?.call(e);
    }
  }

  /// Send JSON data
  void sendJson(Map<String, dynamic> data) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send JSON - not connected");
      return;
    }

    try {
      _socket?.emit('message', data);
      debugPrint("📤 JSON sent: $data");
    } catch (e) {
      debugPrint("❌ Error sending JSON: $e");
    }
  }

  /// Send text message
  void send(String message) {
    if (!_isConnected) {
      debugPrint("⚠️ Cannot send message - not connected");
      return;
    }

    _socket?.emit('message', message);
  }

  /// Manually reconnect
  void reconnect() {
    debugPrint("🔄 Manual reconnect requested");
    disconnect();
    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  /// Disconnect and cleanup
  void disconnect() {
    debugPrint("🔌 Disconnecting...");
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _reconnectAttempts = 0;
  }

  /// Get connection status
  String getStatus() {
    if (_isConnected) return "🟢 Connected";
    if (_reconnectTimer?.isActive ?? false) {
      return "🟡 Reconnecting... (attempt $_reconnectAttempts)";
    }
    return "🔴 Disconnected";
  }
}
