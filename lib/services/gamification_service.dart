import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamification_models.dart';

class GamificationService {
  static const String _kUserStatsKey = 'user_stats';

  // Achievements definitions
  static final List<Achievement> achievements = [
    Achievement(
      id: 'first_landmark',
      title: 'First Steps',
      description: 'Discover your first landmark',
      icon: '🎯',
      pointReward: 50,
      isUnlocked: (stats) => stats.totalLandmarksVisited >= 1,
    ),
    Achievement(
      id: 'explorer_5',
      title: 'Explorer',
      description: 'Visit 5 different landmarks',
      icon: '🗺️',
      pointReward: 100,
      isUnlocked: (stats) => stats.totalLandmarksVisited >= 5,
    ),
    Achievement(
      id: 'world_traveler',
      title: 'World Traveler',
      description: 'Visit 10 different landmarks',
      icon: '🌍',
      pointReward: 200,
      isUnlocked: (stats) => stats.totalLandmarksVisited >= 10,
    ),
    Achievement(
      id: 'photographer',
      title: 'Photographer',
      description: 'Upload 5 photos',
      icon: '📸',
      pointReward: 100,
      isUnlocked: (stats) => stats.totalPhotosUploaded >= 5,
    ),
    Achievement(
      id: 'streak_3',
      title: 'On Fire!',
      description: 'Maintain a 3-day streak',
      icon: '🔥',
      pointReward: 75,
      isUnlocked: (stats) => stats.currentStreak >= 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Committed',
      description: 'Maintain a 7-day streak',
      icon: '⚡',
      pointReward: 150,
      isUnlocked: (stats) => stats.currentStreak >= 7,
    ),
    Achievement(
      id: 'level_5',
      title: 'Rising Star',
      description: 'Reach level 5',
      icon: '⭐',
      pointReward: 250,
      isUnlocked: (stats) => stats.level >= 5,
    ),
    Achievement(
      id: 'level_10',
      title: 'Legend',
      description: 'Reach level 10',
      icon: '👑',
      pointReward: 500,
      isUnlocked: (stats) => stats.level >= 10,
    ),
  ];

  static final List<FortuneWheelReward> wheelRewards = [
    const FortuneWheelReward(
      label: '50',
      discountPercent: 50,
      icon: '🎯',
      description: '50 Points',
      couponCode: 'POINTS50',
    ),
    const FortuneWheelReward(
      label: '100',
      discountPercent: 100,
      icon: '🎯',
      description: '100 Points',
      couponCode: 'POINTS100',
    ),
    const FortuneWheelReward(
      label: '150',
      discountPercent: 150,
      icon: '🎁',
      description: '150 Points',
      couponCode: 'POINTS150',
    ),
    const FortuneWheelReward(
      label: '200',
      discountPercent: 200,
      icon: '💎',
      description: '200 Points',
      couponCode: 'POINTS200',
    ),
    const FortuneWheelReward(
      label: '75',
      discountPercent: 75,
      icon: '🌟',
      description: '75 Points',
      couponCode: 'POINTS75',
    ),
    const FortuneWheelReward(
      label: '125',
      discountPercent: 125,
      icon: '✨',
      description: '125 Points',
      couponCode: 'POINTS125',
    ),
  ];

