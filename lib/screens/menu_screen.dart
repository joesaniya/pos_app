import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/filter_chip_widget.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/menu_provider.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<MenuProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                GradientHeader(
                  title: 'Menu',
                  subtitle: '${provider.menuItems.length} items',
                  actionIcon: Icons.search,
                  bottomWidget: FilterChipRow(
                    items: const [
                      'All',
                      'Appetizers',
                      'Main Course',
                      'Desserts',
                      'Beverages',
                    ],
                    selectedItem: provider.selectedCategory,
                    onItemSelected: (category) =>
                        provider.setSelectedCategory(category),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(size.width * 0.04),
                    physics: const BouncingScrollPhysics(),
                    itemCount: provider.filteredItems.length,
                    itemBuilder: (context, index) =>
                        MenuItemCard(item: provider.filteredItems[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final MenuItem item;

  const MenuItemCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall * 1.5),
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.white,
              size: AppSizes.iconSizeLarge,
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
                Text(
                  item.category,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingSmall),
                Row(
                  children: [
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingSmall,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.available
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.available ? 'Available' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.available
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}