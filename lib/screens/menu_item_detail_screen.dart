// lib/screens/menu_item_detail_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
//  Menu Item Detail Screen
//  Shows: hero image, item info, flags, nutrition facts panel, allergens,
//         full recipe (ingredients + chef notes), edit / back actions.
//  Data source: menu_items row  +  live fetch of linked recipe from Supabase.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/add_menu_item_with_recipe_screen.dart';
import 'package:pos_app/theme/app_colors.dart';

// ─── Design tokens (match add screen) ────────────────────────────────────
class _C {
  static const bg = Color(0xFFF6F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAF8F5);
  static const border = Color(0xFFE8E4DE);
  static const divider = Color(0xFFF0EDE9);
  static const brand = Color(0xFFD97706);
  static const brandLight = Color(0xFFFEF3C7);
  static const teal = Color(0xFF0F766E);
  static const tealLight = Color(0xFFCCFBF1);
  static const indigo = Color(0xFF4338CA);
  static const indigoLight = Color(0xFFEEF2FF);
  static const success = Color(0xFF059669);
  static const successBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const textPri = Color(0xFF1C1917);
  static const textSec = Color(0xFF78716C);
  static const textMut = Color(0xFFA8A29E);
}

// ─── Known allergen metadata (emoji + label, keyed by id) ─────────────────
const _kAllergenMeta = <String, Map<String, String>>{
  'gluten': {'label': 'Gluten', 'emoji': '🌾'},
  'dairy': {'label': 'Dairy', 'emoji': '🥛'},
  'eggs': {'label': 'Eggs', 'emoji': '🥚'},
  'nuts': {'label': 'Tree Nuts', 'emoji': '🌰'},
  'peanuts': {'label': 'Peanuts', 'emoji': '🥜'},
  'shellfish': {'label': 'Shellfish', 'emoji': '🦐'},
  'fish': {'label': 'Fish', 'emoji': '🐟'},
  'soy': {'label': 'Soy', 'emoji': '🫘'},
  'sesame': {'label': 'Sesame', 'emoji': '🌱'},
  'mustard': {'label': 'Mustard', 'emoji': '🟡'},
  'celery': {'label': 'Celery', 'emoji': '🥬'},
  'sulphites': {'label': 'Sulphites', 'emoji': '🧪'},
};

