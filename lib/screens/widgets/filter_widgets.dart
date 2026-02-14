import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS  (dark-theme filter sheet)
// ═══════════════════════════════════════════════════════════════
class FColors {
  static const bg         = Color(0xFF0F0F14);
  static const surface    = Color(0xFF1A1A24);
  static const surfaceHi  = Color(0xFF242433);
  static const border     = Color(0xFF2E2E42);
  static const accent     = Color(0xFFFF6B6B);
  static const accentSoft = Color(0x33FF6B6B);
  static const textPri    = Color(0xFFF2F2F7);
  static const textSec    = Color(0xFF8E8EA0);
  static const textMuted  = Color(0xFF4A4A60);
  static const vegGreen   = Color(0xFF30D158);
  static const nonVegRed  = Color(0xFFFF453A);
  static const gold       = Color(0xFFFFD60A);
}

// ═══════════════════════════════════════════════════════════════
//  SECTION HEADER  — used to separate filter groups
// ═══════════════════════════════════════════════════════════════
class FilterSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const FilterSectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: FColors.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: FColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PILL TOGGLE  — single selectable pill
// ═══════════════════════════════════════════════════════════════
class FilterPill extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const FilterPill({
    Key? key,
    required this.label,
    this.emoji,
    required this.selected,
    this.selectedColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? FColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : FColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : FColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : FColors.textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ICON TOGGLE CARD  — bigger selectable tile with icon
// ═══════════════════════════════════════════════════════════════
class FilterIconCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const FilterIconCard({
    Key? key,
    required this.label,
    required this.emoji,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.14)
              : FColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? selectedColor : FColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? selectedColor : FColors.textSec,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 14, color: selectedColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CUSTOM RANGE SLIDER  — price or any double range
// ═══════════════════════════════════════════════════════════════
class FilterRangeSlider extends StatelessWidget {
  final double min;
  final double max;
  final RangeValues values;
  final String prefix;
  final String suffix;
  final Color color;
  final ValueChanged<RangeValues> onChanged;

  const FilterRangeSlider({
    Key? key,
    required this.min,
    required this.max,
    required this.values,
    this.prefix = '',
    this.suffix = '',
    required this.color,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Value labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ValueBadge(
              text: '$prefix${values.start.toInt()}$suffix',
              color: color,
            ),
            Text(
              '—',
              style: TextStyle(color: FColors.textMuted, fontSize: 16),
            ),
            _ValueBadge(
              text: '$prefix${values.end.toInt()}$suffix',
              color: color,
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: color,
            inactiveTrackColor: FColors.border,
            thumbColor: color,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayColor: color.withOpacity(0.15),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 10,
            ),
            valueIndicatorColor: color,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: RangeSlider(
            min: min,
            max: max,
            values: values,
            onChanged: onChanged,
            labels: RangeLabels(
              '$prefix${values.start.toInt()}$suffix',
              '$prefix${values.end.toInt()}$suffix',
            ),
          ),
        ),
      ],
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _ValueBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAR RATING SELECTOR  — tap to set minimum rating
// ═══════════════════════════════════════════════════════════════
class FilterStarRating extends StatelessWidget {
  final double value;        // 0, 3.0, 3.5, 4.0, 4.5
  final ValueChanged<double> onChanged;

  const FilterStarRating({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  static const _options = [0.0, 3.0, 3.5, 4.0, 4.5];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = value == opt;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? FColors.gold.withOpacity(0.15)
                    : FColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? FColors.gold : FColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    opt == 0 ? 'Any' : '${opt}+',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? FColors.gold : FColors.textSec,
                    ),
                  ),
                  if (opt > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < opt.floor() ? Icons.star : Icons.star_border,
                          size: 8,
                          color: isSelected
                              ? FColors.gold
                              : FColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  INGREDIENT TAG CHIP  — add/remove ingredient from set
// ═══════════════════════════════════════════════════════════════
class IngredientChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const IngredientChip({
    Key? key,
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.16) : FColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : FColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? color : FColors.textSec,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SORT OPTION ROW  — radio-style sort selector
// ═══════════════════════════════════════════════════════════════
class FilterSortRow extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterSortRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? FColors.accentSoft : FColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FColors.accent : FColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? FColors.accent.withOpacity(0.2)
                    : FColors.surfaceHi,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? FColors.accent : FColors.textSec,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? FColors.accent : FColors.textSec,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? FColors.accent : FColors.border,
                  width: 2,
                ),
                color: selected ? FColors.accent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREP TIME STEPPER  — visual max time selector
// ═══════════════════════════════════════════════════════════════
class FilterPrepTimePicker extends StatelessWidget {
  final int value; // max minutes
  final ValueChanged<int> onChanged;

  const FilterPrepTimePicker({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  static const _options = [
    (10, '⚡ 10m'),
    (15, '🔥 15m'),
    (20, '🍳 20m'),
    (30, '🥘 30m'),
    (45, '🫕 45m'),
    (60, '🕐 Any'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((opt) {
        final (mins, label) = opt;
        final selected = value == mins;
        return GestureDetector(
          onTap: () => onChanged(mins),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? FColors.accent.withOpacity(0.15)
                  : FColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? FColors.accent : FColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? FColors.accent : FColors.textSec,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVE FILTER BADGE  — small count badge for filter button
// ═══════════════════════════════════════════════════════════════
class FilterBadge extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;

  const FilterBadge({
    Key? key,
    required this.count,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: count > 0 ? color.withOpacity(0.12) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: count > 0 ? color : const Color(0xFFE0E0E0),
                width: count > 0 ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: count > 0 ? color : const Color(0xFF888888),
                ),
                const SizedBox(width: 5),
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: count > 0 ? color : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: const Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}