/// 用户数据访问对象 (DAO)
/// 
/// 处理用户相关的数据库操作

import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../../models/user/user_profile.dart';
import 'database_service.dart';

/// 用户 DAO
class UserDao {
  final DatabaseService _db;
  
  UserDao(this._db);
  
  /// 获取数据库实例
  Future<Database> get _database => _db.database;
  
  // ========== CRUD 操作 ==========
  
  /// 创建用户
  Future<UserProfile> createUser(UserProfile user) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableUsers,
      user.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return user;
  }
  
  /// 根据 ID 获取用户
  Future<UserProfile?> getUserById(String id) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return UserProfile.fromDb(maps.first);
  }
  
  /// 获取本地用户
  Future<UserProfile?> getLocalUser() async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableUsers,
      where: 'is_local_user = 1',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return UserProfile.fromDb(maps.first);
  }
  
  /// 获取所有用户
  Future<List<UserProfile>> getAllUsers() async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableUsers,
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => UserProfile.fromDb(m)).toList();
  }
  
  /// 搜索用户
  Future<List<UserProfile>> searchUsers(String query) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableUsers,
      where: 'nickname LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'nickname ASC',
    );
    return maps.map((m) => UserProfile.fromDb(m)).toList();
  }
  
  /// 更新用户
  Future<int> updateUser(UserProfile user) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableUsers,
      user.copyWith().toDb(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
  
  /// 更新用户头像
  Future<int> updateAvatar(String userId, Uint8List avatarData) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableUsers,
      {
        'avatar_data': avatarData,
        'avatar_type': AvatarType.custom.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
  
  /// 更新用户头像 URL
  Future<int> updateAvatarUrl(String userId, String url) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableUsers,
      {
        'avatar_url': url,
        'avatar_type': AvatarType.network.name,
        'avatar_data': null, // 清除本地数据
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
  
  /// 删除用户
  Future<int> deleteUser(String id) async {
    final db = await _database;
    return await db.delete(
      DatabaseConfig.tableUsers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// 批量插入/更新用户（用于同步）
  Future<void> batchUpsertUsers(List<UserProfile> users) async {
    final db = await _database;
    final batch = db.batch();
    
    for (final user in users) {
      batch.insert(
        DatabaseConfig.tableUsers,
        user.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }
  
  // ========== 用户设置 ==========
  
  /// 创建设置
  Future<void> createSettings(UserSettings settings) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableUserSettings,
      settings.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// 获取设置
  Future<UserSettings?> getSettings(String userId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableUserSettings,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return UserSettings.fromDb(maps.first);
  }
  
  /// 更新设置
  Future<int> updateSettings(UserSettings settings) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableUserSettings,
      settings.toDb(),
      where: 'user_id = ?',
      whereArgs: [settings.userId],
    );
  }
  
  /// 获取或创建设置
  Future<UserSettings> getOrCreateSettings(String userId) async {
    var settings = await getSettings(userId);
    if (settings == null) {
      settings = UserSettings(userId: userId);
      await createSettings(settings);
    }
    return settings;
  }
  
  // ========== 统计 ==========
  
  /// 获取用户总数
  Future<int> getUserCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConfig.tableUsers}'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// 获取参与最多会议的用户（Top N）
  Future<List<Map<String, dynamic>>> getMostActiveUsers(int limit) async {
    final db = await _database;
    return await db.rawQuery('''
      SELECT u.id, u.nickname, u.avatar_url, COUNT(rp.room_id) as room_count
      FROM ${DatabaseConfig.tableUsers} u
      JOIN room_participants rp ON u.id = rp.user_id
      GROUP BY u.id
      ORDER BY room_count DESC
      LIMIT ?
    ''', [limit]);
  }
}
