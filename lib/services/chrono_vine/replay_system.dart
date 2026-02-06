/// 回放系统 - 延时摄影大片
/// 
/// 支持：
/// - 时间轴回放
/// - 多种相机模式
/// - 建筑生长动画
/// - 视频导出

import 'dart:math' as math;

import '../../models/chrono_vine/chrono_vine_data.dart';
import 'vine_layout_engine.dart';

/// 回放模式
enum ReplayMode {
  /// 第一人称跟随
  firstPerson,
  /// 上帝视角
  godView,
  /// 电影模式（自动机位）
  cinematic,
  /// 幽灵模式（显示所有轨迹）
  ghost,
}

/// 回放控制器
class ReplayController {
  ReplayMode mode;
  double speed;  // 0.1x - 100x
  DateTime? startTime;
  DateTime? endTime;
  DateTime currentTime;
  bool isPlaying;
  
  // 相机状态
  CameraPose currentCamera;
  
  ReplayController({
    this.mode = ReplayMode.cinematic,
    this.speed = 1.0,
    this.startTime,
    this.endTime,
    DateTime? currentTime,
    this.isPlaying = false,
    CameraPose? initialCamera,
  }) : currentTime = currentTime ?? DateTime.now(),
       currentCamera = initialCamera ?? CameraPose.defaultCamera();
  
  /// 更新回放
  void update(double deltaTime, VineLayoutEngine engine) {
    if (!isPlaying) return;
    
    // 推进时间
    final timeDelta = Duration(
      milliseconds: (deltaTime * 1000 * speed).toInt()
    );
    currentTime = currentTime.add(timeDelta);
    
    // 检查是否结束
    if (endTime != null && currentTime.isAfter(endTime!)) {
      currentTime = endTime!;
      isPlaying = false;
    }
    
    // 更新相机
    _updateCamera(engine);
  }
  
  /// 更新相机
  void _updateCamera(VineLayoutEngine engine) {
    switch (mode) {
      case ReplayMode.godView:
        _updateGodViewCamera(engine);
        break;
      case ReplayMode.cinematic:
        _updateCinematicCamera(engine);
        break;
      case ReplayMode.firstPerson:
        _updateFirstPersonCamera(engine);
        break;
      case ReplayMode.ghost:
        _updateGhostCamera(engine);
        break;
    }
  }
  
  /// 上帝视角相机
  void _updateGodViewCamera(VineLayoutEngine engine) {
    final range = engine.getTimeRange();
    if (range == null) return;
    
    // 根据当前时间计算高度
    final progress = currentTime.difference(range.start).inMilliseconds / 
                     range.duration.inMilliseconds;
    
    // 环绕运动
    final angle = progress * math.pi * 2;
    final radius = 400.0;
    final height = progress * 500 - 100;
    
    currentCamera = CameraPose(
      position: Vector3D(
        math.cos(angle) * radius,
        height,
        math.sin(angle) * radius,
      ),
      lookAt: Vector3D(0, height, 0),
      fov: 60,
    );
  }
  
  /// 电影模式相机
  void _updateCinematicCamera(VineLayoutEngine engine) {
    final snapshot = engine.getWorldSnapshotAt(currentTime);
    
    // 找到当前最活跃的区域
    final hotspot = _findActivityHotspot(snapshot);
    
    if (hotspot != null) {
      // 平滑移动到热点
      final targetPos = hotspot.center + Vector3D(
        math.sin(currentTime.millisecondsSinceEpoch / 5000) * 50,
        80,
        math.cos(currentTime.millisecondsSinceEpoch / 5000) * 50,
      );
      
      currentCamera.position = currentCamera.position.lerp(targetPos, 0.02);
      currentCamera.lookAt = currentCamera.lookAt.lerp(hotspot.center, 0.05);
    }
  }
  
  /// 第一人称相机
  void _updateFirstPersonCamera(VineLayoutEngine engine) {
    // TODO: 跟随特定Avatar
  }
  
  /// 幽灵模式相机
  void _updateGhostCamera(VineLayoutEngine engine) {
    // 显示所有历史轨迹
    _updateGodViewCamera(engine);
  }
  
