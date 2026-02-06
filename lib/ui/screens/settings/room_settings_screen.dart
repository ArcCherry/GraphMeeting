/// 房间设置页面
/// 
/// 包含：
/// - 房间信息编辑
/// - 网络模式设置
/// - 成员管理
/// - 权限设置
/// - 房间删除

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/room.dart';
import '../../../services/room/room_repository.dart';

class RoomSettingsScreen extends ConsumerStatefulWidget {
  final Room room;
  
  const RoomSettingsScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends ConsumerState<RoomSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _networkMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descriptionController = TextEditingController();
    _networkMode = widget.room.networkMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    // TODO: 实现保存逻辑
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() => _isSaving = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = true; // TODO: 检查当前用户是否是房主

    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackgroundLayer,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('房间设置'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('保存'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 房间信息
          _buildSectionTitle('基本信息'),
          FluentCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '房间名称',
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入房间名称',
                      hintStyle: AppTheme.textBody.copyWith(
                        color: AppTheme.darkTextTertiary,
                      ),
                      filled: true,
                      fillColor: AppTheme.darkBackgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    '房间描述',
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入房间描述（可选）',
                      hintStyle: AppTheme.textBody.copyWith(
                        color: AppTheme.darkTextTertiary,
                      ),
                      filled: true,
                      fillColor: AppTheme.darkBackgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 访问码
          _buildSectionTitle('访问码'),
          FluentCard(
            child: ListTile(
              leading: const Icon(Icons.key, color: AppTheme.accentPrimary),
              title: Text(
                widget.room.accessCode ?? '------',
                style: AppTheme.textHeading3.copyWith(
                  letterSpacing: 8,
                  color: AppTheme.accentPrimary,
                ),
              ),
              subtitle: Text(
                '分享此代码让其他人加入',
                style: AppTheme.textCaption,
              ),
              trailing: IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: widget.room.accessCode ?? '',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制')),
                  );
                },
                icon: const Icon(Icons.copy),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 网络模式
          _buildSectionTitle('网络模式'),
          FluentCard(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'p2p',
                  groupValue: _networkMode,
                  onChanged: isHost
                      ? (v) => setState(() => _networkMode = v!)
                      : null,
                  title: Text('P2P 模式', style: AppTheme.textBody),
                  subtitle: Text(
                    '点对点连接，无需服务器',
                    style: AppTheme.textCaption,
                  ),
                  secondary: const Icon(Icons.device_hub, color: AppTheme.accentPrimary),
                ),
                const Divider(height: 1, indent: 56),
                RadioListTile<String>(
                  value: 'server',
                  groupValue: _networkMode,
                  onChanged: isHost
                      ? (v) => setState(() => _networkMode = v!)
                      : null,
                  title: Text('服务器模式', style: AppTheme.textBody),
                  subtitle: Text(
                    '通过中央服务器中继',
                    style: AppTheme.textCaption,
                  ),
                  secondary: const Icon(Icons.cloud, color: AppTheme.accentSecondary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 成员管理
          _buildSectionTitle('成员管理'),
          FluentCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.people,
                  title: '管理成员',
                  subtitle: '${widget.room.participantCount} 人',
                  onTap: () => _showMemberManagement(),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.person_add,
                  title: '邀请成员',
                  onTap: () => _showInviteDialog(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 权限设置
          _buildSectionTitle('权限设置'),
          FluentCard(
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.mic,
                  title: '允许语音',
                  value: true,
                  onChanged: (v) {},
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchTile(
                  icon: Icons.image,
                  title: '允许图片',
                  value: true,
                  onChanged: (v) {},
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchTile(
                  icon: Icons.file_present,
                  title: '允许文件',
                  value: true,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 危险操作
          _buildSectionTitle('危险操作'),
          FluentCard(
            child: Column(
              children: [
                if (isHost)
                  _buildListTile(
                    icon: Icons.delete_forever,
                    title: '删除房间',
                    textColor: AppTheme.error,
                    onTap: () => _showDeleteRoomDialog(),
                  )
                else
                  _buildListTile(
                    icon: Icons.exit_to_app,
                    title: '退出房间',
                    textColor: AppTheme.error,
                    onTap: () => _showLeaveRoomDialog(),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
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
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: AppTheme.accentPrimary),
      title: Text(title, style: AppTheme.textBody),
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

  void _showMemberManagement() {
    // TODO: 显示成员管理页面
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('邀请成员', style: AppTheme.textHeading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '分享访问码给其他人',
              style: AppTheme.textBody,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkBackgroundSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.room.accessCode ?? '------',
                    style: AppTheme.textHeading2.copyWith(
                      letterSpacing: 8,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: AppTheme.textBody),
          ),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: widget.room.accessCode ?? '',
              ));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制')),
              );
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRoomDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('删除房间', style: AppTheme.textHeading3),
        content: Text(
          '确定要删除这个房间吗？此操作不可恢复，所有数据将被永久删除。',
          style: AppTheme.textBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: AppTheme.textBody),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // TODO: 删除房间
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showLeaveRoomDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('退出房间', style: AppTheme.textHeading3),
        content: Text(
          '确定要退出这个房间吗？',
          style: AppTheme.textBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: AppTheme.textBody),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // TODO: 退出房间
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
