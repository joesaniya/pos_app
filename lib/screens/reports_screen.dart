import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — warm orange/amber
// ═══════════════════════════════════════════════════════════════
class RC {
  static const bg = Color(0xFFFFFAF0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFF8ED);

  static const orange = Color(0xFFF59E0B);
  static const orangeDark = Color(0xFFD97706);
  static const orangeLight = Color(0xFFFEF3C7);
  static const amber = Color(0xFFFBBF24);

  static const blue = Color(0xFF3B82F6);
  static const blueBg = Color(0xFFDBEAFE);
  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFD1FAE5);
  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFF3E8FF);

  static const textPri = Color(0xFF1F2937);
  static const textSec = Color(0xFF6B7280);
  static const textMute = Color(0xFF9CA3AF);
  static const border = Color(0xFFFED7AA);
  static const divider = Color(0xFFFEF3C7);
}

// ═════════════════════════════════════════════════════════════════════════════
//  REPORTS SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: const _ReportsBody(),
    );
  }
}

class _ReportsBody extends StatefulWidget {
  const _ReportsBody();
  @override
  State<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends State<_ReportsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _period = 'This Week';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: RC.bg,
      body: SafeArea(
        child: Column(
          children: [
            _OrangeHeader(
              period: _period,
              onPeriodChanged: (p) => setState(() => _period = p),
            ),
            Container(
              color: RC.surface,
              child: TabBar(
                controller: _tabCtrl,
                labelColor: RC.orange,
                unselectedLabelColor: RC.textMute,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                indicatorColor: RC.orange,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Sales'),
                  Tab(text: 'Revenue'),
                  Tab(text: 'Products'),
                  Tab(text: 'Staff'),
                ],
              ),
            ),
            const Divider(height: 1, color: RC.divider),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SalesTab(),
                  _RevenueTab(),
                  _ProductsTab(),
                  _StaffTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORANGE HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _OrangeHeader extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriodChanged;
  const _OrangeHeader({required this.period, required this.onPeriodChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [RC.orange, RC.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Reports',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Insights & analytics',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.download_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    'Today',
                    'This Week',
                    'This Month',
                    'This Year',
                    'Custom',
                  ].map((p) {
                    final isSel = period == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onPeriodChanged(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel ? RC.orange : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SALES TAB
// ═════════════════════════════════════════════════════════════════════════════
class _SalesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (ctx, orders, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  emoji: '💰',
                  label: 'Total Sales',
                  value: '₹1,24,500',
                  change: '+12.5%',
                  positive: true,
                  color: RC.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  emoji: '📦',
                  label: 'Orders',
                  value: '348',
                  change: '+8.2%',
                  positive: true,
                  color: RC.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  emoji: '📊',
                  label: 'Avg Order',
                  value: '₹358',
                  change: '+3.1%',
                  positive: true,
                  color: RC.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  emoji: '⏱️',
                  label: 'Avg Time',
                  value: '18m',
                  change: '-2m',
                  positive: true,
                  color: RC.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SalesChart(),
          const SizedBox(height: 20),
          _TopSellingItems(),
          const SizedBox(height: 20),
          _SalesByCategory(),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String emoji, label, value, change;
  final bool positive;
  final Color color;
  const _MetricCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = positive ? RC.green : RC.red;
    final changeBg = positive ? RC.greenBg : RC.redBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: changeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: changeColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: RC.textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly Sales Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: RC.textPri,
                  ),
                ),
              ),
              Text(
                'Last 7 days',
                style: TextStyle(fontSize: 11, color: RC.textMute),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final heights = [0.6, 0.8, 0.5, 0.9, 0.7, 0.6, 0.85];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            height: 125 * heights[i],
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [RC.orange, RC.amber],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: RC.textMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellingItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('🍛', 'Butter Chicken', '₹12,450', '45 orders', 0.65),
      ('🥘', 'Biryani', '₹18,200', '62 orders', 0.85),
      ('🍗', 'Tandoori', '₹8,900', '28 orders', 0.45),
      ('🍲', 'Dal Makhani', '₹6,800', '34 orders', 0.35),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: RC.orangeLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(e.$1, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RC.textPri,
                              ),
                            ),
                            Text(
                              e.$4,
                              style: const TextStyle(
                                fontSize: 11,
                                color: RC.textMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        e.$3,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: RC.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.$5,
                      minHeight: 6,
                      backgroundColor: RC.orangeLight,
                      valueColor: const AlwaysStoppedAnimation(RC.orange),
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
}

class _SalesByCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cats = [
      ('Main Course', '₹52,400', 0.42, RC.orange),
      ('Appetizers', '₹28,600', 0.23, RC.blue),
      ('Beverages', '₹18,900', 0.15, RC.green),
      ('Desserts', '₹24,600', 0.20, RC.purple),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...cats.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RC.textSec,
                        ),
                      ),
                      Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: c.$4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.$3,
                      minHeight: 8,
                      backgroundColor: c.$4.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(c.$4),
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  REVENUE TAB
// ═════════════════════════════════════════════════════════════════════════════
class _RevenueTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _RevenueTile('Total Revenue', '₹1,24,500', RC.orange),
            ),
            const SizedBox(width: 12),
            Expanded(child: _RevenueTile('Net Profit', '₹48,200', RC.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _RevenueTile('Expenses', '₹76,300', RC.red)),
            const SizedBox(width: 12),
            Expanded(
              child: _RevenueTile('Tax Collected', '₹12,450', RC.purple),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _RevenueBreakdown(),
        const SizedBox(height: 20),
        _PaymentMethods(),
      ],
    );
  }
}

class _RevenueTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RevenueTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: RC.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _RevenueBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Dine-in', '₹85,200', 0.68, RC.orange),
      ('Takeaway', '₹28,400', 0.23, RC.blue),
      ('Delivery', '₹10,900', 0.09, RC.green),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue by Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RC.textSec,
                        ),
                      ),
                      Text(
                        i.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: i.$4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: i.$3,
                      minHeight: 8,
                      backgroundColor: i.$4.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(i.$4),
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
}

class _PaymentMethods extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final methods = [
      ('💳', 'Card', '₹58,200', '47%'),
      ('💵', 'Cash', '₹42,300', '34%'),
      ('📱', 'UPI', '₹20,400', '16%'),
      ('🏦', 'Other', '₹3,600', '3%'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RC.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.$2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: RC.textPri,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        m.$3,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: RC.orange,
                        ),
                      ),
                      Text(
                        m.$4,
                        style: const TextStyle(
                          fontSize: 11,
                          color: RC.textMute,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PRODUCTS TAB
// ═════════════════════════════════════════════════════════════════════════════
class _ProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (ctx, inv, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ProductMetrics(),
          const SizedBox(height: 20),
          _LowStockAlert(),
          const SizedBox(height: 20),
          _TopMovingProducts(),
        ],
      ),
    );
  }
}

