import 'dart:math';

/// 时空坐标点：螺旋柱坐标系
class SpaceTimePoint {
  /// Y 轴：绝对时间
  final DateTime timestamp;
  
  /// X 轴：参与者 ID（决定环绕角度）
  final String participantId;
  
  /// Z 轴：对话深度（回复层级）
  final int threadDepth;
  
  /// 3D 渲染坐标（自动计算）
  final Offset3D layoutPosition;

  const SpaceTimePoint({
    required this.timestamp,
    required this.participantId,
    this.threadDepth = 0,
    this.layoutPosition = const Offset3D.zero(),
  });

  /// 计算螺旋柱坐标（实例方法）
  SpaceTimePoint computeSpiralPosition({
    required int laneIndex,
    required int totalLanes,
    required double timeScale,
    required double radius,
  }) {
    final timeY = timestamp.millisecondsSinceEpoch * timeScale;
    
    // 计算环绕角度
    final angle = totalLanes > 0 
      ? (laneIndex / totalLanes) * 2 * pi 
      : 0.0;
    
    // 螺旋柱坐标
    final x = cos(angle) * radius;
    final z = sin(angle) * radius + (threadDepth * 10.0);
    final y = timeY;
    
    return SpaceTimePoint(
      timestamp: timestamp,
      participantId: participantId,
      threadDepth: threadDepth,
      layoutPosition: Offset3D(x: x, y: y, z: z),
    );
  }
  
  /// 计算螺旋柱坐标（静态方法）
  static SpaceTimePoint computeSpiralPositionStatic({
    required DateTime timestamp,
    required String participantId,
    required int laneIndex,
    required int totalLanes,
    required double timeScale,
    required double radius,
    int threadDepth = 0,
  }) {
    final timeY = timestamp.millisecondsSinceEpoch * timeScale;
    
    final angle = totalLanes > 0 
      ? (laneIndex / totalLanes) * 2 * pi 
      : 0.0;
    
    final x = cos(angle) * radius;
    final z = sin(angle) * radius + (threadDepth * 10.0);
    final y = timeY;
    
    return SpaceTimePoint(
      timestamp: timestamp,
      participantId: participantId,
      threadDepth: threadDepth,
      layoutPosition: Offset3D(x: x, y: y, z: z),
    );
  }

  SpaceTimePoint copyWith({
    DateTime? timestamp,
    String? participantId,
    int? threadDepth,
    Offset3D? layoutPosition,
  }) {
    return SpaceTimePoint(
      timestamp: timestamp ?? this.timestamp,
      participantId: participantId ?? this.participantId,
      threadDepth: threadDepth ?? this.threadDepth,
      layoutPosition: layoutPosition ?? this.layoutPosition,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'participantId': participantId,
    'threadDepth': threadDepth,
    'layoutPosition': layoutPosition.toJson(),
  };

  factory SpaceTimePoint.fromJson(Map<String, dynamic> json) {
    return SpaceTimePoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      participantId: json['participantId'] as String,
      threadDepth: json['threadDepth'] as int? ?? 0,
      layoutPosition: Offset3D.fromJson(json['layoutPosition'] as Map<String, dynamic>),
    );
  }
}

/// 3D 偏移量
class Offset3D {
  final double x;
  final double y;
  final double z;

  const Offset3D({
    required this.x,
    required this.y,
    required this.z,
  });

  const Offset3D.zero()
    : x = 0.0,
      y = 0.0,
      z = 0.0;

  /// 与另一个偏移量相加
  Offset3D operator +(Offset3D other) {
    return Offset3D(
      x: x + other.x,
      y: y + other.y,
      z: z + other.z,
    );
  }

  /// 与另一个偏移量相减
  Offset3D operator -(Offset3D other) {
    return Offset3D(
      x: x - other.x,
      y: y - other.y,
      z: z - other.z,
    );
  }

  /// 乘以标量
  Offset3D operator *(double scalar) {
    return Offset3D(
      x: x * scalar,
      y: y * scalar,
      z: z * scalar,
    );
  }

  /// 线性插值
  Offset3D lerp(Offset3D other, double t) {
    return Offset3D(
      x: x + (other.x - x) * t,
      y: y + (other.y - y) * t,
      z: z + (other.z - z) * t,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
  };

  factory Offset3D.fromJson(Map<String, dynamic> json) {
    return Offset3D(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Offset3D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}