  // Load user stats
  static Future<UserStats> loadUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_kUserStatsKey);
    if (statsJson == null) {
      return const UserStats();
    }
    try {
      final decoded = jsonDecode(statsJson) as Map<String, dynamic>;
      return UserStats.fromJson(decoded);
    } catch (_) {
      return const UserStats();
    }
  }

  // Save user stats
  static Future<void> saveUserStats(UserStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserStatsKey, jsonEncode(stats.toJson()));
  }

  // Award points (without affecting level)
  static Future<UserStats> awardPoints(
    UserStats currentStats,
    int points, {
    String? reason,
  }) async {
    final newPoints = currentStats.points + points;

    var updatedStats = currentStats.copyWith(
      points: newPoints,
    );

    // Check for newly unlocked achievements
    final newAchievements = <String>[];
    for (final achievement in achievements) {
      if (!updatedStats.unlockedAchievements.contains(achievement.id) &&
          achievement.isUnlocked(updatedStats)) {
        newAchievements.add(achievement.id);
        updatedStats = updatedStats.copyWith(
          unlockedAchievements: [
            ...updatedStats.unlockedAchievements,
            achievement.id,
          ],
          points: updatedStats.points + achievement.pointReward,
        );
      }
    }

    await saveUserStats(updatedStats);
    return updatedStats;
  }

  // Award XP and handle level ups
  static Future<UserStats> awardXP(
    UserStats currentStats,
    int xpAmount,
  ) async {
    final newXP = currentStats.xp + xpAmount;
    
    // Calculate level based on XP (Level 1: 10 XP, Level 2: 20 XP, etc.)
    int newLevel = 1;
    int totalXPNeeded = 0;
    while (totalXPNeeded + (newLevel * 10) <= newXP) {
      totalXPNeeded += newLevel * 10;
      newLevel++;
    }

    final updatedStats = currentStats.copyWith(
      xp: newXP,
      level: newLevel,
    );

    await saveUserStats(updatedStats);
    return updatedStats;
  }

  // Update streak (call this when user opens app or discovers landmark)
  static Future<UserStats> updateStreak(UserStats currentStats) async {
    final now = DateTime.now();
    final lastCheckIn = currentStats.lastCheckIn;

    if (lastCheckIn == null) {
      // First time
      final updatedStats = currentStats.copyWith(
        currentStreak: 1,
        longestStreak: 1,
        lastCheckIn: now,
      );
      await saveUserStats(updatedStats);
      return updatedStats;
    }

    final daysDiff = now.difference(lastCheckIn).inDays;

    if (daysDiff == 0) {
      // Same day, no change
      return currentStats;
    } else if (daysDiff == 1) {
      // Next day, increment streak
      final newStreak = currentStats.currentStreak + 1;
      final updatedStats = currentStats.copyWith(
        currentStreak: newStreak,
        longestStreak: newStreak > currentStats.longestStreak
            ? newStreak
            : currentStats.longestStreak,
        lastCheckIn: now,
      );
      // Award streak bonus points
      final withPoints = await awardPoints(updatedStats, 10, reason: 'Daily streak');
      return withPoints;
    } else {
      // Streak broken
      final updatedStats = currentStats.copyWith(
        currentStreak: 1,
        lastCheckIn: now,
      );
      await saveUserStats(updatedStats);
      return updatedStats;
    }
  }

  // Record landmark visit - awards spin, 5 points, and 2 XP
  static Future<UserStats> recordLandmarkVisit(UserStats currentStats) async {
    final updatedStats = currentStats.copyWith(
      totalLandmarksVisited: currentStats.totalLandmarksVisited + 1,
      fortuneWheelSpinsRemaining: currentStats.fortuneWheelSpinsRemaining + 1,
    );
    // Award points and XP
    final withPoints = await awardPoints(updatedStats, 5);
    return await awardXP(withPoints, 2);
  }

  // Record photo upload
  static Future<UserStats> recordPhotoUpload(UserStats currentStats) async {
    final updatedStats = currentStats.copyWith(
      totalPhotosUploaded: currentStats.totalPhotosUploaded + 1,
    );
    return await awardPoints(updatedStats, 25, reason: 'Photo uploaded');
  }

  // Spin fortune wheel
  static Future<UserStats?> spinFortuneWheel(UserStats currentStats) async {
    if (currentStats.fortuneWheelSpinsRemaining <= 0) {
      return null; // No spins left
    }

    final updatedStats = currentStats.copyWith(
      fortuneWheelSpinsRemaining: currentStats.fortuneWheelSpinsRemaining - 1,
      lastFortuneWheelSpin: DateTime.now(),
    );

    await saveUserStats(updatedStats);
    return updatedStats;
  }

  // Collect coupon from wheel spin
  static Future<UserStats> collectCoupon(
    UserStats currentStats,
    FortuneWheelReward reward,
  ) async {
    final couponId = 'TRIP${DateTime.now().millisecondsSinceEpoch}';
    final coupon = TripCoupon(
      id: couponId,
      code: reward.couponCode,
      discountPercent: reward.discountPercent,
      description: reward.description,
      earnedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    final updatedCoupons = [
      ...currentStats.collectedCoupons,
      jsonEncode(coupon.toJson()),
    ];

    final updatedStats = currentStats.copyWith(
      collectedCoupons: updatedCoupons,
    );

    await saveUserStats(updatedStats);
    return updatedStats;
  }

  // Get collected coupons
  static List<TripCoupon> getCoupons(UserStats stats) {
    return stats.collectedCoupons
        .map((json) {
          try {
            return TripCoupon.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .whereType<TripCoupon>()
        .toList();
  }

  // Remove daily reset function (no longer needed)
  // Spins are now earned by discovering landmarks

  // Mock leaderboard data (in real app, fetch from server)
  static List<Map<String, dynamic>> getMockLeaderboard(
    UserStats currentUserStats,
  ) {
    return [
      {
        'name': 'You',
        'level': currentUserStats.level,
        'xp': currentUserStats.xp,
        'isCurrentUser': true,
      },
      {'name': 'Maxwell', 'level': 5, 'xp': 42, 'isCurrentUser': false},
      {'name': 'Camelia', 'level': 4, 'xp': 35, 'isCurrentUser': false},
      {'name': 'Wilson', 'level': 3, 'xp': 28, 'isCurrentUser': false},
      {'name': 'Jessica Anderson', 'level': 3, 'xp': 15, 'isCurrentUser': false},
      {'name': 'Sophia Anderson', 'level': 2, 'xp': 18, 'isCurrentUser': false},
      {'name': 'Ethan Carlier', 'level': 2, 'xp': 8, 'isCurrentUser': false},
      {'name': 'Liam Johnson', 'level': 1, 'xp': 6, 'isCurrentUser': false},
    ]..sort((a, b) {
      final levelCompare = (b['level'] as int).compareTo(a['level'] as int);
      if (levelCompare != 0) return levelCompare;
      return (b['xp'] as int).compareTo(a['xp'] as int);
    });
  }
}
