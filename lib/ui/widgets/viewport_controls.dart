import 'package:flutter/material.dart';
import '../../state/viewport_provider.dart';

/// 视角控制按钮组
/// 
/// 提供常用的视角操作：
/// - 重置视角
/// - 缩放控制
/// - 模式切换（自由/跟随/回放）
/// - 视角预设
class ViewportControls extends StatelessWidget {
  final Viewport3D viewport;
  final VoidCallback? onReset;

  const ViewportControls({
    super.key,
    required this.viewport,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 模式选择
          _buildModeSelector(),
          
          const Divider(color: Colors.white24, height: 16),
          
          // 缩放控制
          _buildZoomControls(),
          
          const Divider(color: Colors.white24, height: 16),
          
          // 视角预设
          _buildPresetButtons(),
          
          const Divider(color: Colors.white24, height: 16),
          
          // 重置按钮
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '重置视角',
            onPressed: onReset,
          ),
        ],
      ),
    );
  }

  /// 构建模式选择器
  Widget _buildModeSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildModeButton(
          icon: Icons.pan_tool,
          label: '自由',
          mode: ViewMode.free,
        ),
        const SizedBox(height: 4),
        _buildModeButton(
          icon: Icons.follow_the_signs,
          label: '跟随',
          mode: ViewMode.follow,
        ),
        const SizedBox(height: 4),
        _buildModeButton(
          icon: Icons.play_circle,
          label: '回放',
          mode: ViewMode.replay,
        ),
      ],
    );
  }

  /// 构建模式按钮
  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required ViewMode mode,
  }) {
    final isActive = viewport.mode == mode;
    
    return Material(
      color: isActive ? Colors.blue.withOpacity(0.5) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => viewport.setMode(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建缩放控制
  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          tooltip: '放大',
          onPressed: () => viewport.zoomBy(1.2),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '${(viewport.zoom * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.white),
          tooltip: '缩小',
          onPressed: () => viewport.zoomBy(0.8),
        ),
      ],
    );
  }

  /// 构建视角预设按钮
  Widget _buildPresetButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPresetButton(
          icon: Icons.view_column,
          tooltip: '正面视图',
          onPressed: () {
            viewport
              ..rotate(-viewport.rotationY)
              ..tilt(-30 - viewport.rotationX);
          },
        ),
        const SizedBox(height: 4),
        _buildPresetButton(
          icon: Icons.view_sidebar,
          tooltip: '侧面视图',
          onPressed: () {
            viewport
              ..rotate(90 - viewport.rotationY)
              ..tilt(-30 - viewport.rotationX);
          },
        ),
        const SizedBox(height: 4),
        _buildPresetButton(
          icon: Icons.view_module,
          tooltip: '鸟瞰视图',
          onPressed: () {
            viewport.tilt(-80 - viewport.rotationX);
          },
        ),
      ],
    );
  }

  /// 构建预设按钮
  Widget _buildPresetButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}

/// 简洁版视角控制（用于小屏幕）
class ViewportControlsCompact extends StatelessWidget {
  final Viewport3D viewport;
  final VoidCallback? onReset;

  const ViewportControlsCompact({
    super.key,
    required this.viewport,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ViewMode>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: Colors.black.withOpacity(0.8),
      onSelected: (mode) => viewport.setMode(mode),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ViewMode.free,
          child: _buildMenuItem(Icons.pan_tool, '自由探索'),
        ),
        PopupMenuItem(
          value: ViewMode.follow,
          child: _buildMenuItem(Icons.follow_the_signs, '跟随模式'),
        ),
        PopupMenuItem(
          value: ViewMode.replay,
          child: _buildMenuItem(Icons.play_circle, '回放模式'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: onReset,
          child: _buildMenuItem(Icons.refresh, '重置视角'),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
