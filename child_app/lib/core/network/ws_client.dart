import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WebSocketChannel? _channel;
  final String url;
  final void Function(Map<String, dynamic>)? onMessage;
  final void Function()? onConnected;
  final void Function()? onDisconnected;

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WsClient({
    required this.url,
    this.onMessage,
    this.onConnected,
    this.onDisconnected,
  });

  bool get isConnected => _channel != null;

  void connect() {
    if (_closed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            onMessage?.call(msg);
          } catch (e) {
            print('[WS] JSON parse error: $e');
          }
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          print('[WS] onDone: connection closed (code=$closeCode)');
          if (closeCode == 4001) {
            // Auth failure — don't reconnect
            _closed = true;
            onDisconnected?.call();
            return;
          }
          onDisconnected?.call();
          _scheduleReconnect();
        },
        onError: (error) {
          print('[WS] onError: $error');
          onDisconnected?.call();
          _scheduleReconnect();
        },
      );
      _channel!.ready.then((_) {
        if (!_closed) {
          _reconnectAttempts = 0;
          onConnected?.call();
          _startHeartbeat();
        }
      }).catchError((error) {
        onDisconnected?.call();
        _scheduleReconnect();
      });
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void close() {
    _closed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'heartbeat.ping'});
    });
  }

  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_closed) return;
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      print('[WS] Max reconnect attempts reached, giving up');
      return;
    }
    final delay = Duration(seconds: 3 * _reconnectAttempts);
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }
}
