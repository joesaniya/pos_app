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

    // FIX: reads from _calendarReservations — works for ANY date
    final selectedReservations = prov.reservationsForDate(_selectedDate);

    // FIX: dot indicators — which days in focused month have bookings
    final datesWithDots = prov.reservationDatesInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );

    // Count badge for month header
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
              // ── Day grid ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: _CalendarGrid(
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  datesWithDots: datesWithDots,
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
                  itemBuilder: (_, i) =>
                      _CalendarReservationCard(item: selectedReservations[i]),
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
//  CALENDAR GRID
// ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Set<DateTime> datesWithDots;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.datesWithDots,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startOffset = firstDay.weekday % 7; // Sunday = 0
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
              return const Expanded(child: SizedBox(height: 44));
            }

            final date = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final isToday = date == todayNorm;
            final isSelected = date == selNorm;
            final hasDot = datesWithDots.contains(date);

            return Expanded(
              child: GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  height: 44,
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
                      if (hasDot) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : TC.reserved,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
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
//  RESERVATION CARD  (calendar date list)
// ─────────────────────────────────────────────────────────────
class _CalendarReservationCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const _CalendarReservationCard({required this.item});

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

    return Container(
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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

/*import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/calendar_reserve_sheet.dart';
import 'package:pos_app/screens/tables_screen/sheet/table_etail_sheet.dart';
import 'package:provider/provider.dart';
import '../table_theme.dart';
import '../widgets/shared_widgets.dart';


// ═════════════════════════════════════════════════════════════
//  CALENDAR VIEW
// ═════════════════════════════════════════════════════════════
class CalendarView extends StatefulWidget {
  final TablesProvider prov;
  const CalendarView({super.key, required this.prov});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _displayMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Set<DateTime> get _reservedDates {
    final dates = <DateTime>{};
    for (final t in widget.prov.allTables) {
      if (t.reservation != null) {
        final d = t.reservation!.reservedFor;
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }
    return dates;
  }

  List<RestaurantTable> get _reservationsOnSelected {
    return widget.prov.allTables.where((t) {
      if (t.reservation == null) return false;
      final d = t.reservation!.reservedFor;
      return d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor));
  }

  @override
  Widget build(BuildContext context) {
    final reservedDates = _reservedDates;
    final todayRes = _reservationsOnSelected;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: TC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TC.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                _CalendarHeader(
                  displayMonth: _displayMonth,
                  reservedDates: reservedDates,
                  onPrev: () => setState(
                    () => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1),
                  ),
                  onNext: () => setState(
                    () => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((d) => Expanded(
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
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 4),
                _buildMonthGrid(reservedDates, todayDate),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate == todayDate
                        ? 'Today'
                        : _selectedDate == todayDate.add(const Duration(days: 1))
                            ? 'Tomorrow'
                            : '${_monthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.day}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: TC.textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    todayRes.isEmpty
                        ? 'No reservations'
                        : '${todayRes.length} reservation${todayRes.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: todayRes.isEmpty ? TC.textMute : TC.reserved,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.prov.canAddReservation)
                GestureDetector(
                  onTap: () => _openAddReservation(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: TC.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: TC.accent.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'Reserve',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: todayRes.isEmpty
              ? CalendarEmptyDay(date: _selectedDate, todayDate: todayDate)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: todayRes.length,
                  itemBuilder: (ctx, i) => ReservationTimelineCard(
                    table: todayRes[i],
                    prov: widget.prov,
                    onTap: () => _openTableDetail(ctx, todayRes[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(Set<DateTime> reservedDates, DateTime todayDate) {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
        ),
        itemCount: startWeekday + daysInMonth,
        itemBuilder: (_, idx) {
          if (idx < startWeekday) return const SizedBox.shrink();
          final day = idx - startWeekday + 1;
          final date = DateTime(_displayMonth.year, _displayMonth.month, day);
          final isToday = date == todayDate;
          final isSel = date == _selectedDate;
          final hasRes = reservedDates.contains(date);
          final isPast = date.isBefore(todayDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel ? TC.accent : isToday ? TC.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: isToday && !isSel ? Border.all(color: TC.accent, width: 1.5) : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: (isSel || isToday) ? FontWeight.w800 : FontWeight.w500,
                      color: isSel ? Colors.white : isPast ? TC.textMute : TC.textPri,
                    ),
                  ),
                  if (hasRes && !isSel)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isPast ? TC.textMute : TC.reserved,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (hasRes && isSel)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddReservation(BuildContext context) {
    final allTables = widget.prov.allTables
        .where((t) => t.status != TableStatus.cleaning)
        .toList();
    if (allTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tables available'), backgroundColor: TC.occupied),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: widget.prov,
        child: CalendarReserveSheet(
          provider: widget.prov,
          availableTables: allTables,
          initialDate: _selectedDate,
        ),
      ),
    );
  }

  void _openTableDetail(BuildContext ctx, RestaurantTable table) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: widget.prov,
        child: TableDetailSheet(table: table),
      ),
    );
  }

  String _monthName(int m) => const [
        '',
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
      ][m];
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR HEADER
// ─────────────────────────────────────────────────────────────
class _CalendarHeader extends StatelessWidget {
  final DateTime displayMonth;
  final Set<DateTime> reservedDates;
  final VoidCallback onPrev, onNext;
  const _CalendarHeader({
    required this.displayMonth,
    required this.reservedDates,
    required this.onPrev,
    required this.onNext,
  });

  String _monthName(int m) => const [
        '',
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
      ][m];

  @override
  Widget build(BuildContext context) {
    final thisMonthCount = reservedDates
        .where((d) => d.month == displayMonth.month && d.year == displayMonth.year)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthName(displayMonth.month),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: TC.textPri,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${displayMonth.year}',
                  style: const TextStyle(fontSize: 12, color: TC.textMute, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (thisMonthCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: TC.reservedBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TC.reserved.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    '$thisMonthCount this month',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TC.reserved,
                    ),
                  ),
                ],
              ),
            ),
          NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: 4),
          NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR EMPTY DAY
// ─────────────────────────────────────────────────────────────
class CalendarEmptyDay extends StatelessWidget {
  final DateTime date, todayDate;
  const CalendarEmptyDay({super.key, required this.date, required this.todayDate});

  @override
  Widget build(BuildContext context) {
    final isPast = date.isBefore(todayDate);
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isPast ? TC.surfaceWarm : TC.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Text(isPast ? '📋' : '✨', style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 14),
              Text(
                isPast ? 'No records for this day' : 'No reservations yet',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.textPri),
              ),
              const SizedBox(height: 5),
              Text(
                isPast ? 'This date has passed' : 'Tap + Reserve to add a booking',
                style: const TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RESERVATION TIMELINE CARD
// ─────────────────────────────────────────────────────────────
class ReservationTimelineCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;
  const ReservationTimelineCard({
    super.key,
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final res = table.reservation!;
    final secColor = sectionColor(table.section);
    final secBg = sectionBg(table.section);
    final diff = res.reservedFor.difference(DateTime.now());
    final isOverdue = diff.isNegative;
    final isSoon = !isOverdue && diff.inMinutes <= 30;
    final isEnding = res.isEndingSoon;
    final timeColor = isEnding
        ? TC.occupied
        : isOverdue
            ? TC.occupied
            : isSoon
                ? const Color(0xFFB8730A)
                : TC.reserved;
    final timeBg = isEnding
        ? TC.occupiedBg
        : isOverdue
            ? TC.occupiedBg
            : isSoon
                ? const Color(0xFFFFF4DC)
                : TC.reservedBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isSoon || isEnding) ? timeColor.withOpacity(0.4) : TC.border,
            width: (isSoon || isEnding) ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: timeBg,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      res.timeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: timeColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      res.countdownLabel,
                      style: TextStyle(fontSize: 10, color: timeColor.withOpacity(0.8), fontWeight: FontWeight.w600),
                    ),
                    if (res.checkOut != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '→${res.checkOutTimeLabel}',
                        style: TextStyle(fontSize: 9, color: timeColor.withOpacity(0.7), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              res.customerName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TC.textPri),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: secBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: secColor.withOpacity(0.25)),
                            ),
                            child: Text(
                              '${table.section.emoji} ${table.tableName}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: secColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          ResBadge(icon: Icons.people_outline, text: '${res.guestCount} guests'),
                          const SizedBox(width: 8),
                          if (res.phone != null) ResBadge(icon: Icons.phone_outlined, text: res.phone!),
                        ],
                      ),
                      if (res.notes != null && res.notes!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Text('📝', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                res.notes!,
                                style: const TextStyle(fontSize: 11, color: TC.textSec, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => prov.seatGuests(table.id, res.customerName),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: TC.availableBg, borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.restaurant_rounded, color: TC.available, size: 15),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => prov.cancelReservation(table.id),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: TC.occupiedBg, borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.close_rounded, color: TC.occupied, size: 15),
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
}

class ResBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const ResBadge({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: TC.textMute),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11, color: TC.textSec, fontWeight: FontWeight.w600)),
      ],
    );
  }
}*/
