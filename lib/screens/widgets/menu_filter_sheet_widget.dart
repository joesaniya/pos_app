import 'package:flutter/material.dart';
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
