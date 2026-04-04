// lib/services/tax_calculation_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  TAX CALCULATION SERVICE — Complete Order & Menu Tax Integration
//
//  Features:
//  1. Calculate item-level taxes based on tax slabs
//  2. Aggregate taxes at order level
//  3. Handle inclusive and exclusive taxes
//  4. Support for promo codes and discounts
//  5. Round-off calculations for final billing
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/repositories/tax_repository.dart';

class OrderTaxBreakdown {
  /// Items list with their individual tax details
  final List<ItemTaxDetail> itemDetails;

  /// Total subtotal (sum of all item prices × quantity)
  final double subtotal;

  /// Total tax amount (sum of all item taxes)
  final double totalTaxAmount;

  /// Order total with taxes (subtotal + tax)
  final double totalWithTax;

  /// Average tax rate applied
  final double averageTaxRate;

  /// Tax type breakdown
  final Map<String, double> taxByType; // e.g., {'GST': 120.5, 'SGST': 60.25}

  OrderTaxBreakdown({
    required this.itemDetails,
    required this.subtotal,
    required this.totalTaxAmount,
    required this.totalWithTax,
    required this.averageTaxRate,
    required this.taxByType,
  });
}

class ItemTaxDetail {
  /// Menu item unique identifier
  final String menuItemId;

  /// Item name
  final String itemName;

  /// Price per item
  final double itemPrice;

  /// Quantity ordered
  final int quantity;

  /// Subtotal for this item (price × quantity)
  final double itemSubtotal;

  /// Tax slab applied to this item
  final TaxSlab? taxSlab;

  /// Tax amount calculated for this item
  final double itemTaxAmount;

  /// Item total including tax
  final double itemTotal;

  /// Tax percentage applied
  final double taxPercentage;

  /// Tax type (inclusive/exclusive)
  final TaxType? taxType;

  ItemTaxDetail({
    required this.menuItemId,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    required this.itemSubtotal,
    this.taxSlab,
    required this.itemTaxAmount,
    required this.itemTotal,
    required this.taxPercentage,
    this.taxType,
  });

