/// 高级3D藤蔓绘制器
/// 
/// 提供真实的3D渲染效果：光照、阴影、粒子、发光

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../services/vine_3d/vine_3d_engine.dart';

/// 高级藤蔓绘制器
class AdvancedVinePainter extends CustomPainter {
  final Vine3DEngine engine;
  final List<Node3D> nodes;
  final List<Connection3D> connections;
  final List<AvatarFlight> avatars;
  final ParticleSystem particles;
  final double animationValue;
  final String? selectedNodeId;
  final double timeAxisProgress;
  
  AdvancedVinePainter({
    required this.engine,
    required this.nodes,
    required this.connections,
    required this.avatars,
    required this.particles,
    required this.animationValue,
    this.selectedNodeId,
    this.timeAxisProgress = 1.0,
  }) : super(repaint: null);
  
  @override
  void paint(Canvas canvas, Size size) {
    // 更新摄像机
    engine.updateCamera();
    
    // 按深度排序节点
    final sortedNodes = engine.sortByDepth(nodes, (n) => n.position);
    
    // 1. 绘制背景效果
    _drawBackground(canvas, size);
    
    // 2. 绘制时间轴
    _drawTimeAxis(canvas, size);
    
    // 3. 绘制连接线（远到近）
    _drawConnections(canvas, size, sortedNodes);
    
    // 4. 绘制拖尾
    _drawAvatarTrails(canvas, size);
    
    // 5. 绘制节点
    for (final node in sortedNodes) {
      _drawNode(canvas, size, node);
    }
    
    // 6. 绘制Avatar
    for (final avatar in avatars) {
      _drawAvatar(canvas, size, avatar);
    }
    
    // 7. 绘制粒子
    _drawParticles(canvas, size);
    
    // 8. 绘制前景效果
    _drawForegroundEffects(canvas, size);
  }
  
  /// 绘制背景
  void _drawBackground(Canvas canvas, Size size) {
    // 径向渐变背景
    final gradient = RadialGradient(
      center: const Alignment(0, -0.5),
      radius: 1.5,
      colors: [
        AppTheme.accentPrimary.withAlpha(20),
        AppTheme.darkBackgroundBase,
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // 网格线
    _drawPerspectiveGrid(canvas, size);
  }
  
  /// 绘制透视网格
  void _drawPerspectiveGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.darkBorderPrimary.withAlpha(30)
      ..strokeWidth = 1;
    
    // 水平线（透视）
    for (int i = 0; i < 10; i++) {
      final y = size.height * (0.5 + i * 0.1);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  /// 绘制3D时间轴
  void _drawTimeAxis(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final segments = 20;
    
    for (int i = 0; i < segments; i++) {
      if (i / segments > timeAxisProgress) break;
      
      final t1 = i / segments;
      final t2 = (i + 1) / segments;
      
      final y1 = size.height * (1 - t1 * 0.8);
      final y2 = size.height * (1 - t2 * 0.8);
      
      // 3D柱体效果
      final gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppTheme.accentPrimary.withAlpha(50),
          AppTheme.accentPrimary.withAlpha(150),
          AppTheme.accentPrimary.withAlpha(50),
        ],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(centerX - 20, y2, 40, y1 - y2),
        )
        ..style = PaintingStyle.fill;
      
      final path = Path();
      path.moveTo(centerX - 15, y1);
      path.lineTo(centerX + 15, y1);
      path.lineTo(centerX + 10, y2);
      path.lineTo(centerX - 10, y2);
      path.close();
      
      canvas.drawPath(path, paint);
      
      // 高光边
      final highlightPaint = Paint()
        ..color = AppTheme.accentPrimary.withAlpha(100)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(centerX - 15, y1),
        Offset(centerX - 10, y2),
        highlightPaint,
      );
    }
  }
  
