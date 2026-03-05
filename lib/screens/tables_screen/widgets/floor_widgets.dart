import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/widgets/seated_duration_timer.dart'; // ← NEW

// ═════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════
class TableHeader extends StatelessWidget {
  final TablesProvider prov;
  const TableHeader({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: TC.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: TC.accent.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_bar_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tables',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: TC.textPri,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  '${prov.totalTables} tables · ${prov.totalAvailable} available'
                  '${prov.currentBusinessName.isNotEmpty ? ' · ${prov.currentBusinessName}' : ''}',
                  style: const TextStyle(fontSize: 12, color: TC.textSec),
                ),
              ],
            ),
          ),
          // ── Today / Tomorrow quick counts ───────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (prov.totalReserved > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: TC.reservedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TC.reserved.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📅', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${prov.totalReserved} reserved',

                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniDayBadge(
                    label: 'Today',
                    count: prov.todayReservationCount,
                    color: TC.accent,
                    bg: TC.accentLight,
                  ),
                  const SizedBox(width: 5),
                  _MiniDayBadge(
                    label: 'Tmrw',
                    count: prov.tomorrowReservationCount,
                    color: TC.reserved,
                    bg: TC.reservedBg,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniDayBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg;

  const _MiniDayBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0 ? bg : TC.surfaceWarm,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: count > 0 ? color.withOpacity(0.3) : TC.border,
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: count > 0 ? color : TC.textMute,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPCOMING BANNER
// ─────────────────────────────────────────────────────────────
class UpcomingBanner extends StatelessWidget {
  final TablesProvider prov;
  const UpcomingBanner({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final upcoming = prov.upcomingReservations(30);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TC.nonAcBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.nonAcAmber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${upcoming.length} reservation${upcoming.length > 1 ? 's' : ''} arriving within 30 minutes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.nonAcAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ENDING SOON BANNER
// ─────────────────────────────────────────────────────────────
class EndingSoonBanner extends StatelessWidget {
  final TablesProvider prov;
  const EndingSoonBanner({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final ending = prov.endingSoonTables;
    if (ending.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TC.occupiedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.occupied.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${ending.length} reservation${ending.length > 1 ? 's' : ''} ending within 15 minutes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.occupied,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  NEW: LONG-SEATED BANNER
// ─────────────────────────────────────────────────────────────
class LongSeatedBanner extends StatelessWidget {
  final TablesProvider prov;
  const LongSeatedBanner({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final long = prov.longSeatedTables;
    if (long.isEmpty) return const SizedBox.shrink();

    final names = long.map((t) => t.tableName).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TC.nonAcBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.nonAcAmber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${long.length} table${long.length > 1 ? 's' : ''} seated 2h+: $names',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.nonAcAmber,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryBar extends StatelessWidget {
  final TablesProvider prov;
  const SummaryBar({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    log('Rebuilding SummaryBar:${prov.totalUpcomingReservations}');
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        children: [
          MetricPill(
            emoji: '✅',
            label: 'Available',
            value: '${prov.totalAvailable}',
            color: TC.available,
          ),
          MetricPill(
            emoji: '🍽️',
            label: 'Occupied',
            value: '${prov.totalOccupied}',
            color: TC.occupied,
          ),
          MetricPill(
            emoji: '📅',
            label: 'Reserved',
            value: '${prov.totalReserved}',
            // value: '${prov.totalUpcomingReservations}',
            color: TC.reserved,
          ),
          MetricPill(
            emoji: '🧹',
            label: 'Cleaning',
            value:
                '${prov.allTables.where((t) => t.status == TableStatus.cleaning).length}',
            color: TC.cleaning,
          ),
          MetricPill(
            emoji: '📊',
            label: 'Occupancy',
            value: '${(prov.occupancyRate * 100).toStringAsFixed(0)}%',
            color: TC.accent,
          ),
          // ── NEW: Today's bookings metric ──────────────
          MetricPill(
            emoji: '☀️',
            label: 'Today',
            value: '${prov.todayReservationCount}',
            color: TC.accent,
          ),
        ],
      ),
    );
  }
}

class MetricPill extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const MetricPill({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: TC.textSec,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SECTION TABS
// ═════════════════════════════════════════════════════════════
class SectionTabs extends StatelessWidget {
  final TablesProvider prov;
  const SectionTabs({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final sections = [null, ...TableSection.values];
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final s = sections[i];
          final isSel = prov.selectedSection == s;
          final label = s == null ? 'All Floors' : s.label;
          final floor = s == null ? '' : ' · ${s.floor}';
          final color = s == null ? TC.accent : sectionColor(s);
          final count = s != null
              ? prov.allTables.where((t) => t.section == s).length
              : null;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setSection(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSel ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? color : TC.border,
                    width: isSel ? 0 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s != null) ...[
                      Text(s.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '$label$floor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : TC.textSec,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.25)
                              : TC.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : TC.textMute,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  STATUS FILTER ROW
// ═════════════════════════════════════════════════════════════
class StatusFilterRow extends StatelessWidget {
  final TablesProvider prov;
  const StatusFilterRow({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    const statuses = <TableStatus?>[
      null,
      TableStatus.available,
      TableStatus.occupied,
      TableStatus.reserved,
      TableStatus.cleaning,
    ];
    const labels = ['All', 'Available', 'Occupied', 'Reserved', 'Cleaning'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: List.generate(statuses.length, (i) {
          final s = statuses[i];
          final isSel = prov.selectedStatus == s;
          final color = s == null ? TC.textSec : statusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setStatus(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? (s == null ? TC.textPri : statusBg(s))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? (s == null ? TC.textPri : color) : TC.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSel
                        ? (s == null ? Colors.white : color)
                        : TC.textMute,
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
