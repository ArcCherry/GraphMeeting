/// 房间数据访问对象 (DAO)

import 'package:sqflite/sqflite.dart';
import '../../models/room.dart';
import 'database_service.dart';

/// 房间 DAO
class RoomDao {
  final DatabaseService _db;
  
  RoomDao(this._db);
  
  Future<Database> get _database => _db.database;
  
  /// 创建房间
  Future<Room> createRoom(Room room) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableRooms,
      room.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return room;
  }
  
  /// 获取房间
  Future<Room?> getRoom(String id) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableRooms,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Room.fromDb(maps.first);
  }
  
  /// 获取所有活跃房间
  Future<List<Room>> getActiveRooms() async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableRooms,
      where: 'is_archived = 0',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Room.fromDb(m)).toList();
  }
  
  /// 获取归档房间
  Future<List<Room>> getArchivedRooms() async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableRooms,
      where: 'is_archived = 1',
      orderBy: 'archived_at DESC',
    );
    return maps.map((m) => Room.fromDb(m)).toList();
  }
  
  /// 搜索房间
  Future<List<Room>> searchRooms(String query) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableRooms,
      where: 'name LIKE ? AND is_archived = 0',
      whereArgs: ['%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Room.fromDb(m)).toList();
  }
  
  /// 更新房间
  Future<int> updateRoom(Room room) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableRooms,
      room.toDb(),
      where: 'id = ?',
      whereArgs: [room.id],
    );
  }
  
  /// 归档房间
  Future<int> archiveRoom(String roomId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableRooms,
      {
        'is_archived': 1,
        'archived_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }
  
  /// 恢复房间
  Future<int> unarchiveRoom(String roomId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableRooms,
      {
        'is_archived': 0,
        'archived_at': null,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }
  
  /// 删除房间
  Future<int> deleteRoom(String roomId) async {
    final db = await _database;
    return await db.delete(
      DatabaseConfig.tableRooms,
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }
  
  /// 添加参与者
  Future<void> addParticipant(String roomId, String userId, {String role = 'participant'}) async {
    final db = await _database;
    await db.insert(
      'room_participants',
      {
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().millisecondsSinceEpoch,
        'role': role,
        'is_active': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// 移除参与者
  Future<int> removeParticipant(String roomId, String userId) async {
    final db = await _database;
    return await db.update(
      'room_participants',
      {
        'left_at': DateTime.now().millisecondsSinceEpoch,
        'is_active': 0,
      },
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
  }
  
  /// 获取房间参与者
  Future<List<Map<String, dynamic>>> getParticipants(String roomId) async {
    final db = await _database;
    return await db.rawQuery('''
      SELECT u.id, u.nickname, u.avatar_url, u.accent_color, 
             rp.role, rp.joined_at, rp.is_active
      FROM ${DatabaseConfig.tableUsers} u
      JOIN room_participants rp ON u.id = rp.user_id
      WHERE rp.room_id = ?
      ORDER BY rp.joined_at ASC
    ''', [roomId]);
  }
  
  /// 获取用户的房间列表
  Future<List<Room>> getRoomsForUser(String userId) async {
    final db = await _database;
    final maps = await db.rawQuery('''
      SELECT r.* FROM ${DatabaseConfig.tableRooms} r
      JOIN room_participants rp ON r.id = rp.room_id
      WHERE rp.user_id = ? AND rp.is_active = 1 AND r.is_archived = 0
      ORDER BY r.updated_at DESC
    ''', [userId]);
    return maps.map((m) => Room.fromDb(m)).toList();
  }
  
}

/// Room 模型扩展
extension RoomFields on Room {
  static Room create({
    required String name,
    required String hostId,
    String? description,
    String networkMode = 'p2p',
    String? serverAddress,
    String? accessCode,
    int maxParticipants = 50,
  }) {
    final now = DateTime.now();
    return Room(
      id: 'room_${now.millisecondsSinceEpoch}_$hostId',
      name: name,
      description: description,
      hostId: hostId,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      networkMode: networkMode,
      serverAddress: serverAddress,
      accessCode: accessCode,
      maxParticipants: maxParticipants,
    );
  }
}
