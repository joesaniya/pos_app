import 'package:flutter/material.dart';
import 'package:pos_app/screens/widgets/design_widget.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  double _todayRevenue = 28450.0;
  int _totalOrders = 52;
  int _activeTables = 15;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButtonWithBadge(
            icon: Icons.notifications,
            onPressed: () {
              DesignUtils.hapticLight();
              // Handle notification tap
            },
            badgeCount: 3,
            iconColor: AppColors.primaryPurple,
          ),
          DesignUtils.hSpace8,
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              DesignUtils.hapticMedium();
              themeProvider.toggleTheme();
            },
          ),
          DesignUtils.hSpace8,
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DesignUtils.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Animated Counter
            SlideInAnimation(
              child: _buildWelcomeSection(),
            ),

            DesignUtils.vSpace24,

            // Stats Cards
            SlideInAnimation(
              delay: const Duration(milliseconds: 100),
              child: _buildStatsSection(),
            ),

            DesignUtils.vSpace24,

            // Quick Actions
            SlideInAnimation(
              delay: const Duration(milliseconds: 200),
              child: _buildQuickActionsSection(),
            ),

            DesignUtils.vSpace24,

            // Recent Orders
            SlideInAnimation(
              delay: const Duration(milliseconds: 300),
              child: _buildRecentOrdersSection(),
            ),

            DesignUtils.vSpace24,

            // Charts/Analytics (Example)
            SlideInAnimation(
              delay: const Duration(milliseconds: 400),
              child: _buildAnalyticsSection(),
            ),

            DesignUtils.vSpace24,
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: CustomFloatingActionButton(
        label: 'New Order',
        icon: Icons.add_shopping_cart,
        onPressed: () {
          DesignUtils.hapticHeavy();
          // Handle new order
        },
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: EdgeInsets.all(DesignUtils.space20),
      decoration: BoxDecoration(
        gradient: DesignUtils.primaryGradient(),
        borderRadius: DesignUtils.borderRadiusLG,
        boxShadow: DesignUtils.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Revenue',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          DesignUtils.vSpace8,
          AnimatedCounter(
            value: _todayRevenue,
            textStyle: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            prefix: '₹',
            decimalPlaces: 0,
          ),
          DesignUtils.vSpace8,
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: Colors.greenAccent),
                    DesignUtils.hSpace4,
                    const Text(
                      '+12.5%',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              DesignUtils.hSpace8,
              const Text(
                'vs yesterday',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        DesignUtils.vSpace16,
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: DesignUtils.space16,
          crossAxisSpacing: DesignUtils.space16,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              title: 'Total Orders',
              value: '$_totalOrders',
              icon: Icons.shopping_cart,
              color: AppColors.secondaryBlue,
              showTrend: true,
              trendValue: 8.3,
              onTap: () {
                DesignUtils.hapticLight();
                // Navigate to orders
              },
            ),
            StatCard(
              title: 'Active Tables',
              value: '$_activeTables',
              icon: Icons.table_restaurant,
              color: AppColors.secondaryOrange,
              subtitle: 'of 20 tables',
              onTap: () {
                DesignUtils.hapticLight();
                // Navigate to tables
              },
            ),
            StatCard(
              title: 'Avg. Check',
              value: DesignUtils.formatCurrency(547),
              icon: Icons.receipt_long,
              color: AppColors.secondaryGreen,
              showTrend: true,
              trendValue: -2.1,
            ),
            StatCard(
              title: 'Pending',
              value: '8',
              icon: Icons.pending_actions,
              color: AppColors.warning,
              subtitle: 'orders',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        DesignUtils.vSpace16,
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: DesignUtils.space12,
          crossAxisSpacing: DesignUtils.space12,
          childAspectRatio: 1.5,
          children: [
            QuickActionCard(
              title: 'New Order',
              icon: Icons.add_shopping_cart,
              color: AppColors.primaryPurple,
              onTap: () {
                DesignUtils.hapticMedium();
                // Handle new order
              },
            ),
            QuickActionCard(
              title: 'Tables',
              icon: Icons.table_restaurant,
              color: AppColors.secondaryBlue,
              badge: '3',
              onTap: () {
                DesignUtils.hapticMedium();
                // Handle tables
              },
            ),
            QuickActionCard(
              title: 'Menu',
              icon: Icons.restaurant_menu,
              color: AppColors.secondaryGreen,
              onTap: () {
                DesignUtils.hapticMedium();
                // Handle menu
              },
            ),
            QuickActionCard(
              title: 'Analytics',
              icon: Icons.analytics,
              color: AppColors.secondaryOrange,
              onTap: () {
                DesignUtils.hapticMedium();
                // Handle analytics
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrdersSection() {
    final orders = [
      {'table': 'Table 4', 'items': '3 items', 'amount': 1240.0, 'status': 'Active', 'time': '2m ago'},
      {'table': 'Table 8', 'items': '5 items', 'amount': 2180.0, 'status': 'Ready', 'time': '8m ago'},
      {'table': 'Table 2', 'items': '2 items', 'amount': 680.0, 'status': 'Paid', 'time': '15m ago'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        DesignUtils.vSpace12,
        ...orders.map((order) => Padding(
          padding: EdgeInsets.only(bottom: DesignUtils.space12),
          child: BorderedCard(
            borderColor: AppColors.borderLight,
            onTap: () {
              DesignUtils.hapticLight();
              // Handle order tap
            },
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(DesignUtils.space12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status'] as String).withOpacity(0.1),
                    borderRadius: DesignUtils.borderRadiusSM,
                  ),
                  child: Icon(
                    _getStatusIcon(order['status'] as String),
                    color: _getStatusColor(order['status'] as String),
                  ),
                ),
                DesignUtils.hSpace12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['table'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DesignUtils.vSpace4,
                      Text(
                        order['items'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DesignUtils.formatCurrencyFull(order['amount'] as double),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DesignUtils.vSpace4,
                    Text(
                      order['time'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return ExpandableCard(
      title: 'Today\'s Performance',
      subtitle: 'Tap to view details',
      leadingIcon: Icons.bar_chart,
      headerColor: AppColors.primaryPurple,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    ProgressRing(
                      progress: 0.75,
                      size: 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      progressColor: AppColors.secondaryGreen,
                      child: const Text(
                        '75%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DesignUtils.vSpace8,
                    const Text(
                      'Table Occupancy',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    ProgressRing(
                      progress: 0.85,
                      size: 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      progressColor: AppColors.secondaryBlue,
                      child: const Text(
                        '85%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DesignUtils.vSpace8,
                    const Text(
                      'Order Completion',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        DesignUtils.hapticSelection();
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu),
          label: 'Menu',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.warning;
      case 'Ready':
        return AppColors.info;
      case 'Paid':
        return AppColors.success;
      default:
        return AppColors.lightNeutral500;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.timer;
      case 'Ready':
        return Icons.check_circle;
      case 'Paid':
        return Icons.paid;
      default:
        return Icons.help;
    }
  }
}