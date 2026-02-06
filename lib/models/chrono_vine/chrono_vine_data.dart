/// ChronoVine 核心数据模型
/// 
/// 思维建筑工地的核心数据结构：
/// - 中央时间轴（正Y方向）
/// - 参与者螺旋轨道环绕
/// - 节点沿时间轴分布，形成藤蔓结构
/// - 分支/合并形成铁路线般的网络

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../services/vine_3d/engine3d.dart';

export '../../services/vine_3d/engine3d.dart' show Vec3;

/// 3D空间坐标点
class SpaceTimePoint {
  /// 时间戳（Y轴，向上为正）
  final DateTime timestamp;
  
  /// 参与者ID（决定环绕角度）
  final String participantId;
  
  /// 对话深度（Z轴，回复层级）
  final int threadDepth;
  
  /// 3D渲染坐标（计算得出）
  final Vector3D layoutPosition;
  
  const SpaceTimePoint({
    required this.timestamp,
    required this.participantId,
    this.threadDepth = 0,
    required this.layoutPosition,
  });
  
  SpaceTimePoint copyWith({
    DateTime? timestamp,
    String? participantId,
    int? threadDepth,
    Vector3D? layoutPosition,
  }) => SpaceTimePoint(
    timestamp: timestamp ?? this.timestamp,
    participantId: participantId ?? this.participantId,
    threadDepth: threadDepth ?? this.threadDepth,
    layoutPosition: layoutPosition ?? this.layoutPosition,
  );
}

/// Vector3D别名，使用Vec3实现
typedef Vector3D = Vec3;

/// 藤蔓节点类型
enum VineNodeType {
  /// 语音/文本消息 - 基础方块
  voiceBlock,
  /// 分支点 - 话题分裂
  branch,
  /// 合并点 - 共识达成
  merge,
  /// 里程碑 - 关键决策
  milestone,
  /// 争议 - 待解决
  contention,
  /// AI总结 - 花朵/果实
  aiSummary,
}

/// 节点状态
enum NodeStatus {
  /// 建造中（正在录制/编辑）
  underConstruction,
  /// 已放置（可见但可能未完成）
  placed,
  /// 已连接（与其他节点建立关系）
  connected,
  /// 已确认（达成共识）
  confirmed,
  /// 已归档（历史节点）
  archived,
}

/// 建造事件
class ConstructionEvent {
  final DateTime timestamp;
  final BuildAction action;
  final String avatarId;
  final Map<String, dynamic>? metadata;
  
  ConstructionEvent({
    required this.timestamp,
    required this.action,
    required this.avatarId,
    this.metadata,
  });
}

enum BuildAction {
  /// 初始放置
  placed,
  /// 建立连接
  connected,
  /// 内容修改
  modified,
  /// 被解决（争议→共识）
  resolved,
  /// AI总结生成
  summarized,
}

/// 藤蔓节点实体
class VineNode {
  final String id;
  final String roomId;
  final String messageId;
  
  /// 时空坐标
  final SpaceTimePoint position;
  
  /// 节点内容
  final String content;
  final String contentPreview;
  final VineNodeType type;
  NodeStatus status;
  
  /// 几何属性
  final double size;  // 方块大小，与语音时长/内容长度成正比
  final Color color;
  
  /// 拓扑连接
  String? parentId;
  List<String> childIds;
  List<String> branchTargetIds;  // 分支目标（引用其他分支）
  String? mergeSourceId;  // 合并来源
  
  /// 建造历史
  List<ConstructionEvent> constructionHistory;
  
  /// 建造进度 (0-1)
  double buildProgress;
  
  /// 悬浮动画相位
  double hoverPhase;
  
  /// AI生成的叶子
  List<AILeaf> leaves;
  
  /// 元数据
  final String authorId;
  final DateTime createdAt;
  DateTime? confirmedAt;
  
  VineNode({
    required this.id,
    required this.roomId,
    required this.messageId,
    required this.position,
    required this.content,
    required this.contentPreview,
    required this.type,
    this.status = NodeStatus.underConstruction,
    required this.size,
    required this.color,
    this.parentId,
    this.childIds = const [],
    this.branchTargetIds = const [],
    this.mergeSourceId,
    this.constructionHistory = const [],
    this.buildProgress = 0.0,
    this.hoverPhase = 0.0,
    this.leaves = const [],
    required this.authorId,
    required this.createdAt,
    this.confirmedAt,
  });
  
  /// 创建新节点
  factory VineNode.create({
    required String roomId,
    required String messageId,
    required String content,
    required String authorId,
    required SpaceTimePoint position,
    VineNodeType type = VineNodeType.voiceBlock,
    double? size,
    Color? color,
    String? parentId,
  }) {
    final now = DateTime.now();
    return VineNode(
      id: 'node_${now.millisecondsSinceEpoch}_$authorId',
      roomId: roomId,
      messageId: messageId,
      position: position,
      content: content,
      contentPreview: content.length > 100 
          ? '${content.substring(0, 100)}...' 
          : content,
      type: type,
      size: size ?? 20.0,
      color: color ?? Colors.blue,
      parentId: parentId,
      authorId: authorId,
      createdAt: now,
      constructionHistory: [
        ConstructionEvent(
          timestamp: now,
          action: BuildAction.placed,
          avatarId: authorId,
        ),
      ],
    );
  }
  
