/// VineNode 扩展 - 数据库支持
/// 
/// 添加 DAO 所需的额外字段

import 'vine_node.dart';
import 'space_time_axis.dart';

/// 扩展的 VineNode 数据类，包含数据库所需的全部字段
class VineNodeData {
  final String id;
  final String roomId;
  final String? messageId;
  final String authorId;
  final String? parentId;
  final String content;
  final String? contentPreview;
  final NodeType nodeType;
  final NodeStatus status;
  final SpaceTimePoint position;
  final NodeGeometry geometry;
  final MaterialState? materialState;
  final int lamport;
  final VectorClock? vectorClock;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  VineNodeData({
    required this.id,
    required this.roomId,
    this.messageId,
    required this.authorId,
    this.parentId,
    required this.content,
    this.contentPreview,
    this.nodeType = NodeType.message,
    this.status = NodeStatus.draft,
    required this.position,
    this.geometry = const NodeGeometry.voiceBlock(size: 1.0),
    this.materialState,
    this.lamport = 0,
    this.vectorClock,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从 VineNode 转换
  factory VineNodeData.fromVineNode(
    VineNode node, {
    required String roomId,
    DateTime? updatedAt,
    bool isDeleted = false,
  }) {
    return VineNodeData(
      id: node.id,
      roomId: roomId,
      messageId: node.messageId,
      authorId: node.authorId,
      parentId: node.parentId,
      content: node.content,
      contentPreview: node.contentPreview,
      nodeType: node.nodeType,
      status: node.status,
      position: node.position,
      geometry: node.geometry,
      materialState: node.materialState,
      lamport: node.lamport,
      vectorClock: node.vectorClock.isNotEmpty
          ? VectorClock(node.vectorClock)
          : null,
      createdAt: node.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted,
    );
  }

  /// 转换为 VineNode
  VineNode toVineNode() {
    return VineNode(
      id: id,
      messageId: messageId ?? id,
      position: position,
      content: content,
      contentPreview: contentPreview ?? '',
      nodeType: nodeType,
      status: status,
      parentId: parentId,
      geometry: geometry,
      materialState: materialState ?? const MaterialState(),
      authorId: authorId,
      lamport: lamport,
      vectorClock: vectorClock?.toMap() ?? {},
      createdAt: createdAt,
    );
  }

  VineNodeData copyWith({
    String? id,
    String? roomId,
    String? messageId,
    String? authorId,
    String? parentId,
    String? content,
    String? contentPreview,
    NodeType? nodeType,
    NodeStatus? status,
    SpaceTimePoint? position,
    NodeGeometry? geometry,
    MaterialState? materialState,
    int? lamport,
    VectorClock? vectorClock,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return VineNodeData(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      messageId: messageId ?? this.messageId,
      authorId: authorId ?? this.authorId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      contentPreview: contentPreview ?? this.contentPreview,
      nodeType: nodeType ?? this.nodeType,
      status: status ?? this.status,
      position: position ?? this.position,
      geometry: geometry ?? this.geometry,
      materialState: materialState ?? this.materialState,
      lamport: lamport ?? this.lamport,
      vectorClock: vectorClock ?? this.vectorClock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// VectorClock 类 - 用于 CRDT 版本向量
class VectorClock {
  final Map<String, int> _clocks;

  VectorClock([Map<String, int>? clocks]) : _clocks = clocks ?? {};

  int operator [](String nodeId) => _clocks[nodeId] ?? 0;

  void operator []=(String nodeId, int value) {
    _clocks[nodeId] = value;
  }

  void increment(String nodeId) {
    _clocks[nodeId] = (_clocks[nodeId] ?? 0) + 1;
  }

  Map<String, int> toMap() => Map.unmodifiable(_clocks);

  /// 解析字符串格式的 VectorClock
  static VectorClock? parse(String? str) {
    if (str == null || str.isEmpty) return null;
    
    try {
      final map = <String, int>{};
      // 简单格式: "node1:1,node2:3"
      for (final entry in str.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          map[parts[0]] = int.parse(parts[1]);
        }
      }
      return VectorClock(map);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return _clocks.entries.map((e) => '${e.key}:${e.value}').join(',');
  }
}
