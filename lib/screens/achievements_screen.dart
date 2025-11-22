import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  UserStats? _userStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final stats = await GamificationService.loadUserStats();
    setState(() {
      _userStats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_userStats == null) {
      return const Center(child: Text('Failed to load stats'));
    }

    final unlockedCount = _userStats!.unlockedAchievements.length;
    final totalCount = GamificationService.achievements.length;

    return Column(
      children: [
        // Progress header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$unlockedCount / $totalCount',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Achievements Unlocked',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: totalCount > 0 ? unlockedCount / totalCount : 0,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        // Achievements list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: GamificationService.achievements.length,
            itemBuilder: (context, index) {
              final achievement = GamificationService.achievements[index];
              final isUnlocked = _userStats!.unlockedAchievements
                  .contains(achievement.id);
              return _buildAchievementCard(achievement, isUnlocked);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUnlocked ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isUnlocked
              ? LinearGradient(
                  colors: [
                    Colors.purple.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Colors.purple.shade100
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    achievement.icon,
                    style: TextStyle(
                      fontSize: 32,
                      color: isUnlocked ? null : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        if (isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Unlocked',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUnlocked ? Colors.black54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          size: 16,
                          color: isUnlocked
                              ? Colors.amber
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.pointReward} points',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked
                                ? Colors.deepPurple
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProgress(achievement),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(Achievement achievement) {
    if (_userStats == null) return const SizedBox.shrink();

    final isUnlocked = _userStats!.unlockedAchievements.contains(achievement.id);
    
    // Determine progress based on achievement requirements
    String progressText = '';
    double progress = 0.0;

    if (achievement.id == 'first_landmark') {
      final current = _userStats!.totalLandmarksVisited;
      progressText = '$current / 1';
      progress = current >= 1 ? 1.0 : current / 1;
    } else if (achievement.id == 'explorer_5') {
      final current = _userStats!.totalLandmarksVisited;
      progressText = '$current / 5';
      progress = current >= 5 ? 1.0 : current / 5;
    } else if (achievement.id == 'world_traveler') {
      final current = _userStats!.totalLandmarksVisited;
      progressText = '$current / 10';
      progress = current >= 10 ? 1.0 : current / 10;
    } else if (achievement.id == 'photographer') {
      final current = _userStats!.totalPhotosUploaded;
      progressText = '$current / 5';
      progress = current >= 5 ? 1.0 : current / 5;
    } else if (achievement.id == 'streak_3') {
      final current = _userStats!.currentStreak;
      progressText = '$current / 3';
      progress = current >= 3 ? 1.0 : current / 3;
    } else if (achievement.id == 'streak_7') {
      final current = _userStats!.currentStreak;
      progressText = '$current / 7';
      progress = current >= 7 ? 1.0 : current / 7;
    } else if (achievement.id == 'spin_master') {
      final current = _userStats!.fortuneWheelSpinsRemaining;
      progressText = '$current / 10';
      progress = current >= 10 ? 1.0 : current / 10;
    } else if (achievement.id == 'level_5') {
      final current = _userStats!.level;
      progressText = 'Level $current / 5';
      progress = current >= 5 ? 1.0 : current / 5;
    } else if (achievement.id == 'level_10') {
      final current = _userStats!.level;
      progressText = 'Level $current / 10';
      progress = current >= 10 ? 1.0 : current / 10;
    }

    if (progressText.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          progressText,
          style: TextStyle(
            fontSize: 12,
            color: isUnlocked ? Colors.green : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            isUnlocked ? Colors.green : Colors.deepPurple,
          ),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}
