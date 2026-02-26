import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

// ═════════════════════════════════════════════════════════════
//  TODAY / TOMORROW RESERVATION SUMMARY STRIP
// ═════════════════════════════════════════════════════════════
class TodayReservationStrip extends StatelessWidget {
  final TablesProvider prov;
  final VoidCallback? onViewAll;

  const TodayReservationStrip({
    super.key,
    required this.prov,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final todayList = prov.reservationsForDate(DateTime.now());
    final tomorrowList = prov.reservationsForDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    if (todayList.isEmpty && tomorrowList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text(
                  '📋',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Upcoming Reservations',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TC.textPri,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  GestureDetector(
                    onTap: onViewAll,
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TC.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DayCountTile(
                  label: 'Today',
                  count: todayList.length,
                  tables: todayList,
                  color: TC.accent,
                  bg: TC.accentLight,
                  emoji: '☀️',
                ),
              ),
              Container(width: 1, height: 60, color: TC.divider),
              Expanded(
                child: _DayCountTile(
                  label: 'Tomorrow',
                  count: tomorrowList.length,
                  tables: tomorrowList,
                  color: TC.reserved,
                  bg: TC.reservedBg,
                  emoji: '🌙',
                ),
              ),
            ],
          ),
          if (todayList.isNotEmpty) ...[
            const Divider(height: 1, color: TC.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                "Today's schedule",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TC.textMute,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                itemCount: todayList.length,
                itemBuilder: (_, i) {
                  final t = todayList[i];
                  final res = t.reservation!;
                  return _TodayChip(table: t, res: res);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCountTile extends StatelessWidget {
  final String label, emoji;
  final int count;
  final List<RestaurantTable> tables;
  final Color color, bg;

  const _DayCountTile({
    required this.label,
    required this.count,
    required this.tables,
    required this.color,
    required this.bg,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final guestTotal =
        tables.fold<int>(0, (sum, t) => sum + (t.reservation?.guestCount ?? 0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: TC.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count == 0 ? 'None' : '$count booking${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: count == 0 ? TC.textMute : color,
                  letterSpacing: -0.3,
                ),
              ),
              if (count > 0)
                Text(
                  '$guestTotal guests total',
                  style: const TextStyle(
                    fontSize: 10,
                    color: TC.textMute,
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

class _TodayChip extends StatelessWidget {
  final RestaurantTable table;
  final Reservation res;

  const _TodayChip({required this.table, required this.res});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = res.reservedFor.difference(now).inMinutes;
    final isOverdue = diff < 0;
    final isSoon = !isOverdue && diff <= 30;
    final timeColor = isOverdue
        ? TC.occupied
        : isSoon
            ? TC.nonAcAmber
            : TC.reserved;
    final timeBg = isOverdue
        ? TC.occupiedBg
        : isSoon
            ? TC.nonAcBg
            : TC.reservedBg;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: timeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: timeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            table.tableName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: timeColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            res.timeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: timeColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  FULL TODAY RESERVATIONS VIEW  (sheet / screen)
// ═════════════════════════════════════════════════════════════
class TodayReservationsSheet extends StatefulWidget {
  final TablesProvider prov;

  const TodayReservationsSheet({super.key, required this.prov});

  @override
  State<TodayReservationsSheet> createState() =>
      _TodayReservationsSheetState();
}

class _TodayReservationsSheetState extends State<TodayReservationsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayList = widget.prov.reservationsForDate(DateTime.now());
    final tomorrowList = widget.prov.reservationsForDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: TC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TC.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📋', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reservations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Today & Tomorrow',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: TC.surfaceWarm,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TC.border),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: TC.surface,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: TC.accent,
                unselectedLabelColor: TC.textMute,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(
                    text: 'Today  (${todayList.length})',
                  ),
                  Tab(
                    text: 'Tomorrow  (${tomorrowList.length})',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ReservationDayList(tables: todayList, prov: widget.prov),
                _ReservationDayList(tables: tomorrowList, prov: widget.prov),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationDayList extends StatelessWidget {
  final List<RestaurantTable> tables;
  final TablesProvider prov;

  const _ReservationDayList({required this.tables, required this.prov});

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: TC.surfaceWarm,
                shape: BoxShape.circle,
              ),
              child: const Text('✨', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No reservations',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TC.textPri,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Nothing booked for this day',
              style: TextStyle(fontSize: 12, color: TC.textSec),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: tables.length,
      itemBuilder: (ctx, i) {
        final table = tables[i];
        final res = table.reservation!;
        return _ReservationDetailCard(table: table, res: res, prov: prov);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RESERVATION DETAIL CARD  (who reserved which table)
// ─────────────────────────────────────────────────────────────
class _ReservationDetailCard extends StatelessWidget {
  final RestaurantTable table;
  final Reservation res;
  final TablesProvider prov;

  const _ReservationDetailCard({
    required this.table,
    required this.res,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = res.reservedFor.difference(now).inMinutes;
    final isOverdue = diff < 0;
    final isSoon = !isOverdue && diff <= 30;
    final isEndingSoon = res.isEndingSoon;

    final Color accent = isEndingSoon
        ? TC.occupied
        : isOverdue
            ? TC.occupied
            : isSoon
                ? TC.nonAcAmber
                : TC.reserved;
    final Color accentBg = isEndingSoon
        ? TC.occupiedBg
        : isOverdue
            ? TC.occupiedBg
            : isSoon
                ? TC.nonAcBg
                : TC.reservedBg;

    final secColor = _sectionColor(table.section);
    final secBg = _sectionBg(table.section);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isSoon || isEndingSoon || isOverdue)
              ? accent.withOpacity(0.4)
              : TC.border,
          width: (isSoon || isEndingSoon || isOverdue) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Table badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: secBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: secColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        table.section.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        table.tableName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: secColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Section label
                Text(
                  table.section.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TC.textMute,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEndingSoon
                        ? 'Ending soon'
                        : isOverdue
                            ? 'Overdue'
                            : isSoon
                                ? 'Arriving soon'
                                : res.countdownLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TC.divider),
          // ── Guest info ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TC.textPri,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (res.phone != null) ...[
                            const Icon(
                              Icons.phone_outlined,
                              size: 11,
                              color: TC.textMute,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              res.phone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: TC.textSec,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          const Icon(
                            Icons.people_outline,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${res.guestCount} guests',
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
                // Time block
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🟢',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            res.timeLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      if (res.checkOut != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔴', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              res.checkOutTimeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        if (res.checkOut != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _durationLabel(res.reservedFor, res.checkOut!),
                            style: TextStyle(
                              fontSize: 10,
                              color: accent.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (res.notes != null && res.notes!.isNotEmpty) ...[
            const Divider(height: 1, color: TC.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      res.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TC.textSec,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── Quick actions ────────────────────────────────
          const Divider(height: 1, color: TC.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                _QuickAction(
                  icon: Icons.restaurant_rounded,
                  label: 'Seat',
                  color: TC.available,
                  onTap: () => prov.seatGuests(table.id, res.customerName),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  color: TC.occupied,
                  onTap: () => prov.cancelReservation(table.id),
                ),
                if (table.isPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8DC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⭐ Premium',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB8900A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _durationLabel(DateTime from, DateTime to) {
    final mins = to.difference(from).inMinutes;
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${mins}m slot';
  }

  Color _sectionColor(TableSection s) {
    switch (s) {
      case TableSection.ac:
        return const Color(0xFF1A6BB5);
      case TableSection.nonAc:
        return const Color(0xFFB8730A);
      case TableSection.rooftop:
        return const Color(0xFF1A8070);
      case TableSection.garden:
        return const Color(0xFF2E7D32);
      case TableSection.privateRoom:
        return const Color(0xFF6B3FA0);
    }
  }

  Color _sectionBg(TableSection s) {
    switch (s) {
      case TableSection.ac:
        return const Color(0xFFE8F2FC);
      case TableSection.nonAc:
        return const Color(0xFFFFF4DC);
      case TableSection.rooftop:
        return const Color(0xFFE4F5F2);
      case TableSection.garden:
        return const Color(0xFFE8F5E9);
      case TableSection.privateRoom:
        return const Color(0xFFF3EBF9);
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
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
      ),
    );
  }
}