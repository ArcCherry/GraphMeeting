import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/auth/role_permissions.dart';
import '../sync/offline_queue.dart';

/// 连接状态枚举
enum ConnectionState {
  disconnected,   // 未连接
  connecting,     // 连接中
  connected,      // 已连接
  reconnecting,   // 重连中
  error,          // 错误状态
}

/// 网络质量信息
class NetworkQuality {
  final int latencyMs;        // 延迟（毫秒）
  final double packetLoss;    // 丢包率（0-1）
  final bool isHighLatency;   // 是否高延迟

  const NetworkQuality({
    required this.latencyMs,
    this.packetLoss = 0.0,
    this.isHighLatency = false,
  });

  /// 获取网络质量等级
  NetworkQualityLevel get level {
    if (latencyMs < 100) return NetworkQualityLevel.excellent;
    if (latencyMs < 200) return NetworkQualityLevel.good;
    if (latencyMs < 500) return NetworkQualityLevel.poor;
    return NetworkQualityLevel.bad;
  }
}

enum NetworkQualityLevel {
  excellent,  // 优秀 (<100ms)
  good,       // 良好 (100-200ms)
  poor,       // 较差 (200-500ms)
  bad,        // 很差 (>500ms)
}

/// 服务器消息类型
abstract class ServerMessage {
  final String type;
  final DateTime timestamp;

  ServerMessage({
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'pong':
        return ServerPong.fromJson(json);
      case 'state_update':
        return ServerStateUpdate.fromJson(json);
      case 'latency_warning':
        return ServerLatencyWarning.fromJson(json);
      case 'force_disconnect':
        return ServerForceDisconnect.fromJson(json);
      case 'player_joined':
        return ServerPlayerJoined.fromJson(json);
      case 'player_left':
        return ServerPlayerLeft.fromJson(json);
      default:
        return ServerUnknown(type: type, data: json);
    }
  }
}

class ServerPong extends ServerMessage {
  final DateTime serverTimestamp;

  ServerPong({
    required this.serverTimestamp,
  }) : super(type: 'pong');

