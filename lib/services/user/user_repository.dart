/// 用户仓储
/// 
/// 封装用户数据的业务逻辑访问，是 DAO 的上层抽象。
/// 负责：
/// - 用户 CRUD 的业务逻辑封装
/// - 多数据源协调（本地数据库 + 缓存）
/// - 事务管理

import 'dart:typed_data';
import '../../models/user/user_profile.dart';
import '../database/user_dao.dart';

/// 用户仓储
class UserRepository {
  final UserDao _userDao;

  UserRepository(this._userDao);

  /// 获取本地用户（当前登录用户）
  /// 
  /// 如果没有则返回 null
  Future<UserProfile?> getLocalUser() async {
    return await _userDao.getLocalUser();
  }

  /// 获取或创建本地用户
  /// 
  /// 如果没有本地用户，创建一个默认的访客用户
  Future<UserProfile> getOrCreateLocalUser() async {
    var user = await _userDao.getLocalUser();
    if (user != null) return user;

    // 创建默认访客用户
    user = UserProfile.create(
      nickname: '访客${DateTime.now().millisecondsSinceEpoch % 10000}',
      avatarType: AvatarType.generated,
    );

    await _userDao.createUser(user);
    return user;
  }

  /// 创建新用户
  Future<UserProfile> createUser({
    required String nickname,
    AvatarType avatarType = AvatarType.generated,
    Uint8List? avatarData,
    int accentColor = 0xFF0078D4,
    String? statusMessage,
    PresetAvatarStyle avatarStyle = PresetAvatarStyle.modern,
  }) async {
    final user = UserProfile.create(
      nickname: nickname,
      avatarType: avatarType,
      avatarData: avatarData,
      accentColor: accentColor,
      statusMessage: statusMessage,
      avatarStyle: avatarStyle,
    );

    await _userDao.createUser(user);
    return user;
  }

  /// 更新用户资料
  Future<UserProfile> updateProfile(
    UserProfile user, {
    String? nickname,
    int? accentColor,
    String? statusMessage,
    PresetAvatarStyle? avatarStyle,
  }) async {
    final updated = user.copyWith(
      nickname: nickname,
      accentColor: accentColor,
      statusMessage: statusMessage,
      avatarStyle: avatarStyle,
    );

    await _userDao.updateUser(updated);
    return updated;
  }

  /// 更新头像（自定义图片）
  Future<UserProfile> updateAvatar(
    UserProfile user,
    Uint8List avatarData,
  ) async {
    await _userDao.updateAvatar(user.id, avatarData);

    return user.copyWith(
      avatarType: AvatarType.custom,
      avatarData: avatarData,
      avatarUrl: null,
    );
  }

  /// 更新头像 URL（网络图片）
  Future<UserProfile> updateAvatarUrl(
    UserProfile user,
    String url,
  ) async {
    await _userDao.updateAvatarUrl(user.id, url);

    return user.copyWith(
      avatarType: AvatarType.network,
      avatarUrl: url,
      avatarData: null,
    );
  }

  /// 删除用户
  Future<void> deleteUser(String userId) async {
    await _userDao.deleteUser(userId);
  }

  /// 搜索用户
  Future<List<UserProfile>> searchUsers(String query) async {
    return await _userDao.searchUsers(query);
  }

  /// 获取用户设置
  Future<UserSettings> getSettings(String userId) async {
    return await _userDao.getOrCreateSettings(userId);
  }

  /// 更新设置
  Future<void> updateSettings(UserSettings settings) async {
    await _userDao.updateSettings(settings);
  }
}
