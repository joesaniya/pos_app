import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/filter_chip_widget.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<OrdersProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                GradientHeader(
                  title: 'Orders',
                  subtitle: '${provider.orders.length} total orders',
                  actionIcon: Icons.add,
                  bottomWidget: FilterChipRow(
                    items: const ['All', 'Pending', 'Preparing', 'Served'],
                    selectedItem: provider.selectedFilter,
                    onItemSelected: (filter) =>
                        provider.setSelectedFilter(filter),
                  ),
                ),
                Expanded(
                  child: provider.filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(size.width * 0.04),
                          physics: const BouncingScrollPhysics(),
                          itemCount: provider.filteredOrders.length,
                          itemBuilder: (context, index) =>
                              OrderCard(order: provider.filteredOrders[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: AppSizes.paddingMedium),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({Key? key, required this.order}) : super(key: key);

  Color _getStatusColor() {
    switch (order.status) {
      case 'preparing':
        return AppColors.warning;
      case 'served':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: AppSizes.iconSizeMedium,
                ),
              ),
              const SizedBox(width: AppSizes.paddingSmall * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getFontSize(context, 16),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order.table} • ${order.items} items',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
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
                    '\$${order.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getFontSize(context, 16),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.time,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingSmall * 1.5),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingSmall * 1.5,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusSmall),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              _ActionButton(
                icon: Icons.visibility,
                color: AppColors.info,
                onTap: () {},
              ),
              const SizedBox(width: AppSizes.paddingSmall),
              _ActionButton(
                icon: Icons.check,
                color: AppColors.success,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingSmall),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: AppSizes.iconSizeSmall),
      ),
    );
  }
}