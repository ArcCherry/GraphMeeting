/// 消息数据访问对象 (DAO)

import 'package:sqflite/sqflite.dart';
import '../../models/chrono_vine/vine_node.dart';
import 'database_service.dart';

/// 消息 DAO
class MessageDao {
  final DatabaseService _db;
  
  MessageDao(this._db);
  
  Future<Database> get _database => _db.database;
  
  /// 创建消息
  Future<Message> createMessage(Message message) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableMessages,
      _messageToDb(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return message;
  }
  
  /// 批量创建消息
  Future<void> batchCreateMessages(List<Message> messages) async {
    final db = await _database;
    final batch = db.batch();
    
    for (final msg in messages) {
      batch.insert(
        DatabaseConfig.tableMessages,
        _messageToDb(msg),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }
  
  /// 获取消息
  Future<Message?> getMessage(String id) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _messageFromDb(maps.first);
  }
  
  /// 获取房间的所有消息
  Future<List<Message>> getMessagesForRoom(String roomId, {int limit = 100, int offset = 0}) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => _messageFromDb(m)).toList();
  }
  
  /// 获取节点的关联消息
  Future<Message?> getMessageForNode(String nodeId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'node_id = ?',
      whereArgs: [nodeId],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _messageFromDb(maps.first);
  }
  
  /// 获取未同步的消息
  Future<List<Message>> getUnsyncedMessages(String roomId, {int limit = 50}) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'room_id = ? AND is_synced = 0',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => _messageFromDb(m)).toList();
  }
  
  /// 获取回复某消息的消息
  Future<List<Message>> getReplies(String messageId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'reply_to_id = ?',
      whereArgs: [messageId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _messageFromDb(m)).toList();
  }
  
  /// 搜索消息
  Future<List<Message>> searchMessages(String roomId, String query) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'room_id = ? AND content LIKE ?',
      whereArgs: [roomId, '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => _messageFromDb(m)).toList();
  }
  
  /// 更新消息
  Future<int> updateMessage(Message message) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableMessages,
      _messageToDb(message),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }
  
  /// 标记消息已同步
  Future<int> markAsSynced(String messageId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableMessages,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
  
  /// 更新同步错误
  Future<int> updateSyncError(String messageId, String error) async {
    final db = await _database;
    return await db.rawUpdate('''
      UPDATE ${DatabaseConfig.tableMessages}
      SET sync_attempts = sync_attempts + 1,
          last_sync_error = ?
      WHERE id = ?
    ''', [error, messageId]);
  }
  
  /// 关联消息到节点
  Future<int> linkToNode(String messageId, String nodeId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableMessages,
      {'node_id': nodeId},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
  
  /// 删除消息
  Future<int> deleteMessage(String id) async {
    final db = await _database;
    return await db.delete(
      DatabaseConfig.tableMessages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// 删除房间的所有消息
  Future<int> deleteMessagesForRoom(String roomId) async {
    final db = await _database;
    return await db.delete(
      DatabaseConfig.tableMessages,
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  /// 插入消息（供MessageService使用）
  Future<void> insertMessage(Message message) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableMessages,
      _messageToDb(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取房间的所有消息（Stream，供监听使用）
  /// 使用轮询机制实现实时更新
  Stream<List<Message>> watchMessagesByRoom(String roomId) {
    // 初始查询 + 定期刷新
    return Stream.periodic(const Duration(milliseconds: 500))
        .asyncMap((_) async {
      final db = await _database;
      final maps = await db.query(
        DatabaseConfig.tableMessages,
        where: 'room_id = ?',
        whereArgs: [roomId],
        orderBy: 'timestamp ASC',
      );
      return maps.map((m) => _messageFromDb(m)).toList();
    })
        .distinct((a, b) => a.length == b.length); // 只在数量变化时通知
  }

  /// 获取房间的所有消息（简单查询）
  Future<List<Message>> getMessagesByRoom(String roomId, {int limit = 100}) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableMessages,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => _messageFromDb(m)).toList();
  }

  /// 标记消息为已读
  Future<int> markMessageAsRead(String messageId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableMessages,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// 更新房间最后活动时间
  Future<void> updateRoomLastActivity(String roomId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DatabaseConfig.tableRooms,
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }
  
  /// 获取消息统计
  Future<Map<String, dynamic>> getMessageStats(String roomId) async {
    final db = await _database;
    
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConfig.tableMessages} WHERE room_id = ?',
      [roomId],
    );
    
    final unsyncedResult = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConfig.tableMessages} WHERE room_id = ? AND is_synced = 0',
      [roomId],
    );
    
    final byAuthorResult = await db.rawQuery('''
      SELECT author_id, COUNT(*) as count 
      FROM ${DatabaseConfig.tableMessages} 
      WHERE room_id = ?
      GROUP BY author_id
    ''', [roomId]);
    
    return {
      'total': Sqflite.firstIntValue(totalResult) ?? 0,
      'unsynced': Sqflite.firstIntValue(unsyncedResult) ?? 0,
      'byAuthor': Map.fromEntries(byAuthorResult.map((r) => 
        MapEntry(r['author_id'] as String, r['count'] as int)
      )),
    };
  }
  
  // ========== 转换方法 ==========
  
  Map<String, dynamic> _messageToDb(Message message) {
    return {
      'id': message.id,
      'room_id': message.roomId,
      'node_id': message.nodeId,
      'author_id': message.authorId,
      'content': message.content,
      'content_type': message.contentType,
      'audio_path': message.audioPath,
      'audio_duration': message.audioDuration?.inMilliseconds,
      'reply_to_id': message.replyToId,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'is_synced': message.isSynced ? 1 : 0,
      'sync_attempts': message.syncAttempts,
      'last_sync_error': message.lastSyncError,
      'created_at': message.createdAt.millisecondsSinceEpoch,
    };
  }
  
  Message _messageFromDb(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      nodeId: map['node_id'] as String?,
      authorId: map['author_id'] as String,
      content: map['content'] as String,
      contentType: map['content_type'] as String? ?? 'text',
      audioPath: map['audio_path'] as String?,
      audioDuration: map['audio_duration'] != null 
          ? Duration(milliseconds: map['audio_duration'] as int)
          : null,
      replyToId: map['reply_to_id'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isSynced: (map['is_synced'] as int) == 1,
      syncAttempts: map['sync_attempts'] as int? ?? 0,
      lastSyncError: map['last_sync_error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
