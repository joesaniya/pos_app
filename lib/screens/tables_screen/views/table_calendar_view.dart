import 'package:flutter/material.dart';
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
}