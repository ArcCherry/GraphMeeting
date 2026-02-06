import '../models/chrono_vine/leaf_attachment.dart';
import 'auth/role_permissions.dart';

/// 转写模式
enum TranscriptionMode {
  localWhisper,   // 本地Whisper，隐私好
  cloudApi,       // 云端API，准确率高
  hybrid,         // 本地先转，云端校正
}

/// 世界设置
/// 
/// 服主可配置的整个世界参数
class WorldSettings {
  // 基础设置
  final String worldName;           // 世界名称
  final String? worldDescription;   // 世界描述
  final DateTime createdAt;         // 创建时间
  
  // 语音处理配置
  final TranscriptionMode transcriptionMode;  // 转写模式
  final String? cloudApiEndpoint;   // 自定义云端API地址
  final String? cloudApiKey;        // 云端API密钥
  
  // 网络配置
  final int maxPlayers;             // 最大在线人数（默认100）
  final int latencyThresholdMs;     // 延迟警告阈值（默认200ms）
  final int forceDisconnectLatencyMs;  // 强制掉线阈值（默认500ms）
  final bool enableLatencyKick;     // 是否启用延迟踢出
  
  // 权限配置
  final Map<UserRole, List<String>> customPermissions;  // 自定义权限矩阵
  final VisibilityFilter defaultVisibility;  // 默认可见性
  
  // AI配置
  final bool enableAutoSummary;     // 自动生成总结
  final Duration summaryInterval;   // 总结生成间隔
  final List<LeafType> enabledLeafTypes;  // 启用的AI叶子类型
  final double leafRelevanceThreshold;  // 叶子生成关联度阈值
  
  // 功能开关
  final bool allowFileUpload;       // 允许文件上传
  final bool allowImageUpload;      // 允许图片上传
  final bool allowVoiceMessage;     // 允许语音消息
  final int maxFileSizeMb;          // 最大文件大小（MB）
  final int maxMessageLength;       // 最大消息长度
  
  // 隐私设置
  final bool isPrivate;             // 是否私有世界
  final String? password;           // 访问密码
  final List<String>? allowedDomains;  // 允许的邮箱域名（企业版）

  WorldSettings({
    required this.worldName,
    this.worldDescription,
    DateTime? createdAt,
    this.transcriptionMode = TranscriptionMode.localWhisper,
    this.cloudApiEndpoint,
    this.cloudApiKey,
    this.maxPlayers = 100,
    this.latencyThresholdMs = 200,
    this.forceDisconnectLatencyMs = 500,
    this.enableLatencyKick = true,
    Map<UserRole, List<String>>? customPermissions,
    VisibilityFilter? defaultVisibility,
    this.enableAutoSummary = true,
    this.summaryInterval = const Duration(minutes: 5),
    List<LeafType>? enabledLeafTypes,
    this.leafRelevanceThreshold = 0.7,
    this.allowFileUpload = true,
    this.allowImageUpload = true,
    this.allowVoiceMessage = true,
    this.maxFileSizeMb = 50,
    this.maxMessageLength = 5000,
    this.isPrivate = false,
    this.password,
    this.allowedDomains,
  })  : createdAt = createdAt ?? DateTime.now(),
        customPermissions = customPermissions ?? rolePermissions,
        defaultVisibility = defaultVisibility ?? VisibilityFilter.all(),
        enabledLeafTypes = enabledLeafTypes ?? LeafType.values;

  /// 默认设置
  factory WorldSettings.defaultSettings(String name) => WorldSettings(
    worldName: name,
  );

  /// 企业版设置（更严格）
  factory WorldSettings.enterprise(String name) => WorldSettings(
    worldName: name,
    transcriptionMode: TranscriptionMode.localWhisper,  // 本地处理，数据不出境
    maxPlayers: 500,
    isPrivate: true,
    allowFileUpload: true,
    maxFileSizeMb: 100,
  );

