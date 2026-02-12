import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/models/inventory_item.dart';
import 'package:pos_app/providers/dash_board_provier.dart';
import 'package:pos_app/screens/widgets/custom_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';

import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ResponsiveUtil().init(context);
    
    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      body: SafeArea(
        child: Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  SizedBox(height: 2.h),
                  _buildRevenueCard(context, provider),
                  SizedBox(height: 2.h),
                  _buildQuickStats(provider),
                  SizedBox(height: 2.h),
                  _buildAnalyticsChart(context, provider),
                  SizedBox(height: 2.h),
                  _buildTablesSection(provider),
                  SizedBox(height: 2.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${provider.getGreeting()},',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 0.3.h),
              Text(
                'Jenslin',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(2.5.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: AppColors.primaryPurple,
            size: 22.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard(BuildContext context, DashboardProvider provider) {
    final stats = provider.stats;
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 15,
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
              Text(
                'Today\'s Revenue',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => _showDatePicker(context, provider),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white, size: 14.sp),
                      SizedBox(width: 1.w),
                      Text(
                        DateFormat('MMM dd').format(provider.selectedDate),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            '₹${stats.todayRevenue.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Yesterday',
                  '₹${(stats.yesterdayRevenue / 1000).toStringAsFixed(1)}k',
                  Icons.trending_up,
                  AppColors.success,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildQuickStat(
                  'This Week',
                  '₹${(stats.weekRevenue / 100000).toStringAsFixed(1)}L',
                  Icons.bar_chart,
                  Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(2.5.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DashboardProvider provider) {
    final stats = provider.stats;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 3.w,
      crossAxisSpacing: 3.w,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: 'Total Orders',
          value: '${stats.totalOrders}',
          icon: Icons.receipt_long,
          color: AppColors.secondaryBlue,
          subtitle: '+12 from yesterday',
        ),
        StatCard(
          title: 'Active Tables',
          value: '${stats.activeTables}/${stats.totalTables}',
          icon: Icons.table_restaurant,
          color: AppColors.secondaryGreen,
          subtitle: '${stats.totalTables - stats.activeTables} available',
        ),
        StatCard(
          title: 'Pending Orders',
          value: '${stats.pendingOrders}',
          icon: Icons.hourglass_empty,
          color: AppColors.secondaryOrange,
          subtitle: '5 in preparation',
        ),
        StatCard(
          title: 'Menu Items',
          value: '${stats.menuItems}',
          icon: Icons.restaurant_menu,
          color: AppColors.primaryRed,
          subtitle: '${stats.lowStockItems} low stock',
        ),
      ],
    );
  }

  Widget _buildAnalyticsChart(BuildContext context, DashboardProvider provider) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Analytics',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: AppColors.lightNeutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          SizedBox(
            height: 25.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.lightNeutral200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${(value / 1000).toInt()}k',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9.sp,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= provider.stats.weeklyRevenue.length) {
                          return const SizedBox.shrink();
                        }
                        final date = provider.stats.weeklyRevenue[value.toInt()].date;
                        return Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: Text(
                            DateFormat('EEE').format(date),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.sp,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: provider.stats.weeklyRevenue.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.amount);
                    }).toList(),
                    isCurved: true,
                    gradient: AppColors.primaryGradient,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AppColors.primaryPurple,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryPurple.withOpacity(0.3),
                          AppColors.primaryPurple.withOpacity(0.0),
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

  Widget _buildTablesSection(DashboardProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tables Overview',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text('View All', style: TextStyle(fontSize: 12.sp)),
            ),
          ],
        ),
        SizedBox(height: 1.5.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2.w,
            crossAxisSpacing: 2.w,
            childAspectRatio: 0.9,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final table = provider.tables[index];
            Color statusColor;
            String statusText;

            switch (table.status) {
              case TableStatus.occupied:
                statusColor = AppColors.primaryRed;
                statusText = 'Occupied';
                break;
              case TableStatus.reserved:
                statusColor = AppColors.secondaryOrange;
                statusText = 'Reserved';
                break;
              case TableStatus.empty:
                statusColor = AppColors.secondaryGreen;
                statusText = 'Empty';
                break;
            }

            return TableCard(
              tableNumber: table.number,
              status: statusText,
              statusColor: statusColor,
              orderItems: table.status == TableStatus.occupied ? 4 : null,
              onTap: () {},
            );
          },
        ),
      ],
    );
  }

  void _showDatePicker(BuildContext context, DashboardProvider provider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != provider.selectedDate) {
      provider.selectDate(picked);
    }
  }
}