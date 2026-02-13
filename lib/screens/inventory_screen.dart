import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<InventoryProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                GradientHeader(
                  title: 'Inventory',
                  subtitle: '${provider.totalItemsCount} items',
                  actionIcon: Icons.add,
                  bottomWidget: _buildInventoryStats(provider),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(size.width * 0.04),
                    physics: const BouncingScrollPhysics(),
                    itemCount: provider.inventoryItems.length,
                    itemBuilder: (context, index) =>
                        InventoryItemCard(item: provider.inventoryItems[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInventoryStats(InventoryProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _InventoryStatCard(
            title: 'Total Items',
            value: provider.totalItemsCount.toString(),
            icon: Icons.inventory_2,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSizes.paddingSmall * 1.5),
        Expanded(
          child: _InventoryStatCard(
            title: 'Low Stock',
            value: provider.lowStockCount.toString(),
            icon: Icons.warning,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSizes.paddingSmall * 1.5),
        Expanded(
          child: _InventoryStatCard(
            title: 'Critical',
            value: provider.criticalStockCount.toString(),
            icon: Icons.error,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InventoryStatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.paddingSmall * 1.5,
        horizontal: AppSizes.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const InventoryItemCard({Key? key, required this.item}) : super(key: key);

  Color _getStatusColor() {
    switch (item.status) {
      case 'good':
        return AppColors.success;
      case 'low':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  String _getStatusText() {
    switch (item.status) {
      case 'good':
        return 'Good Stock';
      case 'low':
        return 'Low Stock';
      default:
        return 'Critical';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final statusText = _getStatusText();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall * 1.5),
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
              ),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory,
              color: Colors.white,
              size: AppSizes.iconSizeMedium,
            ),
          ),
          const SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getFontSize(context, 16),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.lastUpdated,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getFontSize(context, 16),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingSmall,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}