  /// 快速会议设置（简化）
  factory WorldSettings.quickMeeting(String name) => WorldSettings(
    worldName: name,
    transcriptionMode: TranscriptionMode.hybrid,
    maxPlayers: 10,
    enableAutoSummary: false,  // 手动生成总结
    summaryInterval: const Duration(minutes: 10),
  );

  WorldSettings copyWith({
    String? worldName,
    String? worldDescription,
    TranscriptionMode? transcriptionMode,
    String? cloudApiEndpoint,
    String? cloudApiKey,
    int? maxPlayers,
    int? latencyThresholdMs,
    int? forceDisconnectLatencyMs,
    bool? enableLatencyKick,
    Map<UserRole, List<String>>? customPermissions,
    VisibilityFilter? defaultVisibility,
    bool? enableAutoSummary,
    Duration? summaryInterval,
    List<LeafType>? enabledLeafTypes,
    double? leafRelevanceThreshold,
    bool? allowFileUpload,
    bool? allowImageUpload,
    bool? allowVoiceMessage,
    int? maxFileSizeMb,
    int? maxMessageLength,
    bool? isPrivate,
    String? password,
    List<String>? allowedDomains,
  }) {
    return WorldSettings(
      worldName: worldName ?? this.worldName,
      worldDescription: worldDescription ?? this.worldDescription,
      createdAt: createdAt,
      transcriptionMode: transcriptionMode ?? this.transcriptionMode,
      cloudApiEndpoint: cloudApiEndpoint ?? this.cloudApiEndpoint,
      cloudApiKey: cloudApiKey ?? this.cloudApiKey,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      latencyThresholdMs: latencyThresholdMs ?? this.latencyThresholdMs,
      forceDisconnectLatencyMs: forceDisconnectLatencyMs ?? this.forceDisconnectLatencyMs,
      enableLatencyKick: enableLatencyKick ?? this.enableLatencyKick,
      customPermissions: customPermissions ?? this.customPermissions,
      defaultVisibility: defaultVisibility ?? this.defaultVisibility,
      enableAutoSummary: enableAutoSummary ?? this.enableAutoSummary,
      summaryInterval: summaryInterval ?? this.summaryInterval,
      enabledLeafTypes: enabledLeafTypes ?? this.enabledLeafTypes,
      leafRelevanceThreshold: leafRelevanceThreshold ?? this.leafRelevanceThreshold,
      allowFileUpload: allowFileUpload ?? this.allowFileUpload,
      allowImageUpload: allowImageUpload ?? this.allowImageUpload,
      allowVoiceMessage: allowVoiceMessage ?? this.allowVoiceMessage,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      isPrivate: isPrivate ?? this.isPrivate,
      password: password ?? this.password,
      allowedDomains: allowedDomains ?? this.allowedDomains,
    );
  }

  Map<String, dynamic> toJson() => {
    'worldName': worldName,
    'worldDescription': worldDescription,
    'createdAt': createdAt.toIso8601String(),
    'transcriptionMode': transcriptionMode.name,
    'cloudApiEndpoint': cloudApiEndpoint,
    'maxPlayers': maxPlayers,
    'latencyThresholdMs': latencyThresholdMs,
    'forceDisconnectLatencyMs': forceDisconnectLatencyMs,
    'enableLatencyKick': enableLatencyKick,
    'defaultVisibility': defaultVisibility.toJson(),
    'enableAutoSummary': enableAutoSummary,
    'summaryIntervalSeconds': summaryInterval.inSeconds,
    'enabledLeafTypes': enabledLeafTypes.map((e) => e.name).toList(),
    'leafRelevanceThreshold': leafRelevanceThreshold,
    'allowFileUpload': allowFileUpload,
    'allowImageUpload': allowImageUpload,
    'allowVoiceMessage': allowVoiceMessage,
    'maxFileSizeMb': maxFileSizeMb,
    'maxMessageLength': maxMessageLength,
    'isPrivate': isPrivate,
    'allowedDomains': allowedDomains,
  };

