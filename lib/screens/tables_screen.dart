import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TablesProvider(),
      child: const _TablesView(),
    );
  }
}

class _TablesView extends StatelessWidget {
  const _TablesView();

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TableHeader(),
            const _StatusSummaryRow(),
            const _FilterChipBar(),
            Expanded(
              child: Consumer<TablesProvider>(
                builder: (context, provider, _) {
                  final tables = provider.filteredTables;
                  return GridView.builder(
                    padding: EdgeInsets.all(AppSizes.paddingLarge),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSizes.paddingMedium,
                      mainAxisSpacing: AppSizes.paddingMedium,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      return _TableCard(table: tables[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            ),
            child: const Icon(Icons.table_restaurant, color: AppColors.white, size: 28),
          ),
          SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tables',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, 24),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your restaurant tables',
                  style: AppTheme.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryRow extends StatelessWidget {
  const _StatusSummaryRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<TablesProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: EdgeInsets.all(AppSizes.paddingLarge),
          padding: EdgeInsets.all(AppSizes.paddingMedium),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatusItem(
                label: 'Available',
                count: provider.availableCount,
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
              Container(height: 50, width: 1, color: AppColors.borderLight),
              _StatusItem(
                label: 'Occupied',
                count: provider.occupiedCount,
                color: AppColors.warning,
                icon: Icons.people_outline,
              ),
              Container(height: 50, width: 1, color: AppColors.borderLight),
              _StatusItem(
                label: 'Reserved',
                count: provider.reservedCount,
                color: AppColors.info,
                icon: Icons.event_outlined,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: AppTheme.headlineLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<TablesProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 50,
          margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
            itemCount: provider.filters.length,
            itemBuilder: (context, index) {
              final filter = provider.filters[index];
              final isSelected = provider.selectedFilter == filter;
              return Padding(
                padding: EdgeInsets.only(right: AppSizes.paddingSmall),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => provider.setFilter(filter),
                  backgroundColor: AppColors.white,
                  selectedColor: AppColors.primaryPurple.withOpacity(0.15),
                  labelStyle: AppTheme.labelMedium.copyWith(
                    color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryPurple : AppColors.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingMedium,
                    vertical: AppSizes.paddingSmall,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  TABLE CARD — overflow fixed
// ─────────────────────────────────────────
class _TableCard extends StatelessWidget {
  final TableModel table;
  const _TableCard({required this.table});

  Color get _statusColor {
    switch (table.status) {
      case TableStatus.available: return AppColors.success;
      case TableStatus.occupied: return AppColors.warning;
      case TableStatus.reserved: return AppColors.info;
    }
  }

  IconData get _statusIcon {
    switch (table.status) {
      case TableStatus.available: return Icons.check_circle;
      case TableStatus.occupied: return Icons.people;
      case TableStatus.reserved: return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailsSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          border: Border.all(color: _statusColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header strip ──────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingMedium,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.borderRadiusLarge - 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_restaurant, color: _statusColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'T${table.tableNumber}',
                        style: AppTheme.headlineSmall.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 9, color: AppColors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${table.capacity}',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body — FIXED: Expanded + FittedBox to prevent overflow ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.paddingSmall),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon, color: _statusColor, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      table.statusLabel,
                      style: AppTheme.headlineSmall.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (table.status == TableStatus.occupied) ...[
                      const SizedBox(height: 4),
                      Text(
                        table.customerName ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${table.orderTotal?.toStringAsFixed(0)}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 10, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            table.formattedDuration,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ] else if (table.status == TableStatus.reserved) ...[
                      const SizedBox(height: 4),
                      Text(
                        table.customerName ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        table.formattedReservation,
                        style: AppTheme.labelSmall.copyWith(
                          color: AppColors.info,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TableDetailsSheet(table: table),
    );
  }
}

// ─────────────────────────────────────────
//  TABLE DETAILS BOTTOM SHEET
// ─────────────────────────────────────────
class _TableDetailsSheet extends StatelessWidget {
  final TableModel table;
  const _TableDetailsSheet({required this.table});

  Color get _statusColor {
    switch (table.status) {
      case TableStatus.available: return AppColors.success;
      case TableStatus.occupied: return AppColors.warning;
      case TableStatus.reserved: return AppColors.info;
    }
  }

  IconData get _statusIcon {
    switch (table.status) {
      case TableStatus.available: return Icons.check_circle;
      case TableStatus.occupied: return Icons.people;
      case TableStatus.reserved: return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.borderRadiusXLarge),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingLarge,
        AppSizes.paddingLarge,
        AppSizes.paddingLarge,
        AppSizes.paddingLarge + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
                    ),
                    child: Icon(Icons.table_restaurant, color: _statusColor, size: 24),
                  ),
                  SizedBox(width: AppSizes.paddingMedium),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Table ${table.tableNumber}', style: AppTheme.headlineMedium),
                      Text(
                        'Capacity: ${table.capacity} · ${table.section ?? ""}',
                        style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lightNeutral200,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.paddingLarge),
          // Status badge
          Container(
            padding: EdgeInsets.all(AppSizes.paddingMedium),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor),
                const SizedBox(width: 12),
                Text(
                  table.statusLabel,
                  style: AppTheme.headlineSmall.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (table.status == TableStatus.occupied) ...[
            SizedBox(height: AppSizes.paddingLarge),
            _InfoRow(label: 'Customer', value: table.customerName ?? ''),
            _InfoRow(label: 'Order ID', value: table.orderId ?? ''),
            _InfoRow(label: 'Total Amount', value: '₹${table.orderTotal?.toStringAsFixed(0)}'),
            _InfoRow(label: 'Duration', value: table.formattedDuration),
          ] else if (table.status == TableStatus.reserved) ...[
            SizedBox(height: AppSizes.paddingLarge),
            _InfoRow(label: 'Customer', value: table.customerName ?? ''),
            _InfoRow(label: 'Reserved For', value: table.formattedReservation),
          ],
          SizedBox(height: AppSizes.paddingLarge),
          // Action buttons
          Consumer<TablesProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  if (table.status == TableStatus.available)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Assign Table'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          provider.clearTable(table.tableNumber);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Clear Table'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (table.status == TableStatus.occupied) ...[
                      SizedBox(width: AppSizes.paddingSmall),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.receipt, size: 18),
                          label: const Text('View Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}