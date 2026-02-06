import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../services/audio/voice_pipeline.dart';
import 'room_screen.dart';

/// 主页 - WinUI 3 / Fluent Design 风格
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  
  final List<RoomCardData> _recentRooms = [
    RoomCardData(
      id: 'room_alpha',
      name: '产品设计评审',
      participants: 5,
      lastActive: '2小时前',
      accentColor: AppTheme.accentPrimary,
    ),
    RoomCardData(
      id: 'room_beta',
      name: '技术架构讨论',
      participants: 3,
      lastActive: '昨天',
      accentColor: const Color(0xFF744DA9),
    ),
    RoomCardData(
      id: 'room_gamma',
      name: '季度规划会议',
      participants: 8,
      lastActive: '3天前',
      accentColor: const Color(0xFF0F7B0F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      body: Row(
        children: [
          // 左侧导航栏
          _buildNavigationPane(),
          
          // 主内容区
          Expanded(
            child: Column(
              children: [
                // 顶部标题栏
                _buildTitleBar(),
                
                // 内容区
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.space2xl),
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(),
                          
                          const SizedBox(height: AppTheme.space2xl),
                          
                          // 最近房间
                          _buildSectionTitle('最近访问'),
                          const SizedBox(height: AppTheme.spaceLg),
                          _buildRoomList(),
                          
                          const SizedBox(height: AppTheme.space2xl),
                          
                          // 快速操作
                          _buildSectionTitle('快速操作'),
                          const SizedBox(height: AppTheme.spaceLg),
                          _buildQuickActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationPane() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLayer,
        border: Border(
          right: BorderSide(color: AppTheme.borderPrimary),
        ),
      ),
      child: Column(
        children: [
          // Logo 区域
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: Colors.white,
                    size: 18,
                    
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Text(
                  'GraphMeeting',
                  style: AppTheme.textHeading3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: AppTheme.borderPrimary),
          
          // 导航项
          _buildNavItem(
            icon: Icons.home_outlined,
            label: '主页',
            isSelected: true,
          ),
          _buildNavItem(
            icon: Icons.meeting_room_outlined,
            label: '我的房间',
          ),
          _buildNavItem(
            icon: Icons.mic_outlined,
            label: '录音管理',
          ),
          _buildNavItem(
            icon: Icons.analytics_outlined,
            label: '分析报告',
          ),
          
          Spacer(),
          
          Divider(height: 1, color: AppTheme.borderPrimary),
          
          _buildNavItem(
            icon: Icons.settings_outlined,
            label: '设置',
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: isSelected 
            ? Border.all(color: AppTheme.accentPrimary, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
              ? AppTheme.accentPrimary 
              : AppTheme.textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: AppTheme.textBody.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected 
                ? AppTheme.accentPrimary 
                : AppTheme.textPrimary,
          ),
        ),
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
        dense: true,
        onTap: () {
          // 导航项点击处理
          if (isSelected) return;
          
          // 显示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label 功能开发中'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
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
          Text(
            '主页',
            style: AppTheme.textHeading3,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.backgroundLayer,
                  title: const Text('通知'),
                  content: const Text('暂无新通知'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Icon(
              Icons.person,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return FluentCard(
      padding: const EdgeInsets.all(AppTheme.space2xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              '异步协作空间',
              style: AppTheme.textLabel.copyWith(
                color: AppTheme.accentPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spaceLg),
          
          // 主标题
          Text(
            '思维建筑工地',
            style: AppTheme.textDisplay,
          ),
          
          const SizedBox(height: AppTheme.spaceSm),
          
          // 副标题
          Text(
            '像工蜂一样协作，建造认知宫殿',
            style: AppTheme.textBodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: AppTheme.spaceXl),
          
          // CTA 按钮
          Row(
            children: [
              FluentButton(
                style: FluentButtonStyle.accent,
                onPressed: _createRoom,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: AppTheme.spaceSm),
                    Text('创建新房间'),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              FluentButton(
                style: FluentButtonStyle.standard,
                onPressed: _showJoinDialog,
                child: const Text('加入房间'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.textHeading2,
    );
  }

  Widget _buildRoomList() {
    return Column(
      children: [
        for (var i = 0; i < _recentRooms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: _buildRoomCard(_recentRooms[i]),
          ),
      ],
    );
  }

  Widget _buildRoomCard(RoomCardData room) {
    return FluentCard(
      onTap: () => _enterRoom(room.id),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Row(
          children: [
            // 房间图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: room.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: room.accentColor.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.meeting_room,
                color: room.accentColor,
              ),
            ),
            
            const SizedBox(width: AppTheme.spaceLg),
            
            // 房间信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: AppTheme.textHeading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.participants} 人',
                        style: AppTheme.textCaption,
                      ),
                      const SizedBox(width: AppTheme.spaceLg),
                      Text(
                        room.lastActive,
                        style: AppTheme.textCaption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 进入按钮
            IconButton(
              icon: const Icon(Icons.chevron_right),
              color: AppTheme.textTertiary,
              onPressed: () => _enterRoom(room.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: FluentCard(
            onTap: _startVoiceRecording,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mic,
                    color: AppTheme.accentPrimary,
                    size: 28,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    '语音录制',
                    style: AppTheme.textBody.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '开始一段独白',
                    style: AppTheme.textCaption,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: FluentCard(
            onTap: () => _showFeatureInDevelopment(context, 'AI 分析'),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_graph,
                    color: const Color(0xFF0F7B0F),
                    size: 28,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'AI 分析',
                    style: AppTheme.textBody.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '查看会议洞察',
                    style: AppTheme.textCaption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _createRoom() {
    final roomId = 'room_${Random().nextInt(10000).toString().padLeft(4, '0')}';
    _enterRoom(roomId);
  }

  void _enterRoom(String roomId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoomScreen(roomId: roomId),
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundLayer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text('加入房间', style: AppTheme.textHeading2),
        content: TextField(
          style: AppTheme.textBody,
          decoration: const InputDecoration(
            hintText: '输入房间代码',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FluentButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  void _showFeatureInDevelopment(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName 功能开发中...'),
        backgroundColor: AppTheme.accentSecondary,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '知道了',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _startVoiceRecording() async {
    final pipeline = VoicePipeline();
    try {
      await pipeline.start();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('录音中...'),
          backgroundColor: AppTheme.accentPrimary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('录音失败: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

class RoomCardData {
  final String id;
  final String name;
  final int participants;
  final String lastActive;
  final Color accentColor;

  RoomCardData({
    required this.id,
    required this.name,
    required this.participants,
    required this.lastActive,
    required this.accentColor,
  });
}
