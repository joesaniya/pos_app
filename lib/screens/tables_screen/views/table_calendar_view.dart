import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/calendar_reserve_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:provider/provider.dart';

class CalendarView extends StatefulWidget {
  final TablesProvider prov;
  const CalendarView({super.key, required this.prov});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );

  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;
    final selectedReservations = prov.reservationsForDate(_selectedDate);
    final datesWithDots = prov.reservationDatesInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );

    // Build a map of date → count for the focused month
    final dateCountMap = <DateTime, int>{};
    for (final d in datesWithDots) {
      dateCountMap[d] = prov.reservationsForDate(d).length;
    }

    final monthTotal = datesWithDots.fold<int>(
      0,
      (sum, d) => sum + prov.reservationsForDate(d).length,
    );

    return Column(
      children: [
        // ── Calendar card ────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: TC.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TC.border),
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
              // ── Month header ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _monthName(_focusedMonth.month),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: TC.textPri,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${_focusedMonth.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TC.textMute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    if (monthTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TC.reservedBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: TC.reserved.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '📅 $monthTotal this month',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: TC.reserved,
                          ),
                        ),
                      ),
                    const Spacer(),
                    _NavBtn(icon: Icons.chevron_left, onTap: _prevMonth),
                    const SizedBox(width: 4),
                    _NavBtn(icon: Icons.chevron_right, onTap: _nextMonth),
                  ],
                ),
              ),
              // ── Weekday labels ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: TC.textMute,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              // ── Day grid with per-date counts ──────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: _CalendarGrid(
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  dateCountMap: dateCountMap,
                  onDateSelected: (d) => setState(() => _selectedDate = d),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Selected date label + Reserve button ─────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(_selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: TC.textPri,
                    ),
                  ),
                  Text(
                    selectedReservations.isEmpty
                        ? 'No reservations'
                        : '${selectedReservations.length} reservation'
                              '${selectedReservations.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedReservations.isEmpty
                          ? TC.textMute
                          : TC.reserved,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (prov.canAddReservation)
                GestureDetector(
                  onTap: () => _openReserveSheet(context, prov),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: TC.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Reserve',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Reservation list for selected date ───────────
        Expanded(
          child: prov.calendarLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: TC.accent,
                    strokeWidth: 2,
                  ),
                )
              : selectedReservations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: TC.surfaceWarm,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🌙', style: TextStyle(fontSize: 34)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No reservations yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: TC.textPri,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap + Reserve to add a booking',
                        style: TextStyle(fontSize: 12, color: TC.textMute),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: selectedReservations.length,
                  itemBuilder: (_, i) => _CalendarReservationCard(
                    item: selectedReservations[i],
                    prov: prov,
                  ),
                ),
        ),
      ],
    );
  }

  void _openReserveSheet(BuildContext context, TablesProvider prov) {
    final sorted = [...prov.allTables]
      ..sort((a, b) {
        if (a.status == TableStatus.available &&
            b.status != TableStatus.available)
          return -1;
        if (b.status == TableStatus.available &&
            a.status != TableStatus.available)
          return 1;
        return a.tableNumber.compareTo(b.tableNumber);
      });

    if (sorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tables configured yet'),
          backgroundColor: TC.occupied,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: CalendarReserveSheet(
          provider: prov,
          availableTables: sorted,
          initialDate: _selectedDate,
        ),
      ),
    );
  }

  String _monthName(int m) => [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
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
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR GRID  — shows per-date reservation count badge
// ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, int> dateCountMap;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.dateCountMap,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final selNorm = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNumber = cellIndex - startOffset + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 52));
            }

            final date = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final isToday = date == todayNorm;
            final isSelected = date == selNorm;
            final count = dateCountMap[date] ?? 0;
            final hasReservations = count > 0;

            return Expanded(
              child: GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TC.accent
                        : isToday
                        ? TC.accentLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: TC.accent.withOpacity(0.4),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? TC.accent
                              : TC.textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasReservations)
                        // Show count badge instead of plain dot
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.3)
                                : TC.reserved.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : TC.reserved,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  NAV BUTTON
// ─────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TC.border),
        ),
        child: Icon(icon, size: 18, color: TC.textSec),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RESERVATION CARD  (calendar date list) — tappable for detail
