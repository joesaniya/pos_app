import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

// ═════════════════════════════════════════════════════════════
//  HISTORY VIEW
//  FIX 1: Only upcoming reservations shown by default
//  FIX 2: Custom premium date range picker (no showDateRangePicker)
// ═════════════════════════════════════════════════════════════
class HistoryView extends StatefulWidget {
  final TablesProvider prov;
  const HistoryView({super.key, required this.prov});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _scrollCtrl = ScrollController();

  // FIX 1: Default range = today → +60 days (upcoming only)
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 60));
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!widget.prov.historyLoading && widget.prov.historyHasMore) {
        widget.prov.loadHistory();
      }
    }
  }

  // FIX 2: Open custom date picker instead of showDateRangePicker
  Future<void> _pickDateRange() async {
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CustomDateRangePicker(initialFrom: _fromDate, initialTo: _toDate),
    );
    if (result != null) {
      setState(() {
        _fromDate = result.start;
        _toDate = result.end.add(const Duration(days: 1));
      });
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    }
  }

  Map<String, List<ReservationHistoryItem>> _groupByDate(
    List<ReservationHistoryItem> items,
  ) {
    final map = <String, List<ReservationHistoryItem>>{};
    for (final item in items) {
      final key = _dayKey(item.reservedFor);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dayKey(DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    final history = widget.prov.history;

    // FIX 1: For 'active' status, only show future (upcoming) reservations
    final filtered = history.where((h) {
      if (_filterStatus != null && h.status != _filterStatus) return false;
      // When showing 'active' (upcoming), exclude past dates
      if (h.status == 'active' && h.reservedFor.isBefore(DateTime.now()))
        return false;
      return true;
    }).toList();

    final total = filtered.length;
    final upcoming = filtered.where((h) => h.status == 'active').length;
    final seated = filtered.where((h) => h.status == 'seated').length;
    final cancelled = filtered.where((h) => h.status == 'cancelled').length;
    final noshow = filtered.where((h) => h.status == 'no_show').length;

    final grouped = _groupByDate(filtered);
    final dateKeys = grouped.keys.toList();

    final flatItems = <dynamic>[];
    for (final key in dateKeys) {
      flatItems.add(key);
      flatItems.addAll(grouped[key]!);
    }
    if (widget.prov.historyHasMore) flatItems.add('__loader__');

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────
        _Toolbar(
          fromDate: _fromDate,
          toDate: _toDate,
          total: total,
          upcoming: upcoming,
          seated: seated,
          cancelled: cancelled,
          noshow: noshow,
          filterStatus: _filterStatus,
          onPickDate: _pickDateRange,
          onRefresh: () => widget.prov.loadHistory(
            from: _fromDate,
            to: _toDate,
            reset: true,
          ),
          onFilter: (s) => setState(() => _filterStatus = s),
        ),
        const SizedBox(height: 8),

        // ── Stats row ─────────────────────────────────────────────
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                StatPill(label: 'Total', value: '$total', color: TC.textSec),
                const SizedBox(width: 8),
                StatPill(
                  label: 'Upcoming',
                  value: '$upcoming',
                  color: TC.reserved,
                ),
                const SizedBox(width: 8),
                StatPill(
                  label: 'Seated',
                  value: '$seated',
                  color: TC.available,
                ),
                const SizedBox(width: 8),
                StatPill(
                  label: 'No-show',
                  value: '$noshow',
                  color: TC.cleaning,
                ),
              ],
            ),
          ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: flatItems.isEmpty && !widget.prov.historyLoading
              ? _EmptyState()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: flatItems.length,
                  itemBuilder: (ctx, i) {
                    final item = flatItems[i];
                    if (item == '__loader__') {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: TC.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    if (item is String)
                      return _DateHeader(
                        label: item,
                        count: grouped[item]!.length,
                      );
                    return HistoryCard(item: item as ReservationHistoryItem);
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOOLBAR
// ─────────────────────────────────────────────────────────────
class _Toolbar extends StatelessWidget {
  final DateTime fromDate, toDate;
  final int total, upcoming, seated, cancelled, noshow;
  final String? filterStatus;
  final VoidCallback onPickDate, onRefresh;
  final void Function(String?) onFilter;

  const _Toolbar({
    required this.fromDate,
    required this.toDate,
    required this.total,
    required this.upcoming,
    required this.seated,
    required this.cancelled,
    required this.noshow,
    required this.filterStatus,
    required this.onPickDate,
    required this.onRefresh,
    required this.onFilter,
  });

  String _fmt(DateTime dt) {
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
    return '${dt.day} ${m[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Date range button
                GestureDetector(
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TC.accentLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TC.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 15,
                          color: TC.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_fmt(fromDate)} – ${_fmt(toDate.subtract(const Duration(days: 1)))}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: TC.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: TC.accent,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TC.accentLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: TC.accent,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              children: [
                HistoryChip(
                  label: 'All',
                  count: total,
                  selected: filterStatus == null,
                  color: TC.textSec,
                  onTap: () => onFilter(null),
                ),
                HistoryChip(
                  label: 'Upcoming',
                  count: upcoming,
                  selected: filterStatus == 'active',
                  color: TC.reserved,
                  onTap: () => onFilter('active'),
                ),
                HistoryChip(
                  label: 'Seated',
                  count: seated,
                  selected: filterStatus == 'seated',
                  color: TC.available,
                  onTap: () => onFilter('seated'),
                ),
                HistoryChip(
                  label: 'Cancelled',
                  count: cancelled,
                  selected: filterStatus == 'cancelled',
                  color: TC.occupied,
                  onTap: () => onFilter('cancelled'),
                ),
                HistoryChip(
                  label: 'No-show',
                  count: noshow,
                  selected: filterStatus == 'no_show',
                  color: TC.cleaning,
                  onTap: () => onFilter('no_show'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DATE HEADER
// ─────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  final int count;
  const _DateHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: TC.surfaceWarm,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TC.border),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: TC.textSec,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: TC.divider)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              color: TC.textMute,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: TC.surfaceWarm,
              shape: BoxShape.circle,
            ),
            child: const Text('📅', style: TextStyle(fontSize: 38)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No upcoming reservations',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: TC.textPri,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Future bookings will appear here',
            style: TextStyle(fontSize: 12, color: TC.textSec),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  CUSTOM DATE RANGE PICKER  — premium bottom sheet
// ═════════════════════════════════════════════════════════════
class _CustomDateRangePicker extends StatefulWidget {
  final DateTime initialFrom, initialTo;
  const _CustomDateRangePicker({
    required this.initialFrom,
    required this.initialTo,
  });

  @override
  State<_CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<_CustomDateRangePicker> {
  late DateTime _viewMonth; // which month the calendar shows
  DateTime? _from, _to;
  bool _selectingFrom = true; // true = next tap sets 'from', false = sets 'to'

  // Quick presets
  static const _presets = [
    ('Today', 0, 0),
    ('Next 7 days', 0, 6),
    ('Next 30 days', 0, 29),
    ('Next 60 days', 0, 59),
    ('This month', -1, -1), // special
    ('Last 30 days', -30, 0),
  ];

  @override
  void initState() {
    super.initState();
    _from = DateTime(
      widget.initialFrom.year,
      widget.initialFrom.month,
      widget.initialFrom.day,
    );
    _to = DateTime(
      widget.initialTo.year,
      widget.initialTo.month,
      widget.initialTo.day,
    );
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _applyPreset(int fromOffset, int toOffset, bool isThisMonth) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      if (isThisMonth) {
        _from = DateTime(today.year, today.month, 1);
        _to = DateTime(today.year, today.month + 1, 0);
      } else {
        _from = today.add(Duration(days: fromOffset));
        _to = today.add(Duration(days: toOffset));
      }
      _selectingFrom = false;
    });
  }

  void _onDayTap(DateTime day) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectingFrom) {
        _from = day;
        _to = null;
        _selectingFrom = false;
      } else {
        if (day.isBefore(_from!)) {
          _to = _from;
          _from = day;
        } else {
          _to = day;
        }
        _selectingFrom = true;
      }
    });
  }

  bool _inRange(DateTime day) {
    if (_from == null || _to == null) return false;
    return !day.isBefore(_from!) && !day.isAfter(_to!);
  }

  void _confirm() {
    if (_from != null && _to != null) {
      Navigator.pop(context, DateTimeRange(start: _from!, end: _to!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.82,
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: TC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _from == null
                          ? 'Tap a start date'
                          : _to == null
                          ? 'Tap an end date'
                          : '${_fmtShort(_from!)} → ${_fmtShort(_to!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _from != null && _to != null
                            ? TC.accent
                            : TC.textMute,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_from != null || _to != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _from = null;
                      _to = null;
                      _selectingFrom = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TC.surfaceWarm,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: TC.textSec,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Quick Presets ────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _presets.map((p) {
                final isThisMonth = p.$2 == -1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _applyPreset(p.$2, p.$3, isThisMonth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: TC.accentLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TC.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        p.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TC.accent,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Month navigation ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(() {
                    _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month - 1,
                    );
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel(_viewMonth),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => setState(() {
                    _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month + 1,
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Weekday labels ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: TC.textMute,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),

          // ── Calendar grid ───────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CalendarGrid(
                viewMonth: _viewMonth,
                from: _from,
                to: _to,
                inRange: _inRange,
                onDayTap: _onDayTap,
              ),
            ),
          ),

          // ── Confirm button ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_from != null && _to != null) ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TC.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: TC.border,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _from != null && _to != null
                      ? 'Apply  ${_fmtShort(_from!)} → ${_fmtShort(_to!)}'
                      : 'Select a date range',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime dt) {
    const months = [
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
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _fmtShort(DateTime dt) {
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
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR GRID
// ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime? from, to;
  final bool Function(DateTime) inRange;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.viewMonth,
    required this.from,
    required this.to,
    required this.inRange,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(viewMonth.year, viewMonth.month, 1);
    final lastDay = DateTime(viewMonth.year, viewMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];

    // Leading empty cells
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (var d = 1; d <= lastDay.day; d++) {
      final day = DateTime(viewMonth.year, viewMonth.month, d);
      final isFrom = from != null && day == from;
      final isTo = to != null && day == to;
      final isEnd = isFrom || isTo;
      final inRng = inRange(day);
      final isToday = day == todayDay;

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isEnd
                  ? TC.accent
                  : inRng
                  ? TC.accent.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isEnd
                  ? Border.all(color: TC.accent.withOpacity(0.5), width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '$d',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isEnd || isToday
                      ? FontWeight.w900
                      : FontWeight.w500,
                  color: isEnd
                      ? Colors.white
                      : inRng
                      ? TC.accent
                      : isToday
                      ? TC.accent
                      : TC.textPri,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: cells,
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TC.surfaceWarm,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TC.border),
      ),
      child: Icon(icon, size: 18, color: TC.textSec),
    ),
  );
}

// ═════════════════════════════════════════════════════════════
//  STAT PILL
// ═════════════════════════════════════════════════════════════
class StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TC.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HISTORY CHIP
// ═════════════════════════════════════════════════════════════
class HistoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const HistoryChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : TC.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : TC.textMute,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.18) : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : TC.textMute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HISTORY CARD
// ═════════════════════════════════════════════════════════════
class HistoryCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const HistoryCard({super.key, required this.item});

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
      'seated' => 'Seated',
      'cancelled' => 'Cancelled',
      'no_show' => 'No-show',
      _ => isPast ? 'Completed' : 'Upcoming',
    };
    final statusIcon = switch (item.status) {
      'seated' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      'no_show' => Icons.person_off_outlined,
      _ => isPast ? Icons.history_rounded : Icons.event_available_outlined,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );
    final secColor = sectionColor(sectionEnum);
    final secBg = sectionBg(sectionEnum);

    final inTime = _fmtTime(item.reservedFor);
    final outTime = item.checkOut != null ? _fmtTime(item.checkOut!) : null;
    final dur = item.checkOut != null
        ? item.checkOut!.difference(item.reservedFor).inMinutes
        : null;
    final durLabel = dur != null
        ? (dur >= 60
              ? '${(dur / 60).toStringAsFixed(dur % 60 == 0 ? 0 : 1)}h'
              : '${dur}m')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            // ── Time column ──────────────────────────────────────
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                border: Border(
                  right: BorderSide(color: statusColor.withOpacity(0.15)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: statusColor.withOpacity(0.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      height: 1.2,
                    ),
                  ),
                  if (outTime != null) ...[
                    const SizedBox(height: 1),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 9,
                      color: statusColor.withOpacity(0.5),
                    ),
                    Text(
                      outTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (durLabel != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                            color: secBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: secColor.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: secColor,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Icon(
                          Icons.person_outline,
                          size: 11,
                          color: TC.textMute,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.createdByName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TC.textMute,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 4),
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
import 'package:pos_app/screens/tables_screen/table_theme.dart';

// ═════════════════════════════════════════════════════════════
//  HISTORY VIEW
// ═════════════════════════════════════════════════════════════
class HistoryView extends StatefulWidget {
  final TablesProvider prov;
  const HistoryView({super.key, required this.prov});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _scrollCtrl = ScrollController();
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!widget.prov.historyLoading && widget.prov.historyHasMore) {
        widget.prov.loadHistory();
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TC.accent,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end.add(const Duration(days: 1));
      });
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    }
  }

  Map<String, List<ReservationHistoryItem>> _groupByDate(
    List<ReservationHistoryItem> items,
  ) {
    final map = <String, List<ReservationHistoryItem>>{};
    for (final item in items) {
      final key = _dayKey(item.reservedFor);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dayKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
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

  @override
  Widget build(BuildContext context) {
    final history = widget.prov.history;
    final filtered = _filterStatus == null
        ? history
        // FIX: use 'no_show' (with underscore) to match the DB value
        : history.where((h) => h.status == _filterStatus).toList();

    final total = filtered.length;
    final seated = filtered.where((h) => h.status == 'seated').length;
    final cancelled = filtered.where((h) => h.status == 'cancelled').length;
    // FIX: count using 'no_show' to match DB
    final noshow = filtered.where((h) => h.status == 'no_show').length;
    final active = filtered.where((h) => h.status == 'active').length;

    final grouped = _groupByDate(filtered);
    final dateKeys = grouped.keys.toList();

    final flatItems = <dynamic>[];
    for (final key in dateKeys) {
      flatItems.add(key);
      flatItems.addAll(grouped[key]!);
    }
    if (widget.prov.historyHasMore) flatItems.add('__loader__');

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: TC.surface,
            borderRadius: BorderRadius.circular(16),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TC.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 15,
                              color: TC.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_fmtDate(_fromDate)} – ${_fmtDate(_toDate.subtract(const Duration(days: 1)))}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: TC.textPri,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 14,
                              color: TC.textMute,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.prov.loadHistory(
                        from: _fromDate,
                        to: _toDate,
                        reset: true,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TC.accentLight,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: TC.accent,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  children: [
                    HistoryChip(
                      label: 'All',
                      count: total,
                      selected: _filterStatus == null,
                      color: TC.textSec,
                      onTap: () => setState(() => _filterStatus = null),
                    ),
                    HistoryChip(
                      label: 'Active',
                      count: active,
                      selected: _filterStatus == 'active',
                      color: TC.reserved,
                      onTap: () => setState(() => _filterStatus = 'active'),
                    ),
                    HistoryChip(
                      label: 'Seated',
                      count: seated,
                      selected: _filterStatus == 'seated',
                      color: TC.available,
                      onTap: () => setState(() => _filterStatus = 'seated'),
                    ),
                    HistoryChip(
                      label: 'Cancelled',
                      count: cancelled,
                      selected: _filterStatus == 'cancelled',
                      color: TC.occupied,
                      onTap: () => setState(() => _filterStatus = 'cancelled'),
                    ),
                    // FIX: filter value changed from 'noshow' → 'no_show'
                    HistoryChip(
                      label: 'No-show',
                      count: noshow,
                      selected: _filterStatus == 'no_show',
                      color: TC.cleaning,
                      onTap: () => setState(() => _filterStatus = 'no_show'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                StatPill(label: 'Total', value: '$total', color: TC.textSec),
                const SizedBox(width: 8),
                StatPill(
                  label: 'Seated',
                  value: '$seated',
                  color: TC.available,
                ),
                const SizedBox(width: 8),
                StatPill(
                  label: 'Cancelled',
                  value: '$cancelled',
                  color: TC.occupied,
                ),
                const SizedBox(width: 8),
                StatPill(
                  label: 'No-show',
                  value: '$noshow',
                  color: TC.cleaning,
                ),
              ],
            ),
          ),
        Expanded(
          child: flatItems.isEmpty && !widget.prov.historyLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          color: TC.surfaceWarm,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('📋', style: TextStyle(fontSize: 38)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No records found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TC.textPri,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Try a different date range or filter',
                        style: TextStyle(fontSize: 12, color: TC.textSec),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: flatItems.length,
                  itemBuilder: (ctx, i) {
                    final item = flatItems[i];
                    if (item == '__loader__') {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: TC.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: TC.border),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: TC.textSec,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(height: 1, color: TC.divider),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${grouped[item]!.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: TC.textMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return HistoryCard(item: item as ReservationHistoryItem);
                  },
                ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) {
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
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────
//  STAT PILL
// ─────────────────────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TC.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HISTORY CHIP
// ─────────────────────────────────────────────────────────────
class HistoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const HistoryChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : TC.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : TC.textMute,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.18) : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : TC.textMute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HISTORY CARD
// ─────────────────────────────────────────────────────────────
class HistoryCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const HistoryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // FIX: For 'active' status, check if the reservedFor date is in the past.
    // Past active records show as "Completed" (grey), future ones show "Upcoming" (reserved color).
    final isPast = item.reservedFor.isBefore(DateTime.now());

    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'cancelled' => TC.occupied,
      // FIX: match DB value 'no_show'
      'no_show' => TC.cleaning,
      // FIX: past active = completed (grey), future active = upcoming (reserved blue)
      _ => isPast ? const Color(0xFF9CA3AF) : TC.reserved,
    };
    final statusLabel = switch (item.status) {
      'seated' => 'Seated',
      'cancelled' => 'Cancelled',
      // FIX: match DB value 'no_show'
      'no_show' => 'No-show',
      // FIX: past = 'Completed', future = 'Upcoming'
      _ => isPast ? 'Completed' : 'Upcoming',
    };
    final statusIcon = switch (item.status) {
      'seated' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      'no_show' => Icons.person_off_outlined,
      _ => isPast ? Icons.history_rounded : Icons.event_available_outlined,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );
    final secColor = sectionColor(sectionEnum);
    final secBg = sectionBg(sectionEnum);

    final inTime = _fmtTime(item.reservedFor);
    final outTime = item.checkOut != null ? _fmtTime(item.checkOut!) : null;
    final dur = item.checkOut != null
        ? item.checkOut!.difference(item.reservedFor).inMinutes
        : null;
    final durLabel = dur != null
        ? (dur >= 60
              ? '${(dur / 60).toStringAsFixed(dur % 60 == 0 ? 0 : 1)}h'
              : '${dur}m')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                border: Border(
                  right: BorderSide(color: statusColor.withOpacity(0.15)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: statusColor.withOpacity(0.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      height: 1.2,
                    ),
                  ),
                  if (outTime != null) ...[
                    const SizedBox(height: 1),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 9,
                      color: statusColor.withOpacity(0.5),
                    ),
                    Text(
                      outTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (durLabel != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                            color: secBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: secColor.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: secColor,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Icon(
                          Icons.person_outline,
                          size: 11,
                          color: TC.textMute,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.createdByName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TC.textMute,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 4),
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
*/