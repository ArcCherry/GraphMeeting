import 'dart:math';
import 'package:flutter/material.dart';
import '../models/chrono_vine/space_time_axis.dart';

/// 视角模式
enum ViewMode {
  free, // 自由探索
  follow, // 自动跟随最新消息
  replay, // 延时摄影回放
}

/// 3D 视角状态
class Viewport3D extends ChangeNotifier {
  /// 环绕时间轴旋转（Y轴旋转，看到不同参与者）
  double _rotationY;

  /// 俯视角度（X轴旋转，鸟瞰 vs 平视）
  double _rotationX;

  /// 缩放（全局概览 vs 细节）
  double _zoom;

  /// 当前聚焦时间点
  DateTime _focusTime;

  /// 视角模式
  ViewMode _mode;

  /// 透视投影参数
  final double fov; // 视场角
  final double near; // 近裁剪面
  final double far; // 远裁剪面

  Viewport3D({
    double rotationY = 0,
    double rotationX = -30, // 默认俯视30度
    double zoom = 1.0,
    DateTime? focusTime,
    ViewMode mode = ViewMode.free,
    this.fov = 60,
    this.near = 0.1,
    this.far = 1000,
  })  : _rotationY = rotationY,
        _rotationX = rotationX,
        _zoom = zoom,
        _focusTime = focusTime ?? DateTime.now(),
        _mode = mode;

  // Getters
  double get rotationY => _rotationY;
  double get rotationX => _rotationX;
  double get zoom => _zoom;
  DateTime get focusTime => _focusTime;
  ViewMode get mode => _mode;

  /// 水平旋转（环绕时间轴）
  void rotate(double deltaY) {
    _rotationY = (_rotationY + deltaY) % 360;
    notifyListeners();
  }

  /// 垂直旋转（俯仰角）
  void tilt(double deltaX) {
    _rotationX = _clamp(_rotationX + deltaX, -89, 89);
    notifyListeners();
  }

  /// 缩放
  void zoomBy(double factor) {
    _zoom = _clamp(_zoom * factor, 0.1, 5.0);
    notifyListeners();
  }

  /// 设置缩放
  void setZoom(double value) {
    _zoom = _clamp(value, 0.1, 5.0);
    notifyListeners();
  }
  
  /// 放大
  void zoomIn() {
    zoomBy(1.2);
  }
  
  /// 缩小
  void zoomOut() {
    zoomBy(0.8);
  }

  /// 聚焦到指定时间
  void focusTo(DateTime time) {
    _focusTime = time;
    notifyListeners();
  }

  /// 切换视角模式
  void setMode(ViewMode mode) {
    _mode = mode;
    notifyListeners();
  }

  /// 3D 投影：将世界坐标转换为屏幕坐标
  ///
  /// [size] 画布大小
  /// [worldPos] 世界坐标
  /// 返回屏幕坐标 (x, y) 和深度值 z（用于排序）
  ProjectedPoint project(Size size, Offset3D worldPos) {
    // 应用缩放
    final scaled = worldPos * _zoom;

    // 应用 Y 轴旋转（环绕）
    final radY = _degToRad(_rotationY);
    final cosY = cos(radY);
    final sinY = sin(radY);
    final rotY = Offset3D(
      x: scaled.x * cosY - scaled.z * sinY,
      y: scaled.y,
      z: scaled.x * sinY + scaled.z * cosY,
    );

    // 应用 X 轴旋转（俯仰）
    final radX = _degToRad(_rotationX);
    final cosX = cos(radX);
    final sinX = sin(radX);
    final rotX = Offset3D(
      x: rotY.x,
      y: rotY.y * cosX - rotY.z * sinX,
      z: rotY.y * sinX + rotY.z * cosX,
    );

    // 透视投影
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 简单的透视投影
    final distance = 500.0; // 观察距离
    final scale = distance / (distance + rotX.z);

    final screenX = centerX + rotX.x * scale;
    final screenY = centerY + rotX.y * scale;

    return ProjectedPoint(
      offset: Offset(screenX, screenY),
      depth: rotX.z,
      scale: scale,
    );
  }

  /// 重置视角
  void reset() {
    _rotationY = 0;
    _rotationX = -30;
    _zoom = 1.0;
    _mode = ViewMode.free;
    notifyListeners();
  }

  Viewport3D copyWith({
    double? rotationY,
    double? rotationX,
    double? zoom,
    DateTime? focusTime,
    ViewMode? mode,
  }) {
    return Viewport3D(
      rotationY: rotationY ?? _rotationY,
      rotationX: rotationX ?? _rotationX,
      zoom: zoom ?? _zoom,
      focusTime: focusTime ?? _focusTime,
      mode: mode ?? _mode,
    );
  }

  static double _degToRad(double deg) => deg * pi / 180.0;
  
  static T _clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// 投影后的点
class ProjectedPoint {
  final Offset offset;
  final double depth;
  final double scale;

  const ProjectedPoint({
    required this.offset,
    required this.depth,
    required this.scale,
  });

  double get x => offset.dx;
  double get y => offset.dy;
}
