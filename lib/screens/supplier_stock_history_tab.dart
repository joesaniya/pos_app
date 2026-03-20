// lib/screens/supplier_stock_history_tab.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SUPPLIER STOCK HISTORY TAB
//  Shows all inventory items linked to this supplier (by supplierId),
//  with product name, qty, last updated, total value, and transaction count.
//  Integrated into the SupplierDetailScreen as a 5th tab.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:provider/provider.dart';

// ── Design tokens (mirrors SC from supplier_screen) ───────────────────────
class _C {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FD);
  static const border = Color(0xFFE4E8F0);
  static const primary = Color(0xFF1E3A5F);
  static const primaryMid = Color(0xFF2D5282);
  static const primaryLight = Color(0xFFE8EEF8);
  static const amber = Color(0xFFD97706);
  static const amberLight = Color(0xFFFEF3C7);
  static const paid = Color(0xFF059669);
  static const paidBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const textPri = Color(0xFF0F172A);
  static const textSec = Color(0xFF64748B);
  static const textMut = Color(0xFFABB8CC);
  static const divider = Color(0xFFEEF1F7);

  // Stock status colors
  static const inStock = Color(0xFF1E8A5E);
  static const inStockBg = Color(0xFFE6F5EE);
  static const lowStock = Color(0xFFB8800A);
  static const lowStockBg = Color(0xFFFFF3DC);
  static const critical = Color(0xFFCC3300);
  static const criticalBg = Color(0xFFFFEDE8);
  static const outOfStock = Color(0xFF5A5A6E);
  static const outOfStockBg = Color(0xFFF0EFF5);
}

Color _stockColor(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return _C.inStock;
    case StockStatus.lowStock:
      return _C.lowStock;
    case StockStatus.critical:
      return _C.critical;
    case StockStatus.outOfStock:
      return _C.outOfStock;
  }
}

