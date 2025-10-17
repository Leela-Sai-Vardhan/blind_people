import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef DetectionCallback = void Function(List<String> objects);
typedef SimpleCallback = void Function();

class ObjectDetectionService {
  final String serverUrl;
  late IO.Socket _socket;

  SimpleCallback? onConnect;
  SimpleCallback? onDisconnect;
  SimpleCallback? onError;
  DetectionCallback? onDetection;

  ObjectDetectionService({required this.serverUrl});

  void connect() {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      onConnect?.call();
      print('✅ Connected to Object Detection server');
    });

    _socket.onDisconnect((_) {
      onDisconnect?.call();
      print('❌ Disconnected from Object Detection server');
    });

    _socket.on('detection', (data) {
      print('📦 Detection event: $data');
      if (data is Map && data['objects'] is List) {
        onDetection?.call(List<String>.from(data['objects']));
      }
    });

    _socket.on('error', (err) {
      onError?.call();
      print('⚠️ Socket error: $err');
    });

    _socket.connect();
  }

  void sendFrameBytes(List<int> bytes) {
    final imgB64 = base64Encode(bytes);
    _socket.emit('frame', {'image': imgB64});
  }

  bool isConnected() => _socket.connected;

  void disconnect() {
    _socket.disconnect();
  }
}
