/// Mind Construction Site - 思维建筑工地可视化
/// 
/// 核心理念：
/// - 中央时间轴像铁路主线一样延伸
/// - 参与者在各自的螺旋轨道上飞行
/// - 节点像建筑方块一样被放置
/// - AI叶子像果实一样层叠在关键节点上
/// - 回放时看到认知宫殿拔地而起

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/chrono_vine/chrono_vine_data.dart';
import '../../../services/chrono_vine/avatar_system.dart';
import '../../../services/chrono_vine/vine_layout_engine.dart';
import '../../../services/vine_3d/engine3d.dart' show Vec3, Engine3D, Camera, Lighting, ParticleSystem, ProjectedPoint;
import '../../../core/theme.dart';

/// 思维建筑工地可视化
class MindConstructionSite extends StatefulWidget {
  final String roomId;
  final VineLayoutEngine? layoutEngine;
  final AvatarSystem? avatarSystem;
  final Function(VineNode)? onNodeTap;
  final Function(VineNode)? onNodeLongPress;
  
  const MindConstructionSite({
    super.key,
    required this.roomId,
    this.layoutEngine,
    this.avatarSystem,
    this.onNodeTap,
    this.onNodeLongPress,
  });

  @override
  State<MindConstructionSite> createState() => _MindConstructionSiteState();
}

