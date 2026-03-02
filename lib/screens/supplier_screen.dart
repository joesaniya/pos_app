import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/supplier_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS  — slate-blue / amber / clean white
// ═══════════════════════════════════════════════════════════════
class SC {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FD);
  static const border = Color(0xFFE4E8F0);

  // Primary — deep indigo-blue
  static const primary = Color(0xFF1E3A5F);
  static const primaryMid = Color(0xFF2D5282);
  static const primaryLight = Color(0xFFE8EEF8);

  // Accent — electric amber
  static const amber = Color(0xFFD97706);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberBright = Color(0xFFF59E0B);

  // Status
  static const paid = Color(0xFF059669);
  static const paidBg = Color(0xFFECFDF5);
  static const pending = Color(0xFF0284C7);
  static const pendingBg = Color(0xFFE0F2FE);
  static const overdue = Color(0xFFDC2626);
  static const overdueBg = Color(0xFFFEF2F2);
  static const partial = Color(0xFFD97706);
  static const partialBg = Color(0xFFFEF3C7);

  static const active = Color(0xFF059669);
  static const activeBg = Color(0xFFECFDF5);
  static const inactive = Color(0xFF6B7280);
  static const inactiveBg = Color(0xFFF3F4F6);
  static const blacklisted = Color(0xFFDC2626);
  static const blackBg = Color(0xFFFEF2F2);

  // Text
  static const textPri = Color(0xFF0F172A);
  static const textSec = Color(0xFF64748B);
  static const textMute = Color(0xFFABB8CC);
  static const divider = Color(0xFFEEF1F7);
}

Color _payColor(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid:
      return SC.paid;
    case PaymentStatus.pending:
      return SC.pending;
    case PaymentStatus.overdue:
      return SC.overdue;
    case PaymentStatus.partial:
      return SC.partial;
  }
}

Color _payBg(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid:
      return SC.paidBg;
    case PaymentStatus.pending:
      return SC.pendingBg;
    case PaymentStatus.overdue:
      return SC.overdueBg;
    case PaymentStatus.partial:
      return SC.partialBg;
  }
}

Color _supColor(SupplierStatus s) {
  switch (s) {
    case SupplierStatus.active:
      return SC.active;
    case SupplierStatus.inactive:
      return SC.inactive;
    case SupplierStatus.blacklisted:
      return SC.blacklisted;
  }
}

