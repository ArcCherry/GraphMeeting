import 'package:flutter/material.dart';

import '../../models/auth/role_permissions.dart';
import '../../models/world_settings.dart';
import '../../models/chrono_vine/leaf_attachment.dart';

/// 世界管理面板
/// 
/// 服主用于管理世界设置、参与者权限、可见范围等
class WorldAdminPanel extends StatefulWidget {
  const WorldAdminPanel({super.key});

  @override
  State<WorldAdminPanel> createState() => _WorldAdminPanelState();
}

class _WorldAdminPanelState extends State<WorldAdminPanel> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 设置
  late WorldSettings _settings;
  
  // 参与者列表（模拟）
  final List<_ParticipantInfo> _participants = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _settings = WorldSettings.defaultSettings('产品周会');
    _loadParticipants();
  }

  void _loadParticipants() {
    _participants.addAll([
      _ParticipantInfo(
        id: 'user_1',
        name: '张三',
        role: UserRole.owner,
        isOnline: true,
        joinTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _ParticipantInfo(
        id: 'user_2',
        name: '李四',
        role: UserRole.admin,
        isOnline: true,
        joinTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      _ParticipantInfo(
        id: 'user_3',
        name: '王五',
        role: UserRole.member,
        isOnline: false,
        joinTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          '${_settings.worldName} - 管理',
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: '参与者'),
            Tab(icon: Icon(Icons.security), text: '权限'),
            Tab(icon: Icon(Icons.visibility), text: '可见范围'),
            Tab(icon: Icon(Icons.settings), text: '设置'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildParticipantsTab(),
          _buildPermissionsTab(),
          _buildVisibilityTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // 参与者标签页
  Widget _buildParticipantsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return _buildParticipantCard(participant);
      },
    );
  }

  Widget _buildParticipantCard(_ParticipantInfo participant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF16213E),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(participant.role),
          child: Text(
            participant.name[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          participant.name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: participant.isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              participant.isOnline ? '在线' : '离线',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(participant.role).withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                PermissionChecker.getRoleLabel(participant.role),
                style: TextStyle(
                  color: _getRoleColor(participant.role),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        trailing: participant.role != UserRole.owner
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF16213E),
              onSelected: (value) => _handleParticipantAction(participant, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'promote',
                  child: Text('提升为管理员', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'demote',
                  child: Text('降为普通成员', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'kick',
                  child: Text('踢出', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          : null,
      ),
    );
  }

  // 权限标签页
  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: '角色权限矩阵',
          child: Column(
            children: UserRole.values.map((role) {
              return ExpansionTile(
                title: Text(
                  PermissionChecker.getRoleLabel(role),
                  style: const TextStyle(color: Colors.white),
                ),
                children: Permission.all.map((permission) {
                  final hasPermission = PermissionChecker.hasPermission(role, permission);
                  return CheckboxListTile(
                    title: Text(
                      PermissionChecker.getPermissionLabel(permission),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    value: hasPermission,
                    onChanged: role == UserRole.owner
                      ? null  // 服主权限不可修改
                      : (value) => _togglePermission(role, permission, value),
                    activeColor: Colors.blue,
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 可见范围标签页
  Widget _buildVisibilityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 时间范围
        _buildSectionCard(
          title: '可见时间范围',
          child: Column(
            children: [
              RadioListTile<Duration?>(
                title: const Text('全部历史', style: TextStyle(color: Colors.white)),
                value: null,
                groupValue: _settings.defaultVisibility.timeWindow,
                onChanged: (value) => _updateVisibility(timeWindow: value),
                activeColor: Colors.blue,
              ),
              RadioListTile<Duration?>(
                title: const Text('最近24小时', style: TextStyle(color: Colors.white)),
                value: const Duration(hours: 24),
                groupValue: _settings.defaultVisibility.timeWindow,
                onChanged: (value) => _updateVisibility(timeWindow: value),
                activeColor: Colors.blue,
              ),
              RadioListTile<Duration?>(
                title: const Text('最近7天', style: TextStyle(color: Colors.white)),
                value: const Duration(days: 7),
                groupValue: _settings.defaultVisibility.timeWindow,
                onChanged: (value) => _updateVisibility(timeWindow: value),
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 节点类型过滤
        _buildSectionCard(
          title: '可见节点类型',
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('普通消息', style: TextStyle(color: Colors.white)),
                value: true,
                onChanged: (v) {},
                activeColor: Colors.blue,
              ),
              CheckboxListTile(
                title: const Text('里程碑', style: TextStyle(color: Colors.white)),
                value: true,
                onChanged: (v) {},
                activeColor: Colors.blue,
              ),
              CheckboxListTile(
                title: const Text('AI总结', style: TextStyle(color: Colors.white)),
                value: true,
                onChanged: (v) {},
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 隔离模式
        _buildSectionCard(
          title: '高级选项',
          child: SwitchListTile(
            title: const Text('参与者隔离模式', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              '成员只能看到自己的提交，无法看到他人',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            value: _settings.defaultVisibility.isolationMode,
            onChanged: (value) => _updateVisibility(isolationMode: value),
            activeColor: Colors.blue,
          ),
        ),
      ],
    );
  }

  // 设置标签页
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 语音处理
        _buildSectionCard(
          title: '语音处理',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '转写模式',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...TranscriptionMode.values.map((mode) {
                return RadioListTile<TranscriptionMode>(
                  title: Text(
                    mode.label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    mode.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: mode,
                  groupValue: _settings.transcriptionMode,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(transcriptionMode: value);
                      });
                    }
                  },
                  activeColor: Colors.blue,
                );
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 网络设置
        _buildSectionCard(
          title: '网络设置',
          child: Column(
            children: [
              ListTile(
                title: const Text('最大在线人数', style: TextStyle(color: Colors.white)),
                trailing: DropdownButton<int>(
                  value: _settings.maxPlayers,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  items: [10, 20, 50, 100, 200, 500].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count 人'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(maxPlayers: value);
                      });
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('启用延迟踢出', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '延迟超过 ${_settings.forceDisconnectLatencyMs}ms 自动踢出',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                value: _settings.enableLatencyKick,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(enableLatencyKick: value);
                  });
                },
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // AI设置
        _buildSectionCard(
          title: 'AI设置',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('自动生成总结', style: TextStyle(color: Colors.white)),
                value: _settings.enableAutoSummary,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(enableAutoSummary: value);
                  });
                },
                activeColor: Colors.blue,
              ),
              if (_settings.enableAutoSummary)
                ListTile(
                  title: Text(
                    '生成间隔',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                  trailing: DropdownButton<Duration>(
                    value: _settings.summaryInterval,
                    dropdownColor: const Color(0xFF16213E),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const Duration(minutes: 1),
                      const Duration(minutes: 5),
                      const Duration(minutes: 10),
                      const Duration(minutes: 30),
                    ].map((duration) {
                      return DropdownMenuItem(
                        value: duration,
                        child: Text('${duration.inMinutes} 分钟'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _settings = _settings.copyWith(summaryInterval: value);
                        });
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 危险操作
        _buildSectionCard(
          title: '危险操作',
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('删除世界', style: TextStyle(color: Colors.red)),
                subtitle: Text(
                  '此操作不可恢复',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                onTap: _showDeleteConfirmDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      color: const Color(0xFF16213E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.admin:
        return Colors.red;
      case UserRole.moderator:
        return Colors.orange;
      case UserRole.member:
        return Colors.blue;
      case UserRole.guest:
        return Colors.green;
      case UserRole.spectator:
        return Colors.grey;
    }
  }

  void _handleParticipantAction(_ParticipantInfo participant, String action) {
    switch (action) {
      case 'promote':
        setState(() {
          participant.role = UserRole.admin;
        });
        break;
      case 'demote':
        setState(() {
          participant.role = UserRole.member;
        });
        break;
      case 'kick':
        setState(() {
          _participants.removeWhere((p) => p.id == participant.id);
        });
        break;
    }
  }

  void _togglePermission(UserRole role, String permission, bool? value) {
    // 实际实现需要修改权限矩阵
    setState(() {});
  }

  void _updateVisibility({
    Duration? timeWindow,
    bool? isolationMode,
  }) {
    setState(() {
      _settings = _settings.copyWith(
        defaultVisibility: VisibilityFilter(
          timeWindow: timeWindow ?? _settings.defaultVisibility.timeWindow,
          isolationMode: isolationMode ?? _settings.defaultVisibility.isolationMode,
        ),
      );
    });
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('确认删除？', style: TextStyle(color: Colors.red)),
        content: Text(
          '世界 "${_settings.worldName}" 将被永久删除，所有数据不可恢复。',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 返回上一页
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 参与者信息
class _ParticipantInfo {
  final String id;
  String name;
  UserRole role;
  bool isOnline;
  DateTime joinTime;

  _ParticipantInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.isOnline,
    required this.joinTime,
  });
}
