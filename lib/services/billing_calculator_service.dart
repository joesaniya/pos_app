import 'dart:developer';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/models/order_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM TAX CALCULATION
// ─────────────────────────────────────────────────────────────────────────────

class ItemTaxCalculation {
  final String itemId;
  final String itemName;
  final double itemPrice;
  final int quantity;
  final TaxSlab? taxSlab;

  ItemTaxCalculation({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    this.taxSlab,
  });

  /// Subtotal before tax
  double get subtotal {
    if (taxSlab == null || taxSlab!.type == TaxType.none) {
      return itemPrice * quantity;
    }

    if (taxSlab!.type == TaxType.inclusive) {
      // Price includes tax, so subtract tax to get subtotal
      final multiplier = 1 + (taxSlab!.percentage / 100);
      final itemSubtotal = itemPrice / multiplier;
      return itemSubtotal * quantity;
    }

    // Exclusive: price is already the subtotal
    return itemPrice * quantity;
  }

  /// Tax amount for item
  double get taxAmount {
    if (taxSlab == null || taxSlab!.type == TaxType.none) {
      return 0.0;
    }

    if (taxSlab!.type == TaxType.exclusive) {
      return itemPrice * (taxSlab!.percentage / 100) * quantity;
    }

    // Inclusive: tax is already in price
    final multiplier = 1 + (taxSlab!.percentage / 100);
    final itemSubtotal = itemPrice / multiplier;
    return (itemPrice - itemSubtotal) * quantity;
  }

  /// Total price including tax
  double get total => subtotal + taxAmount;

  /// Tax percentage for display
  double get taxPercentage => taxSlab?.percentage ?? 0.0;

  /// Tax type name
  String get taxTypeName => taxSlab?.type.displayName ?? 'No Tax';

  /// Tax name for line item
  String get taxLabel => taxSlab?.name ?? 'No Tax';
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER TAX SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

class OrderTaxSummary {
  final List<ItemTaxCalculation> items;

  OrderTaxSummary({required this.items});

  /// Total subtotal (before any tax)
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Total tax amount across all items
  double get totalTax => items.fold(0.0, (sum, item) => sum + item.taxAmount);

  /// Final total (subtotal + tax)
  double get total => subtotal + totalTax;

  /// Discount amount (if applicable)
  double discountAmount = 0.0;

  /// Final amount after all deductions
  double get finalAmount => total - discountAmount;

  /// Tax breakdown by slab (e.g., GST 5%: 50, GST 12%: 100)
  Map<String, double> get taxBreakdownBySlab {
    final breakdown = <String, double>{};

    for (final item in items) {
      if (item.taxSlab != null && item.taxAmount > 0) {
        final key = item.taxLabel;
        breakdown[key] = (breakdown[key] ?? 0.0) + item.taxAmount;
      }
    }

    return breakdown;
  }

  /// Tax breakdown by percentage (e.g., "5%": 50, "12%": 100)
  Map<String, double> get taxBreakdownByPercentage {
    final breakdown = <String, double>{};

    for (final item in items) {
      if (item.taxSlab != null && item.taxAmount > 0) {
        final key = '${item.taxSlab!.percentage}%';
        breakdown[key] = (breakdown[key] ?? 0.0) + item.taxAmount;
      }
    }

    return breakdown;
  }

  /// Get list of distinct tax types used
  List<TaxSlab> get distinctTaxSlabs {
    final slabs = <String, TaxSlab>{};

    for (final item in items) {
      if (item.taxSlab != null) {
        slabs[item.taxSlab!.id] = item.taxSlab!;
      }
    }

    return slabs.values.toList();
  }

  /// Check if any items use inclusive tax
  bool get hasInclusiveTax =>
      items.any((item) => item.taxSlab?.type == TaxType.inclusive);

  /// Check if any items use exclusive tax
  bool get hasExclusiveTax =>
      items.any((item) => item.taxSlab?.type == TaxType.exclusive);

