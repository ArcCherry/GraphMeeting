import 'package:flutter/material.dart';
import '../../models/chrono_vine/leaf_attachment.dart';
import '../../models/chrono_vine/vine_node.dart';

/// 叶子详情面板
/// 
/// 展示 AI 生成的语义层叠内容：
/// - 总结内容
/// - Todo 清单（可交互）
/// - 决策建议
/// - 风险提醒等
class LeafDetailPanel extends StatelessWidget {
  final LeafAttachment leaf;
  final VineNode node;
  final VoidCallback? onClose;
  final Function(TodoItem)? onTodoToggled;
  final Function(TodoItem)? onTodoAssigneeChanged;

  const LeafDetailPanel({
    super.key,
    required this.leaf,
    required this.node,
    this.onClose,
    this.onTodoToggled,
    this.onTodoAssigneeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 80,
      width: 360,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor().withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getPrimaryColor().withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getPrimaryColor().withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部
                _buildHeader(),
                
                // 内容区域
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 关联度指示
                        _buildRelevanceIndicator(),
                        
                        const SizedBox(height: 12),
                        
                        // 主要内容
                        Text(
                          leaf.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        
                        // Todo 清单
                        if (leaf.todos.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildTodoSection(),
                        ],
                        
                        // 溯源信息
                        const SizedBox(height: 20),
                        _buildSourceInfo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getPrimaryColor().withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: _getPrimaryColor().withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getLeafIcon(),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leaf.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getLeafTypeLabel(),
                  style: TextStyle(
                    color: _getPrimaryColor(),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  /// 构建关联度指示
  Widget _buildRelevanceIndicator() {
    return Row(
      children: [
        Icon(
          Icons.link,
          size: 14,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 4),
        Text(
          '关联度: ${(leaf.relevanceScore * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: leaf.relevanceScore,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getPrimaryColor(),
              ),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建 Todo 部分
  Widget _buildTodoSection() {
    final completedCount = leaf.todos.where((t) => t.isCompleted).length;
    final totalCount = leaf.todos.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                '行动清单 ($completedCount/$totalCount)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          ...leaf.todos.map((todo) => _buildTodoItem(todo)),
        ],
      ),
    );
  }

  /// 构建单个 Todo 项
  Widget _buildTodoItem(TodoItem todo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: todo.isCompleted,
            onChanged: (value) => onTodoToggled?.call(todo),
            activeColor: Colors.green,
            side: const BorderSide(color: Colors.white54),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.description,
                  style: TextStyle(
                    color: todo.isCompleted ? Colors.white38 : Colors.white,
                    fontSize: 13,
                    decoration: todo.isCompleted 
                      ? TextDecoration.lineThrough 
                      : null,
                  ),
                ),
                if (todo.assigneeId != null || todo.deadline != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (todo.assigneeId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '@${todo.assigneeId}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (todo.assigneeId != null && todo.deadline != null)
                          const SizedBox(width: 8),
                        if (todo.deadline != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getDeadlineColor(todo.deadline!).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDeadline(todo.deadline!),
                              style: TextStyle(
                                color: _getDeadlineColor(todo.deadline!),
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _buildPriorityIndicator(todo.priority),
        ],
      ),
    );
  }

  /// 构建优先级指示
  Widget _buildPriorityIndicator(Priority priority) {
    final color = switch (priority) {
      Priority.critical => Colors.red,
      Priority.high => Colors.orange,
      Priority.medium => Colors.yellow,
      Priority.low => Colors.green,
    };

    return Tooltip(
      message: priority.label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// 构建溯源信息
  Widget _buildSourceInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 生成',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                leaf.aiModelVersion,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '生成时间: ${_formatDateTime(leaf.generatedAt)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '源节点: ${node.contentPreview.substring(0, min(30, node.contentPreview.length))}...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 辅助方法 ====================

  Color _getPrimaryColor() {
    return switch (leaf.type) {
      LeafType.summary => const Color(0xFF4CAF50),      // 绿色
      LeafType.actionItems => const Color(0xFFFF9800),  // 橙色
      LeafType.decision => const Color(0xFFE91E63),     // 粉色
      LeafType.riskAlert => const Color(0xFFF44336),    // 红色
      LeafType.insight => const Color(0xFF2196F3),      // 蓝色
      LeafType.reference => const Color(0xFF9E9E9E),    // 灰色
    };
  }

  Color _getBackgroundColor() {
    return switch (leaf.type) {
      LeafType.summary => const Color(0xFF1B5E20),
      LeafType.actionItems => const Color(0xFFE65100),
      LeafType.decision => const Color(0xFF880E4F),
      LeafType.riskAlert => const Color(0xFFB71C1C),
      LeafType.insight => const Color(0xFF0D47A1),
      LeafType.reference => const Color(0xFF424242),
    };
  }

  String _getLeafIcon() {
    return switch (leaf.type) {
      LeafType.summary => '📝',
      LeafType.actionItems => '✓',
      LeafType.decision => '◆',
      LeafType.riskAlert => '⚠️',
      LeafType.insight => '💡',
      LeafType.reference => '🔗',
    };
  }

  String _getLeafTypeLabel() {
    return switch (leaf.type) {
      LeafType.summary => '内容总结',
      LeafType.actionItems => '行动清单',
      LeafType.decision => '决策建议',
      LeafType.riskAlert => '风险提醒',
      LeafType.insight => '洞察发现',
      LeafType.reference => '关联资料',
    };
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    
    if (diff.isNegative) return Colors.red;
    if (diff.inDays < 1) return Colors.orange;
    if (diff.inDays < 3) return Colors.yellow;
    return Colors.green;
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    
    if (diff.isNegative) return '已逾期';
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '明天';
    return '${diff.inDays}天后';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  int min(int a, int b) => a < b ? a : b;
}
