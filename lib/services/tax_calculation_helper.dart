// lib/services/tax_calculation_helper.dart
// ════════════════════════════════════════════════════════════════════════════════
//  TAX CALCULATION HELPER — Formatting, Validation & Utility Functions
//
//  Provides:
//  - Currency formatting with symbols
//  - Percentage formatting
//  - Tax calculation extensions
//  - Validation utilities
//  - Breakdown string generation
// ════════════════════════════════════════════════════════════════════════════════

import 'package:pos_app/services/order_tax_service.dart';
import 'package:pos_app/models/tax_slab_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FORMATTING UTILITIES
/// ─────────────────────────────────────────────────────────────────────────────

/// Format amount as currency with rupee symbol
String formatCurrency(double amount, {String symbol = '₹', int decimals = 2}) {
  if (amount.isNaN || amount.isInfinite) return '${symbol}0.00';
  return '$symbol${amount.toStringAsFixed(decimals)}';
}

/// Format percentage with consistent decimal places
String formatPercentage(double value, {int decimals = 2}) {
  if (value.isNaN || value.isInfinite) return '0.00%';
  return '${value.toStringAsFixed(decimals)}%';
}

/// Format tax name with percentage
String formatTaxDisplay(String taxName, double percentage) {
  return '$taxName (${formatPercentage(percentage)})';
}

/// Format as "Base Amount + Tax Amount = Total"
String formatTaxLine(double baseAmount, double taxAmount, double total) {
  return '${formatCurrency(baseAmount)} + ${formatCurrency(taxAmount)} = ${formatCurrency(total)}';
}

/// ─────────────────────────────────────────────────────────────────────────────
/// BREAKDOWN FORMATTING
/// ─────────────────────────────────────────────────────────────────────────────

/// Create compact tax breakdown summary (single line or short)
String createCompactTaxBreakdown(OrderTaxSummary summary) {
  if (summary.totalTaxAmount == 0) {
    return 'No tax applicable';
  }

  final items = <String>[];
  summary.taxByName.forEach((name, amount) {
    items.add('$name: ${formatCurrency(amount)}');
  });

  return items.join(', ');
}

/// Create detailed breakdown for invoice/bill
String createDetailedTaxBreakdown(
  OrderTaxSummary summary, {
  int lineWidth = 60,
}) {
  if (summary.totalTaxAmount == 0) {
    return 'No tax applicable';
  }

  final lines = <String>[];
  lines.add('─' * lineWidth);
  lines.add('TAX BREAKDOWN');
  lines.add('─' * lineWidth);

  // Tax by name
  summary.taxByName.forEach((name, amount) {
    final percentage = _findPercentageForTax(name, summary);
    final line = '$name (${formatPercentage(percentage)})'.padRight(
      lineWidth - 15,
    );
    lines.add('$line${formatCurrency(amount).padLeft(15)}');
  });

  lines.add('─' * lineWidth);
  final totalLine = 'Total Tax'.padRight(lineWidth - 15);
  lines.add('$totalLine${formatCurrency(summary.totalTaxAmount).padLeft(15)}');
  lines.add('─' * lineWidth);

  return lines.join('\n');
}

/// Create full bill summary with tax
String createTaxBreakdownSummary(
  double subtotal,
  OrderTaxSummary summary, {
  double discountAmount = 0,
  double tipAmount = 0,
  double roundOff = 0,
}) {
  final lines = <String>[];
  lines.add('');
  lines.add('Subtotal           ${formatCurrency(subtotal).padLeft(12)}');

  if (discountAmount != 0) {
    lines.add(
      'Discount           -${formatCurrency(discountAmount).padLeft(11)}',
    );
  }

  if (summary.totalTaxAmount != 0) {
    summary.taxByName.forEach((name, amount) {
      final shortName = name.replaceAll(' ', '').substring(0, 15);
      lines.add('$shortName         ${formatCurrency(amount).padLeft(12)}');
    });
  }

  if (tipAmount != 0) {
    lines.add('Tip                ${formatCurrency(tipAmount).padLeft(12)}');
  }

  if (roundOff != 0) {
    lines.add('Round Off          ${formatCurrency(roundOff).padLeft(12)}');
  }

  lines.add('─' * 35);
  final total =
      subtotal + summary.totalTaxAmount - discountAmount + tipAmount + roundOff;
  lines.add('TOTAL              ${formatCurrency(total).padLeft(12)}');
  lines.add('');

  return lines.join('\n');
}

