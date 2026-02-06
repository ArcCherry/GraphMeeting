/// 用户资料模型 - 像 Minecraft 一样的自定义身份系统
/// 
/// 支持：
/// - 自定义昵称和 ID
/// - 头像系统（预设头像/自定义图片/生成头像）
/// - 个性化配色
/// - 状态消息

import 'dart:convert';
import 'dart:typed_data';

/// 头像类型
enum AvatarType {
  /// 预设头像（内置图标）
  preset,
  /// 自定义上传图片
  custom,
  /// 基于昵称生成的头像（类似 GitHub identicon）
  generated,
  /// 网络图片 URL
  network,
}

/// 预设头像样式
enum PresetAvatarStyle {
  modern('现代', 'modern'),
  classic('经典', 'classic'),
  pixel('像素', 'pixel'),
  minimal('极简', 'minimal'),
  vibrant('鲜艳', 'vibrant');
  
  final String label;
  final String value;
  const PresetAvatarStyle(this.label, this.value);
  
  static PresetAvatarStyle fromString(String value) {
    return PresetAvatarStyle.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PresetAvatarStyle.modern,
    );
  }
}

/// 用户角色
enum UserRole {
  host('房主', 'host'),
  moderator('管理员', 'moderator'),
  participant('参与者', 'participant'),
  observer('观察者', 'observer');
  
  final String label;
  final String value;
  const UserRole(this.label, this.value);
  
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.participant,
    );
  }
}

/// 用户资料
class UserProfile {
  /// 唯一 ID（UUID）
  final String id;
  
  /// 昵称（显示名称，可修改）
  final String nickname;
  
  /// 头像类型
  final AvatarType avatarType;
  
  /// 头像 URL（网络图片或预设标识）
  final String? avatarUrl;
  
  /// 头像二进制数据（自定义上传）
  final Uint8List? avatarData;
  
  /// 强调色（个性化配色）
  final int accentColor;
  
  /// 状态消息（类似 Minecraft 的签名）
  final String? statusMessage;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;
  
  /// 是否是本地用户（当前登录用户）
  final bool isLocalUser;
  
  /// 预设头像样式
  final PresetAvatarStyle avatarStyle;

  const UserProfile({
    required this.id,
    required this.nickname,
    this.avatarType = AvatarType.generated,
    this.avatarUrl,
    this.avatarData,
    this.accentColor = 0xFF0078D4, // WinUI 蓝色
    this.statusMessage,
    required this.createdAt,
    required this.updatedAt,
    this.isLocalUser = false,
    this.avatarStyle = PresetAvatarStyle.modern,
  });

  /// 创建新用户
  factory UserProfile.create({
    required String nickname,
    AvatarType avatarType = AvatarType.generated,
    String? avatarUrl,
    Uint8List? avatarData,
    int accentColor = 0xFF0078D4,
    String? statusMessage,
    PresetAvatarStyle avatarStyle = PresetAvatarStyle.modern,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: _generateUserId(nickname),
      nickname: nickname,
      avatarType: avatarType,
      avatarUrl: avatarUrl,
      avatarData: avatarData,
      accentColor: accentColor,
      statusMessage: statusMessage,
      createdAt: now,
      updatedAt: now,
      isLocalUser: true,
      avatarStyle: avatarStyle,
    );
  }

  /// 生成用户 ID（基于昵称 + 随机数，确保唯一性同时可识别）
  static String _generateUserId(String nickname) {
    final sanitized = nickname
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .substring(0, nickname.length.clamp(0, 16));
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final random = (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
    return '${sanitized}_$timestamp$random';
  }

  /// 复制并修改
  UserProfile copyWith({
    String? nickname,
    AvatarType? avatarType,
    String? avatarUrl,
    Uint8List? avatarData,
    int? accentColor,
    String? statusMessage,
    bool? isLocalUser,
    PresetAvatarStyle? avatarStyle,
  }) {
    return UserProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarType: avatarType ?? this.avatarType,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarData: avatarData ?? this.avatarData,
      accentColor: accentColor ?? this.accentColor,
      statusMessage: statusMessage ?? this.statusMessage,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isLocalUser: isLocalUser ?? this.isLocalUser,
      avatarStyle: avatarStyle ?? this.avatarStyle,
    );
  }

