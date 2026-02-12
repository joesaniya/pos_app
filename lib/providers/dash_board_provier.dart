import 'package:flutter/material.dart';
import 'package:pos_app/models/dashboard_stats_modal.dart';
import 'package:pos_app/models/inventory_item.dart';
import 'package:pos_app/models/menu_item.dart';


class DashboardProvider extends ChangeNotifier {
  DashboardStats _stats = DashboardStats(
    todayRevenue: 45280,
    yesterdayRevenue: 38420,
    weekRevenue: 280000,
    totalOrders: 142,
    activeTables: 8,
    totalTables: 15,
    pendingOrders: 23,
    menuItems: 86,
    lowStockItems: 8,
    weeklyRevenue: [],
  );

  List<TableInfo> _tables = [];
  DateTime _selectedDate = DateTime.now();

  DashboardStats get stats => _stats;
  List<TableInfo> get tables => _tables;
  DateTime get selectedDate => _selectedDate;

  DashboardProvider() {
    _initializeData();
  }

  void _initializeData() {
    // Generate weekly revenue data
    final now = DateTime.now();
    final List<RevenueData> weeklyData = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final amount = 32000 + (i * 2000) + (i % 2 == 0 ? 1000 : 0);
      weeklyData.add(RevenueData(date: date, amount: amount.toDouble()));
    }

    _stats = DashboardStats(
      todayRevenue: _stats.todayRevenue,
      yesterdayRevenue: _stats.yesterdayRevenue,
      weekRevenue: _stats.weekRevenue,
      totalOrders: _stats.totalOrders,
      activeTables: _stats.activeTables,
      totalTables: _stats.totalTables,
      pendingOrders: _stats.pendingOrders,
      menuItems: _stats.menuItems,
      lowStockItems: _stats.lowStockItems,
      weeklyRevenue: weeklyData,
    );

    // Initialize tables
    _tables = List.generate(15, (index) {
      final tableNum = (index + 1).toString();
      TableStatus status;
      
      if (index < 8) {
        status = TableStatus.occupied;
      } else if (index < 10) {
        status = TableStatus.reserved;
      } else {
        status = TableStatus.empty;
      }

      return TableInfo(
        number: tableNum,
        capacity: 4,
        status: status,
      );
    });

    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _updateRevenueForDate(date);
    notifyListeners();
  }

  void _updateRevenueForDate(DateTime date) {
    // Update revenue data based on selected date
    // This is a placeholder - in real app, fetch from API
    final now = DateTime.now();
    final weeklyData = <RevenueData>[];
    
    for (int i = 6; i >= 0; i--) {
      final dataDate = date.subtract(Duration(days: i));
      final amount = 30000 + (i * 2500) + (i % 2 == 0 ? 1500 : 0);
      weeklyData.add(RevenueData(date: dataDate, amount: amount.toDouble()));
    }

    _stats = DashboardStats(
      todayRevenue: weeklyData.last.amount,
      yesterdayRevenue: weeklyData[weeklyData.length - 2].amount,
      weekRevenue: weeklyData.fold(0, (sum, item) => sum + item.amount),
      totalOrders: _stats.totalOrders,
      activeTables: _stats.activeTables,
      totalTables: _stats.totalTables,
      pendingOrders: _stats.pendingOrders,
      menuItems: _stats.menuItems,
      lowStockItems: _stats.lowStockItems,
      weeklyRevenue: weeklyData,
    );
  }

  void updateTableStatus(String tableNumber, TableStatus status) {
    final index = _tables.indexWhere((t) => t.number == tableNumber);
    if (index != -1) {
      _tables[index].status = status;
      
      // Update active tables count
      final activeCount = _tables.where((t) => t.status == TableStatus.occupied).length;
      _stats = DashboardStats(
        todayRevenue: _stats.todayRevenue,
        yesterdayRevenue: _stats.yesterdayRevenue,
        weekRevenue: _stats.weekRevenue,
        totalOrders: _stats.totalOrders,
        activeTables: activeCount,
        totalTables: _stats.totalTables,
        pendingOrders: _stats.pendingOrders,
        menuItems: _stats.menuItems,
        lowStockItems: _stats.lowStockItems,
        weeklyRevenue: _stats.weeklyRevenue,
      );
      
      notifyListeners();
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}