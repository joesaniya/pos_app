import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/models/menu_filter_modal.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/menu_item_detail_screen.dart';
import 'package:pos_app/screens/add_menu_item_screen.dart';
import 'package:pos_app/screens/widgets/menu_filter_sheet_widget.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/filter_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';

/// Roles allowed to add / edit / delete items.
const Set<String> _editableRoles = {'staff', 'admin', 'system', 'owner'};

bool _canEdit(String? role) =>
    role != null && _editableRoles.contains(role.toLowerCase());

class MenuSubcategoryScreen extends StatefulWidget {
  final SupabaseMenuCategory? supabaseCategory;
  final MenuCategory? category;
  final List<Color> gradientColors;

  const MenuSubcategoryScreen({
    Key? key,
    this.supabaseCategory,
    this.category,
    required this.gradientColors,
  }) : assert(supabaseCategory != null || category != null),
       super(key: key);

  @override
  State<MenuSubcategoryScreen> createState() => _MenuSubcategoryScreenState();
}

class _MenuSubcategoryScreenState extends State<MenuSubcategoryScreen> {
  String _searchQuery = '';
  MenuFilterModel _filter = const MenuFilterModel();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedTag = 'All';
  List<String> _tags = ['All'];

  // Cached provider — stored in didChangeDependencies() so dispose() can
  // safely access it without calling context.read() on a deactivated widget.
  SupabaseMenuProvider? _provider;

