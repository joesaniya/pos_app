// lib/widgets/tax_breakdown_widget.dart
// ════════════════════════════════════════════════════════════════════════════════
//  TAX BREAKDOWN WIDGET — Display Tax Information in Orders
//
//  Provides:
//  - TaxBreakdownWidget (compact + expanded modes)
//  - TaxSummaryCard (for dashboard)
//  - Ready to integrate into bills and invoices
// ════════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/services/order_tax_service.dart';
import 'package:pos_app/services/tax_calculation_helper.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TAX BREAKDOWN WIDGET
/// ─────────────────────────────────────────────────────────────────────────────

class TaxBreakdownWidget extends StatefulWidget {
  final OrderTaxSummary taxSummary;
  final double subtotal;
  final double discountAmount;
  final double tipAmount;
  final double roundOff;
  final bool expanded;
  final Color? taxColor;

  const TaxBreakdownWidget({
    Key? key,
    required this.taxSummary,
    required this.subtotal,
    this.discountAmount = 0,
    this.tipAmount = 0,
    this.roundOff = 0,
    this.expanded = false,
    this.taxColor,
  }) : super(key: key);

  @override
  State<TaxBreakdownWidget> createState() => _TaxBreakdownWidgetState();
}

class _TaxBreakdownWidgetState extends State<TaxBreakdownWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.taxSummary.totalTaxAmount == 0) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: (widget.taxColor ?? Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse
            _buildHeader(),
            if (_isExpanded) ...[const SizedBox(height: 12), _buildDetails()],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt,
                size: 18,
                color: widget.taxColor ?? Colors.orange,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax Breakdown',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.taxColor ?? Colors.orange,
                    ),
                  ),
                  Text(
                    'Effective Rate: ${formatPercentage(widget.taxSummary.effectiveTaxRate)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(
                formatCurrency(widget.taxSummary.totalTaxAmount),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.taxColor ?? Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 8),
        // Individual tax items
        ...widget.taxSummary.taxByName.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  formatCurrency(entry.value),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey[300]),
        // Summary rows
        if (widget.discountAmount != 0) ...[
          _buildSummaryRow(
            'Discount',
            -widget.discountAmount,
            Colors.green,
            context,
          ),
        ],
        if (widget.tipAmount != 0) ...[
          _buildSummaryRow('Tip', widget.tipAmount, Colors.blue, context),
        ],
        if (widget.roundOff != 0) ...[
          _buildSummaryRow('Round Off', widget.roundOff, Colors.grey, context),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    Color color,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            formatCurrency(amount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// TAX SUMMARY CARD (For Dashboard)
/// ─────────────────────────────────────────────────────────────────────────────

class TaxSummaryCard extends StatelessWidget {
  final String title;
  final double taxAmount;
  final double totalRevenue;
  final int orderCount;
  final Map<String, double> taxBreakdown;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const TaxSummaryCard({
    Key? key,
    required this.title,
    required this.taxAmount,
    required this.totalRevenue,
    required this.orderCount,
    this.taxBreakdown = const {},
    this.backgroundColor,
    this.textColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final taxPercentage = totalRevenue > 0
        ? (taxAmount / totalRevenue) * 100
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: backgroundColor ?? Colors.orange[50],
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(taxAmount),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor ?? Colors.orange[700],
                          ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.receipt,
                    color: Colors.orange[700],
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(context, 'Orders', orderCount.toString()),
                _buildStat(
                  context,
                  'Avg Tax',
                  formatCurrency(orderCount > 0 ? taxAmount / orderCount : 0),
                ),
                _buildStat(context, 'Rate', formatPercentage(taxPercentage)),
              ],
            ),
            if (taxBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildBreakdownPreview(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownPreview(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          ...taxBreakdown.entries
              .take(3)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        formatCurrency(entry.value),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (taxBreakdown.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${taxBreakdown.length - 3} more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// COMPACT TAX DISPLAY (For lists)
/// ─────────────────────────────────────────────────────────────────────────────

class CompactTaxDisplay extends StatelessWidget {
  final OrderTaxSummary taxSummary;
  final Color? color;
  final TextStyle? style;

  const CompactTaxDisplay({
    Key? key,
    required this.taxSummary,
    this.color,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (taxSummary.totalTaxAmount == 0) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: (color ?? Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        'Tax: ${formatCurrency(taxSummary.totalTaxAmount)} (${formatPercentage(taxSummary.effectiveTaxRate)})',
        style:
            style ??
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? Colors.orange[700],
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
