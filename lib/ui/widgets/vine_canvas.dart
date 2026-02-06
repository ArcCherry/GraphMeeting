import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/space_time_axis.dart';
import '../../models/chrono_vine/leaf_attachment.dart';
import '../../state/viewport_provider.dart';
import '../painters/chrono_vine_painter.dart';
import 'leaf_detail_panel.dart';
import 'viewport_controls.dart';

/// 藤蔓画布
/// 
/// 核心交互组件：
/// - 手势控制 3D 视角（旋转/缩放/平移）
/// - 节点选择与高亮
/// - 叶子详情展示
/// - 动画系统
class VineCanvas extends StatefulWidget {
  final List<VineNode> nodes;
  final Map<String, Color> participantColors;
  final Function(VineNode)? onNodeSelected;
  final Function(VineNode)? onNodeLongPress;
  final VoidCallback? onBackgroundTap;

  const VineCanvas({
    super.key,
    required this.nodes,
    required this.participantColors,
    this.onNodeSelected,
    this.onNodeLongPress,
    this.onBackgroundTap,
  });

  @override
  State<VineCanvas> createState() => _VineCanvasState();
}

class _VineCanvasState extends State<VineCanvas>
    with TickerProviderStateMixin {
  late Viewport3D _viewport;
  VineNode? _selectedNode;
  LeafAttachment? _selectedLeaf;
  
  // 手势状态
  Offset? _lastPanPosition;
  double _lastScale = 1.0;
  
  // 动画控制器
  late AnimationController _leafAnimationController;
  late Animation<double> _leafAnimation;

  @override
  void initState() {
    super.initState();
    _viewport = Viewport3D();
    _viewport.addListener(_onViewportChanged);
    
    _leafAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _leafAnimation = CurvedAnimation(
      parent: _leafAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _viewport.removeListener(_onViewportChanged);
    _leafAnimationController.dispose();
    super.dispose();
  }

  void _onViewportChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 主画布
        GestureDetector(
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onLongPress: _handleLongPress,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              child: CustomPaint(
                size: Size.infinite,
                painter: ChronoVinePainter(
                  nodes: widget.nodes,
                  viewport: _viewport,
                  participantColors: widget.participantColors,
                  selectedNode: _selectedNode,
                  animation: _leafAnimation,
                ),
              ),
            ),
          ),
        ),
        
        // 视角控制按钮
        Positioned(
          right: 16,
          bottom: 100,
          child: ViewportControls(
            viewport: _viewport,
            onReset: () {
              _viewport.reset();
              setState(() {
                _selectedNode = null;
                _selectedLeaf = null;
              });
            },
          ),
        ),
        
        // 时间轴滑块
        Positioned(
          left: 16,
          right: 80,
          bottom: 16,
          child: _buildTimelineSlider(),
        ),
        
        // 叶子详情面板
        if (_selectedLeaf != null)
          LeafDetailPanel(
            leaf: _selectedLeaf!,
            node: _selectedNode!,
            onClose: () {
              setState(() {
                _selectedLeaf = null;
              });
            },
          ),
        
        // 选中节点信息浮层
        if (_selectedNode != null && _selectedLeaf == null)
          _buildNodeInfoOverlay(),
      ],
    );
  }

  /// 构建时间轴滑块
  Widget _buildTimelineSlider() {
    if (widget.nodes.isEmpty) return const SizedBox.shrink();
    
    final times = widget.nodes.map((n) => n.position.timestamp).toList();
    final startTime = times.reduce((a, b) => a.isBefore(b) ? a : b);
    final endTime = times.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDuration = endTime.difference(startTime);
    
    final currentOffset = _viewport.focusTime.difference(startTime);
    final value = totalDuration.inSeconds > 0 
      ? currentOffset.inSeconds / totalDuration.inSeconds 
      : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: (v) {
                  final newTime = startTime.add(
                    Duration(seconds: (v * totalDuration.inSeconds).round()),
                  );
                  _viewport.focusTo(newTime);
                },
              ),
            ),
          ),
          Text(
            '${currentOffset.inMinutes}m',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 构建节点信息浮层
  Widget _buildNodeInfoOverlay() {
    return Positioned(
      left: 16,
      top: 16,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.participantColors[_selectedNode!.authorId] ?? Colors.blue,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.participantColors[_selectedNode!.authorId],
                  child: Text(
                    _selectedNode!.authorId.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedNode!.authorId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedNode = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedNode!.contentPreview,
              style: const TextStyle(color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTypeChip(_selectedNode!.nodeType),
                if (_selectedNode!.leaves.isNotEmpty)
                  Chip(
                    label: Text(
                      '${_selectedNode!.leaves.length} 个叶子',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.green.withOpacity(0.3),
                  ),
              ],
            ),
            if (_selectedNode!.leaves.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '点击叶子查看详情:',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: _selectedNode!.leaves.map((leaf) {
                  return ActionChip(
                    avatar: Text(_getLeafIcon(leaf.type)),
                    label: Text(
                      leaf.title,
                      style: const TextStyle(fontSize: 10),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedLeaf = leaf;
                      });
                      _leafAnimationController.forward(from: 0);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建类型标签
  Widget _buildTypeChip(NodeType type) {
    final (label, color) = switch (type) {
      NodeType.message => ('消息', Colors.blue),
      NodeType.branch => ('分叉', Colors.orange),
      NodeType.merge => ('合并', Colors.green),
      NodeType.milestone => ('里程碑', Colors.purple),
      NodeType.aiSummary => ('AI总结', Colors.pink),
    };

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withOpacity(0.3),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
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

  // ==================== 手势处理 ====================

  void _handleTap() {
    // 检查是否点击了节点或叶子
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(
      (context as Element).findAncestorWidgetOfExactType<GestureDetector>() != null
          ? Offset.zero
          : Offset.zero,
    );
    
    // 简化实现：直接取消选择
    setState(() {
      _selectedNode = null;
      _selectedLeaf = null;
    });
    
    widget.onBackgroundTap?.call();
  }

  void _handleDoubleTap() {
    // 双击重置视角或聚焦
    if (_selectedNode != null) {
      _viewport.focusTo(_selectedNode!.position.timestamp);
    } else {
      _viewport.reset();
    }
  }

  void _handleLongPress() {
    if (_selectedNode != null) {
      widget.onNodeLongPress?.call(_selectedNode!);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _lastPanPosition = details.localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_lastPanPosition == null) return;

    final delta = details.localPosition - _lastPanPosition!;
    
    // 水平拖拽：旋转视角（环绕时间轴）
    // 垂直拖拽：平移时间轴
    if (delta.dx.abs() > delta.dy.abs()) {
      _viewport.rotate(delta.dx * 0.5);
    } else {
      // 垂直拖拽模拟时间平移
      final newTime = _viewport.focusTime.add(
        Duration(minutes: (-delta.dy * 0.5).round()),
      );
      _viewport.focusTo(newTime);
    }
    
    _lastPanPosition = details.localPosition;
  }

  void _handlePanEnd(DragEndDetails details) {
    _lastPanPosition = null;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _lastPanPosition = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // 处理缩放
    final scaleDelta = details.scale / _lastScale;
    if (scaleDelta != 1.0) {
      _viewport.zoomBy(scaleDelta);
      _lastScale = details.scale;
    }
    
    // 处理平移
    if (_lastPanPosition != null) {
      final delta = details.focalPoint - _lastPanPosition!;
      if (delta.dx.abs() > delta.dy.abs()) {
        _viewport.rotate(delta.dx * 0.5);
      } else {
        // 垂直平移模拟时间轴滚动
        final newTime = _viewport.focusTime.add(
          Duration(minutes: (-delta.dy * 0.5).round()),
        );
        _viewport.focusTo(newTime);
      }
      _lastPanPosition = details.focalPoint;
    }
  }
  
  void _handleScaleEnd(ScaleEndDetails details) {
    _lastPanPosition = null;
    _lastScale = 1.0;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // 滚轮缩放
      final scaleFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      _viewport.zoomBy(scaleFactor);
    }
  }
}