  factory WorldSettings.fromJson(Map<String, dynamic> json) {
    return WorldSettings(
      worldName: json['worldName'] as String,
      worldDescription: json['worldDescription'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      transcriptionMode: TranscriptionMode.values.firstWhere(
        (e) => e.name == json['transcriptionMode'],
        orElse: () => TranscriptionMode.localWhisper,
      ),
      cloudApiEndpoint: json['cloudApiEndpoint'] as String?,
      maxPlayers: json['maxPlayers'] as int? ?? 100,
      latencyThresholdMs: json['latencyThresholdMs'] as int? ?? 200,
      forceDisconnectLatencyMs: json['forceDisconnectLatencyMs'] as int? ?? 500,
      enableLatencyKick: json['enableLatencyKick'] as bool? ?? true,
      defaultVisibility: json['defaultVisibility'] != null
        ? VisibilityFilter.fromJson(json['defaultVisibility'] as Map<String, dynamic>)
        : VisibilityFilter.all(),
      enableAutoSummary: json['enableAutoSummary'] as bool? ?? true,
      summaryInterval: Duration(seconds: json['summaryIntervalSeconds'] as int? ?? 300),
      enabledLeafTypes: (json['enabledLeafTypes'] as List<dynamic>?)
        ?.map((e) => LeafType.values.firstWhere(
          (type) => type.name == e,
          orElse: () => LeafType.summary,
        ))
        .toList(),
      leafRelevanceThreshold: json['leafRelevanceThreshold'] as double? ?? 0.7,
      allowFileUpload: json['allowFileUpload'] as bool? ?? true,
      allowImageUpload: json['allowImageUpload'] as bool? ?? true,
      allowVoiceMessage: json['allowVoiceMessage'] as bool? ?? true,
      maxFileSizeMb: json['maxFileSizeMb'] as int? ?? 50,
      maxMessageLength: json['maxMessageLength'] as int? ?? 5000,
      isPrivate: json['isPrivate'] as bool? ?? false,
      allowedDomains: (json['allowedDomains'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    );
  }
}

/// 世界信息（用于列表展示）
class WorldInfo {
  final String id;
  final String name;
  final String? description;
  final String hostId;
  final String hostName;
  final int currentPlayers;
  final int maxPlayers;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? lastActivity;
  final NetworkMode networkMode;

  WorldInfo({
    required this.id,
    required this.name,
    this.description,
    required this.hostId,
    required this.hostName,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.isPrivate,
    required this.createdAt,
    this.lastActivity,
    this.networkMode = NetworkMode.lan,
  });

  bool get isFull => currentPlayers >= maxPlayers;
  bool get isActive => lastActivity != null && 
    DateTime.now().difference(lastActivity!).inMinutes < 30;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'hostId': hostId,
    'hostName': hostName,
    'currentPlayers': currentPlayers,
    'maxPlayers': maxPlayers,
    'isPrivate': isPrivate,
    'createdAt': createdAt.toIso8601String(),
    'lastActivity': lastActivity?.toIso8601String(),
    'networkMode': networkMode.name,
  };
}

/// 网络模式
enum NetworkMode {
  lan,      // 局域网
  wan,      // 公网服务器
  relay,    // 中继服务器
}

/// 转写模式扩展
extension TranscriptionModeExtension on TranscriptionMode {
  String get label {
    switch (this) {
      case TranscriptionMode.localWhisper:
        return '本地Whisper（隐私优先）';
      case TranscriptionMode.cloudApi:
        return '云端API（准确率优先）';
      case TranscriptionMode.hybrid:
        return '混合模式（速度+准确率）';
    }
  }

  String get description {
    switch (this) {
      case TranscriptionMode.localWhisper:
        return '语音数据本地处理，不上传云端，隐私性最好';
      case TranscriptionMode.cloudApi:
        return '语音上传云端处理，准确率最高，需要网络';
      case TranscriptionMode.hybrid:
        return '本地快速初转，云端后台校正，兼顾速度和准确率';
    }
  }
}
