import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/analytics_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM DATE RANGE PICKER
// ─────────────────────────────────────────────────────────────────────────────

class CustomDateRangePicker extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTimeRange> onDateRangeSelected;
  final Color primaryColor;

  const CustomDateRangePicker({
    Key? key,
    this.startDate,
    this.endDate,
    required this.onDateRangeSelected,
    this.primaryColor = const Color(0xFF7C3AED),
  }) : super(key: key);

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
    Color primaryColor = const Color(0xFF7C3AED),
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _DateRangePickerDialog(
          initialStart: initialStart,
          initialEnd: initialEnd,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  @override
  Widget build(BuildContext context) {
    final start = widget.startDate;
    final end = widget.endDate;
    final fmt = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: () async {
        final result = await CustomDateRangePicker.show(
          context,
          initialStart: start,
          initialEnd: end,
          primaryColor: widget.primaryColor,
        );
        if (result != null) widget.onDateRangeSelected(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.primaryColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.primaryColor,
                    widget.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: widget.primaryColor.withOpacity(0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  start != null && end != null
                      ? '${fmt.format(start)} – ${fmt.format(end)}'
                      : 'Select range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: start != null
                        ? const Color(0xFF1A1A2E)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: widget.primaryColor.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final Color primaryColor;

  const _DateRangePickerDialog({
    this.initialStart,
    this.initialEnd,
    required this.primaryColor,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog>
    with SingleTickerProviderStateMixin {
  late DateTime _viewMonth;
  DateTime? _start;
  DateTime? _end;
  bool _selectingEnd = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const _quickRanges = [
    ('Today', 0, 0),
    ('Yesterday', -1, -1),
    ('Last 7 days', -6, 0),
    ('Last 30 days', -29, 0),
    ('This month', -31, 0), // handled specially
    ('Last 3 months', -89, 0),
  ];

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _viewMonth = DateTime.now();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _applyQuickRange(String label, int startOffset, int endOffset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime s, e;
    if (label == 'This month') {
      s = DateTime(now.year, now.month, 1);
      e = today;
    } else {
      s = today.add(Duration(days: startOffset));
      e = today.add(Duration(days: endOffset));
    }
    setState(() {
      _start = s;
      _end = e;
      _selectingEnd = false;
    });
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (!_selectingEnd || _start == null) {
        _start = day;
        _end = null;
        _selectingEnd = true;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        _selectingEnd = false;
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  bool _isStart(DateTime day) => _start != null && _isSameDay(day, _start!);
  bool _isEnd(DateTime day) => _end != null && _isSameDay(day, _end!);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _prevMonth() => setState(() {
    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
  });

  List<Widget> _buildCalendarDays() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Widget> cells = [];

    // Empty leading cells
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_viewMonth.year, _viewMonth.month, d);
      final isStart = _isStart(day);
      final isEnd = _isEnd(day);
      final inRange = _isInRange(day);
      final isToday = _isSameDay(day, today);
      final isFuture = day.isAfter(today);

      cells.add(
        GestureDetector(
          onTap: isFuture ? null : () => _onDayTap(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: (isStart || isEnd)
                  ? LinearGradient(
                      colors: [
                        widget.primaryColor,
                        widget.primaryColor.withOpacity(0.75),
                      ],
                    )
                  : null,
              color: inRange
                  ? widget.primaryColor.withOpacity(0.12)
                  : isToday
                  ? widget.primaryColor.withOpacity(0.08)
                  : null,
              borderRadius: isStart
                  ? const BorderRadius.horizontal(left: Radius.circular(10))
                  : isEnd
                  ? const BorderRadius.horizontal(right: Radius.circular(10))
                  : inRange
                  ? BorderRadius.zero
                  : BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$d',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: (isStart || isEnd || isToday)
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: (isStart || isEnd)
                      ? Colors.white
                      : isFuture
                      ? Colors.grey.withOpacity(0.35)
                      : isToday
                      ? widget.primaryColor
                      : const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final monthFmt = DateFormat('MMMM yyyy');
    final canConfirm = _start != null && _end != null;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFD),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.primaryColor,
                      widget.primaryColor.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.date_range_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Select Date Range',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeaderDateChip(
                          label: 'From',
                          date: _start,
                          isActive: !_selectingEnd,
                          color: widget.primaryColor,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                        _HeaderDateChip(
                          label: 'To',
                          date: _end,
                          isActive: _selectingEnd,
                          color: widget.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Quick ranges ────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickRanges.map((r) {
                    final (label, startOff, endOff) = r;
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    late DateTime qs, qe;
                    if (label == 'This month') {
                      qs = DateTime(now.year, now.month, 1);
                      qe = today;
                    } else {
                      qs = today.add(Duration(days: startOff));
                      qe = today.add(Duration(days: endOff));
                    }
                    final isActive =
                        _start != null &&
                        _end != null &&
                        _isSameDay(_start!, qs) &&
                        _isSameDay(_end!, qe);

                    return GestureDetector(
                      onTap: () => _applyQuickRange(label, startOff, endOff),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? widget.primaryColor
                              : widget.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? widget.primaryColor
                                : widget.primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : widget.primaryColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEEEEF6)),

              // ── Calendar ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Month navigation
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            monthFmt.format(_viewMonth),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Weekday headers
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 7,
                      childAspectRatio: 1.1,
                      children:
                          ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                              .map(
                                (d) => Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: widget.primaryColor.withOpacity(
                                        0.5,
                                      ),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    // Day grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 7,
                      childAspectRatio: 1.1,
                      children: _buildCalendarDays(),
                    ),
                  ],
                ),
              ),

              // ── Footer buttons ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _start = null;
                            _end = null;
                            _selectingEnd = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Clear',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B6B86),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: canConfirm
                            ? () => Navigator.pop(
                                context,
                                DateTimeRange(start: _start!, end: _end!),
                              )
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: canConfirm
                                ? LinearGradient(
                                    colors: [
                                      widget.primaryColor,
                                      widget.primaryColor.withOpacity(0.75),
                                    ],
                                  )
                                : null,
                            color: canConfirm ? null : const Color(0xFFEAEAF4),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: canConfirm
                                ? [
                                    BoxShadow(
                                      color: widget.primaryColor.withOpacity(
                                        0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            canConfirm ? 'Apply Range' : 'Select Both Dates',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: canConfirm
                                  ? Colors.white
                                  : const Color(0xFFAAABBB),
                            ),
                          ),
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

class _HeaderDateChip extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isActive;
  final Color color;

  const _HeaderDateChip({
    required this.label,
    required this.date,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yy');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isActive ? color : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date != null ? fmt.format(date!) : 'Not set',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isActive ? color : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER / SKELETON HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 10,
  });
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFFEEEEF6),
            Color(0xFFF8F8FF),
            Color(0xFFEEEEF6),
          ],
        ),
      ),
    ),
  );
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.02),
      padding: EdgeInsets.all(w * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: w * 0.4, height: 18, radius: 8),
                  const SizedBox(height: 6),
                  _ShimmerBox(width: w * 0.28, height: 12, radius: 6),
                ],
              ),
              _ShimmerBox(width: w * 0.28, height: 38, radius: 12),
            ],
          ),
          SizedBox(height: w * 0.05),
          _ShimmerBox(width: double.infinity, height: 42, radius: 12),
          SizedBox(height: w * 0.05),
          Row(
            children: [
              for (int i = 0; i < 2; i++) ...[
                Expanded(
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: w * 0.28,
                    radius: 14,
                  ),
                ),
                if (i == 0) SizedBox(width: w * 0.03),
              ],
            ],
          ),
          SizedBox(height: w * 0.03),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: w * 0.22,
                    radius: 14,
                  ),
                ),
                if (i < 2) SizedBox(width: w * 0.03),
              ],
            ],
          ),
          SizedBox(height: w * 0.05),
          _ShimmerBox(width: double.infinity, height: w * 0.65, radius: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENHANCED REVENUE ANALYTICS
//  Real data from AnalyticsProvider. Role-gated: admin/system/owner/manager.
// ─────────────────────────────────────────────────────────────────────────────

class EnhancedRevenueAnalytics extends StatefulWidget {
  /// Set true on first open while provider is loading, false once data ready.
  /// Widget handles its own per-period shimmer internally after that.
  final bool isLoading;

  const EnhancedRevenueAnalytics({Key? key, this.isLoading = false})
    : super(key: key);

  @override
  State<EnhancedRevenueAnalytics> createState() =>
      _EnhancedRevenueAnalyticsState();
}

class _EnhancedRevenueAnalyticsState extends State<EnhancedRevenueAnalytics>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _reAnimate() {
    _animCtrl.reset();
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    // ── Skeleton on first load ────────────────────────────────────────────
    if (widget.isLoading) return const _AnalyticsSkeleton();

    return Consumer<AnalyticsProvider>(
      builder: (context, prov, _) {
        // ── Role gate — silently hide for non-privileged roles ────────────
        if (!prov.hasAccess) return const SizedBox.shrink();

        // ── Full skeleton while provider is fetching ──────────────────────
        if (prov.isLoading) return const _AnalyticsSkeleton();

        final size = MediaQuery.of(context).size;
        final stats = prov.currentStats;

        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.width * 0.02,
              ),
              padding: EdgeInsets.all(size.width * 0.05),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadiusXLarge,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, prov),
                  SizedBox(height: size.width * 0.04),
                  _buildPeriodSelector(context, prov),
                  SizedBox(height: size.width * 0.05),
                  _buildMetricCards(context, stats),
                  SizedBox(height: size.width * 0.05),
                  _buildChart(context, prov, stats),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AnalyticsProvider prov) {
    // Always use explicit .toLocal() to ensure correct device timezone
    final now = DateTime.now().toLocal();
    final currentDateStr = DateFormat('dd MMM').format(now);

    final periodLabel = switch (prov.selectedPeriod) {
      'Monthly' => DateFormat('MMMM yyyy').format(now),
      'Yearly' => now.year.toString(),
      _ => () {
        // Calculate week start (Monday) in local timezone
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekStartStr = DateFormat('dd MMM').format(weekStart);
        // Display both week start and current date for clarity
        // return 'Week of $weekStartStr (Today: $currentDateStr)';
        return 'Week of  $currentDateStr';
      }(),
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue Analytics',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, 22),
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                periodLabel,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, 12),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Refresh button
        GestureDetector(
          onTap: () async {
            await prov.refresh();
            _reAnimate();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: ResponsiveUtils.getFontSize(context, 20),
            ),
          ),
        ),
      ],
    );
  }

  // ── Period selector ──────────────────────────────────────────────────────
  Widget _buildPeriodSelector(BuildContext context, AnalyticsProvider prov) {
    const periods = ['Weekly', 'Monthly', 'Yearly'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = prov.selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() => _touchedIndex = null);
                await prov.setPeriod(period);
                _reAnimate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.82),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusMedium,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: ResponsiveUtils.getFontSize(context, 13),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Metric cards — 5 real metrics ────────────────────────────────────────
  Widget _buildMetricCards(BuildContext context, AnalyticsPeriodStats stats) {
    final w = MediaQuery.of(context).size.width;
    final spacing = w * 0.03;

    final growthPositive = stats.growthRate >= 0;
    final growthLabel =
        '${growthPositive ? '+' : ''}${stats.growthRate.toStringAsFixed(1)}%';

    // Top row: Total Revenue (large) + Order Count
    // Bottom row: Average + Highest + Growth (3 equal)
    return Column(
      children: [
        // ── Row 1: two big cards ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _MetricCard(
                icon: Icons.currency_rupee_rounded,
                label: 'Total Revenue',
                value: _fmtCurrency(stats.totalRevenue),
                color: AppColors.primary,
                isLarge: true,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: 2,
              child: _MetricCard(
                icon: Icons.receipt_long_rounded,
                label: 'Order Count',
                value: stats.orderCount.toString(),
                color: AppColors.info,
                isLarge: true,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        // ── Row 2: three equal cards ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.analytics_outlined,
                label: 'Average',
                value: _fmtCurrency(stats.averageRevenue),
                color: AppColors.success,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _MetricCard(
                icon: Icons.emoji_events_rounded,
                label: 'Highest',
                value: _fmtCurrency(stats.highestRevenue),
                color: AppColors.warning,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _MetricCard(
                icon: growthPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                label: 'Growth',
                value: growthLabel,
                color: growthPositive
                    ? AppColors.success
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Chart — real data from provider ─────────────────────────────────────
  Widget _buildChart(
    BuildContext context,
    AnalyticsProvider prov,
    AnalyticsPeriodStats stats,
  ) {
    final size = MediaQuery.of(context).size;
    final chartHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: size.width * 0.65,
      tablet: size.width * 0.4,
      desktop: size.width * 0.25,
    );

    final points = stats.chartPoints;

    // Empty state
    if (points.isEmpty || stats.totalRevenue == 0) {
      return _buildEmptyChart(context, chartHeight, prov.selectedPeriod);
    }

    // Convert to FlSpot — x = index, y = revenue in ₹
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
        .toList();

    final revenues = points.map((p) => p.revenue).toList();
    final maxY = revenues.reduce(math.max);
    final minY = revenues.reduce(math.min);
    final yPad = (maxY - minY) * 0.25;
    final chartMaxY = maxY + yPad;
    final chartMinY = math.max(0.0, minY - yPad * 0.5);
    final yInterval = ((chartMaxY - chartMinY) / 4).clamp(1.0, double.infinity);

    // Show every label for weekly (7), every 5th for monthly, every for yearly (12)
    final period = prov.selectedPeriod;
    int labelInterval = switch (period) {
      'Monthly' => 5,
      _ => 1,
    };

    // For monthly with many points, reduce dots
    final showDots = period != 'Monthly';

    final growthUp = stats.growthRate >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${prov.selectedPeriod} Trend',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                // Dynamic growth pill
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.028,
                    vertical: size.width * 0.013,
                  ),
                  decoration: BoxDecoration(
                    color: growthUp
                        ? AppColors.success.withOpacity(0.12)
                        : const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: growthUp
                          ? AppColors.success.withOpacity(0.25)
                          : const Color(0xFFDC2626).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growthUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: growthUp
                            ? AppColors.success
                            : const Color(0xFFDC2626),
                        size: ResponsiveUtils.getFontSize(context, 11),
                      ),
                      SizedBox(width: size.width * 0.01),
                      Text(
                        '${growthUp ? '+' : ''}${stats.growthRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: growthUp
                              ? AppColors.success
                              : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveUtils.getFontSize(context, 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: size.width * 0.04),
          SizedBox(
            height: chartHeight,
            child: LineChart(
              LineChartData(
                clipData: FlClipData.all(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex = response?.lineBarSpots?.isNotEmpty == true
                          ? response!.lineBarSpots!.first.spotIndex
                          : null;
                    });
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final idx = s.spotIndex;
                        final pt = idx < points.length ? points[idx] : null;
                        return LineTooltipItem(
                          '${pt?.label ?? ''}\n₹${_fmtCurrency(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.12),
                    strokeWidth: 1,
                    dashArray: [6, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: size.width * 0.14,
                      interval: yInterval,
                      getTitlesWidget: (value, _) {
                        final label = _fmtAxisY(value);
                        return Padding(
                          padding: EdgeInsets.only(right: size.width * 0.015),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: ResponsiveUtils.getFontSize(context, 9),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: size.width * 0.08,
                      interval: labelInterval.toDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox();
                        }
                        // For monthly: show every labelInterval-th
                        if (period == 'Monthly' && idx % labelInterval != 0) {
                          return const SizedBox();
                        }
                        final isTouched = _touchedIndex == idx;
                        return Padding(
                          padding: EdgeInsets.only(top: size.width * 0.018),
                          child: Text(
                            points[idx].label,
                            style: TextStyle(
                              color: isTouched
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: ResponsiveUtils.getFontSize(context, 9),
                              fontWeight: isTouched
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.32,
                    color: const Color(0xFF8B5CF6),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: showDots,
                      getDotPainter: (spot, _, __, idx) {
                        final isTouched = _touchedIndex == idx;
                        return FlDotCirclePainter(
                          radius: isTouched ? 7 : 4,
                          color: Colors.white,
                          strokeWidth: isTouched ? 3 : 2,
                          strokeColor: const Color(0xFF8B5CF6),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.28),
                          const Color(0xFFA78BFA).withOpacity(0.16),
                          const Color(0xFFDDD6FE).withOpacity(0.07),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.35, 0.7, 1.0],
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

  // ── Empty chart state ─────────────────────────────────────────────────────
  Widget _buildEmptyChart(BuildContext context, double height, String period) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: AppColors.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 10),
          Text(
            'No orders yet this ${period.toLowerCase().replaceAll('ly', '')}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 13),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Revenue will appear here once orders are placed',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 11),
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  /// Format currency value for metric cards (₹1.2L, ₹45.3K, ₹850)
  static String _fmtCurrency(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  /// Format Y-axis values (₹0, ₹5K, ₹1L etc.)
  static String _fmtAxisY(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE METRIC CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(w * 0.035),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: color,
              size: ResponsiveUtils.getFontSize(context, isLarge ? 18 : 16),
            ),
          ),
          SizedBox(height: w * 0.02),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 10),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(
                  context,
                  isLarge ? 18 : 15,
                ),
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'dart:math' as math;
// import 'package:intl/intl.dart';
// import 'package:pos_app/screens/utils/app_sizes.dart';
// import 'package:pos_app/screens/utils/responsive_utils.dart';
// import 'package:pos_app/theme/app_colors.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// //  CUSTOM DATE RANGE PICKER
// // ─────────────────────────────────────────────────────────────────────────────

// class CustomDateRangePicker extends StatefulWidget {
//   final DateTime? startDate;
//   final DateTime? endDate;
//   final ValueChanged<DateTimeRange> onDateRangeSelected;
//   final Color primaryColor;

//   const CustomDateRangePicker({
//     Key? key,
//     this.startDate,
//     this.endDate,
//     required this.onDateRangeSelected,
//     this.primaryColor = const Color(0xFF7C3AED),
//   }) : super(key: key);

//   static Future<DateTimeRange?> show(
//     BuildContext context, {
//     DateTime? initialStart,
//     DateTime? initialEnd,
//     Color primaryColor = const Color(0xFF7C3AED),
//   }) {
//     return showDialog<DateTimeRange>(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.5),
//       builder: (_) => Dialog(
//         backgroundColor: Colors.transparent,
//         insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//         child: _DateRangePickerDialog(
//           initialStart: initialStart,
//           initialEnd: initialEnd,
//           primaryColor: primaryColor,
//         ),
//       ),
//     );
//   }

//   @override
//   State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
// }

// class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
//   @override
//   Widget build(BuildContext context) {
//     final start = widget.startDate;
//     final end = widget.endDate;
//     final fmt = DateFormat('dd MMM yyyy');

//     return GestureDetector(
//       onTap: () async {
//         final result = await CustomDateRangePicker.show(
//           context,
//           initialStart: start,
//           initialEnd: end,
//           primaryColor: widget.primaryColor,
//         );
//         if (result != null) widget.onDateRangeSelected(result);
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: widget.primaryColor.withOpacity(0.25), width: 1.5),
//           boxShadow: [
//             BoxShadow(
//               color: widget.primaryColor.withOpacity(0.08),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(7),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.7)],
//                 ),
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
//             ),
//             const SizedBox(width: 10),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Date Range',
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w700,
//                     color: widget.primaryColor.withOpacity(0.6),
//                     letterSpacing: 0.8,
//                   ),
//                 ),
//                 const SizedBox(height: 1),
//                 Text(
//                   start != null && end != null
//                       ? '${fmt.format(start)} – ${fmt.format(end)}'
//                       : 'Select range',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                     color: start != null ? const Color(0xFF1A1A2E) : Colors.grey,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(width: 8),
//             Icon(Icons.keyboard_arrow_down_rounded,
//                 color: widget.primaryColor.withOpacity(0.5), size: 18),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _DateRangePickerDialog extends StatefulWidget {
//   final DateTime? initialStart;
//   final DateTime? initialEnd;
//   final Color primaryColor;

//   const _DateRangePickerDialog({
//     this.initialStart,
//     this.initialEnd,
//     required this.primaryColor,
//   });

//   @override
//   State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
// }

// class _DateRangePickerDialogState extends State<_DateRangePickerDialog>
//     with SingleTickerProviderStateMixin {
//   late DateTime _viewMonth;
//   DateTime? _start;
//   DateTime? _end;
//   bool _selectingEnd = false;
//   late AnimationController _animController;
//   late Animation<double> _scaleAnim;
//   late Animation<double> _fadeAnim;

//   static const _quickRanges = [
//     ('Today', 0, 0),
//     ('Yesterday', -1, -1),
//     ('Last 7 days', -6, 0),
//     ('Last 30 days', -29, 0),
//     ('This month', -31, 0), // handled specially
//     ('Last 3 months', -89, 0),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _start = widget.initialStart;
//     _end = widget.initialEnd;
//     _viewMonth = DateTime.now();
//     _animController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
//       CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
//     );
//     _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animController, curve: Curves.easeOut),
//     );
//     _animController.forward();
//   }

//   @override
//   void dispose() {
//     _animController.dispose();
//     super.dispose();
//   }

//   void _applyQuickRange(String label, int startOffset, int endOffset) {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     DateTime s, e;
//     if (label == 'This month') {
//       s = DateTime(now.year, now.month, 1);
//       e = today;
//     } else {
//       s = today.add(Duration(days: startOffset));
//       e = today.add(Duration(days: endOffset));
//     }
//     setState(() {
//       _start = s;
//       _end = e;
//       _selectingEnd = false;
//     });
//   }

//   void _onDayTap(DateTime day) {
//     setState(() {
//       if (!_selectingEnd || _start == null) {
//         _start = day;
//         _end = null;
//         _selectingEnd = true;
//       } else {
//         if (day.isBefore(_start!)) {
//           _end = _start;
//           _start = day;
//         } else {
//           _end = day;
//         }
//         _selectingEnd = false;
//       }
//     });
//   }

//   bool _isInRange(DateTime day) {
//     if (_start == null || _end == null) return false;
//     return day.isAfter(_start!) && day.isBefore(_end!);
//   }

//   bool _isStart(DateTime day) => _start != null && _isSameDay(day, _start!);
//   bool _isEnd(DateTime day) => _end != null && _isSameDay(day, _end!);
//   bool _isSameDay(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;

//   void _prevMonth() => setState(() {
//         _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
//       });

//   void _nextMonth() => setState(() {
//         _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
//       });

//   List<Widget> _buildCalendarDays() {
//     final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
//     final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
//     final startWeekday = firstDay.weekday % 7; // 0 = Sunday
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);

//     List<Widget> cells = [];

//     // Empty leading cells
//     for (int i = 0; i < startWeekday; i++) {
//       cells.add(const SizedBox());
//     }

//     for (int d = 1; d <= daysInMonth; d++) {
//       final day = DateTime(_viewMonth.year, _viewMonth.month, d);
//       final isStart = _isStart(day);
//       final isEnd = _isEnd(day);
//       final inRange = _isInRange(day);
//       final isToday = _isSameDay(day, today);
//       final isFuture = day.isAfter(today);

//       cells.add(
//         GestureDetector(
//           onTap: isFuture ? null : () => _onDayTap(day),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 150),
//             decoration: BoxDecoration(
//               gradient: (isStart || isEnd)
//                   ? LinearGradient(
//                       colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.75)],
//                     )
//                   : null,
//               color: inRange
//                   ? widget.primaryColor.withOpacity(0.12)
//                   : isToday
//                       ? widget.primaryColor.withOpacity(0.08)
//                       : null,
//               borderRadius: isStart
//                   ? const BorderRadius.horizontal(left: Radius.circular(10))
//                   : isEnd
//                       ? const BorderRadius.horizontal(right: Radius.circular(10))
//                       : inRange
//                           ? BorderRadius.zero
//                           : BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Text(
//                 '$d',
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: (isStart || isEnd || isToday)
//                       ? FontWeight.w800
//                       : FontWeight.w500,
//                   color: (isStart || isEnd)
//                       ? Colors.white
//                       : isFuture
//                           ? Colors.grey.withOpacity(0.35)
//                           : isToday
//                               ? widget.primaryColor
//                               : const Color(0xFF1A1A2E),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }

//     return cells;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final monthFmt = DateFormat('MMMM yyyy');
//     final canConfirm = _start != null && _end != null;

//     return FadeTransition(
//       opacity: _fadeAnim,
//       child: ScaleTransition(
//         scale: _scaleAnim,
//         child: Container(
//           decoration: BoxDecoration(
//             color: const Color(0xFFFAFAFD),
//             borderRadius: BorderRadius.circular(24),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.18),
//                 blurRadius: 40,
//                 offset: const Offset(0, 16),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // ── Header ──────────────────────────────────────────
//               Container(
//                 padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.75)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: const Icon(Icons.date_range_rounded,
//                               color: Colors.white, size: 18),
//                         ),
//                         const SizedBox(width: 10),
//                         const Text(
//                           'Select Date Range',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w800,
//                             color: Colors.white,
//                             letterSpacing: -0.3,
//                           ),
//                         ),
//                         const Spacer(),
//                         GestureDetector(
//                           onTap: () => Navigator.pop(context),
//                           child: Container(
//                             padding: const EdgeInsets.all(6),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: const Icon(Icons.close_rounded,
//                                 color: Colors.white, size: 16),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 14),
//                     Row(
//                       children: [
//                         _HeaderDateChip(
//                           label: 'From',
//                           date: _start,
//                           isActive: !_selectingEnd,
//                           color: widget.primaryColor,
//                         ),
//                         const Padding(
//                           padding: EdgeInsets.symmetric(horizontal: 8),
//                           child: Icon(Icons.arrow_forward_rounded,
//                               color: Colors.white70, size: 16),
//                         ),
//                         _HeaderDateChip(
//                           label: 'To',
//                           date: _end,
//                           isActive: _selectingEnd,
//                           color: widget.primaryColor,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),

//               // ── Quick ranges ────────────────────────────────────
//               Container(
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//                 child: Wrap(
//                   spacing: 6,
//                   runSpacing: 6,
//                   children: _quickRanges.map((r) {
//                     final (label, startOff, endOff) = r;
//                     final now = DateTime.now();
//                     final today = DateTime(now.year, now.month, now.day);
//                     late DateTime qs, qe;
//                     if (label == 'This month') {
//                       qs = DateTime(now.year, now.month, 1);
//                       qe = today;
//                     } else {
//                       qs = today.add(Duration(days: startOff));
//                       qe = today.add(Duration(days: endOff));
//                     }
//                     final isActive = _start != null &&
//                         _end != null &&
//                         _isSameDay(_start!, qs) &&
//                         _isSameDay(_end!, qe);

//                     return GestureDetector(
//                       onTap: () => _applyQuickRange(label, startOff, endOff),
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 150),
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 12, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: isActive
//                               ? widget.primaryColor
//                               : widget.primaryColor.withOpacity(0.08),
//                           borderRadius: BorderRadius.circular(20),
//                           border: Border.all(
//                             color: isActive
//                                 ? widget.primaryColor
//                                 : widget.primaryColor.withOpacity(0.2),
//                           ),
//                         ),
//                         child: Text(
//                           label,
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: isActive
//                                 ? Colors.white
//                                 : widget.primaryColor,
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ),

//               const Divider(height: 1, color: Color(0xFFEEEEF6)),

//               // ── Calendar ────────────────────────────────────────
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//                 child: Column(
//                   children: [
//                     // Month navigation
//                     Row(
//                       children: [
//                         GestureDetector(
//                           onTap: _prevMonth,
//                           child: Container(
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color: widget.primaryColor.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: Icon(Icons.chevron_left_rounded,
//                                 color: widget.primaryColor, size: 20),
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             monthFmt.format(_viewMonth),
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w800,
//                               color: Color(0xFF1A1A2E),
//                               letterSpacing: -0.3,
//                             ),
//                           ),
//                         ),
//                         GestureDetector(
//                           onTap: _nextMonth,
//                           child: Container(
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color: widget.primaryColor.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: Icon(Icons.chevron_right_rounded,
//                                 color: widget.primaryColor, size: 20),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     // Weekday headers
//                     GridView.count(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       crossAxisCount: 7,
//                       childAspectRatio: 1.1,
//                       children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
//                           .map((d) => Center(
//                                 child: Text(
//                                   d,
//                                   style: TextStyle(
//                                     fontSize: 10,
//                                     fontWeight: FontWeight.w800,
//                                     color: widget.primaryColor.withOpacity(0.5),
//                                     letterSpacing: 0.5,
//                                   ),
//                                 ),
//                               ))
//                           .toList(),
//                     ),
//                     // Day grid
//                     GridView.count(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       crossAxisCount: 7,
//                       childAspectRatio: 1.1,
//                       children: _buildCalendarDays(),
//                     ),
//                   ],
//                 ),
//               ),

//               // ── Footer buttons ───────────────────────────────────
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             _start = null;
//                             _end = null;
//                             _selectingEnd = false;
//                           });
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(vertical: 13),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFF2F2F8),
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                           child: const Text(
//                             'Clear',
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFF6B6B86),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       flex: 2,
//                       child: GestureDetector(
//                         onTap: canConfirm
//                             ? () => Navigator.pop(
//                                 context,
//                                 DateTimeRange(start: _start!, end: _end!))
//                             : null,
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 200),
//                           padding: const EdgeInsets.symmetric(vertical: 13),
//                           decoration: BoxDecoration(
//                             gradient: canConfirm
//                                 ? LinearGradient(
//                                     colors: [
//                                       widget.primaryColor,
//                                       widget.primaryColor.withOpacity(0.75)
//                                     ],
//                                   )
//                                 : null,
//                             color: canConfirm
//                                 ? null
//                                 : const Color(0xFFEAEAF4),
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: canConfirm
//                                 ? [
//                                     BoxShadow(
//                                       color:
//                                           widget.primaryColor.withOpacity(0.35),
//                                       blurRadius: 12,
//                                       offset: const Offset(0, 6),
//                                     )
//                                   ]
//                                 : [],
//                           ),
//                           child: Text(
//                             canConfirm ? 'Apply Range' : 'Select Both Dates',
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w800,
//                               color: canConfirm
//                                   ? Colors.white
//                                   : const Color(0xFFAAABBB),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _HeaderDateChip extends StatelessWidget {
//   final String label;
//   final DateTime? date;
//   final bool isActive;
//   final Color color;

//   const _HeaderDateChip({
//     required this.label,
//     required this.date,
//     required this.isActive,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final fmt = DateFormat('dd MMM yy');
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: isActive
//             ? Colors.white
//             : Colors.white.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
//           width: 1.5,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             label.toUpperCase(),
//             style: TextStyle(
//               fontSize: 8,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 0.8,
//               color: isActive ? color : Colors.white70,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             date != null ? fmt.format(date!) : 'Not set',
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w800,
//               color: isActive ? color : Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  SHIMMER / SKELETON HELPERS
// // ─────────────────────────────────────────────────────────────────────────────

// class _ShimmerBox extends StatefulWidget {
//   final double width;
//   final double height;
//   final double radius;

//   const _ShimmerBox({
//     required this.width,
//     required this.height,
//     this.radius = 10,
//   });

//   @override
//   State<_ShimmerBox> createState() => _ShimmerBoxState();
// }

// class _ShimmerBoxState extends State<_ShimmerBox>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _anim;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..repeat(reverse: false);
//     _anim = Tween<double>(begin: -2, end: 2).animate(
//       CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _anim,
//       builder: (_, __) => Container(
//         width: widget.width,
//         height: widget.height,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(widget.radius),
//           gradient: LinearGradient(
//             begin: Alignment(_anim.value - 1, 0),
//             end: Alignment(_anim.value + 1, 0),
//             colors: const [
//               Color(0xFFEEEEF6),
//               Color(0xFFF8F8FF),
//               Color(0xFFEEEEF6),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Full skeleton layout that mirrors the real analytics card structure.
// class _AnalyticsSkeleton extends StatelessWidget {
//   const _AnalyticsSkeleton();

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final w = size.width;

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.02),
//       padding: EdgeInsets.all(w * 0.05),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 20,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header row
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 _ShimmerBox(width: w * 0.4, height: 18, radius: 8),
//                 const SizedBox(height: 6),
//                 _ShimmerBox(width: w * 0.28, height: 12, radius: 6),
//               ]),
//               _ShimmerBox(width: w * 0.28, height: 38, radius: 12),
//             ],
//           ),
//           SizedBox(height: w * 0.05),
//           // Period selector bar
//           _ShimmerBox(width: double.infinity, height: 40, radius: 12),
//           SizedBox(height: w * 0.05),
//           // 4 stat cards
//           Row(children: [
//             for (int i = 0; i < 4; i++) ...[
//               Expanded(
//                 child: _ShimmerBox(width: double.infinity, height: w * 0.24, radius: 14),
//               ),
//               if (i < 3) SizedBox(width: w * 0.03),
//             ],
//           ]),
//           SizedBox(height: w * 0.05),
//           // Chart area
//           _ShimmerBox(width: double.infinity, height: w * 0.65, radius: 16),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  ENHANCED REVENUE ANALYTICS (Redesigned chart matching the reference image)
// // ─────────────────────────────────────────────────────────────────────────────

// class EnhancedRevenueAnalytics extends StatefulWidget {
//   final DateTime? selectedDate;

//   /// When true shows the skeleton; when false (and data is non-null) shows content.
//   /// Pass true on first load until data arrives. Once data arrives pass false —
//   /// NEVER flip back to true for subsequent period-change fetches; the widget
//   /// handles its own per-period loading state internally.
//   final bool isLoading;

//   /// Optional real chart spots. When null the widget uses demo data.
//   final List<FlSpot>? chartSpots;

//   /// Optional real stats. When null the widget uses demo data.
//   final Map<String, double>? realStats;

//   const EnhancedRevenueAnalytics({
//     Key? key,
//     this.selectedDate,
//     this.isLoading = false,
//     this.chartSpots,
//     this.realStats,
//   }) : super(key: key);

//   @override
//   State<EnhancedRevenueAnalytics> createState() =>
//       _EnhancedRevenueAnalyticsState();
// }

// class _EnhancedRevenueAnalyticsState extends State<EnhancedRevenueAnalytics>
//     with SingleTickerProviderStateMixin {
//   String selectedPeriod = 'Weekly';
//   DateTimeRange? _customRange;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//   int? _touchedIndex;

//   /// True only during an internal period-switch fetch — never on initial open.
//   bool _periodSwitching = false;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );
//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
//     );
//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   void _changePeriod(String period) async {
//     setState(() {
//       selectedPeriod = period;
//       _touchedIndex = null;
//       _periodSwitching = true;
//     });
//     _animationController.reset();
//     // Brief artificial delay simulating a fast fetch / data swap.
//     // In real usage you'd await your provider call here then set false.
//     await Future.delayed(const Duration(milliseconds: 350));
//     if (!mounted) return;
//     setState(() => _periodSwitching = false);
//     _animationController.forward();
//   }

//   List<FlSpot> _getChartData() {
//     final seed = selectedPeriod.hashCode;
//     final random = math.Random(seed);
//     switch (selectedPeriod) {
//       case 'Weekly':
//         // Match the reference image's undulating pattern
//         return [
//           FlSpot(0, 5.0),
//           FlSpot(1, 5.6),
//           FlSpot(2, 3.2),
//           FlSpot(3, 5.4),
//           FlSpot(4, 5.5),
//           FlSpot(5, 4.2),
//           FlSpot(6, 5.3),
//         ];
//       case 'Monthly':
//         return List.generate(
//           30,
//           (i) => FlSpot(i.toDouble(), 2.5 + random.nextDouble() * 4),
//         );
//       case 'Yearly':
//         return List.generate(
//           12,
//           (i) => FlSpot(i.toDouble(), 4 + random.nextDouble() * 3.5),
//         );
//       case 'Custom':
//         return List.generate(
//           7,
//           (i) => FlSpot(i.toDouble(), 3 + random.nextDouble() * 4),
//         );
//       default:
//         return [];
//     }
//   }

//   String _getXAxisLabel(int index) {
//     switch (selectedPeriod) {
//       case 'Weekly':
//       case 'Custom':
//         const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//         return index < days.length ? days[index] : '';
//       case 'Monthly':
//         return index % 5 == 0 ? '${index + 1}' : '';
//       case 'Yearly':
//         const months = [
//           'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
//         ];
//         return index < months.length ? months[index] : '';
//       default:
//         return '';
//     }
//   }

//   double _getMaxX() {
//     switch (selectedPeriod) {
//       case 'Weekly':
//       case 'Custom':
//         return 6;
//       case 'Monthly':
//         return 29;
//       case 'Yearly':
//         return 11;
//       default:
//         return 6;
//     }
//   }

//   Map<String, dynamic> _getStatistics() {
//     final seed = selectedPeriod.hashCode + 1;
//     final random = math.Random(seed);
//     switch (selectedPeriod) {
//       case 'Weekly':
//         return {
//           'total': 28450.00,
//           'average': 4064.00,
//           'highest': 5600.00,
//           'growth': 12.5,
//         };
//       case 'Monthly':
//         return {
//           'total': 125400.00,
//           'average': 4180.00,
//           'highest': 6500.00,
//           'growth': 18.3,
//         };
//       case 'Yearly':
//         return {
//           'total': 1450000.00,
//           'average': 120833.00,
//           'highest': 145000.00,
//           'growth': 24.7,
//         };
//       case 'Custom':
//         return {
//           'total': 45000.00 + random.nextDouble() * 10000,
//           'average': 6428.00 + random.nextDouble() * 1000,
//           'highest': 8200.00 + random.nextDouble() * 2000,
//           'growth': 8.3 + random.nextDouble() * 8,
//         };
//       default:
//         return {'total': 0.0, 'average': 0.0, 'highest': 0.0, 'growth': 0.0};
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // ── Initial load: full skeleton immediately, never "no data" first ──────
//     if (widget.isLoading) return const _AnalyticsSkeleton();

//     final size = MediaQuery.of(context).size;
//     final stats = _getStatistics();

//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: SlideTransition(
//         position: _slideAnimation,
//         child: Container(
//           margin: EdgeInsets.symmetric(
//             horizontal: size.width * 0.04,
//             vertical: size.width * 0.02,
//           ),
//           padding: EdgeInsets.all(size.width * 0.05),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(AppSizes.borderRadiusXLarge),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.primary.withOpacity(0.08),
//                 blurRadius: 30,
//                 offset: const Offset(0, 10),
//                 spreadRadius: 2,
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(context),
//               SizedBox(height: size.width * 0.04),
//               _buildPeriodSelector(context),
//               SizedBox(height: size.width * 0.05),
//               // ── Stat cards: keep showing previous values during switch ──
//               _buildStatisticsCards(context, stats),
//               SizedBox(height: size.width * 0.05),
//               // ── Chart: shimmer only the chart area during period switch ──
//               _periodSwitching
//                   ? _ShimmerBox(
//                       width: double.infinity,
//                       height: size.width * 0.65,
//                       radius: 16,
//                     )
//                   : _buildChart(context),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader(BuildContext context) {
//     final fmt = DateFormat('dd MMM');
//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Revenue Analytics',
//                 style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 22),
//                   fontWeight: FontWeight.w900,
//                   color: AppColors.textPrimary,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//               SizedBox(height: MediaQuery.of(context).size.width * 0.01),
//               Text(
//                 selectedPeriod == 'Custom' && _customRange != null
//                     ? '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}'
//                     : 'Track your performance over time',
//                 style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 13),
//                   color: AppColors.textSecondary,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // Custom Date Range Picker Button
//         CustomDateRangePicker(
//           startDate: _customRange?.start,
//           endDate: _customRange?.end,
//           primaryColor: AppColors.primary,
//           onDateRangeSelected: (range) {
//             setState(() {
//               _customRange = range;
//               selectedPeriod = 'Custom';
//             });
//             _animationController.reset();
//             _animationController.forward();
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildPeriodSelector(BuildContext context) {
//     final periods = ['Weekly', 'Monthly', 'Yearly'];

//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F4F8),
//         borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//       ),
//       child: Row(
//         children: [
//           ...periods.map((period) {
//             final isSelected = selectedPeriod == period;
//             return Expanded(
//               child: GestureDetector(
//                 onTap: () => _changePeriod(period),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 250),
//                   curve: Curves.easeInOut,
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   decoration: BoxDecoration(
//                     gradient: isSelected
//                         ? LinearGradient(
//                             colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
//                           )
//                         : null,
//                     borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//                     boxShadow: isSelected
//                         ? [
//                             BoxShadow(
//                               color: AppColors.primary.withOpacity(0.35),
//                               blurRadius: 10,
//                               offset: const Offset(0, 4),
//                             ),
//                           ]
//                         : [],
//                   ),
//                   child: Text(
//                     period,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: isSelected ? Colors.white : AppColors.textSecondary,
//                       fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
//                       fontSize: ResponsiveUtils.getFontSize(context, 13),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }),
//           // Custom indicator
//           if (selectedPeriod == 'Custom')
//             Expanded(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 10),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
//                   ),
//                   borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
//                   boxShadow: [
//                     BoxShadow(
//                       color: AppColors.primary.withOpacity(0.35),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Text(
//                   'Custom',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w800,
//                     fontSize: ResponsiveUtils.getFontSize(context, 13),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatisticsCards(BuildContext context, Map<String, dynamic> stats) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
//           context,
//           mobile: 2,
//           tablet: 4,
//           desktop: 4,
//         );
//         final spacing = MediaQuery.of(context).size.width * 0.03;
//         final cardWidth =
//             (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

//         return Wrap(
//           spacing: spacing,
//           runSpacing: spacing,
//           children: [
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(context, 'Total Revenue',
//                   '₹${NumberFormat('#,##0').format(stats['total'])}',
//                   Icons.currency_rupee, AppColors.primary),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(context, 'Average',
//                   '₹${NumberFormat('#,##0').format(stats['average'])}',
//                   Icons.analytics, AppColors.success),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(context, 'Highest',
//                   '₹${NumberFormat('#,##0').format(stats['highest'])}',
//                   Icons.trending_up, AppColors.warning),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(context, 'Growth',
//                   '+${(stats['growth'] as double).toStringAsFixed(1)}%',
//                   Icons.arrow_upward, AppColors.info),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatCard(BuildContext context, String title, String value,
//       IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(AppSizes.paddingMedium),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [color.withOpacity(0.12), color.withOpacity(0.05)],
//         ),
//         borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//         border: Border.all(color: color.withOpacity(0.2), width: 1.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(AppSizes.paddingSmall),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: color,
//                 size: ResponsiveUtils.getFontSize(context, 18)),
//           ),
//           SizedBox(height: MediaQuery.of(context).size.width * 0.02),
//           Text(title,
//               style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 11),
//                   color: AppColors.textSecondary,
//                   fontWeight: FontWeight.w500)),
//           SizedBox(height: MediaQuery.of(context).size.width * 0.01),
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             alignment: Alignment.centerLeft,
//             child: Text(value,
//                 style: TextStyle(
//                     fontSize: ResponsiveUtils.getFontSize(context, 17),
//                     fontWeight: FontWeight.w900,
//                     color: color,
//                     letterSpacing: -0.3)),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildChart(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final chartHeight = ResponsiveUtils.getResponsiveValue(
//       context,
//       mobile: size.width * 0.65,
//       tablet: size.width * 0.4,
//       desktop: size.width * 0.25,
//     );

//     final spots = _getChartData();
//     final maxY = spots.map((s) => s.y).reduce(math.max);
//     final minY = spots.map((s) => s.y).reduce(math.min);
//     final yRange = maxY - minY;
//     final chartMaxY = (maxY + yRange * 0.3).ceilToDouble();
//     final chartMinY = math.max(0, minY - yRange * 0.2).floorToDouble();

//     // Y-axis labels matching reference image ($0, $2000, $4000, etc.)
//     final yInterval = ((chartMaxY - chartMinY) / 4).ceilToDouble();

//     return Container(
//       padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFAF8FF),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: AppColors.primary.withOpacity(0.1),
//           width: 1.5,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Chart header — matches reference exactly
//           Padding(
//             padding: const EdgeInsets.only(left: 4, bottom: 4),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '$selectedPeriod Trend',
//                   style: TextStyle(
//                     fontSize: ResponsiveUtils.getFontSize(context, 16),
//                     fontWeight: FontWeight.w800,
//                     color: AppColors.textPrimary,
//                     letterSpacing: -0.3,
//                   ),
//                 ),
//                 // "Trending Up" pill matching reference design
//                 Container(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: size.width * 0.03,
//                     vertical: size.width * 0.015,
//                   ),
//                   decoration: BoxDecoration(
//                     color: AppColors.success.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(
//                         color: AppColors.success.withOpacity(0.25)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.arrow_upward,
//                           color: AppColors.success,
//                           size: ResponsiveUtils.getFontSize(context, 12)),
//                       SizedBox(width: size.width * 0.01),
//                       Text(
//                         'Trending Up',
//                         style: TextStyle(
//                           color: AppColors.success,
//                           fontWeight: FontWeight.w700,
//                           fontSize: ResponsiveUtils.getFontSize(context, 11),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(height: size.width * 0.04),
//           SizedBox(
//             height: chartHeight,
//             child: LineChart(
//               LineChartData(
//                 clipData: FlClipData.all(),
//                 lineTouchData: LineTouchData(
//                   enabled: true,
//                   touchCallback: (event, response) {
//                     setState(() {
//                       if (response?.lineBarSpots != null &&
//                           response!.lineBarSpots!.isNotEmpty) {
//                         _touchedIndex =
//                             response.lineBarSpots!.first.spotIndex;
//                       } else {
//                         _touchedIndex = null;
//                       }
//                     });
//                   },
//                   touchTooltipData: LineTouchTooltipData(
//                     getTooltipColor: (_) => AppColors.primary,
//                     tooltipBorderRadius: BorderRadius.circular(12),
//                     tooltipPadding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 8),
//                     getTooltipItems: (spots) => spots
//                         .map((s) => LineTooltipItem(
//                               '₹${NumberFormat('#,##0').format(s.y * 1000)}',
//                               const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w800,
//                                 fontSize: 12,
//                               ),
//                             ))
//                         .toList(),
//                   ),
//                 ),
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                   horizontalInterval: yInterval > 0 ? yInterval : 1,
//                   getDrawingHorizontalLine: (value) => FlLine(
//                     color: Colors.grey.withOpacity(0.12),
//                     strokeWidth: 1,
//                     dashArray: [6, 4],
//                   ),
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: size.width * 0.13,
//                       interval: yInterval > 0 ? yInterval : 1,
//                       getTitlesWidget: (value, meta) {
//                         final label = value * 1000 >= 1000
//                             ? '\$${(value * 1000 / 1000).toStringAsFixed(0)}k'
//                             : '\$${(value * 1000).toInt()}';
//                         return Padding(
//                           padding: EdgeInsets.only(right: size.width * 0.02),
//                           child: Text(
//                             label,
//                             style: TextStyle(
//                               color: AppColors.textSecondary,
//                               fontSize: ResponsiveUtils.getFontSize(context, 9),
//                               fontWeight: FontWeight.w500,
//                             ),
//                             textAlign: TextAlign.right,
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: size.width * 0.08,
//                       interval: 1,
//                       getTitlesWidget: (value, meta) {
//                         final label = _getXAxisLabel(value.toInt());
//                         return label.isNotEmpty
//                             ? Padding(
//                                 padding: EdgeInsets.only(top: size.width * 0.02),
//                                 child: Text(
//                                   label,
//                                   style: TextStyle(
//                                     color: _touchedIndex == value.toInt()
//                                         ? AppColors.primary
//                                         : AppColors.textSecondary,
//                                     fontSize:
//                                         ResponsiveUtils.getFontSize(context, 10),
//                                     fontWeight: _touchedIndex == value.toInt()
//                                         ? FontWeight.w800
//                                         : FontWeight.w500,
//                                   ),
//                                 ),
//                               )
//                             : const SizedBox();
//                       },
//                     ),
//                   ),
//                   rightTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false)),
//                   topTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false)),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 minX: 0,
//                 maxX: _getMaxX(),
//                 minY: chartMinY,
//                 maxY: chartMaxY,
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots: spots,
//                     isCurved: true,
//                     curveSmoothness: 0.35,
//                     // Purple/lavender gradient matching reference exactly
//                     color: const Color(0xFF8B5CF6),
//                     barWidth: 2.5,
//                     isStrokeCapRound: true,
//                     dotData: FlDotData(
//                       show: true,
//                       getDotPainter: (spot, percent, barData, index) {
//                         final isTouched = _touchedIndex == index;
//                         return FlDotCirclePainter(
//                           radius: isTouched ? 7 : 4,
//                           color: Colors.white,
//                           strokeWidth: isTouched ? 3 : 2,
//                           strokeColor: const Color(0xFF8B5CF6),
//                         );
//                       },
//                     ),
//                     belowBarData: BarAreaData(
//                       show: true,
//                       // Soft purple fill matching the reference image
//                       gradient: LinearGradient(
//                         colors: [
//                           const Color(0xFF8B5CF6).withOpacity(0.28),
//                           const Color(0xFFA78BFA).withOpacity(0.18),
//                           const Color(0xFFDDD6FE).withOpacity(0.08),
//                           Colors.transparent,
//                         ],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                         stops: const [0.0, 0.35, 0.7, 1.0],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /*import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'dart:math' as math;
// import 'package:intl/intl.dart';
// import 'package:pos_app/screens/utils/app_sizes.dart';
// import 'package:pos_app/screens/utils/responsive_utils.dart';
// import 'package:pos_app/theme/app_colors.dart';


// class EnhancedRevenueAnalytics extends StatefulWidget {
//   final DateTime? selectedDate;

//   const EnhancedRevenueAnalytics({Key? key, this.selectedDate})
//       : super(key: key);

//   @override
//   State<EnhancedRevenueAnalytics> createState() =>
//       _EnhancedRevenueAnalyticsState();
// }

// class _EnhancedRevenueAnalyticsState extends State<EnhancedRevenueAnalytics>
//     with SingleTickerProviderStateMixin {
//   String selectedPeriod = 'Weekly';
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );

//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeOutCubic,
//       ),
//     );

//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   void _changePeriod(String period) {
//     setState(() {
//       selectedPeriod = period;
//     });
//     _animationController.reset();
//     _animationController.forward();
//   }

//   List<FlSpot> _getChartData() {
//     final random = math.Random(DateTime.now().millisecondsSinceEpoch);

//     switch (selectedPeriod) {
//       case 'Weekly':
//         return List.generate(
//           7,
//           (i) => FlSpot(i.toDouble(), 3 + random.nextDouble() * 3),
//         );
//       case 'Monthly':
//         return List.generate(
//           30,
//           (i) => FlSpot(i.toDouble(), 2.5 + random.nextDouble() * 4),
//         );
//       case 'Yearly':
//         return List.generate(
//           12,
//           (i) => FlSpot(i.toDouble(), 4 + random.nextDouble() * 3.5),
//         );
//       default:
//         return [];
//     }
//   }

//   String _getXAxisLabel(int index) {
//     switch (selectedPeriod) {
//       case 'Weekly':
//         const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//         return index < days.length ? days[index] : '';
//       case 'Monthly':
//         return index % 5 == 0 ? '${index + 1}' : '';
//       case 'Yearly':
//         const months = [
//           'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
//         ];
//         return index < months.length ? months[index] : '';
//       default:
//         return '';
//     }
//   }

//   double _getMaxX() {
//     switch (selectedPeriod) {
//       case 'Weekly':
//         return 6;
//       case 'Monthly':
//         return 29;
//       case 'Yearly':
//         return 11;
//       default:
//         return 6;
//     }
//   }

//   Map<String, dynamic> _getStatistics() {
//     final random = math.Random(DateTime.now().millisecondsSinceEpoch);

//     switch (selectedPeriod) {
//       case 'Weekly':
//         return {
//           'total': 28450.00 + random.nextDouble() * 5000,
//           'average': 4064.00 + random.nextDouble() * 700,
//           'highest': 5280.00 + random.nextDouble() * 1000,
//           'growth': 12.5 + random.nextDouble() * 10,
//         };
//       case 'Monthly':
//         return {
//           'total': 125400.00 + random.nextDouble() * 20000,
//           'average': 4180.00 + random.nextDouble() * 800,
//           'highest': 6500.00 + random.nextDouble() * 1500,
//           'growth': 18.3 + random.nextDouble() * 12,
//         };
//       case 'Yearly':
//         return {
//           'total': 1450000.00 + random.nextDouble() * 100000,
//           'average': 120833.00 + random.nextDouble() * 10000,
//           'highest': 145000.00 + random.nextDouble() * 15000,
//           'growth': 24.7 + random.nextDouble() * 15,
//         };
//       default:
//         return {'total': 0.0, 'average': 0.0, 'highest': 0.0, 'growth': 0.0};
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final stats = _getStatistics();

//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: SlideTransition(
//         position: _slideAnimation,
//         child: Container(
//           margin: EdgeInsets.symmetric(
//             horizontal: size.width * 0.04,
//             vertical: size.width * 0.02,
//           ),
//           padding: EdgeInsets.all(size.width * 0.05),
//           decoration: BoxDecoration(
//             gradient: AppColors.cardGradient,
//             borderRadius: BorderRadius.circular(AppSizes.borderRadiusXLarge),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.primary.withOpacity(0.1),
//                 blurRadius: 30,
//                 offset: const Offset(0, 10),
//                 spreadRadius: 5,
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(context),
//               SizedBox(height: size.width * 0.04),
//               _buildPeriodSelector(context),
//               SizedBox(height: size.width * 0.05),
//               _buildStatisticsCards(context, stats),
//               SizedBox(height: size.width * 0.05),
//               _buildChart(context),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Revenue Analytics',
//                 style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 24),
//                   fontWeight: FontWeight.bold,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//               SizedBox(height: MediaQuery.of(context).size.width * 0.01),
//               Text(
//                 'Track your performance over time',
//                 style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 14),
//                   color: AppColors.textSecondary,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.all(AppSizes.paddingMedium),
//           decoration: BoxDecoration(
//             gradient: AppColors.primaryGradient,
//             borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.primary.withOpacity(0.3),
//                 blurRadius: 12,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: Icon(
//             Icons.show_chart,
//             color: Colors.white,
//             size: ResponsiveUtils.getFontSize(context, 24),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPeriodSelector(BuildContext context) {
//     final periods = ['Weekly', 'Monthly', 'Yearly'];

//     return Container(
//       padding: const EdgeInsets.all(AppSizes.paddingSmall),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F4F8),
//         borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//       ),
//       child: Row(
//         children: periods.map((period) {
//           final isSelected = selectedPeriod == period;
//           return Expanded(
//             child: GestureDetector(
//               onTap: () => _changePeriod(period),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 300),
//                 curve: Curves.easeInOut,
//                 padding: const EdgeInsets.symmetric(
//                   vertical: AppSizes.paddingSmall * 1.5,
//                 ),
//                 decoration: BoxDecoration(
//                   gradient: isSelected ? AppColors.primaryGradient : null,
//                   borderRadius:
//                       BorderRadius.circular(AppSizes.borderRadiusMedium),
//                   boxShadow: isSelected
//                       ? [
//                           BoxShadow(
//                             color: AppColors.primary.withOpacity(0.4),
//                             blurRadius: 12,
//                             offset: const Offset(0, 6),
//                           ),
//                         ]
//                       : [],
//                 ),
//                 child: Text(
//                   period,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: isSelected
//                         ? Colors.white
//                         : AppColors.textSecondary,
//                     fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
//                     fontSize: ResponsiveUtils.getFontSize(context, 14),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildStatisticsCards(
//     BuildContext context,
//     Map<String, dynamic> stats,
//   ) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
//           context,
//           mobile: 2,
//           tablet: 4,
//           desktop: 4,
//         );
//         final spacing = MediaQuery.of(context).size.width * 0.03;
//         final cardWidth =
//             (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
//                 crossAxisCount;

//         return Wrap(
//           spacing: spacing,
//           runSpacing: spacing,
//           children: [
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(
//                 context,
//                 'Total Revenue',
//                 '\$${NumberFormat('#,##0.00').format(stats['total'])}',
//                 Icons.attach_money,
//                 AppColors.primary,
//               ),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(
//                 context,
//                 'Average',
//                 '\$${NumberFormat('#,##0.00').format(stats['average'])}',
//                 Icons.analytics,
//                 AppColors.success,
//               ),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(
//                 context,
//                 'Highest',
//                 '\$${NumberFormat('#,##0.00').format(stats['highest'])}',
//                 Icons.trending_up,
//                 AppColors.warning,
//               ),
//             ),
//             SizedBox(
//               width: cardWidth,
//               child: _buildStatCard(
//                 context,
//                 'Growth',
//                 '+${stats['growth'].toStringAsFixed(1)}%',
//                 Icons.arrow_upward,
//                 AppColors.info,
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatCard(
//     BuildContext context,
//     String title,
//     String value,
//     IconData icon,
//     Color color,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(AppSizes.paddingMedium),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
//         ),
//         borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
//         border: Border.all(color: color.withOpacity(0.2), width: 1.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(AppSizes.paddingSmall),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(
//               icon,
//               color: color,
//               size: ResponsiveUtils.getFontSize(context, 20),
//             ),
//           ),
//           SizedBox(height: MediaQuery.of(context).size.width * 0.02),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: ResponsiveUtils.getFontSize(context, 12),
//               color: AppColors.textSecondary,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           SizedBox(height: MediaQuery.of(context).size.width * 0.01),
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             alignment: Alignment.centerLeft,
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: ResponsiveUtils.getFontSize(context, 18),
//                 fontWeight: FontWeight.bold,
//                 color: color,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildChart(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final chartHeight = ResponsiveUtils.getResponsiveValue(
//       context,
//       mobile: size.width * 0.6,
//       tablet: size.width * 0.4,
//       desktop: size.width * 0.25,
//     );

//     return Container(
//       padding: const EdgeInsets.all(AppSizes.paddingMedium),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             AppColors.primary.withOpacity(0.05),
//             AppColors.secondary.withOpacity(0.05),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: AppColors.primary.withOpacity(0.1),
//           width: 1.5,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 '$selectedPeriod Trend',
//                 style: TextStyle(
//                   fontSize: ResponsiveUtils.getFontSize(context, 16),
//                   fontWeight: FontWeight.bold,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//               Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: size.width * 0.03,
//                   vertical: size.width * 0.015,
//                 ),
//                 decoration: BoxDecoration(
//                   color: AppColors.success.withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.arrow_upward,
//                       color: AppColors.success,
//                       size: ResponsiveUtils.getFontSize(context, 14),
//                     ),
//                     SizedBox(width: size.width * 0.01),
//                     Text(
//                       'Trending Up',
//                       style: TextStyle(
//                         color: AppColors.success,
//                         fontWeight: FontWeight.bold,
//                         fontSize: ResponsiveUtils.getFontSize(context, 12),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: size.width * 0.04),
//           SizedBox(
//             height: chartHeight,
//             child: LineChart(
//               LineChartData(
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: selectedPeriod != 'Monthly',
//                   horizontalInterval: 1,
//                   verticalInterval: selectedPeriod == 'Yearly' ? 2 : 1,
//                   getDrawingHorizontalLine: (value) => FlLine(
//                     color: Colors.grey.withOpacity(0.15),
//                     strokeWidth: 1,
//                     dashArray: [5, 5],
//                   ),
//                   getDrawingVerticalLine: (value) => FlLine(
//                     color: Colors.grey.withOpacity(0.15),
//                     strokeWidth: 1,
//                     dashArray: [5, 5],
//                   ),
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: size.width * 0.12,
//                       interval: 1,
//                       getTitlesWidget: (value, meta) => Padding(
//                         padding: EdgeInsets.only(right: size.width * 0.02),
//                         child: Text(
//                           '\$${(value * 1000).toInt()}',
//                           style: TextStyle(
//                             color: AppColors.textSecondary,
//                             fontSize: ResponsiveUtils.getFontSize(context, 10),
//                             fontWeight: FontWeight.w500,
//                           ),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: size.width * 0.08,
//                       interval: 1,
//                       getTitlesWidget: (value, meta) {
//                         final label = _getXAxisLabel(value.toInt());
//                         return label.isNotEmpty
//                             ? Padding(
//                                 padding: EdgeInsets.only(top: size.width * 0.02),
//                                 child: Text(
//                                   label,
//                                   style: TextStyle(
//                                     color: AppColors.textSecondary,
//                                     fontSize:
//                                         ResponsiveUtils.getFontSize(context, 10),
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               )
//                             : const SizedBox();
//                       },
//                     ),
//                   ),
//                   rightTitles: AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                   topTitles: AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                 ),
//                 borderData: FlBorderData(
//                   show: true,
//                   border: Border.all(
//                     color: Colors.grey.withOpacity(0.2),
//                     width: 1,
//                   ),
//                 ),
//                 minX: 0,
//                 maxX: _getMaxX(),
//                 minY: 0,
//                 maxY: 8,
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots: _getChartData(),
//                     isCurved: true,
//                     gradient: AppColors.primaryGradient,
//                     barWidth: 4,
//                     isStrokeCapRound: true,
//                     dotData: FlDotData(
//                       show: true,
//                       getDotPainter: (spot, percent, barData, index) =>
//                           FlDotCirclePainter(
//                         radius: 6,
//                         color: Colors.white,
//                         strokeWidth: 3,
//                         strokeColor: AppColors.primary,
//                       ),
//                     ),
//                     belowBarData: BarAreaData(
//                       show: true,
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primary.withOpacity(0.3),
//                           AppColors.secondary.withOpacity(0.05),
//                         ],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }*/