  /// 查找活动热点
  HotspotInfo? _findActivityHotspot(WorldSnapshot snapshot) {
    if (snapshot.nodes.isEmpty) return null;
    
    // 计算节点密度最高的区域
    final recentNodes = snapshot.nodes.where((n) {
      final diff = currentTime.difference(n.createdAt);
      return diff < const Duration(minutes: 5);
    }).toList();
    
    if (recentNodes.isEmpty) {
      // 返回最新节点的位置
      final latest = snapshot.nodes.reduce((a, b) => 
        a.createdAt.isAfter(b.createdAt) ? a : b
      );
      return HotspotInfo(
        center: latest.position.layoutPosition,
        intensity: 0.5,
      );
    }
    
    // 计算平均位置
    var sumX = 0.0, sumY = 0.0, sumZ = 0.0;
    for (final node in recentNodes) {
      sumX += node.position.layoutPosition.x;
      sumY += node.position.layoutPosition.y;
      sumZ += node.position.layoutPosition.z;
    }
    
    return HotspotInfo(
      center: Vector3D(
        sumX / recentNodes.length,
        sumY / recentNodes.length,
        sumZ / recentNodes.length,
      ),
      intensity: recentNodes.length / 5.0,
    );
  }
  
  /// 播放
  void play() => isPlaying = true;
  
  /// 暂停
  void pause() => isPlaying = false;
  
  /// 跳转到指定时间
  void seekTo(DateTime time) {
    currentTime = time;
  }
  
  /// 设置速度
  void setSpeed(double newSpeed) {
    speed = newSpeed.clamp(0.1, 100.0);
  }
  
  /// 生成相机路径关键帧
  List<CameraKeyFrame> generateCameraPath(VineLayoutEngine engine) {
    final frames = <CameraKeyFrame>[];
    final range = engine.getTimeRange();
    if (range == null) return frames;
    
    // 起始帧：虚空俯瞰
    frames.add(CameraKeyFrame(
      time: 0,
      pose: CameraPose(
        position: Vector3D(0, 300, 0),
        lookAt: Vector3D.zero,
        fov: 90,
      ),
    ));
    
    // 根据事件添加关键帧
    // TODO: 基于实际节点位置生成
    
    // 结束帧：环绕建筑
    frames.add(CameraKeyFrame(
      time: range.duration.inSeconds.toDouble(),
      pose: CameraPose(
        position: Vector3D(200, 100, 200),
        lookAt: Vector3D(0, 100, 0),
        fov: 70,
      ),
    ));
    
    return frames;
  }
}

/// 相机姿态
class CameraPose {
  Vector3D position;
  Vector3D lookAt;
  double fov;
  
  CameraPose({
    required this.position,
    required this.lookAt,
    this.fov = 60,
  });
  
  factory CameraPose.defaultCamera() => CameraPose(
    position: Vector3D(0, 200, 400),
    lookAt: Vector3D.zero,
  );
  
  /// 获取观察方向
  Vector3D get direction => (lookAt - position).normalized;
}

/// 相机动画关键帧
class CameraKeyFrame {
  final double time;  // 秒
  final CameraPose pose;
  
  CameraKeyFrame({required this.time, required this.pose});
}

/// 热点信息
class HotspotInfo {
  final Vector3D center;
  final double intensity;
  
  HotspotInfo({required this.center, required this.intensity});
}

/// 回放导出器
class ReplayExporter {
  /// 导出为视频
  Future<void> exportVideo({
    required ReplayController controller,
    required VineLayoutEngine engine,
    required Duration duration,
    required String outputPath,
  }) async {
    // TODO: 使用FFMpeg或平台API导出视频
  }
  
  /// 生成交互式HTML
  Future<String> generateInteractiveHtml({
    required VineLayoutEngine engine,
  }) async {
    // TODO: 导出为Three.js可加载的格式
    return '';
  }
  
  /// 生成蓝图风格截图
  Future<void> exportBlueprint({
    required VineLayoutEngine engine,
    required DateTime timestamp,
    required String outputPath,
  }) async {
    // TODO: 线框渲染输出
  }
}

/// 时间轴标记
class TimelineMarker {
  final DateTime timestamp;
  final MarkerType type;
  final String label;
  final String? nodeId;
  
  TimelineMarker({
    required this.timestamp,
    required this.type,
    required this.label,
    this.nodeId,
  });
}

enum MarkerType {
  start,      // 会议开始
  milestone,  // 里程碑
  contention, // 争议
  resolution, // 解决
  end,        // 会议结束
}

/// 时间轴控制器
class TimelineController {
  final List<TimelineMarker> markers = [];
  
  void addMarker(TimelineMarker marker) => markers.add(marker);
  
  void clear() => markers.clear();
  
  /// 获取某时间附近的标记
  List<TimelineMarker> getMarkersNear(DateTime time, {Duration window = const Duration(seconds: 30)}) {
    return markers.where((m) {
      final diff = m.timestamp.difference(time).abs();
      return diff < window;
    }).toList();
  }
}
