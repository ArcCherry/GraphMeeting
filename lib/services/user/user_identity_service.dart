/// 用户身份服务（重构后）
/// 
/// 职责：仅负责用户身份的状态管理
/// 
/// 依赖：
/// - UserRepository: 用户数据访问
/// - AvatarGenerator: 头像生成
/// - ImageCompressor: 图片压缩

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user/user_profile.dart';
import '../avatar/avatar_generator.dart';
import '../database/database_providers.dart';
import '../media/image_compressor.dart';
import 'user_repository.dart';

/// 用户身份状态
class UserIdentityState {
  final UserProfile? currentUser;
  final UserSettings? settings;
  final bool isLoading;
  final String? error;

  const UserIdentityState({
    this.currentUser,
    this.settings,
    this.isLoading = false,
    this.error,
  });

  UserIdentityState copyWith({
    UserProfile? currentUser,
    UserSettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return UserIdentityState(
      currentUser: currentUser ?? this.currentUser,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isLoggedIn => currentUser != null;
}

/// 用户身份服务
class UserIdentityService extends StateNotifier<UserIdentityState> {
  final UserRepository _repository;
  final AvatarGenerator _avatarGenerator;
  final ImageCompressor _imageCompressor;

  UserIdentityService({
    required UserRepository repository,
    AvatarGenerator? avatarGenerator,
    ImageCompressor? imageCompressor,
  })  : _repository = repository,
        _avatarGenerator = avatarGenerator ?? const AvatarGenerator(),
        _imageCompressor = imageCompressor ?? const ImageCompressor(),
        super(const UserIdentityState(isLoading: true));

  /// 初始化 - 加载本地用户
  Future<void> initialize() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final localUser = await _repository.getLocalUser();

      if (localUser != null) {
        final settings = await _repository.getSettings(localUser.id);
        state = UserIdentityState(
          currentUser: localUser,
          settings: settings,
          isLoading: false,
        );
      } else {
        state = const UserIdentityState(isLoading: false);
      }
    } catch (e, stackTrace) {
      debugPrint('初始化用户身份失败: $e');
      debugPrint('堆栈: $stackTrace');
      state = UserIdentityState(
        isLoading: false,
        error: '初始化用户身份失败: $e',
      );
    }
  }

  /// 创建新用户
  Future<void> createUser({
    required String nickname,
    AvatarType avatarType = AvatarType.generated,
    Uint8List? avatarData,
    int accentColor = 0xFF0078D4,
    String? statusMessage,
    PresetAvatarStyle avatarStyle = PresetAvatarStyle.modern,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // 生成头像（如果需要）
      Uint8List? finalAvatarData = avatarData;
      if (avatarType == AvatarType.generated && avatarData == null) {
        try {
          finalAvatarData = await _avatarGenerator.generateIdenticon(
            nickname,
            accentColor,
          );
        } catch (e) {
          debugPrint('头像生成失败: $e');
          finalAvatarData = null;
        }
      }

      // 创建用户
      final user = await _repository.createUser(
        nickname: nickname,
        avatarType: avatarType,
        avatarData: finalAvatarData,
        accentColor: accentColor,
        statusMessage: statusMessage,
        avatarStyle: avatarStyle,
      );

      // 获取设置
      final settings = await _repository.getSettings(user.id);

      state = UserIdentityState(
        currentUser: user,
        settings: settings,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('创建用户失败: $e');
      debugPrint('堆栈: $stackTrace');
      state = UserIdentityState(
        currentUser: state.currentUser,
        settings: state.settings,
        isLoading: false,
        error: '创建用户失败: $e',
      );
    }
  }

  /// 更新用户资料
  Future<void> updateProfile({
    String? nickname,
    int? accentColor,
    String? statusMessage,
    PresetAvatarStyle? avatarStyle,
  }) async {
    final currentUser = state.currentUser;
    if (currentUser == null) return;

    try {
      final updated = await _repository.updateProfile(
        currentUser,
        nickname: nickname,
        accentColor: accentColor,
        statusMessage: statusMessage,
        avatarStyle: avatarStyle,
      );

      state = state.copyWith(currentUser: updated);
    } catch (e) {
      state = state.copyWith(error: '更新资料失败: $e');
    }
  }

  /// 更新头像（自定义图片）
  Future<void> updateAvatar(Uint8List imageData) async {
    final currentUser = state.currentUser;
    if (currentUser == null) return;

    try {
      // 压缩图片
      final compressed = await _imageCompressor.compress(
        imageData,
        config: CompressionConfig.avatar,
      );

      final updated = await _repository.updateAvatar(currentUser, compressed);
      state = state.copyWith(currentUser: updated);
    } catch (e) {
      state = state.copyWith(error: '更新头像失败: $e');
    }
  }

  /// 更新头像 URL（网络图片）
  Future<void> updateAvatarUrl(String url) async {
    final currentUser = state.currentUser;
    if (currentUser == null) return;

    try {
      final updated = await _repository.updateAvatarUrl(currentUser, url);
      state = state.copyWith(currentUser: updated);
    } catch (e) {
      state = state.copyWith(error: '更新头像失败: $e');
    }
  }

  /// 重新生成头像
  Future<void> regenerateAvatar() async {
    final currentUser = state.currentUser;
    if (currentUser == null) return;

    try {
      final newAvatar = await _avatarGenerator.generateIdenticon(
        currentUser.nickname,
        currentUser.accentColor,
      );

      final updated = await _repository.updateAvatar(currentUser, newAvatar);
      state = state.copyWith(currentUser: updated);
    } catch (e) {
      state = state.copyWith(error: '重新生成头像失败: $e');
    }
  }

  /// 更新设置
  Future<void> updateSettings(UserSettings settings) async {
    try {
      await _repository.updateSettings(settings);
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: '更新设置失败: $e');
    }
  }

  /// 切换主题
  Future<void> setThemeMode(AppThemeMode mode) async {
    final settings = state.settings;
    if (settings == null) return;

    await updateSettings(settings.copyWith(themeMode: mode));
  }

  /// 登出
  Future<void> logout() async {
    final currentUser = state.currentUser;
    if (currentUser == null) return;

    try {
      await _repository.deleteUser(currentUser.id);
      state = const UserIdentityState();
    } catch (e) {
      state = state.copyWith(error: '登出失败: $e');
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider 导出
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final userDao = ref.watch(userDaoProvider);
  return UserRepository(userDao);
});

final userIdentityServiceProvider =
    StateNotifierProvider<UserIdentityService, UserIdentityState>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UserIdentityService(repository: repository);
});

final currentUserProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userIdentityServiceProvider).currentUser;
});

final currentUserSettingsProvider = Provider<UserSettings?>((ref) {
  return ref.watch(userIdentityServiceProvider).settings;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(userIdentityServiceProvider).isLoggedIn;
});

/// 头像生成器 Provider
final avatarGeneratorProvider = Provider<AvatarGenerator>((ref) {
  return const AvatarGenerator();
});

/// 图片压缩器 Provider
final imageCompressorProvider = Provider<ImageCompressor>((ref) {
  return const ImageCompressor();
});