// ─── Roles allowed to edit ────────────────────────────────────────────────
const _editRoles = {'admin', 'system', 'owner', 'manager'};
bool _canEdit(String? r) => r != null && _editRoles.contains(r.toLowerCase());

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class MenuItemDetailScreen extends StatefulWidget {
  final SupabaseMenuItem item;
  final SupabaseMenuCategory category;

  const MenuItemDetailScreen({
    Key? key,
    required this.item,
    required this.category,
  }) : super(key: key);

  @override
  State<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends State<MenuItemDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _recipe;
  bool _loadingRecipe = true;
  String? _recipeError;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchRecipe();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Fetch linked recipe ──────────────────────────────────
  Future<void> _fetchRecipe() async {
    setState(() {
      _loadingRecipe = true;
      _recipeError = null;
    });
    try {
      final res = await Supabase.instance.client
          .from('recipes')
          .select()
          .eq('menu_item_id', widget.item.id)
          .eq('is_active', true)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _recipe = res;
          _loadingRecipe = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _recipeError = e.toString();
          _loadingRecipe = false;
        });
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  List<dynamic> get _ingredients {
    final raw = _recipe?['ingredients'];
    if (raw == null) return [];
    if (raw is List) return raw;
    return [];
  }

  List<String> get _allergens {
    // Prefer recipe allergens; fall back to menu item allergens field
    final raw = _recipe?['allergens'] ?? widget.item.allergens;
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  Map<String, dynamic> get _nutrition {
    final raw = _recipe?['nutritional_info'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    // Also check direct fields on menu item
    return {};
  }

  double _nv(String key) {
    final v = _nutrition[key];
    if (v == null) return 0;
    return (v as num).toDouble();
  }

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  bool get _hasNutrition =>
      _nutrition.isNotEmpty || widget.item.calories != null;

  bool get _hasRecipe => _recipe != null && _ingredients.isNotEmpty;

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(item),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildItemHeader(item),
                    const SizedBox(height: 12),
                    _buildFlagRow(item),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDescription(item),
                    ],
                    const SizedBox(height: 20),
                    _buildQuickStats(item),
                    const SizedBox(height: 20),
                    if (_hasNutrition) ...[
                      _buildNutritionPanel(item),
                      const SizedBox(height: 20),
                    ],
                    if (_allergens.isNotEmpty) ...[
                      _buildAllergenPanel(),
                      const SizedBox(height: 20),
                    ],
                    _buildRecipeSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver AppBar with hero image ─────────────────────────
  Widget _buildSliverAppBar(SupabaseMenuItem item) {
    final menuProv = context.read<SupabaseMenuProvider>();
    final canEdit = _canEdit(menuProv.userRole);

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _C.surface,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
      actions: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMenuItemWithRecipeScreen(
                      category: widget.category,
                      editItem: item,
                    ),
                  ),
                );
                _fetchRecipe(); // refresh after edit
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _C.brand,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _C.brand.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _PlaceholderHero(item: item),
              )
            else
              _PlaceholderHero(item: item),
            // gradient scrim
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // veg/non-veg badge
            Positioned(
              bottom: 14,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: item.isVeg
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.isVeg ? 'VEG' : 'NON-VEG',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item header — name + price ────────────────────────────
  Widget _buildItemHeader(SupabaseMenuItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _C.textPri,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    widget.category.icon,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.category.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _C.textSec,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _C.brand,
                letterSpacing: -0.5,
              ),
            ),
            if (item.discountPrice != null)
              Text(
                'Save ₹${(item.price - item.discountPrice!).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _C.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Flag row ──────────────────────────────────────────────
  Widget _buildFlagRow(SupabaseMenuItem item) {
    final flags = <Map<String, dynamic>>[];
    if (item.isAvailable)
      flags.add({'e': '✅', 'l': 'Available', 'c': _C.success});
    if (item.isBestSeller)
      flags.add({'e': '🔥', 'l': 'Bestseller', 'c': const Color(0xFFEA580C)});
    if (item.isFeatured)
      flags.add({'e': '⭐', 'l': 'Featured', 'c': const Color(0xFFCA8A04)});
    if (item.isNewArrival)
      flags.add({'e': '🆕', 'l': 'New', 'c': const Color(0xFF2563EB)});
    if (item.isSpicy) flags.add({'e': '🌶️', 'l': 'Spicy', 'c': _C.danger});
    if (flags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: flags
          .map(
            (f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (f['c'] as Color).withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (f['c'] as Color).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f['e'] as String, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    f['l'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: f['c'] as Color,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Description ───────────────────────────────────────────
  Widget _buildDescription(SupabaseMenuItem item) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes_rounded, size: 18, color: _C.textMut),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.description,
            style: const TextStyle(
              fontSize: 14,
              color: _C.textSec,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Quick stats row ───────────────────────────────────────
  Widget _buildQuickStats(SupabaseMenuItem item) {
    final stats = <Map<String, String>>[];
    stats.add({
      'emoji': '⏱️',
      'label': 'Prep Time',
      'value': '${item.preparationTime} min',
    });
    if (item.calories != null)
      stats.add({
        'emoji': '🔥',
        'label': 'Calories',
        'value': '${item.calories} kcal',
      });
    stats.add({
      'emoji': '⭐',
      'label': 'Rating',
      'value': item.rating.toStringAsFixed(1),
    });
    if (widget.item.servingSize != null && widget.item.servingSize!.isNotEmpty)
      stats.add({
        'emoji': '🍽️',
        'label': 'Serving',
        'value': widget.item.servingSize!,
      });

    return Row(
      children: stats
          .asMap()
          .entries
          .map(
            (e) => Expanded(
              child: Container(
                margin: EdgeInsets.only(left: e.key == 0 ? 0 : 6),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    Text(
                      e.value['emoji']!,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value['value']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _C.textPri,
                      ),
                    ),
                    Text(
                      e.value['label']!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _C.textMut,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NUTRITION PANEL
  // ══════════════════════════════════════════════════════════
  Widget _buildNutritionPanel(SupabaseMenuItem item) {
    // prefer recipe nutritional_info, fall back to item-level calories
    final cal = _nv('calories') > 0
        ? _nv('calories').toInt()
        : item.calories ?? 0;
    final protein = _nv('protein_g');
    final carbs = _nv('carbs_g');
    final fat = _nv('fat_g');
    final fiber = _nv('fiber_g');
    final sodium = _nv('sodium_mg');
    final sugar = _nv('sugar_g');
    final total = protein + carbs + fat;

    return _DetailCard(
      color: _C.indigo,
      icon: Icons.monitor_heart_outlined,
      title: 'Nutrition Facts',
      subtitle: widget.item.servingSize != null
          ? 'Per serving · ${widget.item.servingSize}'
          : 'Per serving',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calorie hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  cal > 0 ? '$cal' : '—',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEA580C),
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'CALORIES',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Macro bars
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (protein > 0)
                    Expanded(
                      flex: (protein / total * 100).round(),
                      child: Container(
                        height: 8,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  if (carbs > 0)
                    Expanded(
                      flex: (carbs / total * 100).round(),
                      child: Container(
                        height: 8,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  if (fat > 0)
                    Expanded(
                      flex: (fat / total * 100).round(),
                      child: Container(
                        height: 8,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MacroLegend(color: const Color(0xFF3B82F6), label: 'Protein'),
                const SizedBox(width: 16),
                _MacroLegend(color: const Color(0xFFF59E0B), label: 'Carbs'),
                const SizedBox(width: 16),
                _MacroLegend(color: const Color(0xFFEF4444), label: 'Fat'),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Macro grid
          Row(
            children: [
              Expanded(
                child: _MacroTile(
                  label: 'Protein',
                  value: protein,
                  unit: 'g',
                  color: const Color(0xFF3B82F6),
                  emoji: '🥩',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroTile(
                  label: 'Carbs',
                  value: carbs,
                  unit: 'g',
                  color: const Color(0xFFF59E0B),
                  emoji: '🍞',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroTile(
                  label: 'Fat',
                  value: fat,
                  unit: 'g',
                  color: const Color(0xFFEF4444),
                  emoji: '🫙',
                ),
              ),
            ],
          ),

          // Micro row
          if (fiber > 0 || sodium > 0 || sugar > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (fiber > 0)
                  Expanded(
                    child: _MicroRow(
                      emoji: '🌾',
                      label: 'Fiber',
                      value: '${_fmtNum(fiber)} g',
                    ),
                  ),
                if (sodium > 0)
                  Expanded(
                    child: _MicroRow(
                      emoji: '🧂',
                      label: 'Sodium',
                      value: '${_fmtNum(sodium)} mg',
                    ),
                  ),
                if (sugar > 0)
                  Expanded(
                    child: _MicroRow(
                      emoji: '🍬',
                      label: 'Sugar',
                      value: '${_fmtNum(sugar)} g',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ALLERGEN PANEL
  // ══════════════════════════════════════════════════════════
  Widget _buildAllergenPanel() {
    final list = _allergens;
    return _DetailCard(
      color: _C.danger,
      icon: Icons.warning_amber_rounded,
      title: 'Allergen Information',
      subtitle: 'Contains ${list.length} allergen${list.length > 1 ? "s" : ""}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This item contains: ${list.map((id) {
                      final meta = _kAllergenMeta[id.toLowerCase()];
                      return meta?['label'] ?? id;
                    }).join(", ")}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _C.danger,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((id) {
              final meta = _kAllergenMeta[id.toLowerCase()];
              final emoji = meta?['emoji'] ?? '⚠️';
              final label = meta?['label'] ?? id;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _C.dangerBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _C.danger.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.danger,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _C.warning),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Please inform customers with allergies before ordering.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _C.warning,
                      fontWeight: FontWeight.w600,
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

  // ══════════════════════════════════════════════════════════
  //  RECIPE SECTION
  // ══════════════════════════════════════════════════════════
  Widget _buildRecipeSection() {
    if (_loadingRecipe) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _C.teal, strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'Loading recipe...',
                style: TextStyle(color: _C.textSec, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipeError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.dangerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _C.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Could not load recipe',
                    style: TextStyle(
                      color: _C.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _recipeError!,
                    style: const TextStyle(color: _C.danger, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _fetchRecipe, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (!_hasRecipe) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: const Column(
          children: [
            Text('🍳', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              'No Recipe Linked',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.textPri,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap Edit to add ingredients and a recipe to this item.',
              style: TextStyle(fontSize: 13, color: _C.textSec),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final recipe = _recipe!;
    final notes = recipe['notes'] as String?;
    final prepMins = recipe['preparation_time_minutes'] as int? ?? 0;
    final serving = recipe['serving_size'] as String?;
    final totalCost = _ingredients.fold<double>(0, (sum, ing) {
      final qty = (ing['required_quantity'] as num?)?.toDouble() ?? 0;
      final cost = (ing['cost_per_unit'] as num?)?.toDouble() ?? 0;
      return sum + qty * cost;
    });

    return _DetailCard(
      color: _C.teal,
      icon: Icons.science_outlined,
      title: 'Recipe',
      subtitle:
          '${_ingredients.length} ingredient${_ingredients.length > 1 ? "s" : ""}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe meta row
          _RecipeMetaRow(
            prepMins: prepMins,
            serving: serving,
            ingredientCount: _ingredients.length,
          ),
          const SizedBox(height: 16),

          // Ingredients list
          ..._ingredients.asMap().entries.map((e) {
            final ing = e.value as Map;
            final name = ing['inventory_item_name'] as String? ?? 'Ingredient';
            final emoji = ing['inventory_item_emoji'] as String? ?? '🧂';
            final qty = (ing['required_quantity'] as num?)?.toDouble() ?? 0;
            final unit = ing['unit'] as String? ?? '';
            final notes = ing['notes'] as String?;
            final fmtQty = qty == qty.truncateToDouble()
                ? qty.toInt().toString()
                : qty.toStringAsFixed(2);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _C.tealLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.teal.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _C.tealLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _C.textPri,
                          ),
                        ),
                        if (notes != null && notes.isNotEmpty)
                          Text(
                            notes,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _C.textSec,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Quantity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _C.teal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$fmtQty $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Cost summary
          if (totalCost > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Estimated recipe cost',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '₹${totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Chef notes
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.brandLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.brand.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👨‍🍳', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chef Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _C.brand,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.textPri,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

// ── Detail section card ───────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _DetailCard({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _C.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 11, color: _C.textSec),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ],
    ),
  );
}

// ── Placeholder hero when no image ────────────────────────────────────────
class _PlaceholderHero extends StatelessWidget {
  final SupabaseMenuItem item;
  const _PlaceholderHero({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1C1917),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.isVeg ? '🥗' : '🍗', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Macro tile ────────────────────────────────────────────────────────────
class _MacroTile extends StatelessWidget {
  final String label, unit, emoji;
  final double value;
  final Color color;
  const _MacroTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value > 0 ? '${value.toStringAsFixed(1)}$unit' : '—',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: _C.textMut)),
      ],
    ),
  );
}

// ── Micro row ─────────────────────────────────────────────────────────────
class _MicroRow extends StatelessWidget {
  final String emoji, label, value;
  const _MicroRow({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _C.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _C.textPri,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _C.textMut),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Macro legend dot ──────────────────────────────────────────────────────
class _MacroLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MacroLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: _C.textSec)),
    ],
  );
}

// ── Recipe meta row ───────────────────────────────────────────────────────
class _RecipeMetaRow extends StatelessWidget {
  final int prepMins, ingredientCount;
  final String? serving;
  const _RecipeMetaRow({
    required this.prepMins,
    required this.ingredientCount,
    this.serving,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _MetaPill(emoji: '⏱️', text: '$prepMins min'),
      const SizedBox(width: 8),
      _MetaPill(emoji: '🧂', text: '$ingredientCount ingredients'),
      if (serving != null) ...[
        const SizedBox(width: 8),
        _MetaPill(emoji: '🍽️', text: serving!),
      ],
    ],
  );
}

class _MetaPill extends StatelessWidget {
  final String emoji, text;
  const _MetaPill({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _C.tealLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.teal.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _C.teal,
          ),
        ),
      ],
    ),
  );
}
