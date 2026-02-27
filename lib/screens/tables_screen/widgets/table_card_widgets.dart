import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/table_etail_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/widgets/seated_duration_timer.dart';
import 'package:provider/provider.dart';

import 'shared_widgets.dart';

// ═════════════════════════════════════════════════════════════
//  TABLE GRID  — StatefulWidget so we can run a periodic UI
//  refresh timer for countdowns & duration chips, without
//  needing a full Supabase fetch every 30 s.
// ═════════════════════════════════════════════════════════════
class TableGrid extends StatefulWidget {
  final TablesProvider prov;
  const TableGrid({super.key, required this.prov});

  @override
  State<TableGrid> createState() => _TableGridState();
}

class _TableGridState extends State<TableGrid> {
  /// Refreshes the UI tree every 30 s so that "in 5m", "1h 23m seated"
  /// labels stay current without hammering the database.
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final sections = prov.selectedSection != null
        ? [prov.selectedSection!]
        : TableSection.values;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: sections.map((sec) {
        final tables = prov.filteredTables
            .where((t) => t.section == sec)
            .toList();
        if (tables.isEmpty) return const SizedBox.shrink();
        return SectionGroup(section: sec, tables: tables, prov: prov);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SECTION GROUP
// ─────────────────────────────────────────────────────────────
class SectionGroup extends StatelessWidget {
  final TableSection section;
  final List<RestaurantTable> tables;
  final TablesProvider prov;
  const SectionGroup({
    super.key,
    required this.section,
    required this.tables,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final color = sectionColor(section);
    final bg = sectionBg(section);
    final avail = tables.where((t) => t.status == TableStatus.available).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header pill ───────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(section.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      section.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${section.floor}',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$avail of ${tables.length} available',
                style: const TextStyle(fontSize: 11, color: TC.textMute),
              ),
            ],
          ),
        ),

        // ── Grid ─────────────────────────────────────────
        // childAspectRatio: 0.72 gives cards enough vertical
        // space for the badge + icon + name row + 3 info rows.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: tables.length,
          itemBuilder: (ctx, i) => TableCard(
            table: tables[i],
            prov: prov,
            onTap: () => _openDetail(ctx, tables[i], prov),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openDetail(
    BuildContext ctx,
    RestaurantTable table,
    TablesProvider prov,
  ) {
    log('opening details for ${table.tableName} (id: ${table.id})');
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: TableDetailSheet(table: table),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  TABLE CARD
//
//  ROOT CAUSE OF OVERLAP:
//    Old layout used Spacer() inside a Column that was inside a
//    fixed-height GridView cell.  When the content (badge +
//    icon + name + 3 info rows) exceeded the available height,
//    Flutter rendered overflow.
//
//  FIX:
//    • Remove Spacer() entirely.
//    • Put all content in a simple Column with fixed SizedBox
//      gaps — content grows downward, GridView cell is tall
//      enough (childAspectRatio: 0.72).
//    • Alert badge (Long/Soon/Ending) is the FIRST item in the
//      Column, so it never sits on top of the table icon.
//    • Premium / window icon is still a Positioned top-right,
//      but never overlaps the badge (badge is left-aligned).
//
//  CHECK-IN / CHECK-OUT for SEATED tables:
//    When status == occupied AND table.reservation != null
//    (which is true for any reservation that was "seated" today),
//    we display:
//      🟢 In   9:48 AM   (reservation.checkIn — actual arrival)
//      🔴 Out 11:30 AM   (reservation.checkOut — planned leave)
// ═════════════════════════════════════════════════════════════
class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.prov,
    required this.onTap,
  });

  // ── time formatter ────────────────────────────────────
  static String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  @override
  Widget build(BuildContext context) {
    final sc = statusColor(table.status);
    final sb = statusBg(table.status);
    final secCol = sectionColor(table.section);

    final isOccupied = table.status == TableStatus.occupied;

    final isSoon =
        table.status == TableStatus.reserved &&
        table.reservation != null &&
        table.reservation!.reservedFor.difference(DateTime.now()).inMinutes <=
            30;

    final isEndingSoon = table.reservation?.isEndingSoon ?? false;

    final isLongSeated =
        isOccupied &&
        table.occupiedSince != null &&
        DateTime.now().difference(table.occupiedSince!).inMinutes >= 120;

    // ── Border color logic ────────────────────────────
    final borderColor = isLongSeated
        ? TC.nonAcAmber.withOpacity(0.6)
        : isEndingSoon
        ? TC.occupied.withOpacity(0.5)
        : isSoon
        ? TC.nonAcAmber.withOpacity(0.5)
        : isOccupied
        ? sc.withOpacity(0.3)
        : TC.border;

    final borderWidth = (isSoon || isOccupied || isEndingSoon || isLongSeated)
        ? 1.5
        : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: isOccupied
                  ? sc.withOpacity(0.10)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Left section colour bar ──────────────────
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: secCol,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
            ),

            // ── Premium / window badge (top-right, safe) ──
            if (table.isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8DC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                ),
              )
            else if (table.hasWindow)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TC.acBlueBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🪟', style: TextStyle(fontSize: 10)),
                ),
              ),

            // ── Main card body ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    MainAxisSize.min, // ← critical: don't force expand
                children: [
                  // ① Alert badge — in normal flow, never overlaps icon
                  _AlertBadge(
                    isLongSeated: isLongSeated,
                    isSoon: isSoon,
                    isEndingSoon: isEndingSoon,
                  ),

                  const SizedBox(height: 6),

                  // ② Table shape icon
                  TableIconWidget(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),

                  const SizedBox(height: 8),

                  // ③ Table name + capacity + status pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              table.tableName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 11,
                                  color: TC.textMute,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${table.capacity} seats',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: sb,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          table.status.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: sc,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1, color: TC.divider),
                  const SizedBox(height: 6),

                  // ④ Status-specific info rows
                  _StatusContent(table: table),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ALERT BADGE
//  Lives in normal document flow — no Positioned → no overlap.
// ─────────────────────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  final bool isLongSeated, isSoon, isEndingSoon;
  const _AlertBadge({
    required this.isLongSeated,
    required this.isSoon,
    required this.isEndingSoon,
  });

  @override
  Widget build(BuildContext context) {
    // Reserve minimal space even when no badge is active
    if (!isLongSeated && !isSoon && !isEndingSoon) {
      return const SizedBox(height: 2);
    }

    final Color bg, border, textColor;
    final String label;

    if (isLongSeated) {
      bg = TC.nonAcBg;
      border = TC.nonAcAmber.withOpacity(0.5);
      textColor = TC.nonAcAmber;
      label = '⏱️  Long seated';
    } else if (isEndingSoon) {
      bg = TC.occupiedBg;
      border = TC.occupied.withOpacity(0.5);
      textColor = TC.occupied;
      label = '🔔  Ending soon';
    } else {
      bg = TC.nonAcBg;
      border = TC.nonAcAmber.withOpacity(0.5);
      textColor = TC.nonAcAmber;
      label = '⏰  Arriving soon';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS CONTENT
//  Renders the bottom info section depending on table status.
//
//  OCCUPIED (seated guest):
//    • Customer name
//    • Live SeatedDurationChip  (e.g. "1h 12m")
//    • 🟢 In   9:48 AM  ← actual check-in time from reservation
//    • 🔴 Out 11:30 AM  ← planned check-out from reservation
//    • ₹ order total (if any)
//
//  RESERVED (upcoming):
//    • Customer name
//    • Countdown  (e.g. "in 2h")
//    • 🔴 Out 11:30 AM  (if check-out was set)
//
//  AVAILABLE: "Ready to seat" pill
//  CLEANING:  "Being cleaned" row
// ─────────────────────────────────────────────────────────────
class _StatusContent extends StatelessWidget {
  final RestaurantTable table;
  const _StatusContent({required this.table});

  static String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  @override
  Widget build(BuildContext context) {
    switch (table.status) {
      // ── OCCUPIED ────────────────────────────────────────
      case TableStatus.occupied:
        final res = table.reservation; // null for walk-in (no reservation)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Customer name
            CardInfoRow(
              icon: Icons.person_outline,
              text: table.currentCustomerName ?? '—',
            ),
            const SizedBox(height: 4),

            // Live duration chip (self-ticking widget)
            SeatedDurationChip(
              occupiedSince: table.occupiedSince,
              warningMinutes: 90,
              dangerMinutes: 150,
            ),

            // Check-in time (actual arrival, stored in reservation.checkIn)
            if (res?.checkIn != null) ...[
              const SizedBox(height: 4),
              _TimeChip(
                dotColor: const Color(0xFF22C55E), // green dot
                label: 'In',
                time: _fmt(res!.checkIn!),
                textColor: TC.available,
              ),
            ],

            // Planned check-out time
            if (res?.checkOut != null) ...[
              const SizedBox(height: 3),
              _TimeChip(
                dotColor: const Color(0xFFEF4444), // red dot
                label: 'Out',
                time: _fmt(res!.checkOut!),
                textColor: TC.occupied,
              ),
            ],

            // Order total
            if (table.currentOrderTotal != null) ...[
              const SizedBox(height: 3),
              CardInfoRow(
                icon: Icons.receipt_outlined,
                text: '₹${table.currentOrderTotal!.toInt()}',
                color: TC.accent,
              ),
            ],
          ],
        );

      // ── RESERVED ────────────────────────────────────────
      case TableStatus.reserved:
        final res = table.reservation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CardInfoRow(
              icon: Icons.person_outline,
              text: res?.customerName ?? '—',
            ),
            const SizedBox(height: 3),
            CardInfoRow(
              icon: Icons.access_time_outlined,
              text: res?.countdownLabel ?? '',
              color: TC.reserved,
            ),
            if (res?.checkOut != null) ...[
              const SizedBox(height: 3),
              _TimeChip(
                dotColor: const Color(0xFFEF4444),
                label: 'Out',
                time: _fmt(res!.checkOut!),
                textColor: TC.textSec,
              ),
            ],
          ],
        );

      // ── AVAILABLE ────────────────────────────────────────
      case TableStatus.available:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: TC.available,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Ready to seat',
                style: TextStyle(
                  fontSize: 10,
                  color: TC.available,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      // ── CLEANING ─────────────────────────────────────────
      case TableStatus.cleaning:
        return CardInfoRow(
          icon: Icons.cleaning_services_outlined,
          text: 'Being cleaned',
          color: TC.cleaning,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  TIME CHIP  — "🟢 In  9:48 AM"  /  "🔴 Out 11:30 AM"
//  Compact inline chip shown inside the card.
// ─────────────────────────────────────────────────────────────
class _TimeChip extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String time;
  final Color textColor;

  const _TimeChip({
    required this.dotColor,
    required this.label,
    required this.time,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Coloured dot pill (In / Out label)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: dotColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: dotColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Actual time
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  CARD INFO ROW  (shared — used by both _StatusContent and
//  other widgets in the same file)
// ═════════════════════════════════════════════════════════════
class CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const CardInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.color = TC.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


/*import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/table_etail_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/widgets/seated_duration_timer.dart'; // ← NEW
import 'package:provider/provider.dart';

import 'shared_widgets.dart';

// ═════════════════════════════════════════════════════════════
//  TABLE GRID
// ═════════════════════════════════════════════════════════════
class TableGrid extends StatelessWidget {
  final TablesProvider prov;
  const TableGrid({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final sections = prov.selectedSection != null
        ? [prov.selectedSection!]
        : TableSection.values;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: sections.map((sec) {
        final tables = prov.filteredTables
            .where((t) => t.section == sec)
            .toList();
        if (tables.isEmpty) return const SizedBox.shrink();
        return SectionGroup(section: sec, tables: tables, prov: prov);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SECTION GROUP
// ─────────────────────────────────────────────────────────────
class SectionGroup extends StatelessWidget {
  final TableSection section;
  final List<RestaurantTable> tables;
  final TablesProvider prov;
  const SectionGroup({
    super.key,
    required this.section,
    required this.tables,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final color = sectionColor(section);
    final bg = sectionBg(section);
    final avail = tables.where((t) => t.status == TableStatus.available).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(section.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      section.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${section.floor}',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$avail of ${tables.length} available',
                style: const TextStyle(fontSize: 11, color: TC.textMute),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9, // slightly taller for duration chip
          ),
          itemCount: tables.length,
          itemBuilder: (ctx, i) => TableCard(
            table: tables[i],
            prov: prov,
            onTap: () => _openDetail(ctx, tables[i], prov),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openDetail(
    BuildContext ctx,
    RestaurantTable table,
    TablesProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: TableDetailSheet(table: table),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  TABLE CARD
// ═════════════════════════════════════════════════════════════
class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = statusColor(table.status);
    final sb = statusBg(table.status);
    final secCol = sectionColor(table.section);
    final isActive = table.status == TableStatus.occupied;

    final isSoon =
        table.status == TableStatus.reserved &&
        table.reservation != null &&
        table.reservation!.reservedFor.difference(DateTime.now()).inMinutes <=
            30;

    final isEndingSoon = table.reservation?.isEndingSoon ?? false;

    // Long-seated flag
    final isLongSeated =
        table.status == TableStatus.occupied &&
        table.occupiedSince != null &&
        DateTime.now().difference(table.occupiedSince!).inMinutes >= 120;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLongSeated
                ? TC.nonAcAmber.withOpacity(0.6)
                : isEndingSoon
                ? TC.occupied.withOpacity(0.5)
                : isSoon
                ? TC.nonAcAmber.withOpacity(0.5)
                : (isActive ? sc.withOpacity(0.3) : TC.border),
            width: (isSoon || isActive || isEndingSoon || isLongSeated)
                ? 1.5
                : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? sc.withOpacity(0.10)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (table.isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8DC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                ),
              ),
            if (table.hasWindow && !table.isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TC.acBlueBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🪟', style: TextStyle(fontSize: 10)),
                ),
              ),
            // Status badges (top-left)
            if (isLongSeated)
              Positioned(
                top: 10,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TC.nonAcBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TC.nonAcAmber.withOpacity(0.5)),
                  ),
                  child: const Text(
                    '⏱️ Long',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TC.nonAcAmber,
                    ),
                  ),
                ),
              )
            else if (isSoon)
              Positioned(
                top: 10,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TC.nonAcBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TC.nonAcAmber.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TC.nonAcAmber,
                    ),
                  ),
                ),
              )
            else if (isEndingSoon)
              Positioned(
                top: 10,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TC.occupiedBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TC.occupied.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Ending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TC.occupied,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TableIconWidget(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              table.tableName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 11,
                                  color: TC.textMute,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${table.capacity} seats',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sb,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          table.status.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: sc,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (table.status == TableStatus.occupied) ...[
                    CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.currentCustomerName ?? '—',
                    ),
                    const SizedBox(height: 4),
                    // ── LIVE duration chip ────────────────
                    SeatedDurationChip(
                      occupiedSince: table.occupiedSince,
                      warningMinutes: 90,
                      dangerMinutes: 150,
                    ),
                    if (table.currentOrderTotal != null) ...[
                      const SizedBox(height: 3),
                      CardInfoRow(
                        icon: Icons.receipt_outlined,
                        text: '₹${table.currentOrderTotal!.toInt()}',
                        color: TC.accent,
                      ),
                    ],
                  ] else if (table.status == TableStatus.reserved) ...[
                    CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.reservation?.customerName ?? '—',
                    ),
                    const SizedBox(height: 3),
                    CardInfoRow(
                      icon: Icons.access_time_outlined,
                      text: table.reservation?.countdownLabel ?? '',
                      color: TC.reserved,
                    ),
                    if (table.reservation?.checkOut != null) ...[
                      const SizedBox(height: 3),
                      CardInfoRow(
                        icon: Icons.logout_outlined,
                        text: 'Out: ${table.reservation!.checkOutTimeLabel}',
                        color: TC.textSec,
                      ),
                    ],
                  ] else if (table.status == TableStatus.available) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TC.availableBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TC.available,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Ready to seat',
                            style: TextStyle(
                              fontSize: 10,
                              color: TC.available,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    CardInfoRow(
                      icon: Icons.cleaning_services_outlined,
                      text: 'Being cleaned',
                      color: TC.cleaning,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: secCol,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const CardInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.color = TC.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
*/