  bool get _isSupabase => widget.supabaseCategory != null;
  String get _catId => widget.supabaseCategory?.id ?? '';
  String get _catName =>
      widget.supabaseCategory?.name ?? widget.category?.name ?? '';
  String get _catIcon =>
      widget.supabaseCategory?.icon ?? widget.category?.icon ?? '🍽️';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to capture the provider — Flutter allows InheritedWidget
    // lookups here. We store it so dispose() doesn't need context.
    _provider = Provider.of<SupabaseMenuProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    if (_isSupabase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final p = context.read<SupabaseMenuProvider>();
        p.loadItemsForCategory(_catId).then((_) {
          _buildTags(p.itemsForCategory(_catId));
        });
        p.subscribeItems(_catId);
      });
    }
  }

  void _buildTags(List<SupabaseMenuItem> items) {
    final tagSet = <String>{'All'};
    for (final item in items) {
      for (final t in item.tags) {
        if (t.isNotEmpty) tagSet.add(t);
      }
    }
    if (mounted) setState(() => _tags = tagSet.toList());
  }

  List<SupabaseMenuItem> _filtered(List<SupabaseMenuItem> items) {
    var result = items;

    if (_selectedTag != 'All') {
      result = result.where((i) => i.tags.contains(_selectedTag)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.description.toLowerCase().contains(q),
          )
          .toList();
    }

    final asMenuItems = result.map((e) => e.toMenuItem(_catName)).toList();
    final filtered = _filter.apply(asMenuItems);
    final filteredIds = filtered.map((e) => e.id).toSet();
    return result.where((e) => filteredIds.contains(e.id)).toList();
  }

  Future<void> _openFilterSheet(
    BuildContext ctx,
    List<SupabaseMenuItem> items,
  ) async {
    final menuItems = items.map((e) => e.toMenuItem(_catName)).toList();
    final result = await showMenuFilterSheet(
      context: ctx,
      current: _filter,
      accentColor: widget.gradientColors.first,
      totalItems: menuItems.length,
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  void dispose() {
    // Use the cached _provider reference — calling context.read() here
    // is unsafe because the widget is already deactivated at dispose time.
    if (_isSupabase) {
      _provider?.unsubscribeItems(_catId);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;
    final statusBarH = MediaQuery.of(context).padding.top;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── FAB: only for editable roles ─────────────────────────
      floatingActionButton: _isSupabase
          ? Consumer<SupabaseMenuProvider>(
              builder: (_, provider, __) {
                if (!_canEdit(provider.userRole))
                  return const SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddMenuItemScreen(category: widget.supabaseCategory!),
                    ),
                  ),
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.add, color: Colors.white),
                );
              },
            )
          : null,

      body: _isSupabase
          ? Consumer<SupabaseMenuProvider>(
              builder: (ctx, provider, _) {
                final canEdit = _canEdit(provider.userRole);
                final baseItems = provider.itemsForCategory(_catId);
                final items = _filtered(baseItems);
                final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
                  ctx,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                );

                return Column(
                  children: [
                    _HeroSection(
                      name: _catName,
                      icon: _catIcon,
                      imageUrl: widget.supabaseCategory?.imageUrl,
                      gradientColors: widget.gradientColors,
                      statusBarHeight: statusBarH,
                      onBack: () => Navigator.pop(ctx),
                      itemCount: baseItems.length,
                    ),
                    _SearchAndTagsBar(
                      primaryColor: primaryColor,
                      tags: _tags,
                      selectedTag: _selectedTag,
                      searchCtrl: _searchCtrl,
                      filterActiveCount: _filter.activeCount,
                      onTagSelected: (t) => setState(() => _selectedTag = t),
                      onSearchChanged: (q) => setState(() => _searchQuery = q),
                      onFilterTap: () => _openFilterSheet(ctx, baseItems),
                    ),
                    _StatsRow(items: baseItems, primaryColor: primaryColor),
                    Expanded(
                      child: items.isEmpty
                          ? _EmptyState(
                              searchQuery: _searchQuery,
                              filterCount: _filter.activeCount,
                              canEdit: canEdit,
                            )
                          : RefreshIndicator(
                              color: primaryColor,
                              onRefresh: () =>
                                  provider.loadItemsForCategory(_catId),
                              child: GridView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  AppSizes.paddingLarge,
                                  AppSizes.paddingMedium,
                                  AppSizes.paddingLarge,
                                  AppSizes.paddingLarge + 70,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: AppSizes.paddingMedium,
                                      mainAxisSpacing: AppSizes.paddingMedium,
                                      childAspectRatio: 0.72,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (_, idx) => _SupabaseMenuItemCard(
                                  item: items[idx],
                                  primaryColor: primaryColor,
                                  category: widget.supabaseCategory!,
                                  canEdit: canEdit,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            )
          : const SizedBox(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO
// ═════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final String name;
  final String icon;
  final String? imageUrl;
  final List<Color> gradientColors;
  final double statusBarHeight;
  final VoidCallback onBack;
  final int itemCount;

  const _HeroSection({
    required this.name,
    required this.icon,
    this.imageUrl,
    required this.gradientColors,
    required this.statusBarHeight,
    required this.onBack,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final totalHeight = statusBarHeight + 56 + 80.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.28),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          Positioned(
            right: -8,
            top: statusBarHeight + 4,
            child: Opacity(
              opacity: 0.35,
              child: Text(icon, style: const TextStyle(fontSize: 110)),
            ),
          ),
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
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
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
                Row(children: [_Badge('$itemCount items')]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Container(
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

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH + TAGS BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SearchAndTagsBar extends StatelessWidget {
  final Color primaryColor;
  final List<String> tags;
  final String selectedTag;
  final TextEditingController searchCtrl;
  final int filterActiveCount;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;

  const _SearchAndTagsBar({
    required this.primaryColor,
    required this.tags,
    required this.selectedTag,
    required this.searchCtrl,
    required this.filterActiveCount,
    required this.onTagSelected,
    required this.onSearchChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Expanded(
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
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterBadge(
                  count: filterActiveCount,
                  color: primaryColor,
                  onTap: onFilterTap,
                ),
              ],
            ),
          ),
          if (tags.length > 1)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
                itemCount: tags.length,
                itemBuilder: (_, i) {
                  final tag = tags[i];
                  final sel = tag == selectedTag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onTagSelected(tag),
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
                          tag,
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
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATS ROW
// ═════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final List<SupabaseMenuItem> items;
  final Color primaryColor;

  const _StatsRow({required this.items, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => i.isAvailable).length;
    final best = items.where((i) => i.isBestSeller).length;
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
  Widget build(BuildContext context) => Row(
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

// ═════════════════════════════════════════════════════════════════════════════
//  MENU ITEM CARD (Supabase)
// ═════════════════════════════════════════════════════════════════════════════
class _SupabaseMenuItemCard extends StatelessWidget {
  final SupabaseMenuItem item;
  final Color primaryColor;
  final SupabaseMenuCategory category;
  final bool canEdit; // ← role flag passed from parent

  const _SupabaseMenuItemCard({
    required this.item,
    required this.primaryColor,
    required this.category,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final menuItem = item.toMenuItem(category.name);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              MenuItemDetailScreen(item: menuItem, primaryColor: primaryColor),
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
      // Long-press options only available to editable roles
      onLongPress: canEdit ? () => _showItemOptions(context) : null,
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
            // Image zone
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.borderRadiusLarge),
                    ),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _Placeholder(primaryColor, category.icon),
                          )
                        : _Placeholder(primaryColor, category.icon),
                  ),
                  // Veg indicator
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
                  // Badges
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.isBestSeller)
                          _SmallBadge('🔥 Hot', const Color(0xFFFF6B35)),
                        if (item.isNewArrival)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SmallBadge(
                              '🆕 New',
                              const Color(0xFF2196F3),
                            ),
                          ),
                        if (item.isSpicy)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SmallBadge('🌶️', const Color(0xFFFF5722)),
                          ),
                      ],
                    ),
                  ),
                  // Edit hint dot — only visible to editable roles
                  if (canEdit)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  // Unavailable overlay
                  if (!item.isAvailable)
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info zone
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
                          '${item.preparationTime}m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (item.discountPrice != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFAAAAAA),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${((item.price - item.discountPrice!) / item.price * 100).round()}% off',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF2ECC71),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${(item.discountPrice ?? item.price).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        if (item.isAvailable)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuItemDetailScreen(
                                  item: menuItem,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            ),
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

  void _showItemOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemOptionsSheet(
        item: item,
        category: category,
        primaryColor: primaryColor,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Color color;
  final String icon;
  const _Placeholder(this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    color: color.withOpacity(0.08),
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 52))),
  );
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SmallBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM OPTIONS SHEET — only reachable by editable roles (long-press)
// ─────────────────────────────────────────────────────────────────────────────
class _ItemOptionsSheet extends StatelessWidget {
  final SupabaseMenuItem item;
  final SupabaseMenuCategory category;
  final Color primaryColor;

  const _ItemOptionsSheet({
    required this.item,
    required this.category,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SupabaseMenuProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'By ${item.createdByName} · ${item.createdByRole ?? 'staff'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Item',
            color: primaryColor,
            onTap: () {
              // ── FIX: capture navigator before popping sheet ──
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddMenuItemScreen(category: category, editItem: item),
                ),
              );
            },
          ),
          _OptionTile(
            icon: item.isAvailable
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: item.isAvailable ? 'Mark Unavailable' : 'Mark Available',
            color: item.isAvailable ? Colors.orange : AppColors.success,
            onTap: () async {
              // ── FIX: capture provider before popping sheet ──
              final nav = Navigator.of(context);
              nav.pop();
              await provider.toggleAvailability(
                id: item.id,
                categoryId: item.categoryId,
                isAvailable: !item.isAvailable,
              );
            },
          ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Item',
            color: Colors.red,
            onTap: () async {
              // ── FIX: capture everything BEFORE popping sheet ──
              // After Navigator.pop the sheet's context is dead.
              final navigator = Navigator.of(context);
              final prov = provider; // already read above in build()
              final itemName = item.name;
              final itemId = item.id;
              final categoryId = item.categoryId;
              final imageUrl = item.imageUrl;

              navigator.pop(); // close bottom sheet

              // Show confirm dialog from the live parent context
              final confirm = await showDialog<bool>(
                context: navigator.context,
                builder: (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Delete Item?'),
                  content: Text('Are you sure you want to delete "$itemName"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await prov.deleteItem(
                  id: itemId,
                  categoryId: categoryId,
                  imageUrl: imageUrl,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600, color: color),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final int filterCount;
  final bool canEdit;

  const _EmptyState({
    required this.searchQuery,
    required this.filterCount,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = filterCount > 0;
    final hasSearch = searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.tune_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch
                ? 'No results for "$searchQuery"'
                : hasFilter
                ? 'No items match your filters'
                : canEdit
                ? 'No items yet — tap + to add'
                : 'No items available yet',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/models/menu_filter_modal.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/menu_item_detail_screen.dart';
import 'package:pos_app/screens/add_menu_item_screen.dart';
import 'package:pos_app/screens/widgets/menu_filter_sheet_widget.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/filter_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';

/// Roles allowed to add / edit / delete items.
const Set<String> _editableRoles = {'staff', 'admin', 'system', 'owner'};

bool _canEdit(String? role) =>
    role != null && _editableRoles.contains(role.toLowerCase());

class MenuSubcategoryScreen extends StatefulWidget {
  final SupabaseMenuCategory? supabaseCategory;
  final MenuCategory? category;
  final List<Color> gradientColors;

  const MenuSubcategoryScreen({
    Key? key,
    this.supabaseCategory,
    this.category,
    required this.gradientColors,
  }) : assert(supabaseCategory != null || category != null),
       super(key: key);

  @override
  State<MenuSubcategoryScreen> createState() => _MenuSubcategoryScreenState();
}

class _MenuSubcategoryScreenState extends State<MenuSubcategoryScreen> {
  String _searchQuery = '';
  MenuFilterModel _filter = const MenuFilterModel();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedTag = 'All';
  List<String> _tags = ['All'];
  SupabaseMenuProvider? _cachedProvider;

  bool get _isSupabase => widget.supabaseCategory != null;
  String get _catId => widget.supabaseCategory?.id ?? '';
  String get _catName =>
      widget.supabaseCategory?.name ?? widget.category?.name ?? '';
  String get _catIcon =>
      widget.supabaseCategory?.icon ?? widget.category?.icon ?? '🍽️';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the provider reference for safe access in dispose()
    _cachedProvider = context.read<SupabaseMenuProvider>();
  }

  @override
  void initState() {
    super.initState();
    if (_isSupabase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final p = context.read<SupabaseMenuProvider>();
        p.loadItemsForCategory(_catId).then((_) {
          _buildTags(p.itemsForCategory(_catId));
        });
        p.subscribeItems(_catId);
      });
    }
  }

  void _buildTags(List<SupabaseMenuItem> items) {
    final tagSet = <String>{'All'};
    for (final item in items) {
      for (final t in item.tags) {
        if (t.isNotEmpty) tagSet.add(t);
      }
    }
    if (mounted) setState(() => _tags = tagSet.toList());
  }

  List<SupabaseMenuItem> _filtered(List<SupabaseMenuItem> items) {
    var result = items;

    if (_selectedTag != 'All') {
      result = result.where((i) => i.tags.contains(_selectedTag)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.description.toLowerCase().contains(q),
          )
          .toList();
    }

    final asMenuItems = result.map((e) => e.toMenuItem(_catName)).toList();
    final filtered = _filter.apply(asMenuItems);
    final filteredIds = filtered.map((e) => e.id).toSet();
    return result.where((e) => filteredIds.contains(e.id)).toList();
  }

  Future<void> _openFilterSheet(
    BuildContext ctx,
    List<SupabaseMenuItem> items,
  ) async {
    final menuItems = items.map((e) => e.toMenuItem(_catName)).toList();
    final result = await showMenuFilterSheet(
      context: ctx,
      current: _filter,
      accentColor: widget.gradientColors.first,
      totalItems: menuItems.length,
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  void dispose() {
    // Unsubscribe from the realtime channel for this category
    // so we don't leave orphaned WebSocket channels open on Supabase.
    if (_isSupabase && _cachedProvider != null) {
      _cachedProvider!.unsubscribeItems(_catId);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;
    final statusBarH = MediaQuery.of(context).padding.top;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── FAB: only for editable roles ─────────────────────────
      floatingActionButton: _isSupabase
          ? Consumer<SupabaseMenuProvider>(
              builder: (_, provider, __) {
                if (!_canEdit(provider.userRole))
                  return const SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddMenuItemScreen(category: widget.supabaseCategory!),
                    ),
                  ),
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.add, color: Colors.white),
                );
              },
            )
          : null,

      body: _isSupabase
          ? Consumer<SupabaseMenuProvider>(
              builder: (ctx, provider, _) {
                final canEdit = _canEdit(provider.userRole);
                final baseItems = provider.itemsForCategory(_catId);
                final items = _filtered(baseItems);
                final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
                  ctx,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                );

                return Column(
                  children: [
                    _HeroSection(
                      name: _catName,
                      icon: _catIcon,
                      imageUrl: widget.supabaseCategory?.imageUrl,
                      gradientColors: widget.gradientColors,
                      statusBarHeight: statusBarH,
                      onBack: () => Navigator.pop(ctx),
                      itemCount: baseItems.length,
                    ),
                    _SearchAndTagsBar(
                      primaryColor: primaryColor,
                      tags: _tags,
                      selectedTag: _selectedTag,
                      searchCtrl: _searchCtrl,
                      filterActiveCount: _filter.activeCount,
                      onTagSelected: (t) => setState(() => _selectedTag = t),
                      onSearchChanged: (q) => setState(() => _searchQuery = q),
                      onFilterTap: () => _openFilterSheet(ctx, baseItems),
                    ),
                    _StatsRow(items: baseItems, primaryColor: primaryColor),
                    Expanded(
                      child: items.isEmpty
                          ? _EmptyState(
                              searchQuery: _searchQuery,
                              filterCount: _filter.activeCount,
                              canEdit: canEdit,
                            )
                          : RefreshIndicator(
                              color: primaryColor,
                              onRefresh: () =>
                                  provider.loadItemsForCategory(_catId),
                              child: GridView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  AppSizes.paddingLarge,
                                  AppSizes.paddingMedium,
                                  AppSizes.paddingLarge,
                                  AppSizes.paddingLarge + 70,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: AppSizes.paddingMedium,
                                      mainAxisSpacing: AppSizes.paddingMedium,
                                      childAspectRatio: 0.72,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (_, idx) => _SupabaseMenuItemCard(
                                  item: items[idx],
                                  primaryColor: primaryColor,
                                  category: widget.supabaseCategory!,
                                  canEdit: canEdit,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            )
          : const SizedBox(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO
// ═════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final String name;
  final String icon;
  final String? imageUrl;
  final List<Color> gradientColors;
  final double statusBarHeight;
  final VoidCallback onBack;
  final int itemCount;

  const _HeroSection({
    required this.name,
    required this.icon,
    this.imageUrl,
    required this.gradientColors,
    required this.statusBarHeight,
    required this.onBack,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final totalHeight = statusBarHeight + 56 + 80.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.28),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          Positioned(
            right: -8,
            top: statusBarHeight + 4,
            child: Opacity(
              opacity: 0.35,
              child: Text(icon, style: const TextStyle(fontSize: 110)),
            ),
          ),
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
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
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
                Row(children: [_Badge('$itemCount items')]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Container(
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

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH + TAGS BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SearchAndTagsBar extends StatelessWidget {
  final Color primaryColor;
  final List<String> tags;
  final String selectedTag;
  final TextEditingController searchCtrl;
  final int filterActiveCount;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;

  const _SearchAndTagsBar({
    required this.primaryColor,
    required this.tags,
    required this.selectedTag,
    required this.searchCtrl,
    required this.filterActiveCount,
    required this.onTagSelected,
    required this.onSearchChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Expanded(
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
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterBadge(
                  count: filterActiveCount,
                  color: primaryColor,
                  onTap: onFilterTap,
                ),
              ],
            ),
          ),
          if (tags.length > 1)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
                itemCount: tags.length,
                itemBuilder: (_, i) {
                  final tag = tags[i];
                  final sel = tag == selectedTag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onTagSelected(tag),
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
                          tag,
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
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATS ROW
// ═════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final List<SupabaseMenuItem> items;
  final Color primaryColor;

  const _StatsRow({required this.items, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => i.isAvailable).length;
    final best = items.where((i) => i.isBestSeller).length;
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
  Widget build(BuildContext context) => Row(
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

// ═════════════════════════════════════════════════════════════════════════════
//  MENU ITEM CARD (Supabase)
// ═════════════════════════════════════════════════════════════════════════════
class _SupabaseMenuItemCard extends StatelessWidget {
  final SupabaseMenuItem item;
  final Color primaryColor;
  final SupabaseMenuCategory category;
  final bool canEdit; // ← role flag passed from parent

  const _SupabaseMenuItemCard({
    required this.item,
    required this.primaryColor,
    required this.category,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final menuItem = item.toMenuItem(category.name);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              MenuItemDetailScreen(item: menuItem, primaryColor: primaryColor),
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
      // Long-press options only available to editable roles
      onLongPress: canEdit ? () => _showItemOptions(context) : null,
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
            // Image zone
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.borderRadiusLarge),
                    ),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _Placeholder(primaryColor, category.icon),
                          )
                        : _Placeholder(primaryColor, category.icon),
                  ),
                  // Veg indicator
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
                  // Badges
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.isBestSeller)
                          _SmallBadge('🔥 Hot', const Color(0xFFFF6B35)),
                        if (item.isNewArrival)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SmallBadge(
                              '🆕 New',
                              const Color(0xFF2196F3),
                            ),
                          ),
                        if (item.isSpicy)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SmallBadge('🌶️', const Color(0xFFFF5722)),
                          ),
                      ],
                    ),
                  ),
                  // Edit hint dot — only visible to editable roles
                  if (canEdit)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  // Unavailable overlay
                  if (!item.isAvailable)
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info zone
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
                          '${item.preparationTime}m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (item.discountPrice != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFAAAAAA),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${((item.price - item.discountPrice!) / item.price * 100).round()}% off',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF2ECC71),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${(item.discountPrice ?? item.price).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        if (item.isAvailable)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuItemDetailScreen(
                                  item: menuItem,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            ),
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

  void _showItemOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemOptionsSheet(
        item: item,
        category: category,
        primaryColor: primaryColor,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Color color;
  final String icon;
  const _Placeholder(this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    color: color.withOpacity(0.08),
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 52))),
  );
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SmallBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM OPTIONS SHEET — only reachable by editable roles (long-press)
// ─────────────────────────────────────────────────────────────────────────────
class _ItemOptionsSheet extends StatelessWidget {
  final SupabaseMenuItem item;
  final SupabaseMenuCategory category;
  final Color primaryColor;

  const _ItemOptionsSheet({
    required this.item,
    required this.category,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SupabaseMenuProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'By ${item.createdByName} · ${item.createdByRole ?? 'staff'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Item',
            color: primaryColor,
            onTap: () {
              // ── FIX: capture navigator before popping sheet ──
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddMenuItemScreen(category: category, editItem: item),
                ),
              );
            },
          ),
          _OptionTile(
            icon: item.isAvailable
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: item.isAvailable ? 'Mark Unavailable' : 'Mark Available',
            color: item.isAvailable ? Colors.orange : AppColors.success,
            onTap: () async {
              // ── FIX: capture provider before popping sheet ──
              final nav = Navigator.of(context);
              nav.pop();
              await provider.toggleAvailability(
                id: item.id,
                categoryId: item.categoryId,
                isAvailable: !item.isAvailable,
              );
            },
          ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Item',
            color: Colors.red,
            onTap: () async {
              // ── FIX: capture everything BEFORE popping sheet ──
              // After Navigator.pop the sheet's context is dead.
              final navigator = Navigator.of(context);
              final prov = provider; // already read above in build()
              final itemName = item.name;
              final itemId = item.id;
              final categoryId = item.categoryId;
              final imageUrl = item.imageUrl;

              navigator.pop(); // close bottom sheet

              // Show confirm dialog from the live parent context
              final confirm = await showDialog<bool>(
                context: navigator.context,
                builder: (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Delete Item?'),
                  content: Text('Are you sure you want to delete "$itemName"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await prov.deleteItem(
                  id: itemId,
                  categoryId: categoryId,
                  imageUrl: imageUrl,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600, color: color),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final int filterCount;
  final bool canEdit;

  const _EmptyState({
    required this.searchQuery,
    required this.filterCount,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = filterCount > 0;
    final hasSearch = searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.tune_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch
                ? 'No results for "$searchQuery"'
                : hasFilter
                ? 'No items match your filters'
                : canEdit
                ? 'No items yet — tap + to add'
                : 'No items available yet',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
*/