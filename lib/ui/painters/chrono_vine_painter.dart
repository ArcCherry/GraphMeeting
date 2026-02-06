import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/space_time_axis.dart';
import '../../models/chrono_vine/leaf_attachment.dart';
import '../../services/avatar/avatar_service.dart';
import '../../services/game/contention_resolution.dart';
import '../../core/theme.dart';
import '../../state/viewport_provider.dart';

/// 时序藤蔓绘制器
class ChronoVinePainter extends CustomPainter {
  final List<VineNode> nodes;
  final Viewport3D viewport;
  final Map<String, Color> participantColors;
  final VineNode? selectedNode;
  final Animation<double>? animation;
  final List<AvatarData> avatars;
  final Map<String, BeamEffect> beams;
  final Map<String, ContentionNode>? contentions;

  ChronoVinePainter({
    required this.nodes,
    required this.viewport,
    required this.participantColors,
    this.selectedNode,
    this.animation,
    this.avatars = const [],
    this.beams = const {},
    this.contentions,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // 1. 按 Z 深度排序（远到近，正确遮挡）
    final sortedNodes = _sortByDepth(nodes, size);

    // 2. 绘制时间轴（螺旋柱）
    _drawTimeAxis(canvas, size);

    // 3. 绘制藤蔓连接线和节点
    for (final node in sortedNodes) {
      final projected = viewport.project(size, node.position.layoutPosition);

      // 绘制藤蔓段（连接到父节点）
      if (node.parentId != null) {
        final parent = nodes.where((n) => n.id == node.parentId).firstOrNull;
        if (parent != null) {
          final parentProj = viewport.project(size, parent.position.layoutPosition);
          _drawVineSegment(canvas, parentProj, projected, node.nodeType);
        }
      }

      // 绘制节点
      _drawNode(canvas, projected, node);

      // 绘制 AI 叶子
      for (final leaf in node.leaves) {
        _drawLeaf(canvas, projected, leaf, animation?.value ?? 1.0);
      }

      // 绘制争议状态
      _drawContentionIndicator(canvas, size, node);
    }

    // 4. 绘制光束（争议解决效果，在 Avatar 之前）
    _drawBeams(canvas, size);

    // 5. 绘制 Avatar（在最上层）
    for (final avatar in avatars) {
      _drawAvatar(canvas, size, avatar);
    }

    // 5. 绘制选中节点高亮
    if (selectedNode != null) {
      final projected = viewport.project(size, selectedNode!.position.layoutPosition);
      _drawSelectionHighlight(canvas, projected);
    }
  }

  /// 绘制 Avatar
  void _drawAvatar(Canvas canvas, Size size, AvatarData avatar) {
    // 3D 投影
    final pos = avatar.position;
    final projected = viewport.project(size, pos);
    
    // 根据能量值调整发光强度
    final glowIntensity = 0.5 + avatar.energy * 0.5;
    final baseSize = 15.0 * projected.scale;
    
    // 绘制飞行轨迹
    if (avatar.trail.length > 1) {
      _drawAvatarTrail(canvas, size, avatar);
    }
    
    // Avatar 发光效果
    final glowPaint = Paint()
      ..color = avatar.color.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(projected.offset, baseSize * 2, glowPaint);
    
    // Avatar 主体 - 外圈
    final outerPaint = Paint()
      ..color = avatar.color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(projected.offset, baseSize, outerPaint);
    
    // Avatar 内圈 - 表示状态
    final innerColor = avatar.isWorking 
        ? Colors.yellow 
        : avatar.isFlying 
            ? Colors.white 
            : avatar.color.withOpacity(0.5);
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(projected.offset, baseSize * 0.5, innerPaint);
    
    // 绘制名字标签
    _drawAvatarLabel(canvas, projected, avatar, baseSize);
  }
  
  /// 绘制 Avatar 飞行轨迹
  void _drawAvatarTrail(Canvas canvas, Size size, AvatarData avatar) {
    if (avatar.trail.length < 2) return;
    
    final path = Path();
    var first = true;
    
    for (final point in avatar.trail) {
      final projected = viewport.project(size, point);
      if (first) {
        path.moveTo(projected.x, projected.y);
        first = false;
      } else {
        path.lineTo(projected.x, projected.y);
      }
    }
    
    final paint = Paint()
      ..color = avatar.color.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, paint);
  }
  
