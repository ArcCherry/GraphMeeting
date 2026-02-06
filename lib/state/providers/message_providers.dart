import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chrono_vine/vine_node.dart';
import '../../services/database/database_providers.dart';
import '../../services/database/message_dao.dart';
import '../../services/message/message_service.dart';
import '../../services/user/user_identity_service.dart';

/// MessageDao Provider
final messageDaoProvider = Provider<MessageDao>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return MessageDao(dbService);
});

/// 房间消息列表 Provider（按房间ID）
final roomMessagesProvider = StateNotifierProvider.family<MessageService, MessageListState, String>(
  (ref, roomId) {
    final messageDao = ref.watch(messageDaoProvider);
    final userService = ref.watch(userIdentityServiceProvider.notifier);
    return MessageService(
      messageDao: messageDao,
      userService: userService,
      roomId: roomId,
    );
  },
);

/// 当前房间消息列表（简化版，用于当前选中的房间）
final currentRoomMessagesProvider = Provider<List<Message>>((ref) {
  final currentRoomId = ref.watch(currentRoomIdProvider);
  if (currentRoomId == null) return [];
  
  final messageService = ref.watch(roomMessagesProvider(currentRoomId));
  return messageService.messages;
});

/// 当前房间ID Provider
final currentRoomIdProvider = StateProvider<String?>((ref) => null);

/// 设置当前房间
final setCurrentRoomProvider = Provider<Function(String)>((ref) {
  return (String roomId) {
    ref.read(currentRoomIdProvider.notifier).state = roomId;
  };
});
