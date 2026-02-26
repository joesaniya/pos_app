import 'package:flutter/material.dart';
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
