import 'dart:math';
import '../../models/chrono_vine/vine_node.dart';
import '../../models/chrono_vine/leaf_attachment.dart';

/// 贡献度计算器
/// 
/// 计算每个参与者的会议贡献指标：
/// - 发言数量和长度
/// - 节点影响力（被引用次数）
/// - 共识达成贡献
/// - 决策参与度
/// - Todo 完成率
/// 
/// 预留接口，用于后续商业智能功能
class ContributionCalculator {
  /// 计算所有参与者的贡献度
  Map<String, ParticipantStats> calculateAllStats(
    List<VineNode> nodes,
    List<String> participantIds,
  ) {
    final stats = <String, ParticipantStats>{};
    
    for (final id in participantIds) {
      stats[id] = calculateParticipantStats(id, nodes);
    }
    
    return stats;
  }

  /// 计算单个参与者的统计信息
  ParticipantStats calculateParticipantStats(
    String participantId,
    List<VineNode> nodes,
  ) {
    final participantNodes = nodes.where((n) => n.authorId == participantId).toList();
    
    return ParticipantStats(
      participantId: participantId,
      messageCount: _countMessages(participantNodes),
      totalWordCount: _countWords(participantNodes),
      nodeInfluence: _calculateInfluence(participantId, nodes),
      consensusContributed: _countConsensusContributions(participantNodes),
      decisionsParticipated: _countDecisionParticipation(participantNodes),
      keyNodesCreated: _countKeyNodes(participantNodes),
      todoItemsGenerated: _countTodoItems(participantNodes),
      branchPointsCreated: _countBranchPoints(participantNodes),
      mergePointsCreated: _countMergePoints(participantNodes),
      activeTimeRange: _calculateActiveTimeRange(participantNodes),
      averageResponseTime: _calculateAverageResponseTime(participantId, nodes),
    );
  }

  /// 统计消息数量
  int _countMessages(List<VineNode> nodes) => nodes.length;

  /// 统计总字数
  int _countWords(List<VineNode> nodes) {
    return nodes.fold<int>(0, (sum, node) => sum + node.content.length);
  }

  /// 计算节点影响力（被引用次数）
  double _calculateInfluence(String participantId, List<VineNode> allNodes) {
    var totalInfluence = 0.0;
    
    for (final node in allNodes.where((n) => n.authorId == participantId)) {
      // 直接引用
      final directReferences = allNodes.where((n) => 
        n.parentId == node.id || n.mergeTargetId == node.id
      ).length;
      
      // 间接影响力（通过叶子）
      final leafImpact = node.leaves.fold<double>(0, (sum, leaf) => 
        sum + leaf.relevanceScore
      );
      
      // 节点类型权重
      final typeWeight = switch (node.nodeType) {
        NodeType.milestone => 3.0,
        NodeType.merge => 2.5,
        NodeType.branch => 1.5,
        NodeType.aiSummary => 2.0,
        NodeType.message => 1.0,
      };
      
      totalInfluence += (directReferences * 0.5 + leafImpact) * typeWeight;
    }
    
    // 归一化到 0-100
    return min(totalInfluence * 10, 100);
  }

  /// 统计共识贡献次数
  int _countConsensusContributions(List<VineNode> nodes) {
    return nodes.where((n) => n.nodeType == NodeType.merge).length;
  }

  /// 统计决策参与次数
  int _countDecisionParticipation(List<VineNode> nodes) {
    return nodes.where((n) => 
      n.nodeType == NodeType.milestone || 
      n.leaves.any((l) => l.type == LeafType.decision)
    ).length;
  }

  /// 统计关键节点创建数
  int _countKeyNodes(List<VineNode> nodes) {
    return nodes.where((n) => n.isKeyNode).length;
  }

  /// 统计生成的 Todo 项
  int _countTodoItems(List<VineNode> nodes) {
    return nodes.fold<int>(0, (sum, node) => 
      sum + node.leaves.fold<int>(0, (leafSum, leaf) => 
        leafSum + leaf.todos.length
      )
    );
  }

