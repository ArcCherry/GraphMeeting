/// ChronoVine 3D空间布局引擎
/// 
/// 将消息节点映射到3D空间，形成螺旋柱状的藤蔓结构：
/// - Y轴：时间（向上为正方向）
/// - XZ平面：参与者环绕分布
/// - 节点沿各自轨道螺旋上升

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/chrono_vine/chrono_vine_data.dart';

/// 螺旋柱布局配置
class SpiralLayoutConfig {
  /// 中心轴半径
  final double axisRadius;
  
  /// 螺旋升角（每单位时间的旋转角度）
  final double spiralAngle;
  
  /// 时间轴缩放因子（每毫秒对应的Y轴距离）
  final double timeScale;
  
  /// 节点最小间距
  final double minNodeSpacing;
  
  /// 深度层级间距（Z轴）
  final double depthSpacing;
  
  const SpiralLayoutConfig({
    this.axisRadius = 150.0,
    this.spiralAngle = 0.5,  // 每1000ms旋转0.5弧度
    this.timeScale = 0.1,    // 1秒 = 100单位高度
    this.minNodeSpacing = 60.0,
    this.depthSpacing = 30.0,
  });
}

/// 空间布局引擎
class VineLayoutEngine {
  final SpiralLayoutConfig config;
  
  /// 参与者轨道映射
  final Map<String, ParticipantTrack> _tracks = {};
  
  /// 节点ID到节点的映射
  final Map<String, VineNode> _nodes = {};
  
  /// 时间范围
  DateTime? _startTime;
  DateTime? _endTime;
  
  VineLayoutEngine({this.config = const SpiralLayoutConfig()});
  
  /// 注册参与者轨道
  void registerParticipant(String id, String name, Color color, {String? avatarUrl}) {
    if (_tracks.containsKey(id)) return;
    
    final count = _tracks.length;
    // 均匀分布参与者角度
    final angle = (count * 2 * math.pi / math.max(_tracks.length + 1, 3));
    
    _tracks[id] = ParticipantTrack(
      participantId: id,
      name: name,
      color: color,
      avatarUrl: avatarUrl,
      trackAngle: angle,
    );
  }
  
  /// 添加节点并计算其3D位置
  VineNode addNode({
    required String roomId,
    required String messageId,
    required String content,
    required String authorId,
    required DateTime timestamp,
    String? parentId,
    VineNodeType type = VineNodeType.voiceBlock,
    double? size,
  }) {
    // 确保参与者轨道存在
    if (!_tracks.containsKey(authorId)) {
      registerParticipant(authorId, 'User $authorId', Colors.blue);
    }
    
    final track = _tracks[authorId]!;
    
    // 计算时间对应的Y坐标
    final yPos = _timeToY(timestamp);
    
    // 计算螺旋位置（随时间旋转）
    final spiralRotation = timestamp.millisecondsSinceEpoch * config.spiralAngle / 1000;
    final angle = track.trackAngle + spiralRotation;
    
    // 基础位置（在轨道上）
    final xPos = math.cos(angle) * track.trackRadius;
    final zPos = math.sin(angle) * track.trackRadius;
    
    // 如果有父节点，考虑深度偏移
    int threadDepth = 0;
    if (parentId != null && _nodes.containsKey(parentId)) {
      final parent = _nodes[parentId]!;
      threadDepth = parent.position.threadDepth + 1;
    }
    
    // 深度偏移（向内或向外）
    final depthOffset = threadDepth * config.depthSpacing;
    final adjustedRadius = track.trackRadius + (threadDepth % 2 == 0 ? depthOffset : -depthOffset);
    
    final position = SpaceTimePoint(
      timestamp: timestamp,
      participantId: authorId,
      threadDepth: threadDepth,
      layoutPosition: Vector3D(
        math.cos(angle) * adjustedRadius,
        yPos,
        math.sin(angle) * adjustedRadius,
      ),
    );
    
    final node = VineNode.create(
      roomId: roomId,
      messageId: messageId,
      content: content,
      authorId: authorId,
      position: position,
      type: type,
      size: size,
      color: track.color,
      parentId: parentId,
    );
    
    _nodes[node.id] = node;
    
    // 更新参与者轨道
    track.nodeIds = [...track.nodeIds, node.id];
    
    // 更新时间范围
    _startTime = _startTime == null || timestamp.isBefore(_startTime!) 
        ? timestamp 
        : _startTime;
    _endTime = _endTime == null || timestamp.isAfter(_endTime!) 
        ? timestamp 
        : _endTime;
    
    // 检测分支/合并
    _detectTopology(node);
    
    return node;
  }
  