  /// 更新建造进度
  void updateBuildProgress(double progress) {
    buildProgress = progress.clamp(0.0, 1.0);
    if (progress >= 1.0 && status == NodeStatus.underConstruction) {
      status = NodeStatus.placed;
    }
  }
  
  /// 添加连接
  void connectTo(String targetId, {bool isBranch = false}) {
    if (isBranch) {
      branchTargetIds = [...branchTargetIds, targetId];
    } else {
      childIds = [...childIds, targetId];
    }
    constructionHistory = [
      ...constructionHistory,
      ConstructionEvent(
        timestamp: DateTime.now(),
        action: BuildAction.connected,
        avatarId: authorId,
        metadata: {'targetId': targetId, 'isBranch': isBranch},
      ),
    ];
    status = NodeStatus.connected;
  }
  
  /// 标记为已确认（达成共识）
  void confirm() {
    status = NodeStatus.confirmed;
    confirmedAt = DateTime.now();
  }
  
  /// 添加AI叶子
  void addLeaf(AILeaf leaf) {
    leaves = [...leaves, leaf];
    constructionHistory = [
      ...constructionHistory,
      ConstructionEvent(
        timestamp: DateTime.now(),
        action: BuildAction.summarized,
        avatarId: 'ai_system',
        metadata: {'leafType': leaf.type.toString()},
      ),
    ];
  }
  
  VineNode copyWith({
    SpaceTimePoint? position,
    String? content,
    NodeStatus? status,
    double? buildProgress,
    double? hoverPhase,
    List<AILeaf>? leaves,
    List<String>? childIds,
    List<String>? branchTargetIds,
    DateTime? confirmedAt,
  }) => VineNode(
    id: id,
    roomId: roomId,
    messageId: messageId,
    position: position ?? this.position,
    content: content ?? this.content,
    contentPreview: contentPreview,
    type: type,
    status: status ?? this.status,
    size: size,
    color: color,
    parentId: parentId,
    childIds: childIds ?? this.childIds,
    branchTargetIds: branchTargetIds ?? this.branchTargetIds,
    mergeSourceId: mergeSourceId,
    constructionHistory: constructionHistory,
    buildProgress: buildProgress ?? this.buildProgress,
    hoverPhase: hoverPhase ?? this.hoverPhase,
    leaves: leaves ?? this.leaves,
    authorId: authorId,
    createdAt: createdAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
  );
}

/// AI生成的叶子
class AILeaf {
  final String id;
  final AILeafType type;
  final String title;
  final String content;
  final List<TodoItem> todos;
  final double relevanceScore;
  final DateTime generatedAt;
  final Vector3D offset;  // 相对于父节点的偏移
  
  AILeaf({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.todos = const [],
    required this.relevanceScore,
    required this.generatedAt,
    required this.offset,
  });
  
  factory AILeaf.generate({
    required VineNode parentNode,
    required AILeafType type,
    required String title,
    required String content,
    List<TodoItem>? todos,
  }) {
    // 计算偏移：在父节点上方，略有随机
    final random = math.Random();
    return AILeaf(
      id: 'leaf_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      content: content,
      todos: todos ?? [],
      relevanceScore: 0.8 + random.nextDouble() * 0.2,
      generatedAt: DateTime.now(),
      offset: Vector3D(
        (random.nextDouble() - 0.5) * 40,
        -30 - random.nextDouble() * 20,
        (random.nextDouble() - 0.5) * 20,
      ),
    );
  }
}

enum AILeafType {
  summary,      // 内容总结
  actionItems,  // 行动清单
  decision,     // 决策建议
  riskAlert,    // 风险提醒
  insight,      // 洞察发现
  reference,    // 关联资料
}

class TodoItem {
  final String id;
  final String description;
  final TodoPriority priority;
  final String? assigneeId;
  final DateTime? deadline;
  bool isCompleted;
  final String? sourceMessageId;
  
  TodoItem({
    required this.id,
    required this.description,
    this.priority = TodoPriority.medium,
    this.assigneeId,
    this.deadline,
    this.isCompleted = false,
    this.sourceMessageId,
  });
}

enum TodoPriority { low, medium, high, urgent }

/// 连接边
class VineEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final EdgeType type;
  final DateTime createdAt;
  double growthProgress;  // 0-1，用于生长动画
  
  VineEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.type = EdgeType.temporal,
    required this.createdAt,
    this.growthProgress = 0.0,
  });
}

enum EdgeType {
  temporal,   // 时间序（父子）
  branch,     // 分支（话题分裂）
  merge,      // 合并（共识达成）
  reference,  // 引用
  consensus,  // 共识连接
}

/// 参与者轨道
class ParticipantTrack {
  final String participantId;
  final String name;
  final Color color;
  final String? avatarUrl;
  
  /// 轨道角度（在XY平面上的角度）
  final double trackAngle;
  
  /// 轨道半径（距离中心轴的距离）
  final double trackRadius;
  
  /// 该参与者的所有节点ID
  List<String> nodeIds;
  
  /// 活跃度（影响轨道亮度）
  double energy;
  
  ParticipantTrack({
    required this.participantId,
    required this.name,
    required this.color,
    this.avatarUrl,
    required this.trackAngle,
    this.trackRadius = 150.0,
    this.nodeIds = const [],
    this.energy = 1.0,
  });
}
