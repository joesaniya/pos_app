import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_filter_modal.dart';
import 'package:pos_app/screens/widgets/filter_widgets.dart';

/// All known ingredients across all menu items
const _allIngredients = [
  ('Rice batter', '🍚'),
  ('Potato', '🥔'),
  ('Onion', '🧅'),
  ('Ghee', '🧈'),
  ('Butter', '🧈'),
  ('Cheese', '🧀'),
  ('Coconut', '🥥'),
  ('Tomato', '🍅'),
  ('Garlic', '🧄'),
  ('Ginger', '🫚'),
  ('Spinach', '🥬'),
  ('Paneer', '🧀'),
  ('Chicken', '🍗'),
  ('Mutton', '🥩'),
  ('Prawns', '🦐'),
  ('Cream', '🥛'),
  ('Cashews', '🥜'),
  ('Saffron', '✨'),
  ('Cardamom', '🫙'),
  ('Rice', '🍚'),
  ('Lentils', '🫘'),
  ('Cumin', '🌿'),
  ('Pepper', '🫙'),
  ('Mango', '🥭'),
];

/// All known allergens
const _allAllergens = [
  ('Dairy', '🥛'),
  ('Gluten', '🌾'),
  ('Nuts', '🥜'),
  ('Shellfish', '🦐'),
  ('Eggs', '🥚'),
  ('Soy', '🫘'),
];

// ── Design tokens ────────────────────────────────────────────────────────────
class _C {
  // Warm cream base
  static const bg = Color(0xFFFDF6EE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFF3E6);

  // Warm coral/orange accent
  static const accent = Color(0xFFE8602C);
  static const accentSoft = Color(0xFFFDE8DC);
  static const accentMid = Color(0xFFF4A07A);

  // Saffron yellow highlight
  static const saffron = Color(0xFFFFB830);
  static const saffronSoft = Color(0xFFFFF3CC);

  // Mint green for veg
  static const mint = Color(0xFF3DB87A);
  static const mintSoft = Color(0xFFDDF4EA);

  // Red for non-veg
  static const chili = Color(0xFFE03E3E);
  static const chiliSoft = Color(0xFFFFE5E5);

  // Text
  static const textPri = Color(0xFF1A1208);
  static const textSec = Color(0xFF8A6E52);
  static const textTer = Color(0xFFBBA48C);

  // Border
  static const border = Color(0xFFEDE0D0);
  static const borderMid = Color(0xFFD4C4B0);
}