  /// 将时间转换为Y坐标
  double _timeToY(DateTime time) {
    if (_startTime == null) return 0.0;
    
    final diff = time.difference(_startTime!);
    return diff.inMilliseconds * config.timeScale;
  }
  
  /// 检测拓扑关系（分支/合并）
  void _detectTopology(VineNode newNode) {
    if (newNode.parentId == null) return;
    
    final parent = _nodes[newNode.parentId];
    if (parent == null) return;
    
    // 检查是否跨参与者回复（形成分支）
    if (newNode.authorId != parent.authorId) {
      // 这是一个分支连接
      if (!parent.branchTargetIds.contains(newNode.id)) {
        parent.connectTo(newNode.id, isBranch: true);
      }
    } else {
      // 同参与者的连续节点
      parent.connectTo(newNode.id, isBranch: false);
    }
    
    // 检测潜在的合并（内容相似度高的节点）
    _detectPotentialMerge(newNode);
  }
  
  /// 检测潜在合并点
  void _detectPotentialMerge(VineNode node) {
    // 简化的合并检测：在相近时间范围内，不同参与者讨论相似主题
    // 实际实现应该使用语义相似度
    final timeWindow = const Duration(minutes: 5);
    
    for (final other in _nodes.values) {
      if (other.id == node.id) continue;
      if (other.authorId == node.authorId) continue;
      
      final timeDiff = node.createdAt.difference(other.createdAt).abs();
      if (timeDiff > timeWindow) continue;
      
      // TODO: 使用语义嵌入计算相似度
      // 暂时使用简单的关键词匹配
      final similarity = _calculateSimilarity(node.content, other.content);
      
      if (similarity > 0.7) {
        // 潜在的合并点
        // 在实际应用中，这需要AI确认或用户手动确认
      }
    }
  }
  
  /// 计算内容相似度（简化版）
  double _calculateSimilarity(String a, String b) {
    final wordsA = a.toLowerCase().split(' ').toSet();
    final wordsB = b.toLowerCase().split(' ').toSet();
    
    final intersection = wordsA.intersection(wordsB);
    final union = wordsA.union(wordsB);
    
    return intersection.length / union.length;
  }
  
  /// 获取某个时间点的世界状态（用于回放）
  WorldSnapshot getWorldSnapshotAt(DateTime time) {
    final visibleNodes = _nodes.values
        .where((n) => n.createdAt.isBefore(time) || n.createdAt == time)
        .toList();
    
    // 计算建造进度
    final nodesWithProgress = visibleNodes.map((node) {
      if (node.status == NodeStatus.underConstruction) {
        final buildDuration = const Duration(seconds: 2);
        final elapsed = time.difference(node.createdAt);
        final progress = elapsed.inMilliseconds / buildDuration.inMilliseconds;
        return node.copyWith(buildProgress: progress.clamp(0.0, 1.0));
      }
      return node;
    }).toList();
    
    return WorldSnapshot(
      timestamp: time,
      nodes: nodesWithProgress,
      tracks: Map.from(_tracks),
      activeAvatars: _getActiveAvatarsAt(time),
    );
  }
  
  /// 获取某时刻活跃的Avatar
  List<AvatarState> _getActiveAvatarsAt(DateTime time) {
    // 返回在该时刻有操作的Avatar
    final activeIds = <String>{};
    
    for (final node in _nodes.values) {
      final timeDiff = time.difference(node.createdAt).abs();
      if (timeDiff < const Duration(seconds: 5)) {
        activeIds.add(node.authorId);
      }
      
      // 检查建造历史
      for (final event in node.constructionHistory) {
        final eventDiff = time.difference(event.timestamp).abs();
        if (eventDiff < const Duration(seconds: 2)) {
          activeIds.add(event.avatarId);
        }
      }
    }
    
    return activeIds.map((id) {
      final track = _tracks[id]!;
      return AvatarState(
        id: id,
        name: track.name,
        color: track.color,
        position: _getAvatarPositionAt(id, time),
        state: _getAvatarActivityState(id, time),
        energy: track.energy,
      );
    }).toList();
  }
  