  factory ServerPong.fromJson(Map<String, dynamic> json) {
    return ServerPong(
      serverTimestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ServerStateUpdate extends ServerMessage {
  final Map<String, dynamic> data;

  ServerStateUpdate({
    required this.data,
  }) : super(type: 'state_update');

  factory ServerStateUpdate.fromJson(Map<String, dynamic> json) {
    return ServerStateUpdate(
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class ServerLatencyWarning extends ServerMessage {
  final int latencyMs;
  final int threshold;

  ServerLatencyWarning({
    required this.latencyMs,
    required this.threshold,
  }) : super(type: 'latency_warning');

  factory ServerLatencyWarning.fromJson(Map<String, dynamic> json) {
    return ServerLatencyWarning(
      latencyMs: json['latencyMs'] as int,
      threshold: json['threshold'] as int,
    );
  }
}

class ServerForceDisconnect extends ServerMessage {
  final String reason;

  ServerForceDisconnect({
    required this.reason,
  }) : super(type: 'force_disconnect');

  factory ServerForceDisconnect.fromJson(Map<String, dynamic> json) {
    return ServerForceDisconnect(
      reason: json['reason'] as String,
    );
  }
}

class ServerPlayerJoined extends ServerMessage {
  final PlayerIdentity player;

  ServerPlayerJoined({
    required this.player,
  }) : super(type: 'player_joined');

  factory ServerPlayerJoined.fromJson(Map<String, dynamic> json) {
    return ServerPlayerJoined(
      player: PlayerIdentity.fromJson(json['player'] as Map<String, dynamic>),
    );
  }
}

class ServerPlayerLeft extends ServerMessage {
  final String playerId;
  final String? reason;

  ServerPlayerLeft({
    required this.playerId,
    this.reason,
  }) : super(type: 'player_left');

  factory ServerPlayerLeft.fromJson(Map<String, dynamic> json) {
    return ServerPlayerLeft(
      playerId: json['playerId'] as String,
      reason: json['reason'] as String?,
    );
  }
}

class ServerUnknown extends ServerMessage {
  final Map<String, dynamic> data;

  ServerUnknown({
    required String type,
    required this.data,
  }) : super(type: type);
}

/// 客户端消息类型
abstract class ClientMessage {
  final String type;
  final DateTime timestamp;

  ClientMessage({
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson();
}

class ClientPing extends ClientMessage {
  final DateTime clientTimestamp;

  ClientPing({
    DateTime? clientTimestamp,
  })  : clientTimestamp = clientTimestamp ?? DateTime.now(),
        super(type: 'ping');

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'timestamp': clientTimestamp.toIso8601String(),
  };
}

class ClientSubmitMessage extends ClientMessage {
  final String messageId;
  final String content;
  final String? replyTo;
  final List<String>? attachments;

  ClientSubmitMessage({
    required this.messageId,
    required this.content,
    this.replyTo,
    this.attachments,
  }) : super(type: 'submit_message');

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'messageId': messageId,
    'content': content,
    'replyTo': replyTo,
    'attachments': attachments,
  };
}

/// 网络配置
class NetworkConfig {
  final String host;
  final int port;
  final bool useTls;
  final Duration connectTimeout;
  final Duration pingInterval;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;
  final int latencyThresholdMs;      // 延迟警告阈值
  final int forceDisconnectLatencyMs; // 强制掉线阈值

  const NetworkConfig({
    required this.host,
    required this.port,
    this.useTls = true,
    this.connectTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 5),
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 2),
    this.latencyThresholdMs = 200,
    this.forceDisconnectLatencyMs = 500,
  });

  String get wsUrl => '${useTls ? 'wss' : 'ws'}://$host:$port';
}

/// 连接管理器
/// 
/// 管理 WebSocket 连接、延迟检测、自动重连
class ConnectionManager extends ChangeNotifier {
  final NetworkConfig config;
  final OfflineQueue _offlineQueue;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _latencyCheckTimer;

  // 状态
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  // 网络质量
  int _latencyMs = 0;
  int get latencyMs => _latencyMs;

  NetworkQuality get networkQuality => NetworkQuality(
    latencyMs: _latencyMs,
    isHighLatency: _latencyMs > config.latencyThresholdMs,
  );

  // 重连
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;

  // 流控制器
  final _messageController = StreamController<ServerMessage>.broadcast();
  Stream<ServerMessage> get messageStream => _messageController.stream;

  ConnectionManager({
    required this.config,
    OfflineQueue? offlineQueue,
  }) : _offlineQueue = offlineQueue ?? OfflineQueue();

  /// 连接到世界
  Future<void> connect({
    required String worldId,
    required PlayerIdentity identity,
  }) async {
    if (_state == ConnectionState.connecting || 
        _state == ConnectionState.connected) {
      return;
    }

    _setState(ConnectionState.connecting);
    _shouldReconnect = true;

    try {
      final wsUrl = '${config.wsUrl}/world/$worldId'
          '?player_id=${identity.id}'
          '&token=${identity.authToken ?? ''}'
          '&role=${identity.role.name}';

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      // 监听消息
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // 启动心跳和延迟检测
      _startHeartbeat();
      _startLatencyCheck();

      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;

      // 同步离线队列
      _syncOfflineQueue();

    } catch (e) {
      _setState(ConnectionState.error);
      _attemptReconnect(worldId: worldId, identity: identity);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _stopTimers();
    await _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  /// 发送消息
  Future<void> send(ClientMessage message) async {
    if (_state != ConnectionState.connected) {
      // 离线时加入队列
      await _offlineQueue.enqueue(message);
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      // 发送失败，加入队列
      await _offlineQueue.enqueue(message);
    }
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      config.pingInterval,
      (_) => _sendPing(),
    );
  }

  /// 启动延迟检测
  void _startLatencyCheck() {
    _latencyCheckTimer?.cancel();
    _latencyCheckTimer = Timer.periodic(
      config.pingInterval,
      (_) => _checkLatency(),
    );
  }

  /// 发送 ping
  void _sendPing() {
    if (_state != ConnectionState.connected) return;
    send(ClientPing());
  }

  /// 检查延迟
  DateTime? _lastPingTime;
  
  Future<void> _checkLatency() async {
    if (_state != ConnectionState.connected) return;

    _lastPingTime = DateTime.now();
    _sendPing();

    // 等待5秒检查是否收到pong
    await Future.delayed(const Duration(seconds: 5));

    // 如果延迟过高，通知UI
    if (_latencyMs > config.latencyThresholdMs) {
      _notifyHighLatency();
    }

    // 如果延迟超过强制掉线阈值，主动断开
    if (_latencyMs > config.forceDisconnectLatencyMs) {
      _forceDisconnect('网络延迟过高 (${_latencyMs}ms)，连接已断开');
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final message = ServerMessage.fromJson(json);

      // 处理 pong 消息，计算延迟
      if (message is ServerPong) {
        if (_lastPingTime != null) {
          _latencyMs = DateTime.now().difference(_lastPingTime!).inMilliseconds;
          notifyListeners();
        }
      }

      // 处理强制掉线
      if (message is ServerForceDisconnect) {
        _forceDisconnect(message.reason);
        return;
      }

      // 广播消息
      _messageController.add(message);
    } catch (e) {
      debugPrint('Failed to parse message: $e');
    }
  }

  /// 处理错误
  void _handleError(error) {
    debugPrint('WebSocket error: $error');
    _setState(ConnectionState.error);
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _stopTimers();
    if (_state != ConnectionState.disconnected) {
      _setState(ConnectionState.disconnected);
      // 尝试重连
      if (_shouldReconnect) {
        // 这里需要保存 worldId 和 identity
        // 简化处理：不重连，需要手动调用 connect
      }
    }
  }

  /// 尝试重连
  Future<void> _attemptReconnect({
    required String worldId,
    required PlayerIdentity identity,
  }) async {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _setState(ConnectionState.error);
      return;
    }

    _setState(ConnectionState.reconnecting);
    _reconnectAttempts++;

    await Future.delayed(config.reconnectDelay * _reconnectAttempts);
    
    if (_shouldReconnect) {
      await connect(worldId: worldId, identity: identity);
    }
  }

  /// 强制断开
  void _forceDisconnect(String reason) {
    _shouldReconnect = false;
    _stopTimers();
    _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);

    // 通知UI
    _messageController.add(ServerForceDisconnect(reason: reason));
  }

  /// 停止定时器
  void _stopTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _latencyCheckTimer?.cancel();
    _latencyCheckTimer = null;
  }

  /// 同步离线队列
  Future<void> _syncOfflineQueue() async {
    final pending = await _offlineQueue.getPending();
    for (final message in pending) {
      await send(message);
    }
    await _offlineQueue.clear();
  }

  /// 通知高延迟
  void _notifyHighLatency() {
    // 通过流通知UI
    _messageController.add(ServerLatencyWarning(
      latencyMs: _latencyMs,
      threshold: config.latencyThresholdMs,
    ));
  }

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimers();
    _channel?.sink.close();
    _messageController.close();
    super.dispose();
  }
}
