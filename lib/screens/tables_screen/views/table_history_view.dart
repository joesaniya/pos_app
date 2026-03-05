import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

class HistoryView extends StatefulWidget {
  final TablesProvider prov;
  const HistoryView({super.key, required this.prov});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _scrollCtrl = ScrollController();

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

    final filtered = history.where((h) {
      if (_filterStatus != null && h.status != _filterStatus) return false;
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
                    return HistoryCard(
                      item: item as ReservationHistoryItem,
                      onTap: () => _showHistoryDetail(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showHistoryDetail(BuildContext context, ReservationHistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryDetailSheet(item: item),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HISTORY DETAIL SHEET
// ═════════════════════════════════════════════════════════════
class _HistoryDetailSheet extends StatelessWidget {
  final ReservationHistoryItem item;
  const _HistoryDetailSheet({required this.item});

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
      'no_show' => 'No Show',
      _ => isPast ? 'Completed' : 'Upcoming',
    };
    final statusEmoji = switch (item.status) {
      'seated' => '🍽️',
      'cancelled' => '✖️',
      'no_show' => '👻',
      _ => isPast ? '✅' : '📅',
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );

    final isCancelledOrNoShow =
        item.status == 'cancelled' || item.status == 'no_show';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        statusEmoji,
                        style: const TextStyle(fontSize: 24),
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
                                '$statusEmoji $statusLabel',
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // ── Guest Details ─────────────────────
                  _SectionLabel('👤 Guest Details'),
                  const SizedBox(height: 8),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: '👤',
                        label: 'Name',
                        value: item.customerName,
                      ),
                      _InfoDivider(),
                      _InfoRow(
                        icon: '📱',
                        label: 'Phone',
                        value: item.phone ?? 'Not provided',
                      ),
                      _InfoDivider(),
                      _InfoRow(
                        icon: '👥',
                        label: 'Party Size',
                        value:
                            '${item.guestCount} guest${item.guestCount != 1 ? 's' : ''}',
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        _InfoDivider(),
                        _InfoRow(
                          icon: '📝',
                          label: 'Special Notes',
                          value: item.notes!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Reservation Info ──────────────────
                  _SectionLabel('📅 Reservation Information'),
                  const SizedBox(height: 8),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: '🏷️',
                        label: 'Table',
                        value:
                            'Table ${item.tableNumber.toString().padLeft(2, '0')} — ${sectionEnum.label}',
                      ),
                      _InfoDivider(),
                      _InfoRow(
                        icon: '📅',
                        label: 'Date',
                        value: _fmtDateFull(item.reservedFor),
                      ),
                      _InfoDivider(),
                      _InfoRow(
                        icon: '🟢',
                        label: 'Check-in',
                        value: _fmtTime(item.reservedFor),
                      ),
                      if (item.checkOut != null) ...[
                        _InfoDivider(),
                        _InfoRow(
                          icon: '🔴',
                          label: 'Check-out',
                          value: _fmtTime(item.checkOut!),
                        ),
                        _InfoDivider(),
                        _InfoRow(
                          icon: '⏱️',
                          label: 'Duration',
                          value: _fmtDuration(item.reservedFor, item.checkOut!),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Activity Log ──────────────────────
                  _SectionLabel('🗂️ Activity Log'),
                  const SizedBox(height: 8),
                  _ActivityTimeline(item: item),
                  const SizedBox(height: 16),

                  // ── Cancellation / No-Show detail ─────
                  if (isCancelledOrNoShow) ...[
                    _CancellationCard(item: item, statusColor: statusColor),
                    const SizedBox(height: 16),
                  ],
                ],
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

  static String _fmtDateFull(DateTime dt) {
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
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _fmtDuration(DateTime from, DateTime to) {
    final mins = to.difference(from).inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ─────────────────────────────────────────────────────────────
//  ACTIVITY TIMELINE
// ─────────────────────────────────────────────────────────────
class _ActivityTimeline extends StatelessWidget {
  final ReservationHistoryItem item;
  const _ActivityTimeline({required this.item});

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: TC.surfaceWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
      ),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final idx = entry.key;
          final event = entry.value;
          final isLast = idx == events.length - 1;
          return _TimelineRow(event: event, isLast: isLast);
        }).toList(),
      ),
    );
  }

  List<_TimelineEvent> _buildEvents() {
    final events = <_TimelineEvent>[];

    // 1. Reservation created
    events.add(
      _TimelineEvent(
        emoji: '📅',
        title: 'Reservation Created',
        subtitle: 'By ${item.createdByName}',
        time: item.createdAt,
        color: TC.reserved,
      ),
    );

    // 2. Check-in (if applicable)
    if (item.checkIn != null) {
      events.add(
        _TimelineEvent(
          emoji: '🍽️',
          title: 'Guest Checked In',
          subtitle:
              'Table ${item.tableNumber.toString().padLeft(2, '0')} occupied',
          time: item.checkIn!,
          color: TC.available,
        ),
      );
    }

    // 3. Cancellation / No-show / Completed
    if (item.status == 'cancelled') {
      // Use updatedAt if available, else estimate from reservedFor
      final cancelTime = item.checkOut ?? item.reservedFor;
      events.add(
        _TimelineEvent(
          emoji: '✖️',
          title: 'Reservation Cancelled',
          subtitle: item.cancelledByName != null
              ? 'By ${item.cancelledByName}'
              : 'Cancelled by staff',
          time: cancelTime,
          color: TC.occupied,
          highlighted: true,
        ),
      );
    } else if (item.status == 'no_show') {
      final noShowTime =
          item.checkOut ?? item.reservedFor.add(const Duration(hours: 1));
      events.add(
        _TimelineEvent(
          emoji: '👻',
          title: 'Marked as No Show',
          subtitle: item.cancelledByName != null
              ? 'By ${item.cancelledByName}'
              : 'Guest never arrived',
          time: noShowTime,
          color: TC.cleaning,
          highlighted: true,
        ),
      );
    } else if (item.status == 'seated') {
      // Still seated or completed without explicit check-out
      events.add(
        _TimelineEvent(
          emoji: '✅',
          title: 'Guest Seated',
          subtitle: 'Currently at table',
          time: item.checkIn ?? item.reservedFor,
          color: TC.available,
        ),
      );
    } else if (item.checkOut != null &&
        item.checkOut!.isBefore(DateTime.now())) {
      events.add(
        _TimelineEvent(
          emoji: '✅',
          title: 'Visit Completed',
          subtitle: 'Guest checked out',
          time: item.checkOut!,
          color: const Color(0xFF9CA3AF),
        ),
      );
    }

    return events;
  }
}

class _TimelineEvent {
  final String emoji, title, subtitle;
  final DateTime time;
  final Color color;
  final bool highlighted;

  const _TimelineEvent({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    this.highlighted = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  const _TimelineRow({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dot + line ─────────────────────────────────
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: event.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    event.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              if (!isLast) Container(width: 2, height: 28, color: TC.divider),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // ── Content ────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Container(
              padding: event.highlighted
                  ? const EdgeInsets.all(10)
                  : EdgeInsets.zero,
              decoration: event.highlighted
                  ? BoxDecoration(
                      color: event.color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: event.color.withOpacity(0.2)),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: event.highlighted ? event.color : TC.textPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: const TextStyle(fontSize: 11, color: TC.textSec),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDateTime(event.time),
                    style: TextStyle(
                      fontSize: 10,
                      color: TC.textMute,
                      fontWeight: event.highlighted
                          ? FontWeight.w700
                          : FontWeight.w500,
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

  static String _fmtDateTime(DateTime dt) {
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
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h12:$m $s';
  }
}

// ─────────────────────────────────────────────────────────────
//  CANCELLATION DETAIL CARD
// ─────────────────────────────────────────────────────────────
class _CancellationCard extends StatelessWidget {
  final ReservationHistoryItem item;
  final Color statusColor;
  const _CancellationCard({required this.item, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final isNoShow = item.status == 'no_show';
    final title = isNoShow ? 'No-Show Details' : 'Cancellation Details';
    final emoji = isNoShow ? '👻' : '✖️';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            bgColor: Colors.white,
            children: [
              _InfoRow(
                icon: '🧑‍💼',
                label: isNoShow ? 'Recorded by' : 'Cancelled by',
                value: item.cancelledByName ?? item.updatedByName ?? 'Staff',
              ),
              _InfoDivider(),
              _InfoRow(
                icon: '🕐',
                label: isNoShow ? 'Recorded at' : 'Cancelled at',
                value: item.cancelledAt != null
                    ? _fmtDateTime(item.cancelledAt!)
                    : '—',
              ),
              if (!isNoShow && item.cancellationReason != null) ...[
                _InfoDivider(),
                _InfoRow(
                  icon: '📋',
                  label: 'Reason',
                  value: item.cancellationReason!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ℹ️', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNoShow
                        ? 'The guest made a reservation but never arrived. '
                              'The table was freed and the booking recorded as no-show.'
                        : 'This reservation was cancelled and the table '
                              'was made available for new bookings.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: TC.textSec,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDateTime(DateTime dt) {
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
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h12:$m $s';
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

// ─────────────────────────────────────────────────────────────
//  CUSTOM DATE RANGE PICKER
// ─────────────────────────────────────────────────────────────
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
  late DateTime _viewMonth;
  DateTime? _from, _to;
  bool _selectingFrom = true;

  static const _presets = [
    ('Today', 0, 0),
    ('Next 7 days', 0, 6),
    ('Next 30 days', 0, 29),
    ('Next 60 days', 0, 59),
    ('This month', -1, -1),
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
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: TC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(
                    () => _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month - 1,
                    ),
                  ),
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
                  onTap: () => setState(
                    () => _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month + 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
    final startOffset = firstDay.weekday % 7;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
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

// ─────────────────────────────────────────────────────────────
//  SHARED REUSABLE WIDGETS
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

class HistoryCard extends StatelessWidget {
  final ReservationHistoryItem item;
  final VoidCallback? onTap;
  const HistoryCard({super.key, required this.item, this.onTap});

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                          const SizedBox(width: 4),
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

// ─────────────────────────────────────────────────────────────
//  TINY SHARED WIDGETS USED IN DETAIL SHEET
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: TC.textSec,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color? bgColor;
  const _InfoCard({required this.children, this.bgColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bgColor ?? TC.surfaceWarm,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TC.border),
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final String icon, label, value;
  const _InfoRow({
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

class _InfoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 16, color: TC.divider);
}
