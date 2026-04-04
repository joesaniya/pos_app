// lib/services/order_tax_service.dart
// ════════════════════════════════════════════════════════════════════════════════
//  ORDER TAX SERVICE — Automatic Tax Application & Calculation
//
//  Responsibilities:
//  1. Fetch applicable taxes for a business
//  2. Apply taxes to cart items based on configuration
//  3. Calculate order-level tax breakdown
//  4. Store tax data in orders
//  5. Support tax analytics and dashboard reporting
// ════════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/repositories/tax_repository.dart';

/// Tax application result for an order
class OrderTaxResult {
  /// All applicable taxes for this business
  final List<TaxSlab> applicableTaxes;

  /// Item-level tax breakdowns
  final Map<String, List<AppliedTax>> itemTaxes; // menuItemId -> [taxes]

  /// Order-level tax summary
  final OrderTaxSummary summary;

  OrderTaxResult({
    required this.applicableTaxes,
    required this.itemTaxes,
    required this.summary,
  });
}

/// Individual tax applied to an item or order
class AppliedTax {
  final String taxSlabId;
  final String taxName;
  final double taxPercentage;
  final TaxType taxType;
  final double baseAmount;
  final double taxAmount;
  final double totalAmount;

  AppliedTax({
    required this.taxSlabId,
    required this.taxName,
    required this.taxPercentage,
    required this.taxType,
    required this.baseAmount,
    required this.taxAmount,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() => {
    'tax_slab_id': taxSlabId,
    'tax_name': taxName,
    'tax_percentage': taxPercentage,
    'tax_type': taxType.dbValue,
    'base_amount': baseAmount,
    'tax_amount': taxAmount,
    'total_amount': totalAmount,
  };
}

/// Order-level tax summary
class OrderTaxSummary {
  /// Subtotal before any taxes
  final double subtotal;

  /// Total tax amount (sum of all taxes)
  final double totalTaxAmount;

  /// Breakdown by tax type
  final Map<String, double> taxByType; // 'GST' -> 500, 'SGST' -> 250

  /// Breakdown by tax slab
  final Map<String, double> taxByName; // 'GST 18%' -> 500

  /// Total with all taxes applied
  final double grandTotal;

  /// Average effective tax rate
  final double effectiveTaxRate;

  OrderTaxSummary({
    required this.subtotal,
    required this.totalTaxAmount,
    required this.taxByType,
    required this.taxByName,
    required this.grandTotal,
    required this.effectiveTaxRate,
  });

  Map<String, dynamic> toJson() => {
    'subtotal': subtotal,
    'total_tax_amount': totalTaxAmount,
    'tax_by_type': taxByType,
    'tax_by_name': taxByName,
    'grand_total': grandTotal,
    'effective_tax_rate': effectiveTaxRate,
  };
}

// ════════════════════════════════════════════════════════════════════════════════
//  ORDER TAX SERVICE
// ════════════════════════════════════════════════════════════════════════════════

class OrderTaxService {
  OrderTaxService._internal();
  static final OrderTaxService instance = OrderTaxService._internal();

  final _taxRepository = TaxRepository.instance;

  /// Get all active taxes for a business
  Future<List<TaxSlab>> getBusinessTaxes(String businessId) async {
    try {
      final allTaxes = await _taxRepository.getAllTaxSlabsForBusiness(
        businessId,
      );
      final activeTaxes = allTaxes.where((tax) => tax.isActive).toList();

      log(
        '[OrderTaxService] Fetched ${activeTaxes.length} active taxes for business: $businessId',
      );
      return activeTaxes;
    } catch (e) {
      log('[OrderTaxService] Error fetching taxes: $e');
      return [];
    }
  }

  /// Apply taxes to order items and calculate order-level totals
  /// This is called during order creation
  Future<OrderTaxResult> calculateOrderTaxes({
    required List<CartItem> cartItems,
    required String businessId,
    Map<String, String?>? itemTaxSlabIds, // Map of menuItemId -> taxSlabId
  }) async {
    // Fetch applicable taxes for this business
    final applicableTaxes = await getBusinessTaxes(businessId);

    double subtotal = 0;
    double totalTaxAmount = 0;
    final Map<String, double> taxByType = {};
    final Map<String, double> taxByName = {};
    final Map<String, List<AppliedTax>> itemTaxes = {};

    // Calculate tax for each item
    for (final item in cartItems) {
      final itemSubtotal = item.itemPrice * item.quantity;
      subtotal += itemSubtotal;

      final List<AppliedTax> appliedToItem = [];

      // Get tax slab for this item if specified
      final taxSlabId = itemTaxSlabIds?[item.menuItemId];

      if (taxSlabId != null && taxSlabId.isNotEmpty) {
        try {
          final taxSlab = await _taxRepository.getTaxSlabById(taxSlabId);

          if (taxSlab != null && taxSlab.isActive) {
            // Calculate tax for this slab
            final calc = TaxCalculation(
              taxSlab: taxSlab,
              itemPrice: item.itemPrice,
            );
            final itemTaxAmount = calc.taxAmount * item.quantity;
            final itemTotalWithTax = calc.finalPrice * item.quantity;

            final appliedTax = AppliedTax(
              taxSlabId: taxSlab.id,
              taxName: taxSlab.name,
              taxPercentage: taxSlab.percentage,
              taxType: taxSlab.type,
              baseAmount: itemSubtotal,
              taxAmount: itemTaxAmount,
              totalAmount: itemTotalWithTax,
            );

            appliedToItem.add(appliedTax);
            totalTaxAmount += itemTaxAmount;

            // Track tax by type
            final taxTypeKey = taxSlab.type.dbValue;
            taxByType[taxTypeKey] =
                (taxByType[taxTypeKey] ?? 0) + itemTaxAmount;

            // Track tax by name
            taxByName[taxSlab.name] =
                (taxByName[taxSlab.name] ?? 0) + itemTaxAmount;
          } else {
            log(
              '[OrderTaxService] Tax slab is inactive or not found: $taxSlabId',
            );
          }
        } catch (e) {
          log('[OrderTaxService] Error fetching tax slab $taxSlabId: $e');
        }
      }

      // Also apply default/global taxes if configured
      // For now, we only apply per-item taxes
      itemTaxes[item.menuItemId] = appliedToItem;
    }

    final grandTotal = subtotal + totalTaxAmount;
    final effectiveTaxRate = subtotal > 0
        ? (totalTaxAmount / subtotal) * 100
        : 0.0;

    final summary = OrderTaxSummary(
      subtotal: subtotal,
      totalTaxAmount: totalTaxAmount,
      taxByType: taxByType,
      taxByName: taxByName,
      grandTotal: grandTotal,
      effectiveTaxRate: effectiveTaxRate,
    );

    return OrderTaxResult(
      applicableTaxes: applicableTaxes,
      itemTaxes: itemTaxes,
      summary: summary,
    );
  }

  /// Get aggregated tax data for dashboard reporting
  /// Groups taxes by type and date range
  Future<TaxDashboardData> getTaxDashboardData({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // This will be implemented by querying orders with tax data
      // For now, return empty structure
      // Actual implementation will fetch from orders collection

      return TaxDashboardData(
        businessId: businessId,
        startDate: startDate,
        endDate: endDate,
        totalTaxCollected: 0,
        totalOrders: 0,
        averageTaxPerOrder: 0,
        taxBreakdown: {},
        dailyTaxTotals: {},
        topTaxSlabs: [],
      );
    } catch (e) {
      log('[OrderTaxService] Error fetching dashboard data: $e');
      rethrow;
    }
  }

  /// Get tax summary for a specific order
  Future<OrderTaxSummary?> getOrderTaxSummary(Order order) async {
    try {
      // Extract tax data from order if stored
      // This assumes order has taxAmount and taxRate fields
      return OrderTaxSummary(
        subtotal: order.subtotal,
        totalTaxAmount: order.taxAmount,
        taxByType: {}, // Would be stored in order if needed
        taxByName: {}, // Would be stored in order if needed
        grandTotal: order.totalAmount,
        effectiveTaxRate: order.taxRate,
      );
    } catch (e) {
      log('[OrderTaxService] Error getting order tax summary: $e');
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  DASHBOARD DATA MODEL
// ════════════════════════════════════════════════════════════════════════════════

class TaxDashboardData {
  final String businessId;
  final DateTime startDate;
  final DateTime endDate;

  /// Total tax amount collected in this period
  final double totalTaxCollected;

  /// Number of orders in this period
  final int totalOrders;

  /// Average tax per order
  final double averageTaxPerOrder;

  /// Breakdown of tax by type (e.g., 'GST' -> 5000)
  final Map<String, double> taxBreakdown;

  /// Daily tax totals (date string -> amount)
  final Map<String, double> dailyTaxTotals;

  /// Top tax slabs by collection
  final List<TaxSlabStats> topTaxSlabs;

  TaxDashboardData({
    required this.businessId,
    required this.startDate,
    required this.endDate,
    required this.totalTaxCollected,
    required this.totalOrders,
    required this.averageTaxPerOrder,
    required this.taxBreakdown,
    required this.dailyTaxTotals,
    required this.topTaxSlabs,
  });

  /// Calculate tax as percentage of revenue
  double get taxAsPercentageOfRevenue {
    final revenue =
        totalTaxCollected /
        (1 + (totalOrders > 0 ? averageTaxPerOrder / totalTaxCollected : 0));
    return revenue > 0
        ? (totalTaxCollected / (revenue + totalTaxCollected)) * 100
        : 0;
  }

  /// Format for display
  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'total_tax_collected': totalTaxCollected,
    'total_orders': totalOrders,
    'average_tax_per_order': averageTaxPerOrder,
    'tax_breakdown': taxBreakdown,
    'daily_tax_totals': dailyTaxTotals,
    'top_tax_slabs': topTaxSlabs.map((t) => t.toJson()).toList(),
    'tax_as_percentage_of_revenue': taxAsPercentageOfRevenue,
  };
}

/// Statistics for a tax slab
class TaxSlabStats {
  final String taxSlabId;
  final String taxSlabName;
  final double percentage;
  final TaxType taxType;
  final double totalTaxCollected;
  final int timesApplied;
  final double averageTaxPerApplication;

  TaxSlabStats({
    required this.taxSlabId,
    required this.taxSlabName,
    required this.percentage,
    required this.taxType,
    required this.totalTaxCollected,
    required this.timesApplied,
    required this.averageTaxPerApplication,
  });

  Map<String, dynamic> toJson() => {
    'tax_slab_id': taxSlabId,
    'tax_slab_name': taxSlabName,
    'percentage': percentage,
    'tax_type': taxType.dbValue,
    'total_collected': totalTaxCollected,
    'times_applied': timesApplied,
    'average_per_application': averageTaxPerApplication,
  };
}