class _MindConstructionSiteState extends State<MindConstructionSite>
    with TickerProviderStateMixin {
  // 3D引擎
  late Engine3D _engine;
  late VineLayoutEngine _layoutEngine;
  late AvatarSystem _avatarSystem;
  
  // 动画
  late AnimationController _animationController;
  
  // 粒子系统
  final ParticleSystem _particles = ParticleSystem();
  
  // 状态
  String? _selectedNodeId;
  String? _hoveredNodeId;
  bool _isDragging = false;
  Offset _lastPanPosition = Offset.zero;
  
  // 相机控制
  double _targetRotationY = 0.3;
  double _targetRotationX = -0.2;
  double _targetZoom = 1.0;

  @override
  void initState() {
    super.initState();
    
    _layoutEngine = widget.layoutEngine ?? VineLayoutEngine();
    _avatarSystem = widget.avatarSystem ?? AvatarSystem();
    _engine = Engine3D(
      camera: Camera(
        position: Vec3(300, 200, 400),
        target: Vec3.zero,
        fov: 50,
      ),
    );
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    
    _animationController.addListener(_onAnimationUpdate);
    
    _initializeDemoData();
  }
  
  void _initializeDemoData() {
    // 颜色调色板
    final colors = [
      const Color(0xFF60A5FA), // 蓝
      const Color(0xFF34D399), // 绿
      const Color(0xFFFBBF24), // 黄
      const Color(0xFFA78BFA), // 紫
    ];
    
    // 参与者
    final participants = [
      ('alice', 'Alice'),
      ('bob', 'Bob'),
      ('carol', 'Carol'),
    ];
    
    // 注册轨道
    for (var i = 0; i < participants.length; i++) {
      final (id, name) = participants[i];
      _layoutEngine.registerParticipant(id, name, colors[i]);
      
      _avatarSystem.createAvatar(
        id,
        name,
        colors[i],
        initialPosition: Vec3(
          math.cos(i * 2 * math.pi / 3) * 150,
          -50,
          math.sin(i * 2 * math.pi / 3) * 150,
        ),
      );
    }
    
    // 生成时间轴数据（模拟一场真实会议）
    final baseTime = DateTime.now().subtract(const Duration(minutes: 45));
    
    // Alice的主线 - 开场介绍
    var lastAliceNode = _layoutEngine.addNode(
      roomId: widget.roomId,
      messageId: 'msg_1',
      content: '大家好，今天我们来讨论Q4的产品规划。我的初步想法是...',
      authorId: 'alice',
      timestamp: baseTime,
      size: 25,
    );
    
    // Bob的回应 - 分支
    var lastBobNode = _layoutEngine.addNode(
      roomId: widget.roomId,
      messageId: 'msg_2',
      content: '我觉得这个方向不错，但我想补充一下技术实现的考虑...',
      authorId: 'bob',
      timestamp: baseTime.add(const Duration(minutes: 3)),
      parentId: lastAliceNode.id,
      size: 22,
    );
    
    // Carol的不同意见 - 形成争议
    var carolNode = _layoutEngine.addNode(
      roomId: widget.roomId,
      messageId: 'msg_3',
      content: '我有一个不同的看法。从市场角度，我们可能应该优先考虑...',
      authorId: 'carol',
      timestamp: baseTime.add(const Duration(minutes: 5)),
      parentId: lastAliceNode.id,
      type: VineNodeType.branch,
      size: 24,
    );
    carolNode.status = NodeStatus.placed;
    
    // Alice的里程碑决策
    var milestone = _layoutEngine.addNode(
      roomId: widget.roomId,
      messageId: 'msg_4',
      content: '综合大家的意见，我决定：我们将采用混合方案，A方向为主，B方向为辅。',
      authorId: 'alice',
      timestamp: baseTime.add(const Duration(minutes: 15)),
      parentId: lastBobNode.id,
      type: VineNodeType.milestone,
      size: 35,
    );
    milestone.confirm();
    
    // 添加AI叶子
    milestone.addLeaf(AILeaf.generate(
      parentNode: milestone,
      type: AILeafType.decision,
      title: '关键决策',
      content: '采用混合方案：A方向为主（60%资源），B方向为辅（40%资源）',
      todos: [
        TodoItem(
          id: 'todo_1',
          description: '制定A方向详细计划',
          assigneeId: 'bob',
          priority: TodoPriority.high,
        ),
        TodoItem(
          id: 'todo_2',
          description: '市场调研报告',
          assigneeId: 'carol',
          priority: TodoPriority.high,
        ),
      ],
    ));
    
    // 更多节点...
    for (var i = 0; i < 8; i++) {
      final author = participants[i % 3].$1;
      final parent = _layoutEngine.nodes.values
          .where((n) => n.authorId == author)
          .lastOrNull?.id;
      
      final node = _layoutEngine.addNode(
        roomId: widget.roomId,
        messageId: 'msg_${i + 5}',
        content: '补充讨论点 ${i + 1}：具体实施细节和分工安排...',
        authorId: author,
        timestamp: baseTime.add(Duration(minutes: 20 + i * 3)),
        parentId: parent,
        size: 18 + math.Random().nextDouble() * 10,
      );
    }
    
    // 触发Avatar飞行动画
    _scheduleAvatarMovements();
  }
  
  void _scheduleAvatarMovements() {
    var delay = 0;
    for (final node in _layoutEngine.nodes.values) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          _avatarSystem.dispatchToPlaceNode(
            node.authorId,
            node.position.layoutPosition,
            node.id,
          );
        }
      });
      delay += 800;
    }
  }
  
  void _onAnimationUpdate() {
    final dt = 0.016;
    
    // 平滑相机控制
    _engine.camera.position = _engine.camera.position.lerp(
      _calculateCameraPosition(),
      0.05,
    );
    
    // 更新Avatar
    _avatarSystem.updateAll(dt, _layoutEngine);
    
    // 更新粒子
    _particles.update(dt);
    
    // 更新节点建造进度
    for (final node in _layoutEngine.nodes.values) {
      if (node.buildProgress < 1.0) {
        node.updateBuildProgress(node.buildProgress + dt * 0.3);
      }
      node.hoverPhase += dt;
    }
    
    setState(() {});
  }
  
  Vec3 _calculateCameraPosition() {
    final distance = 500 / _targetZoom;
    return Vec3(
      math.sin(_targetRotationY) * distance,
      math.sin(_targetRotationX) * distance * 0.5 + 100,
      math.cos(_targetRotationY) * distance,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _engine.screenSize = constraints.biggest;
        
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onTapUp: _onTapUp,
          onLongPressStart: _onLongPress,
          child: Container(
            color: const Color(0xFF0A0A0F),
            child: CustomPaint(
              size: constraints.biggest,
              painter: _MindConstructionPainter(
                engine: _engine,
                layoutEngine: _layoutEngine,
                avatarSystem: _avatarSystem,
                particles: _particles,
                selectedNodeId: _selectedNodeId,
                animationValue: _animationController.value,
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _onScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.focalPoint;
    _isDragging = true;
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      _targetZoom = (_targetZoom * details.scale).clamp(0.3, 3.0);
    }
    
    final delta = details.focalPoint - _lastPanPosition;
    _targetRotationY += delta.dx * 0.005;
    _targetRotationX += delta.dy * 0.005;
    _targetRotationX = _targetRotationX.clamp(-0.8, 0.5);
    
    _lastPanPosition = details.focalPoint;
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    _isDragging = false;
  }
  
  void _onTapUp(TapUpDetails details) {
    final hitNode = _hitTestNode(details.localPosition);
    if (hitNode != null) {
      setState(() => _selectedNodeId = hitNode.id);
      HapticFeedback.lightImpact();
      _particles.emit(
        hitNode.position.layoutPosition,
        hitNode.color,
        count: 15,
      );
      widget.onNodeTap?.call(hitNode);
    } else {
      setState(() => _selectedNodeId = null);
    }
  }
  
  void _onLongPress(LongPressStartDetails details) {
    final hitNode = _hitTestNode(details.localPosition);
    if (hitNode != null) {
      HapticFeedback.mediumImpact();
      widget.onNodeLongPress?.call(hitNode);
    }
  }
  
  VineNode? _hitTestNode(Offset position) {
    // 逆序检测（先检测前面的）
    final sorted = _layoutEngine.getNodesSortedByDepth(_engine.camera.position);
    
    for (final node in sorted.reversed) {
      final projected = _engine.project(node.position.layoutPosition);
      if (!projected.isVisible) continue;
      
      final distance = (position - projected.screenPos).distance;
      if (distance < node.size * projected.scale + 15) {
        return node;
      }
    }
    return null;
  }
}

/// 思维建筑工地绘制器
class _MindConstructionPainter extends CustomPainter {
  final Engine3D engine;
  final VineLayoutEngine layoutEngine;
  final AvatarSystem avatarSystem;
  final ParticleSystem particles;
  final String? selectedNodeId;
  final double animationValue;
  
  _MindConstructionPainter({
    required this.engine,
    required this.layoutEngine,
    required this.avatarSystem,
    required this.particles,
    this.selectedNodeId,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景
    _drawBackground(canvas, size);
    
    // 2. 绘制中央时间轴（铁路主线）
    _drawTimeAxis(canvas, size);
    
    // 3. 绘制参与者轨道
    _drawParticipantTracks(canvas, size);
    
    // 4. 获取按深度排序的节点
    final sortedNodes = layoutEngine.getNodesSortedByDepth(engine.camera.position);
    
    // 5. 绘制连接线
    _drawConnections(canvas, size, sortedNodes);
    
    // 6. 绘制Avatar拖尾
    _drawAvatarTrails(canvas, size);
    
    // 7. 绘制节点
    for (final node in sortedNodes) {
      _drawNode(canvas, size, node);
    }
    
    // 8. 绘制Avatar
    for (final avatar in avatarSystem.allAvatars) {
      _drawAvatar(canvas, size, avatar);
    }
    
    // 9. 绘制粒子
    _drawParticles(canvas, size);
    
    // 10. 前景效果
    _drawForegroundEffects(canvas, size);
  }
  
  void _drawBackground(Canvas canvas, Size size) {
    // 径向渐变背景
    final gradient = RadialGradient(
      center: Alignment(0, -0.3),
      radius: 1.2,
      colors: [
        const Color(0xFF1a1a2e),
        const Color(0xFF0A0A0F),
      ],
    );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
    
    // 星空效果
    final random = math.Random(42);
    final starPaint = Paint()
      ..color = Colors.white.withAlpha(30);
    
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }
  }
  
  void _drawTimeAxis(Canvas canvas, Size size) {
    final range = layoutEngine.getTimeRange();
    if (range == null) return;
    
    // 主时间轴线（发光效果）
    final glowPaint = Paint()
      ..color = const Color(0xFF60A5FA).withAlpha(80)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke;
    
    final linePaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // 绘制时间轴段落（带动画）
    final segments = 20;
    for (var i = 0; i < segments; i++) {
      final t1 = i / segments;
      final t2 = (i + 1) / segments;
      
      final y1 = _timeToY(t1, size);
      final y2 = _timeToY(t2, size);
      
      // 发光背景
      canvas.drawLine(
        Offset(size.width / 2, y1),
        Offset(size.width / 2, y2),
        glowPaint,
      );
      
      // 主体线
      canvas.drawLine(
        Offset(size.width / 2, y1),
        Offset(size.width / 2, y2),
        linePaint,
      );
    }
    
    // 时间刻度
    final tickPaint = Paint()
      ..color = const Color(0xFF60A5FA).withAlpha(150)
      ..strokeWidth = 2;
    
    final duration = range.duration.inMinutes;
    for (var i = 0; i <= duration; i += 5) {
      final t = i / duration.clamp(1, 999);
      final y = _timeToY(1 - t, size);
      
      canvas.drawLine(
        Offset(size.width / 2 - 8, y),
        Offset(size.width / 2 + 8, y),
        tickPaint,
      );
    }
  }
  
  double _timeToY(double t, Size size) {
    return size.height * 0.85 - t * size.height * 0.7;
  }
  
  void _drawParticipantTracks(Canvas canvas, Size size) {
    for (final track in layoutEngine.tracks.values) {
      final paint = Paint()
        ..color = track.color.withAlpha(40)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      // 螺旋轨道
      final path = Path();
      var first = true;
      
      for (var t = 0.0; t <= 1.0; t += 0.02) {
        final y = _timeToY(1 - t, size);
        final angle = track.trackAngle + t * 6 * math.pi;
        final radius = track.trackRadius;
        
        final x = size.width / 2 + math.cos(angle) * radius;
        
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  void _drawConnections(Canvas canvas, Size size, List<VineNode> nodes) {
    final nodeMap = {for (final n in nodes) n.id: n};
    
    for (final node in nodes) {
      if (node.parentId == null) continue;
      
      final parent = nodeMap[node.parentId];
      if (parent == null) continue;
      
      final from = engine.project(parent.position.layoutPosition);
      final to = engine.project(node.position.layoutPosition);
      
      if (!from.isVisible || !to.isVisible) continue;
      
      final isBranch = node.type == VineNodeType.branch;
      
      // 发光效果
      final glowPaint = Paint()
        ..color = (isBranch ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA))
            .withAlpha(60)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.stroke;
      
      // 主体线
      final paint = Paint()
        ..color = isBranch ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA)
        ..strokeWidth = isBranch ? 2.5 : 2
        ..style = PaintingStyle.stroke;
      
      // 贝塞尔曲线
      final path = Path();
      path.moveTo(from.screenPos.dx, from.screenPos.dy);
      
      final midY = (from.screenPos.dy + to.screenPos.dy) / 2;
      path.cubicTo(
        from.screenPos.dx, midY,
        to.screenPos.dx, midY,
        to.screenPos.dx, to.screenPos.dy,
      );
      
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }
  
  void _drawAvatarTrails(Canvas canvas, Size size) {
    for (final avatar in avatarSystem.allAvatars) {
      if (avatar.trail.length < 2) continue;
      
      for (var i = 0; i < avatar.trail.length - 1; i++) {
        final from = engine.project(avatar.trail[i].position);
        final to = engine.project(avatar.trail[i + 1].position);
        
        if (!from.isVisible || !to.isVisible) continue;
        
        final alpha = ((i / avatar.trail.length) * 200).toInt();
        final width = ((i / avatar.trail.length) * 5).clamp(1.0, 5.0);
        
        canvas.drawLine(
          from.screenPos,
          to.screenPos,
          Paint()
            ..color = avatar.color.withAlpha(alpha)
            ..strokeWidth = width,
        );
      }
    }
  }
  
  void _drawNode(Canvas canvas, Size size, VineNode node) {
    final projected = engine.project(node.position.layoutPosition);
    if (!projected.isVisible) return;
    
    final nodeSize = node.size * projected.scale * node.buildProgress;
    if (nodeSize < 2) return;
    
    final center = projected.screenPos;
    
    // 选中效果
    if (node.id == selectedNodeId) {
      canvas.drawCircle(
        center,
        nodeSize * 1.8,
        Paint()
          ..color = Colors.white.withAlpha(40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }
    
    // 悬浮动画
    final hoverOffset = math.sin(node.hoverPhase * 2) * 3 * projected.scale;
    final pos = center.translate(0, hoverOffset);
    
    // 阴影
    _drawNodeShadow(canvas, pos, nodeSize);
    
    // 根据类型绘制
    switch (node.type) {
      case VineNodeType.milestone:
        _drawMilestone(canvas, pos, nodeSize, node);
        break;
      case VineNodeType.merge:
        _drawConsensusCrystal(canvas, pos, nodeSize, node);
        break;
      case VineNodeType.contention:
        _drawContentionThorns(canvas, pos, nodeSize, node);
        break;
      default:
        _drawVoiceBlock(canvas, pos, nodeSize, node);
    }
    
    // AI叶子
    for (final leaf in node.leaves) {
      _drawLeaf(canvas, size, node, leaf, projected.scale);
    }
  }
  
  void _drawNodeShadow(Canvas canvas, Offset center, double size) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, size * 0.8),
        width: size * 2.2,
        height: size * 0.6,
      ),
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.4),
    );
  }
  
  void _drawVoiceBlock(Canvas canvas, Offset center, double size, VineNode node) {
    // 发光边框
    canvas.drawCircle(
      center,
      size * 1.1,
      Paint()
        ..color = node.color.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    
    // 主体
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: [
        _lighten(node.color, 0.4),
        node.color,
        _darken(node.color, 0.3),
      ],
    );
    
    canvas.drawCircle(
      center,
      size,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: size),
        ),
    );
    
    // 高光
    canvas.drawCircle(
      center.translate(-size * 0.3, -size * 0.3),
      size * 0.25,
      Paint()
        ..color = Colors.white.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  
  void _drawConsensusCrystal(Canvas canvas, Offset center, double size, VineNode node) {
    // 脉冲发光
    final pulse = (math.sin(animationValue * math.pi * 4) + 1) / 2;
    canvas.drawCircle(
      center,
      size * (1.5 + pulse * 0.3),
      Paint()
        ..color = const Color(0xFF34D399).withAlpha((100 * pulse).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    
    // 多面体水晶
    final path = Path();
    final facets = 6;
    
    for (var i = 0; i < facets * 2; i++) {
      final angle = (i / (facets * 2)) * math.pi * 2 - math.pi / 2;
      final radius = i % 2 == 0 ? size * 1.3 : size * 0.7;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    // 水晶填充
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF34D399).withAlpha(100)
        ..style = PaintingStyle.fill,
    );
    
    // 边框
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF34D399)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }
  
  void _drawContentionThorns(Canvas canvas, Offset center, double size, VineNode node) {
    final random = math.Random(42);
    
    // 红色脉冲
    final pulse = (math.sin(animationValue * math.pi * 6) + 1) / 2;
    canvas.drawCircle(
      center,
      size * (1 + pulse * 0.2),
      Paint()
        ..color = const Color(0xFFEF4444).withAlpha((150 * pulse).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    
    // 荆棘放射状
    for (var i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2 + random.nextDouble() * 0.5;
      final length = size * (1 + random.nextDouble() * 0.5);
      
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * length,
          center.dy + math.sin(angle) * length,
        ),
        Paint()
          ..color = const Color(0xFFEF4444).withAlpha(150 + random.nextInt(100))
          ..strokeWidth = 2 + random.nextDouble() * 2
          ..strokeCap = StrokeCap.round,
      );
    }
    
    // 核心
    canvas.drawCircle(
      center,
      size * 0.5,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.fill,
    );
  }
  
  void _drawMilestone(Canvas canvas, Offset center, double size, VineNode node) {
    // 星光效果
    final path = Path();
    final points = 5;
    
    for (var i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final radius = i % 2 == 0 ? size * 1.4 : size * 0.5;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    // 金色发光
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD700).withAlpha(150)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    
    // 星形
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill,
    );
  }
  
  void _drawLeaf(Canvas canvas, Size size, VineNode parent, AILeaf leaf, double scale) {
    final parentProj = engine.project(parent.position.layoutPosition);
    if (!parentProj.isVisible) return;
    
    final leafPos = parentProj.screenPos.translate(
      leaf.offset.x * scale,
      (leaf.offset.y + math.sin(animationValue * math.pi * 2 + parent.id.hashCode) * 3) * scale,
    );
    
    final leafSize = 12 * scale * leaf.relevanceScore;
    
    final color = _getLeafColor(leaf.type);
    
    // 叶子形状
    final path = Path();
    path.moveTo(leafPos.dx, leafPos.dy - leafSize);
    path.quadraticBezierTo(
      leafPos.dx + leafSize * 1.5, leafPos.dy - leafSize * 0.3,
      leafPos.dx + leafSize * 0.5, leafPos.dy + leafSize,
    );
    path.quadraticBezierTo(
      leafPos.dx - leafSize * 0.5, leafPos.dy + leafSize,
      leafPos.dx - leafSize * 1.5, leafPos.dy - leafSize * 0.3,
    );
    path.close();
    
    // 发光
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    
    // 主体
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha(180)
        ..style = PaintingStyle.fill,
    );
    
    // 叶脉
    canvas.drawLine(
      leafPos.translate(0, -leafSize * 0.7),
      leafPos.translate(0, leafSize * 0.7),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }
  
  void _drawAvatar(Canvas canvas, Size size, AvatarEntity avatar) {
    final projected = engine.project(avatar.position);
    if (!projected.isVisible) return;
    
    final avatarSize = 14 * projected.scale;
    final center = projected.screenPos;
    
    // 能量环脉冲
    final pulse = (math.sin(animationValue * math.pi * 3 + avatar.id.hashCode) + 1) / 2;
    canvas.drawCircle(
      center,
      avatarSize * (1.3 + pulse * 0.2),
      Paint()
        ..color = avatar.color.withAlpha((100 * avatar.energy * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * projected.scale,
    );
    
    // 主体
    final gradient = RadialGradient(
      colors: [
        _lighten(avatar.color, 0.3),
        avatar.color,
        _darken(avatar.color, 0.2),
      ],
    );
    
    canvas.drawCircle(
      center,
      avatarSize,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: avatarSize),
        ),
    );
    
    // 状态指示
    final statusColor = avatar.state == AvatarBehaviorState.working
        ? const Color(0xFFFBBF24)
        : avatar.state == AvatarBehaviorState.flying
            ? Colors.white
            : const Color(0xFF34D399);
    
    canvas.drawCircle(
      center.translate(avatarSize * 0.7, -avatarSize * 0.7),
      4 * projected.scale,
      Paint()..color = statusColor,
    );
    
    // 名字标签
    if (projected.scale > 0.5) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: avatar.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10 * projected.scale,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center.translate(-textPainter.width / 2, avatarSize + 6),
      );
    }
  }
  
  void _drawParticles(Canvas canvas, Size size) {
    for (final p in particles.particles) {
      final projected = engine.project(p.position);
      if (!projected.isVisible) continue;
      
      canvas.drawCircle(
        projected.screenPos,
        p.size * projected.scale * p.lifeRatio,
        Paint()
          ..color = p.color.withAlpha((255 * p.lifeRatio).toInt())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.3),
      );
    }
  }
  
  void _drawForegroundEffects(Canvas canvas, Size size) {
    // 晕影效果
    final vignette = RadialGradient(
      colors: [
        Colors.transparent,
        Colors.black.withAlpha(100),
      ],
      stops: const [0.7, 1.0],
    );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = vignette.createShader(Offset.zero & size)
        ..blendMode = BlendMode.dstIn,
    );
  }
  
  Color _lighten(Color c, double amount) {
    return Color.lerp(c, Colors.white, amount.clamp(0, 1))!;
  }
  
  Color _darken(Color c, double amount) {
    return Color.lerp(c, Colors.black, amount.clamp(0, 1))!;
  }
  
  Color _getLeafColor(AILeafType type) {
    return switch (type) {
      AILeafType.summary => const Color(0xFF60A5FA),
      AILeafType.actionItems => const Color(0xFFFBBF24),
      AILeafType.decision => const Color(0xFF34D399),
      AILeafType.riskAlert => const Color(0xFFEF4444),
      AILeafType.insight => const Color(0xFFA78BFA),
      AILeafType.reference => const Color(0xFF9CA3AF),
    };
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