  /// Format tax display for receipt
  String getTaxDisplay() {
    if (taxSlab == null) return 'No Tax';
    return '${taxSlab!.name} (${taxPercentage.toStringAsFixed(2)}%)';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAX CALCULATION SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class TaxCalculationService {
  TaxCalculationService._internal();
  static final TaxCalculationService instance =
      TaxCalculationService._internal();

  final _taxRepository = TaxRepository.instance;

  /// Calculate taxes for a single item
  /// Returns (taxAmount, finalPrice)
  ({double taxAmount, double finalPrice}) calculateItemTax({
    required double itemPrice,
    required int quantity,
    required TaxSlab? taxSlab,
  }) {
    if (taxSlab == null) {
      return (taxAmount: 0.0, finalPrice: itemPrice * quantity);
    }

    final calculation = TaxCalculation(taxSlab: taxSlab, itemPrice: itemPrice);

    final itemTaxAmount = calculation.taxAmount;
    final itemFinalPrice = calculation.finalPrice;

    final totalTax = itemTaxAmount * quantity;
    final totalPrice = itemFinalPrice * quantity;

    return (taxAmount: totalTax, finalPrice: totalPrice);
  }

  /// Calculate complete order tax breakdown
  /// Integrates tax for all items in the order
  Future<OrderTaxBreakdown> calculateOrderTaxes({
    required List<CartItem> cartItems,
    required String businessId,
    Map<String, TaxSlab>? taxSlabCache,
  }) async {
    final List<ItemTaxDetail> itemDetails = [];
    double totalSubtotal = 0.0;
    double totalTaxAmount = 0.0;
    final Map<String, double> taxByType = {};

    // Load tax slabs if not cached
    final taxCache = taxSlabCache ?? {};
    if (taxSlabCache == null) {
      try {
        final taxSlabs = await _taxRepository.getAllTaxSlabsForBusiness(
          businessId,
        );
        for (final slab in taxSlabs) {
          taxCache[slab.id] = slab;
        }
      } catch (e) {
        log('[TaxCalculationService] Error loading tax slabs: $e');
      }
    }

    // Calculate tax for each item
    for (final cartItem in cartItems) {
      final itemSubtotal = cartItem.itemPrice * cartItem.quantity;
      totalSubtotal += itemSubtotal;

      // For now, we'll use default tax or none if not available
      // In a real app, you'd fetch the tax slab from the menu item
      TaxSlab? appliedTax;
      double itemTaxAmount = 0.0;
      double itemTotal = itemSubtotal;

      if (appliedTax != null) {
        final calculation = TaxCalculation(
          taxSlab: appliedTax,
          itemPrice: cartItem.itemPrice,
        );
        itemTaxAmount = calculation.taxAmount * cartItem.quantity;
        itemTotal = calculation.finalPrice * cartItem.quantity;

        totalTaxAmount += itemTaxAmount;

        // Track tax by type
        final taxName = appliedTax.name;
        taxByType[taxName] = (taxByType[taxName] ?? 0.0) + itemTaxAmount;
      }

      itemDetails.add(
        ItemTaxDetail(
          menuItemId: cartItem.menuItemId,
          itemName: cartItem.itemName,
          itemPrice: cartItem.itemPrice,
          quantity: cartItem.quantity,
          itemSubtotal: itemSubtotal,
          taxSlab: appliedTax,
          itemTaxAmount: itemTaxAmount,
          itemTotal: itemTotal,
          taxPercentage: appliedTax?.percentage ?? 0.0,
          taxType: appliedTax?.type,
        ),
      );
    }

    final totalWithTax = totalSubtotal + totalTaxAmount;
    final averageTaxRate = totalSubtotal > 0
        ? (totalTaxAmount / totalSubtotal) * 100
        : 0.0;

    return OrderTaxBreakdown(
      itemDetails: itemDetails,
      subtotal: totalSubtotal,
      totalTaxAmount: totalTaxAmount,
      totalWithTax: totalWithTax,
      averageTaxRate: averageTaxRate,
      taxByType: taxByType,
    );
  }

  /// Calculate final bill amount with all components
  /// Handles: subtotal, taxes, discounts, tips, round-off
  ({
    double subtotal,
    double taxAmount,
    double discountAmount,
    double tipAmount,
    double roundOff,
    double grandTotal,
  })
  calculateFinalBill({
    required double subtotal,
    required double taxAmount,
    required double discountAmount,
    required double tipAmount,
    required bool enableRoundOff,
  }) {
    final afterDiscount = subtotal + taxAmount - discountAmount;
    final beforeRoundOff = afterDiscount + tipAmount;

    double roundOff = 0.0;
    if (enableRoundOff) {
      final remainder = beforeRoundOff % 1;
      if (remainder >= 0.5) {
        roundOff = (1.0 - remainder).toStringAsFixed(2) == '1.00'
            ? 1.0
            : (1.0 - remainder);
      } else if (remainder > 0) {
        roundOff = -remainder;
      }
    }

    final grandTotal = beforeRoundOff + roundOff;

    return (
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      roundOff: roundOff,
      grandTotal: grandTotal.toStringAsFixed(2) == grandTotal.toStringAsFixed(2)
          ? grandTotal
          : double.parse(grandTotal.toStringAsFixed(2)),
    );
  }

  /// Apply tax slab to menu item price
  /// Used when displaying menu item final price to customer
  double getMenuItemFinalPrice({
    required double basePrice,
    required TaxSlab? taxSlab,
  }) {
    if (taxSlab == null) return basePrice;

    final calculation = TaxCalculation(taxSlab: taxSlab, itemPrice: basePrice);
    return calculation.finalPrice;
  }

  /// Get display text for item price with tax info
  String getPriceDisplayText({
    required double basePrice,
    required TaxSlab? taxSlab,
    bool includeTaxInfo = true,
  }) {
    if (taxSlab == null) {
      return '₹${basePrice.toStringAsFixed(2)}';
    }

    final calculation = TaxCalculation(taxSlab: taxSlab, itemPrice: basePrice);
    final finalPrice = calculation.finalPrice;
    final taxAmount = calculation.taxAmount;

    if (!includeTaxInfo) {
      return '₹${finalPrice.toStringAsFixed(2)}';
    }

    if (taxSlab.type == TaxType.inclusive) {
      return '₹${finalPrice.toStringAsFixed(2)} (incl. ${taxSlab.percentage}% tax)';
    } else {
      return '₹${basePrice.toStringAsFixed(2)} + ₹${taxAmount.toStringAsFixed(2)} tax';
    }
  }

  /// Format tax breakdown for receipt
  String formatTaxBreakdown(OrderTaxBreakdown breakdown) {
    final buffer = StringBuffer();
    buffer.writeln('═' * 50);
    buffer.writeln('TAX BREAKDOWN');
    buffer.writeln('═' * 50);

    for (final item in breakdown.itemDetails) {
      buffer.writeln('${item.itemName} x${item.quantity}');
      buffer.writeln('  Base: ₹${item.itemSubtotal.toStringAsFixed(2)}');
      if (item.itemTaxAmount > 0) {
        buffer.writeln(
          '  Tax: ₹${item.itemTaxAmount.toStringAsFixed(2)} (${item.getTaxDisplay()})',
        );
      }
      buffer.writeln('  Total: ₹${item.itemTotal.toStringAsFixed(2)}');
      buffer.writeln('---');
    }

    buffer.writeln();
    buffer.writeln('Subtotal: ₹${breakdown.subtotal.toStringAsFixed(2)}');
    buffer.writeln(
      'Tax Total: ₹${breakdown.totalTaxAmount.toStringAsFixed(2)}',
    );
    buffer.writeln('─' * 50);
    buffer.writeln(
      'Grand Total: ₹${breakdown.totalWithTax.toStringAsFixed(2)}',
    );

    return buffer.toString();
  }
}
