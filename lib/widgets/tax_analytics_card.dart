// lib/widgets/tax_analytics_card.dart
// ════════════════════════════════════════════════════════════════════════════════
//  TAX ANALYTICS CARD — Dashboard Integration
//
//  Displays:
//  - Total tax collected
//  - Tax metrics and breakdown
//  - Trend indicators
// ════════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/services/order_tax_service.dart';
import 'package:pos_app/services/tax_analytics_service.dart';
import 'package:pos_app/services/tax_calculation_helper.dart';

class TaxAnalyticsCard extends StatefulWidget {
  final String businessId;
  final bool isLoading;

  const TaxAnalyticsCard({
    super.key,
    required this.businessId,
    this.isLoading = false,
  });

  @override
  State<TaxAnalyticsCard> createState() => _TaxAnalyticsCardState();
}

class _TaxAnalyticsCardState extends State<TaxAnalyticsCard> {
  late Future<TaxDashboardData> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    _analyticsFuture = TaxAnalyticsService.instance.getMonthAnalytics(
      widget.businessId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaxDashboardData>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (widget.isLoading ||
            snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        final analytics = snapshot.data;
        if (analytics == null) {
          return _buildEmptyState();
        }

        return _buildAnalyticsCard(analytics);
      },
    );
  }

  Widget _buildAnalyticsCard(TaxDashboardData analytics) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.95),
            Colors.deepOrange.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Month',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main metric: Total Tax Collected
          Text(
            formatCurrency(analytics.totalTaxCollected),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Total Tax Collected',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),

          // Metrics Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildMetricBox(
                context,
                analytics.totalOrders.toString(),
                'Orders',
                Colors.white.withValues(alpha: 0.9),
              ),
              _buildMetricBox(
                context,
                formatCurrency(analytics.averageTaxPerOrder),
                'Per Order',
                Colors.white.withValues(alpha: 0.9),
              ),
              _buildMetricBox(
                context,
                analytics.topTaxSlabs.isNotEmpty
                    ? analytics.topTaxSlabs.first.taxSlabName.length > 12
                          ? analytics.topTaxSlabs.first.taxSlabName.substring(
                                  0,
                                  12,
                                ) +
                                '...'
                          : analytics.topTaxSlabs.first.taxSlabName
                    : 'N/A',
                'Top Tax',
                Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tax Breakdown
          if (analytics.topTaxSlabs.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Breakdown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...analytics.topTaxSlabs
                      .take(3)
                      .map(
                        (slab) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                slab.taxSlabName,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                              ),
                              Text(
                                formatCurrency(slab.totalTaxCollected),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (analytics.topTaxSlabs.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${analytics.topTaxSlabs.length - 3} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBox(
    BuildContext context,
    String value,
    String label,
    Color bgColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      height: 300,
      child: const Column(
        children: [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading tax analytics...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(height: 8),
          Text(
            'Error loading tax analytics',
            style: TextStyle(color: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.receipt_long, color: Colors.orange[700], size: 32),
          const SizedBox(height: 12),
          Text(
            'No tax data available',
            style: TextStyle(color: Colors.orange[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tax will appear here once orders are created',
            style: TextStyle(color: Colors.orange[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
