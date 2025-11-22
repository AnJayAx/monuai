class UserStats {
  final int points;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCheckIn;
  final List<String> unlockedAchievements;
  final int totalLandmarksVisited;
  final int totalPhotosUploaded;
  final int fortuneWheelSpinsRemaining;
  final DateTime? lastFortuneWheelSpin;
  final List<String> collectedCoupons;

  const UserStats({
    this.points = 0,
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCheckIn,
    this.unlockedAchievements = const [],
    this.totalLandmarksVisited = 0,
    this.totalPhotosUploaded = 0,
    this.fortuneWheelSpinsRemaining = 0,
    this.lastFortuneWheelSpin,
    this.collectedCoupons = const [],
  });

  int get xpToNextLevel => level * 10;
  int get progressToNextLevel => xp % xpToNextLevel;
  double get levelProgress => progressToNextLevel / xpToNextLevel;

  UserStats copyWith({
    int? points,
    int? xp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCheckIn,
    List<String>? unlockedAchievements,
    int? totalLandmarksVisited,
    int? totalPhotosUploaded,
    int? fortuneWheelSpinsRemaining,
    DateTime? lastFortuneWheelSpin,
    List<String>? collectedCoupons,
  }) {
    return UserStats(
      points: points ?? this.points,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      totalLandmarksVisited: totalLandmarksVisited ?? this.totalLandmarksVisited,
      totalPhotosUploaded: totalPhotosUploaded ?? this.totalPhotosUploaded,
      fortuneWheelSpinsRemaining:
          fortuneWheelSpinsRemaining ?? this.fortuneWheelSpinsRemaining,
      lastFortuneWheelSpin: lastFortuneWheelSpin ?? this.lastFortuneWheelSpin,
      collectedCoupons: collectedCoupons ?? this.collectedCoupons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'points': points,
      'xp': xp,
      'level': level,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'unlockedAchievements': unlockedAchievements,
      'totalLandmarksVisited': totalLandmarksVisited,
      'totalPhotosUploaded': totalPhotosUploaded,
      'fortuneWheelSpinsRemaining': fortuneWheelSpinsRemaining,
      'lastFortuneWheelSpin': lastFortuneWheelSpin?.toIso8601String(),
      'collectedCoupons': collectedCoupons,
    };
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      points: json['points'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.tryParse(json['lastCheckIn'] as String)
          : null,
      unlockedAchievements: (json['unlockedAchievements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalLandmarksVisited: json['totalLandmarksVisited'] as int? ?? 0,
      totalPhotosUploaded: json['totalPhotosUploaded'] as int? ?? 0,
      fortuneWheelSpinsRemaining:
          json['fortuneWheelSpinsRemaining'] as int? ?? 0,
      lastFortuneWheelSpin: json['lastFortuneWheelSpin'] != null
          ? DateTime.tryParse(json['lastFortuneWheelSpin'] as String)
          : null,
      collectedCoupons: (json['collectedCoupons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int pointReward;
  final bool Function(UserStats stats) isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointReward,
    required this.isUnlocked,
  });
}

class FortuneWheelReward {
  final String label;
  final int discountPercent;
  final String icon;
  final String description;
  final String couponCode;

  const FortuneWheelReward({
    required this.label,
    required this.discountPercent,
    required this.icon,
    required this.description,
    required this.couponCode,
  });
}

class TripCoupon {
  final String id;
  final String code;
  final int discountPercent;
  final String description;
  final DateTime earnedAt;
  final DateTime expiresAt;
  final bool isUsed;

  const TripCoupon({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.description,
    required this.earnedAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discountPercent': discountPercent,
      'description': description,
      'earnedAt': earnedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
    };
  }

  factory TripCoupon.fromJson(Map<String, dynamic> json) {
    return TripCoupon(
      id: json['id'] as String,
      code: json['code'] as String,
      discountPercent: json['discountPercent'] as int,
      description: json['description'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isUsed: json['isUsed'] as bool? ?? false,
    );
  }
}
