import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS  —  warm cream / terracotta / forest green
// ═══════════════════════════════════════════════════════════════
class TC {
  static const bg = Color(0xFFFAF8F4); // warm parchment
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFF7F4EE); // cream card
  static const border = Color(0xFFE8E3D8);
  static const borderLight = Color(0xFFF0ECE4);

  // Accent — terracotta
  static const accent = Color(0xFFC25A2A); // terracotta
  static const accentLight = Color(0xFFFAEDE5);
  static const accentMid = Color(0xFFD97B47);

  // Section colors
  static const acBlue = Color(0xFF1A6BB5);
  static const acBlueBg = Color(0xFFE8F2FC);
  static const nonAcAmber = Color(0xFFB8730A);
  static const nonAcBg = Color(0xFFFFF4DC);
  static const rooftopTeal = Color(0xFF1A8070);
  static const rooftopBg = Color(0xFFE4F5F2);
  static const gardenGreen = Color(0xFF2E7D32);
  static const gardenBg = Color(0xFFE8F5E9);
  static const privatePurp = Color(0xFF6B3FA0);
  static const privateBg = Color(0xFFF3EBF9);

  // Status
  static const available = Color(0xFF2E7D32);
  static const availableBg = Color(0xFFE8F5E9);
  static const occupied = Color(0xFFC25A2A);
  static const occupiedBg = Color(0xFFFAEDE5);
  static const reserved = Color(0xFF1A6BB5);
  static const reservedBg = Color(0xFFE8F2FC);
  static const cleaning = Color(0xFF888898);
  static const cleaningBg = Color(0xFFF3F3F8);

  // Text
  static const textPri = Color(0xFF1E1A14);
  static const textSec = Color(0xFF7A705E);
  static const textMute = Color(0xFFB0A898);
  static const divider = Color(0xFFEEE9E0);
}

// Section → color helpers
Color _sectionColor(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlue;
    case TableSection.nonAc:
      return TC.nonAcAmber;
    case TableSection.rooftop:
      return TC.rooftopTeal;
    case TableSection.garden:
      return TC.gardenGreen;
    case TableSection.privateRoom:
      return TC.privatePurp;
  }
}

Color _sectionBg(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlueBg;
    case TableSection.nonAc:
      return TC.nonAcBg;
    case TableSection.rooftop:
      return TC.rooftopBg;
    case TableSection.garden:
      return TC.gardenBg;
    case TableSection.privateRoom:
      return TC.privateBg;
  }
}

Color _statusColor(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.available;
    case TableStatus.occupied:
      return TC.occupied;
    case TableStatus.reserved:
      return TC.reserved;
    case TableStatus.cleaning:
      return TC.cleaning;
  }
}

