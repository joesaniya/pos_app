// lib/screens/inventory_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/screens/stock_notification_history_screen.dart';
import 'package:pos_app/screens/supplier_screen.dart';
import 'package:pos_app/screens/widgets/inventory_widgets.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class IColors {
  static const bg = Color(0xFFF5F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF9F8F5);
  static const accent = Color(0xFF1B4D3E);
  static const accentMid = Color(0xFF2D7A5F);
  static const accentLight = Color(0xFFE8F5F0);
  static const inStock = Color(0xFF1E8A5E);
  static const inStockBg = Color(0xFFE6F5EE);
  static const lowStock = Color(0xFFB8800A);
  static const lowStockBg = Color(0xFFFFF3DC);
  static const critical = Color(0xFFCC3300);
  static const criticalBg = Color(0xFFFFEDE8);
  static const outOfStock = Color(0xFF5A5A6E);
  static const outOfStockBg = Color(0xFFF0EFF5);
  static const textPrimary = Color(0xFF1A1A28);
  static const textSecondary = Color(0xFF6B6B80);
  static const textMuted = Color(0xFFAAABBB);
  static const divider = Color(0xFFEEEDF0);
  static const cardShadow = Color(0x14000000);
  static const inputFill = Color(0xFFF2F1EE);

  static const roleOwner = Color(0xFF7C3AED);
  static const roleOwnerBg = Color(0xFFF5F3FF);
  static const roleSystem = Color(0xFF0369A1);
  static const roleSystemBg = Color(0xFFE0F2FE);
  static const roleManager = Color(0xFF2D7A5F);
  static const roleManagerBg = Color(0xFFE8F5F0);
}

Color iStatusColor(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStock;
    case StockStatus.lowStock:
      return IColors.lowStock;
    case StockStatus.critical:
      return IColors.critical;
    case StockStatus.outOfStock:
      return IColors.outOfStock;
  }
}

Color iStatusBg(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStockBg;
    case StockStatus.lowStock:
      return IColors.lowStockBg;
    case StockStatus.critical:
      return IColors.criticalBg;
    case StockStatus.outOfStock:
      return IColors.outOfStockBg;
  }
}

Color roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return IColors.roleOwner;
    case 'system':
      return IColors.roleSystem;
    case 'manager':
      return IColors.roleManager;
    default:
      return IColors.textMuted;
  }
}

Color roleBgColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return IColors.roleOwnerBg;
    case 'system':
      return IColors.roleSystemBg;
    case 'manager':
      return IColors.roleManagerBg;
    default:
      return IColors.surfaceAlt;
  }
}

