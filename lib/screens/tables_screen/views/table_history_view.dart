import 'package:flutter/material.dart';
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


//noshow filter issue in this
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
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
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
          colorScheme: const ColorScheme.light(primary: TC.accent, onPrimary: Colors.white),
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

  Map<String, List<ReservationHistoryItem>> _groupByDate(List<ReservationHistoryItem> items) {
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
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.prov.history;
    final filtered = _filterStatus == null
        ? history
        : history.where((h) => h.status == _filterStatus).toList();

    final total = filtered.length;
    final seated = filtered.where((h) => h.status == 'seated').length;
    final cancelled = filtered.where((h) => h.status == 'cancelled').length;
    final noshow = filtered.where((h) => h.status == 'noshow').length;
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
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TC.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 15, color: TC.accent),
                            const SizedBox(width: 6),
                            Text(
                              '${_fmtDate(_fromDate)} – ${_fmtDate(_toDate.subtract(const Duration(days: 1)))}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.textPri),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded, size: 14, color: TC.textMute),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TC.accentLight,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: TC.accent, size: 17),
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
                    HistoryChip(label: 'All', count: total, selected: _filterStatus == null, color: TC.textSec, onTap: () => setState(() => _filterStatus = null)),
                    HistoryChip(label: 'Active', count: active, selected: _filterStatus == 'active', color: TC.reserved, onTap: () => setState(() => _filterStatus = 'active')),
                    HistoryChip(label: 'Seated', count: seated, selected: _filterStatus == 'seated', color: TC.available, onTap: () => setState(() => _filterStatus = 'seated')),
                    HistoryChip(label: 'Cancelled', count: cancelled, selected: _filterStatus == 'cancelled', color: TC.occupied, onTap: () => setState(() => _filterStatus = 'cancelled')),
                    HistoryChip(label: 'No-show', count: noshow, selected: _filterStatus == 'noshow', color: TC.cleaning, onTap: () => setState(() => _filterStatus = 'noshow')),
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
                StatPill(label: 'Seated', value: '$seated', color: TC.available),
                const SizedBox(width: 8),
                StatPill(label: 'Cancelled', value: '$cancelled', color: TC.occupied),
                const SizedBox(width: 8),
                StatPill(label: 'No-show', value: '$noshow', color: TC.cleaning),
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
                        decoration: const BoxDecoration(color: TC.surfaceWarm, shape: BoxShape.circle),
                        child: const Text('📋', style: TextStyle(fontSize: 38)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No records found',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.textPri),
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
                        child: Center(child: CircularProgressIndicator(color: TC.accent, strokeWidth: 2)),
                      );
                    }
                    if (item is String) {
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
                            Expanded(child: Container(height: 1, color: TC.divider)),
                            const SizedBox(width: 8),
                            Text(
                              '${grouped[item]!.length}',
                              style: const TextStyle(fontSize: 11, color: TC.textMute, fontWeight: FontWeight.w600),
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
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────
//  STAT PILL
// ─────────────────────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const StatPill({super.key, required this.label, required this.value, required this.color});
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
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: TC.textMute)),
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
            border: Border.all(color: selected ? color : TC.border, width: selected ? 1.5 : 1),
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
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'cancelled' => TC.occupied,
      'noshow' => TC.cleaning,
      _ => TC.reserved,
    };
    final statusLabel = switch (item.status) {
      'seated' => 'Seated',
      'cancelled' => 'Cancelled',
      'noshow' => 'No-show',
      _ => 'Upcoming',
    };
    final statusIcon = switch (item.status) {
      'seated' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      'noshow' => Icons.person_off_outlined,
      _ => Icons.event_available_outlined,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );
    final secColor = sectionColor(sectionEnum);
    final secBg = sectionBg(sectionEnum);

    final inTime = _fmtTime(item.reservedFor);
    final outTime = item.checkOut != null ? _fmtTime(item.checkOut!) : null;
    final dur = item.checkOut != null ? item.checkOut!.difference(item.reservedFor).inMinutes : null;
    final durLabel = dur != null
        ? (dur >= 60 ? '${(dur / 60).toStringAsFixed(dur % 60 == 0 ? 0 : 1)}h' : '${dur}m')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                border: Border(right: BorderSide(color: statusColor.withOpacity(0.15))),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: statusColor.withOpacity(0.8)),
                  const SizedBox(height: 3),
                  Text(
                    inTime,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor, height: 1.2),
                  ),
                  if (outTime != null) ...[
                    const SizedBox(height: 1),
                    Icon(Icons.arrow_downward_rounded, size: 9, color: statusColor.withOpacity(0.5)),
                    Text(
                      outTime,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor, height: 1.2),
                    ),
                  ],
                  if (durLabel != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(durLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: secBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: secColor.withOpacity(0.25)),
                          ),
                          child: Text(
                            '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: secColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 11, color: TC.textMute),
                            const SizedBox(width: 3),
                            Text(
                              '${item.guestCount}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TC.textSec),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.customerName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TC.textPri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.phone != null) ...[
                          const Icon(Icons.phone_outlined, size: 11, color: TC.textMute),
                          const SizedBox(width: 3),
                          Text(item.phone!, style: const TextStyle(fontSize: 11, color: TC.textSec, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 10),
                        ],
                        const Icon(Icons.person_outline, size: 11, color: TC.textMute),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.createdByName,
                            style: const TextStyle(fontSize: 11, color: TC.textMute, fontWeight: FontWeight.w500),
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
                          const Icon(Icons.notes_rounded, size: 11, color: TC.textMute),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
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
}*/