import 'dart:math';
import 'vine_node.dart';

/// 藤蔓拓扑结构
/// 
/// 定义藤蔓图的整体拓扑关系，包括：
/// - 所有节点
/// - 边连接关系
/// - 主分支路径
/// - 分叉/合并点索引
/// /// 性能优化：内部使用 Map 索引实现 O(1) 节点查找
class VineTopology {
  /// 所有节点列表（对外只读）
  final List<VineNode> nodes;

  /// 边连接关系
  final List<VineEdge> edges;

  /// 主分支（时间主线）
  final List<String> mainBranch;

  /// 分叉点映射：父节点 -> 分支列表
  final Map<String, List<String>> branchPoints;

  /// 合并点映射：目标节点 -> 来源列表
  final Map<String, List<String>> mergePoints;

  /// 里程碑索引
  final List<String> milestones;

  // ===== 内部索引（性能优化）=====
  late final Map<String, VineNode> _nodeMap;
  late final Map<String, List<VineNode>> _childrenMap;

  VineTopology({
    required this.nodes,
    required this.edges,
    required this.mainBranch,
    required this.branchPoints,
    required this.mergePoints,
    required this.milestones,
  }) {
    // 构建索引
    _nodeMap = {for (var n in nodes) n.id: n};
    _childrenMap = {};
    for (final node in nodes) {
      if (node.parentId != null) {
        _childrenMap.putIfAbsent(node.parentId!, () => []);
        _childrenMap[node.parentId!]!.add(node);
      }
    }
  }

  factory VineTopology.fromNodes(List<VineNode> nodes) {
    final edges = <VineEdge>[];
    final mainBranch = <String>[];
    final branchPoints = <String, List<String>>{};
    final mergePoints = <String, List<String>>{};
    final milestones = <String>[];

    // 构建边和索引
    for (final node in nodes) {
      // 主分支：无父节点或父节点在主分支上的节点
      if (node.parentId == null) {
        mainBranch.add(node.id);
      }

      // 创建边
      if (node.parentId != null) {
        edges.add(VineEdge(
          from: node.parentId!,
          to: node.id,
          type: node.nodeType == NodeType.merge
              ? EdgeType.merge
              : EdgeType.temporal,
        ));
      }

      // 记录分叉点
      if (node.branchIds.isNotEmpty) {
        branchPoints[node.id] = node.branchIds;
      }

      // 记录合并点
      if (node.mergeTargetId != null) {
        mergePoints.putIfAbsent(node.mergeTargetId!, () => []);
        mergePoints[node.mergeTargetId!]!.add(node.id);
      }

      // 记录里程碑
      if (node.nodeType == NodeType.milestone) {
        milestones.add(node.id);
      }
    }

    return VineTopology(
      nodes: nodes,
      edges: edges,
      mainBranch: mainBranch,
      branchPoints: branchPoints,
      mergePoints: mergePoints,
      milestones: milestones,
    );
  }

  // ===== O(1) 查找方法 =====

  /// 根据 ID 获取节点（O(1)）
  VineNode? getNode(String id) => _nodeMap[id];

  /// 获取节点的直接子节点（O(1)）
  List<VineNode> getChildren(String nodeId) {
    return _childrenMap[nodeId] ?? [];
  }

  /// 获取节点的深度（距离主分支的距离）
  /// 
  /// 时间复杂度：O(depth)，depth 通常很小（<10）
  int getNodeDepth(String nodeId) {
    var depth = 0;
    var currentId = nodeId;

    while (true) {
      final node = _nodeMap[currentId];
      if (node == null) break;

      if (mainBranch.contains(node.id)) break;
      if (node.parentId == null) break;

      depth++;
      currentId = node.parentId!;
    }

    return depth;
  }

  /// 获取节点的所有祖先
  /// 
  /// 时间复杂度：O(depth)
  List<VineNode> getAncestors(String nodeId) {
    final ancestors = <VineNode>[];
    final node = _nodeMap[nodeId];
    if (node == null) return ancestors;

    var currentId = node.parentId;
    while (currentId != null) {
      final parent = _nodeMap[currentId];
      if (parent == null) break;

      ancestors.add(parent);
      currentId = parent.parentId;
    }

    return ancestors;
  }

  /// 获取节点的所有后代
  /// 
  /// 时间复杂度：O(subtree_size)
  List<VineNode> getDescendants(String nodeId) {
    final descendants = <VineNode>[];
    if (!_nodeMap.containsKey(nodeId)) return descendants;

    void collect(String id) {
      final children = _childrenMap[id] ?? [];
      for (final child in children) {
        descendants.add(child);
        collect(child.id);
      }
    }

    collect(nodeId);
    return descendants;
  }

