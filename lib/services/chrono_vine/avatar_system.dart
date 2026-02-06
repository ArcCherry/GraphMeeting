/// Avatar实体化系统
/// 
/// 将每个参与者转化为3D空间中的可飞行Avatar：
/// - 工蜂般的建筑师
/// - 飞行轨迹拖尾
/// - 放置节点时的动画
/// - 靠近节点自动工作

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/chrono_vine/chrono_vine_data.dart';
import 'vine_layout_engine.dart';

/// Avatar实体
class AvatarEntity {
  final String id;
  final String name;
  final Color color;
  final String? avatarUrl;
  
  /// 3D变换
  Vector3D position;
  Vector3D rotation;
  double scale;
  
  /// 状态
  AvatarBehaviorState state;
  
  /// 飞行轨迹
  List<TrailPoint> trail;
  
  /// 能量（影响发光强度和操作速度）
  double energy;
  
  /// 当前目标（如果有）
  String? targetNodeId;
  
  /// 状态机数据
  FlyingData? flyingData;
  WorkingData? workingData;
  
  AvatarEntity({
    required this.id,
    required this.name,
    required this.color,
    this.avatarUrl,
    required this.position,
    this.rotation = const Vector3D(0, 0, 0),
    this.scale = 1.0,
    this.state = AvatarBehaviorState.idle,
    this.trail = const [],
    this.energy = 1.0,
    this.targetNodeId,
    this.flyingData,
    this.workingData,
  });
  
  /// 更新状态
  void update(double deltaTime, VineLayoutEngine engine) {
    // 更新轨迹
    _updateTrail(deltaTime);
    
    switch (state) {
      case AvatarBehaviorState.idle:
        _updateIdle(deltaTime);
        break;
      case AvatarBehaviorState.flying:
        _updateFlying(deltaTime);
        break;
      case AvatarBehaviorState.working:
        _updateWorking(deltaTime);
        break;
      case AvatarBehaviorState.departing:
        _updateDeparting(deltaTime);
        break;
    }
  }
  
  /// 更新轨迹
  void _updateTrail(double deltaTime) {
    trail = [
      TrailPoint(
        position: position,
        timestamp: DateTime.now(),
        intensity: energy,
      ),
      ...trail.where((t) => 
        DateTime.now().difference(t.timestamp) < const Duration(seconds: 3)
      ),
    ];
    
    // 限制轨迹长度
    if (trail.length > 30) {
      trail = trail.sublist(0, 30);
    }
  }
  
  /// 待机状态：悬浮呼吸
  void _updateIdle(double deltaTime) {
    // 悬浮动画
    final hoverOffset = math.sin(DateTime.now().millisecondsSinceEpoch / 1000) * 2;
    position = Vector3D(
      position.x,
      position.y + hoverOffset * deltaTime,
      position.z,
    );
    
    // 能量恢复
    energy = math.min(1.0, energy + deltaTime * 0.1);
  }
  
  /// 飞行状态
  void _updateFlying(double deltaTime) {
    if (flyingData == null) return;
    
    final data = flyingData!;
    data.progress += deltaTime * data.speed;
    
    if (data.progress >= 1.0) {
      // 到达目的地
      position = data.to;
      
      if (targetNodeId != null) {
        // 切换到工作状态
        state = AvatarBehaviorState.working;
        workingData = WorkingData(
          nodeId: targetNodeId!,
          startTime: DateTime.now(),
          action: WorkType.planting,
        );
      } else {
        state = AvatarBehaviorState.idle;
      }
      flyingData = null;
      return;
    }
    
    // 插值位置（带缓动）
    final t = _easeInOutCubic(data.progress);
    position = data.from.lerp(data.to, t);
    
    // 计算朝向
    final direction = (data.to - data.from).normalized;
    rotation = Vector3D(
      math.asin(-direction.y),
      math.atan2(direction.x, direction.z),
      0,
    );
    
    // 消耗能量
    energy = math.max(0.3, energy - deltaTime * 0.05);
  }
  
  /// 工作状态
  void _updateWorking(double deltaTime) {
    if (workingData == null) return;
    
    final data = workingData!;
    final elapsed = DateTime.now().difference(data.startTime);
    
    // 工作动画（在节点周围小幅移动）
    final workAnim = elapsed.inMilliseconds / 1000;
    position = Vector3D(
      position.x + math.sin(workAnim * 3) * 0.5,
      position.y + math.sin(workAnim * 2) * 0.3,
      position.z + math.cos(workAnim * 3) * 0.5,
    );
    
    // 工作完成
    if (elapsed > const Duration(seconds: 2)) {
      // 播放完成效果
      state = AvatarBehaviorState.departing;
      workingData = null;
    }
  }
  
  /// 离开状态
  void _updateDeparting(double deltaTime) {
    // 向上飞起，然后进入待机
    position = Vector3D(
      position.x,
      position.y + 30 * deltaTime,
      position.z,
    );
    
    // 延迟后进入待机
    Future.delayed(const Duration(milliseconds: 500), () {
      state = AvatarBehaviorState.idle;
      targetNodeId = null;
    });
  }
  
  /// 飞往目标
  void flyTo(Vector3D target, {String? nodeId, double speed = 2.0}) {
    state = AvatarBehaviorState.flying;
    targetNodeId = nodeId;
    flyingData = FlyingData(
      from: position,
      to: target,
      speed: speed,
      progress: 0.0,
    );
  }
  
  /// 开始工作
  void startWorking(String nodeId, WorkType action) {
    state = AvatarBehaviorState.working;
    targetNodeId = nodeId;
    workingData = WorkingData(
      nodeId: nodeId,
      startTime: DateTime.now(),
      action: action,
    );
  }
  