// ═════════════════════════════════════════════════════════════════════════════
//  PUBLIC API
// ═════════════════════════════════════════════════════════════════════════════
Future<MenuFilterModel?> showMenuFilterSheet({
  required BuildContext context,
  required MenuFilterModel current,
  required Color accentColor,
  required int totalItems,
}) {
  return showModalBottomSheet<MenuFilterModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _MenuFilterSheet(
      initial: current,
      accentColor: accentColor,
      totalItems: totalItems,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHEET WIDGET
// ═════════════════════════════════════════════════════════════════════════════
class _MenuFilterSheet extends StatefulWidget {
  final MenuFilterModel initial;
  final Color accentColor;
  final int totalItems;

  const _MenuFilterSheet({
    required this.initial,
    required this.accentColor,
    required this.totalItems,
  });

  @override
  State<_MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends State<_MenuFilterSheet>
    with TickerProviderStateMixin {
  late MenuFilterModel _filter;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _update(MenuFilterModel updated) => setState(() => _filter = updated);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.93),
        decoration: const BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          // Warm top border accent
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Decorative top strip ─────────────────────
            Container(
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(colors: [_C.accent, _C.saffron]),
              ),
            ),

            // ── Header ───────────────────────────────────
            _SheetHeader(
              activeCount: _filter.activeCount,
              onReset: () => _update(const MenuFilterModel()),
            ),

            // ── Section divider ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _WaveDivider(),
            ),

            // ── Scrollable content ───────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── SORT ──────────────────────────────
                    _SectionLabel(title: 'Sort By', icon: '↕️'),
                    const SizedBox(height: 10),
                    _SortGrid(
                      selected: _filter.sortBy,
                      onSelected: (opt) =>
                          _update(_filter.copyWith(sortBy: opt)),
                    ),

                    _Spacer(),

                    // ── DIET ──────────────────────────────
                    _SectionLabel(
                      title: 'Diet Preference',
                      icon: '🌿',
                      subtitle: 'Pick one or none',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DietCard(
                            label: 'Veg Only',
                            emoji: '🟢',
                            tagline: 'Pure vegetarian',
                            selected: _filter.vegOnly,
                            activeColor: _C.mint,
                            activeBg: _C.mintSoft,
                            onTap: () => _update(
                              _filter.copyWith(
                                vegOnly: !_filter.vegOnly,
                                nonVegOnly: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DietCard(
                            label: 'Non-Veg',
                            emoji: '🔴',
                            tagline: 'Includes meat',
                            selected: _filter.nonVegOnly,
                            activeColor: _C.chili,
                            activeBg: _C.chiliSoft,
                            onTap: () => _update(
                              _filter.copyWith(
                                nonVegOnly: !_filter.nonVegOnly,
                                vegOnly: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _Spacer(),

                    // ── AVAILABILITY ──────────────────────
                    _SectionLabel(title: 'Quick Filters', icon: '⚡'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleTile(
                            emoji: '✅',
                            label: 'Available Now',
                            selected: _filter.availableOnly,
                            activeColor: _C.mint,
                            onTap: () => _update(
                              _filter.copyWith(
                                availableOnly: !_filter.availableOnly,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ToggleTile(
                            emoji: '🔥',
                            label: 'Bestsellers',
                            selected: _filter.bestsellersOnly,
                            activeColor: _C.accent,
                            onTap: () => _update(
                              _filter.copyWith(
                                bestsellersOnly: !_filter.bestsellersOnly,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _Spacer(),

                    // ── PRICE RANGE ───────────────────────
                    _SectionLabel(title: 'Price Range', icon: '₹'),
                    const SizedBox(height: 8),
                    _PriceSliderCard(
                      min: 0,
                      max: 500,
                      values: RangeValues(_filter.minPrice, _filter.maxPrice),
                      color: _C.accent,
                      onChanged: (v) => _update(
                        _filter.copyWith(minPrice: v.start, maxPrice: v.end),
                      ),
                    ),

                    _Spacer(),

                    // ── MIN RATING ────────────────────────
                    _SectionLabel(
                      title: 'Minimum Rating',
                      icon: '⭐',
                      subtitle: 'Only show items rated at or above',
                    ),
                    const SizedBox(height: 10),
                    _StarRatingRow(
                      value: _filter.minRating,
                      onChanged: (v) => _update(_filter.copyWith(minRating: v)),
                    ),

                    _Spacer(),

                    // ── PREP TIME ─────────────────────────
                    _SectionLabel(
                      title: 'Max Prep Time',
                      icon: '⏱️',
                      subtitle: 'Show items ready within',
                    ),
                    const SizedBox(height: 10),
                    _PrepTimeRow(
                      value: _filter.maxPrepTime,
                      onChanged: (v) =>
                          _update(_filter.copyWith(maxPrepTime: v)),
                    ),

                    _Spacer(),

                    // ── INGREDIENTS ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SectionLabel(
                            title: 'Must Include',
                            icon: '🥗',
                            subtitle: 'Item must contain all selected',
                          ),
                        ),
                        if (_filter.includeIngredients.isNotEmpty)
                          _ClearBtn(
                            onTap: () => _update(
                              _filter.copyWith(includeIngredients: {}),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allIngredients.map((ing) {
                        final (name, emoji) = ing;
                        final sel = _filter.includeIngredients.contains(name);
                        return _EmojiChip(
                          label: name,
                          emoji: emoji,
                          selected: sel,
                          activeColor: _C.accent,
                          activeBg: _C.accentSoft,
                          onTap: () {
                            final updated = Set<String>.from(
                              _filter.includeIngredients,
                            );
                            sel ? updated.remove(name) : updated.add(name);
                            _update(
                              _filter.copyWith(includeIngredients: updated),
                            );
                          },
                        );
                      }).toList(),
                    ),

                    _Spacer(),

                    // ── ALLERGENS ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SectionLabel(
                            title: 'Exclude Allergens',
                            icon: '🚫',
                            subtitle: 'Hide items containing these',
                          ),
                        ),
                        if (_filter.excludeAllergens.isNotEmpty)
                          _ClearBtn(
                            onTap: () =>
                                _update(_filter.copyWith(excludeAllergens: {})),
                            isRed: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allAllergens.map((a) {
                        final (name, emoji) = a;
                        final sel = _filter.excludeAllergens.contains(name);
                        return _EmojiChip(
                          label: name,
                          emoji: emoji,
                          selected: sel,
                          activeColor: _C.chili,
                          activeBg: _C.chiliSoft,
                          onTap: () {
                            final updated = Set<String>.from(
                              _filter.excludeAllergens,
                            );
                            sel ? updated.remove(name) : updated.add(name);
                            _update(
                              _filter.copyWith(excludeAllergens: updated),
                            );
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────
            _SheetFooter(
              filter: _filter,
              onApply: () => Navigator.pop(context, _filter),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SheetHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback onReset;

  const _SheetHeader({required this.activeCount, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.accent, _C.saffron],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter & Sort',
                  style: TextStyle(
                    color: _C.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeCount > 0
                      ? '$activeCount filter${activeCount > 1 ? 's' : ''} active'
                      : 'Refine your search',
                  style: const TextStyle(color: _C.textSec, fontSize: 12),
                ),
              ],
            ),
          ),

          // Reset badge
          if (activeCount > 0)
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.accentMid.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh_rounded, size: 13, color: _C.accent),
                    SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        color: _C.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  WAVE DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class _WaveDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _C.border,
            _C.borderMid,
            _C.border,
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  final String icon;
  final String? subtitle;

  const _SectionLabel({required this.title, required this.icon, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _C.textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: _C.textSec, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SORT GRID — horizontal scrolling pill cards
// ─────────────────────────────────────────────────────────────────────────────
class _SortGrid extends StatelessWidget {
  final SortOption selected;
  final ValueChanged<SortOption> onSelected;

  const _SortGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: SortOption.values.map((opt) {
          final isSel = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSel ? _C.accent : _C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSel ? _C.accent : _C.border,
                  width: isSel ? 0 : 1.5,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: _C.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(opt.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : _C.textSec,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIET CARD
// ─────────────────────────────────────────────────────────────────────────────
class _DietCard extends StatelessWidget {
  final String label;
  final String emoji;
  final String tagline;
  final bool selected;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;

  const _DietCard({
    required this.label,
    required this.emoji,
    required this.tagline,
    required this.selected,
    required this.activeColor,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? activeBg : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? activeColor : _C.border,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? activeColor : _C.textPri,
                    ),
                  ),
                  Text(
                    tagline,
                    style: const TextStyle(fontSize: 10, color: _C.textSec),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: activeColor),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOGGLE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.08) : _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : _C.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? activeColor : _C.textSec,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? activeColor : _C.borderMid,
                  width: 2,
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  PRICE SLIDER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PriceSliderCard extends StatelessWidget {
  final double min, max;
  final RangeValues values;
  final Color color;
  final ValueChanged<RangeValues> onChanged;

  const _PriceSliderCard({
    required this.min,
    required this.max,
    required this.values,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Price labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PriceLabel('₹${values.start.round()}', isMin: true),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _C.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${values.start.round()} – ₹${values.end.round()}',
                  style: const TextStyle(
                    color: _C.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _PriceLabel('₹${values.end.round()}', isMin: false),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _C.accent,
              inactiveTrackColor: _C.border,
              thumbColor: Colors.white,
              overlayColor: _C.accent.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 4,
              ),
              trackHeight: 4,
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 4,
              ),
            ),
            child: RangeSlider(
              min: min,
              max: max,
              values: values,
              onChanged: onChanged,
              activeColor: _C.accent,
              inactiveColor: _C.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final String text;
  final bool isMin;
  const _PriceLabel(this.text, {required this.isMin});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      color: _C.textTer,
      fontWeight: FontWeight.w600,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAR RATING ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StarRatingRow extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StarRatingRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // "Any" option
          _RatingOption(
            label: 'Any',
            emoji: '—',
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
          ...List.generate(5, (i) {
            final stars = (i + 1).toDouble();
            return _RatingOption(
              label: '${stars.round()}+',
              emoji: '⭐',
              selected: value == stars,
              onTap: () => onChanged(stars),
            );
          }),
        ],
      ),
    );
  }
}

class _RatingOption extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _RatingOption({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _C.saffronSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _C.saffron : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            if (emoji != '—') Text(emoji, style: const TextStyle(fontSize: 14)),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? _C.saffron : _C.textTer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PREP TIME ROW
// ─────────────────────────────────────────────────────────────────────────────
const _prepOptions = [
  (0, 'Any'),
  (10, '10m'),
  (20, '20m'),
  (30, '30m'),
  (45, '45m'),
  (60, '1hr'),
];

class _PrepTimeRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PrepTimeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _prepOptions.map((opt) {
        final (mins, label) = opt;
        final sel = value == mins;
        return GestureDetector(
          onTap: () => onChanged(mins),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _C.accent : _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? _C.accent : _C.border,
                width: sel ? 0 : 1.5,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: _C.accent.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _C.textSec,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMOJI CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;

  const _EmojiChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.activeColor,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeBg : _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : _C.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeColor : _C.textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CLEAR BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ClearBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isRed;

  const _ClearBtn({required this.onTap, this.isRed = false});

  @override
  Widget build(BuildContext context) {
    final color = isRed ? _C.chili : _C.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Clear',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPACER
// ─────────────────────────────────────────────────────────────────────────────
class _Spacer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 6);
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _SheetFooter extends StatelessWidget {
  final MenuFilterModel filter;
  final VoidCallback onApply;

  const _SheetFooter({required this.filter, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 1.5)),
      ),
      child: Row(
        children: [
          // Active sort preview badge
          if (filter.sortBy != SortOption.relevance)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _C.saffronSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.saffron.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.sortBy.icon,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filter.sortBy.label.split(':').first,
                    style: const TextStyle(
                      color: _C.saffron,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Apply button
          GestureDetector(
            onTap: onApply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.accent, Color(0xFFFF8243)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _C.accent.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
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
}

/*import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_filter_modal.dart';
import 'package:pos_app/screens/widgets/filter_widgets.dart';

/// All known ingredients across all menu items (for the ingredient picker)
const _allIngredients = [
  ('Rice batter', '🍚'),
  ('Potato', '🥔'),
  ('Onion', '🧅'),
  ('Ghee', '🧈'),
  ('Butter', '🧈'),
  ('Cheese', '🧀'),
  ('Coconut', '🥥'),
  ('Tomato', '🍅'),
  ('Garlic', '🧄'),
  ('Ginger', '🫚'),
  ('Spinach', '🥬'),
  ('Paneer', '🧀'),
  ('Chicken', '🍗'),
  ('Mutton', '🥩'),
  ('Prawns', '🦐'),
  ('Cream', '🥛'),
  ('Cashews', '🥜'),
  ('Saffron', '✨'),
  ('Cardamom', '🫙'),
  ('Rice', '🍚'),
  ('Lentils', '🫘'),
  ('Cumin', '🌿'),
  ('Pepper', '🫙'),
  ('Mango', '🥭'),
];

/// All known allergens
const _allAllergens = [
  ('Dairy', '🥛'),
  ('Gluten', '🌾'),
  ('Nuts', '🥜'),
  ('Shellfish', '🦐'),
  ('Eggs', '🥚'),
  ('Soy', '🫘'),
];

// ═════════════════════════════════════════════════════════════════════════════
//  PUBLIC API  — call this to open the sheet
// ═════════════════════════════════════════════════════════════════════════════
Future<MenuFilterModel?> showMenuFilterSheet({
  required BuildContext context,
  required MenuFilterModel current,
  required Color accentColor,
  required int totalItems,
}) {
  return showModalBottomSheet<MenuFilterModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _MenuFilterSheet(
      initial: current,
      accentColor: accentColor,
      totalItems: totalItems,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHEET WIDGET
// ═════════════════════════════════════════════════════════════════════════════
class _MenuFilterSheet extends StatefulWidget {
  final MenuFilterModel initial;
  final Color accentColor;
  final int totalItems;

  const _MenuFilterSheet({
    required this.initial,
    required this.accentColor,
    required this.totalItems,
  });

  @override
  State<_MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends State<_MenuFilterSheet> {
  late MenuFilterModel _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
  }

  void _update(MenuFilterModel updated) => setState(() => _filter = updated);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      // Max height = 92% of screen
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: const BoxDecoration(
        color: FColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────
          _SheetHeader(
            activeCount: _filter.activeCount,
            onReset: () => _update(const MenuFilterModel()),
          ),

          // ── Divider ──────────────────────────────────────
          Container(height: 1, color: FColors.border),

          // ── Scrollable content ───────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SORT ──────────────────────────────────
                  const FilterSectionHeader(title: 'Sort By'),
                  ...SortOption.values.map(
                    (opt) => FilterSortRow(
                      icon: opt.icon,
                      label: opt.label,
                      selected: _filter.sortBy == opt,
                      onTap: () => _update(_filter.copyWith(sortBy: opt)),
                    ),
                  ),

                  // ── DIET ──────────────────────────────────
                  const FilterSectionHeader(
                    title: 'Diet Preference',
                    subtitle: 'Pick one or none',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilterIconCard(
                          label: 'Veg Only',
                          emoji: '🟢',
                          selected: _filter.vegOnly,
                          selectedColor: FColors.vegGreen,
                          onTap: () => _update(
                            _filter.copyWith(
                              vegOnly: !_filter.vegOnly,
                              nonVegOnly: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilterIconCard(
                          label: 'Non-Veg',
                          emoji: '🔴',
                          selected: _filter.nonVegOnly,
                          selectedColor: FColors.nonVegRed,
                          onTap: () => _update(
                            _filter.copyWith(
                              nonVegOnly: !_filter.nonVegOnly,
                              vegOnly: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── AVAILABILITY ──────────────────────────
                  const FilterSectionHeader(title: 'Availability'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'Available Now',
                        emoji: '✅',
                        selected: _filter.availableOnly,
                        selectedColor: FColors.vegGreen,
                        onTap: () => _update(
                          _filter.copyWith(
                            availableOnly: !_filter.availableOnly,
                          ),
                        ),
                      ),
                      FilterPill(
                        label: 'Bestsellers',
                        emoji: '🔥',
                        selected: _filter.bestsellersOnly,
                        selectedColor: const Color(0xFFFF9500),
                        onTap: () => _update(
                          _filter.copyWith(
                            bestsellersOnly: !_filter.bestsellersOnly,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── PRICE RANGE ───────────────────────────
                  const FilterSectionHeader(title: 'Price Range'),
                  FilterRangeSlider(
                    min: 0,
                    max: 500,
                    values: RangeValues(_filter.minPrice, _filter.maxPrice),
                    prefix: '₹',
                    color: widget.accentColor,
                    onChanged: (v) => _update(
                      _filter.copyWith(minPrice: v.start, maxPrice: v.end),
                    ),
                  ),

                  // ── MIN RATING ────────────────────────────
                  const FilterSectionHeader(
                    title: 'Minimum Rating',
                    subtitle: 'Only show items rated at or above',
                  ),
                  FilterStarRating(
                    value: _filter.minRating,
                    onChanged: (v) => _update(_filter.copyWith(minRating: v)),
                  ),

                  // ── PREP TIME ─────────────────────────────
                  const FilterSectionHeader(
                    title: 'Max Prep Time',
                    subtitle: 'Show items ready within',
                  ),
                  FilterPrepTimePicker(
                    value: _filter.maxPrepTime,
                    onChanged: (v) => _update(_filter.copyWith(maxPrepTime: v)),
                  ),

                  // ── INGREDIENTS ───────────────────────────
                  FilterSectionHeader(
                    title: 'Must Include Ingredient',
                    subtitle: 'Item must contain all selected',
                    trailing: _filter.includeIngredients.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _update(
                              _filter.copyWith(includeIngredients: {}),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: FColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allIngredients.map((ing) {
                      final (name, emoji) = ing;
                      final selected = _filter.includeIngredients.contains(
                        name,
                      );
                      return IngredientChip(
                        label: name,
                        emoji: emoji,
                        selected: selected,
                        color: widget.accentColor,
                        onTap: () {
                          final updated = Set<String>.from(
                            _filter.includeIngredients,
                          );
                          if (selected) {
                            updated.remove(name);
                          } else {
                            updated.add(name);
                          }
                          _update(
                            _filter.copyWith(includeIngredients: updated),
                          );
                        },
                      );
                    }).toList(),
                  ),

                  // ── ALLERGENS ─────────────────────────────
                  FilterSectionHeader(
                    title: 'Exclude Allergens',
                    subtitle: 'Hide items containing these',
                    trailing: _filter.excludeAllergens.isNotEmpty
                        ? GestureDetector(
                            onTap: () =>
                                _update(_filter.copyWith(excludeAllergens: {})),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: FColors.nonVegRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allAllergens.map((a) {
                      final (name, emoji) = a;
                      final selected = _filter.excludeAllergens.contains(name);
                      return IngredientChip(
                        label: name,
                        emoji: emoji,
                        selected: selected,
                        color: FColors.nonVegRed,
                        onTap: () {
                          final updated = Set<String>.from(
                            _filter.excludeAllergens,
                          );
                          if (selected) {
                            updated.remove(name);
                          } else {
                            updated.add(name);
                          }
                          _update(_filter.copyWith(excludeAllergens: updated));
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Apply / footer ───────────────────────────────
          _SheetFooter(
            filter: _filter,
            totalItems: widget.totalItems,
            accentColor: widget.accentColor,
            onApply: () => Navigator.pop(context, _filter),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHEET HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SheetHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback onReset;

  const _SheetHeader({required this.activeCount, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: FColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter & Sort',
                  style: TextStyle(
                    color: FColors.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  activeCount > 0
                      ? '$activeCount filter${activeCount > 1 ? 's' : ''} active'
                      : 'Refine your search',
                  style: const TextStyle(color: FColors.textSec, fontSize: 12),
                ),
              ],
            ),
          ),

          // Reset button
          if (activeCount > 0)
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: FColors.surfaceHi,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Reset all',
                style: TextStyle(
                  color: FColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHEET FOOTER  — results count + apply button
// ─────────────────────────────────────────────────────────────────────────────
class _SheetFooter extends StatelessWidget {
  final MenuFilterModel filter;
  final int totalItems;
  final Color accentColor;
  final VoidCallback onApply;

  const _SheetFooter({
    required this.filter,
    required this.totalItems,
    required this.accentColor,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: FColors.surface,
        border: Border(top: BorderSide(color: FColors.border)),
      ),
      child: Row(
        children: [
          // Sort label preview
          if (filter.sortBy != SortOption.relevance)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: FColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    filter.sortBy.icon,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filter.sortBy.label.split(':').first,
                    style: const TextStyle(
                      color: FColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Apply button
          GestureDetector(
            onTap: onApply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.75)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
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
}
*/