  /// 获取从根到节点的路径
  /// 
  /// 时间复杂度：O(depth)
  List<VineNode> getPathToRoot(String nodeId) {
    final path = <VineNode>[];
    final node = _nodeMap[nodeId];
    if (node == null) return path;

    path.add(node);
    path.addAll(getAncestors(nodeId));
    return path;
  }

  /// 获取两个节点的最近公共祖先
  /// 
  /// 时间复杂度：O(depth1 + depth2)
  VineNode? getCommonAncestor(String nodeId1, String nodeId2) {
    final ancestors1 = <String>{};
    
    // 收集 nodeId1 的所有祖先（包括自身）
    String? currentId = nodeId1;
    while (currentId != null) {
      ancestors1.add(currentId);
      final node = _nodeMap[currentId];
      if (node == null) break;
      currentId = node.parentId;
    }

    // 检查 nodeId2 的祖先
    currentId = nodeId2;
    while (currentId != null) {
      if (ancestors1.contains(currentId)) {
        return _nodeMap[currentId];
      }
      final node = _nodeMap[currentId];
      if (node == null) break;
      currentId = node.parentId;
    }

    return null;
  }

  /// 获取分叉的子树
  /// 
  /// 时间复杂度：O(subtree_size)
  List<VineNode> getBranchSubtree(String branchPointId) {
    final branchIds = branchPoints[branchPointId];
    if (branchIds == null) return [];

    final subtree = <VineNode>[];
    for (final branchId in branchIds) {
      final branchRoot = _nodeMap[branchId];
      if (branchRoot != null) {
        subtree.add(branchRoot);
        subtree.addAll(getDescendants(branchId));
      }
    }

    return subtree;
  }

  /// 获取时间范围内的节点
  /// 
  /// 时间复杂度：O(n)
  List<VineNode> getNodesInTimeRange(DateTime start, DateTime end) {
    return nodes.where((n) {
      final ts = n.position.timestamp;
      return ts.isAfter(start) && ts.isBefore(end);
    }).toList();
  }

  /// 获取参与者相关的所有节点
  /// 
  /// 时间复杂度：O(n)
  List<VineNode> getParticipantNodes(String participantId) {
    return nodes.where((n) => n.authorId == participantId).toList();
  }

  /// 计算拓扑复杂度
  TopologyMetrics calculateMetrics() {
    final totalNodes = nodes.length;
    final totalBranches = branchPoints.length;
    final totalMerges = mergePoints.length;

    // 平均分支深度
    var totalDepth = 0;
    for (final node in nodes) {
      totalDepth += getNodeDepth(node.id);
    }
    final avgDepth = totalNodes > 0 ? totalDepth / totalNodes : 0;

    // 分叉率
    final branchingFactor =
        totalNodes > 0 ? totalBranches / totalNodes : 0;

    // 合并率
    final mergeRate = totalNodes > 0 ? totalMerges / totalNodes : 0;

    return TopologyMetrics(
      totalNodes: totalNodes,
      totalBranches: totalBranches,
      totalMerges: totalMerges,
      totalMilestones: milestones.length,
      averageDepth: avgDepth.toDouble(),
      branchingFactor: branchingFactor.toDouble(),
      mergeRate: mergeRate.toDouble(),
      convergenceScore:
          totalBranches > 0 ? totalMerges / totalBranches : 1.0,
    );
  }
}

/// 藤蔓边
class VineEdge {
  final String from;
  final String to;
  final EdgeType type;

  const VineEdge({
    required this.from,
    required this.to,
    required this.type,
  });
}

/// 边类型
enum EdgeType {
  temporal, // 时间序边
  branch, // 分叉边
  merge, // 合并边
  reference, // 引用边
}

/// 拓扑指标
class TopologyMetrics {
  final int totalNodes;
  final int totalBranches;
  final int totalMerges;
  final int totalMilestones;
  final double averageDepth;
  final double branchingFactor;
  final double mergeRate;
  final double convergenceScore;

  const TopologyMetrics({
    required this.totalNodes,
    required this.totalBranches,
    required this.totalMerges,
    required this.totalMilestones,
    required this.averageDepth,
    required this.branchingFactor,
    required this.mergeRate,
    required this.convergenceScore,
  });

  Map<String, dynamic> toJson() => {
        'totalNodes': totalNodes,
        'totalBranches': totalBranches,
        'totalMerges': totalMerges,
        'totalMilestones': totalMilestones,
        'averageDepth': averageDepth,
        'branchingFactor': branchingFactor,
        'mergeRate': mergeRate,
        'convergenceScore': convergenceScore,
      };
}

/// 扩展方法
extension VineTopologyExtensions on List<VineNode> {
  VineTopology toTopology() => VineTopology.fromNodes(this);
}
