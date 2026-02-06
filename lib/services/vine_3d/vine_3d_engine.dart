/// 3D藤蔓渲染引擎
/// 
/// 提供真实的3D投影、光照、阴影和粒子效果

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 3D向量
class Vector3 {
  final double x, y, z;
  
  const Vector3(this.x, this.y, this.z);
  
  Vector3 operator +(Vector3 other) => Vector3(x + other.x, y + other.y, z + other.z);
  Vector3 operator -(Vector3 other) => Vector3(x - other.x, y - other.y, z - other.z);
  Vector3 operator *(double scalar) => Vector3(x * scalar, y * scalar, z * scalar);
  
  double get length => math.sqrt(x * x + y * y + z * z);
  
  Vector3 get normalized {
    final len = length;
    if (len == 0) return const Vector3(0, 0, 0);
    return Vector3(x / len, y / len, z / len);
  }
  
  /// 叉乘
  Vector3 cross(Vector3 other) => Vector3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
  
  /// 点乘
  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;
  
  /// 绕Y轴旋转
  Vector3 rotateY(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vector3(
      x * cos - z * sin,
      y,
      x * sin + z * cos,
    );
  }
  
  /// 绕X轴旋转
  Vector3 rotateX(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vector3(
      x,
      y * cos - z * sin,
      y * sin + z * cos,
    );
  }
}

/// 3D投影配置
class ProjectionConfig {
  /// 视场角
  final double fov;
  /// 近平面
  final double near;
  /// 远平面
  final double far;
  /// 摄像机距离
  final double cameraDistance;
  
  const ProjectionConfig({
    this.fov = 60,
    this.near = 0.1,
    this.far = 1000,
    this.cameraDistance = 400,
  });
}

/// 3D到2D投影结果
class ProjectedPoint {
  final Offset position;
  final double depth;
  final double scale;
  final bool isVisible;
  
  const ProjectedPoint({
    required this.position,
    required this.depth,
    required this.scale,
    this.isVisible = true,
  });
}

/// 3D渲染引擎
class Vine3DEngine {
  final ProjectionConfig config;
  double rotationX = -0.3; // 俯视角度
  double rotationY = 0;    // 环绕角度
  double zoom = 1.0;
  
  // 摄像机位置
  Vector3 _cameraPosition = const Vector3(0, 0, 400);
  
  Vine3DEngine({this.config = const ProjectionConfig()});
  
  /// 更新摄像机位置
  void updateCamera() {
    final distance = config.cameraDistance / zoom;
    final radY = rotationY;
    final radX = rotationX;
    
    _cameraPosition = Vector3(
      distance * math.sin(radY) * math.cos(radX),
      distance * math.sin(radX),
      distance * math.cos(radY) * math.cos(radX),
    );
  }
  
  /// 3D点投影到2D
  ProjectedPoint project(Vector3 point, Size screenSize) {
    // 应用摄像机旋转
    var rotated = point - _cameraPosition;
    rotated = rotated.rotateY(-rotationY);
    rotated = rotated.rotateX(-rotationX);
    
    // 透视投影
    if (rotated.z <= config.near) {
      return const ProjectedPoint(
        position: Offset.zero,
        depth: 0,
        scale: 0,
        isVisible: false,
      );
    }
    
    final fovRad = config.fov * math.pi / 180;
    final focalLength = screenSize.width / (2 * math.tan(fovRad / 2));
    
    final scale = focalLength / rotated.z;
    final x2d = rotated.x * scale + screenSize.width / 2;
    final y2d = rotated.y * scale + screenSize.height / 2;
    
    return ProjectedPoint(
      position: Offset(x2d, y2d),
      depth: rotated.z,
      scale: scale.clamp(0.01, 10),
      isVisible: x2d >= -100 && x2d <= screenSize.width + 100 &&
                 y2d >= -100 && y2d <= screenSize.height + 100,
    );
  }
  
  /// 计算光照强度 (0-1)
  double calculateLighting(Vector3 position, Vector3 normal) {
    // 光源位置（固定右上角）
    const lightPos = Vector3(200, -200, 200);
    final lightDir = (lightPos - position).normalized;
    final normalizedNormal = normal.normalized;
    
    // 漫反射
    var diffuse = normalizedNormal.dot(lightDir).clamp(0.0, 1.0);
    
    // 环境光
    const ambient = 0.3;
    
    return (diffuse * 0.7 + ambient).clamp(0.0, 1.0);
  }
  
  /// 计算阴影强度
  double calculateShadow(Vector3 position) {
    // 简化阴影：越远离中心越暗
    final dist = math.sqrt(position.x * position.x + position.z * position.z);
    return (1 - (dist / 500).clamp(0.0, 0.5));
  }
  
