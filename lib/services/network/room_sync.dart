import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/result.dart';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/leaf_attachment.dart';
import '../../models/chrono_vine/space_time_axis.dart';
import '../../services/avatar/avatar_service.dart';
import 'socket_client.dart';

/// 同步事件类型
enum SyncEventType {
  nodeCreated,
  nodeUpdated,
  nodeDeleted,
  avatarMoved,
  avatarStateChanged,
  leafGenerated,
  userJoined,
  userLeft,
  consensusFormed,
  contentionResolved,
}

/// 同步事件
class SyncEvent {
  final SyncEventType type;
  final String roomId;
  final String userId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String vectorClock;

  SyncEvent({
    required this.type,
    required this.roomId,
    required this.userId,
    required this.data,
    required this.vectorClock,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'roomId': roomId,
        'userId': userId,
        'data': data,
        'vectorClock': vectorClock,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEvent(
      type: SyncEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncEventType.nodeCreated,
      ),
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      vectorClock: json['vectorClock'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}

/// 房间状态
class RoomState {
  final String roomId;
  final Map<String, VineNode> nodes;
  final Map<String, AvatarData> avatars;
  final Map<String, int> vectorClock;
  final DateTime lastUpdate;

  const RoomState({
    required this.roomId,
    this.nodes = const {},
    this.avatars = const {},
    this.vectorClock = const {},
    required this.lastUpdate,
  });

  RoomState copyWith({
    String? roomId,
    Map<String, VineNode>? nodes,
    Map<String, AvatarData>? avatars,
    Map<String, int>? vectorClock,
    DateTime? lastUpdate,
  }) {
    return RoomState(
      roomId: roomId ?? this.roomId,
      nodes: nodes ?? this.nodes,
      avatars: avatars ?? this.avatars,
      vectorClock: vectorClock ?? this.vectorClock,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// 房间同步服务
/// 
/// 管理房间状态同步，处理冲突解决
class RoomSyncService extends ChangeNotifier {
  final String _currentUserId;
  final String _roomId;
  final SocketClient _socket;
  final _uuid = const Uuid();

  // 本地状态
  RoomState _state;
  final _pendingEvents = <SyncEvent>[];
  final _eventController = StreamController<SyncEvent>.broadcast();

  // 订阅
  StreamSubscription<SocketMessage>? _messageSubscription;
  StreamSubscription<NetworkError>? _errorSubscription;

  // Getters
  RoomState get state => _state;
  String get roomId => _roomId;
  String get currentUserId => _currentUserId;
  Stream<SyncEvent> get eventStream => _eventController.stream;
  List<SyncEvent> get pendingEvents => List.unmodifiable(_pendingEvents);

  bool get isOnline => _socket.isConnected;

  RoomSyncService({
    required String roomId,
    required String userId,
    SocketClient? socket,
  })  : _roomId = roomId,
        _currentUserId = userId,
        _socket = socket ?? SocketClient(url: _getWebSocketUrl(roomId, userId)),
        _state = RoomState(
          roomId: roomId,
          lastUpdate: DateTime.now(),
        ) {
    _init();
  }

  static String _getWebSocketUrl(String roomId, String userId) {
    // 生产环境应该使用环境变量或配置
    const baseUrl = 'wss://api.graphmeeting.com';
    return '$baseUrl/rooms/$roomId?userId=$userId';
  }

  void _init() {
    // 监听消息
    _messageSubscription = _socket.messageStream.listen(_handleMessage);
    _errorSubscription = _socket.errorStream.listen(_handleError);

    // 自动连接
    connect();
  }

  // ========== 连接管理 ==========

  Future<void> connect() async {
    final result = await _socket.connect();
    result.map((_) {
      // 连接成功后发送本地未同步的事件
      _syncPendingEvents();
    });
  }

  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _socket.disconnect();
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }

  // ========== 状态更新 ==========

  /// 添加/更新节点
  Future<Result<void, NetworkError>> upsertNode(VineNode node) async {
    final event = _createEvent(
      SyncEventType.nodeCreated,
      {'node': node.toJson()},
    );

    // 立即更新本地状态（乐观更新）
    _updateLocalState(event);

    // 发送给服务器
    return _sendEvent(event);
  }

  /// 删除节点
  Future<Result<void, NetworkError>> deleteNode(String nodeId) async {
    final event = _createEvent(
      SyncEventType.nodeDeleted,
      {'nodeId': nodeId},
    );

    _updateLocalState(event);
    return _sendEvent(event);
  }

  /// 更新 Avatar 位置
  Future<Result<void, NetworkError>> updateAvatarPosition(
    String avatarId,
    Offset3D position,
  ) async {
    final event = _createEvent(
      SyncEventType.avatarMoved,
      {
        'avatarId': avatarId,
        'position': position.toJson(),
      },
    );

    // Avatar 移动太频繁，只发送给服务器，不立即更新本地（已经更新了）
    return _sendEvent(event);
  }

  /// Avatar 状态变化
  Future<Result<void, NetworkError>> updateAvatarState(
    String avatarId,
    String state,
  ) async {
    final event = _createEvent(
      SyncEventType.avatarStateChanged,
      {
        'avatarId': avatarId,
        'state': state,
      },
    );

    return _sendEvent(event);
  }

  /// 生成叶子
  Future<Result<void, NetworkError>> generateLeaf(
    String nodeId,
    LeafAttachment leaf,
  ) async {
    final event = _createEvent(
      SyncEventType.leafGenerated,
      {
        'nodeId': nodeId,
        'leaf': leaf.toJson(),
      },
    );

    _updateLocalState(event);
    return _sendEvent(event);
  }

  /// 形成共识
  Future<Result<void, NetworkError>> formConsensus(
    String nodeId,
    List<String> participantIds,
  ) async {
    final event = _createEvent(
      SyncEventType.consensusFormed,
      {
        'nodeId': nodeId,
        'participantIds': participantIds,
      },
    );

    _updateLocalState(event);
    return _sendEvent(event);
  }

  /// 解决争议
  Future<Result<void, NetworkError>> resolveContention(
    String nodeId,
    String resolution,
  ) async {
    final event = _createEvent(
      SyncEventType.contentionResolved,
      {
        'nodeId': nodeId,
        'resolution': resolution,
      },
    );

    _updateLocalState(event);
    return _sendEvent(event);
  }

  // ========== 私有方法 ==========

  SyncEvent _createEvent(SyncEventType type, Map<String, dynamic> data) {
    return SyncEvent(
      type: type,
      roomId: _roomId,
      userId: _currentUserId,
      data: data,
      vectorClock: _incrementVectorClock(),
    );
  }

  String _incrementVectorClock() {
    final clock = Map<String, int>.from(_state.vectorClock);
    clock[_currentUserId] = (clock[_currentUserId] ?? 0) + 1;

    _state = _state.copyWith(vectorClock: clock);

    // 序列化向量时钟
    return clock.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  Result<void, NetworkError> _sendEvent(SyncEvent event) {
    if (!_socket.isConnected) {
      // 离线模式：加入待发送队列
      _pendingEvents.add(event);
      notifyListeners();
      return Result.ok(null);
    }

    final message = SocketMessage(
      type: 'sync_event',
      payload: event.toJson(),
    );

    return _socket.send(message);
  }

  void _updateLocalState(SyncEvent event) {
    switch (event.type) {
      case SyncEventType.nodeCreated:
        final nodeJson = event.data['node'] as Map<String, dynamic>;
        final node = VineNode.fromJson(nodeJson);
        final newNodes = Map<String, VineNode>.from(_state.nodes);
        newNodes[node.id] = node;
        _state = _state.copyWith(nodes: newNodes);
        break;

      case SyncEventType.nodeDeleted:
        final nodeId = event.data['nodeId'] as String;
        final newNodes = Map<String, VineNode>.from(_state.nodes);
        newNodes.remove(nodeId);
        _state = _state.copyWith(nodes: newNodes);
        break;

      case SyncEventType.leafGenerated:
        final nodeId = event.data['nodeId'] as String;
        final leafJson = event.data['leaf'] as Map<String, dynamic>;
        final leaf = LeafAttachment.fromJson(leafJson);

        final node = _state.nodes[nodeId];
        if (node != null) {
          final newNode = node.copyWith(leaves: [...node.leaves, leaf]);
          final newNodes = Map<String, VineNode>.from(_state.nodes);
          newNodes[nodeId] = newNode;
          _state = _state.copyWith(nodes: newNodes);
        }
        break;

      default:
        break;
    }

    _state = _state.copyWith(lastUpdate: DateTime.now());
    _eventController.add(event);
    notifyListeners();
  }

  void _handleMessage(SocketMessage message) {
    if (message.type != 'sync_event') return;

    try {
      final eventJson = message.payload as Map<String, dynamic>;
      final event = SyncEvent.fromJson(eventJson);

      // 忽略自己发送的事件
      if (event.userId == _currentUserId) return;

      // 解决冲突（Last-Write-Wins）
      if (_shouldApplyEvent(event)) {
        _updateLocalState(event);
      }
    } catch (e) {
      debugPrint('Failed to handle sync event: $e');
    }
  }

  bool _shouldApplyEvent(SyncEvent event) {
    // 简单的 LWW（Last-Write-Wins）策略
    // 更复杂的 CRDT 可以在这里实现
    return event.timestamp.isAfter(_state.lastUpdate) ||
        event.timestamp.difference(_state.lastUpdate).inSeconds.abs() < 2;
  }

  void _handleError(NetworkError error) {
    debugPrint('RoomSync error: $error');
  }

  void _syncPendingEvents() {
    if (_pendingEvents.isEmpty) return;

    debugPrint('Syncing ${_pendingEvents.length} pending events');

    final eventsToSync = List<SyncEvent>.from(_pendingEvents);
    _pendingEvents.clear();

    for (final event in eventsToSync) {
      _sendEvent(event);
    }

    notifyListeners();
  }
}

/// 扩展：为 VineNode 添加 toJson/fromJson
extension VineNodeJson on VineNode {
  Map<String, dynamic> toJson() => {
        'id': id,
        'messageId': messageId,
        'position': position.toJson(),
        'content': content,
        'contentPreview': contentPreview,
        'nodeType': nodeType.name,
        'status': status.name,
        'parentId': parentId,
        'branchIds': branchIds,
        'mergeTargetId': mergeTargetId,
        'authorId': authorId,
        'createdAt': createdAt.toIso8601String(),
        'leaves': leaves.map((l) => l.toJson()).toList(),
      };

  static VineNode fromJson(Map<String, dynamic> json) {
    return VineNode(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      position: SpaceTimePoint.fromJson(json['position'] as Map<String, dynamic>),
      content: json['content'] as String,
      contentPreview: json['contentPreview'] as String,
      nodeType: NodeType.values.firstWhere((e) => e.name == json['nodeType']),
      status: NodeStatus.values.firstWhere((e) => e.name == json['status']),
      parentId: json['parentId'] as String?,
      branchIds: (json['branchIds'] as List<dynamic>?)?.cast<String>() ?? [],
      mergeTargetId: json['mergeTargetId'] as String?,
      authorId: json['authorId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      leaves: (json['leaves'] as List<dynamic>)
          .map((l) => LeafAttachment.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 扩展：SpaceTimePoint JSON
extension SpaceTimePointJson on SpaceTimePoint {
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'participantId': participantId,
        'threadDepth': threadDepth,
        'layoutPosition': layoutPosition,
      };

  static SpaceTimePoint fromJson(Map<String, dynamic> json) {
    return SpaceTimePoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      participantId: json['participantId'] as String,
      threadDepth: json['threadDepth'] as int,
      layoutPosition: Offset3D.fromJson(json['layoutPosition'] as Map<String, dynamic>),
    );
  }
}

/// 扩展：Offset3D JSON
extension Offset3DJson on Offset3D {
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  static Offset3D fromJson(Map<String, dynamic> json) {
    return Offset3D(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }
}
