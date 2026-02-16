import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/inventory_modal.dart';
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
                _Header(
                  alertCount: prov.lowStockCount + prov.outOfStockCount,
                ),
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
      BuildContext ctx, InventoryItem item, InventoryProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DetailSheet(item: item, provider: prov),
    );
  }

  void _openStockSheet(
      BuildContext ctx, InventoryItem item, InventoryProvider prov) {
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
            child: const Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inventory',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: IColors.textPrimary,
                      letterSpacing: -0.8,
                    )),
                Text('Stock management',
                    style: TextStyle(
                      fontSize: 12,
                      color: IColors.textMuted,
                    )),
              ],
            ),
          ),
          // Alert bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: IColors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: IColors.divider),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: IColors.textSecondary, size: 22),
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
                          BorderSide(color: IColors.bg, width: 2)),
                    ),
                    child: Text('$alertCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
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
                    fontSize: 14, color: IColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search items, suppliers...',
                  hintStyle: const TextStyle(
                      color: IColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: IColors.textMuted, size: 20),
                  suffixIcon: controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            controller.clear();
                            onChanged('');
                          },
                          child: const Icon(Icons.close_rounded,
                              size: 17, color: IColors.textMuted),
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
                        color: IColors.accentMid, width: 1.5),
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
              child: const Icon(Icons.sort_rounded,
                  color: IColors.textSecondary, size: 20),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final options = {
          InventorySortBy.name:          ('A–Z Name',       '🔤'),
          InventorySortBy.stockLowHigh:  ('Stock: Low → High','📉'),
          InventorySortBy.stockHighLow:  ('Stock: High → Low','📈'),
          InventorySortBy.lastUpdated:   ('Recently Updated','🕐'),
          InventorySortBy.value:         ('Highest Value',   '💰'),
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
              const Text('Sort By',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: IColors.textPrimary)),
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
                        horizontal: 14, vertical: 12),
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
                        Text(e.value.$2,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.value.$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? IColors.accentMid
                                    : IColors.textPrimary,
                              )),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: IColors.accentMid, size: 18),
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
      (InventoryFilter.all,        'All',      ''),
      (InventoryFilter.inStock,    'In Stock', '✅'),
      (InventoryFilter.lowStock,   'Low',      '⚠️'),
      (InventoryFilter.critical,   'Critical', '🔴'),
      (InventoryFilter.outOfStock, 'Out',      '❌'),
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
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? IColors.accent : IColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? IColors.accent : IColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty) ...[
                      Text(emoji,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                    ],
                    Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : IColors.textSecondary,
                        )),
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
                    horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel
                      ? IColors.accentLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel
                        ? IColors.accentMid
                        : Colors.transparent,
                  ),
                ),
                child: Text(cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel
                          ? IColors.accentMid
                          : IColors.textSecondary,
                    )),
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
            child: const Text('📦',
                style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 18),
          const Text('No items found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: IColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Try adjusting your search or filters',
              style: TextStyle(
                  fontSize: 13, color: IColors.textSecondary)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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
            Text('Add Item',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                )),
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
                                const Text('Current Stock',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: IColors.textSecondary,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(item.stockDisplay,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                      letterSpacing: -0.8,
                                    )),
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
                            Text('Min: ${item.minThreshold.toInt()} ${item.unit.label}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: IColors.textSecondary)),
                            Text(
                                '${(item.stockPercent * 100).toInt()}% of capacity',
                                style: TextStyle(
                                    fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                            Text('Max: ${item.maxCapacity.toInt()} ${item.unit.label}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: IColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Info grid ─────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _InfoTile(label: 'Cost / Unit', value: '₹${item.costPerUnit.toInt()}')),
                      const SizedBox(width: 10),
                      Expanded(child: _InfoTile(label: 'Total Value', value: '₹${item.totalValue.toInt()}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _InfoTile(label: 'Supplier', value: item.supplier)),
                      const SizedBox(width: 10),
                      Expanded(child: _InfoTile(label: 'Last Updated', value: item.lastUpdatedLabel)),
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
                                  item: item, provider: provider),
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
                                  provider: provider, editItem: item),
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
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: IColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: IColors.divider),
                      ),
                      child: Column(
                        children: item.transactions
                            .map((tx) => Column(
                                  children: [
                                    TransactionTile(
                                        tx: tx, unit: item.unit),
                                    if (tx != item.transactions.last)
                                      const Divider(
                                          height: 1,
                                          color: IColors.divider),
                                  ],
                                ))
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${item.name}?',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will remove the item from inventory.',
            style: TextStyle(color: IColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: IColors.textSecondary))),
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
                  borderRadius: BorderRadius.circular(10)),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: IColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: IColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
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
  final _qtyCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

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
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: IColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: IColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: IColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Text('Current',
                            style: TextStyle(
                                fontSize: 12, color: IColors.textSecondary)),
                        const Spacer(),
                        Text(item.stockDisplay,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: IColors.textPrimary,
                            )),
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
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Confirm Update',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
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
      (TransactionType.stockIn,    '📥', 'Stock In',  IColors.inStock),
      (TransactionType.stockOut,   '📤', 'Stock Out', IColors.lowStock),
      (TransactionType.adjustment, '🔧', 'Adjust',    IColors.accentMid),
      (TransactionType.waste,      '🗑️', 'Waste',     IColors.critical),
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
                    Text(label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSel ? color : IColors.textSecondary,
                        )),
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
    'Grains', 'Pulses', 'Vegetables', 'Dairy',
    'Oils', 'Spices', 'Herbs', 'Beverages', 'Other'
  ];
  static const _emojis = [
    '🍚','🫘','🥔','🍅','🧅','🌶️','🥬','🧄','🫚',
    '🧈','🥛','🌻','🥥','🌿','🌱','📦','🫙','🍶',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl     = TextEditingController(text: e?.name ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _stockCtrl    = TextEditingController(text: e != null ? '${e.currentStock}' : '');
    _minCtrl      = TextEditingController(text: e != null ? '${e.minThreshold}' : '');
    _maxCtrl      = TextEditingController(text: e != null ? '${e.maxCapacity}' : '');
    _costCtrl     = TextEditingController(text: e != null ? '${e.costPerUnit}' : '');
    _unit         = e?.unit ?? StockUnit.kg;
    _category     = e?.category ?? 'Grains';
    _emoji        = e?.emoji ?? '📦';
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _supplierCtrl, _stockCtrl, _minCtrl, _maxCtrl, _costCtrl]) {
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
            bottom: MediaQuery.of(context).viewInsets.bottom),
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
                              child: Text(_emojis[i],
                                  style: const TextStyle(fontSize: 22)),
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
                          const Text('Category',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: IColors.textSecondary,
                                  letterSpacing: 0.3)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
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
                                    color: IColors.textPrimary),
                                dropdownColor: IColors.surface,
                                items: _categories
                                    .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c)))
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
                          const Text('Unit',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: IColors.textSecondary,
                                  letterSpacing: 0.3)),
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
                                      horizontal: 14, vertical: 8),
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
                                  child: Text(u.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSel
                                            ? IColors.accentMid
                                            : IColors.textSecondary,
                                      )),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                            isEditing ? 'Save Changes' : 'Add to Inventory',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
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