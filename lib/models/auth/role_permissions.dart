/// 用户角色枚举
/// 
/// 定义了世界中的不同角色权限等级
enum UserRole {
  owner,      // 服主：拥有所有权限
  admin,      // 管理员：可踢人、修改世界设置
  moderator,  // 主持人：可标记里程碑、生成报告
  member,     // 普通成员：可提交、可查看全部
  guest,      // 访客：仅查看、不可提交
  spectator,  // 观察者：仅观看3D场景，无交互
}

/// 权限常量定义
class Permission {
  static const String submitMessage = 'submit';      // 提交独白
  static const String viewAllNodes = 'view_all';     // 查看全部节点
  static const String viewOwnOnly = 'view_own';      // 仅看自己相关
  static const String editNodes = 'edit';            // 编辑/删除节点
  static const String manageWorld = 'manage';        // 世界设置
  static const String kickPlayer = 'kick';           // 踢人
  static const String assignTasks = 'assign';        // 分配Todo
  static const String exportReport = 'export';       // 导出报告
  static const String inviteOthers = 'invite';       // 邀请他人
  static const String deleteWorld = 'delete';        // 删除世界
  static const String changePermissions = 'change_permissions'; // 修改权限

  static const List<String> all = [
    submitMessage,
    viewAllNodes,
    viewOwnOnly,
    editNodes,
    manageWorld,
    kickPlayer,
    assignTasks,
    exportReport,
    inviteOthers,
    deleteWorld,
    changePermissions,
  ];
}

/// 角色权限矩阵
/// 
/// 定义每个角色拥有的权限列表
final Map<UserRole, List<String>> rolePermissions = {
  UserRole.owner: [
    Permission.submitMessage,
    Permission.viewAllNodes,
    Permission.viewOwnOnly,
    Permission.editNodes,
    Permission.manageWorld,
    Permission.kickPlayer,
    Permission.assignTasks,
    Permission.exportReport,
    Permission.inviteOthers,
    Permission.deleteWorld,
    Permission.changePermissions,
  ],
  UserRole.admin: [
    Permission.submitMessage,
    Permission.viewAllNodes,
    Permission.viewOwnOnly,
    Permission.editNodes,
    Permission.manageWorld,
    Permission.kickPlayer,
    Permission.assignTasks,
    Permission.exportReport,
    Permission.inviteOthers,
    Permission.changePermissions,
  ],
  UserRole.moderator: [
    Permission.submitMessage,
    Permission.viewAllNodes,
    Permission.viewOwnOnly,
    Permission.editNodes,
    Permission.assignTasks,
    Permission.exportReport,
    Permission.inviteOthers,
  ],
  UserRole.member: [
    Permission.submitMessage,
    Permission.viewAllNodes,
    Permission.viewOwnOnly,
    Permission.assignTasks,
  ],
  UserRole.guest: [
    Permission.viewAllNodes,
    Permission.viewOwnOnly,
  ],
  UserRole.spectator: [
    Permission.viewOwnOnly,
  ],
};

/// 权限检查工具类
class PermissionChecker {
  /// 检查角色是否拥有指定权限
  static bool hasPermission(UserRole role, String permission) {
    final permissions = rolePermissions[role];
    if (permissions == null) return false;
    return permissions.contains(permission);
  }

  /// 检查角色是否拥有所有指定权限
  static bool hasAllPermissions(UserRole role, List<String> permissions) {
    return permissions.every((p) => hasPermission(role, p));
  }

  /// 检查角色是否拥有任一指定权限
  static bool hasAnyPermission(UserRole role, List<String> permissions) {
    return permissions.any((p) => hasPermission(role, p));
  }

  /// 获取角色的权限列表
  static List<String> getPermissions(UserRole role) {
    return List<String>.from(rolePermissions[role] ?? []);
  }

  /// 获取角色的权限标签（本地化）
  static String getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return '服主';
      case UserRole.admin:
        return '管理员';
      case UserRole.moderator:
        return '主持人';
      case UserRole.member:
        return '成员';
      case UserRole.guest:
        return '访客';
      case UserRole.spectator:
        return '观察者';
    }
  }

  /// 获取权限标签（本地化）
  static String getPermissionLabel(String permission) {
    switch (permission) {
      case Permission.submitMessage:
        return '提交独白';
      case Permission.viewAllNodes:
        return '查看全部节点';
      case Permission.viewOwnOnly:
        return '查看个人内容';
      case Permission.editNodes:
        return '编辑节点';
      case Permission.manageWorld:
        return '管理世界';
      case Permission.kickPlayer:
        return '踢出玩家';
      case Permission.assignTasks:
        return '分配任务';
      case Permission.exportReport:
        return '导出报告';
      case Permission.inviteOthers:
        return '邀请他人';
      case Permission.deleteWorld:
        return '删除世界';
      case Permission.changePermissions:
        return '修改权限';
      default:
        return permission;
    }
  }
}

/// 玩家身份信息
class PlayerIdentity {
  final String id;              // 唯一设备ID
  final String displayName;     // 显示名称
  final String? avatarUrl;      // 头像URL
  final String? authToken;      // 认证令牌
  final UserRole role;          // 当前角色

  PlayerIdentity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.authToken,
    this.role = UserRole.member,
  });

  PlayerIdentity copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? authToken,
    UserRole? role,
  }) {
    return PlayerIdentity(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authToken: authToken ?? this.authToken,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role.name,
  };

  factory PlayerIdentity.fromJson(Map<String, dynamic> json) {
    return PlayerIdentity(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      authToken: json['authToken'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.member,
      ),
    );
  }
}

/// 可见性过滤器
/// 
/// 服主配置的可见范围
class VisibilityFilter {
  final Duration? timeWindow;           // 可见时间范围（null表示全部）
  final List<String>? visibleAuthors;   // 可见的作者（null表示全部）
  final bool isolationMode;             // 是否仅看自己

  const VisibilityFilter({
    this.timeWindow,
    this.visibleAuthors,
    this.isolationMode = false,
  });

  /// 默认：全部可见
  factory VisibilityFilter.all() => const VisibilityFilter();

  /// 仅看自己
  factory VisibilityFilter.ownOnly() => const VisibilityFilter(
    isolationMode: true,
  );

  /// 最近N小时
  factory VisibilityFilter.recentHours(int hours) => VisibilityFilter(
    timeWindow: Duration(hours: hours),
  );

  /// 检查节点是否可见
  bool canSee({
    required DateTime nodeTimestamp,
    required String authorId,
    required String currentUserId,
  }) {
    // 隔离模式：只看自己
    if (isolationMode && authorId != currentUserId) {
      return false;
    }

    // 作者过滤
    if (visibleAuthors != null && !visibleAuthors!.contains(authorId)) {
      return false;
    }

    // 时间过滤
    if (timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow!);
      if (nodeTimestamp.isBefore(cutoff)) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> toJson() => {
    'timeWindowHours': timeWindow?.inHours,
    'visibleAuthors': visibleAuthors,
    'isolationMode': isolationMode,
  };

  factory VisibilityFilter.fromJson(Map<String, dynamic> json) {
    return VisibilityFilter(
      timeWindow: json['timeWindowHours'] != null
        ? Duration(hours: json['timeWindowHours'] as int)
        : null,
      visibleAuthors: (json['visibleAuthors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
      isolationMode: json['isolationMode'] as bool? ?? false,
    );
  }
}
