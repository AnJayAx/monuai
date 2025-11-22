import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'landmark_photo_screen.dart';
import 'package:country_flags/country_flags.dart';
import 'leaderboard_screen.dart';
import 'fortune_wheel_screen.dart';
import 'coupons_screen.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class Country {
  final String name;
  final List<String> landmarks;
  final String code; // ISO2 lowercase e.g., 'sg', 'jp'
  final String? emoji; // Optional flag/emoji for fun UI

  const Country({
    required this.name,
    required this.landmarks,
    required this.code,
    this.emoji,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _kDiscoveredKey = 'discovered_landmarks';
  static const String _kPhotosKey = 'landmark_photos';
  static const String _kConfirmedKey = 'confirmed_landmarks';
  static const String _kDescriptionsKey = 'landmark_descriptions';
  static const String _kCapturedAtKey = 'landmark_captured_at';
  Set<String> _discovered = <String>{};
  Map<String, String> _photoPaths = <String, String>{};
  Map<String, String> _capturedAt = <String, String>{};
  UserStats? _userStats;

  @override
  void initState() {
    super.initState();
    _loadDiscovered();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final stats = await GamificationService.loadUserStats();
    final updatedStats = await GamificationService.updateStreak(stats);
    if (!mounted) return;
    setState(() {
      _userStats = updatedStats;
    });
  }

  Future<void> _loadDiscovered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDiscoveredKey) ?? <String>[];
      final photosJson = prefs.getString(_kPhotosKey);
      final capturedJson = prefs.getString(_kCapturedAtKey);
      Map<String, String> photoMap = <String, String>{};
      Map<String, String> capturedMap = <String, String>{};
      if (photosJson != null) {
        try {
          final decoded = jsonDecode(photosJson) as Map<String, dynamic>;
          photoMap = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      if (capturedJson != null) {
        try {
          final decoded = jsonDecode(capturedJson) as Map<String, dynamic>;
          capturedMap = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _discovered = list.toSet();
        _photoPaths = photoMap;
        _capturedAt = capturedMap;
      });
    } catch (_) {}
  }

  // Countries and their landmarks (can be moved to a separate data file later)
  final List<Country> _countries = const [
    Country(
      name: 'Singapore',
      code: 'sg',
      emoji: '🇸🇬',
      landmarks: [
        'Merlion',
        'Marina Bay Sands',
        'Esplanade',
        'Art Science Museum',
      ],
    ),
    Country(
      name: 'Japan',
      code: 'jp',
      emoji: '🇯🇵',
      landmarks: ['Himeji Castle', 'Kinkaku-ji', 'Tokyo Tower', 'Osaka Castle'],
    ),
    Country(
      name: 'France',
      code: 'fr',
      emoji: '🇫🇷',
      landmarks: [
        'Eiffel Tower',
        'Louvre Museum',
        'Arc de Triomphe',
        'Notre-Dame Cathedral',
      ],
    ),
    Country(
      name: 'Malaysia',
      code: 'my',
      emoji: '🇲🇾',
      landmarks: [
        'Petronas Twin Towers',
        'Menara KL Tower',
        'Batu Caves',
        'Stadthuys (Malacca)',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Landmarks'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Delete all detected landmarks',
            icon: const Icon(Icons.delete_forever),
            onPressed: _confirmAndResetAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDiscovered();
          await _loadUserStats();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Gamification header
            if (_userStats != null)
              SliverToBoxAdapter(
                child: _buildGamificationHeader(),
              ),
            // Countries list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final country = _countries[index];
                  return _buildCountryCard(country);
                },
                childCount: _countries.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationHeader() {
    final stats = _userStats!;
    final leaderboardRank = _getLeaderboardRank(stats);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text(
            'Welcome back!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          // Stats cards row
          Row(
            children: [
              Expanded(
                child: _StatsCard(
                  icon: Icons.stars,
                  label: 'Points',
                  value: '${stats.points}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatsCard(
                  icon: Icons.emoji_events,
                  label: 'Rank',
                  value: '#$leaderboardRank',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatsCard(
                  icon: Icons.explore,
                  label: 'Total Landmarks',
                  value: '${stats.totalLandmarksVisited}',
                  color: Colors.blue,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Statistics dashboard coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Level and XP bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.military_tech, color: Colors.purple[700], size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Level ${stats.level}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${stats.xp} / ${stats.xpToNextLevel} XP',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: stats.levelProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            children: [
              // Fortune wheel button
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FortuneWheelScreen(),
                      ),
                    );
                    await _loadUserStats();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF5856D6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.casino, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Spin (${stats.fortuneWheelSpinsRemaining})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Coupons button
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CouponsScreen(),
                      ),
                    );
                    await _loadUserStats();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Coupons (${stats.collectedCoupons.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  int _getLeaderboardRank(UserStats stats) {
    final leaderboard = GamificationService.getMockLeaderboard(stats);
    for (int i = 0; i < leaderboard.length; i++) {
      if (leaderboard[i]['isCurrentUser'] == true) {
        return i + 1;
      }
    }
    return leaderboard.length;
  }

  Widget _buildCountryCard(Country country) {
    return Card(
      child: Stack(
        children: [
          // Background image with subtle blur and gradient overlay
          Positioned.fill(
            child: _CountryHeaderBackground(code: country.code),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),
          Theme(
            data: Theme.of(
              context,
            ).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              childrenPadding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 12,
              ),
              leading: CountryFlag.fromCountryCode(
                country.code,
                height: 20,
                width: 28,
                borderRadius: 4,
              ),
              title: Text(
                country.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${_visitedCount(country)}/${country.landmarks.length} landmarks visited',
                style: const TextStyle(color: Colors.white70),
              ),
              children: [
                const SizedBox(height: 4),
                ...country.landmarks.map((lm) {
                  final discovered = _discovered.contains(lm);
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: discovered
                        ? Colors.green.shade50
                        : Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.7),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: discovered
                            ? Colors.green
                            : Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        lm,
                        style: TextStyle(
                          color: discovered
                              ? Colors.green[800]
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: discovered
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                      subtitle: discovered && _capturedAt[lm] != null
                          ? Text(
                              'Captured on ${_formatTimestamp(_capturedAt[lm]!)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: discovered
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : null,
                      onTap: () async {
                        final path = _photoPaths[lm];
                        if (discovered &&
                            path != null &&
                            path.isNotEmpty) {
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LandmarkPhotoScreen(
                                landmark: lm,
                                imagePath: path,
                              ),
                            ),
                          );
                        } else {
                          _onLandmarkTap(country.name, lm);
                        }
                        await _loadDiscovered();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';
  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  int _visitedCount(Country country) {
    int count = 0;
    for (final lm in country.landmarks) {
      if (_discovered.contains(lm)) count++;
    }
    return count;
  }

  void _onLandmarkTap(String country, String landmark) {
    // Placeholder action for now: show a snackbar.
    // Later, this can navigate to a scan or details screen.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: $landmark ($country)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmAndResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Progress?'),
        content: const Text(
          'This will delete all detected landmarks, photos, points, coupons, and other collected data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Delete stored photo files if present
      final photosJson = prefs.getString(_kPhotosKey);
      if (photosJson != null) {
        try {
          final Map<String, dynamic> map = jsonDecode(photosJson);
          for (final entry in map.entries) {
            final path = entry.value?.toString();
            if (path != null && path.isNotEmpty) {
              try {
                final f = File(path);
                if (await f.exists()) {
                  await f.delete();
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Remove landmark data
      await prefs.remove(_kDiscoveredKey);
      await prefs.remove(_kPhotosKey);
      await prefs.remove(_kConfirmedKey);
      await prefs.remove(_kDescriptionsKey);
      await prefs.remove(_kCapturedAtKey);
      
      // Remove gamification data (using hardcoded key since it's private)
      await prefs.remove('user_stats');

      await _loadDiscovered();
      await _loadUserStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All progress, points, and coupons have been cleared.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset progress: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _CountryHeaderBackground extends StatelessWidget {
  final String code;
  const _CountryHeaderBackground({required this.code});

  Future<String?> _resolveAssetPath() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> map =
          jsonDecode(manifest) as Map<String, dynamic>;
      final prefix = 'assets/images/${code}_header';
      for (final key in map.keys) {
        if (key.startsWith(prefix)) return key; // matches any extension
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveAssetPath(),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black26],
            ).createShader(rect),
            blendMode: BlendMode.darken,
            child: Image.asset(path, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
