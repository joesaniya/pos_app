import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/screens/menu_item_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class MenuSubcategoryScreen extends StatefulWidget {
  final MenuCategory category;
  final List<Color> gradientColors;

  const MenuSubcategoryScreen({
    Key? key,
    required this.category,
    required this.gradientColors,
  }) : super(key: key);

  @override
  State<MenuSubcategoryScreen> createState() => _MenuSubcategoryScreenState();
}

class _MenuSubcategoryScreenState extends State<MenuSubcategoryScreen> {
  String _selectedSub = 'All';

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;

    return Consumer<MenuProvider>(
      builder: (context, provider, _) {
        final items = provider.itemsForCategory(
          widget.category.name,
          _selectedSub,
        );
        final subcategories = widget.category.subcategories;
        final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
          context,
          mobile: 2,
          tablet: 3,
          desktop: 4,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // ── Hero SliverAppBar ──────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: primaryColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(
                    left: 56,
                    bottom: 16,
                    right: 16,
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${widget.category.itemCount} items',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient bg
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Image overlay
                      if (widget.category.imageUrl != null)
                        Image.network(
                          widget.category.imageUrl!,
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.35),
                          colorBlendMode: BlendMode.darken,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      // Big emoji decoration
                      Positioned(
                        right: -10,
                        bottom: 20,
                        child: Text(
                          widget.category.icon,
                          style: const TextStyle(fontSize: 120),
                        ),
                      ),
                    ],
                  ),
                ),
                // Subcategory chips pinned in bottom of app bar
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Container(
                    height: 52,
                    color: AppColors.white,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingLarge,
                        vertical: 8,
                      ),
                      itemCount: subcategories.length,
                      itemBuilder: (context, index) {
                        final sub = subcategories[index];
                        final isSelected = _selectedSub == sub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedSub = sub),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : AppColors.lightNeutral200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                sub,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Stats bar ─────────────────────────────────
              SliverToBoxAdapter(
                child: _StatsBar(items: items, primaryColor: primaryColor),
              ),

              // ── Items grid ────────────────────────────────
              items.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this category',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.all(AppSizes.paddingLarge),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _MenuItemCard(
                            item: items[index],
                            primaryColor: primaryColor,
                          ),
                          childCount: items.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: AppSizes.paddingMedium,
                          mainAxisSpacing: AppSizes.paddingMedium,
                          childAspectRatio: 0.72,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<MenuItem> items;
  final Color primaryColor;

  const _StatsBar({required this.items, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => i.available).length;
    final bestSellers = items.where((i) => i.isBestseller).length;
    final veg = items.where((i) => i.isVeg).length;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSizes.paddingLarge,
        AppSizes.paddingLarge,
        AppSizes.paddingLarge,
        0,
      ),
      padding: EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
            label: 'Available',
            value: '$available',
            color: AppColors.success,
            icon: Icons.check_circle_outline,
          ),
          Container(height: 36, width: 1, color: AppColors.borderLight),
          _StatChip(
            label: 'Bestsellers',
            value: '$bestSellers',
            color: primaryColor,
            icon: Icons.star_outline,
          ),
          Container(height: 36, width: 1, color: AppColors.borderLight),
          _StatChip(
            label: 'Veg',
            value: '$veg',
            color: const Color(0xFF2E7D32),
            icon: Icons.eco_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTheme.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  MENU ITEM CARD
// ─────────────────────────────────────────
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final Color primaryColor;

  const _MenuItemCard({required this.item, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) =>
                MenuItemDetailScreen(item: item, primaryColor: primaryColor),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / icon hero
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSizes.borderRadiusLarge),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryEmoji(item.category),
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                  // Veg/non-veg badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: item.isVeg
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB71C1C),
                          width: 1.5,
                        ),
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.isVeg
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFB71C1C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // Bestseller ribbon
                  if (item.isBestseller)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🔥 Hot',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Unavailable overlay
                  if (!item.available)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppSizes.borderRadiusLarge),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Unavailable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTheme.headlineSmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Rating row
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 11,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.access_time,
                          size: 10,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item.prepTimeMinutes}m',
                          style: AppTheme.labelSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        if (item.available)
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
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

  String _getCategoryEmoji(String category) {
    const map = {
      'Dosa': '🫓',
      'Curry': '🍛',
      'Breakfast': '🍳',
      'Lunch': '🍱',
      'Dinner': '🌙',
      'Desserts': '🧁',
      'Beverages': '🥤',
    };
    return map[category] ?? '🍽️';
  }
}
