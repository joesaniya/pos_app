// lib/widgets/price_with_tax_display.dart
// ══════════════════════════════════════════════════════════════════════════════
//  PRICE WITH TAX DISPLAY WIDGETS
//
//  Reusable widgets for displaying prices with tax information throughout the app
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/services/tax_calculation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SIMPLE PRICE DISPLAY WITH TAX
// ─────────────────────────────────────────────────────────────────────────────

class PriceWithTax extends StatelessWidget {
  final double basePrice;
  final TaxSlab? taxSlab;
  final int quantity;
  final TextStyle? priceStyle;
  final TextStyle? taxStyle;
  final bool showTaxInfo;
  final bool strikethrough;
  final MainAxisAlignment mainAxisAlignment;

  const PriceWithTax({
    super.key,
    required this.basePrice,
    this.taxSlab,
    this.quantity = 1,
    this.priceStyle,
    this.taxStyle,
    this.showTaxInfo = true,
    this.strikethrough = true,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final taxService = TaxCalculationService.instance;
    final result = taxService.calculateItemTax(
      itemPrice: basePrice,
      quantity: quantity,
      taxSlab: taxSlab,
    );

    final displayPrice = result.finalPrice;
    final showBasePriceStrikethrough = strikethrough && taxSlab != null;

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBasePriceStrikethrough)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '₹${(basePrice * quantity).toStringAsFixed(2)}',
              style: (taxStyle ?? const TextStyle()).copyWith(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        Text(
          '₹${displayPrice.toStringAsFixed(2)}',
          style:
              priceStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
        ),
        if (showTaxInfo && taxSlab != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                taxSlab!.name,
                style: (taxStyle ?? const TextStyle()).copyWith(
                  fontSize: 10,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAILED PRICE BREAKDOWN CARD
// ─────────────────────────────────────────────────────────────────────────────

class PriceBreakdownCard extends StatelessWidget {
  final double basePrice;
  final TaxSlab? taxSlab;
  final int quantity;
  final double? discountAmount;
  final String title;
  final bool expanded;

  const PriceBreakdownCard({
    super.key,
    required this.basePrice,
    this.taxSlab,
    this.quantity = 1,
    this.discountAmount,
    required this.title,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final taxService = TaxCalculationService.instance;
    final result = taxService.calculateItemTax(
      itemPrice: basePrice,
      quantity: quantity,
      taxSlab: taxSlab,
    );

    final subtotal = basePrice * quantity;
    final taxAmount = result.taxAmount;
    final finalPrice = result.finalPrice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            _buildRow('Base Price (×$quantity):', subtotal),
            if (discountAmount != null && discountAmount! > 0)
              _buildRow('Discount:', -discountAmount!, color: Colors.green),
            if (taxAmount > 0)
              _buildRow(
                'Tax (${taxSlab?.percentage}% ${taxSlab?.type.displayName}):',
                taxAmount,
                color: Colors.blue,
              ),
            const Divider(height: 16),
            _buildRow(
              'Final Total:',
              finalPrice + (discountAmount ?? 0),
              isFinal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    bool isFinal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isFinal ? 13 : 12,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            '₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isFinal ? 13 : 12,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
              color: amount < 0 ? Colors.green : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MINIMAL PRICE DISPLAY (for menu items, cart items)
// ─────────────────────────────────────────────────────────────────────────────

class MinimalPriceDisplay extends StatelessWidget {
  final double basePrice;
  final TaxSlab? taxSlab;
  final TextStyle? style;

  const MinimalPriceDisplay({
    super.key,
    required this.basePrice,
    this.taxSlab,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final taxService = TaxCalculationService.instance;
    final finalPrice = taxService.getMenuItemFinalPrice(
      basePrice: basePrice,
      taxSlab: taxSlab,
    );

    return Text(
      '₹${finalPrice.toStringAsFixed(2)}',
      style:
          style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BILLING SUMMARY DISPLAY (for final bill/receipt)
// ─────────────────────────────────────────────────────────────────────────────

class BillingSummaryDisplay extends StatelessWidget {
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double roundOffAmount;
  final double grandTotal;
  final String? taxBreakdownLabel;

  const BillingSummaryDisplay({
    super.key,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.tipAmount,
    required this.roundOffAmount,
    required this.grandTotal,
    this.taxBreakdownLabel = 'Tax',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Subtotal', subtotal),
            if (taxAmount > 0)
              _buildSummaryRow(
                taxBreakdownLabel ?? 'Tax',
                taxAmount,
                highlight: true,
              ),
            if (discountAmount > 0)
              _buildSummaryRow(
                'Discount',
                -discountAmount,
                color: Colors.green,
              ),
            if (tipAmount > 0) _buildSummaryRow('Tip', tipAmount),
            if (roundOffAmount != 0)
              _buildSummaryRow('Round Off', roundOffAmount, fontSize: 11),
            const Divider(height: 16),
            _buildSummaryRow('Total Due', grandTotal, isFinal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool highlight = false,
    bool isFinal = false,
    Color? color,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isFinal ? 14 : fontSize,
              fontWeight: isFinal
                  ? FontWeight.bold
                  : highlight
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: highlight ? Colors.blue : color,
            ),
          ),
          Text(
            '₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isFinal ? 14 : fontSize,
              fontWeight: isFinal
                  ? FontWeight.bold
                  : highlight
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: amount < 0
                  ? Colors.green
                  : highlight
                  ? Colors.blue
                  : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK PRICE TOOLTIP (hover/tap to see breakdown)
// ─────────────────────────────────────────────────────────────────────────────

class PriceTooltip extends StatelessWidget {
  final double basePrice;
  final TaxSlab? taxSlab;
  final int quantity;
  final Widget child;

  const PriceTooltip({
    super.key,
    required this.basePrice,
    required this.child,
    this.taxSlab,
    this.quantity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final taxService = TaxCalculationService.instance;
    final result = taxService.calculateItemTax(
      itemPrice: basePrice,
      quantity: quantity,
      taxSlab: taxSlab,
    );

    final tooltip = taxSlab == null
        ? '₹${(basePrice * quantity).toStringAsFixed(2)}'
        : 'Base: ₹${(basePrice * quantity).toStringAsFixed(2)}\n'
              'Tax: ₹${result.taxAmount.toStringAsFixed(2)} (${taxSlab!.percentage}%)\n'
              'Total: ₹${result.finalPrice.toStringAsFixed(2)}';

    return Tooltip(message: tooltip, child: child);
  }
}
