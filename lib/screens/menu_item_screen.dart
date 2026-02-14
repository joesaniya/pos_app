import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';


class MenuItemsScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;

  const MenuItemsScreen({
    Key? key,
    required this.categoryName,
    required this.categoryColor,
  }) : super(key: key);

  @override
  State<MenuItemsScreen> createState() => _MenuItemsScreenState();
}

class _MenuItemsScreenState extends State<MenuItemsScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Popular', 'Veg', 'Non-Veg', 'Spicy'];

  final List<MenuItem> menuItems = [
    MenuItem(
      name: 'Masala Dosa',
      description: 'Crispy rice crepe filled with spiced potato',
      price: 120.00,
      image: 'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400',
      isVeg: true,
      isPopular: true,
      rating: 4.8,
      prepTime: '15 min',
    ),
    MenuItem(
      name: 'Butter Chicken',
      description: 'Creamy tomato curry with tender chicken',
      price: 280.00,
      image: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400',
      isVeg: false,
      isPopular: true,
      rating: 4.9,
      prepTime: '25 min',
    ),
    MenuItem(
      name: 'Paneer Tikka',
      description: 'Grilled cottage cheese with Indian spices',
      price: 220.00,
      image: 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400',
      isVeg: true,
      isPopular: true,
      rating: 4.7,
      prepTime: '20 min',
    ),
    MenuItem(
      name: 'Biryani',
      description: 'Fragrant rice with aromatic spices and meat',
      price: 250.00,
      image: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400',
      isVeg: false,
      isPopular: true,
      rating: 4.8,
      prepTime: '30 min',
    ),
    MenuItem(
      name: 'Palak Paneer',
      description: 'Cottage cheese in creamy spinach gravy',
      price: 200.00,
      image: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400',
      isVeg: true,
      isPopular: false,
      rating: 4.6,
      prepTime: '20 min',
    ),
    MenuItem(
      name: 'Chicken Tikka',
      description: 'Marinated grilled chicken pieces',
      price: 260.00,
      image: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=400',
      isVeg: false,
      isPopular: true,
      rating: 4.7,
      prepTime: '25 min',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterChips(context),
            Expanded(
              child: _buildMenuItemsList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.categoryColor, widget.categoryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.categoryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
              SizedBox(width: AppSizes.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: AppTheme.displaySmall.copyWith(
                        color: AppColors.white,
                        fontSize: ResponsiveUtils.getFontSize(context, 24),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${menuItems.length} delicious items',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppColors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.search, color: AppColors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingMedium),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return Padding(
            padding: EdgeInsets.only(right: AppSizes.paddingSmall),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = filter;
                });
              },
              backgroundColor: AppColors.white,
              selectedColor: widget.categoryColor.withOpacity(0.2),
              labelStyle: AppTheme.labelMedium.copyWith(
                color: isSelected ? widget.categoryColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? widget.categoryColor : AppColors.borderLight,
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

  Widget _buildMenuItemsList(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.all(AppSizes.paddingLarge),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          return _buildMenuItemCard(menuItems[index]);
        },
      );
    } else {
      final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
        context,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
      
      return GridView.builder(
        padding: EdgeInsets.all(AppSizes.paddingLarge),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSizes.paddingMedium,
          mainAxisSpacing: AppSizes.paddingMedium,
          childAspectRatio: 1.2,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          return _buildMenuItemCard(menuItems[index]);
        },
      );
    }
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
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
      child: Row(
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppSizes.borderRadiusLarge),
                ),
                child: Image.network(
                  item.image,
                  width: 120,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 140,
                      color: widget.categoryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.restaurant,
                        size: 40,
                        color: widget.categoryColor,
                      ),
                    );
                  },
                ),
              ),
              if (item.isPopular)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 12, color: AppColors.white),
                        SizedBox(width: 4),
                        Text(
                          'Popular',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isVeg ? AppColors.success : AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        item.isVeg ? 'Veg' : 'Non-Veg',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Details Section
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTheme.headlineSmall.copyWith(
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.secondaryYellow),
                          SizedBox(width: 4),
                          Text(
                            item.rating.toString(),
                            style: AppTheme.labelSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 4),
                          Text(
                            item.prepTime,
                            style: AppTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: AppTheme.headlineSmall.copyWith(
                          color: widget.categoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.categoryColor,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: AppTheme.labelMedium.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ],
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
    );
  }
}

class MenuItem {
  final String name;
  final String description;
  final double price;
  final String image;
  final bool isVeg;
  final bool isPopular;
  final double rating;
  final String prepTime;

  MenuItem({
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.isVeg,
    required this.isPopular,
    required this.rating,
    required this.prepTime,
  });
}