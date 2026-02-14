import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class MenuItemDetailScreen extends StatelessWidget {
  final MenuItem item;
  final Color primaryColor;

  const MenuItemDetailScreen({
    Key? key,
    required this.item,
    required this.primaryColor,
  }) : super(key: key);

  String get _emoji {
    const map = {
      'Dosa': '🫓',
      'Curry': '🍛',
      'Breakfast': '🍳',
      'Lunch': '🍱',
      'Dinner': '🌙',
      'Desserts': '🧁',
      'Beverages': '🥤',
    };
    return map[item.category] ?? '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  SizedBox(height: AppSizes.paddingLarge),
                  _buildQuickStats(),
                  SizedBox(height: AppSizes.paddingLarge),
                  _buildDescription(),
                  SizedBox(height: AppSizes.paddingLarge),
                  if (item.nutrition != null) ...[
                    _buildNutritionCard(),
                    SizedBox(height: AppSizes.paddingLarge),
                  ],
                  _buildIngredients(),
                  SizedBox(height: AppSizes.paddingLarge),
                  if (item.allergens.isNotEmpty) ...[
                    _buildAllergens(),
                    SizedBox(height: AppSizes.paddingLarge),
                  ],
                  _buildAddToOrderSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: primaryColor,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.2),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: IconButton(
              icon: const Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () {},
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient bg
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Large emoji
            Center(child: Text(_emoji, style: const TextStyle(fontSize: 100))),
            // Decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Bottom gradient fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, AppColors.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Veg indicator
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: item.isVeg
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFB71C1C),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: item.isVeg
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFB71C1C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.isVeg ? 'Vegetarian' : 'Non-Vegetarian',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.isVeg
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFB71C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.isBestseller) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔥 Bestseller',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: AppTheme.displaySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.category} · ${item.subcategory}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: primaryColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: item.available
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.available ? '● Available' : '● Sold Out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: item.available ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _QuickStatTile(
          icon: Icons.star,
          label: 'Rating',
          value: item.rating.toStringAsFixed(1),
          color: Colors.amber.shade600,
        ),
        const SizedBox(width: 12),
        _QuickStatTile(
          icon: Icons.timer_outlined,
          label: 'Prep Time',
          value: '${item.prepTimeMinutes} min',
          color: primaryColor,
        ),
        if (item.nutrition != null) ...[
          const SizedBox(width: 12),
          _QuickStatTile(
            icon: Icons.local_fire_department_outlined,
            label: 'Calories',
            value: '${item.nutrition!.calories} kcal',
            color: Colors.deepOrange,
          ),
        ],
      ],
    );
  }

  Widget _buildDescription() {
    return _SectionCard(
      title: 'Description',
      icon: Icons.info_outline,
      iconColor: primaryColor,
      child: Text(
        item.description,
        style: AppTheme.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildNutritionCard() {
    final n = item.nutrition!;
    return _SectionCard(
      title: 'Nutrition Info',
      icon: Icons.monitor_heart_outlined,
      iconColor: Colors.deepOrange,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NutritionBar(
                  label: 'Protein',
                  value: n.protein,
                  unit: 'g',
                  max: 50,
                  color: const Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _NutritionBar(
                  label: 'Carbs',
                  value: n.carbs,
                  unit: 'g',
                  max: 100,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NutritionBar(
                  label: 'Fat',
                  value: n.fat,
                  unit: 'g',
                  max: 50,
                  color: const Color(0xFFF44336),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _NutritionBar(
                  label: 'Calories',
                  value: n.calories.toDouble(),
                  unit: 'kcal',
                  max: 800,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return _SectionCard(
      title: 'Key Ingredients',
      icon: Icons.grass_outlined,
      iconColor: const Color(0xFF2E7D32),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: item.ingredients
            .map(
              (ing) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: Text(
                  ing,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAllergens() {
    return _SectionCard(
      title: 'Allergen Info',
      icon: Icons.warning_amber_outlined,
      iconColor: const Color(0xFFE65100),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: item.allergens
            .map(
              (a) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE65100).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 13,
                      color: Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAddToOrderSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.05),
            primaryColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₹${item.price.toStringAsFixed(2)} per serving',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity selector
              _QuantitySelector(primaryColor: primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: item.available ? () {} : null,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(
                item.available ? 'Add to Order' : 'Currently Unavailable',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionBar extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double max;
  final Color color;

  const _NutritionBar({
    required this.label,
    required this.value,
    required this.unit,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _QuantitySelector extends StatefulWidget {
  final Color primaryColor;
  const _QuantitySelector({required this.primaryColor});

  @override
  State<_QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<_QuantitySelector> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QtyButton(
          icon: Icons.remove,
          onTap: () => setState(() => _quantity = (_quantity - 1).clamp(1, 99)),
          color: widget.primaryColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$_quantity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.primaryColor,
            ),
          ),
        ),
        _QtyButton(
          icon: Icons.add,
          onTap: () => setState(() => _quantity = (_quantity + 1).clamp(1, 99)),
          color: widget.primaryColor,
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