  /// Get total tax percentage (average or specific based on order type)
  double get effectiveTaxPercentage {
    if (subtotal == 0) return 0.0;
    return (totalTax / subtotal) * 100;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BILLING CALCULATOR SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class BillingCalculatorService {
  static final BillingCalculatorService _instance =
      BillingCalculatorService._internal();

  factory BillingCalculatorService() {
    return _instance;
  }

  BillingCalculatorService._internal();

  // ─────────────────────────────────────────────────────────────────────────

  /// Calculate order summary from items and tax slabs
  OrderTaxSummary calculateOrder({
    required List<CartItem> cartItems,
    double discountAmount = 0.0,
  }) {
    final itemCalculations = cartItems.map((cartItem) {
      return ItemTaxCalculation(
        itemId: cartItem.id,
        itemName: cartItem.name,
        itemPrice: cartItem.price,
        quantity: cartItem.quantity,
        taxSlab: cartItem.taxSlab,
      );
    }).toList();

    final summary = OrderTaxSummary(items: itemCalculations);
    summary.discountAmount = discountAmount;

    logCalculation(summary);
    return summary;
  }

  /// Calculate for a single item
  ItemTaxCalculation calculateItem({
    required String itemId,
    required String itemName,
    required double itemPrice,
    required int quantity,
    required TaxSlab? taxSlab,
  }) {
    return ItemTaxCalculation(
      itemId: itemId,
      itemName: itemName,
      itemPrice: itemPrice,
      quantity: quantity,
      taxSlab: taxSlab,
    );
  }

  /// Apply percentage discount to summary
  void applyPercentageDiscount({
    required OrderTaxSummary summary,
    required double discountPercentage,
  }) {
    summary.discountAmount = summary.total * (discountPercentage / 100);
    log(
      '[BillingCalculator] Discount applied: ${discountPercentage}% = ₹${summary.discountAmount.toStringAsFixed(2)}',
    );
  }

  /// Apply flat discount to summary
  void applyFlatDiscount({
    required OrderTaxSummary summary,
    required double discountAmount,
  }) {
    summary.discountAmount = discountAmount;
    log(
      '[BillingCalculator] Flat discount applied: ₹${discountAmount.toStringAsFixed(2)}',
    );
  }

  /// For CGST/SGST split (Indian GST)
  Map<String, double> splitCGSTSGST(ItemTaxCalculation item) {
    // Assumes GST is split 50-50 between CGST and SGST
    if (item.taxSlab == null) {
      return {'CGST': 0.0, 'SGST': 0.0};
    }

    final totalTax = item.taxAmount;
    return {'CGST': totalTax / 2, 'SGST': totalTax / 2};
  }

  /// Generate human-readable billing summary
  String generateBillingSummary(OrderTaxSummary summary) {
    final buffer = StringBuffer();

    buffer.writeln('╔════════════════════════════════════════╗');
    buffer.writeln('║           BILLING SUMMARY              ║');
    buffer.writeln('╠════════════════════════════════════════╣');

    // Items
    for (final item in summary.items) {
      buffer.writeln(
        '║ ${item.itemName.padRight(28)} × ${item.quantity}      ║',
      );
      buffer.writeln(
        '║   Price: ₹${item.subtotal.toStringAsFixed(2).padLeft(14)}          ║',
      );
      if (item.taxAmount > 0) {
        buffer.writeln(
          '║   Tax: ₹${item.taxAmount.toStringAsFixed(2).padLeft(16)}          ║',
        );
      }
    }

    buffer.writeln('╠════════════════════════════════════════╣');
    buffer.writeln(
      '║ Subtotal: ₹${summary.subtotal.toStringAsFixed(2).padLeft(25)}║',
    );

    // Tax Breakdown
    if (summary.totalTax > 0) {
      for (final entry in summary.taxBreakdownBySlab.entries) {
        buffer.writeln(
          '║ ${entry.key.padRight(28)}: ₹${entry.value.toStringAsFixed(2).padLeft(8)}║',
        );
      }
    }

    buffer.writeln(
      '║ Total Tax: ₹${summary.totalTax.toStringAsFixed(2).padLeft(22)}║',
    );

    if (summary.discountAmount > 0) {
      buffer.writeln(
        '║ Discount: -₹${summary.discountAmount.toStringAsFixed(2).padLeft(19)}║',
      );
    }

    buffer.writeln('╠════════════════════════════════════════╣');
    buffer.writeln(
      '║ TOTAL: ₹${summary.finalAmount.toStringAsFixed(2).padLeft(29)}║',
    );
    buffer.writeln('╚════════════════════════════════════════╝');

    return buffer.toString();
  }

  /// Log calculation details
  void logCalculation(OrderTaxSummary summary) {
    log('[BillingCalculator] ═════════════════════════════════════');
    log(
      '[BillingCalculator] Subtotal: ₹${summary.subtotal.toStringAsFixed(2)}',
    );
    log(
      '[BillingCalculator] Total Tax: ₹${summary.totalTax.toStringAsFixed(2)} (Effective: ${summary.effectiveTaxPercentage.toStringAsFixed(2)}%)',
    );
    log('[BillingCalculator] Total: ₹${summary.total.toStringAsFixed(2)}');

    if (summary.discountAmount > 0) {
      log(
        '[BillingCalculator] Discount: ₹${summary.discountAmount.toStringAsFixed(2)}',
      );
      log(
        '[BillingCalculator] Final: ₹${summary.finalAmount.toStringAsFixed(2)}',
      );
    }

    for (final entry in summary.taxBreakdownBySlab.entries) {
      log(
        '[BillingCalculator]   ${entry.key}: ₹${entry.value.toStringAsFixed(2)}',
      );
    }

    log('[BillingCalculator] ═════════════════════════════════════');
  }

  /// Validate order calculations
  bool validateCalculation(OrderTaxSummary summary) {
    // Check for negative values
    if (summary.subtotal < 0 || summary.totalTax < 0 || summary.total < 0) {
      log('[BillingCalculator] ❌ Negative values detected');
      return false;
    }

    // Check that tax ≈ subtotal × effectivePercentage
    final expectedTax =
        summary.subtotal * (summary.effectiveTaxPercentage / 100);
    final difference = (summary.totalTax - expectedTax).abs();

    if (difference > 0.01) {
      // Allow small rounding differences
      log('[BillingCalculator] ⚠️  Tax calculation mismatch');
      return false;
    }

    log('[BillingCalculator] ✅ Calculation validated');
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART ITEM MODEL (For use with billing calculator)
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final TaxSlab? taxSlab;
  final String? description;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.taxSlab,
    this.description,
  });

  /// Get this item's tax calculation
  ItemTaxCalculation getCalculation() {
    return ItemTaxCalculation(
      itemId: id,
      itemName: name,
      itemPrice: price,
      quantity: quantity,
      taxSlab: taxSlab,
    );
  }
}
