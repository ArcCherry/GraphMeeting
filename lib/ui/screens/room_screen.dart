import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/space_time_axis.dart';
import '../../models/chrono_vine/leaf_attachment.dart';
import '../../services/avatar/avatar_service.dart';
import '../../services/game/contention_resolution.dart';
import '../../state/viewport_provider.dart';
import '../painters/chrono_vine_painter.dart';

/// 会议房间页面 - WinUI 3 / Fluent Design 风格
class RoomScreen extends StatefulWidget {
  final String roomId;

  const RoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with TickerProviderStateMixin {
  late final Viewport3D _viewport;
  late final AnimationController _animationController;
  late final AvatarService _avatarService;
  late final ContentionResolutionService _contentionService;

  late final List<VineNode> _nodes;
  late final Map<String, Color> _participantColors;

  VineNode? _selectedNode;
  Offset? _lastPanPosition;
  double _initialZoom = 1.0;
  
  bool _showSidebar = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _viewport = Viewport3D();
    _viewport.addListener(_onViewportChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _nodes = _generateMockNodes();
    _participantColors = _generateParticipantColors();
    
    _avatarService = AvatarService();
    _avatarService.addListener(_onViewportChanged);
    
    _contentionService = ContentionResolutionService(avatarService: _avatarService);
    _contentionService.addListener(_onViewportChanged);
    
    _initAvatars();
    _initDemo();
  }
  
  void _initAvatars() {
    _participantColors.forEach((id, color) {
      _avatarService.createAvatar(
        id, 
        'User ${id.toUpperCase()}', 
        color,
        vsync: this,
      );
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _avatarService.arrangeAvatarsInCircle();
    });
  }
  
  void _initDemo() async {
    await Future.delayed(const Duration(seconds: 2));
    
    final contentionNode = _nodes.firstWhere(
      (n) => n.nodeType == NodeType.message,
      orElse: () => _nodes.first,
    );
    
    _contentionService.createContention(
      contentionNode.id,
      Offset3D(
        x: contentionNode.position.layoutPosition.x,
        y: contentionNode.position.layoutPosition.y,
        z: contentionNode.position.layoutPosition.z,
      ),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    final avatarIds = _avatarService.avatars.take(2).map((a) => a.id).toList();
    if (avatarIds.length >= 2) {
      unawaited(_demoAvatarFly(avatarIds[0], contentionNode));
      await Future.delayed(const Duration(milliseconds: 300));
      unawaited(_demoAvatarFly(avatarIds[1], contentionNode));
    }
  }
  
  Future<void> _demoAvatarFly(String avatarId, VineNode node) async {
    final targetPos = Offset3D(
      x: node.position.layoutPosition.x + (Random().nextDouble() - 0.5) * 20,
      y: node.position.layoutPosition.y,
      z: node.position.layoutPosition.z + (Random().nextDouble() - 0.5) * 20,
    );
    
    await _avatarService.flyTo(avatarId, targetPos, duration: 1.5);
  }

  @override
  void dispose() {
    _viewport.removeListener(_onViewportChanged);
    _avatarService.removeListener(_onViewportChanged);
    _contentionService.removeListener(_onViewportChanged);
    _avatarService.dispose();
    _contentionService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onViewportChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      body: Row(
        children: [
          // 左侧导航面板
          if (_showSidebar) _buildLeftPane(),
          
          // 主内容区
          Expanded(
            child: Column(
              children: [
                // 顶部标题栏
                _buildTitleBar(),
                
                // 3D 画布
                Expanded(
                  child: Stack(
                    children: [
                      // 画布
                      _buildCanvas(),
                      
                      // 右侧控制面板
                      Positioned(
                        right: AppTheme.spaceLg,
                        top: AppTheme.spaceLg,
                        child: _buildControlPanel(),
                      ),
                      
                      // 底部输入栏
                      Positioned(
                        left: AppTheme.spaceLg,
                        right: AppTheme.spaceLg,
                        bottom: AppTheme.spaceLg,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPane() {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLayer,
        border: Border(
          right: BorderSide(color: AppTheme.borderPrimary),
        ),
      ),
      child: Column(
        children: [
          // 返回按钮和房间信息
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderPrimary),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text(
                    widget.roomId.toUpperCase(),
                    style: AppTheme.textBody.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          
          // 参与者列表
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参与者 (${_participantColors.length})', 
                  style: AppTheme.textLabel),
                const SizedBox(height: AppTheme.spaceMd),
                Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    for (var entry in _participantColors.entries)
                      _buildParticipantChip(entry.key, entry.value),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: AppTheme.borderPrimary),
          
          // 节点列表标题
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            alignment: Alignment.centerLeft,
            child: Text('节点列表', style: AppTheme.textLabel),
          ),
          
          // 节点列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
              itemCount: _nodes.length,
              itemBuilder: (context, index) {
                final node = _nodes[index];
                return _buildNodeListItem(node);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(String id, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            id.toUpperCase(),
            style: AppTheme.textCaption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeListItem(VineNode node) {
    final isSelected = _selectedNode?.id == node.id;
    final color = _participantColors[node.authorId] ?? AppTheme.accentPrimary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isSelected ? AppTheme.accentPrimary : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: 4,
        ),
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          node.contentPreview,
          style: AppTheme.textBody.copyWith(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          node.authorId.toUpperCase(),
          style: AppTheme.textCaption,
        ),
        onTap: () => setState(() => _selectedNode = node),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLayer,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderPrimary),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
      child: Row(
        children: [
          // 侧边栏切换
          IconButton(
            icon: Icon(
              _showSidebar ? Icons.view_sidebar_outlined : Icons.view_sidebar,
              size: 20,
            ),
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
          ),
          
          VerticalDivider(width: 24, color: AppTheme.borderPrimary),
          
          // 视角控制
          Text('视角', style: AppTheme.textLabel),
          const SizedBox(width: AppTheme.spaceMd),
          _buildViewButton(Icons.rotate_left, () => _viewport.rotate(-15)),
          _buildViewButton(Icons.rotate_right, () => _viewport.rotate(15)),
          _buildViewButton(Icons.zoom_in, () => _viewport.zoomIn()),
          _buildViewButton(Icons.zoom_out, () => _viewport.zoomOut()),
          
          const Spacer(),
          
          // 更多选项
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更多选项开发中...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: AppTheme.textSecondary,
      onPressed: onTap,
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onTapUp: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_animationController, _avatarService]),
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: ChronoVinePainter(
              nodes: _nodes,
              viewport: _viewport,
              participantColors: _participantColors,
              selectedNode: _selectedNode,
              animation: _animationController,
              avatars: _avatarService.avatars,
              beams: _contentionService.beams,
              contentions: {for (var c in _contentionService.activeContentions) c.nodeId: c},
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 工具按钮
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLayer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.fromBorderSide(
              BorderSide(color: AppTheme.borderPrimary),
            ),
          ),
          child: Column(
            children: [
              _buildToolButton(Icons.layers_outlined, true),
              Divider(height: 16, color: AppTheme.borderPrimary),
              _buildToolButton(Icons.view_in_ar, false),
              _buildToolButton(Icons.filter_list, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton(IconData icon, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isActive ? AppTheme.accentPrimary : AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLayer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.fromBorderSide(
          BorderSide(color: AppTheme.borderPrimary),
        ),
      ),
      child: Row(
        children: [
          // 录制按钮
          GestureDetector(
            onTapDown: (_) => setState(() => _isRecording = true),
            onTapUp: (_) => setState(() => _isRecording = false),
            onTapCancel: () => setState(() => _isRecording = false),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isRecording ? AppTheme.error : AppTheme.accentPrimary,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(width: AppTheme.spaceMd),
          
          // 输入框
          Expanded(
            child: TextField(
              style: AppTheme.textBody,
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: AppTheme.textBody.copyWith(
                  color: AppTheme.textTertiary,
                ),
                filled: true,
                fillColor: AppTheme.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                  vertical: AppTheme.spaceMd,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: AppTheme.spaceMd),
          
          // 发送按钮
          IconButton(
            icon: const Icon(Icons.send),
            color: AppTheme.accentPrimary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('消息发送功能开发中...')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.localFocalPoint;
    _initialZoom = _viewport.zoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      _viewport.setZoom(_initialZoom * details.scale);
    }

    if (_lastPanPosition != null && details.focalPointDelta != Offset.zero) {
      final delta = details.focalPointDelta;
      _viewport.rotate(delta.dx * 0.5);
      _viewport.tilt(-delta.dy * 0.5);
    }
    _lastPanPosition = details.localFocalPoint;
  }

  void _handleTap(TapUpDetails details) {
    setState(() => _selectedNode = null);
  }

  List<VineNode> _generateMockNodes() {
    final nodes = <VineNode>[];
    final participants = ['user_a', 'user_b', 'user_c'];
    final now = DateTime.now();

    for (var i = 0; i < 15; i++) {
      final participantId = participants[i % participants.length];
      final spaceTimePoint = SpaceTimePoint.computeSpiralPositionStatic(
        timestamp: now.subtract(Duration(minutes: (15 - i) * 5)),
        participantId: participantId,
        laneIndex: participants.indexOf(participantId),
        totalLanes: participants.length,
        timeScale: 0.5,
        radius: 50.0,
      );

      final node = VineNode(
        id: 'node_$i',
        messageId: 'msg_$i',
        position: spaceTimePoint,
        content: '消息内容 $i',
        contentPreview: '这是第 $i 条消息的内容预览...',
        nodeType: i % 5 == 0
            ? NodeType.milestone
            : (i % 3 == 0 ? NodeType.branch : NodeType.message),
        status: NodeStatus.committed,
        parentId: i > 0 ? 'node_${i - 1}' : null,
        authorId: participantId,
        createdAt: now.subtract(Duration(minutes: (15 - i) * 5)),
        leaves: i % 4 == 0
            ? [
                LeafAttachment.summary(
                  'node_$i',
                  '这是节点 $i 的 AI 总结内容',
                ),
              ]
            : [],
      );

      nodes.add(node);
    }

    return nodes;
  }

  Map<String, Color> _generateParticipantColors() {
    return {
      'user_a': AppTheme.accentPrimary,
      'user_b': const Color(0xFF0F7B0F),
      'user_c': const Color(0xFF744DA9),
    };
  }
}