Color _statusBg(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.availableBg;
    case TableStatus.occupied:
      return TC.occupiedBg;
    case TableStatus.reserved:
      return TC.reservedBg;
    case TableStatus.cleaning:
      return TC.cleaningBg;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════════════════════
class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TablesProvider(),
      child: const _TablesBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MAIN BODY
// ═════════════════════════════════════════════════════════════════════════════
class _TablesBody extends StatefulWidget {
  const _TablesBody();

  @override
  State<_TablesBody> createState() => _TablesBodyState();
}

class _TablesBodyState extends State<_TablesBody>
    with SingleTickerProviderStateMixin {
  bool _calendarMode = false;
  late final AnimationController _toggleAnim;

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _toggleAnim.dispose();
    super.dispose();
  }

  void _switchMode(bool toCalendar) {
    setState(() => _calendarMode = toCalendar);
    if (toCalendar) {
      _toggleAnim.forward();
    } else {
      _toggleAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<TablesProvider>(
      builder: (ctx, prov, _) => Scaffold(
        backgroundColor: TC.bg,
        floatingActionButton: _calendarMode
            ? null
            : _AddTableFAB(onTap: () => _openAddTable(ctx, prov)),
        body: SafeArea(
          child: Column(
            children: [
              _Header(prov: prov),
              // ── View toggle pill ─────────────────────────
              _ViewToggle(isCalendar: _calendarMode, onChanged: _switchMode),
              // ── Content ──────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _calendarMode
                      ? _CalendarView(
                          key: const ValueKey('calendar'),
                          prov: prov,
                        )
                      : Column(
                          key: const ValueKey('tables'),
                          children: [
                            _SummaryBar(prov: prov),
                            _SectionTabs(prov: prov),
                            _StatusFilterRow(prov: prov),
                            Expanded(
                              child: prov.filteredTables.isEmpty
                                  ? const _EmptyState()
                                  : _TableGrid(prov: prov),
                            ),
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

  void _openAddTable(BuildContext ctx, TablesProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditTableSheet(provider: prov),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final TablesProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Icon in terracotta
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
                  '${prov.totalTables} tables · ${prov.totalAvailable} available now',
                  style: const TextStyle(fontSize: 12, color: TC.textSec),
                ),
              ],
            ),
          ),
          // Reservation queue badge
          if (prov.totalReserved > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: TC.reservedBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TC.reserved.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    '${prov.totalReserved} reserved',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TC.reserved,
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
//  VIEW TOGGLE  (Tables Grid ↔ Calendar)
// ═════════════════════════════════════════════════════════════════════════════
class _ViewToggle extends StatelessWidget {
  final bool isCalendar;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.isCalendar, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TC.border),
        ),
        child: Row(
          children: [
            _ToggleTab(
              label: 'Floor View',
              icon: Icons.grid_view_rounded,
              selected: !isCalendar,
              onTap: () => onChanged(false),
            ),
            _ToggleTab(
              label: 'Calendar',
              icon: Icons.calendar_month_rounded,
              selected: isCalendar,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? TC.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? TC.accent : TC.textMute),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? TC.accent : TC.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CALENDAR VIEW  — month grid + reservations for selected date
// ═════════════════════════════════════════════════════════════════════════════
class _CalendarView extends StatefulWidget {
  final TablesProvider prov;
  const _CalendarView({Key? key, required this.prov}) : super(key: key);

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _displayMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // All reservation dates → quick lookup
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
    }).toList()..sort(
      (a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor),
    );
  }

  void _prevMonth() => setState(() {
    _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
  });

  @override
  Widget build(BuildContext context) {
    final reservedDates = _reservedDates;
    final todayRes = _reservationsOnSelected;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        const SizedBox(height: 12),
        // ── Calendar card ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: TC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TC.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Month nav
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                  child: Row(
                    children: [
                      // Month + year
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _monthName(_displayMonth.month),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '${_displayMonth.year}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TC.textMute,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reservation count badge
                      if (reservedDates.any(
                        (d) =>
                            d.month == _displayMonth.month &&
                            d.year == _displayMonth.year,
                      ))
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: TC.reservedBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: TC.reserved.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('📅', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                '${reservedDates.where((d) => d.month == _displayMonth.month && d.year == _displayMonth.year).length} this month',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: TC.reserved,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Prev / Next arrows
                      _NavArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _prevMonth,
                      ),
                      const SizedBox(width: 4),
                      _NavArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // Day labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
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

                // Date grid
                _buildMonthGrid(reservedDates, todayDate),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Selected date header ──────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Date label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate == todayDate
                        ? 'Today'
                        : _selectedDate ==
                              todayDate.add(const Duration(days: 1))
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
              // Quick-add reservation button
              GestureDetector(
                onTap: () => _openAddReservation(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: TC.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: TC.accent.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Reserve',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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

        const SizedBox(height: 10),

        // ── Reservation list ──────────────────────────────
        Expanded(
          child: todayRes.isEmpty
              ? _CalendarEmptyDay(date: _selectedDate, todayDate: todayDate)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: todayRes.length,
                  itemBuilder: (ctx, i) => _ReservationTimelineCard(
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
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

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
          final isSelected = date == _selectedDate;
          final hasRes = reservedDates.contains(date);
          final isPast = date.isBefore(todayDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? TC.accent
                    : isToday
                    ? TC.accentLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: isToday && !isSelected
                    ? Border.all(color: TC.accent, width: 1.5)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isPast
                          ? TC.textMute
                          : TC.textPri,
                    ),
                  ),
                  // Reservation dot
                  if (hasRes && !isSelected)
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
                  if (hasRes && isSelected)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white54,
                          shape: BoxShape.circle,
                        ),
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
    // Find first available table to pre-select, or let user pick
    final availTables = widget.prov.allTables
        .where((t) => t.status == TableStatus.available)
        .toList();
    if (availTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available tables to reserve'),
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
        value: widget.prov,
        child: _CalendarReserveSheet(
          provider: widget.prov,
          availableTables: availTables,
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
        child: _TableDetailSheet(table: table),
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

// ─────────────────────────────────────────────────────────────────────────────
//  NAV ARROW
// ─────────────────────────────────────────────────────────────────────────────
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TC.border),
        ),
        child: Icon(icon, color: TC.textSec, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESERVATION TIMELINE CARD  (in calendar view)
// ─────────────────────────────────────────────────────────────────────────────
class _ReservationTimelineCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;

  const _ReservationTimelineCard({
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final res = table.reservation!;
    final sectionColor = _sectionColor(table.section);
    final sectionBg = _sectionBg(table.section);

    // Time indicator
    final now = DateTime.now();
    final diff = res.reservedFor.difference(now);
    final isOverdue = diff.isNegative;
    final isSoon = !isOverdue && diff.inMinutes <= 30;
    final timeColor = isOverdue
        ? TC.occupied
        : isSoon
        ? const Color(0xFFB8730A)
        : TC.reserved;
    final timeBg = isOverdue
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
            color: isSoon ? timeColor.withOpacity(0.4) : TC.border,
            width: isSoon ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Time column
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: timeBg,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: timeColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: TC.textPri,
                              ),
                            ),
                          ),
                          // Table + section chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sectionBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sectionColor.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              '${table.section.emoji} ${table.tableName}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: sectionColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _ResBadge(
                            icon: Icons.people_outline,
                            text: '${res.guestCount} guests',
                          ),
                          const SizedBox(width: 8),
                          if (res.phone != null)
                            _ResBadge(
                              icon: Icons.phone_outlined,
                              text: res.phone!,
                            ),
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action dots
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Seat now
                    GestureDetector(
                      onTap: () {
                        prov.seatGuests(table.id, res.customerName);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TC.availableBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: TC.available,
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Cancel
                    GestureDetector(
                      onTap: () {
                        prov.cancelReservation(table.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TC.occupiedBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: TC.occupied,
                          size: 15,
                        ),
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

class _ResBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ResBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: TC.textMute),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: TC.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CALENDAR EMPTY DAY
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarEmptyDay extends StatelessWidget {
  final DateTime date;
  final DateTime todayDate;
  const _CalendarEmptyDay({required this.date, required this.todayDate});

  @override
  Widget build(BuildContext context) {
    final isPast = date.isBefore(todayDate);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPast ? TC.surfaceWarm : TC.accentLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              isPast ? '📋' : '✨',
              style: const TextStyle(fontSize: 36),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isPast ? 'No records for this day' : 'No reservations yet',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TC.textPri,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isPast ? 'This date has passed' : 'Tap + Reserve to add a booking',
            style: const TextStyle(fontSize: 12, color: TC.textSec),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CALENDAR QUICK-RESERVE SHEET  (pick table + fill details)
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarReserveSheet extends StatefulWidget {
  final TablesProvider provider;
  final List<RestaurantTable> availableTables;
  final DateTime initialDate;

  const _CalendarReserveSheet({
    required this.provider,
    required this.availableTables,
    required this.initialDate,
  });

  @override
  State<_CalendarReserveSheet> createState() => _CalendarReserveSheetState();
}

class _CalendarReserveSheetState extends State<_CalendarReserveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _tableId;
  int _guestCount = 2;
  late DateTime _reservedFor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tableId = widget.availableTables.first.id;
    final d = widget.initialDate;
    _reservedFor = DateTime(d.year, d.month, d.day, DateTime.now().hour + 1, 0);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reservedFor),
    );
    if (t != null) {
      setState(() {
        _reservedFor = DateTime(
          _reservedFor.year,
          _reservedFor.month,
          _reservedFor.day,
          t.hour,
          t.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final res = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _reservedFor,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.provider.addReservation(_tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: '📅',
              title: 'Quick Reserve',
              subtitle: 'Add a reservation for this date',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table picker
                    const Text(
                      'Select Table',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.availableTables.length,
                        itemBuilder: (_, i) {
                          final t = widget.availableTables[i];
                          final isSel = _tableId == t.id;
                          final secCol = _sectionColor(t.section);
                          final secBg = _sectionBg(t.section);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _tableId = t.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel ? secBg : TC.surfaceWarm,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? secCol : TC.border,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      t.section.emoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t.tableName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSel ? secCol : TC.textSec,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '· ${t.capacity}p',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSel
                                            ? secCol.withOpacity(0.7)
                                            : TC.textMute,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Guest name
                    _FormField(
                      label: 'Guest Name *',
                      hint: 'Full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Phone + time in a row
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label: 'Phone',
                            hint: '+91 98765...',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: TC.textSec,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: TC.surfaceWarm,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: TC.border),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '🕐',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      () {
                                        final h = _reservedFor.hour;
                                        final m = _reservedFor.minute
                                            .toString()
                                            .padLeft(2, '0');
                                        final s = h >= 12 ? 'PM' : 'AM';
                                        final h12 = h > 12
                                            ? h - 12
                                            : (h == 0 ? 12 : h);
                                        return '$h12:$m $s';
                                      }(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: TC.textPri,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Party size
                    const Text(
                      'Party Size',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(8, (i) {
                        final n = i + 1;
                        final isSel = _guestCount == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _guestCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    _FormField(
                      label: 'Notes',
                      hint: 'Special requests...',
                      controller: _noteCtrl,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Reservation',
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
//  SUMMARY BAR  (horizontal scroll metrics)
// ═════════════════════════════════════════════════════════════════════════════
class _SummaryBar extends StatelessWidget {
  final TablesProvider prov;
  const _SummaryBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        children: [
          _MetricPill(
            emoji: '✅',
            label: 'Available',
            value: '${prov.totalAvailable}',
            color: TC.available,
          ),
          _MetricPill(
            emoji: '🍽️',
            label: 'Occupied',
            value: '${prov.totalOccupied}',
            color: TC.occupied,
          ),
          _MetricPill(
            emoji: '📅',
            label: 'Reserved',
            value: '${prov.totalReserved}',
            color: TC.reserved,
          ),
          _MetricPill(
            emoji: '🧹',
            label: 'Cleaning',
            value:
                '${prov.allTables.where((t) => t.status == TableStatus.cleaning).length}',
            color: TC.cleaning,
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _MetricPill({
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

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION TABS (AC / Non-AC / Rooftop / Garden / Private)
// ═════════════════════════════════════════════════════════════════════════════
class _SectionTabs extends StatelessWidget {
  final TablesProvider prov;
  const _SectionTabs({required this.prov});

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
          final color = s == null ? TC.accent : _sectionColor(s);
          final bg = s == null ? TC.accentLight : _sectionBg(s);

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

// ═════════════════════════════════════════════════════════════════════════════
//  STATUS FILTER ROW
// ═════════════════════════════════════════════════════════════════════════════
class _StatusFilterRow extends StatelessWidget {
  final TablesProvider prov;
  const _StatusFilterRow({required this.prov});

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
          final color = s == null ? TC.textSec : _statusColor(s);
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
                      ? (s == null ? TC.textPri : _statusBg(s))
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

// ═════════════════════════════════════════════════════════════════════════════
//  TABLE GRID
// ═════════════════════════════════════════════════════════════════════════════
class _TableGrid extends StatelessWidget {
  final TablesProvider prov;
  const _TableGrid({required this.prov});

  @override
  Widget build(BuildContext context) {
    // Group by section
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
        return _SectionGroup(section: sec, tables: tables, prov: prov);
      }).toList(),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final TableSection section;
  final List<RestaurantTable> tables;
  final TablesProvider prov;
  const _SectionGroup({
    required this.section,
    required this.tables,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final color = _sectionColor(section);
    final bg = _sectionBg(section);
    final avail = tables.where((t) => t.status == TableStatus.available).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
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
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: tables.length,
          itemBuilder: (ctx, i) => _TableCard(
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
        child: _TableDetailSheet(table: table),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TABLE CARD
// ═════════════════════════════════════════════════════════════════════════════
class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;

  const _TableCard({
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(table.status);
    final sb = _statusBg(table.status);
    final secCol = _sectionColor(table.section);
    final isActive = table.status == TableStatus.occupied;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? sc.withOpacity(0.3) : TC.border,
            width: isActive ? 1.5 : 1,
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
            // Premium star
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
            // Window badge
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

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table icon shape
                  _TableIcon(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),

                  const Spacer(),

                  // Table number + capacity
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
                      // Status badge
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

                  // Bottom info
                  if (table.status == TableStatus.occupied) ...[
                    _CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.currentCustomerName ?? '—',
                    ),
                    const SizedBox(height: 3),
                    _CardInfoRow(
                      icon: Icons.schedule_outlined,
                      text: table.occupiedDuration,
                      color: TC.occupied,
                    ),
                  ] else if (table.status == TableStatus.reserved) ...[
                    _CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.reservation?.customerName ?? '—',
                    ),
                    const SizedBox(height: 3),
                    _CardInfoRow(
                      icon: Icons.access_time_outlined,
                      text: table.reservation?.countdownLabel ?? '',
                      color: TC.reserved,
                    ),
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
                    _CardInfoRow(
                      icon: Icons.cleaning_services_outlined,
                      text: 'Being cleaned',
                      color: TC.cleaning,
                    ),
                  ],
                ],
              ),
            ),

            // Section color strip on left edge
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

class _CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _CardInfoRow({
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

// ── Table shape icon ───────────────────────────────────────────
class _TableIcon extends StatelessWidget {
  final TableShape shape;
  final int capacity;
  final Color color;
  final Color bg;
  final String tableName;

  const _TableIcon({
    required this.shape,
    required this.capacity,
    required this.color,
    required this.bg,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final w = shape == TableShape.rectangle ? 52.0 : 44.0;
    final h = 44.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape == TableShape.round
            ? BorderRadius.circular(h / 2)
            : shape == TableShape.rectangle
            ? BorderRadius.circular(8)
            : BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        tableName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TABLE DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _TableDetailSheet extends StatelessWidget {
  final RestaurantTable table;
  const _TableDetailSheet({required this.table});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<TablesProvider>();
    final sc = _statusColor(table.status);
    final sb = _statusBg(table.status);
    final secCol = _sectionColor(table.section);
    final secBg = _sectionBg(table.section);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Sheet header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  _TableIcon(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Table ${table.tableNumber}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (table.isPremium)
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: secBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${table.section.emoji} ${table.section.label}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: secCol,
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
                                color: sb,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                table.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sc,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Edit table button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: prov,
                          child: _AddEditTableSheet(
                            provider: prov,
                            editTable: table,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: TC.surfaceWarm,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: TC.border),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: TC.textSec,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: TC.divider),

            // Content
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Info row
                  Row(
                    children: [
                      _InfoTile(
                        label: 'Capacity',
                        value: '${table.capacity} seats',
                        emoji: '👥',
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        label: 'Floor',
                        value: table.section.floor,
                        emoji: '🏢',
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        label: 'Shape',
                        value: table.shape.name.capitalize(),
                        emoji: '⬜',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status-specific content
                  if (table.status == TableStatus.occupied)
                    _OccupiedSection(table: table, prov: prov)
                  else if (table.status == TableStatus.reserved)
                    _ReservationSection(table: table, prov: prov)
                  else if (table.status == TableStatus.available)
                    _AvailableSection(table: table, prov: prov)
                  else
                    _CleaningSection(table: table, prov: prov),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS SECTIONS in detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _OccupiedSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _OccupiedSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetSection('Current Occupancy'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: '👤',
                label: 'Customer',
                value: table.currentCustomerName ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '🧾',
                label: 'Order',
                value: table.currentOrderId ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '💰',
                label: 'Bill so far',
                value: table.currentOrderTotal != null
                    ? '₹${table.currentOrderTotal!.toInt()}'
                    : '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '⏱️',
                label: 'Occupied for',
                value: table.occupiedDuration,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Clear Table',
                emoji: '🧹',
                color: TC.cleaning,
                onTap: () {
                  prov.clearTable(table.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _ReservationSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    final res = table.reservation!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetSection('Reservation Details'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.reservedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.reserved.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _DetailRow(icon: '👤', label: 'Guest', value: res.customerName),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(icon: '📱', label: 'Phone', value: res.phone ?? '—'),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '👥',
                label: 'Party size',
                value: '${res.guestCount} guests',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '📅',
                label: 'Scheduled',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '⏰',
                label: 'Arrives',
                value: res.countdownLabel,
              ),
              if (res.notes != null && res.notes!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                _DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Cancel Reservation',
                emoji: '✖️',
                color: const Color(0xFFDC2626),
                outlined: true,
                onTap: () => _confirmCancel(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Seat Guests',
                emoji: '🍽️',
                color: TC.available,
                onTap: () {
                  prov.seatGuests(table.id, res.customerName);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _ActionBtn(
            label: 'Edit Reservation',
            emoji: '✏️',
            color: TC.accent,
            outlined: true,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(
                  value: prov,
                  child: _ReservationSheet(
                    tableId: table.id,
                    provider: prov,
                    existing: res,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Reservation?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: Text(
          'The reservation for ${table.reservation?.customerName} will be removed.',
          style: const TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.cancelReservation(table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _AvailableSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.available.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table is Ready',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.available,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Walk-in guests can be seated now',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Reserve Table',
                emoji: '📅',
                color: TC.reserved,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: prov,
                      child: _ReservationSheet(
                        tableId: table.id,
                        provider: prov,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Seat Walk-in',
                emoji: '🚶',
                color: TC.accent,
                onTap: () {
                  prov.seatGuests(table.id, 'Walk-in Guest');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CleaningSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _CleaningSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.cleaningBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.cleaning.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Text('🧹', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Being Cleaned',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.cleaning,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Table will be available shortly',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _ActionBtn(
            label: 'Mark as Available',
            emoji: '✅',
            color: TC.available,
            onTap: () {
              prov.markAvailable(table.id);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESERVATION SHEET  (add / edit)
// ─────────────────────────────────────────────────────────────────────────────
class _ReservationSheet extends StatefulWidget {
  final String tableId;
  final TablesProvider provider;
  final Reservation? existing;

  const _ReservationSheet({
    required this.tableId,
    required this.provider,
    this.existing,
  });

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;
  late int _guestCount;
  late DateTime _reservedFor;
  bool _isLoading = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _guestCount = e?.guestCount ?? 2;
    _reservedFor =
        e?.reservedFor ??
        DateTime.now()
            .add(const Duration(hours: 1))
            .copyWith(second: 0, microsecond: 0, millisecond: 0);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reservedFor),
    );
    if (time != null) {
      setState(() {
        _reservedFor = DateTime(
          _reservedFor.year,
          _reservedFor.month,
          _reservedFor.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reservedFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null) {
      setState(() {
        _reservedFor = DateTime(
          date.year,
          date.month,
          date.day,
          _reservedFor.hour,
          _reservedFor.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final res = Reservation(
      id: widget.existing?.id ?? 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _reservedFor,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    if (isEdit) {
      await widget.provider.updateReservation(widget.tableId, res);
    } else {
      await widget.provider.addReservation(widget.tableId, res);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: '📅',
              title: isEdit ? 'Edit Reservation' : 'New Reservation',
              subtitle: isEdit
                  ? 'Update details below'
                  : 'Reserve this table for a guest',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Guest name
                    _FormField(
                      label: 'Guest Name *',
                      hint: 'Enter full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    // Phone
                    _FormField(
                      label: 'Phone Number',
                      hint: '+91 98765 43210',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    // Party size
                    const Text(
                      'Party Size',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(8, (i) {
                        final n = i + 1;
                        final isSel = _guestCount == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _guestCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Date + Time
                    const Text(
                      'Date & Time *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TC.border),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '📅',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    () {
                                      final now = DateTime.now();
                                      final today = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );
                                      final rDate = DateTime(
                                        _reservedFor.year,
                                        _reservedFor.month,
                                        _reservedFor.day,
                                      );
                                      if (rDate == today) return 'Today';
                                      if (rDate ==
                                          today.add(const Duration(days: 1)))
                                        return 'Tomorrow';
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
                                      return '${m[_reservedFor.month - 1]} ${_reservedFor.day}';
                                    }(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: TC.textPri,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TC.border),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🕐',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    () {
                                      final h = _reservedFor.hour;
                                      final m = _reservedFor.minute
                                          .toString()
                                          .padLeft(2, '0');
                                      final suffix = h >= 12 ? 'PM' : 'AM';
                                      final h12 = h > 12
                                          ? h - 12
                                          : (h == 0 ? 12 : h);
                                      return '$h12:$m $suffix';
                                    }(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: TC.textPri,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Notes
                    _FormField(
                      label: 'Special Notes',
                      hint: 'Birthday, anniversary, dietary needs...',
                      controller: _notesCtrl,
                    ),
                    const SizedBox(height: 22),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEdit
                                    ? 'Update Reservation'
                                    : 'Confirm Reservation',
                                style: const TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
//  ADD / EDIT TABLE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddEditTableSheet extends StatefulWidget {
  final TablesProvider provider;
  final RestaurantTable? editTable;
  const _AddEditTableSheet({required this.provider, this.editTable});

  @override
  State<_AddEditTableSheet> createState() => _AddEditTableSheetState();
}

class _AddEditTableSheetState extends State<_AddEditTableSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _capacity;
  late TableSection _section;
  late TableShape _shape;
  late bool _hasWindow;
  late bool _isPremium;
  bool _isLoading = false;

  bool get isEdit => widget.editTable != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editTable;
    _capacity = e?.capacity ?? 4;
    _section = e?.section ?? TableSection.ac;
    _shape = e?.shape ?? TableShape.square;
    _hasWindow = e?.hasWindow ?? false;
    _isPremium = e?.isPremium ?? false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final table = RestaurantTable(
      id: widget.editTable?.id ?? widget.provider.generateId(),
      tableNumber:
          widget.editTable?.tableNumber ?? widget.provider.nextTableNumber(),
      capacity: _capacity,
      status: widget.editTable?.status ?? TableStatus.available,
      section: _section,
      shape: _shape,
      hasWindow: _hasWindow,
      isPremium: _isPremium,
      currentCustomerName: widget.editTable?.currentCustomerName,
      currentOrderId: widget.editTable?.currentOrderId,
      currentOrderTotal: widget.editTable?.currentOrderTotal,
      occupiedSince: widget.editTable?.occupiedSince,
      reservation: widget.editTable?.reservation,
    );
    isEdit
        ? await widget.provider.updateTable(table)
        : await widget.provider.addTable(table);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: isEdit ? '✏️' : '➕',
              title: isEdit ? 'Edit Table' : 'Add New Table',
              subtitle: isEdit
                  ? 'Update table configuration'
                  : 'Configure the new table',
              color: TC.accent,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section
                    const Text(
                      'Section',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TableSection.values.map((s) {
                        final isSel = _section == s;
                        final col = _sectionColor(s);
                        final bg = _sectionBg(s);
                        return GestureDetector(
                          onTap: () => setState(() => _section = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? bg : TC.surfaceWarm,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? col : TC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? col : TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Capacity
                    const Text(
                      'Seating Capacity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [2, 4, 6, 8, 10, 12].map((n) {
                        final isSel = _capacity == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _capacity = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.accent : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Shape
                    const Text(
                      'Table Shape',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: TableShape.values.map((s) {
                        final isSel = _shape == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _shape = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSel ? TC.accentLight : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                s.name.capitalize(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? TC.accent : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Toggle switches
                    _ToggleRow(
                      label: 'Window View',
                      subtitle: 'Table has a window or scenic view',
                      emoji: '🪟',
                      value: _hasWindow,
                      onChanged: (v) => setState(() => _hasWindow = v),
                    ),
                    const Divider(height: 1, color: TC.divider),
                    _ToggleRow(
                      label: 'Premium Table',
                      subtitle: 'Marks this as a premium / special table',
                      emoji: '⭐',
                      value: _isPremium,
                      onChanged: (v) => setState(() => _isPremium = v),
                    ),

                    const SizedBox(height: 22),

                    // Submit
                    Row(
                      children: [
                        if (isEdit) ...[
                          _OutlineBtn(
                            label: 'Delete',
                            color: const Color(0xFFDC2626),
                            onTap: () => _confirmDelete(context),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TC.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isEdit ? 'Save Changes' : 'Add Table',
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
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${widget.editTable!.tableName}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: TC.textPri,
          ),
        ),
        content: const Text(
          'This will permanently remove the table.',
          style: TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteTable(widget.editTable!.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
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
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  const _InfoTile({
    required this.label,
    required this.value,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: TC.textPri,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: TC.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: TC.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TC.textPri,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionBtn({
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
          color: outlined ? Colors.transparent : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: outlined ? color : color.withOpacity(0.3),
            width: outlined ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String text;
  const _SheetSection(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: TC.textMute,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: TC.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _SheetTopBar({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: TC.divider),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TC.textPri,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: TC.textMute, fontSize: 13),
            filled: true,
            fillColor: TC.surfaceWarm,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String emoji;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TC.textPri,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: TC.textMute),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: TC.accent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDDDDE8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TC.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Text('🪑', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No tables found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TC.textPri,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different filter or add a new table',
            style: TextStyle(fontSize: 13, color: TC.textSec),
          ),
        ],
      ),
    );
  }
}

class _AddTableFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTableFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: TC.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: TC.accent.withOpacity(0.38),
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
              'Add Table',
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  STRING EXTENSION
// ═════════════════════════════════════════════════════════════════════════════
extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:pos_app/models/table_modal.dart';
// import 'package:pos_app/providers/tables_provider.dart';
// import 'package:provider/provider.dart';

// // ═══════════════════════════════════════════════════════════════
// //  DESIGN TOKENS  — Warm amber restaurant aesthetic
// // ═══════════════════════════════════════════════════════════════
// class TC {
//   // Background — deep warm charcoal
//   static const bg = Color(0xFF1C1A17);
//   static const bgSurface = Color(0xFF252219);
//   static const bgCard = Color(0xFF2E2A22);
//   static const bgLight = Color(0xFFF5F0E8);

//   // Accent — warm amber gold
//   static const amber = Color(0xFFD4943A);
//   static const amberLight = Color(0xFFF5C26B);
//   static const amberDark = Color(0xFF9E6B22);
//   static const amberBg = Color(0xFF3A2E1A);

//   // Status palette
//   static const available = Color(0xFF3DC47E);
//   static const availableBg = Color(0xFF1A2E22);
//   static const occupied = Color(0xFFE05252);
//   static const occupiedBg = Color(0xFF2E1A1A);
//   static const reserved = Color(0xFFD4943A);
//   static const reservedBg = Color(0xFF2E2410);
//   static const cleaning = Color(0xFF5B9BD4);
//   static const cleaningBg = Color(0xFF162130);

//   // Zone colors
//   static const acColor = Color(0xFF5BB8D4);
//   static const acBg = Color(0xFF152028);
//   static const nonAcColor = Color(0xFF72C785);
//   static const nonAcBg = Color(0xFF142018);

//   // Text
//   static const textPri = Color(0xFFF0EBE0);
//   static const textSec = Color(0xFF9A9080);
//   static const textMute = Color(0xFF5A5448);
//   static const divider = Color(0xFF332E26);

//   // Sheet (light)
//   static const sheetBg = Color(0xFFFAF8F3);
//   static const sheetCard = Color(0xFFFFFFFF);
//   static const sheetBorder = Color(0xFFEBE6DC);
//   static const sheetMute = Color(0xFF9E9888);
//   static const sheetText = Color(0xFF2A2520);
// }

// Color _statusColor(TableStatus s) {
//   switch (s) {
//     case TableStatus.available:
//       return TC.available;
//     case TableStatus.occupied:
//       return TC.occupied;
//     case TableStatus.reserved:
//       return TC.reserved;
//     case TableStatus.cleaning:
//       return TC.cleaning;
//   }
// }

// Color _statusBg(TableStatus s) {
//   switch (s) {
//     case TableStatus.available:
//       return TC.availableBg;
//     case TableStatus.occupied:
//       return TC.occupiedBg;
//     case TableStatus.reserved:
//       return TC.reservedBg;
//     case TableStatus.cleaning:
//       return TC.cleaningBg;
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ENTRY POINT
// // ═════════════════════════════════════════════════════════════════════════════
// class TablesScreen extends StatelessWidget {
//   const TablesScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => TablesProvider(),
//       child: const _TablesRoot(),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ROOT
// // ═════════════════════════════════════════════════════════════════════════════
// class _TablesRoot extends StatelessWidget {
//   const _TablesRoot();

//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
//     return Consumer<TablesProvider>(
//       builder: (context, prov, _) {
//         return Scaffold(
//           backgroundColor: TC.bg,
//           floatingActionButton: _AddTableFAB(
//             onTap: () => _openAddEdit(context, prov, null),
//           ),
//           body: SafeArea(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _Header(provider: prov),
//                 _FloorSelector(provider: prov),
//                 _ZoneStatusBar(provider: prov),
//                 _StatsRow(provider: prov),
//                 Expanded(
//                   child: prov.filteredTables.isEmpty
//                       ? const _EmptyFloor()
//                       : _TableGrid(
//                           tables: prov.filteredTables,
//                           onTap: (t) => _openDetail(context, t, prov),
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _openDetail(BuildContext ctx, RestaurantTable t, TablesProvider prov) {
//     showModalBottomSheet(
//       context: ctx,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => ChangeNotifierProvider.value(
//         value: prov,
//         child: _TableDetailSheet(table: t),
//       ),
//     );
//   }

//   void _openAddEdit(
//     BuildContext ctx,
//     TablesProvider prov,
//     RestaurantTable? edit,
//   ) {
//     showModalBottomSheet(
//       context: ctx,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => ChangeNotifierProvider.value(
//         value: prov,
//         child: _AddEditTableSheet(editTable: edit),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  HEADER
// // ═════════════════════════════════════════════════════════════════════════════
// class _Header extends StatelessWidget {
//   final TablesProvider provider;
//   const _Header({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
//       child: Row(
//         children: [
//           // Branded icon
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [TC.amber, TC.amberDark],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(
//               Icons.table_restaurant,
//               color: Colors.white,
//               size: 22,
//             ),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Tables',
//                   style: TextStyle(
//                     fontSize: 26,
//                     fontWeight: FontWeight.w900,
//                     color: TC.textPri,
//                     letterSpacing: -0.8,
//                   ),
//                 ),
//                 Text(
//                   '${provider.totalOnFloor} tables · ${provider.floors.length} floors',
//                   style: const TextStyle(fontSize: 12, color: TC.textSec),
//                 ),
//               ],
//             ),
//           ),
//           // Reservations bell
//           _ReservationsBell(provider: provider),
//         ],
//       ),
//     );
//   }
// }

// class _ReservationsBell extends StatelessWidget {
//   final TablesProvider provider;
//   const _ReservationsBell({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     final count = provider.upcomingReservations.length;
//     return GestureDetector(
//       onTap: () => _showAllReservations(context, provider),
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: TC.bgCard,
//               borderRadius: BorderRadius.circular(13),
//               border: Border.all(color: TC.divider),
//             ),
//             child: const Icon(
//               Icons.calendar_month_outlined,
//               color: TC.textSec,
//               size: 22,
//             ),
//           ),
//           if (count > 0)
//             Positioned(
//               top: -4,
//               right: -4,
//               child: Container(
//                 width: 18,
//                 height: 18,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: TC.reserved,
//                   shape: BoxShape.circle,
//                   border: Border.all(color: TC.bg, width: 2),
//                 ),
//                 child: Text(
//                   '$count',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   void _showAllReservations(BuildContext ctx, TablesProvider prov) {
//     showModalBottomSheet(
//       context: ctx,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _AllReservationsSheet(provider: prov),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  FLOOR SELECTOR  — pill-style horizontal scroller
// // ═════════════════════════════════════════════════════════════════════════════
// class _FloorSelector extends StatelessWidget {
//   final TablesProvider provider;
//   const _FloorSelector({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 48,
//       child: ListView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
//         children: provider.floors.map((floor) {
//           final isSel = provider.selectedFloor == floor;
//           final label = floor == 0 ? 'Ground Floor' : 'Floor $floor';

//           return Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: GestureDetector(
//               onTap: () => provider.setFloor(floor),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 18,
//                   vertical: 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isSel ? TC.amber : TC.bgCard,
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(
//                     color: isSel ? TC.amber : TC.divider,
//                     width: isSel ? 0 : 1,
//                   ),
//                   boxShadow: isSel
//                       ? [
//                           BoxShadow(
//                             color: TC.amber.withOpacity(0.35),
//                             blurRadius: 12,
//                             offset: const Offset(0, 4),
//                           ),
//                         ]
//                       : [],
//                 ),
//                 child: Row(
//                   children: [
//                     Text(
//                       floor == 0 ? '🏢' : '🔼',
//                       style: const TextStyle(fontSize: 13),
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       label,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w700,
//                         color: isSel ? Colors.white : TC.textSec,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ZONE + STATUS BAR
// // ═════════════════════════════════════════════════════════════════════════════
// class _ZoneStatusBar extends StatelessWidget {
//   final TablesProvider provider;
//   const _ZoneStatusBar({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
//       child: Row(
//         children: [
//           // Zone toggles
//           _ZoneChip(
//             label: '❄️ AC',
//             color: TC.acColor,
//             selected: provider.selectedZone == TableZone.ac,
//             onTap: () => provider.setZone(TableZone.ac),
//           ),
//           const SizedBox(width: 8),
//           _ZoneChip(
//             label: '🌿 Non-AC',
//             color: TC.nonAcColor,
//             selected: provider.selectedZone == TableZone.nonAc,
//             onTap: () => provider.setZone(TableZone.nonAc),
//           ),
//           const Spacer(),
//           // Status filter dots
//           ...TableStatus.values.map(
//             (s) => Padding(
//               padding: const EdgeInsets.only(left: 8),
//               child: GestureDetector(
//                 onTap: () => provider.setStatus(s),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 150),
//                   width: 10,
//                   height: 10,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: _statusColor(s),
//                     boxShadow: provider.selectedStatus == s
//                         ? [
//                             BoxShadow(
//                               color: _statusColor(s).withOpacity(0.6),
//                               blurRadius: 6,
//                             ),
//                           ]
//                         : [],
//                     border: provider.selectedStatus == s
//                         ? Border.all(color: Colors.white, width: 2)
//                         : null,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ZoneChip extends StatelessWidget {
//   final String label;
//   final Color color;
//   final bool selected;
//   final VoidCallback onTap;

//   const _ZoneChip({
//     required this.label,
//     required this.color,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 160),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: selected ? color.withOpacity(0.18) : TC.bgCard,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//             color: selected ? color : TC.divider,
//             width: selected ? 1.5 : 1,
//           ),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w700,
//             color: selected ? color : TC.textSec,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  STATS ROW
// // ═════════════════════════════════════════════════════════════════════════════
// class _StatsRow extends StatelessWidget {
//   final TablesProvider provider;
//   const _StatsRow({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//       child: Row(
//         children: [
//           _StatChip(
//             count: provider.availableCount,
//             label: 'Free',
//             color: TC.available,
//           ),
//           const SizedBox(width: 8),
//           _StatChip(
//             count: provider.occupiedCount,
//             label: 'Occupied',
//             color: TC.occupied,
//           ),
//           const SizedBox(width: 8),
//           _StatChip(
//             count: provider.reservedCount,
//             label: 'Reserved',
//             color: TC.reserved,
//           ),
//           const SizedBox(width: 8),
//           _StatChip(
//             count: provider.cleaningCount,
//             label: 'Cleaning',
//             color: TC.cleaning,
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StatChip extends StatelessWidget {
//   final int count;
//   final String label;
//   final Color color;
//   const _StatChip({
//     required this.count,
//     required this.label,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.10),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.22)),
//         ),
//         child: Column(
//           children: [
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w900,
//                 color: color,
//               ),
//             ),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 9,
//                 color: TC.textSec,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  TABLE GRID
// // ═════════════════════════════════════════════════════════════════════════════
// class _TableGrid extends StatelessWidget {
//   final List<RestaurantTable> tables;
//   final ValueChanged<RestaurantTable> onTap;

//   const _TableGrid({required this.tables, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GridView.builder(
//       padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3,
//         crossAxisSpacing: 10,
//         mainAxisSpacing: 10,
//         childAspectRatio: 0.82,
//       ),
//       itemCount: tables.length,
//       itemBuilder: (_, i) => _TableCard(table: tables[i], onTap: onTap),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  TABLE CARD
// // ═════════════════════════════════════════════════════════════════════════════
// class _TableCard extends StatelessWidget {
//   final RestaurantTable table;
//   final ValueChanged<RestaurantTable> onTap;

//   const _TableCard({required this.table, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     final sColor = _statusColor(table.status);
//     final sBg = _statusBg(table.status);
//     final zColor = table.zone == TableZone.ac ? TC.acColor : TC.nonAcColor;

//     return GestureDetector(
//       onTap: () => onTap(table),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         decoration: BoxDecoration(
//           color: TC.bgCard,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(
//             color: table.status == TableStatus.available
//                 ? TC.divider
//                 : sColor.withOpacity(0.45),
//             width: table.status == TableStatus.available ? 1 : 1.5,
//           ),
//           boxShadow: table.status != TableStatus.available
//               ? [
//                   BoxShadow(
//                     color: sColor.withOpacity(0.15),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ]
//               : [],
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── Top row: number + zone badge ────────────
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     '${table.number}',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w900,
//                       color: TC.textPri,
//                       letterSpacing: -0.5,
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 6,
//                       vertical: 3,
//                     ),
//                     decoration: BoxDecoration(
//                       color: zColor.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       table.zone.emoji,
//                       style: const TextStyle(fontSize: 10),
//                     ),
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 6),

//               // ── Table shape visual ───────────────────────
//               Expanded(
//                 child: Center(
//                   child: _TableShape(
//                     shape: table.shape,
//                     capacity: table.capacity,
//                     color: sColor,
//                     isActive: table.status != TableStatus.available,
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 6),

//               // ── Status badge ─────────────────────────────
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: sBg,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Container(
//                       width: 5,
//                       height: 5,
//                       decoration: BoxDecoration(
//                         color: sColor,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 4),
//                     Flexible(
//                       child: Text(
//                         table.status == TableStatus.occupied
//                             ? table.occupiedDuration
//                             : table.status == TableStatus.reserved
//                             ? table.reservation?.timeLabel ?? 'Reserved'
//                             : table.status.label,
//                         style: TextStyle(
//                           fontSize: 9,
//                           fontWeight: FontWeight.w700,
//                           color: sColor,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 4),

//               // ── Capacity ─────────────────────────────────
//               Row(
//                 children: [
//                   const Icon(
//                     Icons.people_outline,
//                     size: 10,
//                     color: TC.textMute,
//                   ),
//                   const SizedBox(width: 3),
//                   Text(
//                     '${table.capacity}',
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: TC.textSec,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   if (table.currentBill != null) ...[
//                     const Spacer(),
//                     Text(
//                       '₹${table.currentBill!.toInt()}',
//                       style: const TextStyle(
//                         fontSize: 9,
//                         fontWeight: FontWeight.w700,
//                         color: TC.amber,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  TABLE SHAPE WIDGET  — visual table icon
// // ─────────────────────────────────────────────────────────────────────────────
// class _TableShape extends StatelessWidget {
//   final TableShape shape;
//   final int capacity;
//   final Color color;
//   final bool isActive;

//   const _TableShape({
//     required this.shape,
//     required this.capacity,
//     required this.color,
//     required this.isActive,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final fill = isActive ? color.withOpacity(0.12) : TC.bgSurface;
//     final border = isActive ? color.withOpacity(0.5) : TC.divider;

//     Widget shapeWidget;
//     switch (shape) {
//       case TableShape.round:
//         shapeWidget = Container(
//           width: 48,
//           height: 48,
//           decoration: BoxDecoration(
//             color: fill,
//             shape: BoxShape.circle,
//             border: Border.all(color: border, width: 1.5),
//           ),
//           alignment: Alignment.center,
//           child: Text('🍽', style: const TextStyle(fontSize: 16)),
//         );
//         break;
//       case TableShape.square:
//         shapeWidget = Container(
//           width: 46,
//           height: 46,
//           decoration: BoxDecoration(
//             color: fill,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: border, width: 1.5),
//           ),
//           alignment: Alignment.center,
//           child: Text('🍽', style: const TextStyle(fontSize: 16)),
//         );
//         break;
//       case TableShape.rectangle:
//         shapeWidget = Container(
//           width: 58,
//           height: 38,
//           decoration: BoxDecoration(
//             color: fill,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: border, width: 1.5),
//           ),
//           alignment: Alignment.center,
//           child: Text('🍽', style: const TextStyle(fontSize: 16)),
//         );
//         break;
//     }
//     return shapeWidget;
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  TABLE DETAIL SHEET
// // ═════════════════════════════════════════════════════════════════════════════
// class _TableDetailSheet extends StatelessWidget {
//   final RestaurantTable table;
//   const _TableDetailSheet({required this.table});

//   @override
//   Widget build(BuildContext context) {
//     final prov = context.read<TablesProvider>();
//     final sColor = _statusColor(table.status);
//     final zColor = table.zone == TableZone.ac ? TC.acColor : TC.nonAcColor;

//     return DraggableScrollableSheet(
//       initialChildSize: 0.75,
//       maxChildSize: 0.95,
//       minChildSize: 0.4,
//       builder: (_, ctrl) => Container(
//         decoration: const BoxDecoration(
//           color: TC.sheetBg,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//         ),
//         child: Column(
//           children: [
//             // Handle
//             _SheetHandle(),
//             // Header
//             Padding(
//               padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
//               child: Row(
//                 children: [
//                   // Table number in amber circle
//                   Container(
//                     width: 54,
//                     height: 54,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [TC.amber, TC.amberDark],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       shape: BoxShape.circle,
//                     ),
//                     alignment: Alignment.center,
//                     child: Text(
//                       '${table.number}',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 22,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Table ${table.number}',
//                           style: const TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.w900,
//                             color: TC.sheetText,
//                             letterSpacing: -0.4,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Wrap(
//                           spacing: 6,
//                           children: [
//                             _InfoPill(
//                               table.zone.emoji + ' ' + table.zone.label,
//                               zColor,
//                             ),
//                             _InfoPill(
//                               '👥 ${table.capacity} seats',
//                               TC.sheetMute,
//                             ),
//                             _InfoPill('🏢 ${table.floorLabel}', TC.sheetMute),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Status badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: sColor.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: sColor.withOpacity(0.35)),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           table.status.emoji,
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                         const SizedBox(width: 5),
//                         Text(
//                           table.status.label,
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: sColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1, color: TC.sheetBorder),

//             Expanded(
//               child: ListView(
//                 controller: ctrl,
//                 padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//                 children: [
//                   // ── If occupied: order info ────────────────
//                   if (table.status == TableStatus.occupied) ...[
//                     _DetailSection(
//                       title: 'Current Session',
//                       child: Column(
//                         children: [
//                           _DetailRow('👤', 'Customer', table.occupiedBy ?? '—'),
//                           _DetailRow('⏱', 'Duration', table.occupiedDuration),
//                           if (table.activeOrderId != null)
//                             _DetailRow('🧾', 'Order ID', table.activeOrderId!),
//                           if (table.currentBill != null)
//                             _DetailRow(
//                               '💰',
//                               'Bill so far',
//                               '₹${table.currentBill!.toInt()}',
//                             ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 14),
//                   ],

//                   // ── If reserved: reservation info ──────────
//                   if (table.status == TableStatus.reserved &&
//                       table.reservation != null) ...[
//                     _DetailSection(
//                       title: 'Reservation Details',
//                       child: Column(
//                         children: [
//                           _DetailRow(
//                             '👤',
//                             'Name',
//                             table.reservation!.customerName,
//                           ),
//                           _DetailRow('📱', 'Phone', table.reservation!.phone),
//                           _DetailRow(
//                             '👥',
//                             'Guests',
//                             '${table.reservation!.guestCount}',
//                           ),
//                           _DetailRow(
//                             '🕐',
//                             'Time',
//                             table.reservation!.formattedTime,
//                           ),
//                           _DetailRow(
//                             '⏰',
//                             'Arrives',
//                             table.reservation!.timeLabel,
//                           ),
//                           if (table.reservation!.note != null)
//                             _DetailRow('📝', 'Note', table.reservation!.note!),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 14),
//                   ],

//                   // ── Actions ────────────────────────────────
//                   _DetailSection(
//                     title: 'Actions',
//                     child: Wrap(
//                       spacing: 10,
//                       runSpacing: 10,
//                       children: _buildActions(context, prov),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   List<Widget> _buildActions(BuildContext ctx, TablesProvider prov) {
//     final actions = <Widget>[];

//     if (table.status == TableStatus.available) {
//       actions.add(
//         _ActionBtn('📅 Reserve', TC.reserved, () {
//           Navigator.pop(ctx);
//           showModalBottomSheet(
//             context: ctx,
//             isScrollControlled: true,
//             backgroundColor: Colors.transparent,
//             builder: (_) => ChangeNotifierProvider.value(
//               value: prov,
//               child: _ReservationSheet(table: table),
//             ),
//           );
//         }),
//       );
//       actions.add(
//         _ActionBtn('🍽 Seat Guest', TC.occupied, () {
//           _seatDialog(ctx, prov);
//         }),
//       );
//     }

//     if (table.status == TableStatus.reserved) {
//       actions.add(
//         _ActionBtn('✏️ Edit Reservation', TC.amber, () {
//           Navigator.pop(ctx);
//           showModalBottomSheet(
//             context: ctx,
//             isScrollControlled: true,
//             backgroundColor: Colors.transparent,
//             builder: (_) => ChangeNotifierProvider.value(
//               value: prov,
//               child: _ReservationSheet(
//                 table: table,
//                 editReservation: table.reservation,
//               ),
//             ),
//           );
//         }),
//       );
//       actions.add(
//         _ActionBtn('🍽 Check In', TC.available, () {
//           prov.markOccupied(
//             table.id,
//             table.reservation?.customerName ?? 'Guest',
//           );
//           Navigator.pop(ctx);
//         }),
//       );
//       actions.add(
//         _ActionBtn('❌ Cancel', TC.occupied, () {
//           _confirmCancelReservation(ctx, prov);
//         }),
//       );
//     }

//     if (table.status == TableStatus.occupied) {
//       actions.add(
//         _ActionBtn('🧹 Mark Cleaning', TC.cleaning, () {
//           prov.markCleaning(table.id);
//           Navigator.pop(ctx);
//         }),
//       );
//     }

//     if (table.status == TableStatus.cleaning) {
//       actions.add(
//         _ActionBtn('✅ Mark Available', TC.available, () {
//           prov.markAvailable(table.id);
//           Navigator.pop(ctx);
//         }),
//       );
//     }

//     actions.add(
//       _ActionBtn('✏️ Edit Table', TC.amber, () {
//         Navigator.pop(ctx);
//         showModalBottomSheet(
//           context: ctx,
//           isScrollControlled: true,
//           backgroundColor: Colors.transparent,
//           builder: (_) => ChangeNotifierProvider.value(
//             value: prov,
//             child: _AddEditTableSheet(editTable: table),
//           ),
//         );
//       }),
//     );

//     actions.add(
//       _ActionBtn('🗑 Delete', const Color(0xFFE05252), () {
//         _confirmDelete(ctx, prov);
//       }),
//     );

//     return actions;
//   }

//   void _seatDialog(BuildContext ctx, TablesProvider prov) {
//     final ctrl = TextEditingController();
//     showDialog(
//       context: ctx,
//       builder: (_) => AlertDialog(
//         backgroundColor: TC.sheetBg,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: const Text(
//           'Seat Guest',
//           style: TextStyle(fontWeight: FontWeight.w800),
//         ),
//         content: TextField(
//           controller: ctrl,
//           decoration: const InputDecoration(hintText: 'Customer name'),
//           autofocus: true,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               prov.markOccupied(
//                 table.id,
//                 ctrl.text.isEmpty ? 'Guest' : ctrl.text,
//               );
//               Navigator.pop(ctx);
//               Navigator.pop(ctx);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: TC.amber,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Confirm'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _confirmCancelReservation(BuildContext ctx, TablesProvider prov) {
//     showDialog(
//       context: ctx,
//       builder: (_) => AlertDialog(
//         backgroundColor: TC.sheetBg,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: const Text(
//           'Cancel Reservation?',
//           style: TextStyle(fontWeight: FontWeight.w800),
//         ),
//         content: Text(
//           'Cancel reservation for ${table.reservation?.customerName ?? 'this table'}?',
//           style: const TextStyle(color: TC.sheetMute),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Keep', style: TextStyle(color: TC.sheetMute)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               prov.cancelReservation(table.id);
//               Navigator.pop(ctx);
//               Navigator.pop(ctx);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: TC.occupied,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Cancel Reservation'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _confirmDelete(BuildContext ctx, TablesProvider prov) {
//     showDialog(
//       context: ctx,
//       builder: (_) => AlertDialog(
//         backgroundColor: TC.sheetBg,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text(
//           'Delete Table ${table.number}?',
//           style: const TextStyle(fontWeight: FontWeight.w800),
//         ),
//         content: const Text(
//           'This action cannot be undone.',
//           style: TextStyle(color: TC.sheetMute),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel', style: TextStyle(color: TC.sheetMute)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               prov.deleteTable(table.id);
//               Navigator.pop(ctx);
//               Navigator.pop(ctx);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFFE05252),
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ActionBtn extends StatelessWidget {
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//   const _ActionBtn(this.label, this.color, this.onTap);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.10),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.3)),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//             color: color,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  RESERVATION SHEET  (add / edit)
// // ═════════════════════════════════════════════════════════════════════════════
// class _ReservationSheet extends StatefulWidget {
//   final RestaurantTable table;
//   final Reservation? editReservation;
//   const _ReservationSheet({required this.table, this.editReservation});

//   @override
//   State<_ReservationSheet> createState() => _ReservationSheetState();
// }

// class _ReservationSheetState extends State<_ReservationSheet> {
//   late TextEditingController _nameCtrl;
//   late TextEditingController _phoneCtrl;
//   late TextEditingController _noteCtrl;
//   late TextEditingController _guestCtrl;
//   DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     final e = widget.editReservation;
//     _nameCtrl = TextEditingController(text: e?.customerName ?? '');
//     _phoneCtrl = TextEditingController(text: e?.phone ?? '');
//     _noteCtrl = TextEditingController(text: e?.note ?? '');
//     _guestCtrl = TextEditingController(text: '${e?.guestCount ?? 2}');
//     if (e != null) _selectedDate = e.scheduledAt;
//   }

//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     _phoneCtrl.dispose();
//     _noteCtrl.dispose();
//     _guestCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final prov = context.read<TablesProvider>();
//     final isEdit = widget.editReservation != null;

//     return Container(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       decoration: const BoxDecoration(
//         color: TC.sheetBg,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _SheetHandle(),
//             _SheetHeaderBar(
//               emoji: '📅',
//               title: isEdit ? 'Edit Reservation' : 'New Reservation',
//               subtitle:
//                   'Table ${widget.table.number} · ${widget.table.zone.label}',
//               accentColor: TC.reserved,
//             ),
//             Flexible(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//                 child: Column(
//                   children: [
//                     _FormField(
//                       label: 'Customer Name *',
//                       hint: 'Full name',
//                       ctrl: _nameCtrl,
//                       validator: (v) => v!.isEmpty ? 'Required' : null,
//                     ),
//                     const SizedBox(height: 12),
//                     _FormField(
//                       label: 'Phone *',
//                       hint: '+91 XXXXX XXXXX',
//                       ctrl: _phoneCtrl,
//                       keyboard: TextInputType.phone,
//                       validator: (v) => v!.isEmpty ? 'Required' : null,
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _FormField(
//                             label: 'Guests',
//                             hint: '2',
//                             ctrl: _guestCtrl,
//                             keyboard: TextInputType.number,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Reservation Time',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w700,
//                                   color: TC.sheetMute,
//                                 ),
//                               ),
//                               const SizedBox(height: 6),
//                               GestureDetector(
//                                 onTap: () => _pickDateTime(context),
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 14,
//                                     vertical: 13,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: TC.sheetCard,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(color: TC.sheetBorder),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       const Text(
//                                         '🕐',
//                                         style: TextStyle(fontSize: 14),
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Expanded(
//                                         child: Text(
//                                           _formatDate(_selectedDate),
//                                           style: const TextStyle(
//                                             fontSize: 12,
//                                             fontWeight: FontWeight.w700,
//                                             color: TC.sheetText,
//                                           ),
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     _FormField(
//                       label: 'Special Note',
//                       hint: 'e.g. Birthday, allergies...',
//                       ctrl: _noteCtrl,
//                       maxLines: 2,
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: () => _submit(prov, isEdit),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: TC.reserved,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                           elevation: 0,
//                         ),
//                         child: Text(
//                           isEdit ? 'Update Reservation' : 'Confirm Reservation',
//                           style: const TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickDateTime(BuildContext ctx) async {
//     final date = await showDatePicker(
//       context: ctx,
//       initialDate: _selectedDate,
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 90)),
//     );
//     if (date == null || !mounted) return;
//     final time = await showTimePicker(
//       context: ctx,
//       initialTime: TimeOfDay.fromDateTime(_selectedDate),
//     );
//     if (time == null || !mounted) return;
//     setState(
//       () => _selectedDate = DateTime(
//         date.year,
//         date.month,
//         date.day,
//         time.hour,
//         time.minute,
//       ),
//     );
//   }

//   String _formatDate(DateTime dt) {
//     final now = DateTime.now();
//     final isToday = dt.day == now.day;
//     final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
//     final m = dt.minute.toString().padLeft(2, '0');
//     final p = dt.hour >= 12 ? 'PM' : 'AM';
//     return isToday ? 'Today $h:$m $p' : '${dt.day}/${dt.month} $h:$m $p';
//   }

//   void _submit(TablesProvider prov, bool isEdit) {
//     if (!_formKey.currentState!.validate()) return;
//     final res = Reservation(
//       id: widget.editReservation?.id ?? prov.generateResId(),
//       customerName: _nameCtrl.text.trim(),
//       phone: _phoneCtrl.text.trim(),
//       guestCount: int.tryParse(_guestCtrl.text) ?? 2,
//       scheduledAt: _selectedDate,
//       note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
//     );
//     prov.addReservation(tableId: widget.table.id, reservation: res);
//     Navigator.pop(context);
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ADD / EDIT TABLE SHEET
// // ═════════════════════════════════════════════════════════════════════════════
// class _AddEditTableSheet extends StatefulWidget {
//   final RestaurantTable? editTable;
//   const _AddEditTableSheet({this.editTable});

//   @override
//   State<_AddEditTableSheet> createState() => _AddEditTableSheetState();
// }

// class _AddEditTableSheetState extends State<_AddEditTableSheet> {
//   late TextEditingController _numCtrl;
//   late TextEditingController _capCtrl;
//   TableZone _zone = TableZone.ac;
//   TableShape _shape = TableShape.square;
//   int _floor = 0;
//   final _formKey = GlobalKey<FormState>();

//   bool get isEdit => widget.editTable != null;

//   @override
//   void initState() {
//     super.initState();
//     final e = widget.editTable;
//     _numCtrl = TextEditingController(text: e != null ? '${e.number}' : '');
//     _capCtrl = TextEditingController(text: e != null ? '${e.capacity}' : '');
//     _zone = e?.zone ?? TableZone.ac;
//     _shape = e?.shape ?? TableShape.square;
//     _floor = e?.floor ?? 0;
//   }

//   @override
//   void dispose() {
//     _numCtrl.dispose();
//     _capCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final prov = context.read<TablesProvider>();
//     return Container(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       decoration: const BoxDecoration(
//         color: TC.sheetBg,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _SheetHandle(),
//             _SheetHeaderBar(
//               emoji: isEdit ? '✏️' : '➕',
//               title: isEdit ? 'Edit Table' : 'Add New Table',
//               subtitle: isEdit
//                   ? 'Update table configuration'
//                   : 'Configure the new table',
//               accentColor: TC.amber,
//             ),
//             SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _FormField(
//                           label: 'Table Number *',
//                           hint: 'e.g. 5',
//                           ctrl: _numCtrl,
//                           keyboard: TextInputType.number,
//                           validator: (v) => v!.isEmpty ? 'Required' : null,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: _FormField(
//                           label: 'Capacity *',
//                           hint: 'Seats',
//                           ctrl: _capCtrl,
//                           keyboard: TextInputType.number,
//                           validator: (v) => v!.isEmpty ? 'Required' : null,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),

//                   // Floor selector
//                   _SheetSectionLabel('Floor'),
//                   const SizedBox(height: 8),
//                   Wrap(
//                     spacing: 8,
//                     children: [0, 1, 2].map((f) {
//                       final isSel = _floor == f;
//                       return GestureDetector(
//                         onTap: () => setState(() => _floor = f),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 140),
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 9,
//                           ),
//                           decoration: BoxDecoration(
//                             color: isSel
//                                 ? TC.amber.withOpacity(0.12)
//                                 : TC.sheetCard,
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(
//                               color: isSel ? TC.amber : TC.sheetBorder,
//                               width: isSel ? 1.5 : 1,
//                             ),
//                           ),
//                           child: Text(
//                             f == 0 ? '🏢 Ground' : '🔼 Floor $f',
//                             style: TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.w700,
//                               color: isSel ? TC.amber : TC.sheetMute,
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),

//                   const SizedBox(height: 16),

//                   // Zone
//                   _SheetSectionLabel('Zone'),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: TableZone.values.map((z) {
//                       final isSel = _zone == z;
//                       final c = z == TableZone.ac ? TC.acColor : TC.nonAcColor;
//                       return Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.only(right: 8),
//                           child: GestureDetector(
//                             onTap: () => setState(() => _zone = z),
//                             child: AnimatedContainer(
//                               duration: const Duration(milliseconds: 140),
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                               decoration: BoxDecoration(
//                                 color: isSel
//                                     ? c.withOpacity(0.12)
//                                     : TC.sheetCard,
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: isSel ? c : TC.sheetBorder,
//                                   width: isSel ? 1.5 : 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     z.emoji,
//                                     style: const TextStyle(fontSize: 20),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     z.label,
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w700,
//                                       color: isSel ? c : TC.sheetMute,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),

//                   const SizedBox(height: 16),

//                   // Shape
//                   _SheetSectionLabel('Shape'),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: TableShape.values.map((s) {
//                       final isSel = _shape == s;
//                       final label =
//                           s.name[0].toUpperCase() + s.name.substring(1);
//                       final emoji = s == TableShape.round
//                           ? '⭕'
//                           : s == TableShape.square
//                           ? '⬜'
//                           : '▬';
//                       return Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.only(right: 8),
//                           child: GestureDetector(
//                             onTap: () => setState(() => _shape = s),
//                             child: AnimatedContainer(
//                               duration: const Duration(milliseconds: 140),
//                               padding: const EdgeInsets.symmetric(vertical: 11),
//                               decoration: BoxDecoration(
//                                 color: isSel
//                                     ? TC.amber.withOpacity(0.10)
//                                     : TC.sheetCard,
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: isSel ? TC.amber : TC.sheetBorder,
//                                   width: isSel ? 1.5 : 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     emoji,
//                                     style: const TextStyle(fontSize: 18),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     label,
//                                     style: TextStyle(
//                                       fontSize: 11,
//                                       fontWeight: FontWeight.w700,
//                                       color: isSel ? TC.amber : TC.sheetMute,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),

//                   const SizedBox(height: 22),

//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: () => _submit(prov),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: TC.amber,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         isEdit ? 'Save Changes' : 'Add Table',
//                         style: const TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _submit(TablesProvider prov) {
//     if (!_formKey.currentState!.validate()) return;
//     final table = RestaurantTable(
//       id: widget.editTable?.id ?? prov.generateId(),
//       number: int.tryParse(_numCtrl.text) ?? 0,
//       capacity: int.tryParse(_capCtrl.text) ?? 4,
//       status: widget.editTable?.status ?? TableStatus.available,
//       zone: _zone,
//       shape: _shape,
//       floor: _floor,
//       reservation: widget.editTable?.reservation,
//     );
//     isEdit ? prov.updateTable(table) : prov.addTable(table);
//     Navigator.pop(context);
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ALL RESERVATIONS SHEET
// // ═════════════════════════════════════════════════════════════════════════════
// class _AllReservationsSheet extends StatelessWidget {
//   final TablesProvider provider;
//   const _AllReservationsSheet({required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     final upcoming = provider.upcomingReservations;
//     return Container(
//       decoration: const BoxDecoration(
//         color: TC.sheetBg,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       padding: const EdgeInsets.only(bottom: 24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _SheetHandle(),
//           _SheetHeaderBar(
//             emoji: '📅',
//             title: 'Reservations',
//             subtitle: '${upcoming.length} upcoming today',
//             accentColor: TC.reserved,
//           ),
//           if (upcoming.isEmpty)
//             const Padding(
//               padding: EdgeInsets.all(32),
//               child: Column(
//                 children: [
//                   Text('📭', style: TextStyle(fontSize: 40)),
//                   SizedBox(height: 12),
//                   Text(
//                     'No upcoming reservations',
//                     style: TextStyle(color: TC.sheetMute, fontSize: 14),
//                   ),
//                 ],
//               ),
//             )
//           else
//             ...upcoming.map(
//               (t) => _ReservationListTile(table: t, provider: provider),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class _ReservationListTile extends StatelessWidget {
//   final RestaurantTable table;
//   final TablesProvider provider;
//   const _ReservationListTile({required this.table, required this.provider});

//   @override
//   Widget build(BuildContext context) {
//     final res = table.reservation!;
//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: TC.sheetCard,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: TC.reserved.withOpacity(0.25)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               color: TC.reserved.withOpacity(0.12),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             alignment: Alignment.center,
//             child: Text(
//               '${table.number}',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w900,
//                 color: TC.reserved,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   res.customerName,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w800,
//                     color: TC.sheetText,
//                   ),
//                 ),
//                 Text(
//                   '${res.guestCount} guests · ${res.formattedTime} · ${res.timeLabel}',
//                   style: const TextStyle(fontSize: 11, color: TC.sheetMute),
//                 ),
//               ],
//             ),
//           ),
//           GestureDetector(
//             onTap: () {
//               provider.cancelReservation(table.id);
//               Navigator.pop(context);
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: BoxDecoration(
//                 color: TC.occupied.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: TC.occupied.withOpacity(0.3)),
//               ),
//               child: const Text(
//                 'Cancel',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                   color: TC.occupied,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  EMPTY STATE
// // ═════════════════════════════════════════════════════════════════════════════
// class _EmptyFloor extends StatelessWidget {
//   const _EmptyFloor();

//   @override
//   Widget build(BuildContext context) => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(color: TC.amberBg, shape: BoxShape.circle),
//           child: const Text('🪑', style: TextStyle(fontSize: 44)),
//         ),
//         const SizedBox(height: 18),
//         const Text(
//           'No tables found',
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w800,
//             color: TC.textPri,
//           ),
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           'Try a different filter or add a table',
//           style: TextStyle(fontSize: 13, color: TC.textSec),
//         ),
//       ],
//     ),
//   );
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  ADD TABLE FAB
// // ═════════════════════════════════════════════════════════════════════════════
// class _AddTableFAB extends StatelessWidget {
//   final VoidCallback onTap;
//   const _AddTableFAB({required this.onTap});

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [TC.amberLight, TC.amber],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: TC.amber.withOpacity(0.45),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: const Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.add, color: Colors.white, size: 20),
//           SizedBox(width: 8),
//           Text(
//             'Add Table',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ═════════════════════════════════════════════════════════════════════════════
// //  SHARED SMALL WIDGETS
// // ═════════════════════════════════════════════════════════════════════════════
// class _SheetHandle extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) => Container(
//     width: 36,
//     height: 4,
//     margin: const EdgeInsets.only(top: 12, bottom: 16),
//     decoration: BoxDecoration(
//       color: TC.sheetBorder,
//       borderRadius: BorderRadius.circular(2),
//     ),
//   );
// }

// class _SheetHeaderBar extends StatelessWidget {
//   final String emoji;
//   final String title;
//   final String subtitle;
//   final Color accentColor;

//   const _SheetHeaderBar({
//     required this.emoji,
//     required this.title,
//     required this.subtitle,
//     required this.accentColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: accentColor.withOpacity(0.12),
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Text(emoji, style: const TextStyle(fontSize: 20)),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w900,
//                         color: TC.sheetText,
//                       ),
//                     ),
//                     Text(
//                       subtitle,
//                       style: const TextStyle(fontSize: 12, color: TC.sheetMute),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1, color: TC.sheetBorder),
//       ],
//     );
//   }
// }

// class _DetailSection extends StatelessWidget {
//   final String title;
//   final Widget child;
//   const _DetailSection({required this.title, required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _SheetSectionLabel(title),
//         const SizedBox(height: 10),
//         Container(
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: TC.sheetCard,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: TC.sheetBorder),
//           ),
//           child: child,
//         ),
//       ],
//     );
//   }
// }

// class _DetailRow extends StatelessWidget {
//   final String emoji;
//   final String label;
//   final String value;
//   const _DetailRow(this.emoji, this.label, this.value);

//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.only(bottom: 10),
//     child: Row(
//       children: [
//         Text(emoji, style: const TextStyle(fontSize: 15)),
//         const SizedBox(width: 10),
//         Text(label, style: const TextStyle(fontSize: 12, color: TC.sheetMute)),
//         const Spacer(),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//             color: TC.sheetText,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// class _InfoPill extends StatelessWidget {
//   final String text;
//   final Color color;
//   const _InfoPill(this.text, this.color);

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//     decoration: BoxDecoration(
//       color: color.withOpacity(0.10),
//       borderRadius: BorderRadius.circular(8),
//     ),
//     child: Text(
//       text,
//       style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
//     ),
//   );
// }

// class _SheetSectionLabel extends StatelessWidget {
//   final String text;
//   const _SheetSectionLabel(this.text);

//   @override
//   Widget build(BuildContext context) => Text(
//     text.toUpperCase(),
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w800,
//       color: TC.sheetMute,
//       letterSpacing: 1.4,
//     ),
//   );
// }

// class _FormField extends StatelessWidget {
//   final String label;
//   final String hint;
//   final TextEditingController ctrl;
//   final TextInputType keyboard;
//   final String? Function(String?)? validator;
//   final int maxLines;

//   const _FormField({
//     required this.label,
//     required this.hint,
//     required this.ctrl,
//     this.keyboard = TextInputType.text,
//     this.validator,
//     this.maxLines = 1,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w700,
//             color: TC.sheetMute,
//             letterSpacing: 0.3,
//           ),
//         ),
//         const SizedBox(height: 6),
//         TextFormField(
//           controller: ctrl,
//           keyboardType: keyboard,
//           validator: validator,
//           maxLines: maxLines,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: TC.sheetText,
//           ),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: const TextStyle(color: TC.sheetMute, fontSize: 13),
//             filled: true,
//             fillColor: TC.sheetCard,
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 14,
//               vertical: 12,
//             ),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: TC.sheetBorder),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: TC.sheetBorder),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: TC.amber, width: 1.5),
//             ),
//             errorBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: TC.occupied, width: 1.5),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }



// /*import 'package:flutter/material.dart';
// import 'package:pos_app/models/table_modal.dart';
// import 'package:provider/provider.dart';
// import 'package:pos_app/providers/tables_provider.dart';
// import 'package:pos_app/screens/utils/app_sizes.dart';
// import 'package:pos_app/screens/utils/responsive_utils.dart';
// import 'package:pos_app/theme/app_colors.dart';
// import 'package:pos_app/theme/app_theme.dart';

// class TablesScreen extends StatelessWidget {
//   const TablesScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => TablesProvider(),
//       child: const _TablesView(),
//     );
//   }
// }

// class _TablesView extends StatelessWidget {
//   const _TablesView();

//   @override
//   Widget build(BuildContext context) {
//     final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
//       context,
//       mobile: 2,
//       tablet: 3,
//       desktop: 4,
//     );

//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: Column(
//           children: [
//             const _TableHeader(),
//             const _StatusSummaryRow(),
//             const _FilterChipBar(),
//             Expanded(
//               child: Consumer<TablesProvider>(
//                 builder: (context, provider, _) {
//                   final tables = provider.filteredTables;
//                   return GridView.builder(
//                     padding: EdgeInsets.all(AppSizes.paddingLarge),
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: crossAxisCount,
//                       crossAxisSpacing: AppSizes.paddingMedium,
//                       mainAxisSpacing: AppSizes.paddingMedium,
//                       childAspectRatio: 0.88,
//                     ),
//                     itemCount: tables.length,
//                     itemBuilder: (context, index) {
//                       return _TableCard(table: tables[index]);
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _TableHeader extends StatelessWidget {
//   const _TableHeader();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(AppSizes.paddingLarge),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.shadowLight,
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               gradient: AppColors.primaryGradient,
//               borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//             ),
//             child: const Icon(Icons.table_restaurant, color: AppColors.white, size: 28),
//           ),
//           SizedBox(width: AppSizes.paddingMedium),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Tables',
//                   style: AppTheme.displaySmall.copyWith(
//                     fontSize: ResponsiveUtils.getFontSize(context, 24),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Manage your restaurant tables',
//                   style: AppTheme.bodyMedium.copyWith(color: AppColors.textSecondary),
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             onPressed: () {},
//             icon: const Icon(Icons.add),
//             style: IconButton.styleFrom(
//               backgroundColor: AppColors.primaryPurple,
//               foregroundColor: AppColors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StatusSummaryRow extends StatelessWidget {
//   const _StatusSummaryRow();

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<TablesProvider>(
//       builder: (context, provider, _) {
//         return Container(
//           margin: EdgeInsets.all(AppSizes.paddingLarge),
//           padding: EdgeInsets.all(AppSizes.paddingMedium),
//           decoration: BoxDecoration(
//             color: AppColors.white,
//             borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.shadowLight,
//                 blurRadius: 10,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _StatusItem(
//                 label: 'Available',
//                 count: provider.availableCount,
//                 color: AppColors.success,
//                 icon: Icons.check_circle_outline,
//               ),
//               Container(height: 50, width: 1, color: AppColors.borderLight),
//               _StatusItem(
//                 label: 'Occupied',
//                 count: provider.occupiedCount,
//                 color: AppColors.warning,
//                 icon: Icons.people_outline,
//               ),
//               Container(height: 50, width: 1, color: AppColors.borderLight),
//               _StatusItem(
//                 label: 'Reserved',
//                 count: provider.reservedCount,
//                 color: AppColors.info,
//                 icon: Icons.event_outlined,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class _StatusItem extends StatelessWidget {
//   final String label;
//   final int count;
//   final Color color;
//   final IconData icon;

//   const _StatusItem({
//     required this.label,
//     required this.count,
//     required this.color,
//     required this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//           ),
//           child: Icon(icon, color: color, size: 24),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           count.toString(),
//           style: AppTheme.headlineLarge.copyWith(
//             color: color,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: AppTheme.labelSmall.copyWith(color: AppColors.textSecondary),
//         ),
//       ],
//     );
//   }
// }

// class _FilterChipBar extends StatelessWidget {
//   const _FilterChipBar();

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<TablesProvider>(
//       builder: (context, provider, _) {
//         return Container(
//           height: 50,
//           margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
//             itemCount: provider.filters.length,
//             itemBuilder: (context, index) {
//               final filter = provider.filters[index];
//               final isSelected = provider.selectedFilter == filter;
//               return Padding(
//                 padding: EdgeInsets.only(right: AppSizes.paddingSmall),
//                 child: ChoiceChip(
//                   label: Text(filter),
//                   selected: isSelected,
//                   onSelected: (_) => provider.setFilter(filter),
//                   backgroundColor: AppColors.white,
//                   selectedColor: AppColors.primaryPurple.withOpacity(0.15),
//                   labelStyle: AppTheme.labelMedium.copyWith(
//                     color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
//                     fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
//                   ),
//                   side: BorderSide(
//                     color: isSelected ? AppColors.primaryPurple : AppColors.borderLight,
//                     width: isSelected ? 2 : 1,
//                   ),
//                   padding: EdgeInsets.symmetric(
//                     horizontal: AppSizes.paddingMedium,
//                     vertical: AppSizes.paddingSmall,
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// // ─────────────────────────────────────────
// //  TABLE CARD — overflow fixed
// // ─────────────────────────────────────────
// class _TableCard extends StatelessWidget {
//   final TableModel table;
//   const _TableCard({required this.table});

//   Color get _statusColor {
//     switch (table.status) {
//       case TableStatus.available: return AppColors.success;
//       case TableStatus.occupied: return AppColors.warning;
//       case TableStatus.reserved: return AppColors.info;
//     }
//   }

//   IconData get _statusIcon {
//     switch (table.status) {
//       case TableStatus.available: return Icons.check_circle;
//       case TableStatus.occupied: return Icons.people;
//       case TableStatus.reserved: return Icons.event;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => _showDetailsSheet(context),
//       child: Container(
//         decoration: BoxDecoration(
//           color: AppColors.white,
//           borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//           border: Border.all(color: _statusColor.withOpacity(0.3), width: 2),
//           boxShadow: [
//             BoxShadow(
//               color: AppColors.shadowLight,
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             // ── Header strip ──────────────────────────────
//             Container(
//               padding: EdgeInsets.symmetric(
//                 horizontal: AppSizes.paddingMedium,
//                 vertical: 10,
//               ),
//               decoration: BoxDecoration(
//                 color: _statusColor.withOpacity(0.1),
//                 borderRadius: BorderRadius.vertical(
//                   top: Radius.circular(AppSizes.borderRadiusLarge - 2),
//                 ),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.table_restaurant, color: _statusColor, size: 18),
//                       const SizedBox(width: 6),
//                       Text(
//                         'T${table.tableNumber}',
//                         style: AppTheme.headlineSmall.copyWith(
//                           color: _statusColor,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: _statusColor,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.person, size: 9, color: AppColors.white),
//                         const SizedBox(width: 3),
//                         Text(
//                           '${table.capacity}',
//                           style: AppTheme.labelSmall.copyWith(
//                             color: AppColors.white,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 11,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // ── Body — FIXED: Expanded + FittedBox to prevent overflow ──
//             Expanded(
//               child: Padding(
//                 padding: EdgeInsets.all(AppSizes.paddingSmall),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: _statusColor.withOpacity(0.1),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(_statusIcon, color: _statusColor, size: 26),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       table.statusLabel,
//                       style: AppTheme.headlineSmall.copyWith(
//                         color: _statusColor,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 13,
//                       ),
//                     ),
//                     if (table.status == TableStatus.occupied) ...[
//                       const SizedBox(height: 4),
//                       Text(
//                         table.customerName ?? '',
//                         style: AppTheme.bodySmall.copyWith(
//                           color: AppColors.textSecondary,
//                           fontSize: 11,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         '₹${table.orderTotal?.toStringAsFixed(0)}',
//                         style: AppTheme.bodyMedium.copyWith(
//                           color: AppColors.primaryPurple,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 13,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.access_time, size: 10, color: AppColors.textSecondary),
//                           const SizedBox(width: 2),
//                           Text(
//                             table.formattedDuration,
//                             style: AppTheme.labelSmall.copyWith(
//                               color: AppColors.textSecondary,
//                               fontSize: 10,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ] else if (table.status == TableStatus.reserved) ...[
//                       const SizedBox(height: 4),
//                       Text(
//                         table.customerName ?? '',
//                         style: AppTheme.bodySmall.copyWith(
//                           color: AppColors.textSecondary,
//                           fontSize: 11,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         table.formattedReservation,
//                         style: AppTheme.labelSmall.copyWith(
//                           color: AppColors.info,
//                           fontSize: 10,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showDetailsSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _TableDetailsSheet(table: table),
//     );
//   }
// }

// // ─────────────────────────────────────────
// //  TABLE DETAILS BOTTOM SHEET
// // ─────────────────────────────────────────
// class _TableDetailsSheet extends StatelessWidget {
//   final TableModel table;
//   const _TableDetailsSheet({required this.table});

//   Color get _statusColor {
//     switch (table.status) {
//       case TableStatus.available: return AppColors.success;
//       case TableStatus.occupied: return AppColors.warning;
//       case TableStatus.reserved: return AppColors.info;
//     }
//   }

//   IconData get _statusIcon {
//     switch (table.status) {
//       case TableStatus.available: return Icons.check_circle;
//       case TableStatus.occupied: return Icons.people;
//       case TableStatus.reserved: return Icons.event;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.vertical(
//           top: Radius.circular(AppSizes.borderRadiusXLarge),
//         ),
//       ),
//       padding: EdgeInsets.fromLTRB(
//         AppSizes.paddingLarge,
//         AppSizes.paddingLarge,
//         AppSizes.paddingLarge,
//         AppSizes.paddingLarge + MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Handle
//           Center(
//             child: Container(
//               width: 40,
//               height: 4,
//               margin: const EdgeInsets.only(bottom: 20),
//               decoration: BoxDecoration(
//                 color: AppColors.borderLight,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//           ),
//           // Title row
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: _statusColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//                     ),
//                     child: Icon(Icons.table_restaurant, color: _statusColor, size: 24),
//                   ),
//                   SizedBox(width: AppSizes.paddingMedium),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Table ${table.tableNumber}', style: AppTheme.headlineMedium),
//                       Text(
//                         'Capacity: ${table.capacity} · ${table.section ?? ""}',
//                         style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               IconButton(
//                 onPressed: () => Navigator.pop(context),
//                 icon: const Icon(Icons.close),
//                 style: IconButton.styleFrom(
//                   backgroundColor: AppColors.lightNeutral200,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: AppSizes.paddingLarge),
//           // Status badge
//           Container(
//             padding: EdgeInsets.all(AppSizes.paddingMedium),
//             decoration: BoxDecoration(
//               color: _statusColor.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//             ),
//             child: Row(
//               children: [
//                 Icon(_statusIcon, color: _statusColor),
//                 const SizedBox(width: 12),
//                 Text(
//                   table.statusLabel,
//                   style: AppTheme.headlineSmall.copyWith(
//                     color: _statusColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (table.status == TableStatus.occupied) ...[
//             SizedBox(height: AppSizes.paddingLarge),
//             _InfoRow(label: 'Customer', value: table.customerName ?? ''),
//             _InfoRow(label: 'Order ID', value: table.orderId ?? ''),
//             _InfoRow(label: 'Total Amount', value: '₹${table.orderTotal?.toStringAsFixed(0)}'),
//             _InfoRow(label: 'Duration', value: table.formattedDuration),
//           ] else if (table.status == TableStatus.reserved) ...[
//             SizedBox(height: AppSizes.paddingLarge),
//             _InfoRow(label: 'Customer', value: table.customerName ?? ''),
//             _InfoRow(label: 'Reserved For', value: table.formattedReservation),
//           ],
//           SizedBox(height: AppSizes.paddingLarge),
//           // Action buttons
//           Consumer<TablesProvider>(
//             builder: (context, provider, _) {
//               return Row(
//                 children: [
//                   if (table.status == TableStatus.available)
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => Navigator.pop(context),
//                         icon: const Icon(Icons.add),
//                         label: const Text('Assign Table'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: AppColors.primaryPurple,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                         ),
//                       ),
//                     )
//                   else ...[
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: () {
//                           provider.clearTable(table.tableNumber);
//                           Navigator.pop(context);
//                         },
//                         icon: const Icon(Icons.close, size: 18),
//                         label: const Text('Clear Table'),
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                         ),
//                       ),
//                     ),
//                     if (table.status == TableStatus.occupied) ...[
//                       SizedBox(width: AppSizes.paddingSmall),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: () => Navigator.pop(context),
//                           icon: const Icon(Icons.receipt, size: 18),
//                           label: const Text('View Bill'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primaryPurple,
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InfoRow extends StatelessWidget {
//   final String label;
//   final String value;
//   const _InfoRow({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: AppTheme.bodyMedium.copyWith(color: AppColors.textSecondary),
//           ),
//           Text(
//             value,
//             style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
//           ),
//         ],
//       ),
//     );
//   }
// }*/