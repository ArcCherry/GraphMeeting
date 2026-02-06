/// 房间详情页 - 3D时空藤蔓主界面
/// 
/// 这是GraphMeeting的核心界面，展示：
/// - 高级3D时空藤蔓可视化（透视/光照/阴影/粒子）
/// - 消息输入区域
/// - 参与者列表
/// - AI生成的共识/争议/ToDo
/// - 完整的交互功能

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/room.dart';
import '../../services/media/media_service.dart';
import '../../services/user/user_identity_service.dart';
import '../../services/vine_3d/vine_3d_engine.dart';
import '../../state/providers/message_providers.dart';
import '../widgets/responsive/responsive_layout.dart';
import '../widgets/vine/mind_construction_site.dart';
import '../widgets/vine/vine_canvas.dart' show ViewportControls;
import '../screens/settings/room_settings_screen.dart';

/// 房间详情屏幕
class RoomDetailScreen extends ConsumerStatefulWidget {
  final Room room;
  
  const RoomDetailScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  bool _showParticipants = true;
  bool _showChat = true;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  // 媒体服务
  final MediaService _mediaService = MediaService();
  
  // 输入状态
  bool _isRecording = false;
  bool _isTyping = false;
  Duration _recordingDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildDesktopLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }
  
  // ===== 手机布局 =====
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: Stack(
            children: [
              // 思维建筑工地 3D可视化
              MindConstructionSite(
                roomId: widget.room.id,
                onNodeTap: (node) => _onNodeTap(node.id),
                onNodeLongPress: (node) => _onNodeLongPress(node.id),
              ),
              
              // 视角控制按钮
              Positioned(
                right: 16,
                top: 16,
                child: ViewportControls(
                  onReset: () {},
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRotateLeft: () {},
                  onRotateRight: () {},
                ),
              ),
              
              // 底部输入区域
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomInputArea(),
              ),
              
              // 浮动操作按钮
              Positioned(
                right: 16,
                bottom: 120,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'participants',
                      onPressed: () => _showParticipantsSheet(context),
                      backgroundColor: AppTheme.darkBackgroundLayer,
                      child: Icon(Icons.people, color: AppTheme.darkTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'chat',
                      onPressed: () => _showChatSheet(context),
                      backgroundColor: AppTheme.darkBackgroundLayer,
                      child: Icon(Icons.chat, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // ===== 桌面布局 =====
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: Row(
            children: [
              // 左侧面板 - 参与者
              if (_showParticipants)
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackgroundLayer,
                    border: Border(
                      right: BorderSide(color: AppTheme.darkBorderPrimary),
                    ),
                  ),
                  child: _buildParticipantsPanel(),
                ),
              
              // 中央3D画布
              Expanded(
                child: Stack(
                  children: [
                    MindConstructionSite(
                      roomId: widget.room.id,
                      onNodeTap: (node) => _onNodeTap(node.id),
                      onNodeLongPress: (node) => _onNodeLongPress(node.id),
                    ),
                    
                    // 视角控制
                    Positioned(
                      right: 24,
                      top: 24,
                      child: ViewportControls(
                        onReset: () {},
                        onZoomIn: () {},
                        onZoomOut: () {},
                        onRotateLeft: () {},
                        onRotateRight: () {},
                      ),
                    ),
                    
                    // 节点详情悬浮卡片
                    Positioned(
                      left: 24,
                      bottom: 100,
                      child: _buildNodeInfoCard(),
                    ),
                  ],
                ),
              ),
              
              // 右侧面板 - 聊天
              if (_showChat)
                Container(
                  width: 340,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackgroundLayer,
                    border: Border(
                      left: BorderSide(color: AppTheme.darkBorderPrimary),
                    ),
                  ),
                  child: _buildChatPanel(),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  // ===== AppBar =====
  Widget _buildAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer.withAlpha(200),
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderPrimary),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.darkTextPrimary,
          ),
          
          const SizedBox(width: 12),
          
          // 房间图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary,
                  AppTheme.accentSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hub,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 房间信息
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.name,
                  style: AppTheme.textHeading3.copyWith(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.room.participantCount} 人在线',
                      style: AppTheme.textCaption.copyWith(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Code: ${widget.room.accessCode ?? '------'}',
                        style: TextStyle(
                          color: AppTheme.accentPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 操作按钮
          IconButton(
            onPressed: _toggleParticipants,
            icon: Icon(
              _showParticipants ? Icons.people : Icons.people_outline,
              color: AppTheme.darkTextPrimary,
            ),
            tooltip: '参与者',
          ),
          
          IconButton(
            onPressed: _toggleChat,
            icon: Icon(
              _showChat ? Icons.chat : Icons.chat_outlined,
              color: AppTheme.darkTextPrimary,
            ),
            tooltip: '聊天',
          ),
          
          IconButton(
            onPressed: () => _showShareDialog(context),
            icon: Icon(Icons.share, color: AppTheme.darkTextPrimary),
            tooltip: '分享',
          ),
          
          IconButton(
            onPressed: () => _showRoomMenu(context),
            icon: Icon(Icons.more_vert, color: AppTheme.darkTextPrimary),
            tooltip: '更多',
          ),
        ],
      ),
    );
  }
  
  // ===== 底部输入区域 =====
  Widget _buildBottomInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppTheme.darkBackgroundBase.withAlpha(200),
            AppTheme.darkBackgroundBase,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 附件按钮
            IconButton(
              onPressed: _showAttachmentOptions,
              icon: Icon(
                Icons.add_circle_outline,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            
            // 输入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _isRecording 
                      ? AppTheme.error.withAlpha(20)
                      : AppTheme.darkBackgroundSecondary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isRecording 
                        ? AppTheme.error 
                        : AppTheme.darkBorderPrimary,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: AppTheme.textBody.copyWith(
                    color: AppTheme.darkTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 语音/发送按钮
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isTyping
                  ? FloatingActionButton.small(
                      key: const ValueKey('send'),
                      onPressed: _sendMessage,
                      backgroundColor: AppTheme.accentPrimary,
                      child: const Icon(Icons.send),
                    )
                  : GestureDetector(
                      key: const ValueKey('mic'),
                      onTapDown: (_) => _startRecording(),
                      onTapUp: (_) => _stopRecording(),
                      onTapCancel: () => _cancelRecording(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppTheme.error
                              : AppTheme.darkBackgroundSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording
                                ? AppTheme.error
                                : AppTheme.darkBorderPrimary,
                          ),
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording
                              ? Colors.white
                              : AppTheme.darkTextSecondary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ===== 参与者面板 =====
  Widget _buildParticipantsPanel() {
    return Column(
      children: [
        _buildParticipantsHeader(),
        Expanded(
          child: _buildParticipantsList(),
        ),
      ],
    );
  }
  
  Widget _buildParticipantsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderPrimary),
        ),
      ),
      child: Row(
        children: [
          Text(
            '参与者',
            style: AppTheme.textHeading3.copyWith(
              color: AppTheme.darkTextPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.room.participantCount}',
              style: TextStyle(
                color: AppTheme.accentPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _inviteParticipant,
            icon: Icon(
              Icons.person_add,
              color: AppTheme.accentPrimary,
              size: 20,
            ),
            tooltip: '邀请',
          ),
        ],
      ),
    );
  }
  
  Widget _buildParticipantsList() {
    // 模拟参与者数据
    final participants = [
      {'name': '我', 'isMe': true, 'status': 'online'},
      {'name': 'Alice', 'isMe': false, 'status': 'online'},
      {'name': 'Bob', 'isMe': false, 'status': 'away'},
      {'name': 'Carol', 'isMe': false, 'status': 'online'},
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        return _buildParticipantItem(
          name: p['name'] as String,
          isMe: p['isMe'] as bool,
          status: p['status'] as String,
        );
      },
    );
  }
  
  Widget _buildParticipantItem({
    required String name,
    required bool isMe,
    required String status,
  }) {
    Color statusColor;
    switch (status) {
      case 'online':
        statusColor = AppTheme.success;
        break;
      case 'away':
        statusColor = AppTheme.warning;
        break;
      default:
        statusColor = AppTheme.darkTextTertiary;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.accentPrimary.withAlpha(20) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 头像
          Stack(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.accentPrimary.withAlpha(100),
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.accentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.darkBackgroundLayer,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // 名字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name + (isMe ? ' (我)' : ''),
                  style: AppTheme.textBody.copyWith(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 14,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  status == 'online' ? '在线' : '离开',
                  style: AppTheme.textCaption.copyWith(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ===== 聊天面板 =====
  Widget _buildChatPanel() {
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: _buildChatList(),
        ),
        _buildChatInput(),
      ],
    );
  }
  
  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderPrimary),
        ),
      ),
      child: Row(
        children: [
          Text(
            '讨论',
            style: AppTheme.textHeading3.copyWith(
              color: AppTheme.darkTextPrimary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showChatFilter,
            icon: Icon(
              Icons.filter_list,
              color: AppTheme.darkTextSecondary,
              size: 20,
            ),
            tooltip: '筛选',
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatList() {
    final messagesState = ref.watch(roomMessagesProvider(widget.room.id));
    final currentUser = ref.watch(userIdentityServiceProvider).currentUser;
    
    if (messagesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (messagesState.error != null) {
      return Center(
        child: Text(
          '加载失败: ${messagesState.error}',
          style: AppTheme.textBody.copyWith(color: AppTheme.error),
        ),
      );
    }
    
    final messages = messagesState.messages;
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: AppTheme.darkTextTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无消息',
              style: AppTheme.textBody.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '开始对话吧！',
              style: AppTheme.textCaption.copyWith(
                color: AppTheme.darkTextTertiary,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = currentUser != null && message.authorId == currentUser.id;
        
        return _buildMessageBubble(
          isMe: isMe,
          text: message.content,
          time: _formatTime(message.timestamp),
          senderName: isMe ? '我' : '用户${message.authorId.substring(0, 4)}',
        );
      },
    );
  }
  
  Widget _buildMessageBubble({
    required bool isMe,
    required String text,
    required String time,
    required String senderName,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 发送者名字
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  senderName,
                  style: AppTheme.textCaption.copyWith(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            
            // 消息气泡
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.accentPrimary : AppTheme.darkBackgroundSecondary,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : null,
                  bottomLeft: !isMe ? const Radius.circular(4) : null,
                ),
              ),
              child: Text(
                text,
                style: AppTheme.textBody.copyWith(
                  color: isMe ? Colors.white : AppTheme.darkTextPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            
            // 时间
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Text(
                time,
                style: AppTheme.textCaption.copyWith(
                  color: AppTheme.darkTextTertiary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.darkBorderPrimary),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _showAttachmentOptions,
            icon: Icon(Icons.add, color: AppTheme.darkTextSecondary),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTheme.textBody.copyWith(
                color: AppTheme.darkTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: AppTheme.textBody.copyWith(
                  color: AppTheme.darkTextTertiary,
                ),
                filled: true,
                fillColor: AppTheme.darkBackgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(Icons.send, color: AppTheme.accentPrimary),
          ),
        ],
      ),
    );
  }
  
  // ===== 节点信息卡片 =====
  Widget _buildNodeInfoCard() {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackgroundLayer.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorderPrimary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPrimary.withAlpha(100),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '想法节点',
                style: AppTheme.textBody.copyWith(
                  color: AppTheme.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '点击节点查看详细内容，长按进行更多操作',
            style: AppTheme.textCaption.copyWith(
              color: AppTheme.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionChip(Icons.reply, '回复'),
              _buildActionChip(Icons.format_quote, '引用'),
              _buildActionChip(Icons.share, '分享'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionChip(IconData icon, String label, {VoidCallback? onTap}) {
    return Material(
      color: AppTheme.darkBackgroundSecondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label 功能开发中...')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.darkTextSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTheme.textCaption.copyWith(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ===== 操作回调 =====
  
  void _onNodeTap(String nodeId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('选中节点: $nodeId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _onNodeLongPress(String nodeId) {
    HapticFeedback.mediumImpact();
    _showNodeActionMenu(nodeId);
  }
  
  void _onCanvasTap(Offset position) {
    // 点击空白处取消选择
  }
  
  // ===== 辅助方法 =====
  
  void _toggleParticipants() {
    setState(() {
      _showParticipants = !_showParticipants;
    });
  }
  
  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
    });
  }
  

  
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final messageService = ref.read(roomMessagesProvider(widget.room.id).notifier);
    await messageService.sendTextMessage(text);
    _messageController.clear();
    
    // 滚动到底部
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _startRecording() async {
    final success = await _mediaService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      HapticFeedback.mediumImpact();
      
      // 开始计时
      _startRecordingTimer();
    }
  }
  
  void _startRecordingTimer() {
    Future.doWhile(() async {
      if (!_isRecording) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration = _mediaService.recordingDuration ?? Duration.zero;
        });
      }
      return _isRecording;
    });
  }
  
  void _stopRecording() async {
    final mediaFile = await _mediaService.stopRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    
    if (mediaFile != null) {
      _sendVoiceMessage(mediaFile);
    }
  }
  
  void _cancelRecording() async {
    await _mediaService.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }
  
  void _sendVoiceMessage(MediaFile mediaFile) async {
    final messageService = ref.read(roomMessagesProvider(widget.room.id).notifier);
    await messageService.sendVoiceMessage(
      mediaFile.path,
      mediaFile.duration?.inSeconds ?? 0,
    );
  }
  
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBackgroundLayer,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: AppTheme.accentPrimary),
              title: Text('图片', style: AppTheme.textBody),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppTheme.accentSecondary),
              title: Text('文件', style: AppTheme.textBody),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.success),
              title: Text('相机', style: AppTheme.textBody),
              onTap: () {
                Navigator.pop(context);
                _openCamera();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _pickImage() async {
    final mediaFile = await _mediaService.pickImage();
    if (mediaFile != null) {
      _sendImageMessage(mediaFile);
    }
  }
  
  void _sendImageMessage(MediaFile mediaFile) async {
    final messageService = ref.read(roomMessagesProvider(widget.room.id).notifier);
    await messageService.sendImageMessage(
      mediaFile.path,
      caption: null,
    );
  }
  
  void _pickFile() async {
    final mediaFile = await _mediaService.pickFile();
    if (mediaFile != null) {
      _sendFileMessage(mediaFile);
    }
  }
  
  void _sendFileMessage(MediaFile mediaFile) async {
    final messageService = ref.read(roomMessagesProvider(widget.room.id).notifier);
    await messageService.sendFileMessage(
      mediaFile.path,
      mediaFile.name,
      mediaFile.size,
    );
  }
  
  void _openCamera() async {
    final mediaFile = await _mediaService.pickImage(fromCamera: true);
    if (mediaFile != null) {
      _sendImageMessage(mediaFile);
    }
  }
  
  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('分享房间', style: AppTheme.textHeading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '访问码',
              style: AppTheme.textCaption,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Text(
              '分享给朋友，让他们加入讨论',
              style: AppTheme.textCaption,
              textAlign: TextAlign.center,
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
              Clipboard.setData(ClipboardData(text: widget.room.accessCode ?? '------'));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }
  
  void _showRoomMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        60,
        16,
        0,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.settings, color: AppTheme.darkTextPrimary),
              const SizedBox(width: 8),
              const Text('房间设置'),
            ],
          ),
          onTap: () => _showRoomSettings(context),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.history, color: AppTheme.darkTextPrimary),
              const SizedBox(width: 8),
              const Text('历史记录'),
            ],
          ),
          onTap: () => _showHistory(context),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.exit_to_app, color: AppTheme.error),
              const SizedBox(width: 8),
              const Text('离开房间'),
            ],
          ),
          onTap: () => _leaveRoom(context),
        ),
      ],
    );
  }
  
  void _showNodeActionMenu(String nodeId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBackgroundLayer,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '节点操作',
              style: AppTheme.textHeading3,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.format_quote),
              title: const Text('引用'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: const Text('置顶'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.error),
              title: const Text('删除', style: TextStyle(color: AppTheme.error)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showParticipantsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBackgroundLayer,
      builder: (context) => Column(
        children: [
          _buildParticipantsHeader(),
          Expanded(
            child: _buildParticipantsList(),
          ),
        ],
      ),
    );
  }
  
  void _showChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBackgroundLayer,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              _buildChatHeader(),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final messagesState = ref.watch(roomMessagesProvider(widget.room.id));
                    final currentUser = ref.watch(userIdentityServiceProvider).currentUser;
                    
                    if (messagesState.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final messages = messagesState.messages;
                    
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          '暂无消息',
                          style: AppTheme.textBody.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = currentUser != null && message.authorId == currentUser.id;
                        return _buildMessageBubble(
                          isMe: isMe,
                          text: message.content,
                          time: _formatTime(message.timestamp),
                          senderName: isMe ? '我' : '用户',
                        );
                      },
                    );
                  },
                ),
              ),
              _buildChatInput(),
            ],
          );
        },
      ),
    );
  }
  
  void _showRoomSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomSettingsScreen(room: widget.room),
      ),
    );
  }
  
  void _showHistory(BuildContext context) {
    // TODO: 显示历史记录
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('历史记录功能开发中...')),
    );
  }
  
  void _inviteParticipant() {
    _showShareDialog(context);
  }
  
  void _showChatFilter() {
    // TODO: 显示筛选选项
  }
  
  void _leaveRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkBackgroundLayer,
        title: Text('离开房间', style: AppTheme.textHeading3),
        content: Text(
          '确定要离开这个房间吗？',
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
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('离开'),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 录音动画
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withAlpha(100),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // 文字
          Text(
            '录音中',
            style: AppTheme.textBody.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 时长
          Text(
            MediaService.formatDuration(_recordingDuration),
            style: AppTheme.textBody.copyWith(
              color: AppTheme.darkTextSecondary,
              fontFamily: 'monospace',
            ),
          ),
          
          const Spacer(),
          
          // 取消按钮
          GestureDetector(
            onTap: _cancelRecording,
            child: Text(
              '取消',
              style: AppTheme.textBody.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