class _ProductMetrics extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _RevenueTile('Total Items', '124', RC.orange)),
      const SizedBox(width: 12),
      Expanded(child: _RevenueTile('Low Stock', '8', RC.red)),
    ],
  );
}

class _LowStockAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RC.redBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: RC.red.withOpacity(0.3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: RC.red, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '8 items need restocking',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: RC.red,
            ),
          ),
        ),
        Text(
          'View →',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: RC.red,
          ),
        ),
      ],
    ),
  );
}

class _TopMovingProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prods = [
      ('🌾', 'Rice Batter', '450 kg sold'),
      ('🫘', 'Urad Dal', '280 kg sold'),
      ('🥥', 'Coconut Oil', '145 L sold'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Moving Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...prods.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RC.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(p.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RC.textPri,
                          ),
                        ),
                        Text(
                          p.$3,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RC.textMute,
                          ),
                        ),
                      ],
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAFF TAB
// ═════════════════════════════════════════════════════════════════════════════
class _StaffTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _StaffMetrics(),
        const SizedBox(height: 20),
        _TopPerformers(),
        const SizedBox(height: 20),
        _StaffByRole(),
        const SizedBox(height: 20),
        _PerformanceLeaderboard(),
        const SizedBox(height: 20),
        _ShiftAnalysis(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAFF METRICS
// ─────────────────────────────────────────────────────────────────────────────
class _StaffMetrics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StaffMetricTile(
            'Total Staff',
            '24',
            '8 active',
            const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StaffMetricTile(
            'Avg Orders',
            '12.5',
            'per staff',
            const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }
}

class _StaffMetricTile extends StatelessWidget {
  final String label, value, subtitle;
  final Color color;
  const _StaffMetricTile(this.label, this.value, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP PERFORMERS
// ─────────────────────────────────────────────────────────────────────────────
class _TopPerformers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final performers = [
      ('Chef Ravi Kumar', 'Head Chef', 148, 4.9, const Color(0xFFEC4899), '🥇'),
      (
        'Priya Sharma',
        'Senior Waitress',
        132,
        4.8,
        const Color(0xFF8B5CF6),
        '🥈',
      ),
      ('Arjun Patel', 'Sous Chef', 124, 4.7, const Color(0xFF0EA5E9), '🥉'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Top Performers This Week',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: RC.textPri,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...performers.asMap().entries.map((e) {
            final p = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [p.$5, p.$5.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.$5.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.$1.split(' ')[0][0] + p.$1.split(' ')[1][0],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            p.$6,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.$1,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: RC.textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.$2,
                          style: const TextStyle(
                            fontSize: 12,
                            color: RC.textSec,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: p.$5.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 11,
                                    color: p.$5,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${p.$3} orders',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: p.$5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              size: 13,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${p.$4}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: RC.textSec,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAFF BY ROLE
// ─────────────────────────────────────────────────────────────────────────────
class _StaffByRole extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roles = [
      ('Kitchen Staff', 8, 420, const Color(0xFFEC4899), '👨‍🍳'),
      ('Waitstaff', 10, 380, const Color(0xFF8B5CF6), '🍽️'),
      ('Management', 3, 145, const Color(0xFF0EA5E9), '📋'),
      ('Bartenders', 3, 180, const Color(0xFF10B981), '🍹'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance by Role',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 16),
          ...roles.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: r.$4.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: r.$4.withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(r.$5, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RC.textPri,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: r.$4.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${r.$2} staff',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: r.$4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: r.$3 / 500,
                            minHeight: 6,
                            backgroundColor: r.$4.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation(r.$4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${r.$3}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: r.$4,
                        ),
                      ),
                      const Text(
                        'orders',
                        style: TextStyle(fontSize: 10, color: RC.textMute),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PERFORMANCE LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────
class _PerformanceLeaderboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final staff = [
      ('Meena S', 'Waitress', 45, 98, const Color(0xFF8B5CF6)),
      ('Karthik R', 'Chef', 42, 95, const Color(0xFFEC4899)),
      ('Sujith M', 'Bartender', 38, 92, const Color(0xFF10B981)),
      ('Divya K', 'Server', 35, 89, const Color(0xFF0EA5E9)),
      ('Rajesh T', 'Cashier', 32, 85, const Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Leaderboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on orders completed & customer ratings',
            style: TextStyle(fontSize: 11, color: RC.textMute),
          ),
          const SizedBox(height: 16),
          ...staff.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i < 3 ? s.$5.withOpacity(0.15) : RC.surfaceWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: i < 3 ? s.$5 : RC.textMute,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: RC.textPri,
                          ),
                        ),
                        Text(
                          s.$2,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RC.textMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: s.$5.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s.$3} orders',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: s.$5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: s.$4 >= 90 ? RC.greenBg : RC.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${s.$4}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: s.$4 >= 90 ? RC.green : RC.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIFT ANALYSIS
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftAnalysis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shifts = [
      ('Morning Shift', '6 AM - 2 PM', 8, 145, 0.65, const Color(0xFFF59E0B)),
      (
        'Afternoon Shift',
        '2 PM - 10 PM',
        10,
        198,
        0.88,
        const Color(0xFF8B5CF6),
      ),
      ('Night Shift', '10 PM - 6 AM', 6, 85, 0.38, const Color(0xFF0EA5E9)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.blueBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule, color: RC.blue, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Shift Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: RC.textPri,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...shifts.map(
            (sh) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sh.$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RC.textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  sh.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: RC.textMute,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${sh.$3} staff',
                                  style: TextStyle(fontSize: 11, color: sh.$6),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${sh.$4}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: sh.$6,
                            ),
                          ),
                          const Text(
                            'orders',
                            style: TextStyle(fontSize: 10, color: RC.textMute),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sh.$5,
                      minHeight: 8,
                      backgroundColor: sh.$6.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(sh.$6),
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
}

/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — warm orange/amber
// ═══════════════════════════════════════════════════════════════
class RC {
  static const bg = Color(0xFFFFFAF0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFF8ED);

  static const orange = Color(0xFFF59E0B);
  static const orangeDark = Color(0xFFD97706);
  static const orangeLight = Color(0xFFFEF3C7);
  static const amber = Color(0xFFFBBF24);

  static const blue = Color(0xFF3B82F6);
  static const blueBg = Color(0xFFDBEAFE);
  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFD1FAE5);
  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFF3E8FF);

  static const textPri = Color(0xFF1F2937);
  static const textSec = Color(0xFF6B7280);
  static const textMute = Color(0xFF9CA3AF);
  static const border = Color(0xFFFED7AA);
  static const divider = Color(0xFFFEF3C7);
}

// ═════════════════════════════════════════════════════════════════════════════
//  REPORTS SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: const _ReportsBody(),
    );
  }
}

class _ReportsBody extends StatefulWidget {
  const _ReportsBody();
  @override
  State<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends State<_ReportsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _period = 'This Week';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: RC.bg,
      body: SafeArea(
        child: Column(
          children: [
            _OrangeHeader(
              period: _period,
              onPeriodChanged: (p) => setState(() => _period = p),
            ),
            Container(
              color: RC.surface,
              child: TabBar(
                controller: _tabCtrl,
                labelColor: RC.orange,
                unselectedLabelColor: RC.textMute,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                indicatorColor: RC.orange,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Sales'),
                  Tab(text: 'Revenue'),
                  Tab(text: 'Products'),
                  Tab(text: 'Staff'),
                ],
              ),
            ),
            const Divider(height: 1, color: RC.divider),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SalesTab(),
                  _RevenueTab(),
                  _ProductsTab(),
                  _StaffTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORANGE HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _OrangeHeader extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriodChanged;
  const _OrangeHeader({required this.period, required this.onPeriodChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [RC.orange, RC.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Reports',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Insights & analytics',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.download_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    'Today',
                    'This Week',
                    'This Month',
                    'This Year',
                    'Custom',
                  ].map((p) {
                    final isSel = period == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onPeriodChanged(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel ? RC.orange : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SALES TAB
// ═════════════════════════════════════════════════════════════════════════════
class _SalesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (ctx, orders, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  emoji: '💰',
                  label: 'Total Sales',
                  value: '₹1,24,500',
                  change: '+12.5%',
                  positive: true,
                  color: RC.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  emoji: '📦',
                  label: 'Orders',
                  value: '348',
                  change: '+8.2%',
                  positive: true,
                  color: RC.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  emoji: '📊',
                  label: 'Avg Order',
                  value: '₹358',
                  change: '+3.1%',
                  positive: true,
                  color: RC.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  emoji: '⏱️',
                  label: 'Avg Time',
                  value: '18m',
                  change: '-2m',
                  positive: true,
                  color: RC.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SalesChart(),
          const SizedBox(height: 20),
          _TopSellingItems(),
          const SizedBox(height: 20),
          _SalesByCategory(),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String emoji, label, value, change;
  final bool positive;
  final Color color;
  const _MetricCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = positive ? RC.green : RC.red;
    final changeBg = positive ? RC.greenBg : RC.redBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: changeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: changeColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: RC.textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly Sales Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: RC.textPri,
                  ),
                ),
              ),
              Text(
                'Last 7 days',
                style: TextStyle(fontSize: 11, color: RC.textMute),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final heights = [0.6, 0.8, 0.5, 0.9, 0.7, 0.6, 0.85];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            height: 125 * heights[i],
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [RC.orange, RC.amber],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: RC.textMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellingItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('🍛', 'Butter Chicken', '₹12,450', '45 orders', 0.65),
      ('🥘', 'Biryani', '₹18,200', '62 orders', 0.85),
      ('🍗', 'Tandoori', '₹8,900', '28 orders', 0.45),
      ('🍲', 'Dal Makhani', '₹6,800', '34 orders', 0.35),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: RC.orangeLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(e.$1, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RC.textPri,
                              ),
                            ),
                            Text(
                              e.$4,
                              style: const TextStyle(
                                fontSize: 11,
                                color: RC.textMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        e.$3,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: RC.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.$5,
                      minHeight: 6,
                      backgroundColor: RC.orangeLight,
                      valueColor: const AlwaysStoppedAnimation(RC.orange),
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
}

class _SalesByCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cats = [
      ('Main Course', '₹52,400', 0.42, RC.orange),
      ('Appetizers', '₹28,600', 0.23, RC.blue),
      ('Beverages', '₹18,900', 0.15, RC.green),
      ('Desserts', '₹24,600', 0.20, RC.purple),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...cats.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RC.textSec,
                        ),
                      ),
                      Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: c.$4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.$3,
                      minHeight: 8,
                      backgroundColor: c.$4.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(c.$4),
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  REVENUE TAB
// ═════════════════════════════════════════════════════════════════════════════
class _RevenueTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _RevenueTile('Total Revenue', '₹1,24,500', RC.orange),
            ),
            const SizedBox(width: 12),
            Expanded(child: _RevenueTile('Net Profit', '₹48,200', RC.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _RevenueTile('Expenses', '₹76,300', RC.red)),
            const SizedBox(width: 12),
            Expanded(
              child: _RevenueTile('Tax Collected', '₹12,450', RC.purple),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _RevenueBreakdown(),
        const SizedBox(height: 20),
        _PaymentMethods(),
      ],
    );
  }
}

class _RevenueTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RevenueTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: RC.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _RevenueBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Dine-in', '₹85,200', 0.68, RC.orange),
      ('Takeaway', '₹28,400', 0.23, RC.blue),
      ('Delivery', '₹10,900', 0.09, RC.green),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue by Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RC.textSec,
                        ),
                      ),
                      Text(
                        i.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: i.$4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: i.$3,
                      minHeight: 8,
                      backgroundColor: i.$4.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(i.$4),
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
}

class _PaymentMethods extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final methods = [
      ('💳', 'Card', '₹58,200', '47%'),
      ('💵', 'Cash', '₹42,300', '34%'),
      ('📱', 'UPI', '₹20,400', '16%'),
      ('🏦', 'Other', '₹3,600', '3%'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RC.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.$2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: RC.textPri,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        m.$3,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: RC.orange,
                        ),
                      ),
                      Text(
                        m.$4,
                        style: const TextStyle(
                          fontSize: 11,
                          color: RC.textMute,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PRODUCTS TAB
// ═════════════════════════════════════════════════════════════════════════════
class _ProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (ctx, inv, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ProductMetrics(),
          const SizedBox(height: 20),
          _LowStockAlert(),
          const SizedBox(height: 20),
          _TopMovingProducts(),
        ],
      ),
    );
  }
}

class _ProductMetrics extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _RevenueTile('Total Items', '124', RC.orange)),
      const SizedBox(width: 12),
      Expanded(child: _RevenueTile('Low Stock', '8', RC.red)),
    ],
  );
}