Color _supBg(SupplierStatus s) {
  switch (s) {
    case SupplierStatus.active:
      return SC.activeBg;
    case SupplierStatus.inactive:
      return SC.inactiveBg;
    case SupplierStatus.blacklisted:
      return SC.blackBg;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════════════════════
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SupplierProvider(),
      child: const _SuppliersBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MAIN BODY
// ═════════════════════════════════════════════════════════════════════════════
class _SuppliersBody extends StatefulWidget {
  const _SuppliersBody();
  @override
  State<_SuppliersBody> createState() => _SuppliersBodyState();
}

class _SuppliersBodyState extends State<_SuppliersBody> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<SupplierProvider>(
      builder: (ctx, prov, _) => Scaffold(
        backgroundColor: SC.bg,
        floatingActionButton: _AddFAB(onTap: () => _openAdd(ctx, prov)),
        body: SafeArea(
          child: Column(
            children: [
              _Header(prov: prov),
              _AlertBanner(prov: prov),
              _SummaryStrip(prov: prov),
              _SearchSortBar(ctrl: _searchCtrl, prov: prov),
              _CategoryChips(prov: prov),
              _StatusPills(prov: prov),
              Expanded(
                child: prov.filtered.isEmpty
                    ? const _EmptyState()
                    : _SupplierList(prov: prov),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAdd(BuildContext ctx, SupplierProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: const _AddEditSupplierSheet(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final SupplierProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SC.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suppliers',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  '${prov.activeCount} active · ${prov.filtered.length} total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Pending badge
          if (prov.totalPending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: SC.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SC.amber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_fmt(prov.totalPending)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: SC.amberBright,
                    ),
                  ),
                  const Text(
                    'pending',
                    style: TextStyle(
                      fontSize: 10,
                      color: SC.amberBright,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALERT BANNER (overdue / expiring docs)
// ═════════════════════════════════════════════════════════════════════════════
class _AlertBanner extends StatelessWidget {
  final SupplierProvider prov;
  const _AlertBanner({required this.prov});

  @override
  Widget build(BuildContext context) {
    final overdueSups = prov.filtered.where((s) => s.totalOverdue > 0).length;
    final expiringDocs = prov.filtered
        .where((s) => s.hasExpiringDocs || s.hasExpiredDocs)
        .length;
    if (overdueSups == 0 && expiringDocs == 0) return const SizedBox.shrink();

    return Container(
      color: SC.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          if (overdueSups > 0)
            _AlertChip(
              emoji: '⚠️',
              label: '$overdueSups overdue',
              color: SC.overdue,
              bg: SC.overdueBg,
            ),
          if (overdueSups > 0 && expiringDocs > 0) const SizedBox(width: 8),
          if (expiringDocs > 0)
            _AlertChip(
              emoji: '📄',
              label: '$expiringDocs doc alert',
              color: SC.amber,
              bg: SC.amberLight,
            ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String emoji, label;
  final Color color, bg;
  const _AlertChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
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

// ═════════════════════════════════════════════════════════════════════════════
//  SUMMARY STRIP
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryStrip extends StatelessWidget {
  final SupplierProvider prov;
  const _SummaryStrip({required this.prov});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        children: [
          _MetricCard(
            label: 'Total Suppliers',
            value: '${prov.filtered.length}',
            emoji: '🏭',
            color: SC.primary,
          ),
          _MetricCard(
            label: 'Pending Amount',
            value: '₹${_fmt(prov.totalPending)}',
            emoji: '🕐',
            color: SC.pending,
          ),
          _MetricCard(
            label: 'Overdue',
            value: '₹${_fmt(prov.totalOverdue)}',
            emoji: '🔴',
            color: SC.overdue,
          ),
          _MetricCard(
            label: 'Active',
            value: '${prov.activeCount}',
            emoji: '✅',
            color: SC.active,
          ),
        ],
      ),
    );
  }
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: SC.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SC.border),
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
                color: SC.textSec,
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
//  SEARCH + SORT BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SearchSortBar extends StatelessWidget {
  final TextEditingController ctrl;
  final SupplierProvider prov;
  const _SearchSortBar({required this.ctrl, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: ctrl,
                onChanged: prov.setSearch,
                style: const TextStyle(fontSize: 14, color: SC.textPri),
                decoration: InputDecoration(
                  hintText: 'Search suppliers, city...',
                  hintStyle: const TextStyle(color: SC.textMute, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: SC.textMute,
                    size: 19,
                  ),
                  suffixIcon: ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            ctrl.clear();
                            prov.setSearch('');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: SC.textMute,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: SC.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: SC.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: SC.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: SC.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showSort(context),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SC.border),
              ),
              child: const Icon(
                Icons.sort_rounded,
                color: SC.textSec,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSort(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: SC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final opts = {
          SupplierSort.name: ('A–Z Name', '🔤'),
          SupplierSort.pending: ('Highest Pending', '💸'),
          SupplierSort.rating: ('Best Rated', '⭐'),
          SupplierSort.recentDelivery: ('Recent Delivery', '🚚'),
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
                    color: SC.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SC.textPri,
                ),
              ),
              const SizedBox(height: 12),
              ...opts.entries.map((e) {
                final isSel = prov.sort == e.key;
                return GestureDetector(
                  onTap: () {
                    prov.setSort(e.key);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSel ? SC.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? SC.primary : Colors.transparent,
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
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel ? SC.primary : SC.textPri,
                            ),
                          ),
                        ),
                        if (isSel)
                          const Icon(
                            Icons.check_circle,
                            color: SC.primary,
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
//  CATEGORY CHIPS
// ═════════════════════════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  final SupplierProvider prov;
  const _CategoryChips({required this.prov});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: prov.categories.length,
      itemBuilder: (_, i) {
        final cat = prov.categories[i];
        final isSel = prov.categoryFilter == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => prov.setCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                color: isSel ? SC.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? SC.primary : SC.border),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : SC.textSec,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATUS PILLS
// ═════════════════════════════════════════════════════════════════════════════
class _StatusPills extends StatelessWidget {
  final SupplierProvider prov;
  const _StatusPills({required this.prov});

  @override
  Widget build(BuildContext context) {
    const statuses = <SupplierStatus?>[
      null,
      SupplierStatus.active,
      SupplierStatus.inactive,
      SupplierStatus.blacklisted,
    ];
    const labels = ['All', 'Active', 'Inactive', 'Blocked'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(4, (i) {
          final s = statuses[i];
          final isSel = prov.statusFilter == s;
          final color = s == null ? SC.primary : _supColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setStatusFilter(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? (s == null ? SC.primaryLight : _supBg(s))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSel ? color : SC.border),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSel ? color : SC.textMute,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUPPLIER LIST
// ═════════════════════════════════════════════════════════════════════════════
class _SupplierList extends StatelessWidget {
  final SupplierProvider prov;
  const _SupplierList({required this.prov});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: prov.filtered.length,
    itemBuilder: (ctx, i) => _SupplierCard(
      supplier: prov.filtered[i],
      onTap: () => _openDetail(ctx, prov.filtered[i], prov),
    ),
  );

  void _openDetail(BuildContext ctx, Supplier sup, SupplierProvider prov) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ChangeNotifierProvider.value(
          value: prov,
          child: SupplierDetailScreen(supplier: sup),
        ),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUPPLIER CARD
// ═════════════════════════════════════════════════════════════════════════════
class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  const _SupplierCard({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final hasAlert =
        s.totalOverdue > 0 || s.hasExpiredDocs || s.hasExpiringDocs;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasAlert ? SC.overdue.withOpacity(0.25) : SC.border,
            width: hasAlert ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // Emoji avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: SC.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SC.primary.withOpacity(0.15)),
                    ),
                    alignment: Alignment.center,
                    child: Text(s.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: SC.textPri,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusBadge(status: s.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              s.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SC.textSec,
                              ),
                            ),
                            if (s.city != null) ...[
                              const Text(
                                ' · ',
                                style: TextStyle(color: SC.textMute),
                              ),
                              Text(
                                s.city!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SC.textMute,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Rating stars
                        _StarRating(rating: s.rating),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom stats row ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: SC.surfaceAlt,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  _CardStat(
                    label: 'Pending',
                    value: s.totalPending > 0
                        ? '₹${_fmt(s.totalPending)}'
                        : '—',
                    color: s.totalPending > 0 ? SC.pending : SC.textMute,
                  ),
                  _StatDiv(),
                  _CardStat(
                    label: 'Overdue',
                    value: s.totalOverdue > 0
                        ? '₹${_fmt(s.totalOverdue)}'
                        : '—',
                    color: s.totalOverdue > 0 ? SC.overdue : SC.textMute,
                  ),
                  _StatDiv(),
                  _CardStat(
                    label: 'Deliveries',
                    value: '${s.deliveries.length}',
                    color: SC.primary,
                  ),
                  _StatDiv(),
                  _CardStat(
                    label: 'Tenure',
                    value: s.tenureLabel,
                    color: SC.textSec,
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

class _CardStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CardStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: SC.textMute,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _StatDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 24, color: SC.divider);
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUPPLIER DETAIL SCREEN  (full page with tabs)
// ═════════════════════════════════════════════════════════════════════════════
class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailScreen({Key? key, required this.supplier})
    : super(key: key);

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Supplier _supplier;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierProvider>(
      builder: (ctx, prov, _) {
        // Keep in sync if updated
        final fresh = prov.filtered
            .where((s) => s.id == _supplier.id)
            .firstOrNull;
        if (fresh != null) _supplier = fresh;

        return Scaffold(
          backgroundColor: SC.bg,
          body: Column(
            children: [
              // ── Hero header ─────────────────────────────────
              _DetailHero(
                supplier: _supplier,
                onBack: () => Navigator.pop(context),
                onEdit: () => _openEdit(ctx, prov),
              ),
              // ── Tab bar ──────────────────────────────────────
              Container(
                color: SC.surface,
                child: TabBar(
                  controller: _tabs,
                  labelColor: SC.primary,
                  unselectedLabelColor: SC.textMute,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: SC.primary,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Payments'),
                    Tab(text: 'Documents'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              const Divider(height: 1, color: SC.divider),
              // ── Tab content ──────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(supplier: _supplier),
                    _PaymentsTab(supplier: _supplier, prov: prov),
                    _DocumentsTab(supplier: _supplier, prov: prov),
                    _HistoryTab(supplier: _supplier),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext ctx, SupplierProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _AddEditSupplierSheet(editSupplier: _supplier),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAIL HERO
// ─────────────────────────────────────────────────────────────────────────────
class _DetailHero extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onBack, onEdit;
  const _DetailHero({
    required this.supplier,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return Container(
      color: SC.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(s.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          s.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                        if (s.city != null) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          Text(
                            s.city!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusBadge(status: s.status, light: true),
                        const SizedBox(width: 8),
                        _StarRating(rating: s.rating, light: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick stats
          Row(
            children: [
              _HeroStat(
                label: 'Total Business',
                value: '₹${_fmt(s.totalPurchased)}',
              ),
              _HeroDivider(),
              _HeroStat(
                label: 'Pending',
                value: s.totalPending > 0 ? '₹${_fmt(s.totalPending)}' : '—',
                valueColor: s.totalPending > 0 ? SC.amberBright : null,
              ),
              _HeroDivider(),
              _HeroStat(
                label: 'On-time Delivery',
                value: '${s.deliveryScore.toInt()}%',
              ),
              _HeroDivider(),
              _HeroStat(label: 'Since', value: s.tenureLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _HeroStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    ),
  );
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.15));
}

// ─────────────────────────────────────────────────────────────────────────────
//  OVERVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Supplier supplier;
  const _OverviewTab({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // Contact cards
        _SectionHeader('Contacts'),
        ...s.contacts.map((c) => _ContactCard(contact: c)),
        const SizedBox(height: 8),

        // Business details
        _SectionHeader('Business Info'),
        _InfoBlock(
          items: [
            if (s.gstNumber != null)
              _InfoItem(icon: '🪪', label: 'GST Number', value: s.gstNumber!),
            if (s.address != null)
              _InfoItem(icon: '📍', label: 'Address', value: s.address!),
            _InfoItem(
              icon: '💳',
              label: 'Credit Limit',
              value: '₹${_fmt(s.creditLimit)}',
            ),
            _InfoItem(
              icon: '📅',
              label: 'Credit Days',
              value: '${s.creditDays} days',
            ),
            _InfoItem(
              icon: '🗓️',
              label: 'Onboarded',
              value: () {
                final d = s.onboardedDate;
                const m = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ];
                return '${m[d.month - 1]} ${d.day}, ${d.year}';
              }(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Performance
        _SectionHeader('Performance'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SC.border),
          ),
          child: Column(
            children: [
              _PerfRow(
                'On-time Deliveries',
                '${s.onTimeDeliveries} / ${s.deliveries.length}',
                '${s.deliveryScore.toInt()}%',
                SC.active,
              ),
              const Divider(height: 20, color: SC.divider),
              _PerfRow(
                'Total Purchased',
                _fmt(s.totalPurchased),
                '₹',
                SC.primary,
              ),
              const Divider(height: 20, color: SC.divider),
              _PerfRow(
                'Outstanding Balance',
                _fmt(s.totalPending),
                '₹',
                s.totalPending > 0 ? SC.pending : SC.textMute,
              ),
              if (s.totalOverdue > 0) ...[
                const Divider(height: 20, color: SC.divider),
                _PerfRow(
                  'Overdue Amount',
                  _fmt(s.totalOverdue),
                  '₹',
                  SC.overdue,
                ),
              ],
            ],
          ),
        ),

        if (s.notes != null) ...[
          const SizedBox(height: 8),
          _SectionHeader('Notes'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SC.amberLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SC.amber.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.notes!,
                    style: const TextStyle(fontSize: 13, color: SC.textSec),
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

class _PerfRow extends StatelessWidget {
  final String label, subValue, mainValue;
  final Color color;
  const _PerfRow(this.label, this.mainValue, this.subValue, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: SC.textSec)),
      Row(
        children: [
          Text(
            mainValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            subValue,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentsTab extends StatelessWidget {
  final Supplier supplier;
  final SupplierProvider prov;
  const _PaymentsTab({required this.supplier, required this.prov});

  @override
  Widget build(BuildContext context) {
    final pendingAmt = supplier.totalPending;
    final overdueAmt = supplier.totalOverdue;

    return Column(
      children: [
        // Summary bar
        if (pendingAmt > 0 || overdueAmt > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                if (pendingAmt > 0)
                  Expanded(
                    child: _PaySummaryTile(
                      label: 'Total Pending',
                      value: '₹${_fmt(pendingAmt)}',
                      color: SC.pending,
                      bg: SC.pendingBg,
                    ),
                  ),
                if (pendingAmt > 0 && overdueAmt > 0) const SizedBox(width: 10),
                if (overdueAmt > 0)
                  Expanded(
                    child: _PaySummaryTile(
                      label: 'Overdue',
                      value: '₹${_fmt(overdueAmt)}',
                      color: SC.overdue,
                      bg: SC.overdueBg,
                    ),
                  ),
              ],
            ),
          ),

        // Add payment button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: GestureDetector(
            onTap: () => _openAddPayment(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: SC.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SC.primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: SC.primary, size: 17),
                  SizedBox(width: 6),
                  Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SC.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: SC.divider),

        Expanded(
          child: supplier.payments.isEmpty
              ? const Center(
                  child: Text(
                    'No payment records',
                    style: TextStyle(color: SC.textMute),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: supplier.payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _PaymentCard(payment: supplier.payments[i]),
                ),
        ),
      ],
    );
  }

  void _openAddPayment(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _AddPaymentSheet(supplierId: supplier.id, provider: prov),
      ),
    );
  }
}

class _PaySummaryTile extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  const _PaySummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: SC.textSec),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final color = _payColor(p.status);
    final bg = _payBg(p.status);

    return Container(
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.isOverdue ? SC.overdue.withOpacity(0.3) : SC.border,
          width: p.isOverdue ? 1.5 : 1,
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
            // Status sidebar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
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
                        Expanded(
                          child: Text(
                            p.description,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SC.textPri,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.status.emoji,
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p.status.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          p.mode.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.mode.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SC.textSec,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('·', style: const TextStyle(color: SC.textMute)),
                        const SizedBox(width: 8),
                        Text(
                          p.dateLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SC.textMute,
                          ),
                        ),
                        if (p.invoiceRef != null) ...[
                          const SizedBox(width: 8),
                          Text('·', style: const TextStyle(color: SC.textMute)),
                          const SizedBox(width: 8),
                          Text(
                            p.invoiceRef!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SC.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${_fmt(p.amount)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: SC.textPri,
                              ),
                            ),
                            if (p.status == PaymentStatus.partial &&
                                p.paidAmount != null)
                              Text(
                                'Paid ₹${_fmt(p.paidAmount!)} · Balance ₹${_fmt(p.outstanding)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SC.partial,
                                ),
                              ),
                          ],
                        ),
                        if (p.dueDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.isOverdue ? SC.overdueBg : SC.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Due ${p.dueDateLabel}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: p.isOverdue ? SC.overdue : SC.textSec,
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

// ─────────────────────────────────────────────────────────────────────────────
//  DOCUMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsTab extends StatelessWidget {
  final Supplier supplier;
  final SupplierProvider prov;
  const _DocumentsTab({required this.supplier, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: () => _openAddDoc(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: SC.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SC.primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded, color: SC.primary, size: 17),
                  SizedBox(width: 6),
                  Text(
                    'Upload Document',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SC.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: SC.divider),
        Expanded(
          child: supplier.documents.isEmpty
              ? const Center(
                  child: Text(
                    'No documents uploaded',
                    style: TextStyle(color: SC.textMute),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: supplier.documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _DocumentCard(doc: supplier.documents[i]),
                ),
        ),
      ],
    );
  }

  void _openAddDoc(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _AddDocumentSheet(supplierId: supplier.id, provider: prov),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final SupplierDocument doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isExp = doc.isExpired;
    final isSoon = doc.expiresSOon;
    final borderColor = isExp
        ? SC.overdue
        : isSoon
        ? SC.amber
        : SC.border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor.withOpacity(isExp || isSoon ? 0.5 : 1),
          width: isExp || isSoon ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isExp
                  ? SC.overdueBg
                  : isSoon
                  ? SC.amberLight
                  : SC.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(doc.type.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SC.textPri,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: SC.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.type.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: SC.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _uploadDate(doc.uploadedOn),
                      style: const TextStyle(fontSize: 11, color: SC.textMute),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isExp
                  ? SC.overdueBg
                  : isSoon
                  ? SC.amberLight
                  : SC.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              doc.expiryLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isExp
                    ? SC.overdue
                    : isSoon
                    ? SC.amber
                    : SC.textMute,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _uploadDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HISTORY TAB  (delivery log)
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final Supplier supplier;
  const _HistoryTab({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final deliveries = supplier.deliveries;
    if (deliveries.isEmpty) {
      return const Center(
        child: Text(
          'No delivery history',
          style: TextStyle(color: SC.textMute),
        ),
      );
    }

    final onTime = deliveries.where((d) => d.onTime).length;
    final total = deliveries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // Delivery score card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SC.primary, SC.primaryMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🚚', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Performance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$onTime/$total on-time',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${supplier.deliveryScore.toInt()}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: SC.amberBright,
                    ),
                  ),
                  const Text(
                    'score',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Timeline
        ...deliveries.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          return _DeliveryTimelineItem(
            delivery: d,
            isLast: i == deliveries.length - 1,
          );
        }),
      ],
    );
  }
}

class _DeliveryTimelineItem extends StatelessWidget {
  final SupplierDelivery delivery;
  final bool isLast;
  const _DeliveryTimelineItem({required this.delivery, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline track
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: d.onTime ? SC.paidBg : SC.overdueBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: d.onTime ? SC.active : SC.overdue,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  d.onTime ? Icons.check_rounded : Icons.warning_amber_rounded,
                  color: d.onTime ? SC.active : SC.overdue,
                  size: 15,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: SC.divider)),
            ],
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SC.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.dateLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SC.textPri,
                          ),
                        ),
                      ),
                      Text(
                        '₹${_fmt(d.totalValue)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: SC.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: d.items
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SC.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: SC.border),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 11,
                                color: SC.textSec,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (d.note != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SC.textSec,
                              fontStyle: FontStyle.italic,
                            ),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD PAYMENT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddPaymentSheet extends StatefulWidget {
  final String supplierId;
  final SupplierProvider provider;
  const _AddPaymentSheet({required this.supplierId, required this.provider});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  PaymentStatus _status = PaymentStatus.pending;
  PaymentMode _mode = PaymentMode.upi;
  DateTime _date = DateTime.now();
  DateTime? _due;
  bool _loading = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final p = PaymentRecord(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      amount: double.parse(_amtCtrl.text),
      status: _status,
      mode: _mode,
      date: _date,
      dueDate: _due,
      description: _descCtrl.text.trim(),
      invoiceRef: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
    );
    await widget.provider.addPayment(widget.supplierId, p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(),
            _SheetTop(
              emoji: '💳',
              title: 'Record Payment',
              subtitle: 'Add a payment entry',
              color: SC.primary,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Amount (₹) *'),
                    _TField(
                      ctrl: _amtCtrl,
                      hint: '0.00',
                      type: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Description *'),
                    _TField(
                      ctrl: _descCtrl,
                      hint: 'What is this payment for?',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Invoice Ref'),
                    _TField(ctrl: _refCtrl, hint: 'INV-2025-001'),
                    const SizedBox(height: 14),
                    _FieldLabel('Payment Status'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PaymentStatus.values.map((s) {
                        final isSel = _status == s;
                        return GestureDetector(
                          onTap: () => setState(() => _status = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? _payBg(s) : SC.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? _payColor(s) : SC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.emoji,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? _payColor(s) : SC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Payment Mode'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PaymentMode.values.map((m) {
                        final isSel = _mode == m;
                        return GestureDetector(
                          onTap: () => setState(() => _mode = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? SC.primaryLight : SC.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? SC.primary : SC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? SC.primary : SC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SC.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
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
                                'Save Payment',
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
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD DOCUMENT SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddDocumentSheet extends StatefulWidget {
  final String supplierId;
  final SupplierProvider provider;
  const _AddDocumentSheet({required this.supplierId, required this.provider});

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  final _titleCtrl = TextEditingController();
  DocumentType _type = DocumentType.invoice;
  DateTime? _expiry;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final doc = SupplierDocument(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      title: _titleCtrl.text.trim(),
      uploadedOn: DateTime.now(),
      expiryDate: _expiry,
    );
    await widget.provider.addDocument(widget.supplierId, doc);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickExpiry() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _expiry = d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          _SheetTop(
            emoji: '📎',
            title: 'Upload Document',
            subtitle: 'Add a new document record',
            color: SC.primary,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Document Title *'),
                  _TField(ctrl: _titleCtrl, hint: 'e.g. GST Certificate 2025'),
                  const SizedBox(height: 14),
                  _FieldLabel('Document Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DocumentType.values.map((t) {
                      final isSel = _type == t;
                      return GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSel ? SC.primaryLight : SC.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? SC.primary : SC.border,
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? SC.primary : SC.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _pickExpiry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: SC.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SC.border),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _expiry == null
                                ? 'Set expiry date (optional)'
                                : () {
                                    const m = [
                                      'Jan',
                                      'Feb',
                                      'Mar',
                                      'Apr',
                                      'May',
                                      'Jun',
                                      'Jul',
                                      'Aug',
                                      'Sep',
                                      'Oct',
                                      'Nov',
                                      'Dec',
                                    ];
                                    return 'Expires ${m[_expiry!.month - 1]} ${_expiry!.day}, ${_expiry!.year}';
                                  }(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _expiry != null ? SC.textPri : SC.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SC.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Document',
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT SUPPLIER SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _AddEditSupplierSheet extends StatefulWidget {
  final Supplier? editSupplier;
  const _AddEditSupplierSheet({this.editSupplier});

  @override
  State<_AddEditSupplierSheet> createState() => _AddEditSupplierSheetState();
}

class _AddEditSupplierSheetState extends State<_AddEditSupplierSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl,
      _cityCtrl,
      _gstCtrl,
      _addrCtrl,
      _notesCtrl;
  late int _creditDays;
  late double _creditLimit;
  late String _category;
  late String _emoji;
  late SupplierStatus _status;
  bool _loading = false;

  bool get isEdit => widget.editSupplier != null;

  static const _categories = [
    'Grains & Pulses',
    'Dairy',
    'Vegetables',
    'Oils',
    'Spices',
    'Herbs',
    'Beverages',
    'Packaging',
    'Other',
  ];
  static const _emojis = [
    '🌾',
    '🥛',
    '🥬',
    '🫙',
    '🌶️',
    '🌿',
    '☕',
    '📦',
    '🏭',
    '🧂',
    '🐟',
    '🍗',
    '🫚',
    '🧃',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editSupplier;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _cityCtrl = TextEditingController(text: e?.city ?? '');
    _gstCtrl = TextEditingController(text: e?.gstNumber ?? '');
    _addrCtrl = TextEditingController(text: e?.address ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _creditDays = e?.creditDays ?? 14;
    _creditLimit = e?.creditLimit ?? 25000;
    _category = e?.category ?? 'Grains & Pulses';
    _emoji = e?.emoji ?? '🏭';
    _status = e?.status ?? SupplierStatus.active;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _cityCtrl, _gstCtrl, _addrCtrl, _notesCtrl])
      c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final prov = context.read<SupplierProvider>();
    final sup = Supplier(
      id: widget.editSupplier?.id ?? prov.generateId(),
      name: _nameCtrl.text.trim(),
      category: _category,
      emoji: _emoji,
      status: _status,
      gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
      address: _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      creditLimit: _creditLimit,
      creditDays: _creditDays,
      rating: widget.editSupplier?.rating ?? 0,
      contacts: widget.editSupplier?.contacts ?? [],
      documents: widget.editSupplier?.documents ?? [],
      payments: widget.editSupplier?.payments ?? [],
      deliveries: widget.editSupplier?.deliveries ?? [],
      onboardedDate: widget.editSupplier?.onboardedDate ?? DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    log('Submitting supplier: ${sup}, isEdit: $isEdit');
    isEdit ? await prov.updateSupplier(sup) : await prov.addSupplier(sup);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Handle(),
              _SheetTop(
                emoji: isEdit ? '✏️' : '➕',
                title: isEdit ? 'Edit Supplier' : 'Add Supplier',
                subtitle: isEdit
                    ? 'Update supplier details'
                    : 'Register a new supplier',
                color: SC.primary,
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    // Emoji
                    _FieldLabel('Icon'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emojis.length,
                        itemBuilder: (_, i) {
                          final isSel = _emoji == _emojis[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _emoji = _emojis[i]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? SC.primaryLight
                                      : SC.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? SC.primary : SC.border,
                                    width: isSel ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  _emojis[i],
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    _FieldLabel('Supplier Name *'),
                    _TField(
                      ctrl: _nameCtrl,
                      hint: 'e.g. Sri Annapoorna Traders',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('City'),
                              _TField(ctrl: _cityCtrl, hint: 'Chennai'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('GST Number'),
                              _TField(ctrl: _gstCtrl, hint: '33ABCDE...'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Address'),
                    _TField(ctrl: _addrCtrl, hint: 'Street, Market, Area'),
                    const SizedBox(height: 14),

                    // Category
                    _FieldLabel('Category'),
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
                              color: isSel ? SC.primaryLight : SC.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? SC.primary : SC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSel ? SC.primary : SC.textSec,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Credit
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Credit Days'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [7, 14, 21, 30, 45, 60].map((d) {
                                  final isSel = _creditDays == d;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _creditDays = d),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 130,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? SC.primaryLight
                                            : SC.surfaceAlt,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: isSel ? SC.primary : SC.border,
                                        ),
                                      ),
                                      child: Text(
                                        '$d days',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSel
                                              ? SC.primary
                                              : SC.textSec,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Status
                    _FieldLabel('Status'),
                    const SizedBox(height: 8),
                    Row(
                      children: SupplierStatus.values.map((s) {
                        final isSel = _status == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _status = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 130),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSel ? _supBg(s) : SC.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? _supColor(s) : SC.border,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? _supColor(s) : SC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    _FieldLabel('Notes'),
                    _TField(
                      ctrl: _notesCtrl,
                      hint: 'Any special instructions or remarks...',
                    ),
                    const SizedBox(height: 22),

                    Row(
                      children: [
                        if (isEdit) ...[
                          GestureDetector(
                            onTap: () => _confirmDelete(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: SC.overdueBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: SC.overdue.withOpacity(0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: SC.overdue,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SC.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
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
                                    isEdit ? 'Save Changes' : 'Add Supplier',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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

  void _confirmDelete(BuildContext ctx) {
    final prov = ctx.read<SupplierProvider>();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: SC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${widget.editSupplier!.name}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: SC.textPri,
          ),
        ),
        content: const Text(
          'This will permanently remove this supplier.',
          style: TextStyle(color: SC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteSupplier(widget.editSupplier!.id);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SC.overdue,
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

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED MICRO-WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final SupplierStatus status;
  final bool light;
  const _StatusBadge({required this.status, this.light = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: light ? Colors.white.withOpacity(0.12) : _supBg(status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: light ? Colors.white.withOpacity(0.85) : _supColor(status),
      ),
    ),
  );
}

class _StarRating extends StatelessWidget {
  final double rating;
  final bool light;
  const _StarRating({required this.rating, this.light = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('⭐', style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 3),
      Text(
        rating.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: light ? Colors.white.withOpacity(0.75) : SC.amber,
        ),
      ),
    ],
  );
}

class _ContactCard extends StatelessWidget {
  final SupplierContact contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SC.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SC.border),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SC.primaryLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            contact.name[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SC.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SC.textPri,
                ),
              ),
              Text(
                contact.role,
                style: const TextStyle(fontSize: 11, color: SC.textMute),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              contact.phone,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SC.primary,
              ),
            ),
            if (contact.email != null)
              Text(
                contact.email!,
                style: const TextStyle(fontSize: 11, color: SC.textMute),
              ),
          ],
        ),
      ],
    ),
  );
}

class _InfoBlock extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoBlock({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SC.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SC.border),
    ),
    child: Column(
      children: items
          .asMap()
          .entries
          .map(
            (e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Text(e.value.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value.label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: SC.textMute,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              e.value.value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: SC.textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.key < items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: SC.divider,
                  ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _InfoItem {
  final String icon, label, value;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: SC.textMute,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    decoration: BoxDecoration(
      color: SC.divider,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _SheetTop extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  const _SheetTop({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: SC.textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: SC.textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: SC.divider),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: SC.textSec,
      letterSpacing: 0.3,
    ),
  );
}

class _TField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType type;
  final String? Function(String?)? validator;

  const _TField({
    required this.ctrl,
    required this.hint,
    this.type = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SC.textPri,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SC.textMute, fontSize: 13),
        filled: true,
        fillColor: SC.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SC.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SC.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SC.overdue),
        ),
      ),
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SC.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Text('🏭', style: TextStyle(fontSize: 42)),
        ),
        const SizedBox(height: 16),
        const Text(
          'No suppliers found',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: SC.textPri,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Add your first supplier',
          style: TextStyle(fontSize: 13, color: SC.textSec),
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
        color: SC.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: SC.primary.withOpacity(0.38),
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
            'Add Supplier',
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

// ─── Helpers ─────────────────────────────────────────────────────────────────
String _fmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toInt().toString();
}