  /// 统计创建的分叉点
  int _countBranchPoints(List<VineNode> nodes) {
    return nodes.where((n) => n.nodeType == NodeType.branch).length;
  }

  /// 统计创建的合并点
  int _countMergePoints(List<VineNode> nodes) {
    return nodes.where((n) => n.nodeType == NodeType.merge).length;
  }

  /// 计算活跃时间范围
  Duration _calculateActiveTimeRange(List<VineNode> nodes) {
    if (nodes.isEmpty) return Duration.zero;
    
    final timestamps = nodes.map((n) => n.position.timestamp).toList()..sort();
    return timestamps.last.difference(timestamps.first);
  }

  /// 计算平均响应时间
  Duration _calculateAverageResponseTime(
    String participantId,
    List<VineNode> allNodes,
  ) {
    final participantNodes = allNodes.where((n) => n.authorId == participantId).toList();
    if (participantNodes.isEmpty) return Duration.zero;
    
    var totalResponseTime = Duration.zero;
    var responseCount = 0;
    
    for (final node in participantNodes) {
      if (node.parentId != null) {
        final parent = allNodes.where((n) => n.id == node.parentId).firstOrNull;
        if (parent != null) {
          totalResponseTime += node.position.timestamp.difference(parent.position.timestamp);
          responseCount++;
        }
      }
    }
    
    if (responseCount == 0) return Duration.zero;
    return Duration(milliseconds: totalResponseTime.inMilliseconds ~/ responseCount);
  }

  /// 生成参与者对比报告
  ComparisonReport generateComparisonReport(
    Map<String, ParticipantStats> stats,
  ) {
    final sortedByInfluence = stats.values.toList()
      ..sort((a, b) => b.nodeInfluence.compareTo(a.nodeInfluence));
    
    final sortedByContribution = stats.values.toList()
      ..sort((a, b) => b.totalContributionScore.compareTo(a.totalContributionScore));
    
    return ComparisonReport(
      topInfluencer: sortedByInfluence.firstOrNull?.participantId,
      topContributor: sortedByContribution.firstOrNull?.participantId,
      influenceRankings: sortedByInfluence.map((s) => s.participantId).toList(),
      contributionRankings: sortedByContribution.map((s) => s.participantId).toList(),
      averageMessagesPerPerson: stats.values.map((s) => s.messageCount).reduce((a, b) => a + b) / stats.length,
      totalConsensusPoints: stats.values.map((s) => s.consensusContributed).reduce((a, b) => a + b),
      totalDecisionsMade: stats.values.map((s) => s.decisionsParticipated).reduce((a, b) => a + b),
    );
  }

  /// 生成协作网络图数据
  /// 
  /// 返回参与者之间的互动关系，用于可视化
  CollaborationNetwork generateCollaborationNetwork(
    List<VineNode> nodes,
    List<String> participantIds,
  ) {
    final edges = <CollaborationEdge>[];
    final nodeCounts = <String, int>{};
    
    // 统计互动
    for (final node in nodes) {
      nodeCounts[node.authorId] = (nodeCounts[node.authorId] ?? 0) + 1;
      
      if (node.parentId != null) {
        final parent = nodes.where((n) => n.id == node.parentId).firstOrNull;
        if (parent != null && parent.authorId != node.authorId) {
          edges.add(CollaborationEdge(
            from: parent.authorId,
            to: node.authorId,
            type: EdgeType.reply,
            weight: 1.0,
          ));
        }
      }
    }
    
    // 合并相同边的权重
    final edgeMap = <String, CollaborationEdge>{};
    for (final edge in edges) {
      final key = '${edge.from}->${edge.to}';
      if (edgeMap.containsKey(key)) {
        edgeMap[key] = edgeMap[key]!.copyWith(weight: edgeMap[key]!.weight + 1);
      } else {
        edgeMap[key] = edge;
      }
    }
    
    return CollaborationNetwork(
      nodes: participantIds.map((id) => NetworkNode(
        id: id,
        messageCount: nodeCounts[id] ?? 0,
      )).toList(),
      edges: edgeMap.values.toList(),
    );
  }
}

