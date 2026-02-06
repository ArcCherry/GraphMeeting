/// 响应式布局系统
/// 
/// 统一适配手机、平板、桌面三种设备的交互模式
/// 使用折叠面板（Collapsible Panels）实现多端一致的交互体验

import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// 设备类型
enum DeviceType {
  mobile,   // < 600px
  tablet,   // 600px - 1200px
  desktop,  // > 1200px
}

/// 响应式布局构建器
class ResponsiveLayout extends StatelessWidget {
  /// 手机布局
  final Widget mobile;
  
  /// 平板布局（可选，默认使用桌面布局）
  final Widget? tablet;
  
  /// 桌面布局
  final Widget desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = getDeviceType(constraints.maxWidth);
        
        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? desktop;
          case DeviceType.desktop:
            return desktop;
        }
      },
    );
  }
  
  /// 根据宽度获取设备类型
  static DeviceType getDeviceType(double width) {
    if (width < AppTheme.breakpointMobile) {
      return DeviceType.mobile;
    } else if (width < AppTheme.breakpointDesktop) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// 当前是否为手机
  static bool isMobile(BuildContext context) {
    return getDeviceType(MediaQuery.of(context).size.width) == DeviceType.mobile;
  }
  
  /// 当前是否为平板
  static bool isTablet(BuildContext context) {
    return getDeviceType(MediaQuery.of(context).size.width) == DeviceType.tablet;
  }
  
  /// 当前是否为桌面
  static bool isDesktop(BuildContext context) {
    return getDeviceType(MediaQuery.of(context).size.width) == DeviceType.desktop;
  }
}

/// 折叠面板布局
/// 
/// 核心交互组件，适配所有设备：
/// - 手机：底部滑出面板（BottomSheet）
/// - 平板/桌面：侧边可折叠面板（Collapsible Side Panel）
class CollapsiblePanel extends StatefulWidget {
  /// 主内容区
  final Widget content;
  
  /// 面板内容
  final Widget panel;
  
  /// 面板标题
  final String? panelTitle;
  
  /// 是否默认展开（仅平板/桌面）
  final bool initiallyExpanded;
  
  /// 面板宽度（平板/桌面）
  final double panelWidth;
  
  /// 面板位置
  final PanelPosition panelPosition;
  
  /// 展开/折叠回调
  final ValueChanged<bool>? onToggle;
  
  const CollapsiblePanel({
    super.key,
    required this.content,
    required this.panel,
    this.panelTitle,
    this.initiallyExpanded = true,
    this.panelWidth = 320,
    this.panelPosition = PanelPosition.right,
    this.onToggle,
  });

  @override
  State<CollapsiblePanel> createState() => _CollapsiblePanelState();
}

enum PanelPosition { left, right }

class _CollapsiblePanelState extends State<CollapsiblePanel> {
  late bool _isExpanded;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }
  
  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onToggle?.call(_isExpanded);
  }
  
  void _openPanelMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBackgroundLayer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Column(
              children: [
                // 拖拽手柄
                Container(
                  margin: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题栏
                if (widget.panelTitle != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceSm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          widget.panelTitle!,
                          style: AppTheme.textHeading3.copyWith(
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                // 面板内容
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget.panel,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      // 手机：底部按钮触发面板
      mobile: Stack(
        children: [
          widget.content,
          Positioned(
            right: AppTheme.spaceLg,
            bottom: AppTheme.spaceLg,
            child: FloatingActionButton(
              onPressed: _openPanelMobile,
              backgroundColor: AppTheme.accentPrimary,
              child: const Icon(Icons.view_sidebar),
            ),
          ),
        ],
      ),
      // 平板/桌面：侧边可折叠面板
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
  
  Widget _buildDesktopLayout() {
    final panelWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isExpanded ? widget.panelWidth : 48,
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer,
        border: Border(
          left: widget.panelPosition == PanelPosition.right
              ? BorderSide(color: AppTheme.darkBorderPrimary)
              : BorderSide.none,
          right: widget.panelPosition == PanelPosition.left
              ? BorderSide(color: AppTheme.darkBorderPrimary)
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // 折叠/展开按钮
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  _isExpanded
                      ? (widget.panelPosition == PanelPosition.right
                          ? Icons.chevron_right
                          : Icons.chevron_left)
                      : (widget.panelPosition == PanelPosition.right
                          ? Icons.chevron_left
                          : Icons.chevron_right),
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
          ),
          // 面板内容
          if (_isExpanded)
            Expanded(
              child: Column(
                children: [
                  if (widget.panelTitle != null)
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Text(
                        widget.panelTitle!,
                        style: AppTheme.textHeading3.copyWith(
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: widget.panel,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    
    return Row(
      children: widget.panelPosition == PanelPosition.left
          ? [panelWidget, Expanded(child: widget.content)]
          : [Expanded(child: widget.content), panelWidget],
    );
  }
}

/// 自适应列表/网格切换
/// 
/// 根据屏幕宽度自动切换列表和网格视图
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double itemWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;
  
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.itemWidth = 280,
    this.spacing = AppTheme.spaceLg,
    this.padding = const EdgeInsets.all(AppTheme.spaceLg),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        final crossAxisCount = (width / (itemWidth + spacing)).floor().clamp(1, 6);
        
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// 响应式间距
/// 
/// 根据设备类型返回不同的间距值
class ResponsiveSpacing {
  final double mobile;
  final double tablet;
  final double desktop;
  
  const ResponsiveSpacing({
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });
  
  double get(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}
