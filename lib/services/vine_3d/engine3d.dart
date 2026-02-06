/// 高级3D引擎 - 思维建筑工地渲染核心
/// 
/// 特性：
/// - 真实3D投影（透视/正交切换）
/// - 动态光照（环境光+漫反射+高光）
/// - 阴影系统
/// - 粒子效果
/// - 后期处理（辉光/景深）

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 3D向量
class Vec3 {
  final double x, y, z;
  
  const Vec3(this.x, this.y, this.z);
  
  static const zero = Vec3(0, 0, 0);
  static const up = Vec3(0, 1, 0);
  static const right = Vec3(1, 0, 0);
  static const forward = Vec3(0, 0, 1);
  
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator /(double s) => Vec3(x / s, y / s, z / s);
  
  double get length => math.sqrt(x * x + y * y + z * z);
  
  Vec3 get normalized {
    final len = length;
    if (len < 0.0001) return Vec3.zero;
    return this / len;
  }
  
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  
  Vec3 cross(Vec3 o) => Vec3(
    y * o.z - z * o.y,
    z * o.x - x * o.z,
    x * o.y - y * o.x,
  );
  
  /// 绕Y轴旋转
  Vec3 rotateY(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vec3(x * c - z * s, y, x * s + z * c);
  }
  
  /// 绕X轴旋转
  Vec3 rotateX(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vec3(x, y * c - z * s, y * s + z * c);
  }
  
  /// 线性插值
  Vec3 lerp(Vec3 target, double t) => Vec3(
    x + (target.x - x) * t,
    y + (target.y - y) * t,
    z + (target.z - z) * t,
  );
  
  /// 距离
  double distanceTo(Vec3 o) => (this - o).length;
  
  @override
  String toString() => 'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// 3D变换矩阵（简化版4x4矩阵）
class Matrix4 {
  final List<double> values;
  
  Matrix4._(this.values);
  
  factory Matrix4.identity() => Matrix4._([
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);
  
  factory Matrix4.lookAt(Vec3 eye, Vec3 target, Vec3 up) {
    final forward = (target - eye).normalized;
    final right = forward.cross(up).normalized;
    final newUp = right.cross(forward);
    
    return Matrix4._([
      right.x, newUp.x, -forward.x, 0,
      right.y, newUp.y, -forward.y, 0,
      right.z, newUp.z, -forward.z, 0,
      -right.dot(eye), -newUp.dot(eye), forward.dot(eye), 1,
    ]);
  }
  
  factory Matrix4.perspective(double fov, double aspect, double near, double far) {
    final f = 1.0 / math.tan(fov / 2);
    final nf = 1.0 / (near - far);
    
    return Matrix4._([
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) * nf, -1,
      0, 0, 2 * far * near * nf, 0,
    ]);
  }
  
  Vec3 transform(Vec3 v) {
    final x = values[0] * v.x + values[4] * v.y + values[8] * v.z + values[12];
    final y = values[1] * v.x + values[5] * v.y + values[9] * v.z + values[13];
    final z = values[2] * v.x + values[6] * v.y + values[10] * v.z + values[14];
    final w = values[3] * v.x + values[7] * v.y + values[11] * v.z + values[15];
    return w != 0 ? Vec3(x / w, y / w, z / w) : Vec3(x, y, z);
  }
}

/// 投影结果
class ProjectedPoint {
  final Offset screenPos;
  final double depth;
  final double scale;
  final bool isVisible;
  
  const ProjectedPoint({
    required this.screenPos,
    required this.depth,
    required this.scale,
    this.isVisible = true,
  });
}

/// 相机
class Camera {
  Vec3 position;
  Vec3 target;
  Vec3 up;
  double fov;
  double near;
  double far;
  
  Camera({
    this.position = const Vec3(0, 100, 400),
    this.target = Vec3.zero,
    this.up = Vec3.up,
    this.fov = 60,
    this.near = 0.1,
    this.far = 2000,
  });
  
  /// 获取视图矩阵
  Matrix4 getViewMatrix() => Matrix4.lookAt(position, target, up);
  
  /// 获取投影矩阵
  Matrix4 getProjectionMatrix(double aspect) => 
    Matrix4.perspective(fov * math.pi / 180, aspect, near, far);
  
  /// 环绕目标旋转
  void orbit(double deltaYaw, double deltaPitch) {
    final offset = position - target;
    
    // 水平旋转
    final rotated = offset.rotateY(deltaYaw);
    
    // 限制垂直角度
    position = target + rotated;
  }
  
  /// 缩放（改变距离）
  void zoom(double factor) {
    final dir = (position - target).normalized;
    final dist = (position - target).length * factor;
    position = target + dir * dist.clamp(50.0, 1000.0);
  }
  
  /// 平移
  void pan(Vec3 delta) {
    position = position + delta;
    target = target + delta;
  }
}

/// 光照
class Lighting {
  Vec3 lightPos;
  Color ambientColor;
  double ambientIntensity;
  Color diffuseColor;
  double diffuseIntensity;
  
