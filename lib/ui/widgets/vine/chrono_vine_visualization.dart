/// ChronoVine 3D可视化组件
/// 
/// 核心特性：
/// - 中央时间轴（铁路线）
/// - 参与者螺旋轨道
/// - 节点建筑生长动画
/// - Avatar飞行系统
/// - AI叶子层叠
/// - 回放控制

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../models/chrono_vine/chrono_vine_data.dart';
import '../../../services/chrono_vine/avatar_system.dart';
import '../../../services/chrono_vine/replay_system.dart';
import '../../../services/chrono_vine/vine_layout_engine.dart';
import 'painters/advanced_vine_painter.dart';

/// ChronoVine可视化器
class ChronoVineVisualization extends StatefulWidget {
  final String roomId;
  final VineLayoutEngine? engine;
  final AvatarSystem? avatarSystem;
  final Function(VineNode)? onNodeTap;
  final Function(VineNode)? onNodeLongPress;
  
  const ChronoVineVisualization({
    super.key,
    required this.roomId,
    this.engine,
    this.avatarSystem,
    this.onNodeTap,
    this.onNodeLongPress,
  });

  @override
  State<ChronoVineVisualization> createState() => _ChronoVineVisualizationState();
}

class _ChronoVineVisualizationState extends State<ChronoVineVisualization>
    with TickerProviderStateMixin {
  late VineLayoutEngine _engine;
  late AvatarSystem _avatarSystem;
  late ReplayController _replayController;
  late AnimationController _animationController;
  
  // 相机控制
  double _rotationY = 0;
  double _rotationX = -0.3;
  double _zoom = 1.0;
  
  // 选中的节点
  String? _selectedNodeId;
  
  // 参与者颜色
  final Map<String, Color> _participantColors = {};
  final List<Color> _colorPalette = [
    AppTheme.accentPrimary,
    AppTheme.success,
    AppTheme.warning,
    const Color(0xFF744DA9),
    const Color(0xFF00B7C3),
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFE66D),
  ];

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? VineLayoutEngine();
    _avatarSystem = widget.avatarSystem ?? AvatarSystem();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    
    _animationController.addListener(_onAnimationUpdate);
    
    // 初始化示例数据
    _initializeDemoData();
  }
  
  void _initializeDemoData() {
    // 注册参与者
    final participants = [
      ('user1', 'Alice'),
      ('user2', 'Bob'),
      ('user3', 'Carol'),
    ];
    
    for (var i = 0; i < participants.length; i++) {
      final (id, name) = participants[i];
      final color = _colorPalette[i % _colorPalette.length];
      _participantColors[id] = color;
      
      _engine.registerParticipant(id, name, color);
      _avatarSystem.createAvatar(
        id, 
        name, 
        color,
        initialPosition: Vector3D(
          math.cos(i * 2 * math.pi / 3) * 200,
          0,
          math.sin(i * 2 * math.pi / 3) * 200,
        ),
      );
    }
    
    // 创建示例节点（模拟一条沿着时间轴的铁路线）
    final now = DateTime.now();
    final baseTime = now.subtract(const Duration(minutes: 30));
    
    // Alice的节点（主线）
    String? lastAliceNode;
    for (var i = 0; i < 5; i++) {
      final node = _engine.addNode(
        roomId: widget.roomId,
        messageId: 'msg_alice_$i',
        content: 'Alice的想法 $i：关于产品方向的讨论内容',
        authorId: 'user1',
        timestamp: baseTime.add(Duration(minutes: i * 5)),
        parentId: lastAliceNode,
        type: i == 2 ? VineNodeType.milestone : VineNodeType.voiceBlock,
        size: 20 + i * 2,
      );
      lastAliceNode = node.id;
      
      // 添加AI叶子到里程碑
      if (i == 2) {
        node.addLeaf(AILeaf.generate(
          parentNode: node,
          type: AILeafType.decision,
          title: '关键决策',
          content: '确定产品核心方向',
        ));
      }
    }
    
    // Bob的分支（从Alice的第2个节点分出来）
    final bobBranchParent = _engine.nodes.values
        .where((n) => n.authorId == 'user1')
        .skip(1)
        .first
        .id;
    
    String? lastBobNode;
    for (var i = 0; i < 3; i++) {
      final node = _engine.addNode(
        roomId: widget.roomId,
        messageId: 'msg_bob_$i',
        content: 'Bob的补充 $i：技术实现方案讨论',
        authorId: 'user2',
        timestamp: baseTime.add(Duration(minutes: 12 + i * 4)),
        parentId: lastBobNode ?? bobBranchParent,
        type: i == 1 ? VineNodeType.contention : VineNodeType.voiceBlock,
      );
      lastBobNode = node.id;
    }
    
    // Carol的节点（另一个分支，最后合并）
    String? lastCarolNode;
    for (var i = 0; i < 4; i++) {
      final node = _engine.addNode(
        roomId: widget.roomId,
        messageId: 'msg_carol_$i',
        content: 'Carol的观点 $i：市场分析角度',
        authorId: 'user3',
        timestamp: baseTime.add(Duration(minutes: 15 + i * 3)),
        parentId: lastCarolNode ?? bobBranchParent,
        type: i == 3 ? VineNodeType.merge : VineNodeType.voiceBlock,
      );
      lastCarolNode = node.id;
    }
    
    // 触发Avatar飞往节点
    _scheduleAvatarMovements();
  }
  
  void _scheduleAvatarMovements() {
    // 延迟触发Avatar动画
    Future.delayed(const Duration(seconds: 1), () {
      for (final entry in _engine.nodes.entries) {
        final nodeId = entry.key;
        final node = entry.value;
        
        Future.delayed(Duration(seconds: node.position.timestamp.second % 10), () {
          if (mounted) {
            _avatarSystem.dispatchToPlaceNode(
              node.authorId,
              node.position.layoutPosition,
              nodeId,
            );
          }
        });
      }
    });
  }
  
  void _onAnimationUpdate() {
    final dt = 0.016; // 假设60fps
    
    // 更新Avatar
    _avatarSystem.updateAll(dt, _engine);
    
    // 更新节点建造进度
    _updateNodeConstruction(dt);
    
    setState(() {});
  }
  
  void _updateNodeConstruction(double dt) {
    for (final node in _engine.nodes.values) {
      if (node.buildProgress < 1.0) {
        node.updateBuildProgress(node.buildProgress + dt * 0.5);
      }
      // 更新悬浮相位
      node.hoverPhase += dt;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: _onScaleUpdate,
      onTapUp: _onTapUp,
      child: Container(
        color: AppTheme.darkBackgroundBase,
        child: CustomPaint(
          size: Size.infinite,
          painter: ChronoVinePainter(
            engine: _engine,
            avatars: _avatarSystem.allAvatars,
            cameraRotationY: _rotationY,
            cameraRotationX: _rotationX,
            zoom: _zoom,
            selectedNodeId: _selectedNodeId,
            animationValue: _animationController.value,
          ),
        ),
      ),
    );
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale != 1.0) {
        _zoom = (_zoom * details.scale).clamp(0.3, 5.0);
      }
      
      // 旋转
      _rotationY += details.focalPointDelta.dx * 0.005;
      _rotationX += details.focalPointDelta.dy * 0.005;
      _rotationX = _rotationX.clamp(-1.0, 0.5);
    });
  }
  
  void _onTapUp(TapUpDetails details) {
    // 命中测试
    final hitNode = _hitTestNode(details.localPosition);
    if (hitNode != null) {
      setState(() {
        _selectedNodeId = hitNode.id;
      });
      HapticFeedback.lightImpact();
      widget.onNodeTap?.call(hitNode);
    } else {
      setState(() {
        _selectedNodeId = null;
      });
    }
  }
  
  VineNode? _hitTestNode(Offset position) {
    // 简化的命中测试
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    
    for (final node in _engine.nodes.values) {
      // 简单的投影计算
      final projected = _project(node.position.layoutPosition, size);
      
      final distance = (position - projected).distance;
      if (distance < node.size * _zoom + 10) {
        return node;
      }
    }
    return null;
  }
  
  Offset _project(Vector3D point, Size screenSize) {
    // 简化的透视投影
    final distance = 500 / _zoom;
    final scale = distance / (distance + point.z);
    
    final rotated = point.rotateY(_rotationY).rotateX(_rotationX);
    
    return Offset(
      screenSize.width / 2 + rotated.x * scale,
      screenSize.height / 2 - rotated.y * scale + 100, // 向下偏移
    );
  }
}

