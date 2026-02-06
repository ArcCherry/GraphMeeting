/// Riverpod Providers for Database

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import 'user_dao.dart';
import 'room_dao.dart';
import 'node_dao.dart';
import 'message_dao.dart';

/// 数据库服务 Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 用户 DAO Provider
final userDaoProvider = Provider<UserDao>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return UserDao(db);
});

/// 房间 DAO Provider
final roomDaoProvider = Provider<RoomDao>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return RoomDao(db);
});

/// 节点 DAO Provider
final nodeDaoProvider = Provider<NodeDao>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return NodeDao(db);
});

/// 消息 DAO Provider
final messageDaoProvider = Provider<MessageDao>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return MessageDao(db);
});

/// 数据库信息 Provider（调试用）
final databaseInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getDatabaseInfo();
});
