import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../../core/result.dart';

/// 网络错误类型
sealed class NetworkError {
  final String message;
  final DateTime timestamp;

  NetworkError({required this.message, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => message;
}

class ConnectionError extends NetworkError {
  final int? statusCode;
  ConnectionError({required super.message, this.statusCode});
}

class SendError extends NetworkError {
  SendError({required super.message});
}

class TimeoutError extends NetworkError {
  TimeoutError({super.message = 'Operation timed out'});
}

/// WebSocket 连接状态
enum SocketState {
  initial,
  connecting,
  connected,
  reconnecting,
  disconnected,
  error,
}

/// 消息包装器
class SocketMessage {
  final String type;
  final Map<String, dynamic> payload;
  final String id;
  final DateTime timestamp;

  SocketMessage({
    required this.type,
    required this.payload,
    String? id,
    DateTime? timestamp,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
        'id': id,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      id: json['id'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

/// 优雅的 WebSocket 客户端
/// 
/// 特性：
/// - 自动重连（指数退避）
/// - 心跳保活
/// - 类型安全的消息处理
/// - 函数式错误处理
class SocketClient extends ChangeNotifier {
  // 配置
  final String url;
  final Duration connectTimeout;
  final Duration heartbeatInterval;
  final int maxReconnectAttempts;
  final List<Duration> reconnectDelays;

  // 状态
  SocketState _state = SocketState.initial;
  WebSocketChannel? _channel;
  int _reconnectAttempt = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // 流控制器
  final _messageController = StreamController<SocketMessage>.broadcast();
  final _errorController = StreamController<NetworkError>.broadcast();

  // Getters
  SocketState get state => _state;
  bool get isConnected => _state == SocketState.connected;
  bool get isConnecting => _state == SocketState.connecting;

  Stream<SocketMessage> get messageStream => _messageController.stream;
  Stream<NetworkError> get errorStream => _errorController.stream;

  SocketClient({
    required this.url,
    this.connectTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
    this.reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ],
  });

  // ========== 连接管理 ==========

  /// 连接（幂等）
  Future<Result<void, NetworkError>> connect() async {
    if (_state == SocketState.connected || _state == SocketState.connecting) {
      return Result.ok(null);
    }

    _setState(SocketState.connecting);

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(url),
      );

      await _channel!.ready.timeout(connectTimeout);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _setState(SocketState.connected);
      _reconnectAttempt = 0;
      _startHeartbeat();

      return Result.ok(null);
    } on TimeoutException {
      _setState(SocketState.error);
      final error = TimeoutError();
      _errorController.add(error);
      return Result.err(error);
    } catch (e) {
      _setState(SocketState.error);
      final error = ConnectionError(message: e.toString());
      _errorController.add(error);
      return Result.err(error);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _stopHeartbeat();
    _stopReconnect();
    await _channel?.sink.close(status.normalClosure);
    _channel = null;
    _setState(SocketState.disconnected);
  }

  /// 优雅关闭
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _errorController.close();
    super.dispose();
  }

  // ========== 消息发送 ==========

  /// 发送消息
  Result<void, NetworkError> send(SocketMessage message) {
    if (!isConnected) {
      final error = SendError(message: 'Socket not connected');
      _errorController.add(error);
      return Result.err(error);
    }

    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
      return Result.ok(null);
    } catch (e) {
      final error = SendError(message: e.toString());
      _errorController.add(error);
      return Result.err(error);
    }
  }

  /// 发送并等待响应
  Future<Result<SocketMessage, NetworkError>> sendAndWait(
    SocketMessage message, {
    Duration? timeout,
  }) async {
    final sendResult = send(message);
    if (sendResult.isErr) {
      return Result.err(sendResult.errValue!);
    }

    try {
      final response = await _messageController.stream
          .firstWhere((m) => m.id == message.id)
          .timeout(timeout ?? const Duration(seconds: 5));

      return Result.ok(response);
    } on TimeoutException {
      final error = TimeoutError(message: 'Response timeout');
      _errorController.add(error);
      return Result.err(error);
    }
  }

  // ========== 私有方法 ==========

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final message = SocketMessage.fromJson(json);
      _messageController.add(message);
    } catch (e) {
      debugPrint('Failed to parse message: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('WebSocket error: $error');
    _errorController.add(ConnectionError(message: error.toString()));
    _scheduleReconnect();
  }

  void _onDone() {
    if (_state != SocketState.disconnected) {
      _scheduleReconnect();
    }
  }

  void _setState(SocketState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  // ========== 心跳 ==========

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      send(SocketMessage(
        type: 'ping',
        payload: {'time': DateTime.now().millisecondsSinceEpoch},
      ));
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ========== 重连 ==========

  void _scheduleReconnect() {
    if (_reconnectAttempt >= maxReconnectAttempts) {
      _setState(SocketState.error);
      return;
    }

    _setState(SocketState.reconnecting);
    _stopReconnect();

    final delay = reconnectDelays[min(_reconnectAttempt, reconnectDelays.length - 1)];
    _reconnectAttempt++;

    debugPrint('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)');

    _reconnectTimer = Timer(delay, () async {
      await connect();
    });
  }

  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}