/// 参与者统计信息
class ParticipantStats {
  final String participantId;
  final int messageCount;
  final int totalWordCount;
  final double nodeInfluence;
  final int consensusContributed;
  final int decisionsParticipated;
  final int keyNodesCreated;
  final int todoItemsGenerated;
  final int branchPointsCreated;
  final int mergePointsCreated;
  final Duration activeTimeRange;
  final Duration averageResponseTime;

  ParticipantStats({
    required this.participantId,
    required this.messageCount,
    required this.totalWordCount,
    required this.nodeInfluence,
    required this.consensusContributed,
    required this.decisionsParticipated,
    required this.keyNodesCreated,
    required this.todoItemsGenerated,
    required this.branchPointsCreated,
    required this.mergePointsCreated,
    required this.activeTimeRange,
    required this.averageResponseTime,
  });

  /// 综合贡献分数（0-100）
  double get totalContributionScore {
    return min(
      (messageCount * 2) +
      (nodeInfluence * 0.5) +
      (consensusContributed * 10) +
      (decisionsParticipated * 15) +
      (keyNodesCreated * 20) +
      (mergePointsCreated * 12),
      100,
    );
  }

  /// 活跃度等级
  ActivityLevel get activityLevel {
    final score = totalContributionScore;
    if (score >= 80) return ActivityLevel.leader;
    if (score >= 60) return ActivityLevel.active;
    if (score >= 40) return ActivityLevel.participant;
    return ActivityLevel.observer;
  }

  Map<String, dynamic> toJson() => {
    'participantId': participantId,
    'messageCount': messageCount,
    'totalWordCount': totalWordCount,
    'nodeInfluence': nodeInfluence,
    'consensusContributed': consensusContributed,
    'decisionsParticipated': decisionsParticipated,
    'keyNodesCreated': keyNodesCreated,
    'todoItemsGenerated': todoItemsGenerated,
    'branchPointsCreated': branchPointsCreated,
    'mergePointsCreated': mergePointsCreated,
    'activeTimeRangeMinutes': activeTimeRange.inMinutes,
    'averageResponseTimeSeconds': averageResponseTime.inSeconds,
    'totalContributionScore': totalContributionScore,
    'activityLevel': activityLevel.name,
  };
}

/// 活跃度等级
enum ActivityLevel {
  leader,      // 领导者
  active,      // 活跃参与者
  participant, // 普通参与者
  observer,    // 观察者
}

/// 对比报告
class ComparisonReport {
  final String? topInfluencer;
  final String? topContributor;
  final List<String> influenceRankings;
  final List<String> contributionRankings;
  final double averageMessagesPerPerson;
  final int totalConsensusPoints;
  final int totalDecisionsMade;

  ComparisonReport({
    this.topInfluencer,
    this.topContributor,
    required this.influenceRankings,
    required this.contributionRankings,
    required this.averageMessagesPerPerson,
    required this.totalConsensusPoints,
    required this.totalDecisionsMade,
  });
}

/// 协作网络
class CollaborationNetwork {
  final List<NetworkNode> nodes;
  final List<CollaborationEdge> edges;

  CollaborationNetwork({
    required this.nodes,
    required this.edges,
  });
}

/// 网络节点
class NetworkNode {
  final String id;
  final int messageCount;

  NetworkNode({
    required this.id,
    required this.messageCount,
  });
}

/// 协作边
class CollaborationEdge {
  final String from;
  final String to;
  final EdgeType type;
  final double weight;

  CollaborationEdge({
    required this.from,
    required this.to,
    required this.type,
    required this.weight,
  });

  CollaborationEdge copyWith({double? weight}) => CollaborationEdge(
    from: from,
    to: to,
    type: type,
    weight: weight ?? this.weight,
  );
}

/// 边类型
enum EdgeType {
  reply,      // 回复
  reference,  // 引用
  agree,      // 同意
  branch,     // 分叉
}

/// 扩展方法
extension MinExtension on num {
  T min<T extends num>(T other) => this < other ? this as T : other;
}
