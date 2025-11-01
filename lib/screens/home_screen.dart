import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'landmark_photo_screen.dart';
import 'package:country_flags/country_flags.dart';

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

  const Country({required this.name, required this.landmarks, required this.code, this.emoji});
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

  @override
  void initState() {
    super.initState();
    _loadDiscovered();
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
      landmarks: [
        'Himeji Castle',
        'Kinkaku-ji',
        'Tokyo Tower',
        'Osaka Castle',
      ],
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
        onRefresh: _loadDiscovered,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _countries.length,
          itemBuilder: (context, index) {
            final country = _countries[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 12),
                leading: CountryFlag.fromCountryCode(
                  country.code,
                  height: 20,
                  width: 28,
                  borderRadius: 4,
                ),
                title: Text(
                  country.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${_visitedCount(country)}/${country.landmarks.length} landmarks visited'),
                children: [
                  ...country.landmarks.map(
                    (lm) {
                      final discovered = _discovered.contains(lm);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 8, right: 8),
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: discovered ? Colors.green : null,
                        ),
                        title: Text(
                          lm,
                          style: TextStyle(
                            color: discovered ? Colors.green[800] : null,
                            fontWeight: discovered ? FontWeight.w600 : null,
                          ),
                        ),
                        subtitle: discovered && _capturedAt[lm] != null
                            ? Text(
                                'Captured on ${_formatTimestamp(_capturedAt[lm]!)}',
                                style: TextStyle(color: Colors.green[700], fontSize: 12),
                              )
                            : null,
                        trailing: discovered
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        tileColor: discovered ? Colors.green.withValues(alpha: 0.08) : null,
                        onTap: () async {
                          final path = _photoPaths[lm];
                          if (discovered && path != null && path.isNotEmpty) {
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
                      );
                    },
                  ),
                ],
                ),
              ),
            );
          },
        ),
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
        title: const Text('Reset detected progress?'),
        content: const Text(
          'This will delete all visited progress and any stored photos associated with detected landmarks. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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

      await prefs.remove(_kDiscoveredKey);
      await prefs.remove(_kPhotosKey);
      await prefs.remove(_kConfirmedKey);
      await prefs.remove(_kDescriptionsKey);
  await prefs.remove(_kCapturedAtKey);

      await _loadDiscovered();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All detected progress has been cleared.'),
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