  /// 绘制连接线
  void _drawConnections(Canvas canvas, Size size, List<Node3D> sortedNodes) {
    final nodeMap = {for (final n in nodes) n.id: n};
    
    for (final conn in connections) {
      final fromNode = nodeMap[conn.fromId];
      final toNode = nodeMap[conn.toId];
      if (fromNode == null || toNode == null) continue;
      
      final proj1 = engine.project(fromNode.position, size);
      final proj2 = engine.project(toNode.position, size);
      
      if (!proj1.isVisible || !proj2.isVisible) continue;
      
      // 根据连接类型选择颜色
      Color color;
      switch (conn.type) {
        case ConnectionType.branch:
          color = AppTheme.warning;
          break;
        case ConnectionType.merge:
          color = AppTheme.success;
          break;
        case ConnectionType.reference:
          color = AppTheme.accentSecondary;
          break;
        default:
          color = AppTheme.darkTextTertiary;
      }
      
      // 贝塞尔曲线
      final path = Path();
      path.moveTo(proj1.position.dx, proj1.position.dy);
      
      final midY = (proj1.position.dy + proj2.position.dy) / 2;
      path.cubicTo(
        proj1.position.dx, midY,
        proj2.position.dx, midY,
        proj2.position.dx, proj2.position.dy,
      );
      
      // 发光效果
      final glowPaint = Paint()
        ..color = color.withAlpha(100)
        ..strokeWidth = 4 * proj1.scale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(path, glowPaint);
      
      // 主线
      final paint = Paint()
        ..color = color.withAlpha(200)
        ..strokeWidth = 2 * proj1.scale
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(path, paint);
      
      // 流动动画
      if (conn.progress < 1.0) {
        final animOffset = (animationValue * 20) % 20;
        final dashPaint = Paint()
          ..color = Colors.white.withAlpha(150)
          ..strokeWidth = 2 * proj1.scale
          ..style = PaintingStyle.stroke;
        
        // 简化的流动效果
        final flowPath = Path();
        final t = animationValue;
        final fx = proj1.position.dx + (proj2.position.dx - proj1.position.dx) * t;
        final fy = proj1.position.dy + (proj2.position.dy - proj1.position.dy) * t;
        flowPath.addOval(Rect.fromCircle(center: Offset(fx, fy), radius: 4 * proj1.scale));
        canvas.drawPath(flowPath, dashPaint);
      }
    }
  }
  
  /// 绘制Avatar拖尾
  void _drawAvatarTrails(Canvas canvas, Size size) {
    for (final avatar in avatars) {
      if (avatar.trail.length < 2) continue;
      
      for (int i = 0; i < avatar.trail.length - 1; i++) {
        final proj1 = engine.project(avatar.trail[i], size);
        final proj2 = engine.project(avatar.trail[i + 1], size);
        
        if (!proj1.isVisible || !proj2.isVisible) continue;
        
        final alpha = (i / avatar.trail.length * 150).toInt();
        final width = (i / avatar.trail.length * 6 * proj1.scale).clamp(1.0, 10.0);
        
        final paint = Paint()
          ..color = avatar.color.withAlpha(alpha)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round;
        
        canvas.drawLine(proj1.position, proj2.position, paint);
      }
    }
  }
  
  /// 绘制3D节点
  void _drawNode(Canvas canvas, Size size, Node3D node) {
    final projected = engine.project(node.position, size);
    if (!projected.isVisible) return;
    
    final x = projected.position.dx;
    final y = projected.position.dy;
    final scale = projected.scale;
    final nodeSize = node.size * scale * node.animation.growProgress;
    
    // 计算光照
    final normal = Vector3(0, 0, 1);
    final lighting = engine.calculateLighting(node.position, normal);
    
    // 选中状态发光
    if (node.animation.isSelected || node.id == selectedNodeId) {
      final selectGlow = Paint()
        ..color = AppTheme.accentPrimary.withAlpha(150)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset(x, y), nodeSize * 1.5, selectGlow);
    }
    
    // 脉冲效果
    if (node.type == NodeType3D.consensus || node.type == NodeType3D.contention) {
      final pulse = math.sin(animationValue * math.pi * 2 + node.animation.pulsePhase) * 0.5 + 0.5;
      final pulsePaint = Paint()
        ..color = node.color.withAlpha((100 * pulse).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * pulse);
      canvas.drawCircle(Offset(x, y), nodeSize * (1.5 + pulse * 0.5), pulsePaint);
    }
    
    // 悬浮效果
    final hoverY = y + math.sin(animationValue * math.pi * 2) * 3 * scale;
    
    // 阴影
    _drawNodeShadow(canvas, x, y + nodeSize * 0.5, nodeSize * 0.8, scale);
    
