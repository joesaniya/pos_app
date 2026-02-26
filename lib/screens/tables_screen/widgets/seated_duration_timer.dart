import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

// ═════════════════════════════════════════════════════════════
//  LIVE SEATED DURATION TIMER
//  Tick every 60 s so the card refreshes without rebuilding tree
// ═════════════════════════════════════════════════════════════
class SeatedDurationTimer extends StatefulWidget {
  final DateTime? occupiedSince;
  final bool showWarning;         // turns amber/red at thresholds
  final int warningMinutes;       // amber after N minutes
  final int dangerMinutes;        // red after N minutes

  const SeatedDurationTimer({
    super.key,
    required this.occupiedSince,
    this.showWarning = true,
    this.warningMinutes = 90,
    this.dangerMinutes = 150,
  });

  @override
  State<SeatedDurationTimer> createState() => _SeatedDurationTimerState();
}

class _SeatedDurationTimerState extends State<SeatedDurationTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _elapsed {
    if (widget.occupiedSince == null) return Duration.zero;
    return DateTime.now().difference(widget.occupiedSince!);
  }

  String get _durationLabel {
    final d = _elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.occupiedSince == null) {
      return const SizedBox.shrink();
    }

    final mins = _elapsed.inMinutes;

    Color color;
    Color bg;
    String emoji;

    if (widget.showWarning && mins >= widget.dangerMinutes) {
      color = TC.occupied;
      bg = TC.occupiedBg;
      emoji = '🔴';
    } else if (widget.showWarning && mins >= widget.warningMinutes) {
      color = TC.nonAcAmber;
      bg = TC.nonAcBg;
      emoji = '🟠';
    } else {
      color = TC.available;
      bg = TC.availableBg;
      emoji = '🟢';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seated for',
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _durationLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (widget.showWarning && mins >= widget.warningMinutes) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                mins >= widget.dangerMinutes ? 'Very long' : 'Long stay',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  COMPACT DURATION CHIP  (for table cards)
// ═════════════════════════════════════════════════════════════
class SeatedDurationChip extends StatefulWidget {
  final DateTime? occupiedSince;
  final int warningMinutes;
  final int dangerMinutes;

  const SeatedDurationChip({
    super.key,
    required this.occupiedSince,
    this.warningMinutes = 90,
    this.dangerMinutes = 150,
  });

  @override
  State<SeatedDurationChip> createState() => _SeatedDurationChipState();
}

class _SeatedDurationChipState extends State<SeatedDurationChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.occupiedSince == null) return const SizedBox.shrink();
    final mins =
        DateTime.now().difference(widget.occupiedSince!).inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    final label = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';

    final Color color = mins >= widget.dangerMinutes
        ? TC.occupied
        : mins >= widget.warningMinutes
            ? TC.nonAcAmber
            : TC.textSec;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_outlined, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (mins >= widget.warningMinutes) ...[
          const SizedBox(width: 3),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}