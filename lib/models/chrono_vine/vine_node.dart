import 'space_time_axis.dart';
import 'leaf_attachment.dart';

/// 藤蔓节点：每个参与者的消息单元
class VineNode {
  final String id;
  
  /// 关联原始消息
  final String messageId;
  
  /// 时空坐标
  final SpaceTimePoint position;
  
  /// 语音转文字内容
  final String content;
  
  /// 前 100 字摘要
  final String contentPreview;
  
  /// 完整内容载荷
  final MessagePayload payload;
  
  /// 节点类型
  final NodeType nodeType;
  
  /// 节点状态
  NodeStatus status;
  
  /// 上级节点（时间序）
  final String? parentId;
  
  /// 分叉出的子节点
  final List<String> branchIds;
  
  /// 合并目标（如有）
  final String? mergeTargetId;
  
  /// 几何形状
  final NodeGeometry geometry;
  
  /// 材质状态
  final MaterialState materialState;
  
  /// AI 语义层叠
  final List<LeafAttachment> leaves;
  
  /// 作者 ID
  final String authorId;
  
  /// CRDT 逻辑时钟
  final int lamport;
  
  /// 版本向量
  final Map<String, int> vectorClock;
  
  /// 创建时间
  final DateTime createdAt;

  VineNode({
    required this.id,
    required this.messageId,
    required this.position,
    required this.content,
    this.contentPreview = '',
    this.payload = const MessagePayload.text(''),
    this.nodeType = NodeType.message,
    this.status = NodeStatus.draft,
    this.parentId,
    this.branchIds = const [],
    this.mergeTargetId,
    this.geometry = const NodeGeometry.voiceBlock(size: 1.0),
    this.materialState = const MaterialState(),
    this.leaves = const [],
    required this.authorId,
    this.lamport = 0,
    this.vectorClock = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否是关键节点
  bool get isKeyNode => leaves.isNotEmpty || nodeType == NodeType.milestone;

  /// 获取共识度
  double get consensusScore {
    if (leaves.isEmpty) return 0.5;
    final totalRelevance = leaves.fold<double>(0.0, (sum, l) => sum + l.relevanceScore);
    return totalRelevance / leaves.length;
  }

  /// 添加叶子
  VineNode addLeaf(LeafAttachment leaf) {
    return copyWith(
      leaves: [...leaves, leaf],
    );
  }

  /// 更新状态
  VineNode updateStatus(NodeStatus newStatus) {
    return copyWith(status: newStatus);
  }

  VineNode copyWith({
    String? id,
    String? messageId,
    SpaceTimePoint? position,
    String? content,
    String? contentPreview,
    MessagePayload? payload,
    NodeType? nodeType,
    NodeStatus? status,
    String? parentId,
    List<String>? branchIds,
    String? mergeTargetId,
    NodeGeometry? geometry,
    MaterialState? materialState,
    List<LeafAttachment>? leaves,
    String? authorId,
    int? lamport,
    Map<String, int>? vectorClock,
    DateTime? createdAt,
  }) {
    return VineNode(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      position: position ?? this.position,
      content: content ?? this.content,
      contentPreview: contentPreview ?? this.contentPreview,
      payload: payload ?? this.payload,
      nodeType: nodeType ?? this.nodeType,
      status: status ?? this.status,
      parentId: parentId ?? this.parentId,
      branchIds: branchIds ?? this.branchIds,
      mergeTargetId: mergeTargetId ?? this.mergeTargetId,
      geometry: geometry ?? this.geometry,
      materialState: materialState ?? this.materialState,
      leaves: leaves ?? this.leaves,
      authorId: authorId ?? this.authorId,
      lamport: lamport ?? this.lamport,
      vectorClock: vectorClock ?? this.vectorClock,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'position': position.toJson(),
    'content': content,
    'contentPreview': contentPreview,
    'payload': payload.toJson(),
    'nodeType': nodeType.name,
    'status': status.name,
    'parentId': parentId,
    'branchIds': branchIds,
    'mergeTargetId': mergeTargetId,
    'geometry': geometry.toJson(),
    'materialState': materialState.toJson(),
    'leaves': leaves.map((l) => l.toJson()).toList(),
    'authorId': authorId,
    'lamport': lamport,
    'vectorClock': vectorClock,
    'createdAt': createdAt.toIso8601String(),
  };

  factory VineNode.fromJson(Map<String, dynamic> json) {
    return VineNode(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      position: SpaceTimePoint.fromJson(json['position'] as Map<String, dynamic>),
      content: json['content'] as String,
      contentPreview: json['contentPreview'] as String? ?? '',
      payload: MessagePayload.fromJson(json['payload'] as Map<String, dynamic>),
      nodeType: NodeType.values.firstWhere(
        (e) => e.name == json['nodeType'],
        orElse: () => NodeType.message,
      ),
      status: NodeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NodeStatus.draft,
      ),
      parentId: json['parentId'] as String?,
      branchIds: (json['branchIds'] as List<dynamic>?)?.cast<String>() ?? [],
      mergeTargetId: json['mergeTargetId'] as String?,
      geometry: NodeGeometry.fromJson(json['geometry'] as Map<String, dynamic>),
      materialState: MaterialState.fromJson(json['materialState'] as Map<String, dynamic>),
      leaves: (json['leaves'] as List<dynamic>)
          .map((l) => LeafAttachment.fromJson(l as Map<String, dynamic>))
          .toList(),
      authorId: json['authorId'] as String,
      lamport: json['lamport'] as int? ?? 0,
      vectorClock: (json['vectorClock'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ) ?? {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 节点类型
enum NodeType {
  message,      // 普通消息节点
  branch,       // 分叉点（话题分裂）
  merge,        // 合并点（共识达成）
  milestone,    // 里程碑（关键决策）
  aiSummary,    // AI 生成的总结节点
}

/// 节点状态
enum NodeStatus {
  draft,        // 草稿（本地录制中）
  committed,    // 已提交（同步到网络）
  confirmed,    // 已确认（达成共识）
  archived,     // 已归档（历史节点）
}

/// 消息载荷
class MessagePayload {
  final PayloadType type;
  final String? text;
  final ImagePayload? image;
  final FilePayload? file;
  final AudioPayload? audio;

  const MessagePayload._({
    required this.type,
    this.text,
    this.image,
    this.file,
    this.audio,
  });

  const MessagePayload.text(String content)
    : type = PayloadType.text,
      text = content,
      image = null,
      file = null,
      audio = null;

  MessagePayload.image({required String url, required int width, required int height})
    : type = PayloadType.image,
      text = null,
      image = ImagePayload(url: url, width: width, height: height),
      file = null,
      audio = null;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'text': text,
    'image': image?.toJson(),
    'file': file?.toJson(),
    'audio': audio?.toJson(),
  };

  factory MessagePayload.fromJson(Map<String, dynamic> json) {
    final type = PayloadType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => PayloadType.text,
    );
    
    switch (type) {
      case PayloadType.text:
        return MessagePayload.text(json['text'] as String? ?? '');
      case PayloadType.image:
        return MessagePayload._(
          type: type,
          image: ImagePayload.fromJson(json['image'] as Map<String, dynamic>),
        );
      case PayloadType.file:
        return MessagePayload._(
          type: type,
          file: FilePayload.fromJson(json['file'] as Map<String, dynamic>),
        );
      case PayloadType.audio:
        return MessagePayload._(
          type: type,
          audio: AudioPayload.fromJson(json['audio'] as Map<String, dynamic>),
        );
    }
  }
}

enum PayloadType { text, image, file, audio }

class ImagePayload {
  final String url;
  final int width;
  final int height;

  const ImagePayload({required this.url, required this.width, required this.height});

  Map<String, dynamic> toJson() => {'url': url, 'width': width, 'height': height};
  factory ImagePayload.fromJson(Map<String, dynamic> json) => ImagePayload(
    url: json['url'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
  );
}

class FilePayload {
  final String name;
  final int size;
  final String url;

  const FilePayload({required this.name, required this.size, required this.url});

  Map<String, dynamic> toJson() => {'name': name, 'size': size, 'url': url};
  factory FilePayload.fromJson(Map<String, dynamic> json) => FilePayload(
    name: json['name'] as String,
    size: json['size'] as int,
    url: json['url'] as String,
  );
}

class AudioPayload {
  final double durationSecs;
  final String url;

  const AudioPayload({required this.durationSecs, required this.url});

  Map<String, dynamic> toJson() => {'durationSecs': durationSecs, 'url': url};
  factory AudioPayload.fromJson(Map<String, dynamic> json) => AudioPayload(
    durationSecs: (json['durationSecs'] as num).toDouble(),
    url: json['url'] as String,
  );
}

/// 节点几何形状
class NodeGeometry {
  final GeometryType type;
  final double? size;
  final int? branches;
  final int? facets;
  final int? petals;

  const NodeGeometry._({
    required this.type,
    this.size,
    this.branches,
    this.facets,
    this.petals,
  });

  const NodeGeometry.voiceBlock({required double size})
    : type = GeometryType.voiceBlock,
      size = size,
      branches = null,
      facets = null,
      petals = null;

  const NodeGeometry.branchPoint({required int branches})
    : type = GeometryType.branchPoint,
      size = null,
      branches = branches,
      facets = null,
      petals = null;

  const NodeGeometry.mergeCrystal({required int facets})
    : type = GeometryType.mergeCrystal,
      size = null,
      branches = null,
      facets = facets,
      petals = null;

  const NodeGeometry.milestoneMonolith()
    : type = GeometryType.milestoneMonolith,
      size = null,
      branches = null,
      facets = null,
      petals = null;

  const NodeGeometry.aiFlower({required int petals})
    : type = GeometryType.aiFlower,
      size = null,
      branches = null,
      facets = null,
      petals = petals;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'size': size,
    'branches': branches,
    'facets': facets,
    'petals': petals,
  };

  factory NodeGeometry.fromJson(Map<String, dynamic> json) {
    final type = GeometryType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => GeometryType.voiceBlock,
    );
    
    return NodeGeometry._(
      type: type,
      size: (json['size'] as num?)?.toDouble(),
      branches: json['branches'] as int?,
      facets: json['facets'] as int?,
      petals: json['petals'] as int?,
    );
  }
}

enum GeometryType {
  voiceBlock,      // 语音节点：方块
  branchPoint,     // 分叉点：多向分支
  mergeCrystal,    // 合并点：多面水晶
  milestoneMonolith, // 里程碑：方尖碑
  aiFlower,        // AI 总结：花朵
}

/// 材质状态
class MaterialState {
  /// 建造进度 0-1
  final double buildProgress;
  
  /// 发光强度 0-1
  final double glowIntensity;
  
  /// 颜色（RGBA）
  final List<double> color;

  const MaterialState({
    this.buildProgress = 0.0,
    this.glowIntensity = 0.5,
    this.color = const [0.2, 0.6, 1.0, 1.0],
  });

  static MaterialState forStatus(NodeStatus status) {
    switch (status) {
      case NodeStatus.draft:
        return const MaterialState(color: [0.8, 0.8, 0.8, 0.5]);
      case NodeStatus.committed:
        return const MaterialState(color: [0.2, 0.6, 1.0, 1.0]);
      case NodeStatus.confirmed:
        return const MaterialState(color: [0.2, 0.9, 0.4, 1.0]);
      case NodeStatus.archived:
        return const MaterialState(color: [0.5, 0.5, 0.5, 0.8]);
    }
  }

  Map<String, dynamic> toJson() => {
    'buildProgress': buildProgress,
    'glowIntensity': glowIntensity,
    'color': color,
  };

  factory MaterialState.fromJson(Map<String, dynamic> json) {
    return MaterialState(
      buildProgress: (json['buildProgress'] as num?)?.toDouble() ?? 0.0,
      glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 0.5,
      color: (json['color'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.2, 0.6, 1.0, 1.0],
    );
  }
}


// ========== Message 类（聊天消息） ==========

/// 聊天消息
class Message {
  final String id;
  final String roomId;
  final String? nodeId;  // 关联的节点
  final String authorId;
  final String content;
  final String contentType;
  final String? audioPath;
  final Duration? audioDuration;
  final String? replyToId;
  final DateTime timestamp;
  final bool isSynced;
  final int syncAttempts;
  final String? lastSyncError;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.roomId,
    this.nodeId,
    required this.authorId,
    required this.content,
    this.contentType = 'text',
    this.audioPath,
    this.audioDuration,
    this.replyToId,
    required this.timestamp,
    this.isSynced = false,
    this.syncAttempts = 0,
    this.lastSyncError,
    required this.createdAt,
  });

  /// 创建新消息
  factory Message.create({
    required String roomId,
    required String authorId,
    required String content,
    String contentType = 'text',
    String? audioPath,
    Duration? audioDuration,
    String? replyToId,
  }) {
    final now = DateTime.now();
    return Message(
      id: 'msg_${now.millisecondsSinceEpoch}_$authorId',
      roomId: roomId,
      authorId: authorId,
      content: content,
      contentType: contentType,
      audioPath: audioPath,
      audioDuration: audioDuration,
      replyToId: replyToId,
      timestamp: now,
      createdAt: now,
    );
  }

  /// 创建文本消息
  factory Message.createText({
    required String roomId,
    required String senderId,
    required String content,
    String? senderName,
    String? senderAvatarUrl,
    String? replyToId,
  }) {
    return Message.create(
      roomId: roomId,
      authorId: senderId,
      content: content,
      contentType: 'text',
      replyToId: replyToId,
    );
  }

  /// 创建图片消息
  factory Message.createImage({
    required String roomId,
    required String senderId,
    required String filePath,
    String? caption,
    String? senderName,
    String? senderAvatarUrl,
    String? replyToId,
  }) {
    return Message.create(
      roomId: roomId,
      authorId: senderId,
      content: caption ?? filePath,
      contentType: 'image',
      replyToId: replyToId,
    );
  }

  /// 创建文件消息
  factory Message.createFile({
    required String roomId,
    required String senderId,
    required String filePath,
    required String fileName,
    required int fileSize,
    String? senderName,
    String? senderAvatarUrl,
    String? replyToId,
  }) {
    return Message.create(
      roomId: roomId,
      authorId: senderId,
      content: '$fileName|$filePath|$fileSize',
      contentType: 'file',
      replyToId: replyToId,
    );
  }

  /// 创建语音消息
  factory Message.createVoice({
    required String roomId,
    required String senderId,
    required String audioPath,
    required int durationSeconds,
    String? senderName,
    String? senderAvatarUrl,
    String? replyToId,
  }) {
    return Message.create(
      roomId: roomId,
      authorId: senderId,
      content: '[语音 $durationSeconds秒]',
      contentType: 'voice',
      audioPath: audioPath,
      audioDuration: Duration(seconds: durationSeconds),
      replyToId: replyToId,
    );
  }

  Message copyWith({
    String? nodeId,
    bool? isSynced,
    int? syncAttempts,
    String? lastSyncError,
  }) {
    return Message(
      id: id,
      roomId: roomId,
      nodeId: nodeId ?? this.nodeId,
      authorId: authorId,
      content: content,
      contentType: contentType,
      audioPath: audioPath,
      audioDuration: audioDuration,
      replyToId: replyToId,
      timestamp: timestamp,
      isSynced: isSynced ?? this.isSynced,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'nodeId': nodeId,
      'authorId': authorId,
      'content': content,
      'contentType': contentType,
      'audioPath': audioPath,
      'audioDuration': audioDuration?.inMilliseconds,
      'replyToId': replyToId,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      nodeId: json['nodeId'] as String?,
      authorId: json['authorId'] as String,
      content: json['content'] as String,
      contentType: json['contentType'] as String? ?? 'text',
      audioPath: json['audioPath'] as String?,
      audioDuration: json['audioDuration'] != null
          ? Duration(milliseconds: json['audioDuration'] as int)
          : null,
      replyToId: json['replyToId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      syncAttempts: json['syncAttempts'] as int? ?? 0,
      lastSyncError: json['lastSyncError'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() => 'Message($id, $authorId)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}
