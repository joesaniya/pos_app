import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  REUSABLE REPORT CARD
// ═════════════════════════════════════════════════════════════════════════════
class ReportCard extends StatelessWidget {
  final String emoji, label, value, change;
  final bool changePositive;
  final Color color;

  const ReportCard({
    Key? key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.change,
    required this.changePositive,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final changeColor = changePositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final changeBg = changePositive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              if (change.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: changeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        changePositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: changeColor,
                      ),
                      const SizedBox(width: 3),
                      Text(change,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: changeColor,
                          )),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  GRADIENT HEADER (Reusable for any color)
// ═════════════════════════════════════════════════════════════════════════════
class GradientHeader extends StatelessWidget {
  final String title, subtitle;
  final List<Color> gradient;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final VoidCallback? onBackTap;

  const GradientHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.actionIcon,
    this.onActionTap,
    this.onBackTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          if (onBackTap != null) ...[
            GestureDetector(
              onTap: onBackTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          if (actionIcon != null)
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(actionIcon, color: Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PERIOD SELECTOR (Reusable)
// ═════════════════════════════════════════════════════════════════════════════
class PeriodSelector extends StatelessWidget {
  final List<String> periods;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color selectedColor;

  const PeriodSelector({
    Key? key,
    required this.periods,
    required this.selected,
    required this.onChanged,
    this.selectedColor = const Color(0xFF7C3AED),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSel = selected == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? selectedColor : Colors.white,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAT TILE (Small metric display)
// ═════════════════════════════════════════════════════════════════════════════
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const StatTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}