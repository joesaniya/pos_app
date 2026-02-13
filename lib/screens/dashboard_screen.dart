import 'package:flutter/material.dart';
import 'package:pos_app/screens/revenue_analytics_screen.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/action_card_widget.dart';
import 'package:pos_app/screens/widgets/filter_chip_widget.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/screens/widgets/star_card_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<DashboardProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: GradientHeader(
                    title: 'Resto POS',
                    subtitle: provider.selectedDate != null
                        ? 'Data for ${DateFormat('MMM dd, yyyy').format(provider.selectedDate!)}'
                        : 'Dashboard Overview',
                    actionIcon: Icons.notifications_outlined,
                    bottomWidget: _buildPeriodSelector(context, provider),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  sliver: SliverToBoxAdapter(
                    child: _buildStatCards(context, provider),
                  ),
                ),
                SliverToBoxAdapter(
                  child: EnhancedRevenueAnalytics(
                    selectedDate: provider.selectedDate,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  sliver: SliverToBoxAdapter(
                    child: _buildQuickActions(context),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    DashboardProvider provider,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilterChipRow(
            items: const ['Today', 'Yesterday', 'Last Month', 'Last Year'],
            selectedItem: provider.selectedDate != null
                ? ''
                : provider.selectedPeriod,
            onItemSelected: (period) => provider.setSelectedPeriod(period),
          ),
        ),
        const SizedBox(width: 8),
        _buildCalendarButton(context, provider),
      ],
    );
  }

  Widget _buildCalendarButton(
    BuildContext context,
    DashboardProvider provider,
  ) {
    final hasDate = provider.selectedDate != null;

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: provider.selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          provider.setSelectedDate(date);
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
          color: hasDate ? AppColors.primary : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, DashboardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(context);
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
              child: StatCard(
                title: 'Revenue',
                value: '\$${provider.getRevenueForPeriod().toStringAsFixed(0)}',
                change: provider.getRevenueChange(),
                icon: Icons.attach_money,
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatCard(
                title: 'Orders',
                value: provider.getOrdersCount().toString(),
                change: 12.5,
                icon: Icons.receipt,
                color: AppColors.success,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatCard(
                title: 'Avg Order',
                value: '\$${provider.getAverageOrder().toStringAsFixed(0)}',
                change: -2.3,
                icon: Icons.trending_up,
                color: AppColors.warning,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatCard(
                title: 'Active Tables',
                value: provider.getActiveTables().toString(),
                icon: Icons.table_restaurant,
                color: AppColors.info,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
              context,
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
                  child: const ActionCard(
                    title: 'New Order',
                    icon: Icons.add_shopping_cart,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const ActionCard(
                    title: 'View Tables',
                    icon: Icons.table_restaurant,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const ActionCard(
                    title: 'Reports',
                    icon: Icons.bar_chart,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const ActionCard(
                    title: 'Settings',
                    icon: Icons.settings,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