    // 3D球体效果
    _draw3DSphere(
      canvas,
      Offset(x, hoverY),
      nodeSize,
      node.color,
      lighting,
    );
    
    // 类型特定效果
    switch (node.type) {
      case NodeType3D.consensus:
        _drawConsensusEffect(canvas, x, hoverY, nodeSize, scale);
        break;
      case NodeType3D.contention:
        _drawContentionEffect(canvas, x, hoverY, nodeSize, scale);
        break;
      case NodeType3D.aiLeaf:
        _drawAILeafEffect(canvas, x, hoverY, nodeSize, scale, node.color);
        break;
      case NodeType3D.milestone:
        _drawMilestoneEffect(canvas, x, hoverY, nodeSize, scale);
        break;
      default:
        break;
    }
    
    // 标签
    if (node.label != null && scale > 0.5) {
      _drawNodeLabel(canvas, x, hoverY - nodeSize - 10 * scale, node.label!, scale);
    }
  }
  
  /// 绘制节点阴影
  void _drawNodeShadow(Canvas canvas, double x, double y, double size, double scale) {
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.5);
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: size * 2, height: size * 0.6),
      shadowPaint,
    );
  }
  
  /// 绘制3D球体
  void _draw3DSphere(Canvas canvas, Offset center, double radius, Color color, double lighting) {
    // 基础球体渐变
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: [
        _lightenColor(color, 0.4 * lighting),
        color,
        _darkenColor(color, 0.3),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    
    canvas.drawCircle(center, radius, paint);
    
    // 高光反射
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha((80 * lighting).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.25,
      highlightPaint,
    );
    
    // 边缘光
    final rimPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, rimPaint);
  }
  
  /// 绘制共识效果（水晶多面体）
  void _drawConsensusEffect(Canvas canvas, double x, double y, double size, double scale) {
    final path = Path();
    final points = 6;
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final radius = i % 2 == 0 ? size * 1.3 : size * 0.8;
      final px = x + math.cos(angle) * radius;
      final py = y + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    
    // 水晶发光
    final glowPaint = Paint()
      ..color = AppTheme.success.withAlpha(100)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawPath(path, glowPaint);
    
    // 水晶本体
    final crystalPaint = Paint()
      ..color = AppTheme.success.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    
    canvas.drawPath(path, crystalPaint);
    
    // 内部填充
    final fillPaint = Paint()
      ..color = AppTheme.success.withAlpha(30)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);
  }
  
  /// 绘制争议效果（荆棘/碎石）
  void _drawContentionEffect(Canvas canvas, double x, double y, double size, double scale) {
    final random = math.Random(42); // 固定种子保持一致
    
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + random.nextDouble() * 0.5;
      final length = size * (0.8 + random.nextDouble() * 0.6);
      
      final path = Path();
      path.moveTo(x, y);
      path.lineTo(
        x + math.cos(angle) * length,
        y + math.sin(angle) * length,
      );
      
      final paint = Paint()
        ..color = AppTheme.error.withAlpha(150 + random.nextInt(100))
        ..strokeWidth = (2 + random.nextDouble() * 2) * scale
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(path, paint);
    }
    
    // 红色脉冲核心
    final pulse = math.sin(animationValue * math.pi * 4) * 0.5 + 0.5;
    final corePaint = Paint()
      ..color = AppTheme.error.withAlpha((200 + 55 * pulse).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(Offset(x, y), size * 0.5, corePaint);
  }
  
  /// 绘制AI叶子效果
  void _drawAILeafEffect(Canvas canvas, double x, double y, double size, double scale, Color color) {
    // 叶子形状
    final path = Path();
    final w = size * 1.5;
    final h = size * 2;
    
    path.moveTo(x, y - h);
    path.quadraticBezierTo(x + w, y - h * 0.5, x + w * 0.5, y + h * 0.5);
    path.quadraticBezierTo(x, y + h * 0.8, x - w * 0.5, y + h * 0.5);
    path.quadraticBezierTo(x - w, y - h * 0.5, x, y - h);
    path.close();
    
    // 发光
    final glowPaint = Paint()
      ..color = color.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawPath(path, glowPaint);
    
    // 渐变填充
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withAlpha(100),
        color.withAlpha(40),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCenter(center: Offset(x, y), width: w * 2, height: h * 2),
      );
    
    canvas.drawPath(path, paint);
    
    // 叶脉
    final veinPaint = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = 2 * scale;
    
    canvas.drawLine(Offset(x, y - h * 0.8), Offset(x, y + h * 0.5), veinPaint);
  }
  
  /// 绘制里程碑效果
  void _drawMilestoneEffect(Canvas canvas, double x, double y, double size, double scale) {
    // 星形
    final path = Path();
    final points = 5;
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final radius = i % 2 == 0 ? size * 1.4 : size * 0.6;
      final px = x + math.cos(angle) * radius;
      final py = y + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    
    // 金色发光
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withAlpha(150)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawPath(path, glowPaint);
    
    // 星形本体
    final starPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, starPaint);
  }
  
  /// 绘制节点标签
  void _drawNodeLabel(Canvas canvas, double x, double y, String label, double scale) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppTheme.darkTextPrimary,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: Colors.black.withAlpha(150),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // 背景
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y),
        width: textPainter.width + 16 * scale,
        height: textPainter.height + 8 * scale,
      ),
      Radius.circular(8 * scale),
    );
    
    final bgPaint = Paint()
      ..color = AppTheme.darkBackgroundLayer.withAlpha(200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawRRect(bgRect, bgPaint);
    
    // 文字
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }
  
  /// 绘制Avatar
  void _drawAvatar(Canvas canvas, Size size, AvatarFlight avatar) {
    final projected = engine.project(avatar.position, size);
    if (!projected.isVisible) return;
    
    final x = projected.position.dx;
    final y = projected.position.dy;
    final scale = projected.scale;
    final avatarSize = 24 * scale;
    
    // 悬浮动画
    final hoverY = y + math.sin(animationValue * math.pi * 2 + avatar.position.x) * 5;
    
    // 能量环
    final energyPaint = Paint()
      ..color = avatar.color.withAlpha((150 * avatar.energy).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    
    canvas.drawCircle(
      Offset(x, hoverY),
      avatarSize * 1.3 + math.sin(animationValue * math.pi * 3) * 3,
      energyPaint,
    );
    
    // Avatar主体
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: [
        _lightenColor(avatar.color, 0.3),
        avatar.color,
        _darkenColor(avatar.color, 0.3),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, hoverY), radius: avatarSize),
      );
    
    canvas.drawCircle(Offset(x, hoverY), avatarSize, paint);
    
    // 状态指示器
    Color stateColor;
    switch (avatar.state) {
      case AvatarState.flying:
        stateColor = Colors.white;
        break;
      case AvatarState.working:
        stateColor = AppTheme.warning;
        break;
      default:
        stateColor = AppTheme.success;
    }
    
    final statePaint = Paint()
      ..color = stateColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(x + avatarSize * 0.7, hoverY - avatarSize * 0.7),
      6 * scale,
      statePaint,
    );
    
    // 名字标签
    final textPainter = TextPainter(
      text: TextSpan(
        text: avatar.userName,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withAlpha(200),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, hoverY + avatarSize + 8 * scale),
    );
  }
  
  /// 绘制粒子
  void _drawParticles(Canvas canvas, Size size) {
    for (final particle in particles.particles) {
      final projected = engine.project(particle.position, size);
      if (!projected.isVisible) continue;
      
      final paint = Paint()
        ..color = particle.color.withAlpha((255 * particle.life).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 0.5);
      
      canvas.drawCircle(
        projected.position,
        particle.size * projected.scale,
        paint,
      );
    }
  }
  
  /// 绘制前景效果
  void _drawForegroundEffects(Canvas canvas, Size size) {
    // 晕影效果
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: [
        Colors.transparent,
        Colors.black.withAlpha(80),
      ],
      stops: const [0.7, 1.0],
    );
    
    final paint = Paint()
      ..shader = vignette.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..blendMode = BlendMode.multiply;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }
  
  /// 颜色变亮
  Color _lightenColor(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount.clamp(0.0, 1.0))!;
  }
  
  /// 颜色变暗
  Color _darkenColor(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount.clamp(0.0, 1.0))!;
  }
  
  @override
  bool shouldRepaint(covariant AdvancedVinePainter oldDelegate) {
    return true; // 始终重绘以实现动画
  }
}
