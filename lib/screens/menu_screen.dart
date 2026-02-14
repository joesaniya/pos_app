import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String selectedCategory = 'All';

  final List<MenuCategory> categories = [
    MenuCategory(
      name: 'All',
      icon: Icons.apps_rounded,
      color: AppColors.primaryPurple,
      itemCount: 48,
    ),
    MenuCategory(
      name: 'Dosa',
      icon: Icons.restaurant,
      color: Color(0xFFFF6B6B),
      itemCount: 12,
      image:
          'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400',
    ),
    MenuCategory(
      name: 'Curry',
      icon: Icons.soup_kitchen,
      color: Color(0xFFFF9800),
      itemCount: 15,
      image:
          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400',
    ),
    MenuCategory(
      name: 'Breakfast',
      icon: Icons.breakfast_dining,
      color: Color(0xFFFFA726),
      itemCount: 8,
      image:
          'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=400',
    ),
    MenuCategory(
      name: 'Lunch',
      icon: Icons.lunch_dining,
      color: Color(0xFF66BB6A),
      itemCount: 20,
      image: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
    ),
    MenuCategory(
      name: 'Dinner',
      icon: Icons.dinner_dining,
      color: Color(0xFF42A5F5),
      itemCount: 18,
      image: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400',
    ),
    MenuCategory(
      name: 'Desserts',
      icon: Icons.cake,
      color: Color(0xFFEC407A),
      itemCount: 10,
      image:
          'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
    ),
    MenuCategory(
      name: 'Beverages',
      icon: Icons.local_drink,
      color: Color(0xFF26C6DA),
      itemCount: 12,
      image: 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
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
            _buildHeader(context),
            _buildSearchBar(context),
            _buildCategoryChips(context),
            Expanded(child: _buildCategoryGrid(context, crossAxisCount)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: AppColors.white,
              size: 28,
            ),
          ),
          SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu Categories',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, 24),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select a category to explore',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_outlined),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightNeutral200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppSizes.paddingLarge),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
            ),
            child: IconButton(
              icon: Icon(Icons.tune, color: AppColors.white, size: 20),
              onPressed: () {},
            ),
          ),
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingMedium,
            vertical: AppSizes.paddingMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return Container(
      height: 50,
      margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category.name;

          return Padding(
            padding: EdgeInsets.only(right: AppSizes.paddingSmall),
            child: ChoiceChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = category.name;
                });
              },
              backgroundColor: AppColors.white,
              selectedColor: category.color.withOpacity(0.2),
              labelStyle: AppTheme.labelMedium.copyWith(
                color: isSelected ? category.color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? category.color : AppColors.borderLight,
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
  }

  Widget _buildCategoryGrid(BuildContext context, int crossAxisCount) {
    final filteredCategories = selectedCategory == 'All'
        ? categories.where((c) => c.name != 'All').toList()
        : categories.where((c) => c.name == selectedCategory).toList();

    return GridView.builder(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSizes.paddingMedium,
        mainAxisSpacing: AppSizes.paddingMedium,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(filteredCategories[index]);
      },
    );
  }

  Widget _buildCategoryCard(MenuCategory category) {
    return GestureDetector(
      onTap: () {
        // Navigate to category items
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Container
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSizes.borderRadiusLarge),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          category.color.withOpacity(0.8),
                          category.color,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: category.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppSizes.borderRadiusLarge),
                            ),
                            child: Image.network(
                              category.image!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    category.icon,
                                    size: 48,
                                    color: AppColors.white,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              category.icon,
                              size: 48,
                              color: AppColors.white,
                            ),
                          ),
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSizes.borderRadiusLarge),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Item Count Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '${category.itemCount} items',
                        style: AppTheme.labelSmall.copyWith(
                          color: category.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info Container
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(AppSizes.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            category.icon,
                            size: 18,
                            color: category.color,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category.name,
                            style: AppTheme.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: category.color,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'View Menu',
                          style: AppTheme.labelSmall.copyWith(
                            color: category.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuCategory {
  final String name;
  final IconData icon;
  final Color color;
  final int itemCount;
  final String? image;

  MenuCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.itemCount,
    this.image,
  });
}

/*import 'package:flutter/material.dart';
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
}*/
