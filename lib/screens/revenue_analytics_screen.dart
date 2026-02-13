import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';


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
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
          padding: EdgeInsets.all(size.width * 0.05),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusXLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: size.width * 0.04),
              _buildPeriodSelector(context),
              SizedBox(height: size.width * 0.05),
              _buildStatisticsCards(context, stats),
              SizedBox(height: size.width * 0.05),
              _buildChart(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  fontSize: ResponsiveUtils.getFontSize(context, 24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.width * 0.01),
              Text(
                'Track your performance over time',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, 14),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.show_chart,
            color: Colors.white,
            size: ResponsiveUtils.getFontSize(context, 24),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final periods = ['Weekly', 'Monthly', 'Yearly'];

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingSmall),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
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
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.paddingSmall * 1.5,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusMedium),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
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
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: ResponsiveUtils.getFontSize(context, 14),
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
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
          context,
          mobile: 2,
          tablet: 4,
          desktop: 4,
        );
        final spacing = MediaQuery.of(context).size.width * 0.03;
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
                context,
                'Total Revenue',
                '\$${NumberFormat('#,##0.00').format(stats['total'])}',
                Icons.attach_money,
                AppColors.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                context,
                'Average',
                '\$${NumberFormat('#,##0.00').format(stats['average'])}',
                Icons.analytics,
                AppColors.success,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                context,
                'Highest',
                '\$${NumberFormat('#,##0.00').format(stats['highest'])}',
                Icons.trending_up,
                AppColors.warning,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                context,
                'Growth',
                '+${stats['growth'].toStringAsFixed(1)}%',
                Icons.arrow_upward,
                AppColors.info,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingSmall),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: ResponsiveUtils.getFontSize(context, 20),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.width * 0.02),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 12),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.width * 0.01),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final chartHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: size.width * 0.6,
      tablet: size.width * 0.4,
      desktop: size.width * 0.25,
    );

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
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
                  fontSize: ResponsiveUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.03,
                  vertical: size.width * 0.015,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: AppColors.success,
                      size: ResponsiveUtils.getFontSize(context, 14),
                    ),
                    SizedBox(width: size.width * 0.01),
                    Text(
                      'Trending Up',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getFontSize(context, 12),
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
                      reservedSize: size.width * 0.12,
                      interval: 1,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: EdgeInsets.only(right: size.width * 0.02),
                        child: Text(
                          '\$${(value * 1000).toInt()}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: ResponsiveUtils.getFontSize(context, 10),
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
                                padding: EdgeInsets.only(top: size.width * 0.02),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize:
                                        ResponsiveUtils.getFontSize(context, 10),
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
                    gradient: AppColors.primaryGradient,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.secondary.withOpacity(0.05),
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