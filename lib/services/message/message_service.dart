import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chrono_vine/vine_node.dart';
import '../../models/user/user_profile.dart';
import '../database/message_dao.dart';
import '../user/user_identity_service.dart';

/// 消息列表状态
class MessageListState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const MessageListState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  MessageListState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return MessageListState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 消息服务 - 处理消息的发送、接收和状态管理
class MessageService extends StateNotifier<MessageListState> {
  final MessageDao _messageDao;
  final UserIdentityService _userService;
  final String _roomId;
  
  StreamSubscription? _messageSubscription;

  MessageService({
    required MessageDao messageDao,
    required UserIdentityService userService,
    required String roomId,
  })  : _messageDao = messageDao,
        _userService = userService,
        _roomId = roomId,
        super(const MessageListState(isLoading: true)) {
    _initialize();
  }

  /// 初始化 - 加载历史消息
  Future<void> _initialize() async {
    try {
      final messages = await _messageDao.getMessagesByRoom(_roomId);
      state = MessageListState(messages: messages);
      
      // 监听新消息
      _watchMessages();
    } catch (e) {
      state = MessageListState(error: '加载消息失败: $e');
    }
  }

  /// 监听消息变化
  void _watchMessages() {
    _messageSubscription = _messageDao.watchMessagesByRoom(_roomId).listen(
      (messages) {
        state = state.copyWith(messages: messages);
      },
      onError: (error) {
        state = state.copyWith(error: '监听消息失败: $error');
      },
    );
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String content) async {
    if (content.trim().isEmpty) return;

    final currentUser = _userService.state.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: '未登录用户');
      return;
    }

    try {
      final message = Message.createText(
        roomId: _roomId,
        senderId: currentUser.id,
        content: content.trim(),
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarData != null
            ? 'data:image/svg+xml;base64,${base64Encode(currentUser.avatarData!)}'
            : null,
      );

      await _messageDao.insertMessage(message);
      
      // 更新最后活动时间
      await _messageDao.updateRoomLastActivity(_roomId);
    } catch (e) {
      state = state.copyWith(error: '发送消息失败: $e');
    }
  }

  /// 发送图片消息
  Future<void> sendImageMessage(String filePath, {String? caption}) async {
    final currentUser = _userService.state.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: '未登录用户');
      return;
    }

    try {
      final message = Message.createImage(
        roomId: _roomId,
        senderId: currentUser.id,
        filePath: filePath,
        caption: caption,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarData != null
            ? 'data:image/svg+xml;base64,${base64Encode(currentUser.avatarData!)}'
            : null,
      );

      await _messageDao.insertMessage(message);
      await _messageDao.updateRoomLastActivity(_roomId);
    } catch (e) {
      state = state.copyWith(error: '发送图片失败: $e');
    }
  }

  /// 发送文件消息
  Future<void> sendFileMessage(String filePath, String fileName, int fileSize) async {
    final currentUser = _userService.state.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: '未登录用户');
      return;
    }

    try {
      final message = Message.createFile(
        roomId: _roomId,
        senderId: currentUser.id,
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarData != null
            ? 'data:image/svg+xml;base64,${base64Encode(currentUser.avatarData!)}'
            : null,
      );

      await _messageDao.insertMessage(message);
      await _messageDao.updateRoomLastActivity(_roomId);
    } catch (e) {
      state = state.copyWith(error: '发送文件失败: $e');
    }
  }

  /// 发送语音消息
  Future<void> sendVoiceMessage(String audioPath, int durationSeconds) async {
    final currentUser = _userService.state.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: '未登录用户');
      return;
    }

    try {
      final message = Message.createVoice(
        roomId: _roomId,
        senderId: currentUser.id,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
        senderName: currentUser.nickname,
        senderAvatarUrl: currentUser.avatarData != null
            ? 'data:image/svg+xml;base64,${base64Encode(currentUser.avatarData!)}'
            : null,
      );

      await _messageDao.insertMessage(message);
      await _messageDao.updateRoomLastActivity(_roomId);
    } catch (e) {
      state = state.copyWith(error: '发送语音失败: $e');
    }
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messageDao.deleteMessage(messageId);
    } catch (e) {
      state = state.copyWith(error: '删除消息失败: $e');
    }
  }

  /// 标记消息为已读
  Future<void> markAsRead(String messageId) async {
    try {
      await _messageDao.markMessageAsRead(messageId);
    } catch (e) {
      // 静默处理，不影响用户体验
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
