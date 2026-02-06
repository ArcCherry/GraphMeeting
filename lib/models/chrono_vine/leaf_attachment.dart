/// AI 叶子附件
class LeafAttachment {
  final String id;
  final LeafType type;
  
  /// 叶子标题
  final String title;
  
  /// 详细内容
  final String content;
  
  /// 可执行项
  final List<TodoItem> todos;
  
  /// 与父节点关联度 0-1
  final double relevanceScore;
  
  final DateTime generatedAt;
  
  /// 可追溯的 AI 模型版本
  final String aiModelVersion;

  LeafAttachment({
    required this.id,
    this.type = LeafType.summary,
    required this.title,
    required this.content,
    this.todos = const [],
    this.relevanceScore = 0.8,
    DateTime? generatedAt,
    this.aiModelVersion = 'gpt-4',
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// 创建总结叶子
  factory LeafAttachment.summary(String nodeId, String summaryText) {
    return LeafAttachment(
      id: 'leaf_summary_$nodeId',
      type: LeafType.summary,
      title: '要点总结',
      content: summaryText,
    );
  }

  /// 创建行动项叶子
  factory LeafAttachment.actionItems(String nodeId, List<TodoItem> items) {
    return LeafAttachment(
      id: 'leaf_actions_$nodeId',
      type: LeafType.actionItems,
      title: '行动清单',
      content: '${items.length} 个待办事项',
      todos: items,
    );
  }

  /// 添加待办事项
  LeafAttachment addTodo(TodoItem todo) {
    return copyWith(todos: [...todos, todo]);
  }

  /// 获取完成进度 0-1
  double get completionRate {
    if (todos.isEmpty) return 1.0;
    final completed = todos.where((t) => t.isCompleted).length;
    return completed / todos.length;
  }

  /// 获取颜色（基于类型）
  List<double> get color {
    switch (type) {
      case LeafType.summary:
        return [0.3, 0.8, 0.3, 0.9]; // 绿色
      case LeafType.actionItems:
        return [0.9, 0.6, 0.2, 0.9]; // 橙色
      case LeafType.decision:
        return [0.9, 0.3, 0.9, 0.9]; // 紫色
      case LeafType.riskAlert:
        return [0.9, 0.2, 0.2, 0.9]; // 红色
      case LeafType.insight:
        return [0.2, 0.6, 0.9, 0.9]; // 蓝色
      case LeafType.reference:
        return [0.6, 0.6, 0.6, 0.9]; // 灰色
    }
  }

  LeafAttachment copyWith({
    String? id,
    LeafType? type,
    String? title,
    String? content,
    List<TodoItem>? todos,
    double? relevanceScore,
    DateTime? generatedAt,
    String? aiModelVersion,
  }) {
    return LeafAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      todos: todos ?? this.todos,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      generatedAt: generatedAt ?? this.generatedAt,
      aiModelVersion: aiModelVersion ?? this.aiModelVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'content': content,
    'todos': todos.map((t) => t.toJson()).toList(),
    'relevanceScore': relevanceScore,
    'generatedAt': generatedAt.toIso8601String(),
    'aiModelVersion': aiModelVersion,
  };

  factory LeafAttachment.fromJson(Map<String, dynamic> json) {
    return LeafAttachment(
      id: json['id'] as String,
      type: LeafType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LeafType.summary,
      ),
      title: json['title'] as String,
      content: json['content'] as String,
      todos: (json['todos'] as List<dynamic>)
          .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
          .toList(),
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble() ?? 0.8,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      aiModelVersion: json['aiModelVersion'] as String? ?? 'gpt-4',
    );
  }
}

/// 叶子类型
enum LeafType {
  summary,      // 内容总结
  actionItems,  // 行动清单
  decision,     // 决策建议
  riskAlert,    // 风险提醒
  insight,      // 洞察发现
  reference,    // 关联资料
}

/// 待办事项
class TodoItem {
  final String id;
  final String description;
  final Priority priority;
  
  /// 可分配给特定参与者
  final String? assigneeId;
  final DateTime? deadline;
  final bool isCompleted;
  
  /// 溯源到原始消息
  final String? sourceMessageId;

  const TodoItem({
    required this.id,
    required this.description,
    this.priority = Priority.medium,
    this.assigneeId,
    this.deadline,
    this.isCompleted = false,
    this.sourceMessageId,
  });

  TodoItem withPriority(Priority priority) {
    return copyWith(priority: priority);
  }

  TodoItem assignTo(String assigneeId) {
    return copyWith(assigneeId: assigneeId);
  }

  TodoItem withDeadline(DateTime deadline) {
    return copyWith(deadline: deadline);
  }

  /// 标记完成
  TodoItem complete() {
    return copyWith(isCompleted: true);
  }

  /// 获取颜色（基于优先级）
  List<double> get priorityColor {
    switch (priority) {
      case Priority.low:
        return [0.4, 0.8, 0.4, 1.0]; // 浅绿
      case Priority.medium:
        return [0.9, 0.9, 0.2, 1.0]; // 黄色
      case Priority.high:
        return [0.9, 0.6, 0.2, 1.0]; // 橙色
      case Priority.critical:
        return [0.9, 0.2, 0.2, 1.0]; // 红色
    }
  }

  TodoItem copyWith({
    String? id,
    String? description,
    Priority? priority,
    String? assigneeId,
    DateTime? deadline,
    bool? isCompleted,
    String? sourceMessageId,
  }) {
    return TodoItem(
      id: id ?? this.id,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'priority': priority.name,
    'assigneeId': assigneeId,
    'deadline': deadline?.toIso8601String(),
    'isCompleted': isCompleted,
    'sourceMessageId': sourceMessageId,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      description: json['description'] as String,
      priority: Priority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => Priority.medium,
      ),
      assigneeId: json['assigneeId'] as String?,
      deadline: json['deadline'] != null 
        ? DateTime.parse(json['deadline'] as String)
        : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      sourceMessageId: json['sourceMessageId'] as String?,
    );
  }
}

/// 优先级
enum Priority {
  low,
  medium,
  high,
  critical,
}

extension PriorityExtension on Priority {
  String get label {
    switch (this) {
      case Priority.low:
        return '低';
      case Priority.medium:
        return '中';
      case Priority.high:
        return '高';
      case Priority.critical:
        return '紧急';
    }
  }

  int get value {
    switch (this) {
      case Priority.low:
        return 1;
      case Priority.medium:
        return 2;
      case Priority.high:
        return 3;
      case Priority.critical:
        return 4;
    }
  }
}
