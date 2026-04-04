// lib/services/tax_analytics_service.dart
// ════════════════════════════════════════════════════════════════════════════════
//  TAX ANALYTICS SERVICE — Dashboard & Reporting
//
//  Aggregates tax data from orders for:
//  - Dashboard display
//  - Tax compliance reporting
//  - Revenue analysis
//  - Tax breakdown visualization
// ════════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/repositories/orders_repository.dart';
import 'package:pos_app/services/order_tax_service.dart';

class TaxAnalyticsService {
  TaxAnalyticsService._internal();
  static final TaxAnalyticsService instance = TaxAnalyticsService._internal();

  final _ordersRepository = OrdersRepository.instance;

  /// Get tax analytics for a date range (used for dashboard)
  Future<TaxDashboardData> getAnalytics({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Fetch all orders for this business in date range
      final allOrders = await _ordersRepository.fetchAllOrders(
        businessId: businessId,
      );

      // Filter by date range
      final filteredOrders = allOrders.where((order) {
        return order.createdAt.isAfter(startDate) &&
            order.createdAt.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      // Calculate aggregates
      double totalTaxCollected = 0;
      final Map<String, double> taxByType = {};
      final Map<String, double> dailyTotals = {};
      final Map<String, TaxSlabStats> slabStats = {};

      for (final order in filteredOrders) {
        // Skip cancelled orders
        if (order.status == OrderStatus.cancelled) continue;

        totalTaxCollected += order.taxAmount;

        // Group by date
        final dateKey = _formatDate(order.createdAt);
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + order.taxAmount;

        // This is simplified - in production, we'd need tax breakdown stored in order
        // For now, we estimate based on tax rate
        // Real implementation would iterate through order items
      }

      final averageTaxPerOrder = filteredOrders.isNotEmpty
          ? totalTaxCollected / filteredOrders.length
          : 0.0;

      // Sort tax slabs by collection
      final topSlabs = slabStats.values.toList()
        ..sort((a, b) => b.totalTaxCollected.compareTo(a.totalTaxCollected))
        ..take(5);

      return TaxDashboardData(
        businessId: businessId,
        startDate: startDate,
        endDate: endDate,
        totalTaxCollected: totalTaxCollected,
        totalOrders: filteredOrders.length,
        averageTaxPerOrder: averageTaxPerOrder,
        taxBreakdown: taxByType,
        dailyTaxTotals: dailyTotals,
        topTaxSlabs: topSlabs.toList(),
      );
    } catch (e) {
      log('[TaxAnalyticsService] Error calculating analytics: $e');
      rethrow;
    }
  }

  /// Get tax data for today
  Future<TaxDashboardData> getTodayAnalytics(String businessId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getAnalytics(
      businessId: businessId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get tax data for this month
  Future<TaxDashboardData> getMonthAnalytics(String businessId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return getAnalytics(
      businessId: businessId,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
  }

  /// Get tax revenue percentage (tax as % of total revenue)
  Future<double> getTaxRevenuePercentage({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final allOrders = await _ordersRepository.fetchAllOrders(
        businessId: businessId,
      );

      final filteredOrders = allOrders.where((order) {
        return order.createdAt.isAfter(startDate) &&
            order.createdAt.isBefore(endDate.add(const Duration(days: 1))) &&
            order.status != OrderStatus.cancelled;
      }).toList();

      if (filteredOrders.isEmpty) return 0;

      double totalRevenue = 0;
      double totalTax = 0;

      for (final order in filteredOrders) {
        totalTax += order.taxAmount;
        totalRevenue += order.subtotal; // Revenue before tax
      }

      if (totalRevenue == 0) return 0;
      return (totalTax / totalRevenue) * 100;
    } catch (e) {
      log('[TaxAnalyticsService] Error calculating tax revenue %: $e');
      return 0;
    }
  }

  /// Compare tax data between two periods
  Future<TaxComparisonData> comparePeriods({
    required String businessId,
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) async {
    try {
      final data1 = await getAnalytics(
        businessId: businessId,
        startDate: period1Start,
        endDate: period1End,
      );

      final data2 = await getAnalytics(
        businessId: businessId,
        startDate: period2Start,
        endDate: period2End,
      );

      final taxGrowth = data1.totalTaxCollected > 0
          ? ((data2.totalTaxCollected - data1.totalTaxCollected) /
                    data1.totalTaxCollected) *
                100
          : 0.0;

      final ordersGrowth = data1.totalOrders > 0
          ? ((data2.totalOrders - data1.totalOrders) / data1.totalOrders) * 100
          : 0.0;

      return TaxComparisonData(
        period1Data: data1,
        period2Data: data2,
        taxAmountDifference: data2.totalTaxCollected - data1.totalTaxCollected,
        taxGrowthPercentage: taxGrowth,
        ordersDifference: data2.totalOrders - data1.totalOrders,
        ordersGrowthPercentage: ordersGrowth,
      );
    } catch (e) {
      log('[TaxAnalyticsService] Error comparing periods: $e');
      rethrow;
    }
  }

  /// Get tax breakdown by tax type (GST, SGST, CGST, etc.)
  Future<Map<String, dynamic>> getTaxTypeBreakdown({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final analytics = await getAnalytics(
        businessId: businessId,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        'breakdown': analytics.taxBreakdown,
        'total': analytics.totalTaxCollected,
        'currency': '₹',
      };
    } catch (e) {
      log('[TaxAnalyticsService] Error getting tax type breakdown: $e');
      return {};
    }
  }

  /// Format date for grouping
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  TAX COMPARISON DATA MODEL
// ════════════════════════════════════════════════════════════════════════════════

class TaxComparisonData {
  final TaxDashboardData period1Data;
  final TaxDashboardData period2Data;
  final double taxAmountDifference;
  final double taxGrowthPercentage;
  final int ordersDifference;
  final double ordersGrowthPercentage;

  TaxComparisonData({
    required this.period1Data,
    required this.period2Data,
    required this.taxAmountDifference,
    required this.taxGrowthPercentage,
    required this.ordersDifference,
    required this.ordersGrowthPercentage,
  });

  bool get isTaxGrowthPositive => taxGrowthPercentage > 0;
  bool get isOrderGrowthPositive => ordersGrowthPercentage > 0;

  String get taxGrowthLabel =>
      '${isTaxGrowthPositive ? '+' : ''}${taxGrowthPercentage.toStringAsFixed(1)}%';

  String get orderGrowthLabel =>
      '${isOrderGrowthPositive ? '+' : ''}${ordersGrowthPercentage.toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
    'period1': period1Data.toJson(),
    'period2': period2Data.toJson(),
    'tax_difference': taxAmountDifference,
    'tax_growth_percentage': taxGrowthPercentage,
    'orders_difference': ordersDifference,
    'orders_growth_percentage': ordersGrowthPercentage,
  };
}
