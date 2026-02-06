/// 高级3D藤蔓画布
/// 
/// 全新设计的3D渲染系统，提供：
/// - 真实3D投影和透视
/// - 动态光照和阴影
/// - 粒子效果系统
/// - Avatar飞行系统
/// - 丰富的手势交互

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../services/vine_3d/vine_3d_engine.dart';
import 'painters/advanced_vine_painter.dart';

export '../../../services/vine_3d/vine_3d_engine.dart';

/// 高级藤蔓画布
class VineCanvas extends StatefulWidget {
  final Function(String nodeId)? onNodeTap;
  final Function(String nodeId)? onNodeLongPress;
  final Function(Offset position)? onCanvasTap;
  
  const VineCanvas({
    super.key,
    this.onNodeTap,
    this.onNodeLongPress,
    this.onCanvasTap,
  });

  @override
  State<VineCanvas> createState() => VineCanvasState();
}

class VineCanvasState extends State<VineCanvas>
    with TickerProviderStateMixin {
  late Vine3DEngine _engine;
  late AnimationController _animationController;
  late AnimationController _orbitController;
  
  // 场景数据
  final List<Node3D> _nodes = [];
  final List<Connection3D> _connections = [];
  final List<AvatarFlight> _avatars = [];
  final ParticleSystem _particles = ParticleSystem();
  
  // 交互状态
  String? _selectedNodeId;
  String? _hoveredNodeId;
  bool _isDragging = false;
  bool _isRotating = false;
  Offset _lastPanPosition = Offset.zero;
  
  // 视角控制
  double _targetRotationY = 0;
  double _targetRotationX = -0.3;
  double _targetZoom = 1.0;
  
  // 时间轴
  double _timeAxisProgress = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeEngine();
    _initializeAnimation();
    _loadSceneData();
  }
  
  void _initializeEngine() {
    _engine = Vine3DEngine(
      config: const ProjectionConfig(
        fov: 60,
        cameraDistance: 500,
      ),
    );
    _engine.rotationX = _targetRotationX;
    _engine.rotationY = _targetRotationY;
    _engine.zoom = _targetZoom;
  }
  
  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    _animationController.addListener(_onAnimationUpdate);
    
    // 轨道动画控制器
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
  }
  
  void _onAnimationUpdate() {
    final dt = 0.016; // 假设60fps
    
    // 平滑插值到目标值
    _engine.rotationY += (_targetRotationY - _engine.rotationY) * 0.1;
    _engine.rotationX += (_targetRotationX - _engine.rotationX) * 0.1;
    _engine.zoom += (_targetZoom - _engine.zoom) * 0.1;
    
    // 更新粒子
    _particles.update(dt);
    
    // 更新Avatar
    for (final avatar in _avatars) {
      avatar.update(dt);
    }
    
    // 更新时间轴进度
    if (_timeAxisProgress < 1.0) {
      _timeAxisProgress = (_timeAxisProgress + dt * 0.2).clamp(0.0, 1.0);
    }
    
    // 节点动画
    _updateNodeAnimations(dt);
    
    setState(() {});
  }
  
  void _updateNodeAnimations(double dt) {
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      var newAnimation = node.animation;
      
      // 生长动画
      if (node.animation.growProgress < 1.0) {
        newAnimation = newAnimation.copyWith(
          growProgress: (node.animation.growProgress + dt * 2).clamp(0.0, 1.0),
        );
      }
      
      // 悬浮动画
      newAnimation = newAnimation.copyWith(
        hoverOffset: math.sin(_animationController.value * math.pi * 2 + i) * 3,
        pulsePhase: node.animation.pulsePhase + dt,
      );
      
      _nodes[i] = Node3D(
        id: node.id,
        position: node.position,
        size: node.size,
        type: node.type,
        color: node.color,
        label: node.label,
        animation: newAnimation,
      );
    }
  }
  
  void _loadSceneData() {
    // 生成示例场景数据
    final random = math.Random(42);
    final colors = [
      AppTheme.accentPrimary,
      AppTheme.success,
      AppTheme.warning,
      const Color(0xFF744DA9),
    ];
    
    // 生成节点
    for (int i = 0; i < 15; i++) {
      final t = i / 15;
      final angle = t * math.pi * 4;
      final radius = 150 + math.sin(t * math.pi * 2) * 50;
      
      final node = Node3D(
        id: 'node_$i',
        position: Vector3(
          math.cos(angle) * radius,
          -t * 600 + 300,
          math.sin(angle) * radius * 0.5,
        ),
        size: 15 + random.nextDouble() * 10,
        type: NodeType3D.values[random.nextInt(NodeType3D.values.length)],
        color: colors[random.nextInt(colors.length)],
        label: i % 3 == 0 ? 'Node $i' : null,
        animation: AnimationState(
          growProgress: 0.0,
          pulsePhase: random.nextDouble() * math.pi * 2,
        ),
      );
      
      _nodes.add(node);
    }
    
    // 生成连接
    for (int i = 0; i < _nodes.length - 1; i++) {
      if (random.nextDouble() > 0.3) {
        _connections.add(Connection3D(
          fromId: _nodes[i].id,
          toId: _nodes[i + 1].id,
          type: ConnectionType.temporal,
        ));
      }
      
      // 添加一些分支
      if (random.nextDouble() > 0.7 && i < _nodes.length - 2) {
        _connections.add(Connection3D(
          fromId: _nodes[i].id,
          toId: _nodes[i + 2].id,
          type: ConnectionType.branch,
        ));
      }
    }
    
    // 生成Avatar
    _avatars.addAll([
      AvatarFlight(
        userId: 'user1',
        userName: 'Alice',
        color: AppTheme.accentPrimary,
        position: Vector3(-200, 0, 0),
      ),
      AvatarFlight(
        userId: 'user2',
        userName: 'Bob',
        color: AppTheme.success,
        position: Vector3(200, -100, 50),
      ),
      AvatarFlight(
        userId: 'user3',
        userName: 'Carol',
        color: AppTheme.warning,
        position: Vector3(0, -200, -50),
      ),
    ]);
    
    // 延迟触发粒子效果
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _emitRandomParticles();
      } else {
        timer.cancel();
      }
    });
  }
  
  void _emitRandomParticles() {
    if (_nodes.isEmpty) return;
    final random = math.Random();
    final node = _nodes[random.nextInt(_nodes.length)];
    
    if (node.type == NodeType3D.consensus || node.type == NodeType3D.contention) {
      _particles.emit(
        node.position,
        node.color,
        count: random.nextInt(10) + 5,
      );
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTapUp: _onTapUp,
        onLongPressStart: _onLongPressStart,
        child: Container(
          color: AppTheme.darkBackgroundBase,
          child: CustomPaint(
            size: Size.infinite,
            painter: AdvancedVinePainter(
              engine: _engine,
              nodes: _nodes,
              connections: _connections,
              avatars: _avatars,
              particles: _particles,
              animationValue: _animationController.value,
              selectedNodeId: _selectedNodeId,
              timeAxisProgress: _timeAxisProgress,
            ),
          ),
        ),
      ),
    );
  }
  
  // ===== 手势处理 =====
  
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        final delta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        _targetZoom = (_targetZoom * delta).clamp(0.3, 5.0);
      });
    }
  }
  
  void _onScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.focalPoint;
    _isDragging = false;
    _isRotating = false;
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      // 缩放
      _targetZoom = (_targetZoom * details.scale).clamp(0.3, 5.0);
    }
    
    // 旋转
    final delta = details.focalPoint - _lastPanPosition;
    _targetRotationY += delta.dx * 0.005;
    _targetRotationX += delta.dy * 0.005;
    _targetRotationX = _targetRotationX.clamp(-1.0, 1.0);
    
    _lastPanPosition = details.focalPoint;
    
    // 检测点击节点
    _checkNodeHover(details.focalPoint);
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    _hoveredNodeId = null;
  }
  
  void _onTapUp(TapUpDetails details) {
    final hitNodeId = _hitTestNode(details.localPosition);
    
    if (hitNodeId != null) {
      setState(() {
        _selectedNodeId = hitNodeId;
      });
      widget.onNodeTap?.call(hitNodeId);
      
      // 发射粒子
      final node = _nodes.firstWhere((n) => n.id == hitNodeId);
      _particles.emit(node.position, node.color, count: 20);
    } else {
      setState(() {
        _selectedNodeId = null;
      });
      widget.onCanvasTap?.call(details.localPosition);
    }
  }
  
  void _onLongPressStart(LongPressStartDetails details) {
    final hitNodeId = _hitTestNode(details.localPosition);
    if (hitNodeId != null) {
      HapticFeedback.mediumImpact();
      widget.onNodeLongPress?.call(hitNodeId);
    }
  }
  
  // ===== 命中测试 =====
  
  String? _hitTestNode(Offset position) {
    final size = MediaQuery.of(context).size;
    
    for (final node in _nodes.reversed) {
      final projected = _engine.project(node.position, size);
      if (!projected.isVisible) continue;
      
      final distance = (position - projected.position).distance;
      if (distance < node.size * projected.scale + 10) {
        return node.id;
      }
    }
    
    return null;
  }
  
  void _checkNodeHover(Offset position) {
    final hitNodeId = _hitTestNode(position);
    if (hitNodeId != _hoveredNodeId) {
      setState(() {
        _hoveredNodeId = hitNodeId;
      });
      
      if (hitNodeId != null) {
        HapticFeedback.lightImpact();
      }
    }
  }
  
  // ===== 公共方法 =====
  
  /// 聚焦到指定节点
  void focusOnNode(String nodeId) {
    final node = _nodes.firstWhere((n) => n.id == nodeId);
    
    // 计算需要的旋转角度
    _targetRotationY = -math.atan2(node.position.x, node.position.z);
    _targetRotationX = 0;
    
    setState(() {
      _selectedNodeId = nodeId;
    });
  }
  
  /// 添加新节点
  void addNode(Node3D node) {
    setState(() {
      _nodes.add(node);
    });
  }
  
  /// 移动Avatar到位置
  void moveAvatar(String userId, Vector3 targetPosition) {
    final avatar = _avatars.firstWhere((a) => a.userId == userId);
    avatar.targetPosition = targetPosition;
  }
  
  /// 发射粒子
  void emitParticles(Vector3 position, Color color, {int count = 10}) {
    _particles.emit(position, color, count: count);
  }
  
  /// 重置视角
  void resetView() {
    setState(() {
      _targetRotationY = 0;
      _targetRotationX = -0.3;
      _targetZoom = 1.0;
    });
  }
}

/// 视角控制按钮组
class ViewportControls extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  
  const ViewportControls({
    super.key,
    required this.onReset,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.add, onZoomIn, '放大'),
          const SizedBox(height: 4),
          _buildButton(Icons.remove, onZoomOut, '缩小'),
          const Divider(height: 16, color: AppTheme.darkBorderPrimary),
          _buildButton(Icons.rotate_left, onRotateLeft, '左转'),
          const SizedBox(height: 4),
          _buildButton(Icons.rotate_right, onRotateRight, '右转'),
          const Divider(height: 16, color: AppTheme.darkBorderPrimary),
          _buildButton(Icons.center_focus_strong, onReset, '重置'),
        ],
      ),
    );
  }
  
  Widget _buildButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: AppTheme.darkTextPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