  /// 从数据库 Map 解析
  factory UserProfile.fromDb(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      nickname: map['nickname'] as String,
      avatarType: AvatarType.values.byName(map['avatar_type'] ?? 'generated'),
      avatarUrl: map['avatar_url'] as String?,
      avatarData: map['avatar_data'] != null 
          ? Uint8List.fromList(map['avatar_data'] as List<int>)
          : null,
      accentColor: map['accent_color'] as int? ?? 0xFF0078D4,
      statusMessage: map['status_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isLocalUser: (map['is_local_user'] as int?) == 1,
      avatarStyle: PresetAvatarStyle.fromString(map['avatar_style'] ?? 'modern'),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_type': avatarType.name,
      'avatar_url': avatarUrl,
      'avatar_data': avatarData,
      'accent_color': accentColor,
      'status_message': statusMessage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_local_user': isLocalUser ? 1 : 0,
      'avatar_style': avatarStyle.value,
    };
  }

  /// 从 JSON 解析（网络传输）
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      avatarType: AvatarType.values.byName(json['avatarType'] ?? 'generated'),
      avatarUrl: json['avatarUrl'] as String?,
      avatarData: json['avatarData'] != null 
          ? base64Decode(json['avatarData'] as String)
          : null,
      accentColor: json['accentColor'] as int? ?? 0xFF0078D4,
      statusMessage: json['statusMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isLocalUser: false, // 网络传输的总是远程用户
      avatarStyle: PresetAvatarStyle.fromString(json['avatarStyle'] ?? 'modern'),
    );
  }

  /// 转换为 JSON（网络传输）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatarType': avatarType.name,
      'avatarUrl': avatarUrl,
      'avatarData': avatarData != null ? base64Encode(avatarData!) : null,
      'accentColor': accentColor,
      'statusMessage': statusMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'avatarStyle': avatarStyle.value,
    };
  }

  /// 显示名称（带装饰）
  String get displayName => nickname;
  
  /// 短 ID（用于显示）
  String get shortId => id.length > 12 ? '${id.substring(0, 8)}...' : id;
  
  /// 是否使用自定义头像
  bool get hasCustomAvatar => avatarType == AvatarType.custom || avatarType == AvatarType.network;
  
  /// 是否使用生成头像
  bool get hasGeneratedAvatar => avatarType == AvatarType.generated;

  @override
  String toString() => 'UserProfile($nickname, $id)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// 用户设置
class UserSettings {
  final String userId;
  final AppThemeMode themeMode;
  final String language;
  final AudioQuality audioQuality;
  final bool autoSync;
  final bool notificationEnabled;
  final PresetAvatarStyle defaultAvatarStyle;

  const UserSettings({
    required this.userId,
    this.themeMode = AppThemeMode.system,
    this.language = 'zh-CN',
    this.audioQuality = AudioQuality.high,
    this.autoSync = true,
    this.notificationEnabled = true,
    this.defaultAvatarStyle = PresetAvatarStyle.modern,
  });

  factory UserSettings.fromDb(Map<String, dynamic> map) {
    return UserSettings(
      userId: map['user_id'] as String,
      themeMode: AppThemeMode.values.byName(map['theme_mode'] ?? 'system'),
      language: map['language'] as String? ?? 'zh-CN',
      audioQuality: AudioQuality.values.byName(map['audio_quality'] ?? 'high'),
      autoSync: (map['auto_sync'] as int?) == 1,
      notificationEnabled: (map['notification_enabled'] as int?) == 1,
      defaultAvatarStyle: PresetAvatarStyle.fromString(map['default_avatar_style'] ?? 'modern'),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'user_id': userId,
      'theme_mode': themeMode.name,
      'language': language,
      'audio_quality': audioQuality.name,
      'auto_sync': autoSync ? 1 : 0,
      'notification_enabled': notificationEnabled ? 1 : 0,
      'default_avatar_style': defaultAvatarStyle.value,
    };
  }

  UserSettings copyWith({
    AppThemeMode? themeMode,
    String? language,
    AudioQuality? audioQuality,
    bool? autoSync,
    bool? notificationEnabled,
    PresetAvatarStyle? defaultAvatarStyle,
  }) {
    return UserSettings(
      userId: userId,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      audioQuality: audioQuality ?? this.audioQuality,
      autoSync: autoSync ?? this.autoSync,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      defaultAvatarStyle: defaultAvatarStyle ?? this.defaultAvatarStyle,
    );
  }
}

/// 主题模式
enum AppThemeMode { light, dark, system }

/// 音频质量
enum AudioQuality {
  low('低', 'low', 16000, 16000),
  medium('中', 'medium', 22050, 32000),
  high('高', 'high', 44100, 128000),
  ultra('超高', 'ultra', 48000, 256000);

  final String label;
  final String value;
  final int sampleRate;
  final int bitRate;
  
  const AudioQuality(this.label, this.value, this.sampleRate, this.bitRate);
}