Color _stockBg(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return _C.inStockBg;
    case StockStatus.lowStock:
      return _C.lowStockBg;
    case StockStatus.critical:
      return _C.criticalBg;
    case StockStatus.outOfStock:
      return _C.outOfStockBg;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUPPLIER STOCK HISTORY TAB WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class SupplierStockHistoryTab extends StatefulWidget {
  final Supplier supplier;

  const SupplierStockHistoryTab({Key? key, required this.supplier})
      : super(key: key);

  @override
  State<SupplierStockHistoryTab> createState() =>
      _SupplierStockHistoryTabState();
}

class _SupplierStockHistoryTabState extends State<SupplierStockHistoryTab> {
  String _sortBy = 'name'; // 'name' | 'value' | 'qty' | 'recent'
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    // Read the global InventoryProvider (must be provided above in widget tree)
    final invProv = context.watch<InventoryProvider>();

    // Get all stock items linked to this supplier
    final allItems = invProv.allItems
        .where((item) =>
            item.supplierId == widget.supplier.id ||
            item.supplier.toLowerCase() ==
                widget.supplier.name.toLowerCase())
        .toList();

    // Apply status filter
    final filtered = _filterStatus == 'all'
        ? allItems
        : allItems.where((i) {
            switch (_filterStatus) {
              case 'in_stock':
                return i.status == StockStatus.inStock;
              case 'low':
                return i.status == StockStatus.lowStock ||
                    i.status == StockStatus.critical;
              case 'out':
                return i.status == StockStatus.outOfStock;
              default:
                return true;
            }
          }).toList();

    // Apply sort
    final sorted = List<InventoryItem>.from(filtered);
    switch (_sortBy) {
      case 'value':
        sorted.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
      case 'qty':
        sorted.sort((a, b) => b.currentStock.compareTo(a.currentStock));
        break;
      case 'recent':
        sorted.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      default:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }

    // Summary stats
    final totalValue =
        allItems.fold<double>(0, (s, i) => s + i.totalValue);
    final totalTx = allItems.fold<int>(0, (s, i) => s + i.transactions.length);
    final lowCount = allItems
        .where((i) =>
            i.status == StockStatus.lowStock ||
            i.status == StockStatus.critical ||
            i.status == StockStatus.outOfStock)
        .length;

    if (invProv.isLoading && allItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _C.primary),
      );
    }

    return Column(
      children: [
        // ── Summary bar ────────────────────────────────────────────────
        _StockSummaryBar(
          totalItems: allItems.length,
          totalValue: totalValue,
          totalTransactions: totalTx,
          alertCount: lowCount,
        ),

        // ── Sort + filter controls ─────────────────────────────────────
        _StockControls(
          sortBy: _sortBy,
          filterStatus: _filterStatus,
          onSortChanged: (v) => setState(() => _sortBy = v),
          onFilterChanged: (v) => setState(() => _filterStatus = v),
        ),

        const Divider(height: 1, color: _C.divider),

        // ── Content ────────────────────────────────────────────────────
        Expanded(
          child: sorted.isEmpty
              ? _EmptyStockState(
                  supplierName: widget.supplier.name,
                  isFiltered: _filterStatus != 'all',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: sorted.length,
                  itemBuilder: (ctx, i) => _StockItemCard(
                    item: sorted[i],
                    index: i,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Summary Bar ───────────────────────────────────────────────────────────────
class _StockSummaryBar extends StatelessWidget {
  final int totalItems;
  final double totalValue;
  final int totalTransactions;
  final int alertCount;

  const _StockSummaryBar({
    required this.totalItems,
    required this.totalValue,
    required this.totalTransactions,
    required this.alertCount,
  });

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }

  @override
  Widget build(BuildContext context) => Container(
        color: _C.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            _SummaryChip(
              emoji: '📦',
              label: 'Items',
              value: '$totalItems',
              color: _C.primary,
            ),
            const SizedBox(width: 8),
            _SummaryChip(
              emoji: '💰',
              label: 'Value',
              value: _fmt(totalValue),
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            _SummaryChip(
              emoji: '🔄',
              label: 'Transactions',
              value: '$totalTransactions',
              color: _C.primaryMid,
            ),
            if (alertCount > 0) ...[
              const SizedBox(width: 8),
              _SummaryChip(
                emoji: '⚠️',
                label: 'Alerts',
                value: '$alertCount',
                color: _C.danger,
                urgent: true,
              ),
            ],
          ],
        ),
      );
}

class _SummaryChip extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  final bool urgent;

  const _SummaryChip({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: urgent ? color.withOpacity(0.08) : _C.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: urgent ? color.withOpacity(0.3) : _C.border,
              width: urgent ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: _C.textMut,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Controls ──────────────────────────────────────────────────────────────────
class _StockControls extends StatelessWidget {
  final String sortBy;
  final String filterStatus;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onFilterChanged;

  const _StockControls({
    required this.sortBy,
    required this.filterStatus,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips
          Row(
            children: [
              _FilterPill(
                label: 'All',
                selected: filterStatus == 'all',
                onTap: () => onFilterChanged('all'),
              ),
              const SizedBox(width: 6),
              _FilterPill(
                label: '✅ In Stock',
                selected: filterStatus == 'in_stock',
                onTap: () => onFilterChanged('in_stock'),
                color: _C.inStock,
              ),
              const SizedBox(width: 6),
              _FilterPill(
                label: '⚠️ Low/Critical',
                selected: filterStatus == 'low',
                onTap: () => onFilterChanged('low'),
                color: _C.lowStock,
              ),
              const SizedBox(width: 6),
              _FilterPill(
                label: '❌ Out',
                selected: filterStatus == 'out',
                onTap: () => onFilterChanged('out'),
                color: _C.danger,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sort row
          Row(
            children: [
              const Text(
                'Sort:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.textSec,
                ),
              ),
              const SizedBox(width: 8),
              _SortPill(
                label: 'A–Z',
                selected: sortBy == 'name',
                onTap: () => onSortChanged('name'),
              ),
              const SizedBox(width: 5),
              _SortPill(
                label: 'Value',
                selected: sortBy == 'value',
                onTap: () => onSortChanged('value'),
              ),
              const SizedBox(width: 5),
              _SortPill(
                label: 'Stock',
                selected: sortBy == 'qty',
                onTap: () => onSortChanged('qty'),
              ),
              const SizedBox(width: 5),
              _SortPill(
                label: 'Recent',
                selected: sortBy == 'recent',
                onTap: () => onSortChanged('recent'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _C.primary,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : _C.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? color : _C.textMut,
            ),
          ),
        ),
      );
}

class _SortPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? _C.primaryLight : _C.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? _C.primary : _C.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? _C.primary : _C.textSec,
            ),
          ),
        ),
      );
}

// ── Stock Item Card ────────────────────────────────────────────────────────────
class _StockItemCard extends StatelessWidget {
  final InventoryItem item;
  final int index;

  const _StockItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final sColor = _stockColor(item.status);
    final sBg = _stockBg(item.status);
    final txCount = item.transactions.length;
    final lastTx = txCount > 0 ? item.transactions.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (item.status == StockStatus.critical ||
                  item.status == StockStatus.outOfStock)
              ? sColor.withOpacity(0.3)
              : _C.border,
          width: (item.status == StockStatus.critical ||
                  item.status == StockStatus.outOfStock)
              ? 1.5
              : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Status sidebar ──────────────────────────────────────────
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: sColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),

            // ── Main content ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: emoji + name + status badge
                    Row(
                      children: [
                        Text(item.emoji,
                            style: const TextStyle(fontSize: 22)),
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
                                  color: _C.textPri,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: sColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.status.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: sColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Stock progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: item.stockPercent,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFEEEDF0),
                        valueColor: AlwaysStoppedAnimation<Color>(sColor),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.inventory_2_outlined,
                          label: item.stockDisplay,
                          color: sColor,
                          bg: sBg,
                        ),
                        const SizedBox(width: 6),
                        _StatBadge(
                          icon: Icons.currency_rupee_rounded,
                          label: _fmtValue(item.totalValue),
                          color: _C.primary,
                          bg: _C.primaryLight,
                        ),
                        const SizedBox(width: 6),
                        _StatBadge(
                          icon: Icons.swap_horiz_rounded,
                          label: '$txCount txn',
                          color: _C.textSec,
                          bg: _C.surfaceAlt,
                        ),
                        const Spacer(),
                        Text(
                          item.lastUpdatedLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _C.textMut,
                          ),
                        ),
                      ],
                    ),

                    // Last transaction info
                    if (lastTx != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _C.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              lastTx.type.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Last: ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _C.textMut,
                                        ),
                                      ),
                                      Text(
                                        lastTx.type.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _C.textSec,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '· ${lastTx.updatedBy}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: _C.textMut,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lastTx.note.isNotEmpty &&
                                      lastTx.note != '—')
                                    Text(
                                      lastTx.note,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _C.textMut,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${lastTx.type.isPositive ? '+' : '-'}${lastTx.quantity.toInt()} ${item.unit.label}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: lastTx.type.isPositive
                                    ? _C.paid
                                    : _C.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Purchase price if cost > 0
                    if (item.costPerUnit > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.price_check_rounded,
                            size: 12,
                            color: _C.textMut,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '₹${item.costPerUnit.toInt()} / ${item.unit.label}  ·  '
                            'Min threshold: ${item.minThreshold.toInt()} ${item.unit.label}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: _C.textSec,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtValue(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
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

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyStockState extends StatelessWidget {
  final String supplierName;
  final bool isFiltered;

  const _EmptyStockState({
    required this.supplierName,
    required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isFiltered ? '🔍' : '📦',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered
                    ? 'No matching stock items'
                    : 'No stock items linked',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textPri,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered
                    ? 'Try clearing the status filter'
                    : 'Add inventory items and link them to $supplierName '
                        'to track their stock here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _C.textSec,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
}