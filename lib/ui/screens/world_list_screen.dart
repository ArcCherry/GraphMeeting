/// 世界列表界面（Minecraft 服务器列表风格）
/// 
/// 深色主题 + 响应式布局 + 真实数据库数据

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/room.dart';
import '../../services/room/room_providers.dart';
import '../widgets/responsive/responsive_layout.dart';

/// 世界列表屏幕
class WorldListScreen extends ConsumerStatefulWidget {
  const WorldListScreen({super.key});

  @override
  ConsumerState<WorldListScreen> createState() => _WorldListScreenState();
}

class _WorldListScreenState extends ConsumerState<WorldListScreen> {
  final _searchController = TextEditingController();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    // 延迟初始化示例数据
    Future.microtask(() {
      ref.read(roomListProvider.notifier).initializeSampleData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomListProvider);
    final searchQuery = ref.watch(roomSearchQueryProvider);
    final showArchived = ref.watch(showArchivedRoomsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(roomsAsync),
        tablet: _buildDesktopLayout(roomsAsync),
        desktop: _buildDesktopLayout(roomsAsync),
      ),
      floatingActionButton: ResponsiveLayout.isMobile(context)
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateRoomDialog(context),
              backgroundColor: AppTheme.accentPrimary,
              icon: const Icon(Icons.add),
              label: const Text('创建世界'),
            )
          : null,
    );
  }

  // ===== 手机布局 =====
  Widget _buildMobileLayout(AsyncValue<List<Room>> roomsAsync) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: roomsAsync.when(
              data: (rooms) => _buildRoomList(rooms),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text(
                      '加载失败: $err',
                      style: TextStyle(color: AppTheme.darkTextSecondary),
                    ),
                    TextButton(
                      onPressed: () => ref.read(roomListProvider.notifier).loadRooms(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 桌面/平板布局 =====
  Widget _buildDesktopLayout(AsyncValue<List<Room>> roomsAsync) {
    return Row(
      children: [
        _buildSideNavigation(),
        Expanded(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: roomsAsync.when(
                  data: (rooms) => _buildRoomGrid(rooms),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败: $err',
                          style: TextStyle(color: AppTheme.darkTextSecondary),
                        ),
                        TextButton(
                          onPressed: () => ref.read(roomListProvider.notifier).loadRooms(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInfoPanel(),
      ],
    );
  }

  // ===== 组件构建 =====

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderPrimary),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.account_tree,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Text(
            'GraphMeeting',
            style: AppTheme.textHeading2.copyWith(
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const Spacer(),
          if (!ResponsiveLayout.isMobile(context))
            ElevatedButton.icon(
              onPressed: () => _showCreateRoomDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('创建世界'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: AppTheme.spaceMd),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.darkBackgroundSecondary,
            child: Icon(
              Icons.person,
              color: AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (focused) => setState(() => _isSearchFocused = focused),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(roomSearchQueryProvider.notifier).state = value;
                  ref.read(roomListProvider.notifier).search(value);
                },
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: '搜索会议世界...',
                  hintStyle: TextStyle(color: AppTheme.darkTextTertiary),
                  prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(roomSearchQueryProvider.notifier).state = '';
                            ref.read(roomListProvider.notifier).loadRooms();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _isSearchFocused
                      ? AppTheme.darkBackgroundSecondary
                      : AppTheme.darkBackgroundTertiary.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.accentPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          ElevatedButton.icon(
            onPressed: () => _showJoinByCodeDialog(context),
            icon: const Icon(Icons.vpn_key),
            label: const Text('访问码'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkBackgroundSecondary,
              foregroundColor: AppTheme.darkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<Room> rooms) {
    if (rooms.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(roomListProvider.notifier).loadRooms(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          return _buildRoomListItem(rooms[index]);
        },
      ),
    );
  }

  Widget _buildRoomGrid(List<Room> rooms) {
    if (rooms.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(roomListProvider.notifier).loadRooms(),
      child: AdaptiveGrid(
        children: rooms.map((room) => _buildWorldGridCard(room)).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 64,
            color: AppTheme.darkTextTertiary,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Text(
            '还没有房间',
            style: AppTheme.textHeading3.copyWith(
              color: AppTheme.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            '创建一个房间开始协作吧',
            style: AppTheme.textBody.copyWith(
              color: AppTheme.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          ElevatedButton.icon(
            onPressed: () => _showCreateRoomDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('创建房间'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomListItem(Room room) {
    return Dismissible(
      key: Key(room.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceLg),
        color: AppTheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkBackgroundLayer,
            title: Text('确认删除', style: TextStyle(color: AppTheme.darkTextPrimary)),
            content: Text(
              '确定要删除房间 "${room.name}" 吗？此操作不可恢复。',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消', style: TextStyle(color: AppTheme.darkTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(roomListProvider.notifier).deleteRoom(room.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${room.name}')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppTheme.darkBackgroundLayer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.darkBorderPrimary),
        ),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getNetworkTypeColor(room.networkMode),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              _getNetworkTypeIcon(room.networkMode),
              color: Colors.white,
            ),
          ),
          title: Text(
            room.name,
            style: AppTheme.textBodyLarge.copyWith(
              color: AppTheme.darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (room.description != null && room.description!.isNotEmpty)
                Text(
                  room.description!,
                  style: AppTheme.textBody.copyWith(
                    color: AppTheme.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.darkTextTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(room.updatedAt),
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.darkTextTertiary,
                    ),
                  ),
                  if (room.accessCode != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackgroundSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.accessCode!,
                        style: AppTheme.textCaption.copyWith(
                          color: AppTheme.darkTextSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppTheme.darkTextSecondary,
          ),
          onTap: () => _enterRoom(room),
        ),
      ),
    );
  }

  Widget _buildWorldGridCard(Room room) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderPrimary),
      ),
      child: InkWell(
        onTap: () => _enterRoom(room),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getNetworkTypeColor(room.networkMode),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      _getNetworkTypeIcon(room.networkMode),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackgroundSecondary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      room.networkMode.toUpperCase(),
                      style: AppTheme.textCaption.copyWith(
                        color: AppTheme.darkTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                room.name,
                style: AppTheme.textHeading3.copyWith(
                  color: AppTheme.darkTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spaceXs),
              if (room.description != null && room.description!.isNotEmpty)
                Text(
                  room.description!,
                  style: AppTheme.textBody.copyWith(
                    color: AppTheme.darkTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              Row(
                children: [
                  if (room.accessCode != null) ...[
                    Icon(
                      Icons.vpn_key,
                      size: 14,
                      color: AppTheme.darkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      room.accessCode!,
                      style: AppTheme.textCaption.copyWith(
                        color: AppTheme.darkTextTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(room.updatedAt),
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 64,
      color: AppTheme.darkBackgroundLayer,
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spaceLg),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.account_tree,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.space2xl),
          _buildNavItem(Icons.home, '首页', true),
          _buildNavItem(Icons.history, '历史', false),
          _buildNavItem(Icons.settings, '设置', false),
          const Spacer(),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.darkBackgroundSecondary,
            child: Icon(
              Icons.person,
              color: AppTheme.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppTheme.spaceXs,
        horizontal: AppTheme.spaceSm,
      ),
      child: Tooltip(
        message: label,
        child: Material(
          color: isSelected ? AppTheme.accentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: () {
              if (label == '首页') {
                // 已在首页
              } else if (label == '历史') {
                _showHistoryDialog(context);
              } else if (label == '设置') {
                _showSettingsDialog(context);
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isSelected ? AppTheme.accentPrimary : AppTheme.darkTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('历史记录', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text(
          '历史记录功能即将上线',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定', style: TextStyle(color: AppTheme.accentPrimary)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('设置', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用设置功能即将上线',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(Icons.notifications, '通知设置', '已开启'),
            _buildSettingItem(Icons.dark_mode, '深色模式', '已开启'),
            _buildSettingItem(Icons.language, '语言', '简体中文'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定', style: TextStyle(color: AppTheme.accentPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.darkTextSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: AppTheme.darkTextTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final roomsAsync = ref.watch(roomListProvider);
    
    return Container(
      width: 280,
      color: AppTheme.darkBackgroundLayer,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速统计',
            style: AppTheme.textHeading3.copyWith(
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          roomsAsync.when(
            data: (rooms) => Column(
              children: [
                _buildStatCard('我的房间', '${rooms.length}', Icons.meeting_room),
                _buildStatCard('P2P 房间', 
                  '${rooms.where((r) => r.networkMode == 'p2p').length}', 
                  Icons.device_hub),
                _buildStatCard('服务器房间', 
                  '${rooms.where((r) => r.networkMode == 'server').length}', 
                  Icons.cloud),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Spacer(),
          Text(
            'GraphMeeting v0.1.0',
            style: AppTheme.textCaption.copyWith(
              color: AppTheme.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentPrimary),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              label,
              style: AppTheme.textBody.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.textHeading3.copyWith(
              color: AppTheme.darkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 辅助方法 =====

  Color _getNetworkTypeColor(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'p2p':
        return AppTheme.success;
      case 'server':
        return AppTheme.accentPrimary;
      case 'hybrid':
        return AppTheme.warning;
      default:
        return AppTheme.darkBackgroundTertiary;
    }
  }

  IconData _getNetworkTypeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'p2p':
        return Icons.device_hub;
      case 'server':
        return Icons.cloud;
      case 'hybrid':
        return Icons.merge;
      default:
        return Icons.help;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }

  void _enterRoom(Room room) {
    ref.read(selectedRoomProvider.notifier).state = room;
    Navigator.pushNamed(context, '/room', arguments: room);
  }

  // ===== 对话框 =====

  void _showCreateRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String networkMode = 'p2p';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkBackgroundLayer,
          title: Text('创建新世界', style: TextStyle(color: AppTheme.darkTextPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: '房间名称 *',
                    labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: descController,
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: '描述（可选）',
                    labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                DropdownButtonFormField<String>(
                  value: networkMode,
                  dropdownColor: AppTheme.darkBackgroundSecondary,
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: '网络模式',
                    labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'p2p',
                      child: Row(
                        children: [
                          Icon(Icons.device_hub, color: AppTheme.success, size: 20),
                          const SizedBox(width: 8),
                          const Text('P2P（局域网）'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'server',
                      child: Row(
                        children: [
                          Icon(Icons.cloud, color: AppTheme.accentPrimary, size: 20),
                          const SizedBox(width: 8),
                          const Text('服务器模式'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => networkMode = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: AppTheme.darkTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入房间名称')),
                  );
                  return;
                }

                try {
                  await ref.read(roomListProvider.notifier).createRoom(
                    name: nameController.text,
                    description: descController.text,
                    networkMode: networkMode,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('房间创建成功')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建失败: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinByCodeDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('通过访问码加入', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: TextField(
          controller: codeController,
          style: TextStyle(color: AppTheme.darkTextPrimary),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: '访问码',
            hintText: '例如: ABC123',
            labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
            filled: true,
            fillColor: AppTheme.darkBackgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty) return;

              try {
                final room = await ref.read(roomListProvider.notifier).joinByCode(
                  codeController.text.trim(),
                );
                Navigator.pop(context);
                _enterRoom(room);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('加入失败: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