  /// 绘制 Avatar 名字标签
  void _drawAvatarLabel(Canvas canvas, ProjectedPoint projected, AvatarData avatar, double baseSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: avatar.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: max(8, 10 * projected.scale),
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(projected.x - textPainter.width / 2, projected.y - baseSize - textPainter.height - 4),
    );
  }

  /// 按深度排序节点（远到近）
  List<VineNode> _sortByDepth(List<VineNode> nodes, Size size) {
    final withDepth = nodes.map((node) {
      final projected = viewport.project(size, node.position.layoutPosition);
      return (node, projected.depth);
    }).toList();

    withDepth.sort((a, b) => b.$2.compareTo(a.$2));
    return withDepth.map((e) => e.$1).toList();
  }

  /// 绘制时间轴（中心螺旋柱）
  void _drawTimeAxis(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制中心柱
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 简化的螺旋柱表示
    final path = Path();
    const radius = 30.0;
    const turns = 3;
    const pointsPerTurn = 20;

    for (var i = 0; i <= turns * pointsPerTurn; i++) {
      final t = i / pointsPerTurn;
      final angle = t * 2 * pi;
      final y = centerY - t * 100; // 向上延伸
      final x = centerX + cos(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// 绘制藤蔓段
  void _drawVineSegment(
    Canvas canvas,
    ProjectedPoint from,
    ProjectedPoint to,
    NodeType type,
  ) {
    final color = AppTheme.nodeColors[type.name] ?? Colors.blue;
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = _lerp(2, 4, from.scale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 贝塞尔曲线连接
    final path = Path();
    path.moveTo(from.x, from.y);

    // 控制点：使曲线自然弯曲
    final cp1 = Offset(
      from.x + (to.x - from.x) * 0.3,
      from.y + (to.y - from.y) * 0.1,
    );
    final cp2 = Offset(
      from.x + (to.x - from.x) * 0.7,
      from.y + (to.y - from.y) * 0.9,
    );

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.x, to.y);
    canvas.drawPath(path, paint);
  }

  /// 绘制节点
  void _drawNode(Canvas canvas, ProjectedPoint projected, VineNode node) {
    final baseSize = _getNodeSize(node);
    final size = baseSize * projected.scale;
    final color = participantColors[node.authorId] ?? Colors.blue;

    // 节点发光效果
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(projected.offset, size * 1.5, glowPaint);

    // 节点主体
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(projected.offset, size, nodePaint);

    // 节点边框
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2 * projected.scale
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(projected.offset, size, borderPaint);

    // 绘制状态指示器
    _drawStatusIndicator(canvas, projected, node.status, size);
  }

  /// 获取节点大小
  double _getNodeSize(VineNode node) {
    switch (node.geometry.type) {
      case GeometryType.voiceBlock:
        return 8 + (node.geometry.size ?? 1.0) * 4;
      case GeometryType.branchPoint:
        return 12;
      case GeometryType.mergeCrystal:
        return 14;
      case GeometryType.milestoneMonolith:
        return 18;
      case GeometryType.aiFlower:
        return 10;
    }
  }

  /// 绘制状态指示器
  void _drawStatusIndicator(
    Canvas canvas,
    ProjectedPoint projected,
    NodeStatus status,
    double nodeSize,
  ) {
    final color = switch (status) {
      NodeStatus.draft => Colors.grey,
      NodeStatus.committed => Colors.blue,
      NodeStatus.confirmed => Colors.green,
      NodeStatus.archived => Colors.grey.shade600,
    };

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final offset = Offset(
      projected.x + nodeSize * 0.7,
      projected.y - nodeSize * 0.7,
    );

    canvas.drawCircle(offset, nodeSize * 0.3, paint);
  }

  /// 绘制 AI 叶子
  void _drawLeaf(
    Canvas canvas,
    ProjectedPoint nodePos,
    LeafAttachment leaf,
    double animationValue,
  ) {
    final color = _getLeafColor(leaf.type);
    final radius = (12 + leaf.relevanceScore * 8) * nodePos.scale * animationValue;

    // 叶子位置：悬浮在节点上方
    final leafPos = Offset(nodePos.x, nodePos.y - 30 * nodePos.scale);

    // 连接线
    final linePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1 * nodePos.scale;
    canvas.drawLine(nodePos.offset, leafPos, linePaint);

    // 叶子发光
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(leafPos, radius * 1.3, glowPaint);

    // 叶子主体
    final leafPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(leafPos, radius, leafPaint);

    // 叶子图标
    final icon = _getLeafIcon(leaf.type);
    final textPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: max(6, 10 * nodePos.scale),
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      leafPos.translate(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  /// 获取叶子颜色
  Color _getLeafColor(LeafType type) {
    return switch (type) {
      LeafType.summary => AppTheme.leafColors['summary']!,
      LeafType.actionItems => AppTheme.leafColors['actionItems']!,
      LeafType.decision => AppTheme.leafColors['decision']!,
      LeafType.riskAlert => AppTheme.leafColors['riskAlert']!,
      LeafType.insight => AppTheme.leafColors['insight']!,
      LeafType.reference => AppTheme.leafColors['reference']!,
    };
  }

  /// 获取叶子图标
  String _getLeafIcon(LeafType type) {
    return switch (type) {
      LeafType.summary => '📝',
      LeafType.actionItems => '✓',
      LeafType.decision => '◆',
      LeafType.riskAlert => '!',
      LeafType.insight => '💡',
      LeafType.reference => '🔗',
    };
  }

  /// 绘制选中高亮
  void _drawSelectionHighlight(Canvas canvas, ProjectedPoint projected) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.5)
      ..strokeWidth = 3 * projected.scale
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(projected.offset, 20 * projected.scale, paint);
  }

  /// 绘制光束（争议解决游戏化效果）
  void _drawBeams(Canvas canvas, Size size) {
    if (beams.isEmpty) return;

    for (final beam in beams.values) {
      // 找到 Avatar 位置
      final avatar = avatars.where((a) => a.id == beam.fromAvatarId).firstOrNull;
      if (avatar == null) continue;

      // 投影起点和终点
      final fromProj = viewport.project(size, avatar.position);
      final toProj = viewport.project(size, beam.toNodeId == selectedNode?.id
          ? selectedNode!.position.layoutPosition
          : Offset3D(
              x: _getNodePosition(beam.toNodeId)[0],
              y: _getNodePosition(beam.toNodeId)[1],
              z: _getNodePosition(beam.toNodeId)[2],
            ));

      // 光束渐变
      final gradient = LinearGradient(
        colors: [
          beam.color.withOpacity(0.8),
          beam.color.withOpacity(0.3),
          Colors.white.withOpacity(0.5),
        ],
        stops: const [0.0, 0.7, 1.0],
      );

      // 绘制光束主体
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromPoints(fromProj.offset, toProj.offset))
        ..strokeWidth = beam.width * fromProj.scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // 主光束
      canvas.drawLine(fromProj.offset, toProj.offset, paint);

      // 绘制粒子
      for (final particle in beam.particles) {
        final particleProj = viewport.project(size, particle);
        final particlePaint = Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          particleProj.offset,
          2 * particleProj.scale,
          particlePaint,
        );
      }

      // 绘制光束发光效果
      final glowPaint = Paint()
        ..color = beam.color.withOpacity(0.2)
        ..strokeWidth = beam.width * 2 * fromProj.scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawLine(fromProj.offset, toProj.offset, glowPaint);
    }
  }

  /// 绘制争议状态指示器
  void _drawContentionIndicator(Canvas canvas, Size size, VineNode node) {
    if (contentions == null) return;
    
    final contention = contentions![node.id];
    if (contention == null) return;

    final projected = viewport.project(size, node.position.layoutPosition);
    
    // 根据状态选择颜色
    final color = contention.isResolved
        ? Colors.green
        : contention.isResolving
            ? Colors.orange
            : Colors.red;

    // 脉冲动画
    final pulse = contention.isResolving
        ? (DateTime.now().millisecond / 1000) * pi * 2
        : 0.0;
    final pulseScale = 1.0 + sin(pulse) * 0.1;

    // 争议光环
    final paint = Paint()
      ..color = color.withOpacity(0.3 + contention.resolutionProgress * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * projected.scale;

    // 外圈
    canvas.drawCircle(
      projected.offset,
      25 * projected.scale * pulseScale,
      paint,
    );

    // 进度环（如果正在解决）
    if (contention.isResolving) {
      final progressPaint = Paint()
        ..color = Colors.green.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * projected.scale
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: projected.offset, radius: 25 * projected.scale);
      canvas.drawArc(
        rect,
        -pi / 2,
        pi * 2 * contention.resolutionProgress,
        false,
        progressPaint,
      );

      // 显示协作者数量
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${contention.collaborators.length}',
          style: TextStyle(
            color: Colors.white,
            fontSize: max(8, 10 * projected.scale),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        projected.offset.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    }

    // 争议图标
    final icon = contention.isResolved ? '✓' : '!';
    final iconPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: max(8, 12 * projected.scale),
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      projected.offset.translate(20 * projected.scale, -20 * projected.scale),
    );
  }

  List<double> _getNodePosition(String nodeId) {
    final node = nodes.where((n) => n.id == nodeId).firstOrNull;
    if (node != null) {
      return [
        node.position.layoutPosition.x,
        node.position.layoutPosition.y,
        node.position.layoutPosition.z,
      ];
    }
    return [0, 0, 0];
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  bool shouldRepaint(covariant ChronoVinePainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.viewport != viewport ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.avatars != avatars ||
        oldDelegate.beams != beams ||
        oldDelegate.contentions != contentions ||
        oldDelegate.animation?.value != animation?.value;
  }
}
