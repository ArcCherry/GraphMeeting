/// 房间仓储
/// 
/// 封装房间数据的业务逻辑访问

import '../../models/room.dart';
import '../database/room_dao.dart';

export '../../models/room.dart' show NetworkMode;

/// 房间仓储
class RoomRepository {
  final RoomDao _roomDao;

  RoomRepository(this._roomDao);

  /// 创建新房间
  /// 
  /// [name] 房间名称
  /// [hostId] 房主ID
  /// [description] 房间描述（可选）
  /// [networkMode] 网络模式（默认p2p）
  Future<Room> createRoom({
    required String name,
    required String hostId,
    String? description,
    NetworkMode networkMode = NetworkMode.p2p,
    String? serverAddress,
    String? accessCode,
    int maxParticipants = 50,
  }) async {
    // 检查名称
    if (name.trim().isEmpty) {
      throw RoomException('房间名称不能为空');
    }
    if (name.trim().length > 50) {
      throw RoomException('房间名称不能超过50个字符');
    }

    // 生成访问码（如果没有提供）
    final code = accessCode ?? _generateAccessCode();

    final room = Room.create(
      name: name.trim(),
      hostId: hostId,
      description: description?.trim(),
      networkMode: networkMode,
      serverAddress: serverAddress,
      accessCode: code,
      maxParticipants: maxParticipants,
    );

    // 保存到数据库
    await _roomDao.createRoom(room);
    
    // 房主自动成为参与者
    await _roomDao.addParticipant(room.id, hostId, role: 'owner');

    return room;
  }

  /// 获取房间详情
  Future<Room?> getRoom(String roomId) async {
    return await _roomDao.getRoom(roomId);
  }

  /// 获取用户的活跃房间列表
  Future<List<Room>> getActiveRoomsForUser(String userId) async {
    return await _roomDao.getRoomsForUser(userId);
  }

  /// 获取所有活跃房间（公开）
  Future<List<Room>> getAllActiveRooms() async {
    return await _roomDao.getActiveRooms();
  }

  /// 搜索房间
  Future<List<Room>> searchRooms(String query) async {
    if (query.trim().isEmpty) {
      return await _roomDao.getActiveRooms();
    }
    return await _roomDao.searchRooms(query.trim());
  }

  /// 更新房间信息
  Future<Room> updateRoom(
    Room room, {
    String? name,
    String? description,
    int? maxParticipants,
  }) async {
    final updated = room.copyWith(
      name: name,
      description: description,
      maxParticipants: maxParticipants,
      updatedAt: DateTime.now(),
    );

    await _roomDao.updateRoom(updated);
    return updated;
  }

  /// 归档房间
  Future<void> archiveRoom(String roomId) async {
    await _roomDao.archiveRoom(roomId);
  }

  /// 恢复房间
  Future<void> unarchiveRoom(String roomId) async {
    await _roomDao.unarchiveRoom(roomId);
  }

  /// 删除房间
  Future<void> deleteRoom(String roomId) async {
    await _roomDao.deleteRoom(roomId);
  }

  /// 用户加入房间
  Future<void> joinRoom(String roomId, String userId, {String role = 'member'}) async {
    // 检查房间是否存在
    final room = await _roomDao.getRoom(roomId);
    if (room == null) {
      throw RoomException('房间不存在');
    }

    // 检查是否已归档
    if (room.isArchived) {
      throw RoomException('房间已归档，无法加入');
    }

    // 检查人数限制
    final participants = await _roomDao.getParticipants(roomId);
    if (participants.length >= room.maxParticipants) {
      throw RoomException('房间已满');
    }

    // 添加参与者
    await _roomDao.addParticipant(roomId, userId, role: role);
  }

  /// 用户离开房间
  Future<void> leaveRoom(String roomId, String userId) async {
    await _roomDao.removeParticipant(roomId, userId);
  }

  /// 通过访问码加入房间
  Future<Room> joinByAccessCode(String code, String userId) async {
    // 搜索匹配的房间
    final rooms = await _roomDao.getActiveRooms();
    final room = rooms.firstWhere(
      (r) => r.accessCode?.toLowerCase() == code.trim().toLowerCase(),
      orElse: () => throw RoomException('访问码无效或房间不存在'),
    );

    await joinRoom(room.id, userId);
    return room;
  }

  /// 获取房间参与者列表
  Future<List<Map<String, dynamic>>> getParticipants(String roomId) async {
    return await _roomDao.getParticipants(roomId);
  }

  /// 生成访问码
  String _generateAccessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = StringBuffer();
    for (var i = 0; i < 6; i++) {
      code.write(chars[(DateTime.now().millisecond + i * 7) % chars.length]);
    }
    return code.toString();
  }

  /// 创建示例房间（用于首次使用）
  Future<void> createSampleRooms(String userId) async {
    final existingRooms = await _roomDao.getActiveRooms();
    if (existingRooms.isNotEmpty) return;

    // 创建示例房间
    await createRoom(
      name: '欢迎使用 GraphMeeting',
      hostId: userId,
      description: '这是一个示例房间，帮助你了解如何使用 GraphMeeting 进行异步协作',
      networkMode: NetworkMode.p2p,
    );

    await createRoom(
      name: '产品团队周会',
      hostId: userId,
      description: '每周产品迭代讨论，欢迎大家提交想法',
      networkMode: NetworkMode.p2p,
    );

    await createRoom(
      name: '技术架构讨论',
      hostId: userId,
      description: '关于系统架构、技术选型的长期讨论',
      networkMode: NetworkMode.server,
    );
  }
}

/// 房间异常
class RoomException implements Exception {
  final String message;

  const RoomException(this.message);

  @override
  String toString() => 'RoomException: $message';
}
