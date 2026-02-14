import 'package:flutter/material.dart';
import 'package:pos_app/screens/menu_sub_category_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuProvider(),
      child: _MenuBody(
        searchCtrl: _searchCtrl,
        searchQuery: _searchQuery,
        onSearchChanged: (q) => setState(() => _searchQuery = q),
      ),
    );
  }
}

class _MenuBody extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _MenuBody({
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
  });

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
            // ── Header ──────────────────────────────────────
            _MenuHeader(),

            // ── Search ──────────────────────────────────────
            _SearchBar(
              controller: searchCtrl,
              onChanged: onSearchChanged,
            ),

            // ── Grid ────────────────────────────────────────
            Expanded(
              child: Consumer<MenuProvider>(
                builder: (context, provider, _) {
                  // Filter categories by search query
                  final allCategories = provider.categories;
                  final categories = searchQuery.isEmpty
                      ? allCategories
                      : allCategories.where((c) {
                          final q = searchQuery.toLowerCase();
                          // Match category name
                          if (c.name.toLowerCase().contains(q)) return true;
                          // Match any subcategory name
                          if (c.subcategories
                              .any((s) => s.toLowerCase().contains(q))) {
                            return true;
                          }
                          // Match any item name in this category
                          final hasItem = provider
                              .itemsForCategory(c.name)
                              .any((i) =>
                                  i.name.toLowerCase().contains(q) ||
                                  i.subcategory.toLowerCase().contains(q));
                          return hasItem;
                        }).toList();

                  if (categories.isEmpty) {
                    return _SearchEmptyState(query: searchQuery);
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.paddingLarge,
                      0,
                      AppSizes.paddingLarge,
                      AppSizes.paddingLarge,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSizes.paddingMedium,
                      mainAxisSpacing: AppSizes.paddingMedium,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return _CategoryCard(
                        category: cat,
                        gradientColors: _categoryGradients[cat.name] ??
                            [AppColors.primaryPurple, const Color(0xFF9C27B0)],
                        searchQuery: searchQuery,
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

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _MenuHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            child: const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 26),
          ),
          SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize:
                        ResponsiveUtils.getFontSize(context, 22),
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<MenuProvider>(
                  builder: (_, p, __) => Text(
                    '${p.categories.length} categories · ${p.allMenuItems.length} items',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF4F4F4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search categories, dishes...',
            hintStyle: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFAAAAAA),
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFFAAAAAA),
                    ),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF4F4F4),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryPurple,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final MenuCategory category;
  final List<Color> gradientColors;
  final String searchQuery;

  const _CategoryCard({
    required this.category,
    required this.gradientColors,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    // Highlight matched items count when searching
    final provider = context.read<MenuProvider>();
    final matchedItems = searchQuery.isNotEmpty
        ? provider
            .itemsForCategory(category.name)
            .where((i) =>
                i.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                i.subcategory
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
            .length
        : category.itemCount;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuSubcategoryScreen(
            category: category,
            gradientColors: gradientColors,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image hero
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Gradient / image
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.borderRadiusLarge),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: category.imageUrl != null
                          ? Image.network(
                              category.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.15),
                              colorBlendMode: BlendMode.darken,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  category.icon,
                                  style: const TextStyle(fontSize: 44),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                category.icon,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                    ),
                  ),

                  // Item count badge (shows matched count while searching)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        searchQuery.isNotEmpty
                            ? '$matchedItems match'
                            : '$matchedItems items',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gradientColors.first,
                        ),
                      ),
                    ),
                  ),

                  // Emoji bottom-left
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
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

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for a dish or category',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}