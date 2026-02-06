/// 会议房间模型

import 'chrono_vine/vine_node.dart';
import 'auth/role_permissions.dart' show UserRole;

// 导出 UserRole 供其他文件使用
export 'auth/role_permissions.dart' show UserRole;

/// 网络模式
enum NetworkMode {
  p2p,      // 点对点（局域网）
  server,   // 服务器模式
  hybrid,   // 混合模式
}

/// 会议房间
class Room {
  final String id;
  final String name;
  final String? description;
  final String hostId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final bool isArchived;
  final String networkMode;
  final String? serverAddress;
  final String? accessCode;
  final int maxParticipants;
  final String? settingsJson;
  
  // 运行时数据（不存储到数据库）
  final List<VineNode>? nodes;
  final int? participantCount;

  const Room({
    required this.id,
    required this.name,
    this.description,
    required this.hostId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.isArchived = false,
    this.networkMode = 'p2p',
    this.serverAddress,
    this.accessCode,
    this.maxParticipants = 50,
    this.settingsJson,
    this.nodes,
    this.participantCount,
  });

  /// 创建新房间
  factory Room.create({
    required String name,
    required String hostId,
    String? description,
    NetworkMode networkMode = NetworkMode.p2p,
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
      networkMode: networkMode.name,
      serverAddress: serverAddress,
      accessCode: accessCode,
      maxParticipants: maxParticipants,
    );
  }

  Room copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool? isArchived,
    String? networkMode,
    String? serverAddress,
    String? accessCode,
    int? maxParticipants,
    String? settingsJson,
    List<VineNode>? nodes,
    int? participantCount,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      hostId: hostId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      isArchived: isArchived ?? this.isArchived,
      networkMode: networkMode ?? this.networkMode,
      serverAddress: serverAddress ?? this.serverAddress,
      accessCode: accessCode ?? this.accessCode,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      settingsJson: settingsJson ?? this.settingsJson,
      nodes: nodes ?? this.nodes,
      participantCount: participantCount ?? this.participantCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'hostId': hostId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'isArchived': isArchived,
      'networkMode': networkMode,
      'serverAddress': serverAddress,
      'accessCode': accessCode,
      'maxParticipants': maxParticipants,
      'settingsJson': settingsJson,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      hostId: json['hostId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archivedAt: json['archivedAt'] != null 
          ? DateTime.parse(json['archivedAt'] as String)
          : null,
      isArchived: json['isArchived'] as bool? ?? false,
      networkMode: json['networkMode'] as String? ?? 'p2p',
      serverAddress: json['serverAddress'] as String?,
      accessCode: json['accessCode'] as String?,
      maxParticipants: json['maxParticipants'] as int? ?? 50,
      settingsJson: json['settingsJson'] as String?,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'host_id': hostId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'archived_at': archivedAt?.millisecondsSinceEpoch,
      'is_archived': isArchived ? 1 : 0,
      'network_mode': networkMode,
      'server_address': serverAddress,
      'access_code': accessCode,
      'max_participants': maxParticipants,
      'settings_json': settingsJson,
    };
  }

  /// 从数据库 Map 解析
  factory Room.fromDb(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      hostId: map['host_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      archivedAt: map['archived_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int)
          : null,
      isArchived: (map['is_archived'] as int) == 1,
      networkMode: map['network_mode'] as String? ?? 'p2p',
      serverAddress: map['server_address'] as String?,
      accessCode: map['access_code'] as String?,
      maxParticipants: map['max_participants'] as int? ?? 50,
      settingsJson: map['settings_json'] as String?,
    );
  }

  @override
  String toString() => 'Room($name, $id)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// 房间设置
class RoomSettings {
  final bool allowGuest;
  final bool requireApproval;
  final bool recordingEnabled;
  final bool aiAnalysisEnabled;
  final Duration messageRetention;
  final Map<String, dynamic> customSettings;

  const RoomSettings({
    this.allowGuest = true,
    this.requireApproval = false,
    this.recordingEnabled = true,
    this.aiAnalysisEnabled = true,
    this.messageRetention = const Duration(days: 30),
    this.customSettings = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'allowGuest': allowGuest,
      'requireApproval': requireApproval,
      'recordingEnabled': recordingEnabled,
      'aiAnalysisEnabled': aiAnalysisEnabled,
      'messageRetentionDays': messageRetention.inDays,
      'customSettings': customSettings,
    };
  }

  factory RoomSettings.fromJson(Map<String, dynamic> json) {
    return RoomSettings(
      allowGuest: json['allowGuest'] as bool? ?? true,
      requireApproval: json['requireApproval'] as bool? ?? false,
      recordingEnabled: json['recordingEnabled'] as bool? ?? true,
      aiAnalysisEnabled: json['aiAnalysisEnabled'] as bool? ?? true,
      messageRetention: Duration(days: json['messageRetentionDays'] as int? ?? 30),
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// 房间参与者信息
class RoomParticipant {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final UserRole role;
  final bool isActive;
  final DateTime? lastSeenAt;

  const RoomParticipant({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.joinedAt,
    this.leftAt,
    this.role = UserRole.member,
    this.isActive = true,
    this.lastSeenAt,
  });

  bool get isOnline => isActive && 
      (lastSeenAt == null || 
       DateTime.now().difference(lastSeenAt!).inMinutes < 5);
}
