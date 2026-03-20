// lib/screens/inventory_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/providers/supplier_provider.dart';
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

  // Supplier link color
  static const supplierLink = Color(0xFF1E3A5F);
  static const supplierLinkBg = Color(0xFFE8EEF8);
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
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ChangeNotifierProvider(create: (_) => SupplierProvider()),
    ],
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
    final supplierProv = ctx.read<SupplierProvider>();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AddEditSheet(provider: prov, supplierProvider: supplierProv),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    InventoryItem item,
    InventoryProvider prov,
  ) {
    final supplierProv = ctx.read<SupplierProvider>();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        item: item,
        provider: prov,
        supplierProvider: supplierProv,
      ),
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
//  SUPPLIER BADGE — shown in stock cards & detail
// ═════════════════════════════════════════════════════════════════════════════
class _SupplierBadge extends StatelessWidget {
  final String supplierName;
  final bool linked;
  final bool compact;
  const _SupplierBadge({
    required this.supplierName,
    this.linked = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = linked ? IColors.supplierLink : IColors.textMuted;
    final bg = linked ? IColors.supplierLinkBg : IColors.surfaceAlt;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            linked ? Icons.store_rounded : Icons.store_outlined,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              supplierName,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (linked) ...[
            const SizedBox(width: 3),
            Icon(Icons.verified_rounded, size: compact ? 9 : 11, color: color),
          ],
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
//  ITEM GRID — shows supplier badge on each card
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
      childAspectRatio: 0.76,
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

// ═════════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatefulWidget {
  final InventoryItem item;
  final InventoryProvider provider;
  final SupplierProvider supplierProvider;
  const _DetailSheet({
    required this.item,
    required this.provider,
    required this.supplierProvider,
  });
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
                    supplierProvider: widget.supplierProvider,
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
  final InventoryProvider provider;
  final SupplierProvider supplierProvider;
  final ValueChanged<InventoryItem> onRefresh;
  const _OverviewTab({
    required this.item,
    required this.provider,
    required this.supplierProvider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);

    // Try to find the linked supplier
    Supplier? linkedSupplier;
    if (item.hasLinkedSupplier) {
      try {
        linkedSupplier = supplierProvider.filtered.firstWhere(
          (s) => s.id == item.supplierId,
        );
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // ── Stock level card ─────────────────────────────────────────────
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

        // ── Supplier card (prominent) ─────────────────────────────────────
        _SupplierInfoCard(
          item: item,
          linkedSupplier: linkedSupplier,
          onViewSupplier: linkedSupplier != null
              ? () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: supplierProvider,
                        child: SupplierDetailScreen(supplier: linkedSupplier!),
                      ),
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 10),

        // ── Info tiles ───────────────────────────────────────────────────
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
              child: _InfoTile(
                label: 'Last Updated',
                value: item.lastUpdatedLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(label: 'Category', value: item.category),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoTile(label: 'Unit Type', value: item.unit.label),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'Transactions',
                value: '${item.transactions.length}',
              ),
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
        const SizedBox(height: 16),

        // ── Action buttons ────────────────────────────────────────────────
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
                    builder: (_) => _AddEditSheet(
                      provider: provider,
                      supplierProvider: supplierProvider,
                      editItem: item,
                    ),
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
            constraints: const BoxConstraints(maxWidth: 500),
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
                    onTap: () => _open(context, TransactionType.adjustment),
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

// ── Supplier Info Card ─────────────────────────────────────────────────────
class _SupplierInfoCard extends StatelessWidget {
  final InventoryItem item;
  final Supplier? linkedSupplier;
  final VoidCallback? onViewSupplier;
  const _SupplierInfoCard({
    required this.item,
    this.linkedSupplier,
    this.onViewSupplier,
  });

  @override
  Widget build(BuildContext context) {
    final isLinked = linkedSupplier != null;
    final Color borderColor = isLinked ? IColors.supplierLink : IColors.divider;
    final Color bgColor = isLinked
        ? IColors.supplierLinkBg
        : IColors.surfaceAlt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor.withOpacity(0.4),
          width: isLinked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isLinked
                      ? IColors.supplierLink.withOpacity(0.12)
                      : IColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLinked ? Icons.store_rounded : Icons.store_outlined,
                  size: 16,
                  color: isLinked ? IColors.supplierLink : IColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SUPPLIER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: IColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (isLinked) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: IColors.inStockBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LINKED',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: IColors.inStock,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.supplier,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isLinked
                            ? IColors.supplierLink
                            : IColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onViewSupplier != null)
                GestureDetector(
                  onTap: onViewSupplier,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: IColors.supplierLink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (linkedSupplier != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: IColors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                _SupplierStatChip(
                  icon: Icons.star_rounded,
                  label: linkedSupplier!.rating.toStringAsFixed(1),
                  color: const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                _SupplierStatChip(
                  icon: Icons.local_shipping_outlined,
                  label: '${linkedSupplier!.deliveries.length} deliveries',
                  color: IColors.supplierLink,
                ),
                const SizedBox(width: 8),
                _SupplierStatChip(
                  emoji: linkedSupplier!.status == SupplierStatus.active
                      ? '🟢'
                      : '🔴',
                  label: linkedSupplier!.status.label,
                  color: linkedSupplier!.status == SupplierStatus.active
                      ? IColors.inStock
                      : IColors.critical,
                ),
              ],
            ),
            if (linkedSupplier!.contacts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: IColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    linkedSupplier!.contacts.first.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    linkedSupplier!.contacts.first.phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: IColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Text(
              item.hasLinkedSupplier
                  ? 'Supplier data not loaded'
                  : 'No linked supplier profile',
              style: const TextStyle(fontSize: 11, color: IColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupplierStatChip extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String label;
  final Color color;
  const _SupplierStatChip({
    this.icon,
    this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 11, color: color),
        if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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
//  ADD / EDIT SHEET  — mandatory supplier picker
// ═════════════════════════════════════════════════════════════════════════════
class _AddEditSheet extends StatefulWidget {
  final InventoryProvider provider;
  final SupplierProvider supplierProvider;
  final InventoryItem? editItem;
  const _AddEditSheet({
    required this.provider,
    required this.supplierProvider,
    this.editItem,
  });
  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl,
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

  // Supplier selection state
  Supplier? _selectedSupplier;
  bool _useOtherSupplier = false; // fallback: "Other / Unknown"
  final _otherSupplierNameCtrl = TextEditingController();

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

    // Pre-fill supplier if editing
    if (e != null) {
      if (e.supplierId != null &&
          e.supplierId!.isNotEmpty &&
          e.supplierId != 'unknown') {
        try {
          _selectedSupplier = widget.supplierProvider.filtered.firstWhere(
            (s) => s.id == e.supplierId,
          );
        } catch (_) {
          // Supplier not found in list — treat as other
          _useOtherSupplier = true;
          _otherSupplierNameCtrl.text = e.supplier;
        }
      } else {
        _useOtherSupplier = true;
        _otherSupplierNameCtrl.text =
            (e.supplier == 'Unknown' || e.supplier == 'Unknown Supplier')
            ? ''
            : e.supplier;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _stockCtrl,
      _minCtrl,
      _maxCtrl,
      _costCtrl,
      _notesCtrl,
      _otherSupplierNameCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _resolvedSupplierName {
    if (_selectedSupplier != null) return _selectedSupplier!.name;
    if (_useOtherSupplier) {
      return _otherSupplierNameCtrl.text.trim().isEmpty
          ? 'Other Supplier'
          : _otherSupplierNameCtrl.text.trim();
    }
    return 'Unknown Supplier';
  }

  String? get _resolvedSupplierId {
    if (_selectedSupplier != null) return _selectedSupplier!.id;
    if (_useOtherSupplier) return 'other';
    return null;
  }

  bool get _supplierIsSelected =>
      _selectedSupplier != null || _useOtherSupplier;

  void _openSupplierPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierPickerSheet(
        supplierProvider: widget.supplierProvider,
        selectedId: _selectedSupplier?.id,
        onSelected: (supplier) {
          setState(() {
            _selectedSupplier = supplier;
            _useOtherSupplier = false;
          });
        },
        onOtherSelected: () {
          setState(() {
            _selectedSupplier = null;
            _useOtherSupplier = true;
          });
        },
      ),
    );
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
                  // ── Emoji picker ─────────────────────────────────────
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

                  // ── Basic info ───────────────────────────────────────
                  const SheetSection(title: 'Basic Information'),
                  InventoryField(
                    label: 'Item Name *',
                    hint: 'e.g. Rice Batter',
                    controller: _nameCtrl,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),

                  // ── MANDATORY SUPPLIER PICKER ─────────────────────────
                  const SizedBox(height: 4),
                  _SupplierPickerField(
                    selectedSupplier: _selectedSupplier,
                    useOther: _useOtherSupplier,
                    otherNameCtrl: _otherSupplierNameCtrl,
                    isValid: _supplierIsSelected,
                    onPickerTap: _openSupplierPicker,
                  ),
                  const SizedBox(height: 14),

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

    // Validate supplier is selected
    if (!_supplierIsSelected) {
      setState(() => _errorMsg = 'Please select a supplier to continue.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    if (!widget.provider.isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !widget.provider.isInitialized;
      });
    }

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
      supplier: _resolvedSupplierName,
      supplierId: _resolvedSupplierId,
      lastUpdated: DateTime.now(),
      transactions: e?.transactions ?? [],
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
//  SUPPLIER PICKER FIELD — inline field in Add/Edit form
// ═════════════════════════════════════════════════════════════════════════════
class _SupplierPickerField extends StatelessWidget {
  final Supplier? selectedSupplier;
  final bool useOther;
  final TextEditingController otherNameCtrl;
  final bool isValid;
  final VoidCallback onPickerTap;

  const _SupplierPickerField({
    required this.selectedSupplier,
    required this.useOther,
    required this.otherNameCtrl,
    required this.isValid,
    required this.onPickerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Supplier *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: IColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: IColors.criticalBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'REQUIRED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: IColors.critical,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Selected supplier card or picker button
        if (selectedSupplier != null)
          _SelectedSupplierCard(
            supplier: selectedSupplier!,
            onClear: onPickerTap,
          )
        else if (useOther)
          _OtherSupplierEntry(ctrl: otherNameCtrl, onChangeTap: onPickerTap)
        else
          _SupplierPickerButton(onTap: onPickerTap, isValid: isValid),

        if (!isValid)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '⚠️  A supplier must be selected before saving',
              style: TextStyle(
                fontSize: 11,
                color: IColors.critical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedSupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onClear;
  const _SelectedSupplierCard({required this.supplier, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: IColors.supplierLinkBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: IColors.supplierLink.withOpacity(0.4),
        width: 1.5,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: IColors.supplierLink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(supplier.emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: IColors.supplierLink,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: IColors.inStock,
                  ),
                ],
              ),
              Text(
                '${supplier.category}${supplier.city != null ? " · ${supplier.city}" : ""}',
                style: const TextStyle(
                  fontSize: 11,
                  color: IColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: IColors.supplierLink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IColors.supplierLink.withOpacity(0.3)),
            ),
            child: const Text(
              'Change',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IColors.supplierLink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OtherSupplierEntry extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onChangeTap;
  const _OtherSupplierEntry({required this.ctrl, required this.onChangeTap});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              style: const TextStyle(
                fontSize: 14,
                color: IColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter supplier name (optional)',
                hintStyle: const TextStyle(
                  color: IColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.store_outlined,
                  size: 18,
                  color: IColors.textMuted,
                ),
                filled: true,
                fillColor: IColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: IColors.accentMid,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: IColors.accentMid.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: IColors.accentMid,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💡', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Using "Other Supplier" — tap swap to select from your supplier list',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SupplierPickerButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isValid;
  const _SupplierPickerButton({required this.onTap, required this.isValid});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IColors.criticalBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IColors.critical.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: IColors.critical.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.store_outlined,
              size: 18,
              color: IColors.critical,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Supplier',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: IColors.critical,
                  ),
                ),
                Text(
                  'Required — tap to choose from your supplier list',
                  style: TextStyle(fontSize: 11, color: IColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: IColors.critical,
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUPPLIER PICKER SHEET — bottom sheet listing all suppliers
// ═════════════════════════════════════════════════════════════════════════════
class _SupplierPickerSheet extends StatefulWidget {
  final SupplierProvider supplierProvider;
  final String? selectedId;
  final ValueChanged<Supplier> onSelected;
  final VoidCallback onOtherSelected;
  const _SupplierPickerSheet({
    required this.supplierProvider,
    this.selectedId,
    required this.onSelected,
    required this.onOtherSelected,
  });

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Supplier> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.supplierProvider.filtered;
    return widget.supplierProvider.filtered
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.category.toLowerCase().contains(q) ||
              (s.city?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.92,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: IColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IColors.supplierLinkBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: IColors.supplierLink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Supplier',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: IColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Choose from your supplier list',
                        style: TextStyle(
                          fontSize: 12,
                          color: IColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search suppliers...',
                  hintStyle: const TextStyle(
                    color: IColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: IColors.textMuted,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: IColors.surfaceAlt,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: IColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: IColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: IColors.accentMid,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: IColors.divider),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                // "Other Supplier" option — always first
                _OtherSupplierOption(
                  onTap: () {
                    widget.onOtherSelected();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No suppliers found.\nAdd suppliers from the Suppliers section.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: IColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ..._filtered.map(
                    (s) => _SupplierPickerRow(
                      supplier: s,
                      isSelected: widget.selectedId == s.id,
                      onTap: () {
                        widget.onSelected(s);
                        Navigator.pop(context);
                      },
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

class _OtherSupplierOption extends StatelessWidget {
  final VoidCallback onTap;
  const _OtherSupplierOption({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text('🏪', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Other / Unknown Supplier',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                Text(
                  'Manually enter a name or leave blank',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Color(0xFFD97706),
          ),
        ],
      ),
    ),
  );
}

class _SupplierPickerRow extends StatelessWidget {
  final Supplier supplier;
  final bool isSelected;
  final VoidCallback onTap;
  const _SupplierPickerRow({
    required this.supplier,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? IColors.supplierLinkBg : IColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? IColors.supplierLink.withOpacity(0.5)
              : IColors.divider,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: IColors.supplierLinkBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(supplier.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? IColors.supplierLink
                        : IColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      supplier.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: IColors.textSecondary,
                      ),
                    ),
                    if (supplier.city != null) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(color: IColors.textMuted),
                      ),
                      Text(
                        supplier.city!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: IColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: supplier.status == SupplierStatus.active
                            ? IColors.inStock
                            : IColors.critical,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      supplier.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: supplier.status == SupplierStatus.active
                            ? IColors.inStock
                            : IColors.critical,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: IColors.supplierLink,
              size: 20,
            )
          else
            const Icon(
              Icons.radio_button_unchecked_rounded,
              color: IColors.textMuted,
              size: 20,
            ),
        ],
      ),
    ),
  );
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
