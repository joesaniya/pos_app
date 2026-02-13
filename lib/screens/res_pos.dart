import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:intl/intl.dart';

class EnhancedRevenueAnalytics extends StatefulWidget {
  final DateTime? selectedDate;

  const EnhancedRevenueAnalytics({Key? key, this.selectedDate})
    : super(key: key);

  @override
  State<EnhancedRevenueAnalytics> createState() =>
      _EnhancedRevenueAnalyticsState();
}

class _EnhancedRevenueAnalyticsState extends State<EnhancedRevenueAnalytics>
    with SingleTickerProviderStateMixin {
  String selectedPeriod = 'Weekly';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _changePeriod(String period) {
    setState(() {
      selectedPeriod = period;
    });
    _animationController.reset();
    _animationController.forward();
  }

  List<FlSpot> _getChartData() {
    final random = math.Random(DateTime.now().millisecondsSinceEpoch);

    switch (selectedPeriod) {
      case 'Weekly':
        return List.generate(
          7,
          (i) => FlSpot(i.toDouble(), 3 + random.nextDouble() * 3),
        );
      case 'Monthly':
        return List.generate(
          30,
          (i) => FlSpot(i.toDouble(), 2.5 + random.nextDouble() * 4),
        );
      case 'Yearly':
        return List.generate(
          12,
          (i) => FlSpot(i.toDouble(), 4 + random.nextDouble() * 3.5),
        );
      default:
        return [];
    }
  }

  String _getXAxisLabel(int index) {
    switch (selectedPeriod) {
      case 'Weekly':
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return index < days.length ? days[index] : '';
      case 'Monthly':
        return index % 5 == 0 ? '${index + 1}' : '';
      case 'Yearly':
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return index < months.length ? months[index] : '';
      default:
        return '';
    }
  }

  double _getMaxX() {
    switch (selectedPeriod) {
      case 'Weekly':
        return 6;
      case 'Monthly':
        return 29;
      case 'Yearly':
        return 11;
      default:
        return 6;
    }
  }

  Map<String, dynamic> _getStatistics() {
    final random = math.Random(DateTime.now().millisecondsSinceEpoch);

    switch (selectedPeriod) {
      case 'Weekly':
        return {
          'total': 28450.00 + random.nextDouble() * 5000,
          'average': 4064.00 + random.nextDouble() * 700,
          'highest': 5280.00 + random.nextDouble() * 1000,
          'growth': 12.5 + random.nextDouble() * 10,
        };
      case 'Monthly':
        return {
          'total': 125400.00 + random.nextDouble() * 20000,
          'average': 4180.00 + random.nextDouble() * 800,
          'highest': 6500.00 + random.nextDouble() * 1500,
          'growth': 18.3 + random.nextDouble() * 12,
        };
      case 'Yearly':
        return {
          'total': 1450000.00 + random.nextDouble() * 100000,
          'average': 120833.00 + random.nextDouble() * 10000,
          'highest': 145000.00 + random.nextDouble() * 15000,
          'growth': 24.7 + random.nextDouble() * 15,
        };
      default:
        return {'total': 0.0, 'average': 0.0, 'highest': 0.0, 'growth': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    final stats = _getStatistics();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.width * 0.02,
          ),
          padding: EdgeInsets.all(size.width * (isDesktop ? 0.025 : 0.05)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8F9FF)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4CE6).withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(size, isTablet, isDesktop),
              SizedBox(height: size.width * 0.04),
              _buildPeriodSelector(size, isTablet),
              SizedBox(height: size.width * 0.05),
              _buildStatisticsCards(size, isTablet, isDesktop, stats),
              SizedBox(height: size.width * 0.05),
              _buildChart(size, isTablet, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size, bool isTablet, bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue Analytics',
                style: TextStyle(
                  fontSize:
                      size.width *
                      (isDesktop
                          ? 0.02
                          : isTablet
                          ? 0.025
                          : 0.05),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              SizedBox(height: size.width * 0.01),
              Text(
                'Track your performance over time',
                style: TextStyle(
                  fontSize:
                      size.width *
                      (isDesktop
                          ? 0.012
                          : isTablet
                          ? 0.018
                          : 0.03),
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(size.width * 0.02),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4CE6).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.show_chart,
            color: Colors.white,
            size:
                size.width *
                (isDesktop
                    ? 0.02
                    : isTablet
                    ? 0.03
                    : 0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(Size size, bool isTablet) {
    final periods = ['Weekly', 'Monthly', 'Yearly'];

    return Container(
      padding: EdgeInsets.all(size.width * 0.01),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changePeriod(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(vertical: size.width * 0.03),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6B4CE6).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: size.width * (isTablet ? 0.02 : 0.035),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatisticsCards(
    Size size,
    bool isTablet,
    bool isDesktop,
    Map<String, dynamic> stats,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isDesktop
            ? 4
            : isTablet
            ? 2
            : 2;
        final spacing = size.width * 0.03;
        final cardWidth =
            (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Total Revenue',
                '\$${NumberFormat('#,##0.00').format(stats['total'])}',
                Icons.attach_money,
                const Color(0xFF6B4CE6),
                size,
                isTablet,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Average',
                '\$${NumberFormat('#,##0.00').format(stats['average'])}',
                Icons.analytics,
                const Color(0xFF48BB78),
                size,
                isTablet,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Highest',
                '\$${NumberFormat('#,##0.00').format(stats['highest'])}',
                Icons.trending_up,
                const Color(0xFFF6AD55),
                size,
                isTablet,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Growth',
                '+${stats['growth'].toStringAsFixed(1)}%',
                Icons.arrow_upward,
                const Color(0xFF4299E1),
                size,
                isTablet,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Size size,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(size.width * (isTablet ? 0.025 : 0.04)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(size.width * 0.02),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: size.width * (isTablet ? 0.03 : 0.05),
            ),
          ),
          SizedBox(height: size.width * 0.02),
          Text(
            title,
            style: TextStyle(
              fontSize: size.width * (isTablet ? 0.015 : 0.03),
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: size.width * 0.01),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: size.width * (isTablet ? 0.025 : 0.045),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Size size, bool isTablet, bool isDesktop) {
    final chartHeight =
        size.width *
        (isDesktop
            ? 0.25
            : isTablet
            ? 0.4
            : 0.6);

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6B4CE6).withOpacity(0.05),
            const Color(0xFF9C27B0).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6B4CE6).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedPeriod Trend',
                style: TextStyle(
                  fontSize: size.width * (isTablet ? 0.02 : 0.04),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.03,
                  vertical: size.width * 0.015,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF48BB78).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: const Color(0xFF48BB78),
                      size: size.width * (isTablet ? 0.02 : 0.035),
                    ),
                    SizedBox(width: size.width * 0.01),
                    Text(
                      'Trending Up',
                      style: TextStyle(
                        color: const Color(0xFF48BB78),
                        fontWeight: FontWeight.bold,
                        fontSize: size.width * (isTablet ? 0.015 : 0.025),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: size.width * 0.04),
          SizedBox(
            height: chartHeight,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: selectedPeriod != 'Monthly',
                  horizontalInterval: 1,
                  verticalInterval: selectedPeriod == 'Yearly' ? 2 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: size.width * (isTablet ? 0.06 : 0.12),
                      interval: 1,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: EdgeInsets.only(right: size.width * 0.02),
                        child: Text(
                          '\$${(value * 1000).toInt()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: size.width * (isTablet ? 0.015 : 0.025),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: size.width * 0.08,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final label = _getXAxisLabel(value.toInt());
                        return label.isNotEmpty
                            ? Padding(
                                padding: EdgeInsets.only(
                                  top: size.width * 0.02,
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize:
                                        size.width * (isTablet ? 0.015 : 0.025),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: _getMaxX(),
                minY: 0,
                maxY: 8,
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartData(),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: const Color(0xFF6B4CE6),
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6B4CE6).withOpacity(0.3),
                          const Color(0xFF9C27B0).withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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

// ============================================================================
// MAIN SCREEN
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime? selectedDate;

  void _handleDateSelected(DateTime? date) {
    setState(() {
      selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            key: ValueKey(selectedDate),
            selectedDate: selectedDate,
            onDateSelected: _handleDateSelected,
          ),
          const OrdersScreen(),
          const TablesScreen(),
          const MenuScreen(),
          const InventoryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.receipt_long, 'Orders'),
                _buildNavItem(2, Icons.table_restaurant, 'Tables'),
                _buildNavItem(3, Icons.restaurant_menu, 'Menu'),
                _buildNavItem(4, Icons.inventory_2, 'Inventory'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF6B4CE6) : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DASHBOARD SCREEN
// ============================================================================

class DashboardScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateSelected;

  const DashboardScreen({
    Key? key,
    this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String selectedPeriod = 'Today';
  late AnimationController _animationController;

  final Map<String, double> revenueData = {
    'Today': 4250.00,
    'Yesterday': 3890.00,
    'Last Month': 125400.00,
    'Last Year': 1450000.00,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _getRevenueForPeriod() {
    if (widget.selectedDate != null) {
      final random = math.Random(widget.selectedDate!.millisecondsSinceEpoch);
      return 2000 + random.nextDouble() * 3000;
    }
    return revenueData[selectedPeriod] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final revenue = _getRevenueForPeriod();
    final previousRevenue =
        selectedPeriod == 'Today' && widget.selectedDate == null
        ? revenueData['Yesterday']!
        : revenue * 0.85;
    final change = ((revenue - previousRevenue) / previousRevenue * 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(size.width * 0.05),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resto POS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.selectedDate != null
                                    ? 'Data for ${DateFormat('MMM dd, yyyy').format(widget.selectedDate!)}'
                                    : 'Dashboard Overview',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children:
                            [
                                'Today',
                                'Yesterday',
                                'Last Month',
                                'Last Year',
                              ].map((p) => _buildPeriodChip(p)).toList()
                              ..add(_buildCalendarButton()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(size.width * 0.04),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Revenue',
                            '\$${revenue.toStringAsFixed(0)}',
                            change,
                            Icons.attach_money,
                            const Color(0xFF6B4CE6),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Orders',
                            selectedPeriod == 'Today' &&
                                    widget.selectedDate == null
                                ? '48'
                                : '1,245',
                            12.5,
                            Icons.receipt,
                            const Color(0xFF48BB78),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Avg Order',
                            '\$${(revenue / (selectedPeriod == 'Today' && widget.selectedDate == null ? 48 : 1245)).toStringAsFixed(0)}',
                            -2.3,
                            Icons.trending_up,
                            const Color(0xFFF6AD55),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Active Tables',
                            '4',
                            0.0,
                            Icons.table_restaurant,
                            const Color(0xFF4299E1),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ✅ NEW ENHANCED REVENUE ANALYTICS WIDGET
            SliverToBoxAdapter(
              child: EnhancedRevenueAnalytics(
                selectedDate: widget.selectedDate,
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.all(size.width * 0.04),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'New Order',
                                Icons.add_shopping_cart,
                                const Color(0xFF48BB78),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'View Tables',
                                Icons.table_restaurant,
                                const Color(0xFF4299E1),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'Reports',
                                Icons.bar_chart,
                                const Color(0xFFF6AD55),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'Settings',
                                Icons.settings,
                                const Color(0xFF9C27B0),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String period) {
    final isSelected = selectedPeriod == period && widget.selectedDate == null;
    return GestureDetector(
      onTap: () {
        setState(() => selectedPeriod = period);
        widget.onDateSelected(null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarButton() {
    final hasDate = widget.selectedDate != null;
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: widget.selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6B4CE6),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF2D3748),
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          setState(() => selectedPeriod = 'Custom');
          widget.onDateSelected(date);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasDate ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: hasDate
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          Icons.calendar_today,
          color: hasDate ? const Color(0xFF6B4CE6) : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    double change,
    IconData icon,
    Color color,
  ) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                if (change != 0.0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: change > 0
                          ? const Color(0xFF48BB78).withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: change > 0
                              ? const Color(0xFF48BB78)
                              : Colors.red,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${change.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: change > 0
                                ? const Color(0xFF48BB78)
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORDERS SCREEN
// ============================================================================

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedFilter = 'All';

  final orders = [
    {
      'id': '#ORD-1234',
      'table': 'T1',
      'items': 3,
      'amount': 145.50,
      'status': 'preparing',
      'time': '10 min',
    },
    {
      'id': '#ORD-1235',
      'table': 'T3',
      'items': 2,
      'amount': 89.00,
      'status': 'served',
      'time': '25 min',
    },
    {
      'id': '#ORD-1236',
      'table': 'T5',
      'items': 5,
      'amount': 234.75,
      'status': 'preparing',
      'time': '5 min',
    },
    {
      'id': '#ORD-1237',
      'table': 'T7',
      'items': 1,
      'amount': 45.00,
      'status': 'pending',
      'time': '2 min',
    },
    {
      'id': '#ORD-1238',
      'table': 'T2',
      'items': 4,
      'amount': 178.00,
      'status': 'served',
      'time': '35 min',
    },
    {
      'id': '#ORD-1239',
      'table': 'T4',
      'items': 2,
      'amount': 92.50,
      'status': 'pending',
      'time': '1 min',
    },
  ];

  List<Map<String, dynamic>> get filteredOrders => selectedFilter == 'All'
      ? orders
      : orders
            .where(
              (o) =>
                  o['status'].toString().toLowerCase() ==
                  selectedFilter.toLowerCase(),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        'All',
                        'Pending',
                        'Preparing',
                        'Served',
                      ].map(_buildFilterChip).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No orders found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(size.width * 0.04),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(filteredOrders[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'preparing':
          return const Color(0xFFF6AD55);
        case 'served':
          return const Color(0xFF48BB78);
        default:
          return const Color(0xFF4299E1);
      }
    }

    final color = getStatusColor(order['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['id'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order['table']} • ${order['items']} items',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
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
                    '\$${order['amount'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order['time'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  order['status'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              _buildActionButton(Icons.visibility, const Color(0xFF4299E1)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.check, const Color(0xFF48BB78)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Icon(icon, color: color, size: 18),
  );
}

// ============================================================================
// TABLES SCREEN
// ============================================================================

class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tables = [
      {
        'id': 'T1',
        'status': 'active',
        'orders': 3,
        'amount': 145.50,
        'time': '25 min',
      },
      {
        'id': 'T2',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T3',
        'status': 'active',
        'orders': 2,
        'amount': 89.00,
        'time': '15 min',
      },
      {
        'id': 'T4',
        'status': 'reserved',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T5',
        'status': 'active',
        'orders': 5,
        'amount': 234.75,
        'time': '42 min',
      },
      {
        'id': 'T6',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T7',
        'status': 'active',
        'orders': 1,
        'amount': 45.00,
        'time': '8 min',
      },
      {
        'id': 'T8',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tables',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusIndicator(
                        'Active',
                        const Color(0xFF48BB78),
                        4,
                      ),
                      const SizedBox(width: 16),
                      _buildStatusIndicator(
                        'Reserved',
                        const Color(0xFFF6AD55),
                        1,
                      ),
                      const SizedBox(width: 16),
                      _buildStatusIndicator('Vacant', Colors.white, 3),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final size = MediaQuery.of(context).size;
                  final width = size.width;

                  int crossAxisCount = 2;
                  double aspectRatio = 1.0;

                  if (width > 1200) {
                    crossAxisCount = 5;
                    aspectRatio = 1.25;
                  } else if (width > 900) {
                    crossAxisCount = 4;
                    aspectRatio = 1.2;
                  } else if (width > 600) {
                    crossAxisCount = 3;
                    aspectRatio = 1.1;
                  } else {
                    crossAxisCount = 2;
                    aspectRatio = 1.0;
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(width * 0.04),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: width * 0.03,
                      mainAxisSpacing: width * 0.03,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) =>
                        _buildTableCard(context, tables[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color, int count) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label ($count)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _buildTableCard(BuildContext context, Map<String, dynamic> table) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    Color getStatusColor(String status) {
      switch (status) {
        case 'active':
          return const Color(0xFF48BB78);
        case 'reserved':
          return const Color(0xFFF6AD55);
        default:
          return Colors.grey;
      }
    }

    final color = getStatusColor(table['status']);

    return Container(
      padding: EdgeInsets.all(width * 0.025),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.all(width * 0.03),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                color: color,
                size: width * 0.07,
              ),
            ),
          ),
          SizedBox(height: width * 0.02),
          Flexible(
            child: Text(
              table['id'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: Text(
              table['status'].toString().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.028,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (table['status'] == 'active') ...[
            SizedBox(height: width * 0.015),
            Flexible(
              child: Text(
                '\$${table['amount'].toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: Text(
                table['time'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width * 0.025,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// MENU SCREEN
// ============================================================================

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String selectedCategory = 'All';

  final menuItems = [
    {
      'name': 'Grilled Salmon',
      'price': 24.99,
      'category': 'Main Course',
      'available': true,
    },
    {
      'name': 'Caesar Salad',
      'price': 12.50,
      'category': 'Appetizers',
      'available': true,
    },
    {
      'name': 'Chocolate Cake',
      'price': 8.99,
      'category': 'Desserts',
      'available': true,
    },
    {
      'name': 'Iced Coffee',
      'price': 4.50,
      'category': 'Beverages',
      'available': true,
    },
    {
      'name': 'Beef Steak',
      'price': 32.00,
      'category': 'Main Course',
      'available': false,
    },
    {
      'name': 'Chicken Wings',
      'price': 15.99,
      'category': 'Appetizers',
      'available': true,
    },
    {
      'name': 'Tiramisu',
      'price': 7.50,
      'category': 'Desserts',
      'available': true,
    },
  ];

  List<Map<String, dynamic>> get filteredItems => selectedCategory == 'All'
      ? menuItems
      : menuItems
            .where((item) => item['category'] == selectedCategory)
            .toList();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        'All',
                        'Appetizers',
                        'Main Course',
                        'Desserts',
                        'Beverages',
                      ].map(_buildCategoryChip).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(size.width * 0.04),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) =>
                    _buildMenuItem(filteredItems[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['category'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\$${item['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF6B4CE6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['available']
                            ? const Color(0xFF48BB78).withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['available'] ? 'Available' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item['available']
                              ? const Color(0xFF48BB78)
                              : Colors.red,
                        ),
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
  }
}

// ============================================================================
// INVENTORY SCREEN
// ============================================================================

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final inventoryItems = [
      {
        'name': 'Fresh Salmon',
        'quantity': 25,
        'unit': 'kg',
        'status': 'good',
        'lastUpdated': '2 hours ago',
      },
      {
        'name': 'Tomatoes',
        'quantity': 8,
        'unit': 'kg',
        'status': 'low',
        'lastUpdated': '5 hours ago',
      },
      {
        'name': 'Pasta',
        'quantity': 150,
        'unit': 'packs',
        'status': 'good',
        'lastUpdated': '1 day ago',
      },
      {
        'name': 'Olive Oil',
        'quantity': 3,
        'unit': 'liters',
        'status': 'critical',
        'lastUpdated': '3 hours ago',
      },
      {
        'name': 'Chicken',
        'quantity': 40,
        'unit': 'kg',
        'status': 'good',
        'lastUpdated': '4 hours ago',
      },
      {
        'name': 'Lettuce',
        'quantity': 12,
        'unit': 'kg',
        'status': 'low',
        'lastUpdated': '6 hours ago',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inventory',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Total Items',
                          '6',
                          Icons.inventory_2,
                          const Color(0xFF4299E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Low Stock',
                          '2',
                          Icons.warning,
                          const Color(0xFFF6AD55),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Critical',
                          '1',
                          Icons.error,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(size.width * 0.04),
                physics: const BouncingScrollPhysics(),
                itemCount: inventoryItems.length,
                itemBuilder: (context, index) =>
                    _buildInventoryCard(inventoryItems[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'good':
          return const Color(0xFF48BB78);
        case 'low':
          return const Color(0xFFF6AD55);
        default:
          return Colors.red;
      }
    }

    final color = getStatusColor(item['status']);
    final statusText = item['status'] == 'good'
        ? 'Good Stock'
        : item['status'] == 'low'
        ? 'Low Stock'
        : 'Critical';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.inventory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      item['lastUpdated'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                '${item['quantity']} ${item['unit']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/*class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime? selectedDate;

  void _handleDateSelected(DateTime? date) {
    setState(() {
      selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            key: ValueKey(selectedDate),
            selectedDate: selectedDate,
            onDateSelected: _handleDateSelected,
          ),
          const OrdersScreen(),
          const TablesScreen(),
          const MenuScreen(),
          const InventoryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.receipt_long, 'Orders'),
                _buildNavItem(2, Icons.table_restaurant, 'Tables'),
                _buildNavItem(3, Icons.restaurant_menu, 'Menu'),
                _buildNavItem(4, Icons.inventory_2, 'Inventory'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF6B4CE6) : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// DASHBOARD SCREEN - Includes working calendar and dynamic data
class DashboardScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateSelected;

  const DashboardScreen({
    Key? key,
    this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String selectedPeriod = 'Today';
  late AnimationController _animationController;

  final Map<String, double> revenueData = {
    'Today': 4250.00,
    'Yesterday': 3890.00,
    'Last Month': 125400.00,
    'Last Year': 1450000.00,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _getRevenueForPeriod() {
    if (widget.selectedDate != null) {
      final random = math.Random(widget.selectedDate!.millisecondsSinceEpoch);
      return 2000 + random.nextDouble() * 3000;
    }
    return revenueData[selectedPeriod] ?? 0.0;
  }

  List<FlSpot> _getChartDataForPeriod() {
    if (widget.selectedDate != null) {
      final random = math.Random(widget.selectedDate!.millisecondsSinceEpoch);
      return List.generate(
        7,
        (i) => FlSpot(i.toDouble(), 2 + random.nextDouble() * 4),
      );
    }

    Map<String, List<FlSpot>> chartData = {
      'Today': const [
        FlSpot(0, 3),
        FlSpot(1, 4),
        FlSpot(2, 3.5),
        FlSpot(3, 5),
        FlSpot(4, 4),
        FlSpot(5, 4.5),
        FlSpot(6, 5.5),
      ],
      'Yesterday': const [
        FlSpot(0, 2.8),
        FlSpot(1, 3.5),
        FlSpot(2, 3.2),
        FlSpot(3, 4.5),
        FlSpot(4, 3.8),
        FlSpot(5, 4.2),
        FlSpot(6, 5),
      ],
      'Last Month': const [
        FlSpot(0, 4),
        FlSpot(1, 4.5),
        FlSpot(2, 4.2),
        FlSpot(3, 5.5),
        FlSpot(4, 5),
        FlSpot(5, 5.2),
        FlSpot(6, 6),
      ],
    };

    return chartData[selectedPeriod] ??
        const [
          FlSpot(0, 3.5),
          FlSpot(1, 4.2),
          FlSpot(2, 4),
          FlSpot(3, 5.2),
          FlSpot(4, 4.8),
          FlSpot(5, 5),
          FlSpot(6, 5.8),
        ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final revenue = _getRevenueForPeriod();
    final previousRevenue =
        selectedPeriod == 'Today' && widget.selectedDate == null
        ? revenueData['Yesterday']!
        : revenue * 0.85;
    final change = ((revenue - previousRevenue) / previousRevenue * 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(size.width * 0.05),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resto POS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.selectedDate != null
                                    ? 'Data for ${DateFormat('MMM dd, yyyy').format(widget.selectedDate!)}'
                                    : 'Dashboard Overview',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children:
                            [
                                'Today',
                                'Yesterday',
                                'Last Month',
                                'Last Year',
                              ].map((p) => _buildPeriodChip(p)).toList()
                              ..add(_buildCalendarButton()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(size.width * 0.04),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Revenue',
                            '\$${revenue.toStringAsFixed(0)}',
                            change,
                            Icons.attach_money,
                            const Color(0xFF6B4CE6),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Orders',
                            selectedPeriod == 'Today' &&
                                    widget.selectedDate == null
                                ? '48'
                                : '1,245',
                            12.5,
                            Icons.receipt,
                            const Color(0xFF48BB78),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Avg Order',
                            '\$${(revenue / (selectedPeriod == 'Today' && widget.selectedDate == null ? 48 : 1245)).toStringAsFixed(0)}',
                            -2.3,
                            Icons.trending_up,
                            const Color(0xFFF6AD55),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            'Active Tables',
                            '4',
                            0.0,
                            Icons.table_restaurant,
                            const Color(0xFF4299E1),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _animationController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B4CE6).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Revenue Analytics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6B4CE6),
                                    Color(0xFF9C27B0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Weekly',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (v) => FlLine(
                                  color: Colors.grey.withOpacity(0.1),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (v, m) => Text(
                                      '\$${(v * 1000).toInt()}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) {
                                      const days = [
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat',
                                        'Sun',
                                      ];
                                      return v.toInt() < days.length
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                days[v.toInt()],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 10,
                                                ),
                                              ),
                                            )
                                          : const SizedBox();
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: 6,
                              minY: 0,
                              maxY: 6,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _getChartDataForPeriod(),
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6B4CE6),
                                      Color(0xFF9C27B0),
                                    ],
                                  ),
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (s, p, b, i) =>
                                        FlDotCirclePainter(
                                          radius: 5,
                                          color: Colors.white,
                                          strokeWidth: 3,
                                          strokeColor: const Color(0xFF6B4CE6),
                                        ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF6B4CE6,
                                        ).withOpacity(0.3),
                                        const Color(
                                          0xFF9C27B0,
                                        ).withOpacity(0.05),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(size.width * 0.04),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'New Order',
                                Icons.add_shopping_cart,
                                const Color(0xFF48BB78),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'View Tables',
                                Icons.table_restaurant,
                                const Color(0xFF4299E1),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'Reports',
                                Icons.bar_chart,
                                const Color(0xFFF6AD55),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildActionCard(
                                'Settings',
                                Icons.settings,
                                const Color(0xFF9C27B0),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String period) {
    final isSelected = selectedPeriod == period && widget.selectedDate == null;
    return GestureDetector(
      onTap: () {
        setState(() => selectedPeriod = period);
        widget.onDateSelected(null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarButton() {
    final hasDate = widget.selectedDate != null;
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: widget.selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6B4CE6),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF2D3748),
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          setState(() => selectedPeriod = 'Custom');
          widget.onDateSelected(date);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasDate ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: hasDate
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          Icons.calendar_today,
          color: hasDate ? const Color(0xFF6B4CE6) : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    double change,
    IconData icon,
    Color color,
  ) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                if (change != 0.0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: change > 0
                          ? const Color(0xFF48BB78).withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: change > 0
                              ? const Color(0xFF48BB78)
                              : Colors.red,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${change.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: change > 0
                                ? const Color(0xFF48BB78)
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ORDERS SCREEN - Responsive with filtering
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedFilter = 'All';

  final orders = [
    {
      'id': '#ORD-1234',
      'table': 'T1',
      'items': 3,
      'amount': 145.50,
      'status': 'preparing',
      'time': '10 min',
    },
    {
      'id': '#ORD-1235',
      'table': 'T3',
      'items': 2,
      'amount': 89.00,
      'status': 'served',
      'time': '25 min',
    },
    {
      'id': '#ORD-1236',
      'table': 'T5',
      'items': 5,
      'amount': 234.75,
      'status': 'preparing',
      'time': '5 min',
    },
    {
      'id': '#ORD-1237',
      'table': 'T7',
      'items': 1,
      'amount': 45.00,
      'status': 'pending',
      'time': '2 min',
    },
    {
      'id': '#ORD-1238',
      'table': 'T2',
      'items': 4,
      'amount': 178.00,
      'status': 'served',
      'time': '35 min',
    },
    {
      'id': '#ORD-1239',
      'table': 'T4',
      'items': 2,
      'amount': 92.50,
      'status': 'pending',
      'time': '1 min',
    },
  ];

  List<Map<String, dynamic>> get filteredOrders => selectedFilter == 'All'
      ? orders
      : orders
            .where(
              (o) =>
                  o['status'].toString().toLowerCase() ==
                  selectedFilter.toLowerCase(),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        'All',
                        'Pending',
                        'Preparing',
                        'Served',
                      ].map(_buildFilterChip).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No orders found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(size.width * 0.04),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(filteredOrders[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'preparing':
          return const Color(0xFFF6AD55);
        case 'served':
          return const Color(0xFF48BB78);
        default:
          return const Color(0xFF4299E1);
      }
    }

    final color = getStatusColor(order['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['id'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order['table']} • ${order['items']} items',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
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
                    '\$${order['amount'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order['time'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  order['status'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              _buildActionButton(Icons.visibility, const Color(0xFF4299E1)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.check, const Color(0xFF48BB78)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Icon(icon, color: color, size: 18),
  );
}

// TABLES SCREEN - Responsive grid
class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tables = [
      {
        'id': 'T1',
        'status': 'active',
        'orders': 3,
        'amount': 145.50,
        'time': '25 min',
      },
      {
        'id': 'T2',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T3',
        'status': 'active',
        'orders': 2,
        'amount': 89.00,
        'time': '15 min',
      },
      {
        'id': 'T4',
        'status': 'reserved',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T5',
        'status': 'active',
        'orders': 5,
        'amount': 234.75,
        'time': '42 min',
      },
      {
        'id': 'T6',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
      {
        'id': 'T7',
        'status': 'active',
        'orders': 1,
        'amount': 45.00,
        'time': '8 min',
      },
      {
        'id': 'T8',
        'status': 'vacant',
        'orders': 0,
        'amount': 0.0,
        'time': '0 min',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tables',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusIndicator(
                        'Active',
                        const Color(0xFF48BB78),
                        4,
                      ),
                      const SizedBox(width: 16),
                      _buildStatusIndicator(
                        'Reserved',
                        const Color(0xFFF6AD55),
                        1,
                      ),
                      const SizedBox(width: 16),
                      _buildStatusIndicator('Vacant', Colors.white, 3),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final size = MediaQuery.of(context).size;
                  final width = size.width;

                  int crossAxisCount = 2;
                  double aspectRatio = 1.0;

                  if (width > 1200) {
                    crossAxisCount = 5;
                    aspectRatio = 1.25;
                  } else if (width > 900) {
                    crossAxisCount = 4;
                    aspectRatio = 1.2;
                  } else if (width > 600) {
                    crossAxisCount = 3;
                    aspectRatio = 1.1;
                  } else {
                    crossAxisCount = 2;
                    aspectRatio = 1.0;
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(width * 0.04),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: width * 0.03,
                      mainAxisSpacing: width * 0.03,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) =>
                        _buildTableCard(context, tables[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color, int count) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label ($count)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _buildTableCard(BuildContext context, Map<String, dynamic> table) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    Color getStatusColor(String status) {
      switch (status) {
        case 'active':
          return const Color(0xFF48BB78);
        case 'reserved':
          return const Color(0xFFF6AD55);
        default:
          return Colors.grey;
      }
    }

    final color = getStatusColor(table['status']);

    return Container(
      padding: EdgeInsets.all(width * 0.025),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Icon
          Flexible(
            child: Container(
              padding: EdgeInsets.all(width * 0.03),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                color: color,
                size: width * 0.07,
              ),
            ),
          ),

          SizedBox(height: width * 0.02),

          /// Table ID
          Flexible(
            child: Text(
              table['id'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          /// Status
          Flexible(
            child: Text(
              table['status'].toString().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.028,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),

          /// Active details
          if (table['status'] == 'active') ...[
            SizedBox(height: width * 0.015),

            Flexible(
              child: Text(
                '\$${table['amount'].toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Flexible(
              child: Text(
                table['time'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width * 0.025,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// MENU SCREEN - Responsive list
class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String selectedCategory = 'All';

  final menuItems = [
    {
      'name': 'Grilled Salmon',
      'price': 24.99,
      'category': 'Main Course',
      'available': true,
    },
    {
      'name': 'Caesar Salad',
      'price': 12.50,
      'category': 'Appetizers',
      'available': true,
    },
    {
      'name': 'Chocolate Cake',
      'price': 8.99,
      'category': 'Desserts',
      'available': true,
    },
    {
      'name': 'Iced Coffee',
      'price': 4.50,
      'category': 'Beverages',
      'available': true,
    },
    {
      'name': 'Beef Steak',
      'price': 32.00,
      'category': 'Main Course',
      'available': false,
    },
    {
      'name': 'Chicken Wings',
      'price': 15.99,
      'category': 'Appetizers',
      'available': true,
    },
    {
      'name': 'Tiramisu',
      'price': 7.50,
      'category': 'Desserts',
      'available': true,
    },
  ];

  List<Map<String, dynamic>> get filteredItems => selectedCategory == 'All'
      ? menuItems
      : menuItems
            .where((item) => item['category'] == selectedCategory)
            .toList();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        'All',
                        'Appetizers',
                        'Main Course',
                        'Desserts',
                        'Beverages',
                      ].map(_buildCategoryChip).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(size.width * 0.04),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) =>
                    _buildMenuItem(filteredItems[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['category'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\$${item['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF6B4CE6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['available']
                            ? const Color(0xFF48BB78).withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['available'] ? 'Available' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item['available']
                              ? const Color(0xFF48BB78)
                              : Colors.red,
                        ),
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
  }
}

// NEW INVENTORY SCREEN
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final inventoryItems = [
      {
        'name': 'Fresh Salmon',
        'quantity': 25,
        'unit': 'kg',
        'status': 'good',
        'lastUpdated': '2 hours ago',
      },
      {
        'name': 'Tomatoes',
        'quantity': 8,
        'unit': 'kg',
        'status': 'low',
        'lastUpdated': '5 hours ago',
      },
      {
        'name': 'Pasta',
        'quantity': 150,
        'unit': 'packs',
        'status': 'good',
        'lastUpdated': '1 day ago',
      },
      {
        'name': 'Olive Oil',
        'quantity': 3,
        'unit': 'liters',
        'status': 'critical',
        'lastUpdated': '3 hours ago',
      },
      {
        'name': 'Chicken',
        'quantity': 40,
        'unit': 'kg',
        'status': 'good',
        'lastUpdated': '4 hours ago',
      },
      {
        'name': 'Lettuce',
        'quantity': 12,
        'unit': 'kg',
        'status': 'low',
        'lastUpdated': '6 hours ago',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inventory',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Total Items',
                          '6',
                          Icons.inventory_2,
                          const Color(0xFF4299E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Low Stock',
                          '2',
                          Icons.warning,
                          const Color(0xFFF6AD55),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInventoryStatCard(
                          'Critical',
                          '1',
                          Icons.error,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(size.width * 0.04),
                physics: const BouncingScrollPhysics(),
                itemCount: inventoryItems.length,
                itemBuilder: (context, index) =>
                    _buildInventoryCard(inventoryItems[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'good':
          return const Color(0xFF48BB78);
        case 'low':
          return const Color(0xFFF6AD55);
        default:
          return Colors.red;
      }
    }

    final color = getStatusColor(item['status']);
    final statusText = item['status'] == 'good'
        ? 'Good Stock'
        : item['status'] == 'low'
        ? 'Low Stock'
        : 'Critical';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.inventory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      item['lastUpdated'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                '${item['quantity']} ${item['unit']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
*/