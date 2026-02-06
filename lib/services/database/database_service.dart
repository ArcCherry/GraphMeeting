/// SQLite 数据库服务 - 全平台支持
/// 
/// 平台适配策略：
/// - iOS/Android: 使用 sqflite 原生实现
/// - macOS/Windows/Linux: 使用 sqflite_common_ffi
/// - Web: 使用 sqflite_common_ffi_web (IndexedDB 后端)

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:sqflite/sqflite.dart' show Database, Transaction;

/// 数据库配置
class DatabaseConfig {
  static const String dbName = 'graphmeeting.db';
  static const int dbVersion = 3;
  
  /// 表名常量
  static const String tableUsers = 'users';
  static const String tableRooms = 'rooms';
  static const String tableNodes = 'nodes';
  static const String tableMessages = 'messages';
  static const String tableAttachments = 'attachments';
  static const String tableSyncState = 'sync_state';
  static const String tableUserSettings = 'user_settings';
}

/// 数据库服务
class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  static bool _initialized = false;
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  /// 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  /// 初始化数据库（平台自适应）
  Future<Database> _initDatabase() async {
    if (!_initialized) {
      await _setupPlatform();
      _initialized = true;
    }
    
    final dbPath = await _getDatabasePath();
    
    return await openDatabase(
      dbPath,
      version: DatabaseConfig.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }
  
  /// 平台特定设置
  Future<void> _setupPlatform() async {
    if (kIsWeb) {
      // Web: 使用内存数据库（SQLite 在 Web 上需要特殊配置）
      // 在生产环境中，应该使用 IndexedDB 或其他 Web 存储方案
      databaseFactory = databaseFactoryFfi;
    } else if (!Platform.isIOS && !Platform.isAndroid) {
      // 桌面端: 初始化 FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // iOS/Android: 使用默认的 sqflite 实现，无需额外配置
  }
  
  /// 获取数据库路径
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // Web: 使用内存数据库名称（实际存储在 IndexedDB）
      return DatabaseConfig.dbName;
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final dbDir = Directory(join(directory.path, 'GraphMeeting'));
    
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    return join(dbDir.path, DatabaseConfig.dbName);
  }
  
  /// 数据库配置
  Future<void> _onConfigure(Database db) async {
    // 启用外键支持
    await db.execute('PRAGMA foreign_keys = ON');
  }
  
  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    
    // ========== 用户表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableUsers} (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        avatar_type TEXT DEFAULT 'generated',
        avatar_url TEXT,
        avatar_data BLOB,
        accent_color INTEGER DEFAULT 4280072260,
        status_message TEXT,
        avatar_style TEXT DEFAULT 'modern',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_local_user INTEGER DEFAULT 0
      )
    ''');
    
    // 创建索引
    batch.execute('''
      CREATE INDEX idx_users_nickname ON ${DatabaseConfig.tableUsers}(nickname)
    ''');
    
    // ========== 用户设置表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableUserSettings} (
        user_id TEXT PRIMARY KEY,
        theme_mode TEXT DEFAULT 'system',
        language TEXT DEFAULT 'zh-CN',
        audio_quality TEXT DEFAULT 'high',
        auto_sync INTEGER DEFAULT 1,
        notification_enabled INTEGER DEFAULT 1,
        default_avatar_style TEXT DEFAULT 'modern',
        FOREIGN KEY (user_id) REFERENCES ${DatabaseConfig.tableUsers}(id) ON DELETE CASCADE
      )
    ''');
    
    // ========== 房间表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableRooms} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        host_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        archived_at INTEGER,
        is_archived INTEGER DEFAULT 0,
        network_mode TEXT DEFAULT 'p2p',
        server_address TEXT,
        access_code TEXT,
        max_participants INTEGER DEFAULT 50,
        settings_json TEXT
      )
    ''');
    
    batch.execute('''
      CREATE INDEX idx_rooms_host ON ${DatabaseConfig.tableRooms}(host_id)
    ''');
    batch.execute('''
      CREATE INDEX idx_rooms_archived ON ${DatabaseConfig.tableRooms}(is_archived)
    ''');
    
    // ========== 房间参与者关联表 ==========
    batch.execute('''
      CREATE TABLE room_participants (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        left_at INTEGER,
        role TEXT DEFAULT 'participant',
        is_active INTEGER DEFAULT 1,
        last_seen_at INTEGER,
        PRIMARY KEY (room_id, user_id),
        FOREIGN KEY (room_id) REFERENCES ${DatabaseConfig.tableRooms}(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseConfig.tableUsers}(id) ON DELETE CASCADE
      )
    ''');
    
    // ========== 节点表 (Chrono-Vine) ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableNodes} (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        message_id TEXT,
        author_id TEXT NOT NULL,
        parent_id TEXT,
        content TEXT NOT NULL,
        content_preview TEXT,
        node_type TEXT DEFAULT 'message',
        status TEXT DEFAULT 'draft',
        timestamp INTEGER NOT NULL,
        thread_depth INTEGER DEFAULT 0,
        pos_x REAL DEFAULT 0,
        pos_y REAL DEFAULT 0,
        pos_z REAL DEFAULT 0,
        geometry_type TEXT DEFAULT 'voiceBlock',
        material_state TEXT,
        lamport INTEGER DEFAULT 0,
        vector_clock TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (room_id) REFERENCES ${DatabaseConfig.tableRooms}(id) ON DELETE CASCADE,
        FOREIGN KEY (author_id) REFERENCES ${DatabaseConfig.tableUsers}(id) ON DELETE CASCADE,
        FOREIGN KEY (parent_id) REFERENCES ${DatabaseConfig.tableNodes}(id) ON DELETE SET NULL
      )
    ''');
    
    batch.execute('''
      CREATE INDEX idx_nodes_room ON ${DatabaseConfig.tableNodes}(room_id)
    ''');
    batch.execute('''
      CREATE INDEX idx_nodes_author ON ${DatabaseConfig.tableNodes}(author_id)
    ''');
    batch.execute('''
      CREATE INDEX idx_nodes_parent ON ${DatabaseConfig.tableNodes}(parent_id)
    ''');
    batch.execute('''
      CREATE INDEX idx_nodes_timestamp ON ${DatabaseConfig.tableNodes}(timestamp)
    ''');
    
    // ========== 消息表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableMessages} (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        node_id TEXT,
        author_id TEXT NOT NULL,
        content TEXT NOT NULL,
        content_type TEXT DEFAULT 'text',
        audio_path TEXT,
        audio_duration INTEGER,
        reply_to_id TEXT,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0,
        last_sync_error TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (room_id) REFERENCES ${DatabaseConfig.tableRooms}(id) ON DELETE CASCADE,
        FOREIGN KEY (author_id) REFERENCES ${DatabaseConfig.tableUsers}(id) ON DELETE CASCADE,
        FOREIGN KEY (node_id) REFERENCES ${DatabaseConfig.tableNodes}(id) ON DELETE SET NULL
      )
    ''');
    
    batch.execute('''
      CREATE INDEX idx_messages_room ON ${DatabaseConfig.tableMessages}(room_id)
    ''');
    batch.execute('''
      CREATE INDEX idx_messages_node ON ${DatabaseConfig.tableMessages}(node_id)
    ''');
    
    // ========== 附件表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableAttachments} (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT,
        file_data BLOB,
        file_size INTEGER,
        mime_type TEXT,
        width INTEGER,
        height INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (message_id) REFERENCES ${DatabaseConfig.tableMessages}(id) ON DELETE CASCADE
      )
    ''');
    
    // ========== 叶子附件表 (AI 生成) ==========
    batch.execute('''
      CREATE TABLE leaf_attachments (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        leaf_type TEXT DEFAULT 'summary',
        title TEXT NOT NULL,
        content TEXT,
        relevance_score REAL DEFAULT 0.5,
        generated_at INTEGER NOT NULL,
        ai_model_version TEXT,
        is_pinned INTEGER DEFAULT 0,
        FOREIGN KEY (node_id) REFERENCES ${DatabaseConfig.tableNodes}(id) ON DELETE CASCADE
      )
    ''');
    
    batch.execute('''
      CREATE INDEX idx_leaves_node ON leaf_attachments(node_id)
    ''');
    
    // ========== Todo 项表 ==========
    batch.execute('''
      CREATE TABLE todo_items (
        id TEXT PRIMARY KEY,
        leaf_id TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT DEFAULT 'medium',
        assignee_id TEXT,
        deadline INTEGER,
        is_completed INTEGER DEFAULT 0,
        completed_at INTEGER,
        source_message_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (leaf_id) REFERENCES leaf_attachments(id) ON DELETE CASCADE,
        FOREIGN KEY (assignee_id) REFERENCES ${DatabaseConfig.tableUsers}(id) ON DELETE SET NULL
      )
    ''');
    
    // ========== 同步状态表 ==========
    batch.execute('''
      CREATE TABLE ${DatabaseConfig.tableSyncState} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_version INTEGER DEFAULT 1,
        remote_version INTEGER,
        last_sync_at INTEGER,
        sync_status TEXT DEFAULT 'pending',
        conflict_data TEXT,
        UNIQUE(entity_type, entity_id)
      )
    ''');
    
    batch.execute('''
      CREATE INDEX idx_sync_entity ON ${DatabaseConfig.tableSyncState}(entity_type, entity_id)
    ''');
    
    await batch.commit(noResult: true);
  }
  
  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1/v2 -> v3: 添加缺失的字段到 users 表
    if (oldVersion < 3) {
      // 添加 avatar_type 字段
      try {
        await db.execute('''
          ALTER TABLE ${DatabaseConfig.tableUsers} 
          ADD COLUMN avatar_type TEXT DEFAULT 'generated'
        ''');
        debugPrint('已添加 avatar_type 列');
      } catch (e) {
        debugPrint('添加 avatar_type 列时出错 (可能已存在): $e');
      }
      
      // 添加 avatar_style 字段
      try {
        await db.execute('''
          ALTER TABLE ${DatabaseConfig.tableUsers} 
          ADD COLUMN avatar_style TEXT DEFAULT 'modern'
        ''');
        debugPrint('已添加 avatar_style 列');
      } catch (e) {
        debugPrint('添加 avatar_style 列时出错 (可能已存在): $e');
      }
    }
  }
  
  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
  
  /// 删除数据库（调试用）
  Future<void> deleteDatabase() async {
    await close();
    final dbPath = await _getDatabasePath();
    if (!kIsWeb) {
      await databaseFactory.deleteDatabase(dbPath);
    }
  }
  
  /// 获取数据库信息
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
    );
    
    Map<String, int> tableCounts = {};
    for (var table in tables) {
      final name = table['name'] as String;
      if (!name.startsWith('sqlite_') && !name.startsWith('android_')) {
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM "$name"')
        ) ?? 0;
        tableCounts[name] = count;
      }
    }
    
    return {
      'path': await _getDatabasePath(),
      'version': DatabaseConfig.dbVersion,
      'tables': tableCounts,
    };
  }
}
