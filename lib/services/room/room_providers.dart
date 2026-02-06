/// 房间相关的 Riverpod Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room.dart';
import '../database/database_providers.dart';
import '../user/user_identity_service.dart';
import 'room_repository.dart' show RoomRepository, NetworkMode;

/// 房间仓储 Provider
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final roomDao = ref.watch(roomDaoProvider);
  return RoomRepository(roomDao);
});

/// 当前用户房间列表 StateNotifier
class RoomListNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final RoomRepository _repository;
  final String? _userId;

  RoomListNotifier(this._repository, this._userId) : super(const AsyncValue.loading()) {
    if (_userId != null) {
      loadRooms();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  /// 加载房间列表
  Future<void> loadRooms() async {
    if (_userId == null) return;
    
    state = const AsyncValue.loading();
    try {
      final rooms = await _repository.getActiveRoomsForUser(_userId);
      state = AsyncValue.data(rooms);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 搜索房间
  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final rooms = await _repository.searchRooms(query);
      state = AsyncValue.data(rooms);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 创建新房间
  Future<Room> createRoom({
    required String name,
    String? description,
    String networkMode = 'p2p',
  }) async {
    if (_userId == null) throw Exception('用户未登录');
    
    // 转换 networkMode string 为 enum
    final mode = networkMode == 'server' ? NetworkMode.server : NetworkMode.p2p;
    
    try {
      final room = await _repository.createRoom(
        name: name,
        hostId: _userId,
        description: description,
        networkMode: mode,
      );
      // 刷新列表
      await loadRooms();
      return room;
    } catch (e) {
      throw Exception('创建房间失败: $e');
    }
  }

  /// 加入房间
  Future<void> joinRoom(String roomId) async {
    if (_userId == null) throw Exception('用户未登录');
    
    try {
      await _repository.joinRoom(roomId, _userId);
      await loadRooms();
    } catch (e) {
      throw Exception('加入房间失败: $e');
    }
  }

  /// 通过访问码加入
  Future<Room> joinByCode(String code) async {
    if (_userId == null) throw Exception('用户未登录');
    
    try {
      final room = await _repository.joinByAccessCode(code, _userId);
      await loadRooms();
      return room;
    } catch (e) {
      throw Exception('加入房间失败: $e');
    }
  }

  /// 归档房间
  Future<void> archiveRoom(String roomId) async {
    try {
      await _repository.archiveRoom(roomId);
      await loadRooms();
    } catch (e) {
      throw Exception('归档房间失败: $e');
    }
  }

  /// 删除房间
  Future<void> deleteRoom(String roomId) async {
    try {
      await _repository.deleteRoom(roomId);
      await loadRooms();
    } catch (e) {
      throw Exception('删除房间失败: $e');
    }
  }

  /// 初始化示例数据
  Future<void> initializeSampleData() async {
    if (_userId == null) return;
    
    try {
      await _repository.createSampleRooms(_userId);
      await loadRooms();
    } catch (e) {
      // 忽略错误，可能已有数据
    }
  }
}

/// 房间列表 Provider
final roomListProvider = StateNotifierProvider<RoomListNotifier, AsyncValue<List<Room>>>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return RoomListNotifier(repository, user?.id);
});

/// 当前选中房间 Provider
final selectedRoomProvider = StateProvider<Room?>((ref) => null);

/// 房间搜索关键词 Provider
final roomSearchQueryProvider = StateProvider<String>((ref) => '');

/// 是否显示归档房间 Provider
final showArchivedRoomsProvider = StateProvider<bool>((ref) => false);


