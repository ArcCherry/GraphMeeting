import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chrono_vine/space_time_axis.dart';

/// Avatar 状态
enum AvatarState { idle, flying, working, teleporting }

/// Avatar 数据模型
class AvatarData {
  final String id;
  final String name;
  final Color color;
  
  // 3D 位置
  Offset3D position;
  
  // 能量值 0.0 - 1.0（影响发光强度）
  double energy;
  
  // 状态
  AvatarState state;
  
  // 飞行轨迹（用于拖尾效果）
  List<Offset3D> trail;
  
  // 动画
  AnimationController? flyController;
  Animation<Offset3D>? flyAnimation;
  
  DateTime lastUpdate;

  AvatarData({
    required this.id,
    required this.name,
    required this.color,
    this.position = const Offset3D.zero(),
    this.energy = 1.0,
    this.state = AvatarState.idle,
    this.trail = const [],
    DateTime? lastUpdate,
    this.flyController,
    this.flyAnimation,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  bool get isIdle => state == AvatarState.idle;
  bool get isFlying => state == AvatarState.flying;
  bool get isWorking => state == AvatarState.working;
}

/// Avatar 服务
/// 
/// 纯 Flutter 实现，使用 AnimationController 处理飞行动画
class AvatarService extends ChangeNotifier {
  final Map<String, AvatarData> _avatars = {};
  Timer? _trailTimer;
  
  // 当前用户 Avatar ID
  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  // Getters
  List<AvatarData> get avatars => List.unmodifiable(_avatars.values);
  int get count => _avatars.length;

  AvatarService() {
    _init();
  }

  void _init() {
    // 启动轨迹记录（30fps）
    _trailTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _updateTrails(),
    );
  }

  /// 创建 Avatar
  AvatarData createAvatar(
    String id,
    String name,
    Color color, {
    TickerProvider? vsync,
  }) {
    final avatar = AvatarData(
      id: id,
      name: name,
      color: color,
    );

    // 如果有 vsync，创建动画控制器
    if (vsync != null) {
      avatar.flyController = AnimationController(
        vsync: vsync,
        duration: const Duration(seconds: 1),
      );
    }

    _avatars[id] = avatar;
    notifyListeners();
    return avatar;
  }

  /// 设置当前用户
  void setCurrentUser(String id) {
    _currentUserId = id;
    notifyListeners();
  }

  /// 获取 Avatar
  AvatarData? getAvatar(String id) => _avatars[id];

  /// 让 Avatar 飞行到指定位置
  Future<void> flyTo(
    String id,
    Offset3D target, {
    double duration = 1.0,
    Curve curve = Curves.easeInOutCubic,
  }) async {
    final avatar = _avatars[id];
    if (avatar == null || avatar.flyController == null) return;

    final from = avatar.position;
    
    // 设置状态为飞行中
    avatar.state = AvatarState.flying;
    notifyListeners();

    // 创建动画
    avatar.flyController!.duration = Duration(
      milliseconds: (duration * 1000).round(),
    );

    avatar.flyAnimation = Tween<Offset3D>(
      begin: from,
      end: target,
    ).animate(CurvedAnimation(
      parent: avatar.flyController!,
      curve: curve,
    ));

    // 监听动画更新位置
    void onAnimationUpdate() {
      final value = avatar.flyAnimation?.value;
      if (value != null) {
        avatar.position = value;
        notifyListeners();
      }
    }

    avatar.flyController!.addListener(onAnimationUpdate);

    // 动画完成监听
    final completer = Completer<void>();
    void onStatusChange(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        avatar.flyController!.removeListener(onAnimationUpdate);
        avatar.flyController!.removeStatusListener(onStatusChange);
        avatar.state = AvatarState.idle;
        notifyListeners();
        completer.complete();
      }
    }
    
    avatar.flyController!.addStatusListener(onStatusChange);
    avatar.flyController!.forward(from: 0);

    return completer.future;
  }

  /// 让 Avatar 飞向某个节点（放置想法）
  Future<void> flyToNode(String id, Offset3D nodePosition) async {
    // 先飞到节点位置
    await flyTo(id, nodePosition, duration: 0.5);

    // 模拟工作状态
    final avatar = _avatars[id];
    if (avatar != null) {
      avatar.state = AvatarState.working;
      notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 1));

    // 飞回观察位置
    final homePosition = _getHomePosition(id);
    await flyTo(id, homePosition, duration: 0.8);
  }

  /// 获取 Avatar 的"家"位置（环绕轨道的固定位置）
  Offset3D _getHomePosition(String id) {
    final index = _avatars.keys.toList().indexOf(id);
    final total = _avatars.length;
    if (total == 0) return const Offset3D.zero();

    // 围绕中心圆环分布
    final angle = (index / total) * 2 * math.pi;
    const radius = 80.0;

    return Offset3D(
      x: math.cos(angle) * radius,
      y: 0, // Y 轴高度为 0（中心层）
      z: math.sin(angle) * radius,
    );
  }

  /// 更新所有 Avatar 的轨迹
  void _updateTrails() {
    if (_avatars.isEmpty) return;

    for (final avatar in _avatars.values) {
      if (avatar.isFlying) {
        // 添加当前位置到轨迹
        avatar.trail = [...avatar.trail, avatar.position];
        if (avatar.trail.length > 50) {
          avatar.trail = avatar.trail.sublist(avatar.trail.length - 50);
        }
      } else if (avatar.trail.isNotEmpty) {
        // 非飞行状态，轨迹逐渐消失
        avatar.trail = [];
      }
    }

    notifyListeners();
  }

  /// 布置所有 Avatar 到环绕轨道的初始位置
  void arrangeAvatarsInCircle() {
    final ids = _avatars.keys.toList();
    final total = ids.length;

    for (int i = 0; i < total; i++) {
      final id = ids[i];
      final angle = (i / total) * 2 * math.pi;
      const radius = 80.0;

      final target = Offset3D(
        x: math.cos(angle) * radius,
        y: 0,
        z: math.sin(angle) * radius,
      );

      // 直接设置位置（无动画）
      final avatar = _avatars[id];
      if (avatar != null) {
        avatar.position = target;
      }
    }

    notifyListeners();
  }

  /// 清除所有 Avatar
  void clear() {
    for (final avatar in _avatars.values) {
      avatar.flyController?.dispose();
    }
    _avatars.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _trailTimer?.cancel();
    clear();
    super.dispose();
  }
}