  /// 计算Avatar在某时刻的位置
  Vector3D _getAvatarPositionAt(String avatarId, DateTime time) {
    final track = _tracks[avatarId];
    if (track == null) return Vector3D.zero;
    
    // 查找最近操作的节点
    VineNode? nearestNode;
    Duration? nearestDiff;
    
    for (final nodeId in track.nodeIds) {
      final node = _nodes[nodeId];
      if (node == null) continue;
      
      for (final event in node.constructionHistory) {
        if (event.avatarId != avatarId) continue;
        
        final diff = time.difference(event.timestamp).abs();
        if (nearestDiff == null || diff < nearestDiff) {
          nearestDiff = diff;
          nearestNode = node;
        }
      }
    }
    
    if (nearestNode == null) {
      // 返回轨道上的默认位置
      return Vector3D(
        math.cos(track.trackAngle) * track.trackRadius * 1.5,
        _timeToY(time),
        math.sin(track.trackAngle) * track.trackRadius * 1.5,
      );
    }
    
    // 在节点附近悬停
    return nearestNode.position.layoutPosition + Vector3D(30, 0, 30);
  }
  
  /// 获取Avatar的活动状态
  AvatarActivityState _getAvatarActivityState(String avatarId, DateTime time) {
    // 检查最近的活动
    for (final node in _nodes.values) {
      for (final event in node.constructionHistory) {
        if (event.avatarId != avatarId) continue;
        
        final diff = time.difference(event.timestamp);
        if (diff.abs() < const Duration(seconds: 3)) {
          return AvatarActivityState.working;
        }
      }
    }
    
    return AvatarActivityState.idle;
  }
  
  /// 生成连接边
  List<VineEdge> generateEdges() {
    final edges = <VineEdge>[];
    
    for (final node in _nodes.values) {
      // 父子连接
      if (node.parentId != null) {
        edges.add(VineEdge(
          id: 'edge_${node.parentId}_${node.id}',
          fromNodeId: node.parentId!,
          toNodeId: node.id,
          type: EdgeType.temporal,
          createdAt: node.createdAt,
        ));
      }
      
      // 分支连接
      for (final targetId in node.branchTargetIds) {
        edges.add(VineEdge(
          id: 'edge_branch_${node.id}_$targetId',
          fromNodeId: node.id,
          toNodeId: targetId,
          type: EdgeType.branch,
          createdAt: node.createdAt,
        ));
      }
    }
    
    return edges;
  }
  
  /// 获取所有节点（按深度排序，远到近）
  List<VineNode> getNodesSortedByDepth(Vector3D cameraPosition) {
    final sorted = _nodes.values.toList()
      ..sort((a, b) {
        final distA = (a.position.layoutPosition - cameraPosition).length;
        final distB = (b.position.layoutPosition - cameraPosition).length;
        return distB.compareTo(distA); // 远到近
      });
    return sorted;
  }
  
  /// 获取时间范围
  DateTimeRange? getTimeRange() {
    if (_startTime == null || _endTime == null) return null;
    return DateTimeRange(start: _startTime!, end: _endTime!);
  }
  
  /// 清除所有数据
  void clear() {
    _tracks.clear();
    _nodes.clear();
    _startTime = null;
    _endTime = null;
  }
  
  // Getters
  Map<String, ParticipantTrack> get tracks => Map.unmodifiable(_tracks);
  Map<String, VineNode> get nodes => Map.unmodifiable(_nodes);
}

/// 世界快照（用于回放）
class WorldSnapshot {
  final DateTime timestamp;
  final List<VineNode> nodes;
  final Map<String, ParticipantTrack> tracks;
  final List<AvatarState> activeAvatars;
  
  WorldSnapshot({
    required this.timestamp,
    required this.nodes,
    required this.tracks,
    required this.activeAvatars,
  });
}

/// Avatar状态（用于渲染）
class AvatarState {
  final String id;
  final String name;
  final Color color;
  final Vector3D position;
  final AvatarActivityState state;
  final double energy;
  
  AvatarState({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.state,
    required this.energy,
  });
}

enum AvatarActivityState {
  idle,      // 待机
  flying,    // 飞行中
  working,   // 工作中
  departing, // 离开
}

extension Vector3DExtension on Vector3D {
  static Vector3D get zero => const Vector3D(0, 0, 0);
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  
  DateTimeRange({required this.start, required this.end});
  
  Duration get duration => end.difference(start);
}