String roleEmoji(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return '👑';
    case 'system':
      return '⚙️';
    case 'manager':
      return '🧑‍💼';
    default:
      return '👤';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => InventoryProvider(),
    child: const _InventoryBody(),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
class _InventoryBody extends StatefulWidget {
  const _InventoryBody();
  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<InventoryProvider>(
      builder: (context, prov, _) => Scaffold(
        backgroundColor: IColors.bg,
        floatingActionButton: prov.canManageStock
            ? ScaleTransition(
                scale: CurvedAnimation(
                  parent: _fabAnim,
                  curve: Curves.elasticOut,
                ),
                child: _AddFAB(onTap: () => _openAddSheet(context, prov)),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            color: IColors.accent,
            onRefresh: prov.fetchItems,
            child: Column(
              children: [
                _Header(
                  alertCount: prov.lowStockCount + prov.outOfStockCount,
                  onNotifTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationHistoryScreen(),
                    ),
                  ),
                  onSupplierTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                  ),
                ),
                _SearchBar(
                  controller: _searchCtrl,
                  onChanged: prov.setSearch,
                  onFilterTap: () => _openFilterSheet(context, prov),
                ),
                _SummaryStrip(provider: prov),
                _FilterTabBar(
                  current: prov.activeFilter,
                  onChanged: prov.setFilter,
                ),
                _CategoryChips(
                  categories: prov.categories,
                  selected: prov.selectedCategory,
                  onSelected: prov.setCategory,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'My Stocks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: IColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${prov.filteredItems.length} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.textSecondary,
                        ),
                      ),
                      if (prov.userRole.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _RoleBadge(role: prov.userRole, compact: true),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: prov.isLoading && prov.filteredItems.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: IColors.accent,
                          ),
                        )
                      : prov.filteredItems.isEmpty
                      ? const _EmptyState()
                      : _ItemList(
                          items: prov.filteredItems,
                          canManage: prov.canManageStock,
                          onTap: (item) =>
                              _openDetailSheet(context, item, prov),
                          onAddStock: (item) =>
                              _openStockSheet(context, item, prov),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext ctx, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditSheet(provider: prov),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(item: item, provider: prov),
    );
  }

  void _openStockSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockUpdateSheet(item: item, provider: prov),
    );
  }

  void _openFilterSheet(BuildContext ctx, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSortSheet(prov: prov),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROLE BADGE
// ═════════════════════════════════════════════════════════════════════════════
class _RoleBadge extends StatelessWidget {
  final String role;
  final bool compact;
  const _RoleBadge({required this.role, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final bg = roleBgColor(role);
    final label = role.isEmpty
        ? ''
        : role[0].toUpperCase() + role.substring(1).toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(roleEmoji(role), style: TextStyle(fontSize: compact ? 10 : 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final int alertCount;
  final VoidCallback onNotifTap;
  final VoidCallback onSupplierTap;
  const _Header({
    required this.alertCount,
    required this.onNotifTap,
    required this.onSupplierTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: IColors.accent,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      bottom: 16,
    ),
    child: Row(
      children: [
        const Text(
          'Inventory',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),
        const Spacer(),
        /*  GestureDetector(
          onTap: onSupplierTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.store_outlined, color: Colors.white, size: 15),
                SizedBox(width: 5),
                Text(
                  'Suppliers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onNotifTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (alertCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: IColors.accent, width: 2),
                    ),
                    child: Text(
                      '$alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      */
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: IColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search items, suppliers, category...',
                hintStyle: const TextStyle(
                  color: IColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: IColors.textMuted,
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
                          size: 17,
                          color: IColors.textMuted,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: IColors.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: IColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: IColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color: IColors.accentMid,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onFilterTap,
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: IColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: IColors.divider),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: IColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILTER + SORT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _FilterSortSheet extends StatefulWidget {
  final InventoryProvider prov;
  const _FilterSortSheet({required this.prov});
  @override
  State<_FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<_FilterSortSheet> {
  late InventoryFilter _filter;
  late InventorySortBy _sort;

  @override
  void initState() {
    super.initState();
    _filter = widget.prov.activeFilter;
    _sort = widget.prov.sortBy;
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: IColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: [
            const Text(
              'Filter & Sort',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: IColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _filter = InventoryFilter.all;
                _sort = InventorySortBy.name;
              }),
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 13,
                  color: IColors.accentMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'STOCK STATUS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: IColors.textMuted,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(InventoryFilter.all, 'All', ''),
            _filterChip(InventoryFilter.inStock, 'In Stock', '✅'),
            _filterChip(InventoryFilter.lowStock, 'Low Stock', '⚠️'),
            _filterChip(InventoryFilter.critical, 'Critical', '🔴'),
            _filterChip(InventoryFilter.outOfStock, 'Out of Stock', '❌'),
          ],
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'SORT BY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: IColors.textMuted,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...[
          (InventorySortBy.name, 'A–Z Name', '🔤'),
          (InventorySortBy.stockLowHigh, 'Stock: Low → High', '📉'),
          (InventorySortBy.stockHighLow, 'Stock: High → Low', '📈'),
          (InventorySortBy.lastUpdated, 'Recently Updated', '🕐'),
          (InventorySortBy.value, 'Highest Value', '💰'),
        ].map((e) {
          final (sort, label, emoji) = e;
          final isSel = _sort == sort;
          return GestureDetector(
            onTap: () => setState(() => _sort = sort),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? IColors.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? IColors.accentMid : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? IColors.accentMid : IColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isSel)
                    const Icon(
                      Icons.check_circle,
                      color: IColors.accentMid,
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.prov.setFilter(_filter);
              widget.prov.setSortBy(_sort);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _filterChip(InventoryFilter filter, String label, String emoji) {
    final isSel = _filter == filter;
    final Color selColor = isSel
        ? switch (filter) {
            InventoryFilter.inStock => IColors.inStock,
            InventoryFilter.lowStock => IColors.lowStock,
            InventoryFilter.critical => IColors.critical,
            InventoryFilter.outOfStock => IColors.outOfStock,
            _ => IColors.accentMid,
          }
        : IColors.textMuted;

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? selColor.withOpacity(0.12) : IColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? selColor : IColors.divider,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSel ? selColor : IColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUMMARY STRIP
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryStrip extends StatelessWidget {
  final InventoryProvider provider;
  const _SummaryStrip({required this.provider});

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 90,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        _MetricCard(
          label: 'Total Value',
          value: _fmt(provider.totalInventoryValue),
          emoji: '💰',
          color: IColors.accent,
        ),
        _MetricCard(
          label: 'Total Items',
          value: '${provider.totalItems}',
          emoji: '📦',
          color: const Color(0xFF0077CC),
        ),
        _MetricCard(
          label: 'Low / Critical',
          value: '${provider.lowStockCount}',
          emoji: '⚠️',
          color: IColors.lowStock,
        ),
        _MetricCard(
          label: 'Out of Stock',
          value: '${provider.outOfStockCount}',
          emoji: '❌',
          color: IColors.critical,
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: IColors.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: IColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILTER TAB BAR
// ═════════════════════════════════════════════════════════════════════════════
class _FilterTabBar extends StatelessWidget {
  final InventoryFilter current;
  final ValueChanged<InventoryFilter> onChanged;
  const _FilterTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (InventoryFilter.all, 'All', ''),
      (InventoryFilter.inStock, 'In Stock', '✅'),
      (InventoryFilter.lowStock, 'Low', '⚠️'),
      (InventoryFilter.critical, 'Critical', '🔴'),
      (InventoryFilter.outOfStock, 'Out', '❌'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tabs.map((tab) {
          final (filter, label, emoji) = tab;
          final isSel = current == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSel ? IColors.accent : IColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? IColors.accent : IColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty) ...[
                      Text(emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CATEGORY CHIPS
// ═════════════════════════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      children: categories.map((cat) {
        final isSel = selected == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSel ? IColors.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSel ? IColors.accentMid : Colors.transparent,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? IColors.accentMid : IColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ITEM GRID
// ═════════════════════════════════════════════════════════════════════════════
class _ItemList extends StatelessWidget {
  final List<InventoryItem> items;
  final bool canManage;
  final ValueChanged<InventoryItem> onTap;
  final ValueChanged<InventoryItem> onAddStock;
  const _ItemList({
    required this.items,
    required this.canManage,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => InventoryItemCardWidgets(
      item: items[i],
      canManage: canManage,
      onTap: () => onTap(items[i]),
      onAddStock: () => onAddStock(items[i]),
    ),
  );
}

class _InventoryGridItem extends StatelessWidget {
  final InventoryItem item;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onAddStock;
  const _InventoryGridItem({
    required this.item,
    required this.canManage,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);
    final bgColor = iStatusBg(item.status);
    final isCritical =
        item.status == StockStatus.critical ||
        item.status == StockStatus.outOfStock;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCritical ? color.withOpacity(0.4) : IColors.divider,
            width: isCritical ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: IColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top color bar + emoji ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Big emoji
                  Text(item.emoji, style: const TextStyle(fontSize: 30)),
                  const Spacer(),
                  // Status badge (compact dot style)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _shortStatus(item.status),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Name + category ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: IColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 10,
                      color: IColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Stock bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: StockBar(
                percent: item.stockPercent,
                height: 5,
                status: item.status,
              ),
            ),

            // ── Stock numbers ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.stockDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'of ${item.maxCapacity.toInt()} ${item.unit.label}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: IColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Add stock button
                  if (canManage)
                    GestureDetector(
                      onTap: onAddStock,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: IColors.accent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: IColors.accent.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Price row ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: IColors.surfaceAlt,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(17),
                ),
                border: Border(top: BorderSide(color: IColors.divider)),
              ),
              child: Text(
                '₹${item.costPerUnit.toInt()} / ${item.unit.label}  ·  Min ${item.minThreshold.toInt()}',
                style: const TextStyle(
                  fontSize: 9,
                  color: IColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortStatus(StockStatus s) {
    switch (s) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low';
      case StockStatus.critical:
        return 'Critical';
      case StockStatus.outOfStock:
        return 'Out';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  const _DetailSheet({required this.item, required this.provider});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late InventoryItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(_item.status);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            SheetHeader(
              title: _item.name,
              subtitle: '${_item.category} · ${_item.supplier}',
              emoji: _item.emoji,
              accentColor: color,
            ),
            Container(
              color: IColors.surface,
              child: TabBar(
                controller: _tabs,
                labelColor: IColors.accent,
                unselectedLabelColor: IColors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: IColors.accent,
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(text: 'Overview'),
                  // Tab(text: 'Actions'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            const Divider(height: 1, color: IColors.divider),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(
                    item: _item,
                    provider: widget.provider,
                    onRefresh: (updated) => setState(() => _item = updated),
                  ),
                  /* _ActionsTab(
                    item: _item,
                    provider: widget.provider,
                    onRefresh: (updated) => setState(() => _item = updated),
                  ),*/
                  _HistoryTab(item: _item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final ValueChanged<InventoryItem> onRefresh;
  const _OverviewTab({
    required this.item,
    required this.provider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: iStatusBg(item.status),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: IColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.stockDisplay,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  StockStatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: 14),
              StockBar(
                percent: item.stockPercent,
                height: 12,
                status: item.status,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Min: ${item.minThreshold.toInt()} ${item.unit.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(item.stockPercent * 100).toInt()}% of capacity',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Max: ${item.maxCapacity.toInt()} ${item.unit.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'Cost / Unit',
                value: '₹${item.costPerUnit.toInt()}/${item.unit.label}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Total Value',
                value: '₹${item.totalValue.toInt()}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Supplier', value: item.supplier),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Last Updated',
                value: item.lastUpdatedLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Category', value: item.category),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(label: 'Unit Type', value: item.unit.label),
            ),
          ],
        ),
        if (item.notes != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD97706).withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: IColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ActionButtonWidget(
                      label: 'Add Stock',
                      emoji: '📥',
                      color: IColors.inStock,
                      onTap: () => _open(context, TransactionType.stockIn),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionButtonWidget(
                      label: 'Edit Item',
                      emoji: '✏️',
                      color: IColors.accentMid,
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              _AddEditSheet(provider: provider, editItem: item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconActionButtonWidgets(
                    icon: Icons.delete_outline_rounded,
                    color: IColors.critical,
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ), // control layout width
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 160,
                        child: ActionButtonWidget(
                          label: 'Use Stock (Stock Out)',
                          emoji: '📤',
                          color: IColors.lowStock,
                          onTap: () => _open(context, TransactionType.stockOut),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: ActionButtonWidget(
                          label: 'Adjust Stock',
                          emoji: '🔧',
                          color: IColors.accentMid,
                          onTap: () =>
                              _open(context, TransactionType.adjustment),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: ActionButtonWidget(
                          label: 'Mark as Waste',
                          emoji: '🗑️',
                          color: IColors.critical,
                          onTap: () => _open(context, TransactionType.waste),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
      ],
    );
  }

  void _open(BuildContext ctx, TransactionType type) {
    Navigator.pop(ctx);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _StockUpdateSheet(item: item, provider: provider, initialType: type),
    );
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${item.name}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will remove the item from inventory.',
          style: TextStyle(color: IColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: IColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteItem(item.id);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Actions Tab ───────────────────────────────────────────────────────────────
class _ActionsTab extends StatelessWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final ValueChanged<InventoryItem> onRefresh;
  const _ActionsTab({
    required this.item,
    required this.provider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!provider.canManageStock) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: IColors.criticalBg,
                  shape: BoxShape.circle,
                ),
                child: const Text('🔒', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: IColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stock management is restricted to\nOwner, System and Manager roles only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: IColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoleBadge(role: 'owner'),
                  const SizedBox(width: 8),
                  _RoleBadge(role: 'system'),
                  const SizedBox(width: 8),
                  _RoleBadge(role: 'manager'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _ActionButton2(
          label: 'Add Stock (Stock In)',
          emoji: '📥',
          color: IColors.inStock,
          onTap: () => _open(context, TransactionType.stockIn),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Use Stock (Stock Out)',
          emoji: '📤',
          color: IColors.lowStock,
          onTap: () => _open(context, TransactionType.stockOut),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Adjust Stock',
          emoji: '🔧',
          color: IColors.accentMid,
          onTap: () => _open(context, TransactionType.adjustment),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Mark as Waste',
          emoji: '🗑️',
          color: IColors.critical,
          onTap: () => _open(context, TransactionType.waste),
        ),
        const SizedBox(height: 20),
        _ActionButton2(
          label: 'Edit Item Details',
          emoji: '✏️',
          color: const Color(0xFF0077CC),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _AddEditSheet(provider: provider, editItem: item),
            );
          },
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Delete Item',
          emoji: '🗑️',
          color: IColors.critical,
          outlined: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _open(BuildContext ctx, TransactionType type) {
    Navigator.pop(ctx);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _StockUpdateSheet(item: item, provider: provider, initialType: type),
    );
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${item.name}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will remove the item from inventory.',
          style: TextStyle(color: IColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: IColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteItem(item.id);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton2 extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionButton2({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(outlined ? 0.5 : 0.25),
          width: outlined ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: color.withOpacity(0.6),
          ),
        ],
      ),
    ),
  );
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final InventoryItem item;
  const _HistoryTab({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transaction history',
          style: TextStyle(color: IColors.textMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'Total Transactions',
                value: '${item.transactions.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Stock Ins',
                value:
                    '${item.transactions.where((t) => t.type == TransactionType.stockIn).length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Stock Outs',
                value:
                    '${item.transactions.where((t) => t.type == TransactionType.stockOut).length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: IColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IColors.divider),
          ),
          child: Column(
            children: item.transactions
                .map(
                  (tx) => Column(
                    children: [
                      _TransactionRow(tx: tx, unit: item.unit),
                      if (tx != item.transactions.last)
                        const Divider(height: 1, color: IColors.divider),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final StockTransaction tx;
  final StockUnit unit;
  const _TransactionRow({required this.tx, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isPos = tx.type.isPositive;
    final color = isPos ? IColors.inStock : IColors.critical;
    final sign = isPos ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(tx.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IColors.textPrimary,
                  ),
                ),
                Text(
                  tx.note,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: IColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tx.updatedBy,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: IColors.textSecondary,
                      ),
                    ),
                    if (tx.updatedByRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleBgColor(tx.updatedByRole),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: roleColor(tx.updatedByRole).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              roleEmoji(tx.updatedByRole),
                              style: const TextStyle(fontSize: 9),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tx.updatedByRole[0].toUpperCase() +
                                  tx.updatedByRole.substring(1).toLowerCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: roleColor(tx.updatedByRole),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${tx.quantity.toInt()} ${unit.label}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (tx.stockBefore > 0 || tx.stockAfter > 0)
                Text(
                  '${tx.stockBefore.toInt()} → ${tx.stockAfter.toInt()} ${unit.label}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: IColors.textMuted,
                  ),
                ),
              Text(
                _timeLabel(tx.date),
                style: const TextStyle(fontSize: 10, color: IColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STOCK UPDATE SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _StockUpdateSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final TransactionType initialType;
  const _StockUpdateSheet({
    required this.item,
    required this.provider,
    this.initialType = TransactionType.stockIn,
  });
  @override
  State<_StockUpdateSheet> createState() => _StockUpdateSheetState();
}

class _StockUpdateSheetState extends State<_StockUpdateSheet> {
  late TransactionType _type;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Update Stock',
            subtitle: widget.item.name,
            emoji: widget.item.emoji,
            accentColor: IColors.accentMid,
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: roleBgColor(widget.provider.userRole),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: roleColor(widget.provider.userRole).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Text(
                  roleEmoji(widget.provider.userRole),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updating as ${widget.provider.userName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: roleColor(widget.provider.userRole),
                        ),
                      ),
                      const Text(
                        'This action will be logged with your role',
                        style: TextStyle(
                          fontSize: 10,
                          color: IColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoleBadge(role: widget.provider.userRole, compact: true),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetSection(title: 'Transaction Type'),
                  _TxTypeSelector(
                    selected: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: 16),
                  InventoryField(
                    label: 'Quantity *',
                    hint: 'Enter quantity',
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: widget.item.unit.label,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Must be a number';
                      if (double.parse(v) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  InventoryField(
                    label: 'Note',
                    hint: 'Reason for update...',
                    controller: _noteCtrl,
                    isLast: true,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: IColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: IColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: IColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.item.stockDisplay,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: IColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StockStatusBadge(
                          status: widget.item.status,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirm Update',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.provider.recordTransaction(
      itemId: widget.item.id,
      type: _type,
      quantity: double.parse(_qtyCtrl.text),
      note: _noteCtrl.text.isEmpty ? '—' : _noteCtrl.text,
      updatedBy: widget.provider.userName,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _TxTypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  const _TxTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      (TransactionType.stockIn, '📥', 'Stock In', IColors.inStock),
      (TransactionType.stockOut, '📤', 'Stock Out', IColors.lowStock),
      (TransactionType.adjustment, '🔧', 'Adjust', IColors.accentMid),
      (TransactionType.waste, '🗑️', 'Waste', IColors.critical),
    ];
    return Row(
      children: types.map((t) {
        final (type, emoji, label, color) = t;
        final isSel = selected == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? color.withOpacity(0.12) : IColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? color : IColors.divider,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSel ? color : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddEditSheet extends StatefulWidget {
  final InventoryProvider provider;
  final InventoryItem? editItem;
  const _AddEditSheet({required this.provider, this.editItem});
  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl,
      _supplierCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
      _notesCtrl;
  StockUnit _unit = StockUnit.kg;
  String _category = 'Grains';
  String _emoji = '📦';
  bool _loading = false;
  String? _errorMsg;

  bool get isEditing => widget.editItem != null;

  static const _categories = [
    'Grains',
    'Pulses',
    'Vegetables',
    'Dairy',
    'Oils',
    'Spices',
    'Herbs',
    'Beverages',
    'Packaging',
    'Other',
  ];
  static const _emojis = [
    '🍚',
    '🫘',
    '🥔',
    '🍅',
    '🧅',
    '🌶️',
    '🥬',
    '🧄',
    '🫚',
    '🧈',
    '🥛',
    '🌻',
    '🥥',
    '🌿',
    '🌱',
    '📦',
    '🫙',
    '🍶',
    '🥚',
    '🧂',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _stockCtrl = TextEditingController(
      text: e != null ? '${e.currentStock}' : '',
    );
    _minCtrl = TextEditingController(
      text: e != null ? '${e.minThreshold}' : '',
    );
    _maxCtrl = TextEditingController(text: e != null ? '${e.maxCapacity}' : '');
    _costCtrl = TextEditingController(
      text: e != null ? '${e.costPerUnit}' : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _unit = e?.unit ?? StockUnit.kg;
    _category = e?.category ?? 'Grains';
    _emoji = e?.emoji ?? '📦';
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _supplierCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            SheetHeader(
              title: isEditing ? 'Edit Item' : 'Add New Item',
              subtitle: isEditing
                  ? 'Update inventory record'
                  : 'Create a new stock entry',
              emoji: isEditing ? '✏️' : '➕',
              accentColor: IColors.accentMid,
            ),
            // Role banner
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: roleBgColor(widget.provider.userRole),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: roleColor(widget.provider.userRole).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    roleEmoji(widget.provider.userRole),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isEditing ? "Editing" : "Adding"} as ${widget.provider.userName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: roleColor(widget.provider.userRole),
                      ),
                    ),
                  ),
                  _RoleBadge(role: widget.provider.userRole, compact: true),
                ],
              ),
            ),
            // Error banner
            if (_errorMsg != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: IColors.criticalBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: IColors.critical.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: IColors.critical,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMsg = null),
                      child: const Icon(
                        Icons.close,
                        color: IColors.critical,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  // Emoji picker
                  const SheetSection(title: 'Pick an Emoji'),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final isSel = _emoji == _emojis[i];
                        return GestureDetector(
                          onTap: () => setState(() => _emoji = _emojis[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? IColors.accentLight
                                  : IColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? IColors.accentMid
                                    : IColors.divider,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              _emojis[i],
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Basic info
                  const SheetSection(title: 'Basic Information'),
                  InventoryField(
                    label: 'Item Name *',
                    hint: 'e.g. Rice Batter',
                    controller: _nameCtrl,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  InventoryField(
                    label: 'Supplier Name',
                    hint: 'e.g. Sri Annapoorna Traders',
                    controller: _supplierCtrl,
                  ),
                  // Category
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((c) {
                            final isSel = _category == c;
                            return GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? IColors.accentLight
                                      : IColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.divider,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Unit
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: StockUnit.values.map((u) {
                            final isSel = _unit == u;
                            return GestureDetector(
                              onTap: () => setState(() => _unit = u),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? IColors.accentLight
                                      : IColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.divider,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  u.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Stock levels
                  const SheetSection(title: 'Stock Levels'),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryField(
                          label: 'Current Stock *',
                          hint: '0',
                          controller: _stockCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryField(
                          label: 'Min Threshold *',
                          hint: '0',
                          controller: _minCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryField(
                          label: 'Max Capacity *',
                          hint: '100',
                          controller: _maxCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryField(
                          label: 'Cost / Unit *',
                          hint: '0',
                          controller: _costCtrl,
                          prefix: '₹',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  InventoryField(
                    label: 'Notes',
                    hint: 'Any special instructions...',
                    controller: _notesCtrl,
                    isLast: true,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add to Inventory',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    // Wait for provider init
    if (!widget.provider.isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !widget.provider.isInitialized;
      });
    }

    final e = widget.editItem;
    log(
      '[AddEditSheet] Submitting form — name="${_nameCtrl.text}", '
      'stock="${_stockCtrl.text}", min="${_minCtrl.text}", max="${_maxCtrl.text}", '
      'cost="${_costCtrl.text}", supplier="${_supplierCtrl.text}", '
      'category="$_category", emoji="$_emoji", unit="${_unit.label}"',
    );

    final item = InventoryItem(
      id: e?.id ?? widget.provider.generateId(),
      name: _nameCtrl.text.trim(),
      category: _category,
      emoji: _emoji,
      currentStock: double.tryParse(_stockCtrl.text) ?? 0,
      minThreshold: double.tryParse(_minCtrl.text) ?? 0,
      maxCapacity: double.tryParse(_maxCtrl.text) ?? 100,
      unit: _unit,
      costPerUnit: double.tryParse(_costCtrl.text) ?? 0,
      supplier: _supplierCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _supplierCtrl.text.trim(),
      lastUpdated: DateTime.now(),
      transactions: e?.transactions ?? [],
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    log(
      '[AddEditSheet] InventoryItem built — name=${item.name}, isEditing=$isEditing, '
      'role=${widget.provider.userRole}, businessReady=${widget.provider.isInitialized}',
    );

    final success = isEditing
        ? await widget.provider.updateItem(item)
        : await widget.provider.addItem(item);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() {
          _loading = false;
          _errorMsg = widget.provider.errorMessage.isNotEmpty
              ? widget.provider.errorMessage
              : 'Failed to save item. Please try again.';
        });
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED MICRO WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: IColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: IColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: IColors.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IColors.accentLight,
            shape: BoxShape.circle,
          ),
          child: const Text('📦', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 16),
        const Text(
          'No items found',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try adjusting your search or filters',
          style: TextStyle(fontSize: 13, color: IColors.textSecondary),
        ),
      ],
    ),
  );
}

class _AddFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFAB({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IColors.accent, IColors.accentMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: IColors.accent.withOpacity(0.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Add Item',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

/*supbase fn added completed
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/screens/stock_notification_history_screen.dart';
import 'package:pos_app/screens/supplier_screen.dart';
import 'package:pos_app/screens/widgets/inventory_widgets.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class IColors {
  static const bg = Color(0xFFF5F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF9F8F5);
  static const accent = Color(0xFF1B4D3E);
  static const accentMid = Color(0xFF2D7A5F);
  static const accentLight = Color(0xFFE8F5F0);
  static const inStock = Color(0xFF1E8A5E);
  static const inStockBg = Color(0xFFE6F5EE);
  static const lowStock = Color(0xFFB8800A);
  static const lowStockBg = Color(0xFFFFF3DC);
  static const critical = Color(0xFFCC3300);
  static const criticalBg = Color(0xFFFFEDE8);
  static const outOfStock = Color(0xFF5A5A6E);
  static const outOfStockBg = Color(0xFFF0EFF5);
  static const textPrimary = Color(0xFF1A1A28);
  static const textSecondary = Color(0xFF6B6B80);
  static const textMuted = Color(0xFFAAABBB);
  static const divider = Color(0xFFEEEDF0);
  static const cardShadow = Color(0x14000000);
  static const inputFill = Color(0xFFF2F1EE);

  static const roleOwner = Color(0xFF7C3AED);
  static const roleOwnerBg = Color(0xFFF5F3FF);
  static const roleSystem = Color(0xFF0369A1);
  static const roleSystemBg = Color(0xFFE0F2FE);
  static const roleManager = Color(0xFF2D7A5F);
  static const roleManagerBg = Color(0xFFE8F5F0);
}

Color iStatusColor(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStock;
    case StockStatus.lowStock:
      return IColors.lowStock;
    case StockStatus.critical:
      return IColors.critical;
    case StockStatus.outOfStock:
      return IColors.outOfStock;
  }
}

Color iStatusBg(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStockBg;
    case StockStatus.lowStock:
      return IColors.lowStockBg;
    case StockStatus.critical:
      return IColors.criticalBg;
    case StockStatus.outOfStock:
      return IColors.outOfStockBg;
  }
}

Color roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return IColors.roleOwner;
    case 'system':
      return IColors.roleSystem;
    case 'manager':
      return IColors.roleManager;
    default:
      return IColors.textMuted;
  }
}

Color roleBgColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return IColors.roleOwnerBg;
    case 'system':
      return IColors.roleSystemBg;
    case 'manager':
      return IColors.roleManagerBg;
    default:
      return IColors.surfaceAlt;
  }
}

String roleEmoji(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
      return '👑';
    case 'system':
      return '⚙️';
    case 'manager':
      return '🧑‍💼';
    default:
      return '👤';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => InventoryProvider(),
    child: const _InventoryBody(),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
class _InventoryBody extends StatefulWidget {
  const _InventoryBody();
  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<InventoryProvider>(
      builder: (context, prov, _) => Scaffold(
        backgroundColor: IColors.bg,
        floatingActionButton: prov.canManageStock
            ? ScaleTransition(
                scale: CurvedAnimation(
                  parent: _fabAnim,
                  curve: Curves.elasticOut,
                ),
                child: _AddFAB(onTap: () => _openAddSheet(context, prov)),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            color: IColors.accent,
            onRefresh: prov.fetchItems,
            child: Column(
              children: [
                _Header(
                  alertCount: prov.lowStockCount + prov.outOfStockCount,
                  onNotifTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationHistoryScreen(),
                    ),
                  ),
                  onSupplierTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                  ),
                ),
                _SearchBar(
                  controller: _searchCtrl,
                  onChanged: prov.setSearch,
                  onFilterTap: () => _openFilterSheet(context, prov),
                ),
                _SummaryStrip(provider: prov),
                _FilterTabBar(
                  current: prov.activeFilter,
                  onChanged: prov.setFilter,
                ),
                _CategoryChips(
                  categories: prov.categories,
                  selected: prov.selectedCategory,
                  onSelected: prov.setCategory,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'My Stocks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: IColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${prov.filteredItems.length} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.textSecondary,
                        ),
                      ),
                      if (prov.userRole.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _RoleBadge(role: prov.userRole, compact: true),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: prov.isLoading && prov.filteredItems.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: IColors.accent,
                          ),
                        )
                      : prov.filteredItems.isEmpty
                      ? const _EmptyState()
                      : _ItemList(
                          items: prov.filteredItems,
                          canManage: prov.canManageStock,
                          onTap: (item) =>
                              _openDetailSheet(context, item, prov),
                          onAddStock: (item) =>
                              _openStockSheet(context, item, prov),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext ctx, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditSheet(provider: prov),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(item: item, provider: prov),
    );
  }

  void _openStockSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockUpdateSheet(item: item, provider: prov),
    );
  }

  void _openFilterSheet(BuildContext ctx, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSortSheet(prov: prov),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROLE BADGE
// ═════════════════════════════════════════════════════════════════════════════
class _RoleBadge extends StatelessWidget {
  final String role;
  final bool compact;
  const _RoleBadge({required this.role, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final bg = roleBgColor(role);
    final label = role.isEmpty
        ? ''
        : role[0].toUpperCase() + role.substring(1).toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(roleEmoji(role), style: TextStyle(fontSize: compact ? 10 : 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final int alertCount;
  final VoidCallback onNotifTap;
  final VoidCallback onSupplierTap;
  const _Header({
    required this.alertCount,
    required this.onNotifTap,
    required this.onSupplierTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: IColors.accent,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      bottom: 16,
    ),
    child: Row(
      children: [
        const Text(
          'Inventory',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSupplierTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.store_outlined, color: Colors.white, size: 15),
                SizedBox(width: 5),
                Text(
                  'Suppliers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onNotifTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (alertCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: IColors.accent, width: 2),
                    ),
                    child: Text(
                      '$alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: IColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search items, suppliers, category...',
                hintStyle: const TextStyle(
                  color: IColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: IColors.textMuted,
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
                          size: 17,
                          color: IColors.textMuted,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: IColors.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: IColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: IColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color: IColors.accentMid,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onFilterTap,
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: IColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: IColors.divider),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: IColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILTER + SORT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _FilterSortSheet extends StatefulWidget {
  final InventoryProvider prov;
  const _FilterSortSheet({required this.prov});
  @override
  State<_FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<_FilterSortSheet> {
  late InventoryFilter _filter;
  late InventorySortBy _sort;

  @override
  void initState() {
    super.initState();
    _filter = widget.prov.activeFilter;
    _sort = widget.prov.sortBy;
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: IColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: [
            const Text(
              'Filter & Sort',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: IColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _filter = InventoryFilter.all;
                _sort = InventorySortBy.name;
              }),
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 13,
                  color: IColors.accentMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'STOCK STATUS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: IColors.textMuted,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(InventoryFilter.all, 'All', ''),
            _filterChip(InventoryFilter.inStock, 'In Stock', '✅'),
            _filterChip(InventoryFilter.lowStock, 'Low Stock', '⚠️'),
            _filterChip(InventoryFilter.critical, 'Critical', '🔴'),
            _filterChip(InventoryFilter.outOfStock, 'Out of Stock', '❌'),
          ],
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'SORT BY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: IColors.textMuted,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...[
          (InventorySortBy.name, 'A–Z Name', '🔤'),
          (InventorySortBy.stockLowHigh, 'Stock: Low → High', '📉'),
          (InventorySortBy.stockHighLow, 'Stock: High → Low', '📈'),
          (InventorySortBy.lastUpdated, 'Recently Updated', '🕐'),
          (InventorySortBy.value, 'Highest Value', '💰'),
        ].map((e) {
          final (sort, label, emoji) = e;
          final isSel = _sort == sort;
          return GestureDetector(
            onTap: () => setState(() => _sort = sort),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? IColors.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? IColors.accentMid : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? IColors.accentMid : IColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isSel)
                    const Icon(
                      Icons.check_circle,
                      color: IColors.accentMid,
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.prov.setFilter(_filter);
              widget.prov.setSortBy(_sort);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _filterChip(InventoryFilter filter, String label, String emoji) {
    final isSel = _filter == filter;
    final Color selColor = isSel
        ? switch (filter) {
            InventoryFilter.inStock => IColors.inStock,
            InventoryFilter.lowStock => IColors.lowStock,
            InventoryFilter.critical => IColors.critical,
            InventoryFilter.outOfStock => IColors.outOfStock,
            _ => IColors.accentMid,
          }
        : IColors.textMuted;

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? selColor.withOpacity(0.12) : IColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? selColor : IColors.divider,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSel ? selColor : IColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUMMARY STRIP
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryStrip extends StatelessWidget {
  final InventoryProvider provider;
  const _SummaryStrip({required this.provider});

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 90,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        _MetricCard(
          label: 'Total Value',
          value: _fmt(provider.totalInventoryValue),
          emoji: '💰',
          color: IColors.accent,
        ),
        _MetricCard(
          label: 'Total Items',
          value: '${provider.totalItems}',
          emoji: '📦',
          color: const Color(0xFF0077CC),
        ),
        _MetricCard(
          label: 'Low / Critical',
          value: '${provider.lowStockCount}',
          emoji: '⚠️',
          color: IColors.lowStock,
        ),
        _MetricCard(
          label: 'Out of Stock',
          value: '${provider.outOfStockCount}',
          emoji: '❌',
          color: IColors.critical,
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: IColors.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: IColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILTER TAB BAR
// ═════════════════════════════════════════════════════════════════════════════
class _FilterTabBar extends StatelessWidget {
  final InventoryFilter current;
  final ValueChanged<InventoryFilter> onChanged;
  const _FilterTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (InventoryFilter.all, 'All', ''),
      (InventoryFilter.inStock, 'In Stock', '✅'),
      (InventoryFilter.lowStock, 'Low', '⚠️'),
      (InventoryFilter.critical, 'Critical', '🔴'),
      (InventoryFilter.outOfStock, 'Out', '❌'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tabs.map((tab) {
          final (filter, label, emoji) = tab;
          final isSel = current == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSel ? IColors.accent : IColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? IColors.accent : IColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty) ...[
                      Text(emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CATEGORY CHIPS
// ═════════════════════════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      children: categories.map((cat) {
        final isSel = selected == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSel ? IColors.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSel ? IColors.accentMid : Colors.transparent,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? IColors.accentMid : IColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ITEM LIST
// ═════════════════════════════════════════════════════════════════════════════
class _ItemList extends StatelessWidget {
  final List<InventoryItem> items;
  final bool canManage;
  final ValueChanged<InventoryItem> onTap;
  final ValueChanged<InventoryItem> onAddStock;
  const _ItemList({
    required this.items,
    required this.canManage,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: items.length,
    itemBuilder: (_, i) => _InventoryListItem(
      item: items[i],
      canManage: canManage,
      onTap: () => onTap(items[i]),
      onAddStock: () => onAddStock(items[i]),
    ),
  );
}

class _InventoryListItem extends StatelessWidget {
  final InventoryItem item;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onAddStock;
  const _InventoryListItem({
    required this.item,
    required this.canManage,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);
    final isCritical =
        item.status == StockStatus.critical ||
        item.status == StockStatus.outOfStock;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCritical ? color.withOpacity(0.35) : IColors.divider,
            width: isCritical ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: IColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: IColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      item.category,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: IColors.textMuted,
                                      ),
                                    ),
                                    const Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: IColors.textMuted,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.supplier,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: IColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          StockStatusBadge(status: item.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StockBar(
                        percent: item.stockPercent,
                        height: 6,
                        status: item.status,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            item.stockDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          Text(
                            ' / ${item.maxCapacity.toInt()} ${item.unit.label}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: IColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Min: ${item.minThreshold.toInt()} ${item.unit.label}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: IColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${item.costPerUnit.toInt()}/${item.unit.label}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: IColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (canManage) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: onAddStock,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: IColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: IColors.accentMid,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  const _DetailSheet({required this.item, required this.provider});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late InventoryItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(_item.status);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            SheetHeader(
              title: _item.name,
              subtitle: '${_item.category} · ${_item.supplier}',
              emoji: _item.emoji,
              accentColor: color,
            ),
            Container(
              color: IColors.surface,
              child: TabBar(
                controller: _tabs,
                labelColor: IColors.accent,
                unselectedLabelColor: IColors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: IColors.accent,
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Actions'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            const Divider(height: 1, color: IColors.divider),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(item: _item),
                  _ActionsTab(
                    item: _item,
                    provider: widget.provider,
                    onRefresh: (updated) => setState(() => _item = updated),
                  ),
                  _HistoryTab(item: _item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final InventoryItem item;
  const _OverviewTab({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: iStatusBg(item.status),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: IColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.stockDisplay,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  StockStatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: 14),
              StockBar(
                percent: item.stockPercent,
                height: 12,
                status: item.status,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Min: ${item.minThreshold.toInt()} ${item.unit.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(item.stockPercent * 100).toInt()}% of capacity',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Max: ${item.maxCapacity.toInt()} ${item.unit.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'Cost / Unit',
                value: '₹${item.costPerUnit.toInt()}/${item.unit.label}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Total Value',
                value: '₹${item.totalValue.toInt()}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Supplier', value: item.supplier),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Last Updated',
                value: item.lastUpdatedLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Category', value: item.category),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(label: 'Unit Type', value: item.unit.label),
            ),
          ],
        ),
        if (item.notes != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD97706).withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: IColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Actions Tab ───────────────────────────────────────────────────────────────
class _ActionsTab extends StatelessWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final ValueChanged<InventoryItem> onRefresh;
  const _ActionsTab({
    required this.item,
    required this.provider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!provider.canManageStock) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: IColors.criticalBg,
                  shape: BoxShape.circle,
                ),
                child: const Text('🔒', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: IColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stock management is restricted to\nOwner, System and Manager roles only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: IColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoleBadge(role: 'owner'),
                  const SizedBox(width: 8),
                  _RoleBadge(role: 'system'),
                  const SizedBox(width: 8),
                  _RoleBadge(role: 'manager'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _ActionButton2(
          label: 'Add Stock (Stock In)',
          emoji: '📥',
          color: IColors.inStock,
          onTap: () => _open(context, TransactionType.stockIn),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Use Stock (Stock Out)',
          emoji: '📤',
          color: IColors.lowStock,
          onTap: () => _open(context, TransactionType.stockOut),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Adjust Stock',
          emoji: '🔧',
          color: IColors.accentMid,
          onTap: () => _open(context, TransactionType.adjustment),
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Mark as Waste',
          emoji: '🗑️',
          color: IColors.critical,
          onTap: () => _open(context, TransactionType.waste),
        ),
        const SizedBox(height: 20),
        _ActionButton2(
          label: 'Edit Item Details',
          emoji: '✏️',
          color: const Color(0xFF0077CC),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _AddEditSheet(provider: provider, editItem: item),
            );
          },
        ),
        const SizedBox(height: 10),
        _ActionButton2(
          label: 'Delete Item',
          emoji: '🗑️',
          color: IColors.critical,
          outlined: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _open(BuildContext ctx, TransactionType type) {
    Navigator.pop(ctx);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _StockUpdateSheet(item: item, provider: provider, initialType: type),
    );
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${item.name}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will remove the item from inventory.',
          style: TextStyle(color: IColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: IColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteItem(item.id);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton2 extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionButton2({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(outlined ? 0.5 : 0.25),
          width: outlined ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: color.withOpacity(0.6),
          ),
        ],
      ),
    ),
  );
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final InventoryItem item;
  const _HistoryTab({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transaction history',
          style: TextStyle(color: IColors.textMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'Total Transactions',
                value: '${item.transactions.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Stock Ins',
                value:
                    '${item.transactions.where((t) => t.type == TransactionType.stockIn).length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Stock Outs',
                value:
                    '${item.transactions.where((t) => t.type == TransactionType.stockOut).length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: IColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IColors.divider),
          ),
          child: Column(
            children: item.transactions
                .map(
                  (tx) => Column(
                    children: [
                      _TransactionRow(tx: tx, unit: item.unit),
                      if (tx != item.transactions.last)
                        const Divider(height: 1, color: IColors.divider),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final StockTransaction tx;
  final StockUnit unit;
  const _TransactionRow({required this.tx, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isPos = tx.type.isPositive;
    final color = isPos ? IColors.inStock : IColors.critical;
    final sign = isPos ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(tx.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IColors.textPrimary,
                  ),
                ),
                Text(
                  tx.note,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: IColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tx.updatedBy,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: IColors.textSecondary,
                      ),
                    ),
                    if (tx.updatedByRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleBgColor(tx.updatedByRole),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: roleColor(tx.updatedByRole).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              roleEmoji(tx.updatedByRole),
                              style: const TextStyle(fontSize: 9),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tx.updatedByRole[0].toUpperCase() +
                                  tx.updatedByRole.substring(1).toLowerCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: roleColor(tx.updatedByRole),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${tx.quantity.toInt()} ${unit.label}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (tx.stockBefore > 0 || tx.stockAfter > 0)
                Text(
                  '${tx.stockBefore.toInt()} → ${tx.stockAfter.toInt()} ${unit.label}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: IColors.textMuted,
                  ),
                ),
              Text(
                _timeLabel(tx.date),
                style: const TextStyle(fontSize: 10, color: IColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STOCK UPDATE SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _StockUpdateSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final TransactionType initialType;
  const _StockUpdateSheet({
    required this.item,
    required this.provider,
    this.initialType = TransactionType.stockIn,
  });
  @override
  State<_StockUpdateSheet> createState() => _StockUpdateSheetState();
}

class _StockUpdateSheetState extends State<_StockUpdateSheet> {
  late TransactionType _type;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: IColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Update Stock',
            subtitle: widget.item.name,
            emoji: widget.item.emoji,
            accentColor: IColors.accentMid,
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: roleBgColor(widget.provider.userRole),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: roleColor(widget.provider.userRole).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Text(
                  roleEmoji(widget.provider.userRole),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updating as ${widget.provider.userName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: roleColor(widget.provider.userRole),
                        ),
                      ),
                      const Text(
                        'This action will be logged with your role',
                        style: TextStyle(
                          fontSize: 10,
                          color: IColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoleBadge(role: widget.provider.userRole, compact: true),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetSection(title: 'Transaction Type'),
                  _TxTypeSelector(
                    selected: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: 16),
                  InventoryField(
                    label: 'Quantity *',
                    hint: 'Enter quantity',
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: widget.item.unit.label,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Must be a number';
                      if (double.parse(v) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  InventoryField(
                    label: 'Note',
                    hint: 'Reason for update...',
                    controller: _noteCtrl,
                    isLast: true,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: IColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: IColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: IColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.item.stockDisplay,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: IColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StockStatusBadge(
                          status: widget.item.status,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirm Update',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.provider.recordTransaction(
      itemId: widget.item.id,
      type: _type,
      quantity: double.parse(_qtyCtrl.text),
      note: _noteCtrl.text.isEmpty ? '—' : _noteCtrl.text,
      updatedBy: widget.provider.userName,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _TxTypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  const _TxTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      (TransactionType.stockIn, '📥', 'Stock In', IColors.inStock),
      (TransactionType.stockOut, '📤', 'Stock Out', IColors.lowStock),
      (TransactionType.adjustment, '🔧', 'Adjust', IColors.accentMid),
      (TransactionType.waste, '🗑️', 'Waste', IColors.critical),
    ];
    return Row(
      children: types.map((t) {
        final (type, emoji, label, color) = t;
        final isSel = selected == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? color.withOpacity(0.12) : IColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? color : IColors.divider,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSel ? color : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddEditSheet extends StatefulWidget {
  final InventoryProvider provider;
  final InventoryItem? editItem;
  const _AddEditSheet({required this.provider, this.editItem});
  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl,
      _supplierCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
      _notesCtrl;
  StockUnit _unit = StockUnit.kg;
  String _category = 'Grains';
  String _emoji = '📦';
  bool _loading = false;
  String? _errorMsg;

  bool get isEditing => widget.editItem != null;

  static const _categories = [
    'Grains',
    'Pulses',
    'Vegetables',
    'Dairy',
    'Oils',
    'Spices',
    'Herbs',
    'Beverages',
    'Packaging',
    'Other',
  ];
  static const _emojis = [
    '🍚',
    '🫘',
    '🥔',
    '🍅',
    '🧅',
    '🌶️',
    '🥬',
    '🧄',
    '🫚',
    '🧈',
    '🥛',
    '🌻',
    '🥥',
    '🌿',
    '🌱',
    '📦',
    '🫙',
    '🍶',
    '🥚',
    '🧂',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _stockCtrl = TextEditingController(
      text: e != null ? '${e.currentStock}' : '',
    );
    _minCtrl = TextEditingController(
      text: e != null ? '${e.minThreshold}' : '',
    );
    _maxCtrl = TextEditingController(text: e != null ? '${e.maxCapacity}' : '');
    _costCtrl = TextEditingController(
      text: e != null ? '${e.costPerUnit}' : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _unit = e?.unit ?? StockUnit.kg;
    _category = e?.category ?? 'Grains';
    _emoji = e?.emoji ?? '📦';
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _supplierCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            SheetHeader(
              title: isEditing ? 'Edit Item' : 'Add New Item',
              subtitle: isEditing
                  ? 'Update inventory record'
                  : 'Create a new stock entry',
              emoji: isEditing ? '✏️' : '➕',
              accentColor: IColors.accentMid,
            ),
            // Role banner
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: roleBgColor(widget.provider.userRole),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: roleColor(widget.provider.userRole).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    roleEmoji(widget.provider.userRole),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isEditing ? "Editing" : "Adding"} as ${widget.provider.userName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: roleColor(widget.provider.userRole),
                      ),
                    ),
                  ),
                  _RoleBadge(role: widget.provider.userRole, compact: true),
                ],
              ),
            ),
            // Error banner
            if (_errorMsg != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: IColors.criticalBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: IColors.critical.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: IColors.critical,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMsg = null),
                      child: const Icon(
                        Icons.close,
                        color: IColors.critical,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  // Emoji picker
                  const SheetSection(title: 'Pick an Emoji'),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final isSel = _emoji == _emojis[i];
                        return GestureDetector(
                          onTap: () => setState(() => _emoji = _emojis[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? IColors.accentLight
                                  : IColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? IColors.accentMid
                                    : IColors.divider,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              _emojis[i],
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Basic info
                  const SheetSection(title: 'Basic Information'),
                  InventoryField(
                    label: 'Item Name *',
                    hint: 'e.g. Rice Batter',
                    controller: _nameCtrl,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  InventoryField(
                    label: 'Supplier Name',
                    hint: 'e.g. Sri Annapoorna Traders',
                    controller: _supplierCtrl,
                  ),
                  // Category
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((c) {
                            final isSel = _category == c;
                            return GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? IColors.accentLight
                                      : IColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.divider,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Unit
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: StockUnit.values.map((u) {
                            final isSel = _unit == u;
                            return GestureDetector(
                              onTap: () => setState(() => _unit = u),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? IColors.accentLight
                                      : IColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.divider,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  u.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? IColors.accentMid
                                        : IColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Stock levels
                  const SheetSection(title: 'Stock Levels'),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryField(
                          label: 'Current Stock *',
                          hint: '0',
                          controller: _stockCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryField(
                          label: 'Min Threshold *',
                          hint: '0',
                          controller: _minCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryField(
                          label: 'Max Capacity *',
                          hint: '100',
                          controller: _maxCtrl,
                          suffix: _unit.label,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryField(
                          label: 'Cost / Unit *',
                          hint: '0',
                          controller: _costCtrl,
                          prefix: '₹',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  InventoryField(
                    label: 'Notes',
                    hint: 'Any special instructions...',
                    controller: _notesCtrl,
                    isLast: true,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add to Inventory',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    // Wait for provider init
    if (!widget.provider.isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !widget.provider.isInitialized;
      });
    }

    final e = widget.editItem;
    log(
      '[AddEditSheet] Submitting form — name="${_nameCtrl.text}", '
      'stock="${_stockCtrl.text}", min="${_minCtrl.text}", max="${_maxCtrl.text}", '
      'cost="${_costCtrl.text}", supplier="${_supplierCtrl.text}", '
      'category="$_category", emoji="$_emoji", unit="${_unit.label}"',
    );

    final item = InventoryItem(
      id: e?.id ?? widget.provider.generateId(),
      name: _nameCtrl.text.trim(),
      category: _category,
      emoji: _emoji,
      currentStock: double.tryParse(_stockCtrl.text) ?? 0,
      minThreshold: double.tryParse(_minCtrl.text) ?? 0,
      maxCapacity: double.tryParse(_maxCtrl.text) ?? 100,
      unit: _unit,
      costPerUnit: double.tryParse(_costCtrl.text) ?? 0,
      supplier: _supplierCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _supplierCtrl.text.trim(),
      lastUpdated: DateTime.now(),
      transactions: e?.transactions ?? [],
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    log(
      '[AddEditSheet] InventoryItem built — name=${item.name}, isEditing=$isEditing, '
      'role=${widget.provider.userRole}, businessReady=${widget.provider.isInitialized}',
    );

    final success = isEditing
        ? await widget.provider.updateItem(item)
        : await widget.provider.addItem(item);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() {
          _loading = false;
          _errorMsg = widget.provider.errorMessage.isNotEmpty
              ? widget.provider.errorMessage
              : 'Failed to save item. Please try again.';
        });
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED MICRO WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: IColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: IColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: IColors.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IColors.accentLight,
            shape: BoxShape.circle,
          ),
          child: const Text('📦', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 16),
        const Text(
          'No items found',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: IColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try adjusting your search or filters',
          style: TextStyle(fontSize: 13, color: IColors.textSecondary),
        ),
      ],
    ),
  );
}

class _AddFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFAB({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IColors.accent, IColors.accentMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: IColors.accent.withOpacity(0.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Add Item',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
*/
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/screens/supplier_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/screens/widgets/inventory_widgets.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InventoryProvider(),
      child: const _InventoryBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROOT BODY
// ═════════════════════════════════════════════════════════════════════════════
class _InventoryBody extends StatefulWidget {
  const _InventoryBody();

  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Consumer<InventoryProvider>(
      builder: (context, prov, _) {
        final items = prov.filteredItems;

        return Scaffold(
          backgroundColor: IColors.bg,
          floatingActionButton: ScaleTransition(
            scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
            child: _AddFAB(onTap: () => _openAddSheet(context, prov)),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ── HEADER ──────────────────────────────────
                _Header(alertCount: prov.lowStockCount + prov.outOfStockCount),
                // ── SEARCH BAR ──────────────────────────────
                _SearchBar(
                  controller: _searchCtrl,
                  onChanged: prov.setSearch,
                  sortBy: prov.sortBy,
                  onSortChanged: prov.setSortBy,
                ),
                // ── SUMMARY STRIP ───────────────────────────
                _SummaryStrip(provider: prov),
                // ── FILTER TABS ─────────────────────────────
                _FilterTabBar(
                  current: prov.activeFilter,
                  onChanged: prov.setFilter,
                ),
                // ── CATEGORY CHIPS ──────────────────────────
                _CategoryChips(
                  categories: prov.categories,
                  selected: prov.selectedCategory,
                  onSelected: prov.setCategory,
                ),
                // ── ITEM GRID / EMPTY ────────────────────────
                Expanded(
                  child: items.isEmpty
                      ? const _EmptyState()
                      : _ItemGrid(
                          items: items,
                          onTap: (item) =>
                              _openDetailSheet(context, item, prov),
                          onAddStock: (item) =>
                              _openStockSheet(context, item, prov),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddSheet(BuildContext ctx, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditSheet(provider: prov),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(item: item, provider: prov),
    );
  }

  void _openStockSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockUpdateSheet(item: item, provider: prov),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final int alertCount;
  const _Header({required this.alertCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          // Left: icon + title
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IColors.accent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: IColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  'Stock management',
                  style: TextStyle(fontSize: 12, color: IColors.textMuted),
                ),
              ],
            ),
          ),
          // Alert bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, a, __) => SuppliersScreen(),
                    transitionsBuilder: (_, a, __, child) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: a,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                  ),
                ),

                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: IColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: IColors.divider),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: IColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
              if (alertCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: IColors.critical,
                      shape: BoxShape.circle,
                      border: const Border.fromBorderSide(
                        BorderSide(color: IColors.bg, width: 2),
                      ),
                    ),
                    child: Text(
                      '$alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SEARCH BAR + SORT
// ═════════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final InventorySortBy sortBy;
  final ValueChanged<InventorySortBy> onSortChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.sortBy,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 14,
                  color: IColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search items, suppliers...',
                  hintStyle: const TextStyle(
                    color: IColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: IColors.textMuted,
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
                            size: 17,
                            color: IColors.textMuted,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: IColors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: IColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: IColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: IColors.accentMid,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Sort button
          GestureDetector(
            onTap: () => _showSortMenu(context),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: IColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: IColors.divider),
              ),
              child: const Icon(
                Icons.sort_rounded,
                color: IColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: IColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final options = {
          InventorySortBy.name: ('A–Z Name', '🔤'),
          InventorySortBy.stockLowHigh: ('Stock: Low → High', '📉'),
          InventorySortBy.stockHighLow: ('Stock: High → Low', '📈'),
          InventorySortBy.lastUpdated: ('Recently Updated', '🕐'),
          InventorySortBy.value: ('Highest Value', '💰'),
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: IColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: IColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...options.entries.map((e) {
                final isSelected = sortBy == e.key;
                return GestureDetector(
                  onTap: () {
                    onSortChanged(e.key);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? IColors.accentLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? IColors.accentMid
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(e.value.$2, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value.$1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? IColors.accentMid
                                  : IColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: IColors.accentMid,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUMMARY STRIP
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryStrip extends StatelessWidget {
  final InventoryProvider provider;
  const _SummaryStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final value = provider.totalInventoryValue;
    final valueStr = value >= 1000
        ? '₹${(value / 1000).toStringAsFixed(1)}K'
        : '₹${value.toInt()}';

    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          SizedBox(
            width: 155,
            child: InventoryMetricTile(
              label: 'Total Value',
              value: valueStr,
              emoji: '💰',
              color: IColors.accent,
              isWide: false,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: InventoryMetricTile(
              label: 'Total Items',
              value: '${provider.totalItems}',
              emoji: '📦',
              color: const Color(0xFF0077CC),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: InventoryMetricTile(
              label: 'Low / Critical',
              value: '${provider.lowStockCount}',
              emoji: '⚠️',
              color: IColors.lowStock,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: InventoryMetricTile(
              label: 'Out of Stock',
              value: '${provider.outOfStockCount}',
              emoji: '❌',
              color: IColors.critical,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILTER TAB BAR
// ═════════════════════════════════════════════════════════════════════════════
class _FilterTabBar extends StatelessWidget {
  final InventoryFilter current;
  final ValueChanged<InventoryFilter> onChanged;

  const _FilterTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (InventoryFilter.all, 'All', ''),
      (InventoryFilter.inStock, 'In Stock', '✅'),
      (InventoryFilter.lowStock, 'Low', '⚠️'),
      (InventoryFilter.critical, 'Critical', '🔴'),
      (InventoryFilter.outOfStock, 'Out', '❌'),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tabs.map((tab) {
          final (filter, label, emoji) = tab;
          final isSelected = current == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? IColors.accent : IColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? IColors.accent : IColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty) ...[
                      Text(emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CATEGORY CHIPS
// ═════════════════════════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        children: categories.map((cat) {
          final isSel = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSel ? IColors.accentLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? IColors.accentMid : Colors.transparent,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSel ? IColors.accentMid : IColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ITEM GRID
// ═════════════════════════════════════════════════════════════════════════════
class _ItemGrid extends StatelessWidget {
  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onTap;
  final ValueChanged<InventoryItem> onAddStock;

  const _ItemGrid({
    required this.items,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => InventoryItemCard(
        item: items[i],
        onTap: () => onTap(items[i]),
        onAddStock: () => onAddStock(items[i]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: IColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Text('📦', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No items found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: IColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(fontSize: 13, color: IColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD FAB
// ═════════════════════════════════════════════════════════════════════════════
class _AddFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [IColors.accent, IColors.accentMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: IColors.accent.withOpacity(0.40),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Item',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final InventoryItem item;
  final InventoryProvider provider;

  const _DetailSheet({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            SheetHeader(
              title: item.name,
              subtitle: '${item.category} · ${item.supplier}',
              emoji: item.emoji,
              accentColor: color,
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // ── Stock meter ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: iStatusBg(item.status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: IColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.stockDisplay,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                            StockStatusBadge(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        StockBar(
                          percent: item.stockPercent,
                          height: 10,
                          status: item.status,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Min: ${item.minThreshold.toInt()} ${item.unit.label}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: IColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${(item.stockPercent * 100).toInt()}% of capacity',
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Max: ${item.maxCapacity.toInt()} ${item.unit.label}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: IColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Info grid ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'Cost / Unit',
                          value: '₹${item.costPerUnit.toInt()}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoTile(
                          label: 'Total Value',
                          value: '₹${item.totalValue.toInt()}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'Supplier',
                          value: item.supplier,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoTile(
                          label: 'Last Updated',
                          value: item.lastUpdatedLabel,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Action buttons ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Add Stock',
                          emoji: '📥',
                          color: IColors.inStock,
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _StockUpdateSheet(
                                item: item,
                                provider: provider,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          label: 'Edit Item',
                          emoji: '✏️',
                          color: IColors.accentMid,
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _AddEditSheet(
                                provider: provider,
                                editItem: item,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      _IconActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: IColors.critical,
                        onTap: () => _confirmDelete(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Transaction history ───────────────────
                  if (item.transactions.isNotEmpty) ...[
                    const SheetSection(title: 'Transaction History'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: IColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: IColors.divider),
                      ),
                      child: Column(
                        children: item.transactions
                            .map(
                              (tx) => Column(
                                children: [
                                  TransactionTile(tx: tx, unit: item.unit),
                                  if (tx != item.transactions.last)
                                    const Divider(
                                      height: 1,
                                      color: IColors.divider,
                                    ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${item.name}?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will remove the item from inventory.',
          style: TextStyle(color: IColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: IColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteItem(item.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: IColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: IColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STOCK UPDATE SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _StockUpdateSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  const _StockUpdateSheet({required this.item, required this.provider});

  @override
  State<_StockUpdateSheet> createState() => _StockUpdateSheetState();
}

class _StockUpdateSheetState extends State<_StockUpdateSheet> {
  TransactionType _txType = TransactionType.stockIn;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Update Stock',
              subtitle: item.name,
              emoji: item.emoji,
              accentColor: IColors.accentMid,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction type selector
                  const SheetSection(title: 'Transaction Type'),
                  _TxTypeSelector(
                    selected: _txType,
                    onChanged: (t) => setState(() => _txType = t),
                  ),
                  const SizedBox(height: 18),

                  // Quantity
                  InventoryField(
                    label: 'Quantity',
                    hint: 'Enter quantity',
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: item.unit.label,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Must be a number';
                      if (double.parse(v) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Note
                  InventoryField(
                    label: 'Note',
                    hint: 'Reason for update...',
                    controller: _noteCtrl,
                    isLast: true,
                  ),
                  const SizedBox(height: 22),

                  // Current stock indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: IColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: IColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 12,
                            color: IColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.stockDisplay,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: IColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StockStatusBadge(status: item.status, compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm Update',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.provider.recordTransaction(
      itemId: widget.item.id,
      type: _txType,
      quantity: double.parse(_qtyCtrl.text),
      note: _noteCtrl.text.isEmpty ? '—' : _noteCtrl.text,
      updatedBy: 'Arjun K',
    );
    Navigator.pop(context);
  }
}

class _TxTypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TxTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      (TransactionType.stockIn, '📥', 'Stock In', IColors.inStock),
      (TransactionType.stockOut, '📤', 'Stock Out', IColors.lowStock),
      (TransactionType.adjustment, '🔧', 'Adjust', IColors.accentMid),
      (TransactionType.waste, '🗑️', 'Waste', IColors.critical),
    ];
    return Row(
      children: types.map((t) {
        final (type, emoji, label, color) = t;
        final isSel = selected == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? color.withOpacity(0.12) : IColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? color : IColors.divider,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSel ? color : IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddEditSheet extends StatefulWidget {
  final InventoryProvider provider;
  final InventoryItem? editItem;

  const _AddEditSheet({required this.provider, this.editItem});

  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _costCtrl;
  StockUnit _unit = StockUnit.kg;
  String _category = 'Grains';
  String _emoji = '📦';

  bool get isEditing => widget.editItem != null;

  static const _categories = [
    'Grains',
    'Pulses',
    'Vegetables',
    'Dairy',
    'Oils',
    'Spices',
    'Herbs',
    'Beverages',
    'Other',
  ];
  static const _emojis = [
    '🍚',
    '🫘',
    '🥔',
    '🍅',
    '🧅',
    '🌶️',
    '🥬',
    '🧄',
    '🫚',
    '🧈',
    '🥛',
    '🌻',
    '🥥',
    '🌿',
    '🌱',
    '📦',
    '🫙',
    '🍶',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _stockCtrl = TextEditingController(
      text: e != null ? '${e.currentStock}' : '',
    );
    _minCtrl = TextEditingController(
      text: e != null ? '${e.minThreshold}' : '',
    );
    _maxCtrl = TextEditingController(text: e != null ? '${e.maxCapacity}' : '');
    _costCtrl = TextEditingController(
      text: e != null ? '${e.costPerUnit}' : '',
    );
    _unit = e?.unit ?? StockUnit.kg;
    _category = e?.category ?? 'Grains';
    _emoji = e?.emoji ?? '📦';
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _supplierCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SheetHeader(
                title: isEditing ? 'Edit Item' : 'Add New Item',
                subtitle: isEditing
                    ? 'Update inventory record'
                    : 'Create a new stock entry',
                emoji: isEditing ? '✏️' : '➕',
                accentColor: IColors.accentMid,
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    // ── Emoji picker ─────────────────────
                    const SheetSection(title: 'Pick an Emoji'),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emojis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final isSelected = _emoji == _emojis[i];
                          return GestureDetector(
                            onTap: () => setState(() => _emoji = _emojis[i]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? IColors.accentLight
                                    : IColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? IColors.accentMid
                                      : IColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                _emojis[i],
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Basic info ───────────────────────
                    const SheetSection(title: 'Basic Information'),
                    InventoryField(
                      label: 'Item Name *',
                      hint: 'e.g. Rice Batter',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    InventoryField(
                      label: 'Supplier',
                      hint: 'e.g. Sri Annapoorna Traders',
                      controller: _supplierCtrl,
                    ),

                    // Category dropdown
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: IColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: IColors.inputFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _category,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: IColors.textPrimary,
                                ),
                                dropdownColor: IColors.surface,
                                items: _categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _category = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unit dropdown
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: IColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: StockUnit.values.map((u) {
                              final isSel = _unit == u;
                              return GestureDetector(
                                onTap: () => setState(() => _unit = u),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? IColors.accentLight
                                        : IColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSel
                                          ? IColors.accentMid
                                          : IColors.divider,
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    u.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSel
                                          ? IColors.accentMid
                                          : IColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // ── Stock levels ─────────────────────
                    const SheetSection(title: 'Stock Levels'),
                    Row(
                      children: [
                        Expanded(
                          child: InventoryField(
                            label: 'Current Stock *',
                            hint: '0',
                            controller: _stockCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            suffix: _unit.label,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InventoryField(
                            label: 'Min Threshold *',
                            hint: '0',
                            controller: _minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            suffix: _unit.label,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InventoryField(
                            label: 'Max Capacity *',
                            hint: '100',
                            controller: _maxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            suffix: _unit.label,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InventoryField(
                            label: 'Cost / Unit *',
                            hint: '0',
                            controller: _costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefix: '₹',
                            isLast: true,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Add to Inventory',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final e = widget.editItem;
    final item = InventoryItem(
      id: e?.id ?? widget.provider.generateId(),
      name: _nameCtrl.text.trim(),
      category: _category,
      emoji: _emoji,
      currentStock: double.tryParse(_stockCtrl.text) ?? 0,
      minThreshold: double.tryParse(_minCtrl.text) ?? 0,
      maxCapacity: double.tryParse(_maxCtrl.text) ?? 100,
      unit: _unit,
      costPerUnit: double.tryParse(_costCtrl.text) ?? 0,
      supplier: _supplierCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _supplierCtrl.text.trim(),
      lastUpdated: DateTime.now(),
      transactions: e?.transactions ?? [],
    );
    isEditing
        ? widget.provider.updateItem(item)
        : widget.provider.addItem(item);
    Navigator.pop(context);
  }
}
*/
