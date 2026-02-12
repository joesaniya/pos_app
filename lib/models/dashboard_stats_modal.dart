import 'package:pos_app/models/inventory_item.dart';

class DashboardStats {
  final double todayRevenue;
  final double yesterdayRevenue;
  final double weekRevenue;
  final int totalOrders;
  final int activeTables;
  final int totalTables;
  final int pendingOrders;
  final int menuItems;
  final int lowStockItems;
  final List<RevenueData> weeklyRevenue;

  DashboardStats({
    required this.todayRevenue,
    required this.yesterdayRevenue,
    required this.weekRevenue,
    required this.totalOrders,
    required this.activeTables,
    required this.totalTables,
    required this.pendingOrders,
    required this.menuItems,
    required this.lowStockItems,
    required this.weeklyRevenue,
  });
}