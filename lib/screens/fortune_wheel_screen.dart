import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class FortuneWheelScreen extends StatefulWidget {
  const FortuneWheelScreen({super.key});

  @override
  State<FortuneWheelScreen> createState() => _FortuneWheelScreenState();
}

class _FortuneWheelScreenState extends State<FortuneWheelScreen>
    with SingleTickerProviderStateMixin {
  UserStats? _userStats;
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );
    _loadData();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stats = await GamificationService.loadUserStats();
    if (!mounted) return;
    setState(() {
      _userStats = stats;
    });
  }

  Future<void> _spin() async {
    if (_userStats == null ||
        _userStats!.fortuneWheelSpinsRemaining <= 0 ||
        _isSpinning) {
      return;
    }

    setState(() {
      _isSpinning = true;
    });

    // Deduct spin
    final updatedStats = await GamificationService.spinFortuneWheel(_userStats!);
    if (updatedStats == null || !mounted) return;

    // Pick random reward FIRST
    final randomIndex =
        math.Random().nextInt(GamificationService.wheelRewards.length);
    final reward = GamificationService.wheelRewards[randomIndex];

    // Calculate the angle needed to land the selected segment under the arrow at top
    final itemCount = GamificationService.wheelRewards.length;
    final segmentAngle = 2 * math.pi / itemCount;
    
    // Segments are drawn starting at -pi/2 (top), going clockwise
    // Segment i has its center at: -pi/2 + i * segmentAngle + segmentAngle/2
    // We need to rotate the wheel so segment[randomIndex] center ends at -pi/2 (arrow position)
    // Amount to rotate = -(randomIndex * segmentAngle + segmentAngle/2)
    final targetRotation = -(randomIndex * segmentAngle + segmentAngle / 2);
    
    // Add 5 full rotations for visual effect
    final totalRotation = (2 * math.pi * 5) + targetRotation;
    
    // Spin animation
    _spinController.reset();
    _spinAnimation = Tween<double>(begin: 0, end: totalRotation).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );
    await _spinController.forward();

    if (!mounted) return;

    // Award points based on where the wheel lands
    final pointsToAward = reward.discountPercent; // Using discountPercent field to store points
    final withPoints = await GamificationService.awardPoints(updatedStats, pointsToAward);

    setState(() {
      _isSpinning = false;
      _userStats = withPoints;
    });

    // Show reward dialog
    if (mounted) {
      _showRewardDialog(reward);
    }
  }

  void _showRewardDialog(FortuneWheelReward reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(reward.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Congratulations!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You won',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${reward.discountPercent} Points',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1F44),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Fortune Wheel',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _userStats == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Spacer(),
                // Wheel with static arrow
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Spinning wheel
                    AnimatedBuilder(
                      animation: _spinAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _spinAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildWheel(),
                    ),
                    // Static arrow pointer at top
                    Positioned(
                      top: -15,
                      child: Container(
                        width: 0,
                        height: 0,
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(width: 15, color: Colors.transparent),
                            right: BorderSide(width: 15, color: Colors.transparent),
                            bottom: BorderSide(width: 30, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Spins remaining
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Spin remaining: ${_userStats!.fortuneWheelSpinsRemaining}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.stars,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Spin button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _isSpinning ||
                                  _userStats!.fortuneWheelSpinsRemaining <= 0
                              ? null
                              : _spin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        disabledBackgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 8,
                      ),
                      child: Text(
                        _isSpinning
                            ? 'Spinning...'
                            : _userStats!.fortuneWheelSpinsRemaining <= 0
                                ? 'No Spins Left'
                                : 'Spin!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWheel() {
    const wheelSize = 280.0;
    final rewards = GamificationService.wheelRewards;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Wheel segments (no outer glow square)
        ClipOval(
          child: SizedBox(
            width: wheelSize,
            height: wheelSize,
            child: CustomPaint(
              painter: _WheelPainter(rewards: rewards),
            ),
          ),
        ),
        // Center circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade700, width: 3),
          ),
          child: const Center(
            child: Icon(Icons.star, color: Colors.amber, size: 32),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<FortuneWheelReward> rewards;

  _WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * math.pi / rewards.length;

    final colors = [
      const Color(0xFF4A90E2),
      const Color(0xFF5856D6),
      const Color(0xFFAF52DE),
      const Color(0xFFFF2D55),
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
    ];

    for (int i = 0; i < rewards.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      final startAngle = -math.pi / 2 + i * segmentAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw segment border
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Draw text
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.7;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: rewards[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
      );
    }

    // Outer border
    final outerBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, outerBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
