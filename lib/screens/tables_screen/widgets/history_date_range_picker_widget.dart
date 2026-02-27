// ─────────────────────────────────────────────────────────────────────────────
//  HISTORY SCREEN — DATE RANGE PATCH
//
//  Drop this file as: lib/screens/tables_screen/history_date_filter.dart
//
//  This replaces the date-range picker widget used in your history tab.
//  Key fixes:
//   1. Default range = last 30 days → next 60 days (March reservations visible)
//   2. lastDate extended to 90 days ahead so future bookings are always reachable
//   3. "Active" status tab includes both past-due AND upcoming active reservations
//   4. A clear "Today forward" shortcut button added
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

// ══════════════════════════════════════════════════════════════
//  HISTORY DATE RANGE PICKER  (replaces old Jan-Feb fixed range)
// ══════════════════════════════════════════════════════════════
class HistoryDateRangePicker extends StatefulWidget {
  /// Called when user confirms a date range.
  final void Function(DateTime from, DateTime to) onRangeSelected;

  /// The currently active range — shown in the trigger button.
  final DateTime? activeFrom;
  final DateTime? activeTo;

  const HistoryDateRangePicker({
    super.key,
    required this.onRangeSelected,
    this.activeFrom,
    this.activeTo,
  });

  @override
  State<HistoryDateRangePicker> createState() => _HistoryDateRangePickerState();
}

class _HistoryDateRangePickerState extends State<HistoryDateRangePicker> {
  // ── Default date range ────────────────────────────────────────────────────
  //
  // FIX: Was hardcoded to Jan 28 – Feb 28 which excluded March reservations.
  // Now defaults to: (today – 30 days)  →  (today + 60 days)
  // This ensures all upcoming reservations are visible without any manual
  // date range selection.
  //
  DateTime get _defaultFrom =>
      DateTime.now().subtract(const Duration(days: 30));
  DateTime get _defaultTo => DateTime.now().add(const Duration(days: 60));

  DateTime get _from => widget.activeFrom ?? _defaultFrom;
  DateTime get _to => widget.activeTo ?? _defaultTo;

  String _label(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[dt.month - 1]} ${dt.day}';
  }

  Future<void> _openPicker() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      // FIX: firstDate is 1 year back, lastDate is 90 days ahead
      // Previously lastDate was Feb 28 → March reservations were invisible
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TC.accent,
            onPrimary: Colors.white,
            surface: TC.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      widget.onRangeSelected(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Date range button ──────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: _openPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: TC.surfaceWarm,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TC.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 15, color: TC.accent),
                  const SizedBox(width: 6),
                  Text(
                    '${_label(_from)} – ${_label(_to)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TC.textPri,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 15, color: TC.textMute),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ── "Today →" quick shortcut ──────────────────────────────────────
        // Jumps to today → +60 days range with one tap
        Tooltip(
          message: 'Show from today onwards',
          child: GestureDetector(
            onTap: () {
              final now = DateTime.now();
              widget.onRangeSelected(
                DateTime(now.year, now.month, now.day),
                now.add(const Duration(days: 60)),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: TC.surfaceWarm,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TC.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: TC.accent),
                  SizedBox(width: 4),
                  Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TC.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  STATUS TAB BAR  (with corrected Active label)
// ══════════════════════════════════════════════════════════════
//
//  "Active" tab includes ALL reservations with status = 'active',
//  regardless of date (past-due actives + future actives both appear here).
//  This is correct — old "active" rows that slipped through without being
//  marked no_show will still surface here until manually handled.
//
class ReservationStatusTabs extends StatelessWidget {
  final String? selectedStatus;
  final Map<String, int> counts; // { 'all': 5, 'active': 2, 'seated': 1, ... }
  final ValueChanged<String?> onSelected;

  const ReservationStatusTabs({
    super.key,
    required this.selectedStatus,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _Tab(label: 'All', key: null, icon: '📋'),
      _Tab(label: 'Active', key: 'active', icon: '🟡'),
      _Tab(label: 'Seated', key: 'seated', icon: '🪑'),
      _Tab(label: 'Cancelled', key: 'cancelled', icon: '❌'),
      _Tab(label: 'No-show', key: 'no_show', icon: '👻'),
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isSelected = selectedStatus == tab.key;
          final count = counts[tab.key ?? 'all'] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(tab.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? TC.accent : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? TC.accent : TC.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.icon,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? Colors.white : TC.textSec,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.25)
                              : TC.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                isSelected ? Colors.white : TC.accent,
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

class _Tab {
  final String label;
  final String? key;
  final String icon;
  const _Tab({required this.label, required this.key, required this.icon});
}

// ══════════════════════════════════════════════════════════════
//  HOW TO USE IN YOUR HISTORY SCREEN
// ══════════════════════════════════════════════════════════════
//
//  1. Replace your existing date range button with:
//       HistoryDateRangePicker(
//         activeFrom: provider.historyFrom,     // expose via getter
//         activeTo: provider.historyTo,         // expose via getter
//         onRangeSelected: (from, to) {
//           provider.loadHistory(from: from, to: to, reset: true);
//         },
//       )
//
//  2. Replace your status filter chips with:
//       ReservationStatusTabs(
//         selectedStatus: _selectedStatus,
//         counts: {
//           'all': provider.history.length,
//           'active': provider.history.where((r) => r.status == 'active').length,
//           'seated': provider.history.where((r) => r.status == 'seated').length,
//           'cancelled': provider.history.where((r) => r.status == 'cancelled').length,
//           'no_show': provider.history.where((r) => r.status == 'no_show').length,
//         },
//         onSelected: (status) => setState(() => _selectedStatus = status),
//       )
//
//  3. In TablesProvider, expose historyFrom/historyTo:
//       DateTime? get historyFrom => _historyFrom;
//       DateTime? get historyTo => _historyTo;
//
// ══════════════════════════════════════════════════════════════