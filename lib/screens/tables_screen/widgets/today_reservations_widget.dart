import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────
bool _isUpcoming(ReservationHistoryItem r) {
  if (r.status == 'no_show') return false;
  final now = DateTime.now();
  // If reservation has a checkOut time, show until that time passes
  // Otherwise show until reservedFor time passes
  final endTime = r.checkOut ?? r.reservedFor;
  return endTime.isAfter(now);
}

bool _isTomorrowUpcoming(ReservationHistoryItem r) {
  return r.status != 'no_show';
}

class TodayReservationStrip extends StatelessWidget {
  final TablesProvider prov;
  final VoidCallback onViewAll;

  const TodayReservationStrip({
    super.key,
    required this.prov,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final todayUpcoming = prov.todayReservations.where(_isUpcoming).toList();

    final tomorrowUpcoming = prov
        .reservationsForDate(now.add(const Duration(days: 1)))
        .where(_isTomorrowUpcoming)
        .toList();

    final todayCount = todayUpcoming.length;
    final tomorrowCount = tomorrowUpcoming.length;

    // Hide strip entirely if nothing upcoming today or tomorrow
    if (todayCount == 0 && tomorrowCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                const Text(
                  'Upcoming Reservations',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TC.textPri,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TC.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TC.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Today / Tomorrow count pills ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                if (todayCount > 0)
                  _CountPill(
                    label: 'Today',
                    count: todayCount,
                    color: TC.reserved,
                    icon: Icons.today_rounded,
                  ),
                if (todayCount > 0 && tomorrowCount > 0)
                  const SizedBox(width: 8),
                if (tomorrowCount > 0)
                  _CountPill(
                    label: 'Tomorrow',
                    count: tomorrowCount,
                    color: TC.available,
                    icon: Icons.event_rounded,
                  ),
              ],
            ),
          ),
          // ── Next upcoming reservation cards ───────────
          if (todayCount > 0) ...[
            const Divider(height: 1, color: TC.divider),
            _UpcomingList(items: todayUpcoming),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  COUNT PILL
// ─────────────────────────────────────────────────────────────
class _CountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPCOMING LIST — first 3 upcoming reservations today
// ─────────────────────────────────────────────────────────────
class _UpcomingList extends StatelessWidget {
  final List<ReservationHistoryItem> items;
  const _UpcomingList({required this.items});

  @override
  Widget build(BuildContext context) {
    final display = items.take(3).toList();
    if (display.isEmpty) return const SizedBox.shrink();

    return Column(
      children: display.map((item) => _MiniReservationRow(item: item)).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MINI RESERVATION ROW
// ─────────────────────────────────────────────────────────────
class _MiniReservationRow extends StatelessWidget {
  final ReservationHistoryItem item;
  const _MiniReservationRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      _ => TC.reserved,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TC.divider, width: 0.8)),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              _fmtTime(item.reservedFor),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Table badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: sectionColor(sectionEnum).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: sectionColor(sectionEnum),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Text(
              item.customerName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TC.textPri,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Guest count
          Row(
            children: [
              const Icon(Icons.people_outline, size: 11, color: TC.textMute),
              const SizedBox(width: 3),
              Text(
                '${item.guestCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TC.textSec,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ═════════════════════════════════════════════════════════════
//  TODAY RESERVATIONS SHEET  (full list modal)
// ═════════════════════════════════════════════════════════════
class TodayReservationsSheet extends StatelessWidget {
  final TablesProvider prov;
  const TodayReservationsSheet({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Only show upcoming (future, not seated/no_show)
    final today = prov.todayReservations.where(_isUpcoming).toList();
    final tomorrow = prov
        .reservationsForDate(now.add(const Duration(days: 1)))
        .where(_isTomorrowUpcoming)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SheetTopBar(
            emoji: '📅',
            title: 'Upcoming Reservations',
            subtitle: 'Today & Tomorrow',
            color: TC.reserved,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (today.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Today',
                      count: today.length,
                      color: TC.reserved,
                    ),
                    const SizedBox(height: 6),
                    ...today.map((r) => _SheetReservationCard(item: r)),
                  ],
                  if (tomorrow.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionHeader(
                      label: 'Tomorrow',
                      count: tomorrow.length,
                      color: TC.available,
                    ),
                    const SizedBox(height: 6),
                    ...tomorrow.map((r) => _SheetReservationCard(item: r)),
                  ],
                  if (today.isEmpty && tomorrow.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No upcoming reservations',
                          style: TextStyle(fontSize: 14, color: TC.textMute),
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

// ─────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: TC.divider)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHEET RESERVATION CARD
// ─────────────────────────────────────────────────────────────
class _SheetReservationCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const _SheetReservationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      _ => TC.reserved,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TC.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _fmtTime(item.reservedFor),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: sectionColor(sectionEnum).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: sectionColor(sectionEnum),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TC.textPri,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.phone != null)
                  Text(
                    item.phone!,
                    style: const TextStyle(fontSize: 11, color: TC.textMute),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 12, color: TC.textMute),
              const SizedBox(width: 3),
              Text(
                '${item.guestCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TC.textSec,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

//all displayed
/*import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import '../widgets/shared_widgets.dart';

class TodayReservationStrip extends StatelessWidget {
  final TablesProvider prov;
  final VoidCallback onViewAll;

  const TodayReservationStrip({
    super.key,
    required this.prov,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final todayCount = prov.todayReservationCount;
    final tomorrowCount = prov.tomorrowReservationCount;

    // Hide strip entirely if nothing today or tomorrow
    if (todayCount == 0 && tomorrowCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                const Text(
                  'Reservations',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TC.textPri,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TC.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TC.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Today / Tomorrow count pills ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                if (todayCount > 0)
                  _CountPill(
                    label: 'Today',
                    count: todayCount,
                    color: TC.reserved,
                    icon: Icons.today_rounded,
                  ),
                if (todayCount > 0 && tomorrowCount > 0)
                  const SizedBox(width: 8),
                if (tomorrowCount > 0)
                  _CountPill(
                    label: 'Tomorrow',
                    count: tomorrowCount,
                    color: TC.available,
                    icon: Icons.event_rounded,
                  ),
              ],
            ),
          ),
          // ── Next upcoming reservation cards ───────────
          if (todayCount > 0) ...[
            const Divider(height: 1, color: TC.divider),
            _UpcomingList(prov: prov),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  COUNT PILL
// ─────────────────────────────────────────────────────────────
class _CountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPCOMING LIST — first 3 reservations today, sorted by time
// ─────────────────────────────────────────────────────────────
class _UpcomingList extends StatelessWidget {
  final TablesProvider prov;
  const _UpcomingList({required this.prov});

  @override
  Widget build(BuildContext context) {
    // Use calendarReservations-based getter — correct for all dates
    final items = prov.todayReservations.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: items.map((item) => _MiniReservationRow(item: item)).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MINI RESERVATION ROW
// ─────────────────────────────────────────────────────────────
class _MiniReservationRow extends StatelessWidget {
  final ReservationHistoryItem item;
  const _MiniReservationRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = item.reservedFor.isBefore(now);
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'no_show' => TC.cleaning,
      _ => isPast ? const Color(0xFF9CA3AF) : TC.reserved,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: TC.divider, width: 0.8)),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              _fmtTime(item.reservedFor),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Table badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: sectionColor(sectionEnum).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: sectionColor(sectionEnum),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Text(
              item.customerName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TC.textPri,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Guest count
          Row(
            children: [
              const Icon(Icons.people_outline, size: 11, color: TC.textMute),
              const SizedBox(width: 3),
              Text(
                '${item.guestCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TC.textSec,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ═════════════════════════════════════════════════════════════
//  TODAY RESERVATIONS SHEET  (full list modal)
// ═════════════════════════════════════════════════════════════
class TodayReservationsSheet extends StatelessWidget {
  final TablesProvider prov;
  const TodayReservationsSheet({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final today = prov.todayReservations;
    final tomorrow = prov.reservationsForDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    return Container(
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SheetTopBar(
            emoji: '📅',
            title: 'Reservations',
            subtitle: 'Today & Tomorrow',
            color: TC.reserved,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (today.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Today',
                      count: today.length,
                      color: TC.reserved,
                    ),
                    const SizedBox(height: 6),
                    ...today.map((r) => _SheetReservationCard(item: r)),
                  ],
                  if (tomorrow.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionHeader(
                      label: 'Tomorrow',
                      count: tomorrow.length,
                      color: TC.available,
                    ),
                    const SizedBox(height: 6),
                    ...tomorrow.map((r) => _SheetReservationCard(item: r)),
                  ],
                  if (today.isEmpty && tomorrow.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No upcoming reservations',
                          style: TextStyle(fontSize: 14, color: TC.textMute),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: TC.divider)),
      ],
    );
  }
}

class _SheetReservationCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const _SheetReservationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPast = item.reservedFor.isBefore(DateTime.now());
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'no_show' => TC.cleaning,
      _ => isPast ? const Color(0xFF9CA3AF) : TC.reserved,
    };
    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TC.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _fmtTime(item.reservedFor),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: sectionColor(sectionEnum).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: sectionColor(sectionEnum),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TC.textPri,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.phone != null)
                  Text(
                    item.phone!,
                    style: const TextStyle(fontSize: 11, color: TC.textMute),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 12, color: TC.textMute),
              const SizedBox(width: 3),
              Text(
                '${item.guestCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TC.textSec,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}


*/
