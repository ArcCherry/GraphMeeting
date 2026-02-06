import 'package:flutter/material.dart';

/// 参与者轨道指示器
/// 
/// 显示所有参与者在时间轴上的位置，
/// 帮助用户快速定位特定参与者的发言
class ParticipantRail extends StatelessWidget {
  final Map<String, Color> participantColors;
  final String? highlightedParticipantId;
  final Function(String)? onParticipantTap;
  final Function(String)? onParticipantHover;

  const ParticipantRail({
    super.key,
    required this.participantColors,
    this.highlightedParticipantId,
    this.onParticipantTap,
    this.onParticipantHover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // 标题图标
          const Icon(
            Icons.people,
            color: Colors.white54,
            size: 20,
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, indent: 8, endIndent: 8),
          const SizedBox(height: 8),
          
          // 参与者头像列表
          ...participantColors.entries.map((entry) {
            final isHighlighted = entry.key == highlightedParticipantId;
            return _buildParticipantAvatar(
              id: entry.key,
              color: entry.value,
              isHighlighted: isHighlighted,
            );
          }),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar({
    required String id,
    required Color color,
    required bool isHighlighted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        onEnter: (_) => onParticipantHover?.call(id),
        onExit: (_) => onParticipantHover?.call(''),
        child: GestureDetector(
          onTap: () => onParticipantTap?.call(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isHighlighted
                ? Border.all(color: Colors.white, width: 3)
                : null,
              boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
            ),
            child: Center(
              child: Text(
                id.substring(0, min(1, id.length)).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}

/// 扩展版参与者轨道（带统计信息）
class ParticipantRailExtended extends StatelessWidget {
  final Map<String, ParticipantStats> participantStats;
  final Map<String, Color> participantColors;
  final String? highlightedParticipantId;
  final Function(String)? onParticipantTap;
  final VoidCallback? onStatsExpand;

  const ParticipantRailExtended({
    super.key,
    required this.participantStats,
    required this.participantColors,
    this.highlightedParticipantId,
    this.onParticipantTap,
    this.onStatsExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '参与者',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart, color: Colors.white70, size: 18),
                  onPressed: onStatsExpand,
                  tooltip: '查看统计',
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          
          // 参与者列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: participantStats.length,
              itemBuilder: (context, index) {
                final entry = participantStats.entries.elementAt(index);
                final isHighlighted = entry.key == highlightedParticipantId;
                
                return _buildParticipantCard(
                  id: entry.key,
                  stats: entry.value,
                  color: participantColors[entry.key] ?? Colors.grey,
                  isHighlighted: isHighlighted,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required String id,
    required ParticipantStats stats,
    required Color color,
    required bool isHighlighted,
  }) {
    return InkWell(
      onTap: () => onParticipantTap?.call(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isHighlighted ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isHighlighted
            ? Border.all(color: color, width: 2)
            : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  id.substring(0, min(1, id.length)).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble, size: 10, color: color.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.messageCount}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.leaderboard, size: 10, color: Colors.amber.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.nodeInfluence.toInt()}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 活跃度指示
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _getActivityColor(stats.activityLevel),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActivityColor(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.leader => Colors.purple,
      ActivityLevel.active => Colors.green,
      ActivityLevel.participant => Colors.blue,
      ActivityLevel.observer => Colors.grey,
    };
  }

  int min(int a, int b) => a < b ? a : b;
}

// 占位类，实际应从 contribution_calculator.dart 导入
class ParticipantStats {
  final String participantId;
  final int messageCount;
  final double nodeInfluence;
  final ActivityLevel activityLevel;

  ParticipantStats({
    required this.participantId,
    required this.messageCount,
    required this.nodeInfluence,
    this.activityLevel = ActivityLevel.observer,
  });
}

enum ActivityLevel {
  leader,
  active,
  participant,
  observer,
}
