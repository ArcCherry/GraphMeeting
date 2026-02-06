/// 拓扑分析器
/// 
/// 负责检测藤蔓结构中的：
/// - 分叉点（话题分裂）
/// - 合并点（共识达成）
/// - 里程碑（关键决策）
/// - 引用关系

import '../../models/chrono_vine/chrono_vine_data.dart';

class TopologyAnalyzer {
  /// 决策关键词
  static const Set<String> _decisionKeywords = {
    '决定', '确定', '同意', '批准', '通过',
    'decide', 'decision', 'agree', 'approve', 'confirm',
    '决议', '结论', '定论', '拍板',
    'result', 'conclusion', 'resolve',
  };

  /// 同意关键词
  static const Set<String> _agreementKeywords = {
    '同意', '赞成', '支持', '认可', '附议',
    'agree', 'support', 'approve', 'second', 'concur',
    '没问题', '可以', '好的', 'ok', 'yes',
  };

  /// 分叉关键词
  static const Set<String> _branchKeywords = {
    '但是', '不过', '然而', '另一方面',
    'but', 'however', 'although', 'on the other hand',
    '换个角度', '不同看法', '补充一点',
    'alternatively', 'instead', 'or',
  };

  /// 检测节点类型
  static VineNodeType detectNodeType(String content, {String? parentId}) {
    // 检查是否是里程碑
    if (_containsDecision(content)) {
      return VineNodeType.milestone;
    }
    
    // 检查是否是同意（合并点）
    if (_isAgreementMessage(content)) {
      return VineNodeType.merge;
    }
    
    // 检查是否是分叉点
    if (_containsBranchKeyword(content)) {
      return VineNodeType.branch;
    }
    
    // 新话题（无父节点）
    if (parentId == null) {
      return VineNodeType.branch;
    }
    
    return VineNodeType.voiceBlock;
  }

  /// 检查内容是否包含决策关键词
  static bool _containsDecision(String content) {
    final lowerContent = content.toLowerCase();
    return _decisionKeywords.any((keyword) => lowerContent.contains(keyword));
  }

  /// 检查是否是同意消息
  static bool _isAgreementMessage(String content) {
    final lowerContent = content.toLowerCase();
    return _agreementKeywords.any((keyword) => lowerContent.contains(keyword));
  }

  /// 检查是否包含分叉关键词
  static bool _containsBranchKeyword(String content) {
    final lowerContent = content.toLowerCase();
    return _branchKeywords.any((keyword) => lowerContent.contains(keyword));
  }

  /// 计算两个节点的相似度（用于合并检测）
  static double calculateSimilarity(VineNode a, VineNode b) {
    final wordsA = a.content.toLowerCase().split(' ').toSet();
    final wordsB = b.content.toLowerCase().split(' ').toSet();
    
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;
    
    final intersection = wordsA.intersection(wordsB);
    final union = wordsA.union(wordsB);
    
    return intersection.length / union.length;
  }

  /// 检测潜在合并点
  static List<MergeSuggestion> detectPotentialMerges(
    VineNode newNode,
    List<VineNode> existingNodes,
  ) {
    final suggestions = <MergeSuggestion>[];
    
    for (final node in existingNodes) {
      if (node.id == newNode.id) continue;
      if (node.authorId == newNode.authorId) continue;
      
      // 时间窗口检查
      final timeDiff = newNode.createdAt.difference(node.createdAt).abs();
      if (timeDiff > const Duration(minutes: 10)) continue;
      
      // 相似度检查
      final similarity = calculateSimilarity(newNode, node);
      if (similarity > 0.5) {
        suggestions.add(MergeSuggestion(
          targetNode: node,
          similarity: similarity,
          reason: '内容相似度 ${(similarity * 100).toStringAsFixed(0)}%',
        ));
      }
    }
    
    // 按相似度排序
    suggestions.sort((a, b) => b.similarity.compareTo(a.similarity));
    return suggestions.take(3).toList();
  }

  /// 构建贡献度报告
  static ContributionReport generateContributionReport(
    String participantId,
    List<VineNode> allNodes,
  ) {
    final myNodes = allNodes.where((n) => n.authorId == participantId).toList();
    
    // 计算各项指标
    final messageCount = myNodes.length;
    
    final totalWords = myNodes.fold<int>(
      0, 
      (sum, n) => sum + n.content.split(' ').length,
    );
    
    final branchCount = myNodes.where((n) => n.type == VineNodeType.branch).length;
    final mergeCount = myNodes.where((n) => n.type == VineNodeType.merge).length;
    final milestoneCount = myNodes.where((n) => n.type == VineNodeType.milestone).length;
    
    // 连接数（回复他人）
    final connections = myNodes.where((n) => n.parentId != null).length;
    
    // 被连接数（被他人回复）
    final myNodeIds = myNodes.map((n) => n.id).toSet();
    final referencedBy = allNodes.where((n) {
      return n.parentId != null && myNodeIds.contains(n.parentId);
    }).length;
    
    return ContributionReport(
      participantId: participantId,
      messageCount: messageCount,
      totalWords: totalWords,
      branchCount: branchCount,
      mergeCount: mergeCount,
      milestoneCount: milestoneCount,
      connections: connections,
      referencedBy: referencedBy,
      participationScore: _calculateParticipationScore(
        messageCount,
        connections,
        referencedBy,
        allNodes.length,
      ),
    );
  }

  static double _calculateParticipationScore(
    int messages,
    int connections,
    int referencedBy,
    int totalMessages,
  ) {
    if (totalMessages == 0) return 0.0;
    
    final messageRatio = messages / totalMessages;
    final connectivity = (connections + referencedBy) / (messages * 2);
    
    return (messageRatio * 0.4 + connectivity * 0.6).clamp(0.0, 1.0);
  }
}

/// 合并建议
class MergeSuggestion {
  final VineNode targetNode;
  final double similarity;
  final String reason;
  
  MergeSuggestion({
    required this.targetNode,
    required this.similarity,
    required this.reason,
  });
}

/// 贡献度报告
class ContributionReport {
  final String participantId;
  final int messageCount;
  final int totalWords;
  final int branchCount;
  final int mergeCount;
  final int milestoneCount;
  final int connections;
  final int referencedBy;
  final double participationScore;
  
  ContributionReport({
    required this.participantId,
    required this.messageCount,
    required this.totalWords,
    required this.branchCount,
    required this.mergeCount,
    required this.milestoneCount,
    required this.connections,
    required this.referencedBy,
    required this.participationScore,
  });
  
  String get participationPercentage => 
    '${(participationScore * 100).toStringAsFixed(1)}%';
}
