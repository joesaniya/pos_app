import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/screens/menu_sub_category_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

/// Pastel gradient palettes per category
const Map<String, List<Color>> _categoryGradients = {
  'Dosa': [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  'Curry': [Color(0xFFFF9800), Color(0xFFFFB74D)],
  'Breakfast': [Color(0xFFFFA726), Color(0xFFFFCC02)],
  'Lunch': [Color(0xFF56AB2F), Color(0xFFA8E063)],
  'Dinner': [Color(0xFF1A237E), Color(0xFF42A5F5)],
  'Desserts': [Color(0xFFEC407A), Color(0xFFFF6F91)],
  'Beverages': [Color(0xFF00B4DB), Color(0xFF0083B0)],
};

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuProvider(),
      child: _MenuView(searchCtrl: _searchCtrl),
    );
  }
}

class _MenuView extends StatelessWidget {
  final TextEditingController searchCtrl;
  const _MenuView({required this.searchCtrl});

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
            const _MenuHeader(),
            _SearchBar(controller: searchCtrl),
            Expanded(
              child: Consumer<MenuProvider>(
                builder: (context, provider, _) {
                  return GridView.builder(
                    padding: EdgeInsets.all(AppSizes.paddingLarge),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSizes.paddingMedium,
                      mainAxisSpacing: AppSizes.paddingMedium,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: provider.categories.length,
                    itemBuilder: (context, index) {
                      return _CategoryCard(
                        category: provider.categories[index],
                        gradientColors:
                            _categoryGradients[provider
                                .categories[index]
                                .name] ??
                            [AppColors.primaryPurple, const Color(0xFF9C27B0)],
                      );
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

class _MenuHeader extends StatelessWidget {
  const _MenuHeader();

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
            child: const Icon(
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
                  'Menu',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, 24),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse categories & items',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightNeutral200,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppSizes.paddingLarge),
      child: TextField(
        controller: controller,
        onChanged: (v) => context.read<MenuProvider>().setSearchQuery(v),
        decoration: InputDecoration(
          hintText: 'Search categories or items...',
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
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
}

class _CategoryCard extends StatelessWidget {
  final MenuCategory category;
  final List<Color> gradientColors;

  const _CategoryCard({required this.category, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MenuSubcategoryScreen(
              category: category,
              gradientColors: gradientColors,
            ),
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
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / gradient hero
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSizes.borderRadiusLarge),
                      ),
                    ),
                    child: category.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppSizes.borderRadiusLarge),
                            ),
                            child: Image.network(
                              category.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.15),
                              colorBlendMode: BlendMode.darken,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  category.icon,
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                  ),
                  // Item count badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '${category.itemCount}',
                        style: AppTheme.labelSmall.copyWith(
                          color: gradientColors.first,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Emoji overlay
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(AppSizes.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.name,
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${category.itemCount} items · ${category.subcategories.length - 1} types',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: gradientColors.first,
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
