/// 节点数据访问对象 (DAO) - Chrono-Vine 核心数据

import 'package:sqflite/sqflite.dart';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/space_time_axis.dart';
import '../../models/chrono_vine/vine_node_extensions.dart';
import 'database_service.dart';

/// 节点 DAO
class NodeDao {
  final DatabaseService _db;
  
  NodeDao(this._db);
  
  Future<Database> get _database => _db.database;
  
  /// 创建节点
  Future<VineNodeData> createNode(VineNodeData node) async {
    final db = await _database;
    await db.insert(
      DatabaseConfig.tableNodes,
      _nodeToDb(node),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return node;
  }
  
  /// 批量创建节点
  Future<void> batchCreateNodes(List<VineNodeData> nodes) async {
    final db = await _database;
    final batch = db.batch();
    
    for (final node in nodes) {
      batch.insert(
        DatabaseConfig.tableNodes,
        _nodeToDb(node),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }
  
  /// 获取节点
  Future<VineNodeData?> getNode(String id) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _nodeFromDb(maps.first);
  }
  
  /// 获取房间的所有节点
  Future<List<VineNodeData>> getNodesForRoom(String roomId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND is_deleted = 0',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 获取时间范围内的节点
  Future<List<VineNodeData>> getNodesInTimeRange(
    String roomId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND timestamp BETWEEN ? AND ? AND is_deleted = 0',
      whereArgs: [roomId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 获取子节点
  Future<List<VineNodeData>> getChildNodes(String parentId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'parent_id = ? AND is_deleted = 0',
      whereArgs: [parentId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 获取特定类型的节点
  Future<List<VineNodeData>> getNodesByType(String roomId, NodeType type) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND node_type = ? AND is_deleted = 0',
      whereArgs: [roomId, type.name],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 获取特定状态的节点
  Future<List<VineNodeData>> getNodesByStatus(String roomId, NodeStatus status) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND status = ? AND is_deleted = 0',
      whereArgs: [roomId, status.name],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 获取用户的节点
  Future<List<VineNodeData>> getNodesByAuthor(String roomId, String authorId) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND author_id = ? AND is_deleted = 0',
      whereArgs: [roomId, authorId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 搜索节点内容
  Future<List<VineNodeData>> searchNodes(String roomId, String query) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND content LIKE ? AND is_deleted = 0',
      whereArgs: [roomId, '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  /// 更新节点
  Future<int> updateNode(VineNodeData node) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableNodes,
      _nodeToDb(node.copyWith(updatedAt: DateTime.now())),
      where: 'id = ?',
      whereArgs: [node.id],
    );
  }
  
  /// 更新节点状态
  Future<int> updateNodeStatus(String nodeId, NodeStatus status) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableNodes,
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }
  
  /// 更新节点位置
  Future<int> updateNodePosition(String nodeId, Offset3D position) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableNodes,
      {
        'pos_x': position.x,
        'pos_y': position.y,
        'pos_z': position.z,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }
  
  /// 软删除节点
  Future<int> softDeleteNode(String nodeId) async {
    final db = await _database;
    return await db.update(
      DatabaseConfig.tableNodes,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }
  
  /// 硬删除节点
  Future<int> hardDeleteNode(String nodeId) async {
    final db = await _database;
    return await db.delete(
      DatabaseConfig.tableNodes,
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }
  
  /// 获取房间节点统计
  Future<Map<String, int>> getRoomStats(String roomId) async {
    final db = await _database;
    
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConfig.tableNodes} WHERE room_id = ? AND is_deleted = 0',
      [roomId],
    );
    
    final byTypeResult = await db.rawQuery('''
      SELECT node_type, COUNT(*) as count 
      FROM ${DatabaseConfig.tableNodes} 
      WHERE room_id = ? AND is_deleted = 0
      GROUP BY node_type
    ''', [roomId]);
    
    final byAuthorResult = await db.rawQuery('''
      SELECT author_id, COUNT(*) as count 
      FROM ${DatabaseConfig.tableNodes} 
      WHERE room_id = ? AND is_deleted = 0
      GROUP BY author_id
    ''', [roomId]);
    
    return {
      'total': Sqflite.firstIntValue(totalResult) ?? 0,
      ...Map.fromEntries(byTypeResult.map((r) => 
        MapEntry('type_${r['node_type']}', r['count'] as int)
      )),
      ...Map.fromEntries(byAuthorResult.map((r) => 
        MapEntry('author_${r['author_id']}', r['count'] as int)
      )),
    };
  }
  
  /// 获取最新节点（用于增量同步）
  Future<List<VineNodeData>> getNodesAfter(
    String roomId,
    DateTime after,
    int limit,
  ) async {
    final db = await _database;
    final maps = await db.query(
      DatabaseConfig.tableNodes,
      where: 'room_id = ? AND updated_at > ? AND is_deleted = 0',
      whereArgs: [roomId, after.millisecondsSinceEpoch],
      orderBy: 'updated_at ASC',
      limit: limit,
    );
    return maps.map((m) => _nodeFromDb(m)).toList();
  }
  
  // ========== 转换方法 ==========
  
  Map<String, dynamic> _nodeToDb(VineNodeData node) {
    return {
      'id': node.id,
      'room_id': node.roomId,
      'message_id': node.messageId,
      'author_id': node.authorId,
      'parent_id': node.parentId,
      'content': node.content,
      'content_preview': node.contentPreview,
      'node_type': node.nodeType.name,
      'status': node.status.name,
      'timestamp': node.position.timestamp.millisecondsSinceEpoch,
      'thread_depth': node.position.threadDepth,
      'pos_x': node.position.layoutPosition.x,
      'pos_y': node.position.layoutPosition.y,
      'pos_z': node.position.layoutPosition.z,
      'geometry_type': node.geometry.type.name,
      'material_state': node.materialState != null ? _materialStateToJson(node.materialState!) : null,
      'lamport': node.lamport,
      'vector_clock': node.vectorClock?.toString(),
      'created_at': node.createdAt.millisecondsSinceEpoch,
      'updated_at': node.updatedAt.millisecondsSinceEpoch,
      'is_deleted': node.isDeleted ? 1 : 0,
    };
  }
  
  VineNodeData _nodeFromDb(Map<String, dynamic> map) {
    final typeName = map['geometry_type'] as String? ?? 'voiceBlock';
    final geometryType = GeometryType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => GeometryType.voiceBlock,
    );
    
    return VineNodeData(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      messageId: map['message_id'] as String?,
      authorId: map['author_id'] as String,
      parentId: map['parent_id'] as String?,
      content: map['content'] as String,
      contentPreview: map['content_preview'] as String?,
      nodeType: NodeType.values.byName(map['node_type'] as String),
      status: NodeStatus.values.byName(map['status'] as String),
      position: SpaceTimePoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        participantId: map['author_id'] as String,
        threadDepth: map['thread_depth'] as int? ?? 0,
        layoutPosition: Offset3D(
          x: (map['pos_x'] as num).toDouble(),
          y: (map['pos_y'] as num).toDouble(),
          z: (map['pos_z'] as num).toDouble(),
        ),
      ),
      geometry: _createGeometry(geometryType),
      materialState: map['material_state'] != null 
          ? _materialStateFromJson(map['material_state'] as String)
          : null,
      lamport: map['lamport'] as int? ?? 0,
      vectorClock: VectorClock.parse(map['vector_clock'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }
  
  NodeGeometry _createGeometry(GeometryType type) {
    switch (type) {
      case GeometryType.voiceBlock:
        return const NodeGeometry.voiceBlock(size: 1.0);
      case GeometryType.branchPoint:
        return const NodeGeometry.branchPoint(branches: 2);
      case GeometryType.mergeCrystal:
        return const NodeGeometry.mergeCrystal(facets: 6);
      case GeometryType.milestoneMonolith:
        return const NodeGeometry.milestoneMonolith();
      case GeometryType.aiFlower:
        return const NodeGeometry.aiFlower(petals: 5);
    }
  }
  
  String _materialStateToJson(MaterialState state) {
    return '{"progress":${state.buildProgress},"glow":${state.glowIntensity}}';
  }
  
  MaterialState? _materialStateFromJson(String json) {
    try {
      // 简化解析
      return const MaterialState();
    } catch (_) {
      return null;
    }
  }
}
