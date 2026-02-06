import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/chrono_vine/vine_node.dart';
import '../../services/avatar/avatar_service.dart';
import '../../models/chrono_vine/space_time_axis.dart';

/// 争议状态
enum ContentionStatus {
  active,      // 争议中（红色）
  resolving,   // 解决中（多人靠近）
  resolved,    // 已解决（变为共识水晶）
}

/// 协作参与者
class Collaborator {
  final String avatarId;
  final Offset3D position;
  final double energy;
  final DateTime joinedAt;

  Collaborator({
    required this.avatarId,
    required this.position,
    required this.energy,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();
}

/// 争议节点状态
class ContentionNode {
  final String nodeId;
  final Offset3D position;
  ContentionStatus status;
  final List<Collaborator> collaborators;
  double resolutionProgress;  // 0.0 - 1.0
  DateTime? resolvedAt;

  ContentionNode({
    required this.nodeId,
    required this.position,
    this.status = ContentionStatus.active,
    this.collaborators = const [],
    this.resolutionProgress = 0.0,
    this.resolvedAt,
  });

  bool get isActive => status == ContentionStatus.active;
  bool get isResolving => status == ContentionStatus.resolving;
  bool get isResolved => status == ContentionStatus.resolved;

  /// 计算总能量
  double get totalEnergy => collaborators.fold(0.0, (sum, c) => sum + c.energy);

  /// 获取最佳参与者（能量最高）
  Collaborator? get leadingCollaborator {
    if (collaborators.isEmpty) return null;
    return collaborators.reduce((a, b) => a.energy > b.energy ? a : b);
  }

  ContentionNode copyWith({
    ContentionStatus? status,
    List<Collaborator>? collaborators,
    double? resolutionProgress,
    DateTime? resolvedAt,
  }) {
    return ContentionNode(
      nodeId: nodeId,
      position: position,
      status: status ?? this.status,
      collaborators: collaborators ?? this.collaborators,
      resolutionProgress: resolutionProgress ?? this.resolutionProgress,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// 光束视觉效果
class BeamEffect {
  final String fromAvatarId;
  final String toNodeId;
  final Color color;
  final double intensity;  // 0.0 - 1.0
  final double width;
  final List<Offset3D> particles;  // 粒子效果

  BeamEffect({
    required this.fromAvatarId,
    required this.toNodeId,
    required this.color,
    this.intensity = 1.0,
    this.width = 2.0,
    this.particles = const [],
  });
}

/// 争议解决服务
/// 
/// 实现游戏化的多人协作争议解决机制
class ContentionResolutionService extends ChangeNotifier {
  // 配置
  static const double proximityThreshold = 30.0;  // 靠近阈值
  static const double baseResolutionSpeed = 0.02;  // 基础解决速度
  static const int minCollaborators = 2;  // 最少需要 2 人协作

  // 状态
  final Map<String, ContentionNode> _contentions = {};
  final Map<String, BeamEffect> _beams = {};
  Timer? _updateTimer;

  // 依赖
  final AvatarService? avatarService;

  // Getters
  List<ContentionNode> get activeContentions => _contentions.values
      .where((c) => c.isActive || c.isResolving)
      .toList();
  
  List<ContentionNode> get resolvedContentions => _contentions.values
      .where((c) => c.isResolved)
      .toList();
  
  Map<String, BeamEffect> get beams => Map.unmodifiable(_beams);

  ContentionResolutionService({this.avatarService}) {
    _init();
  }

  void _init() {
    // 启动更新循环（30fps）
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _update(),
    );
  }

  // ========== 争议管理 ==========

  /// 创建争议节点
  ContentionNode createContention(String nodeId, Offset3D position) {
    final contention = ContentionNode(
      nodeId: nodeId,
      position: position,
    );
    _contentions[nodeId] = contention;
    notifyListeners();
    return contention;
  }

  /// 移除争议
  void removeContention(String nodeId) {
    _contentions.remove(nodeId);
    _removeBeamsForNode(nodeId);
    notifyListeners();
  }

  /// 将普通节点标记为争议
  void markAsContention(VineNode node) {
    createContention(node.id, node.position.layoutPosition);
  }

  // ========== 核心更新循环 ==========

  void _update() {
    if (_contentions.isEmpty) return;
    if (avatarService == null) return;

    bool hasChanges = false;

    for (final contention in _contentions.values) {
      if (contention.isResolved) continue;

      // 1. 检测附近的 Avatar
      final nearbyAvatars = _findNearbyAvatars(contention);

      // 2. 更新协作者列表
      final updatedContention = _updateCollaborators(contention, nearbyAvatars);

      // 3. 更新光束效果
      _updateBeams(updatedContention, nearbyAvatars);

      // 4. 计算解决进度
      final newContention = _calculateProgress(updatedContention);

      // 5. 检查是否解决
      final finalContention = _checkResolution(newContention);

      if (finalContention != contention) {
        _contentions[contention.nodeId] = finalContention;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  // ========== 辅助方法 ==========
  
  double _distance(Offset3D a, Offset3D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  // ========== 协作逻辑 ==========

  List<AvatarData> _findNearbyAvatars(ContentionNode contention) {
    final nearby = <AvatarData>[];

    for (final avatar in avatarService!.avatars) {
      final distance = _distance(avatar.position, contention.position);
      if (distance <= proximityThreshold) {
        nearby.add(avatar);
      }
    }

    return nearby;
  }

  ContentionNode _updateCollaborators(
    ContentionNode contention,
    List<AvatarData> nearbyAvatars,
  ) {
    final newCollaborators = nearbyAvatars.map((avatar) {
      // 检查是否已经是协作者
      final existing = contention.collaborators
          .where((c) => c.avatarId == avatar.id)
          .firstOrNull;

      if (existing != null) {
        // 更新位置
        return Collaborator(
          avatarId: avatar.id,
          position: avatar.position,
          energy: avatar.energy,
          joinedAt: existing.joinedAt,
        );
      } else {
        // 新加入
        return Collaborator(
          avatarId: avatar.id,
          position: avatar.position,
          energy: avatar.energy,
        );
      }
    }).toList();

    // 更新状态
    final newStatus = newCollaborators.length >= minCollaborators
        ? ContentionStatus.resolving
        : ContentionStatus.active;

    return contention.copyWith(
      collaborators: newCollaborators,
      status: newStatus,
    );
  }

  ContentionNode _calculateProgress(ContentionNode contention) {
    if (!contention.isResolving) return contention;

    // 解决速度 = 基础速度 + 协作者加成 + 能量加成
    final collaboratorBonus = contention.collaborators.length * 0.01;
    final energyBonus = contention.totalEnergy * 0.01;
    
    final speed = baseResolutionSpeed + collaboratorBonus + energyBonus;
    final newProgress = (contention.resolutionProgress + speed).clamp(0.0, 1.0);

    return contention.copyWith(resolutionProgress: newProgress);
  }

  ContentionNode _checkResolution(ContentionNode contention) {
    if (contention.resolutionProgress >= 1.0 && !contention.isResolved) {
      // 解决完成！
      _onContentionResolved(contention);
      
      return contention.copyWith(
        status: ContentionStatus.resolved,
        resolvedAt: DateTime.now(),
      );
    }
    return contention;
  }

  void _onContentionResolved(ContentionNode contention) {
    // 触发解决效果
    _playResolutionEffect(contention);
    
    // 移除光束
    _removeBeamsForNode(contention.nodeId);
  }

  // ========== 光束效果 ==========

  void _updateBeams(ContentionNode contention, List<AvatarData> avatars) {
    for (final avatar in avatars) {
      final beamId = '${avatar.id}_${contention.nodeId}';
      
      // 计算颜色（基于能量和进度）
      final hue = (contention.resolutionProgress * 120).toInt();  // 红(0) -> 绿(120)
      final color = HSLColor.fromAHSL(1.0, hue.toDouble(), 0.8, 0.5).toColor();

      // 计算强度
      final intensity = avatar.energy * (1.0 + contention.resolutionProgress);

      // 生成粒子
      final particles = _generateParticles(
        avatar.position,
        contention.position,
        (5 * intensity).toInt(),
      );

      _beams[beamId] = BeamEffect(
        fromAvatarId: avatar.id,
        toNodeId: contention.nodeId,
        color: color,
        intensity: intensity,
        width: 2.0 + contention.resolutionProgress * 4,
        particles: particles,
      );
    }

    // 移除离开 Avatar 的光束
    _beams.removeWhere((id, beam) {
      if (beam.toNodeId != contention.nodeId) return false;
      return !avatars.any((a) => a.id == beam.fromAvatarId);
    });
  }

  List<Offset3D> _generateParticles(Offset3D from, Offset3D to, int count) {
    final particles = <Offset3D>[];
    final direction = to - from;
    
    for (var i = 0; i < count; i++) {
      final t = math.Random().nextDouble();
      final basePos = from + direction * t;
      
      // 添加随机偏移
      final jitter = Offset3D(
        x: (math.Random().nextDouble() - 0.5) * 5,
        y: (math.Random().nextDouble() - 0.5) * 5,
        z: (math.Random().nextDouble() - 0.5) * 5,
      );
      
      particles.add(basePos + jitter);
    }
    
    return particles;
  }

  void _removeBeamsForNode(String nodeId) {
    _beams.removeWhere((id, beam) => beam.toNodeId == nodeId);
  }

  void _playResolutionEffect(ContentionNode contention) {
    // 这里可以触发音效、粒子爆发等
    // 通过 notifyListeners 通知 UI 播放动画
  }

  // ========== 公共方法 ==========

  /// 获取节点的解决进度
  double getProgress(String nodeId) {
    return _contentions[nodeId]?.resolutionProgress ?? 0.0;
  }

  /// 获取节点的协作者数量
  int getCollaboratorCount(String nodeId) {
    return _contentions[nodeId]?.collaborators.length ?? 0;
  }

  /// 检查节点是否是争议状态
  bool isContention(String nodeId) {
    return _contentions.containsKey(nodeId);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _contentions.clear();
    _beams.clear();
    super.dispose();
  }
}
