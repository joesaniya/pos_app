import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/providers/tax_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SELECTOR WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable tax selector dropdown widget for menu item editing
class TaxSelectorDropdown extends StatelessWidget {
  final String? selectedTaxSlabId;
  final Function(String? taxSlabId) onTaxSelected;
  final bool includeNoTax;
  final String label;
  final bool required;

  const TaxSelectorDropdown({
    Key? key,
    required this.selectedTaxSlabId,
    required this.onTaxSelected,
    this.includeNoTax = true,
    this.label = 'Select Tax',
    this.required = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxProvider>(
      builder: (context, provider, _) {
        List<TaxSlab> taxes = [...provider.activeTaxSlabs];

        return DropdownButtonFormField<String?>(
          value: selectedTaxSlabId,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.receipt),
          ),
          hint: Text(label),
          items: [
            if (includeNoTax)
              const DropdownMenuItem(value: null, child: Text('No Tax')),
            ...taxes.map((tax) {
              return DropdownMenuItem(
                value: tax.id,
                child: Row(
                  children: [
                    Text(tax.name),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tax.type == TaxType.inclusive
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tax.percentage}% (${tax.type.displayName})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (value) => onTaxSelected(value),
          validator: required
              ? (value) {
                  if (value == null) {
                    return 'Please select a tax';
                  }
                  return null;
                }
              : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX DISPLAY CARD
// ─────────────────────────────────────────────────────────────────────────────

/// Display tax information for an item
class TaxDisplayCard extends StatelessWidget {
  final TaxSlab? taxSlab;
  final double itemPrice;
  final int quantity;

  const TaxDisplayCard({
    Key? key,
    required this.taxSlab,
    required this.itemPrice,
    this.quantity = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (taxSlab == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Text(
          'No tax applied to this item',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final calculation = TaxCalculation(taxSlab: taxSlab!, itemPrice: itemPrice);

    final totalPrice = (calculation.finalPrice * quantity).toStringAsFixed(2);
    final totalTax = (calculation.taxAmount * quantity).toStringAsFixed(2);
    final subtotal = (calculation.subtotal * quantity).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                taxSlab!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: taxSlab!.type == TaxType.inclusive
                      ? Colors.purple.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  taxSlab!.type.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: taxSlab!.type == TaxType.inclusive
                        ? Colors.purple
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal (${quantity}×):',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '₹$subtotal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax (${taxSlab!.percentage}%):',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '+ ₹$totalTax',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '₹$totalPrice',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX BREAKDOWN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Shows detailed tax breakdown for cart/order
class TaxBreakdownWidget extends StatelessWidget {
  final double subtotal;
  final double totalTax;
  final Map<String, double> taxBreakdown;
  final double discountAmount;

  const TaxBreakdownWidget({
    Key? key,
    required this.subtotal,
    required this.totalTax,
    required this.taxBreakdown,
    this.discountAmount = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = subtotal + totalTax;
    final finalAmount = total - discountAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', subtotal),
          const SizedBox(height: 8),
          if (taxBreakdown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tax Details:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...taxBreakdown.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildSummaryRow(
                        '  ${entry.key}',
                        entry.value,
                        color: Colors.blue,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          _buildSummaryRow('Total Tax', totalTax, isBold: true),
          if (discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Discount', -discountAmount, color: Colors.orange),
          ],
          const Divider(height: 16),
          _buildSummaryRow(
            'Total Amount',
            finalAmount,
            isBold: true,
            color: Colors.green,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SUMMARY TILE
// ─────────────────────────────────────────────────────────────────────────────

/// Compact tax summary tile for list views
class TaxSummaryTile extends StatelessWidget {
  final String? taxSlabId;
  final double amount;
  final String? taxSlabName;
  final double? taxPercentage;

  const TaxSummaryTile({
    Key? key,
    required this.taxSlabId,
    required this.amount,
    this.taxSlabName,
    this.taxPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (taxSlabId == null) {
      return const Chip(label: Text('No Tax'), backgroundColor: Colors.grey);
    }

    return Chip(
      avatar: const Icon(Icons.receipt, size: 16),
      label: Text(
        '${taxSlabName ?? "Tax"} (${taxPercentage?.toStringAsFixed(1) ?? "0"}%)',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: Colors.blue.withOpacity(0.2),
    );
  }
}