  /// 离开
  void depart() {
    state = AvatarBehaviorState.departing;
  }
  
  /// 缓动函数
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}

/// Avatar行为状态
enum AvatarBehaviorState {
  idle,      // 待机悬浮
  flying,    // 飞行中
  working,   // 工作中
  departing, // 离开
}

/// 飞行数据
class FlyingData {
  final Vector3D from;
  final Vector3D to;
  double speed;
  double progress;
  
  FlyingData({
    required this.from,
    required this.to,
    required this.speed,
    required this.progress,
  });
}

/// 工作数据
class WorkingData {
  final String nodeId;
  final DateTime startTime;
  final WorkType action;
  double progress;
  
  WorkingData({
    required this.nodeId,
    required this.startTime,
    required this.action,
    this.progress = 0.0,
  });
}

/// 工作类型
enum WorkType {
  planting,   // 种植新节点
  weaving,    // 连接线条
  resolving,  // 解决争议
  harvesting, // 收获共识
}

/// 轨迹点
class TrailPoint {
  final Vector3D position;
  final DateTime timestamp;
  final double intensity;
  
  TrailPoint({
    required this.position,
    required this.timestamp,
    required this.intensity,
  });
}

/// Avatar系统管理器
class AvatarSystem {
  final Map<String, AvatarEntity> _avatars = {};
  
  /// 创建Avatar
  AvatarEntity createAvatar(String id, String name, Color color, {
    String? avatarUrl,
    Vector3D? initialPosition,
  }) {
    final avatar = AvatarEntity(
      id: id,
      name: name,
      color: color,
      avatarUrl: avatarUrl,
      position: initialPosition ?? Vector3D.zero,
    );
    _avatars[id] = avatar;
    return avatar;
  }
  
  /// 获取Avatar
  AvatarEntity? getAvatar(String id) => _avatars[id];
  
  /// 移除Avatar
  void removeAvatar(String id) => _avatars.remove(id);
  
  /// 更新所有Avatar
  void updateAll(double deltaTime, VineLayoutEngine engine) {
    for (final avatar in _avatars.values) {
      avatar.update(deltaTime, engine);
    }
  }
  
  /// 触发Avatar前往放置节点
  void dispatchToPlaceNode(String avatarId, Vector3D nodePosition, String nodeId) {
    final avatar = _avatars[avatarId];
    if (avatar == null) return;
    
    // 在节点上方悬停
    final hoverPosition = nodePosition + Vector3D(0, 20, 0);
    avatar.flyTo(hoverPosition, nodeId: nodeId, speed: 3.0);
  }
  
  /// 触发Avatar参与协作解决
  void dispatchToCollaborate(String avatarId, Vector3D contentionPosition) {
    final avatar = _avatars[avatarId];
    if (avatar == null) return;
    
    // 围绕争议节点盘旋
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final radius = 30 + random.nextDouble() * 20;
    
    final orbitPosition = contentionPosition + Vector3D(
      math.cos(angle) * radius,
      random.nextDouble() * 20,
      math.sin(angle) * radius,
    );
    
    avatar.flyTo(orbitPosition, speed: 2.5);
  }
  
  /// 获取所有Avatar
  List<AvatarEntity> get allAvatars => _avatars.values.toList();
  
  /// 获取活跃Avatar（能量>0.5）
  List<AvatarEntity> get activeAvatars => 
    _avatars.values.where((a) => a.energy > 0.5).toList();
}

/// 接近检测系统
class ProximitySystem {
  final double interactionRadius;
  
  ProximitySystem({this.interactionRadius = 50.0});
  
  /// 检测Avatar与节点的接近
  List<ProximityInteraction> checkProximity(
    List<AvatarEntity> avatars,
    List<VineNode> nodes,
  ) {
    final interactions = <ProximityInteraction>[];
    
    for (final avatar in avatars) {
      for (final node in nodes) {
        final distance = (avatar.position - node.position.layoutPosition).length;
        
        if (distance < interactionRadius) {
          interactions.add(ProximityInteraction(
            avatarId: avatar.id,
            nodeId: node.id,
            distance: distance,
            kind: node.type == VineNodeType.contention 
                ? InteractionKind.resolve 
                : InteractionKind.inspect,
          ));
        }
      }
    }
    
    return interactions;
  }
  
  /// 检测多人协作
  List<Collaboration> checkCollaborations(
    List<AvatarEntity> avatars,
    VineNode contestedNode,
  ) {
    final nearby = avatars.where((a) {
      final dist = (a.position - contestedNode.position.layoutPosition).length;
      return dist < interactionRadius * 0.6;
    }).toList();
    
    if (nearby.length >= 2) {
      return [
        Collaboration(
          participantIds: nearby.map((a) => a.id).toList(),
          targetNodeId: contestedNode.id,
          totalPower: nearby.fold(0.0, (sum, a) => sum + a.energy),
        ),
      ];
    }
    
    return [];
  }
}

/// 接近交互
class ProximityInteraction {
  final String avatarId;
  final String nodeId;
  final double distance;
  final InteractionKind kind;
  
  ProximityInteraction({
    required this.avatarId,
    required this.nodeId,
    required this.distance,
    required this.kind,
  });
}

enum InteractionKind {
  inspect,  // 查看
  resolve,  // 解决
  connect,  // 连接
}

/// 协作解决
class Collaboration {
  final List<String> participantIds;
  final String targetNodeId;
  final double totalPower;
  double progress;
  
  Collaboration({
    required this.participantIds,
    required this.targetNodeId,
    required this.totalPower,
    this.progress = 0.0,
  });
}
