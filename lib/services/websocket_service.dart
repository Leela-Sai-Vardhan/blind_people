import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  final Uri uri;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  void Function(String message)? onMessage;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  WebSocketService(this.uri);

  void connect() {
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        (event) => onMessage?.call(event.toString()),
        onDone: () => onDisconnected?.call(),
        onError: (err) => onError?.call(err),
      );
      onConnected?.call();
    } catch (e) {
      onError?.call(e);
    }
  }

  void send(String message) {
    _channel?.sink.add(message);
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
  }
}