  /// 按深度排序
  List<T> sortByDepth<T>(List<T> items, Vector3 Function(T) getPosition) {
    return List<T>.from(items)..sort((a, b) {
      final posA = getPosition(a);
      final posB = getPosition(b);
      
      // 计算到摄像机的距离
      final distA = (posA - _cameraPosition).length;
      final distB = (posB - _cameraPosition).length;
      
      // 远到近排序（ painters algorithm ）
      return distB.compareTo(distA);
    });
  }
}

/// 3D节点数据
class Node3D {
  final String id;
  final Vector3 position;
  final double size;
  final NodeType3D type;
  final Color color;
  final String? label;
  final AnimationState animation;
  
  Node3D({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    required this.color,
    this.label,
    this.animation = const AnimationState(),
  });
}

/// 节点类型
enum NodeType3D {
  message,
  branch,
  merge,
  milestone,
  consensus,
  contention,
  aiLeaf,
}

/// 动画状态
class AnimationState {
  final double growProgress;  // 0-1 生长进度
  final double hoverOffset;   // 悬浮偏移
  final double pulsePhase;    // 脉冲相位
  final bool isSelected;
  final double glowIntensity;
  
  const AnimationState({
    this.growProgress = 1.0,
    this.hoverOffset = 0,
    this.pulsePhase = 0,
    this.isSelected = false,
    this.glowIntensity = 0,
  });
  
  AnimationState copyWith({
    double? growProgress,
    double? hoverOffset,
    double? pulsePhase,
    bool? isSelected,
    double? glowIntensity,
  }) => AnimationState(
    growProgress: growProgress ?? this.growProgress,
    hoverOffset: hoverOffset ?? this.hoverOffset,
    pulsePhase: pulsePhase ?? this.pulsePhase,
    isSelected: isSelected ?? this.isSelected,
    glowIntensity: glowIntensity ?? this.glowIntensity,
  );
}

/// 粒子效果
class Particle {
  Vector3 position;
  Vector3 velocity;
  double life;  // 0-1
  double size;
  Color color;
  
  Particle({
    required this.position,
    required this.velocity,
    this.life = 1.0,
    this.size = 2.0,
    required this.color,
  });
  
  void update(double dt) {
    position = position + velocity * dt;
    life -= dt * 0.5;
    size *= 0.99;
  }
}

/// 粒子系统
class ParticleSystem {
  final List<Particle> particles = [];
  
  void emit(Vector3 position, Color color, {int count = 10}) {
    final random = math.Random();
    for (var i = 0; i < count; i++) {
      particles.add(Particle(
        position: position,
        velocity: Vector3(
          (random.nextDouble() - 0.5) * 20,
          (random.nextDouble() - 0.5) * 20,
          (random.nextDouble() - 0.5) * 20,
        ),
        color: color.withAlpha(200),
        size: random.nextDouble() * 4 + 2,
      ));
    }
  }
  
  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.life <= 0);
  }
  
  void clear() => particles.clear();
}

/// 3D连接线
class Connection3D {
  final String fromId;
  final String toId;
  final ConnectionType type;
  final double progress;  // 绘制进度 0-1
  
  Connection3D({
    required this.fromId,
    required this.toId,
    this.type = ConnectionType.temporal,
    this.progress = 1.0,
  });
}

enum ConnectionType {
  temporal,   // 时间序
  branch,     // 分支
  merge,      // 合并
  reference,  // 引用
}

/// Avatar飞行数据
class AvatarFlight {
  final String userId;
  final String userName;
  final Color color;
  Vector3 position;
  Vector3? targetPosition;
  List<Vector3> trail = [];  // 拖尾轨迹
  double trailTimer = 0;
  AvatarState state;
  double energy;
  
  AvatarFlight({
    required this.userId,
    required this.userName,
    required this.color,
    required this.position,
    this.targetPosition,
    this.state = AvatarState.idle,
    this.energy = 1.0,
  });
  
  void update(double dt) {
    // 更新拖尾
    trailTimer += dt;
    if (trailTimer > 0.1) {
      trail.add(position);
      if (trail.length > 20) trail.removeAt(0);
      trailTimer = 0;
    }
    
    // 向目标移动
    if (targetPosition != null) {
      final dir = targetPosition! - position;
      final dist = dir.length;
      if (dist > 1) {
        position = position + dir.normalized * math.min(dist, 50 * dt);
        state = AvatarState.flying;
      } else {
        state = AvatarState.idle;
        targetPosition = null;
      }
    }
  }
}

enum AvatarState {
  idle,
  flying,
  working,
}
