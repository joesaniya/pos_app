import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<MenuItem> _filtered(List<MenuItem> items) {
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q) ||
              i.subcategory.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;
    final statusBarH = MediaQuery.of(context).padding.top;

    // Force white icons in status bar while on this screen
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Consumer<MenuProvider>(
      builder: (context, provider, _) {
        final baseItems = provider.itemsForCategory(
          widget.category.name,
          _selectedSub,
        );
        final items = _filtered(baseItems);
        final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
          context,
          mobile: 2,
          tablet: 3,
          desktop: 4,
        );

        return Scaffold(
          // No appBar — we build it manually inside the hero so we control exact positioning
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ══════════════════════════════════════════════
              //  HERO  (status bar height + custom toolbar + image + title)
              // ══════════════════════════════════════════════
              _HeroSection(
                category: widget.category,
                gradientColors: widget.gradientColors,
                statusBarHeight: statusBarH,
                onBack: () => Navigator.pop(context),
              ),

              // ══════════════════════════════════════════════
              //  STICKY SEARCH + CHIPS  (white, always visible)
              // ══════════════════════════════════════════════
              _SearchAndChipsBar(
                primaryColor: primaryColor,
                subcategories: widget.category.subcategories,
                selectedSub: _selectedSub,
                searchCtrl: _searchCtrl,
                onSubSelected: (s) => setState(() {
                  _selectedSub = s;
                  _searchQuery = '';
                  _searchCtrl.clear();
                }),
                onSearchChanged: (q) => setState(() => _searchQuery = q),
              ),

              // ══════════════════════════════════════════════
              //  SCROLLABLE CONTENT
              // ══════════════════════════════════════════════
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Stats
                    SliverToBoxAdapter(
                      child: _StatsBar(
                        items: baseItems,
                        primaryColor: primaryColor,
                      ),
                    ),

                    // Grid / empty
                    items.isEmpty
                        ? SliverFillRemaining(
                            child: _EmptyState(searchQuery: _searchQuery),
                          )
                        : SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppSizes.paddingLarge,
                              AppSizes.paddingMedium,
                              AppSizes.paddingLarge,
                              AppSizes.paddingLarge,
                            ),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _MenuItemCard(
                                  item: items[index],
                                  primaryColor: primaryColor,
                                ),
                                childCount: items.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: AppSizes.paddingMedium,
                                    mainAxisSpacing: AppSizes.paddingMedium,
                                    childAspectRatio: 0.72,
                                  ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO SECTION  —  image + back button + fully visible title
// ═════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final MenuCategory category;
  final List<Color> gradientColors;
  final double statusBarHeight;
  final VoidCallback onBack;

  const _HeroSection({
    required this.category,
    required this.gradientColors,
    required this.statusBarHeight,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Total hero = status bar + toolbar (56) + bottom title area (80)
    final totalHeight = statusBarHeight + 56 + 80.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background gradient ──────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Network image overlay ─────────────────────────
          if (category.imageUrl != null)
            Image.network(
              category.imageUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.28),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),

          // ── Decorative emoji (top-right, semi-transparent) ─
          Positioned(
            right: -8,
            top: statusBarHeight + 4,
            child: Opacity(
              opacity: 0.35,
              child: Text(category.icon, style: const TextStyle(fontSize: 110)),
            ),
          ),

          // ── Dark gradient scrim at bottom for text legibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.62)],
                ),
              ),
            ),
          ),

          // ── Back button  (just below status bar) ───────────
          Positioned(
            top: statusBarHeight + 8,
            left: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // ── TITLE  — anchored to bottom, ALWAYS fully visible ─
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category name — large, bold, with drop-shadow
                Text(
                  category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Pill badges
                Row(
                  children: [
                    _HeroBadge(label: '${category.itemCount} items'),
                    const SizedBox(width: 8),
                    _HeroBadge(
                      label: '${category.subcategories.length - 1} varieties',
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

class _HeroBadge extends StatelessWidget {
  final String label;
  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH BAR  +  SUBCATEGORY CHIPS  (non-scrolling, always pinned below hero)
// ═════════════════════════════════════════════════════════════════════════════
class _SearchAndChipsBar extends StatelessWidget {
  final Color primaryColor;
  final List<String> subcategories;
  final String selectedSub;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSubSelected;
  final ValueChanged<String> onSearchChanged;

  const _SearchAndChipsBar({
    required this.primaryColor,
    required this.subcategories,
    required this.selectedSub,
    required this.searchCtrl,
    required this.onSubSelected,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            searchCtrl.clear();
                            onSearchChanged('');
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
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // Subcategory chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 14, right: 8),
              itemCount: subcategories.length,
              itemBuilder: (_, i) {
                final sub = subcategories[i];
                final sel = sub == selectedSub;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onSubSelected(sub),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? primaryColor : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF777777),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATS BAR
// ═════════════════════════════════════════════════════════════════════════════
class _StatsBar extends StatelessWidget {
  final List<MenuItem> items;
  final Color primaryColor;

  const _StatsBar({required this.items, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => i.available).length;
    final best = items.where((i) => i.isBestseller).length;
    final veg = items.where((i) => i.isVeg).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            icon: Icons.check_circle_outline,
            label: 'Available',
            value: '$available',
            color: AppColors.success,
          ),
          Container(height: 32, width: 1, color: const Color(0xFFEEEEEE)),
          _Stat(
            icon: Icons.star_outline,
            label: 'Bestsellers',
            value: '$best',
            color: primaryColor,
          ),
          Container(height: 32, width: 1, color: const Color(0xFFEEEEEE)),
          _Stat(
            icon: Icons.eco_outlined,
            label: 'Veg',
            value: '$veg',
            color: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  const _EmptyState({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.restaurant_outlined,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            searchQuery.isNotEmpty
                ? 'No results for "$searchQuery"'
                : 'No items in this category',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MENU ITEM CARD
// ═════════════════════════════════════════════════════════════════════════════
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final Color primaryColor;

  const _MenuItemCard({required this.item, required this.primaryColor});

  String _emoji(String c) {
    const m = {
      'Dosa': '🫓',
      'Curry': '🍛',
      'Breakfast': '🍳',
      'Lunch': '🍱',
      'Dinner': '🌙',
      'Desserts': '🧁',
      'Beverages': '🥤',
    };
    return m[c] ?? '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              MenuItemDetailScreen(item: item, primaryColor: primaryColor),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
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
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image zone ──────────────────────────────────
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
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
                        _emoji(item.category),
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                  // Veg/non-veg indicator
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
                  // Bestseller badge
                  if (item.isBestseller)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
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
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppSizes.borderRadiusLarge),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Unavailable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info zone ──────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
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
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time,
                          size: 10,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item.prepTimeMinutes}m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
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
                              padding: const EdgeInsets.all(6),
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
}
