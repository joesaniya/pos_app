// lib/widgets/tax_dashboard_widget.dart
// ════════════════════════════════════════════════════════════════════════════════
//  TAX DASHBOARD WIDGETS
//
//  Display tax analytics:
//  - Tax collected (total, daily, monthly)
//  - Tax breakdown (by type, by slab)
//  - Tax trends and comparisons
//  - Revenue analysis
// ════════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class TaxSummaryCard extends StatelessWidget {
  final double totalTaxCollected;
  final double averageTaxPerOrder;
  final int totalOrders;
  final double taxPercentage; // tax as % of revenue

  const TaxSummaryCard({
    super.key,
    required this.totalTaxCollected,
    required this.averageTaxPerOrder,
    required this.totalOrders,
    required this.taxPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tax Collection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${taxPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn(
                  'Total Tax',
                  '₹${totalTaxCollected.toStringAsFixed(2)}',
                  Colors.green,
                ),
                _buildStatColumn(
                  'Per Order',
                  '₹${averageTaxPerOrder.toStringAsFixed(2)}',
                  Colors.blue,
                ),
                _buildStatColumn(
                  'Orders',
                  totalOrders.toString(),
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX BREAKDOWN CARD (by type or slab)
// ─────────────────────────────────────────────────────────────────────────────

class TaxBreakdownCard extends StatelessWidget {
  final Map<String, double> taxBreakdown;
  final String title;
  final bool showPercentage;

  const TaxBreakdownCard({
    super.key,
    required this.taxBreakdown,
    required this.title,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (taxBreakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'No tax data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = taxBreakdown.values.reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...taxBreakdown.entries.map((entry) {
              final percentage = showPercentage
                  ? (entry.value / (total > 0 ? total : 1)) * 100
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (showPercentage) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getColorForPercentage(percentage),
                          ),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage > 50) return Colors.red;
    if (percentage > 25) return Colors.orange;
    return Colors.green;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX COMPARISON CARD (Period vs Period)
// ─────────────────────────────────────────────────────────────────────────────

class TaxComparisonCard extends StatelessWidget {
  final double taxAmountDifference;
  final double taxGrowthPercentage;
  final int ordersDifference;
  final double ordersGrowthPercentage;
  final String period1Label;
  final String period2Label;

  const TaxComparisonCard({
    super.key,
    required this.taxAmountDifference,
    required this.taxGrowthPercentage,
    required this.ordersDifference,
    required this.ordersGrowthPercentage,
    required this.period1Label,
    required this.period2Label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comparison',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '$period1Label vs $period2Label',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildComparisonRow(
              label: 'Tax Amount',
              value: '₹${taxAmountDifference.abs().toStringAsFixed(2)}',
              growth: taxGrowthPercentage,
              isPositive: taxAmountDifference >= 0,
            ),
            const SizedBox(height: 12),
            _buildComparisonRow(
              label: 'Orders Count',
              value: ordersDifference.abs().toString(),
              growth: ordersGrowthPercentage,
              isPositive: ordersDifference >= 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String value,
    required double growth,
    required bool isPositive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isPositive ? Colors.green : Colors.red).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 12,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX LOADING SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class TaxDashboardSkeleton extends StatelessWidget {
  const TaxDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  height: 20,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 60,
                      width: 80,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    Container(
                      height: 60,
                      width: 80,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    Container(
                      height: 60,
                      width: 80,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