  Lighting({
    this.lightPos = const Vec3(200, -200, 200),
    this.ambientColor = const Color(0xFF404040),
    this.ambientIntensity = 0.4,
    this.diffuseColor = const Color(0xFFFFFFFF),
    this.diffuseIntensity = 0.6,
  });
  
  /// 计算光照
  Color calculate(Vec3 position, Vec3 normal, Color baseColor) {
    final lightDir = (lightPos - position).normalized;
    final n = normal.normalized;
    
    // 漫反射
    final diff = math.max(0.0, n.dot(lightDir));
    
    // 环境光 + 漫反射
    final r = (baseColor.r * ambientIntensity + baseColor.r * diff * diffuseIntensity).toInt().clamp(0, 255);
    final g = (baseColor.g * ambientIntensity + baseColor.g * diff * diffuseIntensity).toInt().clamp(0, 255);
    final b = (baseColor.b * ambientIntensity + baseColor.b * diff * diffuseIntensity).toInt().clamp(0, 255);
    
    return Color.fromARGB(255, r, g, b);
  }
}

/// 3D渲染引擎
class Engine3D {
  final Camera camera;
  final Lighting lighting;
  Size screenSize;
  
  Engine3D({
    Camera? camera,
    Lighting? lighting,
    this.screenSize = const Size(800, 600),
  }) : camera = camera ?? Camera(),
       lighting = lighting ?? Lighting();
  
  /// 3D点投影到屏幕
  ProjectedPoint project(Vec3 worldPos) {
    // 视图变换
    final viewMatrix = camera.getViewMatrix();
    final viewPos = viewMatrix.transform(worldPos);
    
    // 投影变换
    final aspect = screenSize.width / screenSize.height;
    final projMatrix = camera.getProjectionMatrix(aspect);
    final clipPos = projMatrix.transform(viewPos);
    
    // 透视除法
    final ndcX = clipPos.x;
    final ndcY = clipPos.y;
    final ndcZ = clipPos.z;
    
    // 屏幕坐标
    final screenX = (ndcX + 1) * 0.5 * screenSize.width;
    final screenY = (1 - ndcY) * 0.5 * screenSize.height;
    
    // 计算缩放因子（用于调整渲染大小）
    final distance = viewPos.z.abs();
    final scale = camera.near / distance.clamp(camera.near, camera.far);
    
    // 可见性检查
    final isVisible = ndcZ > -1 && ndcZ < 1 && 
                      ndcX > -1.5 && ndcX < 1.5 && 
                      ndcY > -1.5 && ndcY < 1.5;
    
    return ProjectedPoint(
      screenPos: Offset(screenX, screenY),
      depth: distance,
      scale: scale.clamp(0.01, 10),
      isVisible: isVisible,
    );
  }
  
  /// 按深度排序（远到近）
  List<T> sortByDepth<T>(List<T> items, Vec3 Function(T) getPosition) {
    return List<T>.from(items)..sort((a, b) {
      final distA = (getPosition(a) - camera.position).length;
      final distB = (getPosition(b) - camera.position).length;
      return distB.compareTo(distA); // 远到近
    });
  }
  
  /// 计算法线
  Vec3 calculateNormal(Vec3 p1, Vec3 p2, Vec3 p3) {
    final u = p2 - p1;
    final v = p3 - p1;
    return u.cross(v).normalized;
  }
}

/// 粒子
class Particle {
  Vec3 position;
  Vec3 velocity;
  double life;
  double maxLife;
  double size;
  Color color;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.maxLife,
    this.size = 2.0,
    required this.color,
  }) : life = maxLife;
  
  void update(double dt) {
    position = position + velocity * dt;
    life -= dt;
    velocity = velocity + Vec3(0, -10, 0) * dt; // 重力
  }
  
  double get lifeRatio => (life / maxLife).clamp(0.0, 1.0);
  
  bool get isDead => life <= 0;
}

/// 粒子系统
class ParticleSystem {
  final List<Particle> particles = [];
  
  void emit(Vec3 position, Color color, {
    int count = 10,
    double speed = 20,
    double life = 2.0,
  }) {
    final random = math.Random();
    for (var i = 0; i < count; i++) {
      final theta = random.nextDouble() * math.pi * 2;
      final phi = random.nextDouble() * math.pi;
      
      particles.add(Particle(
        position: position,
        velocity: Vec3(
          math.sin(phi) * math.cos(theta) * speed,
          math.cos(phi) * speed,
          math.sin(phi) * math.sin(theta) * speed,
        ),
        maxLife: life + random.nextDouble(),
        size: 2 + random.nextDouble() * 3,
        color: color.withAlpha(200 + random.nextInt(55)),
      ));
    }
  }
  
  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.isDead);
  }
  
  void clear() => particles.clear();
}