class _LowStockAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RC.redBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: RC.red.withOpacity(0.3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: RC.red, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '8 items need restocking',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: RC.red,
            ),
          ),
        ),
        Text(
          'View →',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: RC.red,
          ),
        ),
      ],
    ),
  );
}

class _TopMovingProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prods = [
      ('🌾', 'Rice Batter', '450 kg sold'),
      ('🫘', 'Urad Dal', '280 kg sold'),
      ('🥥', 'Coconut Oil', '145 L sold'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Moving Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: RC.textPri,
            ),
          ),
          const SizedBox(height: 14),
          ...prods.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RC.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(p.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RC.textPri,
                          ),
                        ),
                        Text(
                          p.$3,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RC.textMute,
                          ),
                        ),
                      ],
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAFF TAB
// ═════════════════════════════════════════════════════════════════════════════
class _StaffTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final staff = [
      ('Chef Ravi', 'Head Chef', '45 orders', RC.orange),
      ('Priya S', 'Waitress', '38 orders', RC.blue),
      ('Arjun K', 'Manager', '28 tasks', RC.green),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RC.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: RC.textPri,
                ),
              ),
              const SizedBox(height: 14),
              ...staff.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: s.$4.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s.$1.split(' ')[0][0] + s.$1.split(' ')[1][0],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: s.$4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RC.textPri,
                              ),
                            ),
                            Text(
                              s.$2,
                              style: const TextStyle(
                                fontSize: 11,
                                color: RC.textMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s.$3,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: s.$4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
*/
