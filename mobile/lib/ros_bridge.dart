import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class RosBridge {
  WebSocketChannel? _channel;
  ConnectionStatus status = ConnectionStatus.disconnected;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  Future<void> connect(String host, {int port = 9090}) async {
    _setStatus(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection to be established
      await _channel!.ready;
      _setStatus(ConnectionStatus.connected);

      // Listen for errors / closure
      _channel!.stream.listen(
        (_) {},
        onError: (_) => _setStatus(ConnectionStatus.error),
        onDone: () => _setStatus(ConnectionStatus.disconnected),
      );
    } catch (e) {
      _setStatus(ConnectionStatus.error);
    }
  }

  void publishTwist({
    double linearX = 0.0,
    double angularZ = 0.0,
    String topic = '/turtle1/cmd_vel',
  }) {
    if (status != ConnectionStatus.connected) return;

    final msg = {
      'op': 'publish',
      'topic': topic,
      'msg': {
        'linear': {'x': linearX, 'y': 0.0, 'z': 0.0},
        'angular': {'x': 0.0, 'y': 0.0, 'z': angularZ},
      },
    };

    _channel?.sink.add(jsonEncode(msg));
  }

  /// Advertise the topic so rosbridge knows the message type before publishing.
  void advertise({
    String topic = '/turtle1/cmd_vel',
    String type = 'geometry_msgs/Twist',
  }) {
    if (status != ConnectionStatus.connected) return;
    final msg = {'op': 'advertise', 'topic': topic, 'type': type};
    _channel?.sink.add(jsonEncode(msg));
  }

  void stop() => publishTwist(linearX: 0, angularZ: 0);

  void disconnect() {
    _channel?.sink.close();
    _setStatus(ConnectionStatus.disconnected);
  }

  void _setStatus(ConnectionStatus s) {
    status = s;
    _statusController.add(s);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}