/// ─────────────────────────────────────────────────────────────────────────────
/// VALIDATION UTILITIES
/// ─────────────────────────────────────────────────────────────────────────────

/// Validate that calculations are accurate
bool validateTaxCalculation(
  double subtotal,
  OrderTaxSummary summary, {
  double tolerance = 0.01,
}) {
  final calculatedTotal = subtotal + summary.totalTaxAmount;
  final difference = (calculatedTotal - summary.grandTotal).abs();
  return difference <= tolerance;
}

/// Check if tax amount is reasonable (not more than 50% of item price)
bool isReasonableTaxAmount(double baseAmount, double taxAmount) {
  if (baseAmount == 0) return taxAmount == 0;
  final taxRate = (taxAmount / baseAmount) * 100;
  return taxRate <= 50 && taxRate >= 0;
}

/// Validate tax percentage is in reasonable range
bool isValidTaxPercentage(double percentage) {
  return percentage >= 0 && percentage <= 50;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// CALCULATION EXTENSIONS
/// ─────────────────────────────────────────────────────────────────────────────

extension TaxCalculations on double {
  /// Calculate tax amount on this value
  /// Example: 100.calculateTax(18) returns 18
  double calculateTax(double taxPercentage) {
    return this * (taxPercentage / 100);
  }

  /// Apply exclusive tax (adds tax on top)
  /// Example: 100.applyExclusiveTax(18) returns 118
  double applyExclusiveTax(double taxPercentage) {
    return this + calculateTax(taxPercentage);
  }

  /// Extract tax from inclusive price
  /// Example: 118.extractInclusiveTax(18) returns 18
  double extractInclusiveTax(double taxPercentage) {
    final multiplier = 1 + (taxPercentage / 100);
    return this - (this / multiplier);
  }

  /// Get base amount from inclusive price
  /// Example: 118.getBaseFromInclusive(18) returns 100
  double getBaseFromInclusive(double taxPercentage) {
    final multiplier = 1 + (taxPercentage / 100);
    return this / multiplier;
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// HELPER FUNCTIONS
/// ─────────────────────────────────────────────────────────────────────────────

/// Find percentage for a tax name from summary
double _findPercentageForTax(String taxName, OrderTaxSummary summary) {
  // Try to extract from tax name (e.g., "GST 18%" -> 18)
  final regExp = RegExp(r'(\d+\.?\d*)');
  final match = regExp.firstMatch(taxName);
  if (match != null) {
    return double.tryParse(match.group(1)!) ?? 0;
  }
  return 0;
}

/// Round to 2 decimal places (standard currency)
double roundToNearest(double value) {
  return double.parse(value.toStringAsFixed(2));
}

/// Get effective tax rate as percentage
double getEffectiveTaxRate(double subtotal, double totalTax) {
  if (subtotal == 0) return 0;
  return (totalTax / subtotal) * 100;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// TAX TYPE UTILITIES
/// ─────────────────────────────────────────────────────────────────────────────

/// Get display name for tax type
String getTaxTypeDisplay(TaxType taxType) {
  switch (taxType) {
    case TaxType.exclusive:
      return 'Exclusive (Added on top)';
    case TaxType.inclusive:
      return 'Inclusive (Included in price)';
    case TaxType.none:
      return 'No Tax';
  }
}

/// Get short name for tax type
String getTaxTypeShort(TaxType taxType) {
  switch (taxType) {
    case TaxType.exclusive:
      return 'EXC';
    case TaxType.inclusive:
      return 'INC';
    case TaxType.none:
      return 'NONE';
  }
}