/// ChronoVine专用绘制器
class ChronoVinePainter extends CustomPainter {
  final VineLayoutEngine engine;
  final List<AvatarEntity> avatars;
  final double cameraRotationY;
  final double cameraRotationX;
  final double zoom;
  final String? selectedNodeId;
  final double animationValue;
  
  ChronoVinePainter({
    required this.engine,
    required this.avatars,
    required this.cameraRotationY,
    required this.cameraRotationX,
    required this.zoom,
    this.selectedNodeId,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制背景网格
    _drawGrid(canvas, size);
    
    // 绘制中央时间轴（铁路主线）
    _drawTimeAxis(canvas, size);
    
    // 绘制参与者轨道
    _drawParticipantTracks(canvas, size);
    
    // 获取节点并按深度排序
    final cameraPos = Vector3D(
      math.sin(cameraRotationY) * 400,
      math.sin(cameraRotationX) * 200,
      math.cos(cameraRotationY) * 400,
    );
    
    final sortedNodes = engine.getNodesSortedByDepth(cameraPos);
    
    // 绘制连接线（在节点后面）
    _drawConnections(canvas, size, sortedNodes);
    
    // 绘制Avatar拖尾
    _drawAvatarTrails(canvas, size);
    
    // 绘制节点
    for (final node in sortedNodes) {
      _drawNode(canvas, size, node);
    }
    
    // 绘制Avatar
    for (final avatar in avatars) {
      _drawAvatar(canvas, size, avatar);
    }
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.darkBorderPrimary.withAlpha(20)
      ..strokeWidth = 1;
    
    // 绘制透视网格
    for (int i = -5; i <= 5; i++) {
      final x = size.width / 2 + i * 100;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }
  
  void _drawTimeAxis(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final range = engine.getTimeRange();
    
    if (range == null) return;
    
    // 时间轴线
    final paint = Paint()
      ..color = AppTheme.accentPrimary.withAlpha(100)
      ..strokeWidth = 4 * zoom
      ..style = PaintingStyle.stroke;
    
    // 绘制垂直的时间轴（铁路主线）
    final path = Path();
    path.moveTo(centerX, size.height * 0.8);
    path.lineTo(centerX, size.height * 0.2);
    
    canvas.drawPath(path, paint);
    
    // 时间刻度
    final tickPaint = Paint()
      ..color = AppTheme.accentPrimary.withAlpha(150)
      ..strokeWidth = 2 * zoom;
    
    final duration = range.duration.inMinutes;
    for (var i = 0; i <= duration; i += 5) {
      final y = size.height * 0.8 - (i / duration) * size.height * 0.6;
      
      canvas.drawLine(
        Offset(centerX - 10 * zoom, y),
        Offset(centerX + 10 * zoom, y),
        tickPaint,
      );
    }
  }
  
  void _drawParticipantTracks(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    
    for (final track in engine.tracks.values) {
      final paint = Paint()
        ..color = track.color.withAlpha(50)
        ..strokeWidth = 2 * zoom
        ..style = PaintingStyle.stroke;
      
      // 绘制螺旋轨道
      final path = Path();
      for (var t = 0.0; t < 1.0; t += 0.02) {
        final angle = track.trackAngle + t * 4 * math.pi;
        final y = size.height * 0.8 - t * size.height * 0.6;
        final x = centerX + math.cos(angle) * track.trackRadius * zoom;
        
        if (t == 0) {
          path.moveTo(x, y);
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
      // 父连接
      if (node.parentId != null && nodeMap.containsKey(node.parentId)) {
        final parent = nodeMap[node.parentId]!;
        _drawConnectionLine(
          canvas, 
          size, 
          parent.position.layoutPosition,
          node.position.layoutPosition,
          isBranch: false,
        );
      }
      
      // 分支连接
      for (final targetId in node.branchTargetIds) {
        if (nodeMap.containsKey(targetId)) {
          _drawConnectionLine(
            canvas,
            size,
            node.position.layoutPosition,
            nodeMap[targetId]!.position.layoutPosition,
            isBranch: true,
          );
        }
      }
    }
  }
  
  void _drawConnectionLine(
    Canvas canvas, 
    Size size, 
    Vector3D from, 
    Vector3D to, {
    bool isBranch = false,
  }) {
    final fromProj = _project(from, size);
    final toProj = _project(to, size);
    
    final paint = Paint()
      ..color = isBranch ? AppTheme.warning.withAlpha(150) : AppTheme.accentPrimary.withAlpha(100)
      ..strokeWidth = isBranch ? 3 * zoom : 2 * zoom
      ..style = PaintingStyle.stroke;
    
    // 贝塞尔曲线
    final path = Path();
    path.moveTo(fromProj.dx, fromProj.dy);
    
    final midY = (fromProj.dy + toProj.dy) / 2;
    path.cubicTo(
      fromProj.dx, midY,
      toProj.dx, midY,
      toProj.dx, toProj.dy,
    );
    
    canvas.drawPath(path, paint);
  }
  
  void _drawAvatarTrails(Canvas canvas, Size size) {
    for (final avatar in avatars) {
      if (avatar.trail.length < 2) continue;
      
      for (int i = 0; i < avatar.trail.length - 1; i++) {
        final from = _project(avatar.trail[i].position, size);
        final to = _project(avatar.trail[i + 1].position, size);
        
        final alpha = (i / avatar.trail.length * 200).toInt();
        final paint = Paint()
          ..color = avatar.color.withAlpha(alpha)
          ..strokeWidth = (i / avatar.trail.length * 4 * zoom).clamp(1.0, 8.0);
        
        canvas.drawLine(from, to, paint);
      }
    }
  }
  
  void _drawNode(Canvas canvas, Size size, VineNode node) {
    final projected = _project(node.position.layoutPosition, size);
    final nodeSize = node.size * zoom * node.buildProgress;
    
    if (nodeSize < 2) return; // 太小不绘制
    
    // 选中效果
    if (node.id == selectedNodeId) {
      final glowPaint = Paint()
        ..color = AppTheme.accentPrimary.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(projected, nodeSize * 1.5, glowPaint);
    }
    
    // 悬浮动画
    final hoverOffset = math.sin(node.hoverPhase * 2) * 3 * zoom;
    final finalPos = Offset(projected.dx, projected.dy + hoverOffset);
    
    // 阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(60)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, nodeSize * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(finalPos.dx, finalPos.dy + nodeSize * 0.8),
        width: nodeSize * 2,
        height: nodeSize * 0.6,
      ),
      shadowPaint,
    );
    
    // 节点主体
    final gradient = RadialGradient(
      colors: [
        _lightenColor(node.color, 0.3),
        node.color,
        _darkenColor(node.color, 0.3),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: finalPos, radius: nodeSize),
      );
    
    // 根据类型绘制不同形状
    switch (node.type) {
      case VineNodeType.merge:
        _drawCrystal(canvas, finalPos, nodeSize, paint);
        break;
      case VineNodeType.contention:
        _drawThorns(canvas, finalPos, nodeSize, node.color);
        break;
      case VineNodeType.milestone:
        _drawStar(canvas, finalPos, nodeSize, paint);
        break;
      default:
        canvas.drawCircle(finalPos, nodeSize, paint);
    }
    
    // AI叶子
    for (final leaf in node.leaves) {
      _drawLeaf(canvas, size, node, leaf);
    }
  }
  
  void _drawCrystal(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final points = 6;
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
      final radius = i % 2 == 0 ? size : size * 0.6;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawThorns(Canvas canvas, Offset center, double size, Color color) {
    final random = math.Random(42);
    
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + random.nextDouble() * 0.5;
      final length = size * (0.8 + random.nextDouble() * 0.6);
      
      final paint = Paint()
        ..color = color.withAlpha(150 + random.nextInt(100))
        ..strokeWidth = 2 + random.nextDouble() * 2
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * length,
          center.dy + math.sin(angle) * length,
        ),
        paint,
      );
    }
  }
  
  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final points = 5;
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
      final radius = i % 2 == 0 ? size : size * 0.4;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawLeaf(Canvas canvas, Size size, VineNode parent, AILeaf leaf) {
    final parentProj = _project(parent.position.layoutPosition, size);
    final leafPos = parentProj.translate(
      leaf.offset.x * zoom,
      leaf.offset.y * zoom,
    );
    
    final leafSize = 15 * zoom * leaf.relevanceScore;
    
    final paint = Paint()
      ..color = _getLeafColor(leaf.type).withAlpha(150)
      ..style = PaintingStyle.fill;
    
    // 简化的叶子形状
    final path = Path();
    path.moveTo(leafPos.dx, leafPos.dy - leafSize);
    path.quadraticBezierTo(
      leafPos.dx + leafSize, leafPos.dy - leafSize * 0.5,
      leafPos.dx, leafPos.dy + leafSize,
    );
    path.quadraticBezierTo(
      leafPos.dx - leafSize, leafPos.dy - leafSize * 0.5,
      leafPos.dx, leafPos.dy - leafSize,
    );
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawAvatar(Canvas canvas, Size size, AvatarEntity avatar) {
    final projected = _project(avatar.position, size);
    final avatarSize = 16 * zoom;
    
    // 能量环
    final energyPaint = Paint()
      ..color = avatar.color.withAlpha((150 * avatar.energy).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * zoom;
    
    canvas.drawCircle(
      projected,
      avatarSize * 1.2 + math.sin(animationValue * 10) * 2,
      energyPaint,
    );
    
    // Avatar主体
    final paint = Paint()
      ..color = avatar.color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(projected, avatarSize, paint);
    
    // 状态指示器
    final statusColor = switch (avatar.state) {
      AvatarBehaviorState.working => AppTheme.warning,
      AvatarBehaviorState.flying => Colors.white,
      _ => AppTheme.success,
    };
    
    final statusPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(projected.dx + avatarSize * 0.7, projected.dy - avatarSize * 0.7),
      4 * zoom,
      statusPaint,
    );
  }
  
  Offset _project(Vector3D point, Size size) {
    final distance = 500 / zoom;
    final scale = distance / (distance + point.z * 0.5);
    
    final rotated = point.rotateY(cameraRotationY).rotateX(cameraRotationX);
    
    return Offset(
      size.width / 2 + rotated.x * scale,
      size.height / 2 - rotated.y * scale + 100,
    );
  }
  
  Color _lightenColor(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount.clamp(0.0, 1.0))!;
  }
  
  Color _darkenColor(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount.clamp(0.0, 1.0))!;
  }
  
  Color _getLeafColor(AILeafType type) {
    return switch (type) {
      AILeafType.summary => AppTheme.accentPrimary,
      AILeafType.actionItems => AppTheme.warning,
      AILeafType.decision => AppTheme.success,
      AILeafType.riskAlert => AppTheme.error,
      AILeafType.insight => const Color(0xFF744DA9),
      AILeafType.reference => AppTheme.darkTextSecondary,
    };
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
