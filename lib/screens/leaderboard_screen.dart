import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserStats? _userStats;
  List<Map<String, dynamic>> _leaderboardData = [];
  String _selectedPeriod = 'All time';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stats = await GamificationService.loadUserStats();
    final leaderboard = GamificationService.getMockLeaderboard(stats);
    if (!mounted) return;
    setState(() {
      _userStats = stats;
      _leaderboardData = leaderboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44), // Deep blue from reference
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1F44),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: _userStats == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Period selector
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PeriodChip(
                        label: 'Today',
                        isSelected: _selectedPeriod == 'Today',
                        onTap: () => setState(() => _selectedPeriod = 'Today'),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'This week',
                        isSelected: _selectedPeriod == 'This week',
                        onTap: () =>
                            setState(() => _selectedPeriod = 'This week'),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'All time',
                        isSelected: _selectedPeriod == 'All time',
                        onTap: () =>
                            setState(() => _selectedPeriod = 'All time'),
                      ),
                    ],
                  ),
                ),
                // Top 3 Podium
                _buildPodium(),
                const SizedBox(height: 24),
                // Rest of rankings
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Drag handle
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _leaderboardData.length > 3
                                ? _leaderboardData.length - 3
                                : 0,
                            itemBuilder: (context, index) {
                              final ranking = _leaderboardData[index + 3];
                              final rank = index + 4;
                              final isCurrentUser =
                                  ranking['isCurrentUser'] as bool? ?? false;
                              return _RankingItem(
                                rank: rank,
                                name: ranking['name'] as String,
                                level: ranking['level'] as int,
                                xp: ranking['xp'] as int,
                                isCurrentUser: isCurrentUser,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPodium() {
    if (_leaderboardData.length < 3) {
      return const SizedBox.shrink();
    }

    // Get top 3 (sorted by level already)
    final first = _leaderboardData[0];
    final second = _leaderboardData[1];
    final third = _leaderboardData[2];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2nd place
          _TopUserAvatar(
            rank: 2,
            name: second['name'] as String,
            level: second['level'] as int,
            color: const Color(0xFF4A90E2),
          ),
          const SizedBox(width: 24),
          // 1st place (larger)
          _TopUserAvatar(
            rank: 1,
            name: first['name'] as String,
            level: first['level'] as int,
            color: const Color(0xFFFF6B6B),
            isLarger: true,
          ),
          const SizedBox(width: 24),
          // 3rd place
          _TopUserAvatar(
            rank: 3,
            name: third['name'] as String,
            level: third['level'] as int,
            color: const Color(0xFF2F4F7F),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0A1F44) : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TopUserAvatar extends StatelessWidget {
  final int rank;
  final String name;
  final int level;
  final Color color;
  final bool isLarger;

  const _TopUserAvatar({
    required this.rank,
    required this.name,
    required this.level,
    required this.color,
    this.isLarger = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarger ? 90.0 : 70.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLarger ? 36 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (rank == 1)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name.split(' ').first,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Level $level',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RankingItem extends StatelessWidget {
  final int rank;
  final String name;
  final int level;
  final int xp;
  final bool isCurrentUser;

  const _RankingItem({
    required this.rank,
    required this.name,
    required this.level,
    required this.xp,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: Colors.blue.shade300, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser ? Colors.blue.shade200 : Colors.grey[300],
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                color: Colors.grey[900],
              ),
            ),
          ),
          // Points
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrentUser ? Icons.circle : Icons.circle_outlined,
                color: isCurrentUser ? Colors.red : Colors.grey[400],
                size: 8,
              ),
              const SizedBox(width: 4),
              Text(
                'Level $level • $xp XP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
