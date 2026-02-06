/// 设置页面
/// 
/// 包含：
/// - 用户资料设置
/// - 通知设置
/// - 隐私设置
/// - 外观设置
/// - 关于

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/user/user_identity_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userIdentityServiceProvider);
    final user = userState.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackgroundLayer,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户资料卡片
          if (user != null) _buildProfileCard(user),
          
          const SizedBox(height: 24),
          
          // 通用设置
          _buildSectionTitle('通用'),
          FluentCard(
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: '通知',
                  subtitle: '接收消息和活动提醒',
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchTile(
                  icon: Icons.volume_up,
                  title: '声音',
                  subtitle: '播放消息提示音',
                  value: _soundEnabled,
                  onChanged: (v) => setState(() => _soundEnabled = v),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 外观设置
          _buildSectionTitle('外观'),
          FluentCard(
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.dark_mode,
                  title: '深色模式',
                  subtitle: '使用深色主题',
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.color_lens,
                  title: '强调色',
                  subtitle: '自定义主题颜色',
                  onTap: _showColorPicker,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // AI设置
          _buildSectionTitle('AI助手'),
          FluentCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.smart_toy,
                  title: 'AI配置',
                  subtitle: '配置API连接',
                  onTap: () => Navigator.pushNamed(context, '/ai_config'),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchTile(
                  icon: Icons.auto_awesome,
                  title: '自动生成摘要',
                  subtitle: '为每个节点生成AI总结',
                  value: true,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 账号设置
          _buildSectionTitle('账号'),
          FluentCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.edit,
                  title: '编辑资料',
                  onTap: () => _navigateToProfileEdit(),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.security,
                  title: '隐私设置',
                  onTap: () => _showPrivacySettings(),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.logout,
                  title: '退出登录',
                  textColor: AppTheme.error,
                  onTap: () => _showLogoutDialog(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 关于
          _buildSectionTitle('关于'),
          FluentCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.info,
                  title: '关于 GraphMeeting',
                  onTap: () => _showAboutDialog(),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.description,
                  title: '隐私政策',
                  onTap: () => _showInDevelopment('隐私政策'),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.help,
                  title: '帮助与反馈',
                  onTap: () => _showInDevelopment('帮助与反馈'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 版本号
          Center(
            child: Text(
              'GraphMeeting v1.0.0',
              style: AppTheme.textCaption.copyWith(
                color: AppTheme.darkTextTertiary,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(dynamic user) {
    return FluentCard(
      onTap: () => _navigateToProfileEdit(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 头像
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPrimary,
                    AppTheme.accentSecondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Text(
                  user.nickname.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
                    style: AppTheme.textHeading3.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.statusMessage ?? '暂无状态',
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // 箭头
            Icon(
              Icons.chevron_right,
              color: AppTheme.darkTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: AppTheme.textCaption.copyWith(
          color: AppTheme.accentPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: AppTheme.accentPrimary),
      title: Text(title, style: AppTheme.textBody),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTheme.textCaption)
          : null,
      activeColor: AppTheme.accentPrimary,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppTheme.accentPrimary),
      title: Text(
        title,
        style: AppTheme.textBody.copyWith(color: textColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTheme.textCaption)
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.darkTextTertiary,
      ),
      onTap: onTap,
    );
  }

  void _showColorPicker() {
    // TODO: 实现颜色选择
  }

  void _navigateToProfileEdit() {
    // TODO: 导航到资料编辑
  }

  void _showPrivacySettings() {
    // TODO: 显示隐私设置
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('退出登录', style: AppTheme.textHeading3),
        content: Text(
          '确定要退出登录吗？',
          style: AppTheme.textBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: AppTheme.textBody),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(userIdentityServiceProvider.notifier).logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/user_setup',
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showInDevelopment(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 功能开发中...')),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'GraphMeeting',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.hub, color: Colors.white),
      ),
      children: [
        Text(
          'GraphMeeting 是一个革命性的3D可视化会议工具，让每一次讨论都留下一座可漫游的思维宫殿。',
          style: AppTheme.textBody,
        ),
      ],
    );
  }
}