// ─────────────────────────────────────────────────────────────
class _CalendarReservationCard extends StatelessWidget {
  final ReservationHistoryItem item;
  final TablesProvider prov;
  const _CalendarReservationCard({required this.item, required this.prov});

  @override
  Widget build(BuildContext context) {
    final isPast = item.reservedFor.isBefore(DateTime.now());
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'cancelled' => TC.occupied,
      'no_show' => TC.cleaning,
      _ => isPast ? const Color(0xFF9CA3AF) : TC.reserved,
    };
    final statusLabel = switch (item.status) {
      'seated' => '🍽️ Seated',
      'cancelled' => '✖️ Cancelled',
      'no_show' => '👻 No-show',
      _ => isPast ? '✅ Completed' : '📅 Upcoming',
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TC.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Time sidebar ─────────────────────────────
              Container(
                width: 66,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  border: Border(
                    right: BorderSide(color: statusColor.withOpacity(0.15)),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: statusColor.withOpacity(0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmtTime(item.reservedFor),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.2,
                      ),
                    ),
                    if (item.checkOut != null) ...[
                      const SizedBox(height: 1),
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 9,
                        color: statusColor.withOpacity(0.5),
                      ),
                      Text(
                        _fmtTime(item.checkOut!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              // ── Details ──────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.people_outline,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.guestCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: TC.textSec,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: TC.textMute,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: TC.textPri,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.phone != null || item.notes != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (item.phone != null) ...[
                              const Icon(
                                Icons.phone_outlined,
                                size: 11,
                                color: TC.textMute,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                item.phone!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TC.textSec,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (item.notes != null) ...[
                              const Icon(
                                Icons.notes_rounded,
                                size: 11,
                                color: TC.textMute,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TC.textSec,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _ReservationDetailSheet(item: item, prov: prov),
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
//  RESERVATION DETAIL SHEET  (tap-through from calendar card)
// ═════════════════════════════════════════════════════════════
class _ReservationDetailSheet extends StatelessWidget {
  final ReservationHistoryItem item;
  final TablesProvider prov;
  const _ReservationDetailSheet({required this.item, required this.prov});

  @override
  Widget build(BuildContext context) {
    final isPast = item.reservedFor.isBefore(DateTime.now());
    final isActive = item.status == 'active' || item.status == 'seated';

    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'cancelled' => TC.occupied,
      'no_show' => TC.cleaning,
      _ => isPast ? const Color(0xFF9CA3AF) : TC.reserved,
    };
    final statusLabel = switch (item.status) {
      'seated' => '🍽️ Seated',
      'cancelled' => '✖️ Cancelled',
      'no_show' => '👻 No Show',
      _ => isPast ? '✅ Completed' : '📅 Upcoming',
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _statusEmoji(item.status, isPast),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.customerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: TC.textPri,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: sectionColor(
                                  sectionEnum,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sectionColor(sectionEnum),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
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
            const Divider(height: 1, color: TC.divider),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Guest Details card ─────────────────
                  _SectionLabel('Guest Details'),
                  const SizedBox(height: 8),
                  _DetailCard(
                    children: [
                      _DetailRow(
                        icon: '👤',
                        label: 'Name',
                        value: item.customerName,
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        icon: '📱',
                        label: 'Phone',
                        value: item.phone ?? '—',
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        icon: '👥',
                        label: 'Party Size',
                        value: '${item.guestCount} guests',
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        _DetailDivider(),
                        _DetailRow(
                          icon: '📝',
                          label: 'Notes',
                          value: item.notes!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Reservation Details card ────────────
                  _SectionLabel('Reservation Details'),
                  const SizedBox(height: 8),
                  _DetailCard(
                    children: [
                      _DetailRow(
                        icon: '🏷️',
                        label: 'Table',
                        value:
                            'Table ${item.tableNumber.toString().padLeft(2, '0')} · ${sectionEnum.label}',
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        icon: '📅',
                        label: 'Date',
                        value: _fmtDate(item.reservedFor),
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        icon: '🟢',
                        label: 'Check-in',
                        value: _fmtTime(item.reservedFor),
                      ),
                      if (item.checkOut != null) ...[
                        _DetailDivider(),
                        _DetailRow(
                          icon: '🔴',
                          label: 'Check-out',
                          value: _fmtTime(item.checkOut!),
                        ),
                        _DetailDivider(),
                        _DetailRow(
                          icon: '⏱️',
                          label: 'Duration',
                          value: _fmtDuration(item.reservedFor, item.checkOut!),
                        ),
                      ],
                      _DetailDivider(),
                      _DetailRow(
                        icon: '🏷️',
                        label: 'Reserved by',
                        value: item.createdByName,
                      ),
                      _DetailDivider(),
                      _DetailRow(
                        icon: '🕐',
                        label: 'Created at',
                        value: _fmtDateTime(item.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Action buttons (only if active) ─────
                  if (isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _ActionButton(
                            label: 'Edit Reservation',
                            emoji: '✏️',
                            color: TC.accent,
                            onTap: () {
                              Navigator.pop(context);
                              _openEditSheet(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            label: 'Cancel',
                            emoji: '✖️',
                            color: const Color(0xFFDC2626),
                            outlined: true,
                            onTap: () => _confirmCancel(context),
                          ),
                        ),
                      ],
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

  void _openEditSheet(BuildContext context) {
    // Convert ReservationHistoryItem → Reservation for the edit sheet
    final table = prov.allTables
        .where((t) => t.tableNumber == item.tableNumber)
        .firstOrNull;
    if (table == null) return;

    final reservation = Reservation(
      id: item.id,
      customerName: item.customerName,
      phone: item.phone,
      guestCount: item.guestCount,
      reservedFor: item.reservedFor,
      checkOut: item.checkOut,
      notes: item.notes,
      createdAt: item.createdAt,
      createdByName: item.createdByName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CalendarEditSheet(
          tableId: table.id,
          provider: prov,
          existing: reservation,
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cancel Reservation?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: Text(
        'The reservation for ${item.customerName} will be cancelled and the table freed.',
        style: const TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            // Cancel by table ID — find matching table
            final table = prov.allTables
                .where((t) => t.tableNumber == item.tableNumber)
                .firstOrNull;
            if (table != null) prov.cancelReservation(table.id);
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // close detail sheet
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel Booking'),
        ),
      ],
    ),
  );

  String _statusEmoji(String status, bool isPast) => switch (status) {
    'seated' => '🍽️',
    'cancelled' => '✖️',
    'no_show' => '👻',
    _ => isPast ? '✅' : '📅',
  };

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }

  String _fmtDate(DateTime dt) {
    const months = [
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today, ${months[dt.month - 1]} ${dt.day}';
    if (d == today.add(const Duration(days: 1)))
      return 'Tomorrow, ${months[dt.month - 1]} ${dt.day}';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _fmtDateTime(DateTime dt) {
    const months = [
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${_fmtTime(dt)}';
  }

  String _fmtDuration(DateTime from, DateTime to) {
    final mins = to.difference(from).inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Inline edit sheet launched from calendar detail ──────────────────────────
// Thin wrapper so the calendar view can open reservation editing
// without importing reservation_sheet.dart directly.
class _CalendarEditSheet extends StatelessWidget {
  final String tableId;
  final TablesProvider provider;
  final Reservation existing;
  const _CalendarEditSheet({
    required this.tableId,
    required this.provider,
    required this.existing,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate to the standard ReservationSheet widget used elsewhere
    // Import it via your existing import alias at the top of this file:
    //   import 'reservation_sheet.dart';
    // For now we just pop — replace with your ReservationSheet widget below.
    //
    // return ReservationSheet(
    //   tableId: tableId,
    //   provider: provider,
    //   existing: existing,
    // );
    //
    // PLACEHOLDER — swap the return below with the line above once you add
    // the import for reservation_sheet.dart at the top of this file.
    return Container(
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: Text('ReservationSheet goes here — add import above.'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: TC.textMute,
      letterSpacing: 1.2,
    ),
  );
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TC.surfaceWarm,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TC.border),
    ),
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  final String icon, label, value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 12, color: TC.textSec)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TC.textPri,
          ),
        ),
      ),
    ],
  );
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 18, color: TC.divider);
}

class _ActionButton extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
