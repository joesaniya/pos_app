
import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/screens/add_menu_category_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/menu_sub_category_screen.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

const Map<String, List<Color>> _categoryGradients = {
  'Dosa':      [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  'Curry':     [Color(0xFFFF9800), Color(0xFFFFB74D)],
  'Breakfast': [Color(0xFFFFA726), Color(0xFFFFCC02)],
  'Lunch':     [Color(0xFF56AB2F), Color(0xFFA8E063)],
  'Dinner':    [Color(0xFF1A237E), Color(0xFF42A5F5)],
  'Desserts':  [Color(0xFFEC407A), Color(0xFFFF6F91)],
  'Beverages': [Color(0xFF00B4DB), Color(0xFF0083B0)],
};

List<Color> _gradientFor(SupabaseMenuCategory cat) {
  final match = _categoryGradients[cat.name];
  if (match != null) return match;
  // Generate a deterministic colour pair from colorHex
  final hex = cat.colorHex.replaceFirst('#', '');
  final base = Color(int.parse('FF$hex', radix: 16));
  return [base, base.withOpacity(0.65)];
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Init provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupabaseMenuProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
      floatingActionButton: _AddCategoryFab(),
      body: SafeArea(
        child: Column(
          children: [
            _MenuHeader(),
            _SearchBar(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
            Expanded(
              child: Consumer<SupabaseMenuProvider>(
                builder: (_, provider, __) {
                  // Loading skeleton
                  if (provider.categoryState == MenuLoadState.loading) {
                    return _LoadingGrid(crossAxisCount: crossAxisCount);
                  }

                  // Error
                  if (provider.categoryState == MenuLoadState.error) {
                    return _ErrorState(
                      message: provider.error ?? 'Unknown error',
                      onRetry: provider.loadCategories,
                    );
                  }

                  final all = provider.categories;
                  final q = _searchQuery.toLowerCase();
                  final categories = q.isEmpty
                      ? all
                      : all.where((c) {
                          if (c.name.toLowerCase().contains(q)) return true;
                          final items = provider.itemsForCategory(c.id);
                          return items.any((i) =>
                              i.name.toLowerCase().contains(q) ||
                              i.description.toLowerCase().contains(q));
                        }).toList();

                  if (categories.isEmpty && q.isNotEmpty) {
                    return _SearchEmptyState(query: _searchQuery);
                  }

                  if (categories.isEmpty) {
                    return _EmptyCategoriesState();
                  }

                  return RefreshIndicator(
                    color: AppColors.primaryPurple,
                    onRefresh: provider.loadCategories,
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSizes.paddingLarge,
                        0,
                        AppSizes.paddingLarge,
                        AppSizes.paddingLarge,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppSizes.paddingMedium,
                        mainAxisSpacing: AppSizes.paddingMedium,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (ctx, i) => _CategoryCard(
                        category: categories[i],
                        gradientColors: _gradientFor(categories[i]),
                        searchQuery: _searchQuery,
                        itemCount: provider
                            .itemsForCategory(categories[i].id)
                            .length,
                      ),
                    ),
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
//  FAB — Add Category
// ─────────────────────────────────────────────────────────────────────────────
class _AddCategoryFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
      ),
      backgroundColor: AppColors.primaryPurple,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
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
              borderRadius:
                  BorderRadius.circular(AppSizes.borderRadiusMedium),
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
                    fontSize: ResponsiveUtils.getFontSize(context, 22),
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<SupabaseMenuProvider>(
                  builder: (_, p, __) => Text(
                    '${p.categories.length} categories · ${p.allItems.length} items',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<SupabaseMenuProvider>().loadCategories(),
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF4F4F4),
            ),
            tooltip: 'Refresh',
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
            hintStyle:
                const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFFAAAAAA)),
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
                  color: AppColors.primaryPurple, width: 1.5),
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
  final SupabaseMenuCategory category;
  final List<Color> gradientColors;
  final String searchQuery;
  final int itemCount;

  const _CategoryCard({
    required this.category,
    required this.gradientColors,
    required this.searchQuery,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuSubcategoryScreen(
            supabaseCategory: category,
            gradientColors: gradientColors,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(AppSizes.borderRadiusLarge),
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
            // Image / Gradient hero
            Expanded(
              flex: 3,
              child: Stack(
                children: [
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
                                child: Text(category.icon,
                                    style:
                                        const TextStyle(fontSize: 44)),
                              ),
                            )
                          : Center(
                              child: Text(category.icon,
                                  style:
                                      const TextStyle(fontSize: 44)),
                            ),
                    ),
                  ),
                  // Badge
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
                        '$itemCount items',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gradientColors.first,
                        ),
                      ),
                    ),
                  ),
                  // Creator tag
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'By ${category.createdByName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Emoji
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Text(category.icon,
                        style: const TextStyle(fontSize: 28)),
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
                          fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.description.isNotEmpty
                                ? category.description
                                : '$itemCount items available',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFAAAAAA)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 11, color: gradientColors.first),
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
//  LOADING GRID (skeleton)
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  final int crossAxisCount;
  const _LoadingGrid({required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSizes.paddingMedium,
        mainAxisSpacing: AppSizes.paddingMedium,
        childAspectRatio: 0.82,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius:
                BorderRadius.circular(AppSizes.borderRadiusLarge),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATES
// ─────────────────────────────────────────────────────────────────────────────
class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No results for "$query"',
                style: TextStyle(
                    fontSize: 15, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Try searching for a dish or category',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
}

class _EmptyCategoriesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No categories yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Tap + to add your first category',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 64, color: Color(0xFFFF6B6B)),
              const SizedBox(height: 16),
              const Text('Failed to load menu',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

/*import 'package:flutter/material.dart';
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
}*/