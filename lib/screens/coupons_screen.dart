import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  List<TripCoupon> _coupons = [];
  UserStats? _userStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    final stats = await GamificationService.loadUserStats();
    final coupons = await GamificationService.getCoupons(stats);
    setState(() {
      _userStats = stats;
      _coupons = coupons;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trip.com Coupons'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_userStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPurchaseSection(),
          const SizedBox(height: 24),
          if (_coupons.isNotEmpty) ...[
            Text(
              'My Coupons',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._coupons.map((coupon) => _buildCouponCard(coupon)),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No coupons yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchaseSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Purchase Coupons',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your Points: ${_userStats!.points}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPurchaseCouponButton('5%', 50),
                _buildPurchaseCouponButton('10%', 100),
                _buildPurchaseCouponButton('15%', 200),
                _buildPurchaseCouponButton('20%', 400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCouponButton(String discount, int cost) {
    final canAfford = _userStats!.points >= cost;
    return OutlinedButton(
      onPressed: canAfford ? () => _purchaseCoupon(discount, cost) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: canAfford ? Colors.orange[700] : Colors.grey,
        side: BorderSide(
          color: canAfford ? Colors.orange : Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            discount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$cost pts',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseCoupon(String discount, int cost) async {
    if (_userStats == null || _userStats!.points < cost) return;

    final discountInt = int.parse(discount.replaceAll('%', ''));
    
    // Create a reward with the actual discount percentage
    final reward = FortuneWheelReward(
      label: discount,
      discountPercent: discountInt,
      icon: '🎟️',
      description: '$discount off',
      couponCode: 'TRIP$discountInt',
    );

    // Deduct points
    final updatedStats = await GamificationService.awardPoints(
      _userStats!,
      -cost,
    );

    // Collect coupon
    await GamificationService.collectCoupon(updatedStats, reward);

    await _loadCoupons();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Purchased $discount coupon for $cost points!'),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeader() {
    final activeCoupons = _coupons.where((c) => !c.isUsed && !_isExpired(c)).length;
    final totalSavings = _coupons
        .where((c) => !c.isUsed)
        .fold<int>(0, (sum, c) => sum + c.discountPercent);

    return Card(
      elevation: 4,
      color: Colors.blue[700],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.card_giftcard,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              '$activeCoupons Active Coupons',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Up to $totalSavings% total savings available',
              style: TextStyle(
                color: Colors.blue[100],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(TripCoupon coupon) {
    final bool isExpired = _isExpired(coupon);
    final bool isActive = !coupon.isUsed && !isExpired;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      child: InkWell(
        onTap: isActive ? () => _showCouponDetails(coupon) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Discount Badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [Colors.orange[600]!, Colors.orange[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [Colors.grey[400]!, Colors.grey[300]!],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${coupon.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Coupon Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trip.com Discount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        _buildStatusBadge(coupon, isExpired),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${coupon.code}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isActive ? Colors.blue[700] : Colors.grey,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: isActive ? Colors.grey[600] : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expires: ${_formatDate(coupon.expiresAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? Colors.grey[600] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TripCoupon coupon, bool isExpired) {
    if (coupon.isUsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'USED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'EXPIRED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'ACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  bool _isExpired(TripCoupon coupon) {
    return DateTime.now().isAfter(coupon.expiresAt);
  }

  void _showCouponDetails(TripCoupon coupon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCouponDetailsSheet(coupon),
    );
  }

  Widget _buildCouponDetailsSheet(TripCoupon coupon) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[600]!, Colors.orange[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${coupon.discountPercent}% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trip.com Discount Coupon',
                  style: TextStyle(
                    color: Colors.orange[100],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildDetailRow(Icons.confirmation_number, 'Coupon Code', coupon.code),
          _buildDetailRow(Icons.access_time, 'Earned On', 
              _formatDate(coupon.earnedAt)),
          _buildDetailRow(Icons.event_available, 'Valid Until', 
              _formatDate(coupon.expiresAt)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _copyCouponCode(coupon.code),
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openTripDotCom(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Redeem on Trip.com'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visit Trip.com, select your booking, and apply this code at checkout',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Coupon code "$code" copied!'),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openTripDotCom() {
    // In a real app, this would open the browser or Trip.com app
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Trip.com...'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }
}
