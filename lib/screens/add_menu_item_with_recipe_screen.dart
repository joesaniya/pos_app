// lib/screens/add_menu_item_with_recipe_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
//  COMPLETE — Menu Item + Recipe Builder
//  Step 1 : Menu Details (name, price, flags, rating, image)
//  Step 2 : Nutrition & Allergens  (protein, carbs, fat, calories, allergens)
//  Step 3 : Recipe Builder (ingredients, dynamic units, stock validation)
//  All data saved to menu_items + recipes tables; inventory deducted on save.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ══════════════════════════════════════════════════════════════
class _C {
  static const bg = Color(0xFFF6F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAF8F5);
  static const border = Color(0xFFE8E4DE);
  static const divider = Color(0xFFF0EDE9);

  // Brand amber
  static const brand = Color(0xFFD97706);
  static const brandLight = Color(0xFFFEF3C7);
  static const brandDark = Color(0xFFB45309);

  // Teal (recipe section)
  static const teal = Color(0xFF0F766E);
  static const tealLight = Color(0xFFCCFBF1);
  static const tealDark = Color(0xFF115E59);

  // Indigo (nutrition section)
  static const indigo = Color(0xFF4338CA);
  static const indigoLight = Color(0xFFEEF2FF);

  // Status
  static const success = Color(0xFF059669);
  static const successBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);

  static const textPri = Color(0xFF1C1917);
  static const textSec = Color(0xFF78716C);
  static const textMut = Color(0xFFA8A29E);

  // Step colours
  static const stepDone = Color(0xFF059669);
  static const stepActive = Color(0xFFD97706);
  static const stepIdle = Color(0xFFE7E5E4);
}

// ══════════════════════════════════════════════════════════════
//  UNIT SYSTEM
//  Each ingredient has a base unit; we offer compatible override
//  units so the cook can pick the right granularity.
// ══════════════════════════════════════════════════════════════

/// Short display label for StockUnit
String _unitLabel(StockUnit u) {
  switch (u) {
    case StockUnit.kg:
      return 'kg';
    case StockUnit.g:
      return 'g';
    case StockUnit.litre:
      return 'L';
    case StockUnit.ml:
      return 'ml';
    case StockUnit.pieces:
      return 'pcs';
    case StockUnit.dozen:
      return 'doz';
    case StockUnit.packet:
      return 'pkt';
    case StockUnit.bottle:
      return 'btl';
  }
}

/// Compatible units for a given inventory unit
/// e.g. an item stored in kg also accepts g measurement entries
List<String> _compatibleUnits(StockUnit base) {
  switch (base) {
    case StockUnit.kg:
    case StockUnit.g:
      return ['g', 'mg', 'kg'];
    case StockUnit.litre:
    case StockUnit.ml:
      return ['ml', 'L'];
    case StockUnit.pieces:
      return ['pcs'];
    case StockUnit.dozen:
      return ['doz', 'pcs'];
    case StockUnit.packet:
      return ['pkt'];
    case StockUnit.bottle:
      return ['btl', 'ml', 'L'];
  }
}

/// Convert any compatible unit value → base StockUnit quantity
/// so we can compare against currentStock (which is always in base unit)
double _toBaseUnit(double qty, String selectedUnit, StockUnit base) {
  // Weight conversions
  if (selectedUnit == 'mg' && base == StockUnit.g) return qty / 1000;
  if (selectedUnit == 'mg' && base == StockUnit.kg) return qty / 1_000_000;
  if (selectedUnit == 'g' && base == StockUnit.kg) return qty / 1000;
  if (selectedUnit == 'kg' && base == StockUnit.g) return qty * 1000;
  // Volume conversions
  if (selectedUnit == 'ml' && base == StockUnit.litre) return qty / 1000;
  if (selectedUnit == 'L' && base == StockUnit.ml) return qty * 1000;
  // Dozen ↔ pcs
  if (selectedUnit == 'pcs' && base == StockUnit.dozen) return qty / 12;
  if (selectedUnit == 'doz' && base == StockUnit.pieces) return qty * 12;
  // Bottle sub-units
  if (selectedUnit == 'ml' && base == StockUnit.bottle) return qty / 1000;
  if (selectedUnit == 'L' && base == StockUnit.bottle) return qty;
  return qty; // same unit
}

// ══════════════════════════════════════════════════════════════
//  KNOWN ALLERGENS
// ══════════════════════════════════════════════════════════════
const List<Map<String, String>> _kAllergens = [
  {'id': 'gluten', 'label': 'Gluten', 'emoji': '🌾'},
  {'id': 'dairy', 'label': 'Dairy', 'emoji': '🥛'},
  {'id': 'eggs', 'label': 'Eggs', 'emoji': '🥚'},
  {'id': 'nuts', 'label': 'Tree Nuts', 'emoji': '🌰'},
  {'id': 'peanuts', 'label': 'Peanuts', 'emoji': '🥜'},
  {'id': 'shellfish', 'label': 'Shellfish', 'emoji': '🦐'},
  {'id': 'fish', 'label': 'Fish', 'emoji': '🐟'},
  {'id': 'soy', 'label': 'Soy', 'emoji': '🫘'},
  {'id': 'sesame', 'label': 'Sesame', 'emoji': '🌱'},
  {'id': 'mustard', 'label': 'Mustard', 'emoji': '🟡'},
  {'id': 'celery', 'label': 'Celery', 'emoji': '🥬'},
  {'id': 'sulphites', 'label': 'Sulphites', 'emoji': '🧪'},
];

// ══════════════════════════════════════════════════════════════
//  RECIPE INGREDIENT ENTRY  (in-memory model)
// ══════════════════════════════════════════════════════════════
class RecipeIngredientEntry {
  final InventoryItem item;
  double requiredQty;
  String selectedUnit; // could be 'g', 'mg', 'ml', 'L', etc.
  String? error;
  String notes;

  RecipeIngredientEntry({
    required this.item,
    this.requiredQty = 0,
    required this.selectedUnit,
    this.error,
    this.notes = '',
  });

  /// qty in the item's base StockUnit (for stock comparison)
  double get qtyInBaseUnit => _toBaseUnit(requiredQty, selectedUnit, item.unit);

  bool get isValid =>
      error == null && requiredQty > 0 && qtyInBaseUnit <= item.currentStock;

  Map<String, dynamic> toJson() => {
    'inventory_item_id': item.id,
    'inventory_item_name': item.name,
    'inventory_item_emoji': item.emoji,
    'required_quantity': requiredQty,
    'unit': selectedUnit,
    'base_unit': _unitLabel(item.unit),
    'available_quantity': item.currentStock,
    'notes': notes,
  };
}

// ══════════════════════════════════════════════════════════════
//  MAIN SCREEN  — 3-step wizard
// ══════════════════════════════════════════════════════════════
class AddMenuItemWithRecipeScreen extends StatefulWidget {
  final SupabaseMenuCategory category;
  final SupabaseMenuItem? editItem;

  const AddMenuItemWithRecipeScreen({
    Key? key,
    required this.category,
    this.editItem,
  }) : super(key: key);

  @override
  State<AddMenuItemWithRecipeScreen> createState() =>
      _AddMenuItemWithRecipeScreenState();
}

class _AddMenuItemWithRecipeScreenState
    extends State<AddMenuItemWithRecipeScreen>
    with TickerProviderStateMixin {
  // ── Wizard step (0 = Menu, 1 = Nutrition & Allergens, 2 = Recipe)
  int _currentStep = 0;
  static const int _totalSteps = 3;

  late final AnimationController _stepAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Step 0: Menu Details ──────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _prepTimeCtrl = TextEditingController(text: '15');
  final _servingCtrl = TextEditingController();

  bool _isVeg = true;
  bool _isAvailable = true;
  bool _isBestSeller = false;
  bool _isFeatured = false;
  bool _isSpicy = false;
  bool _isNewArrival = false;
  double _rating = 4.0;
  File? _imageFile;

  // ── Step 1: Nutrition & Allergens ─────────────────────────
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();

  // Allergen selections — key = allergen id
  final Map<String, bool> _allergens = {
    for (final a in _kAllergens) a['id']!: false,
  };

  // ── Step 2: Recipe Builder ────────────────────────────────
  bool _hasRecipe = false;
  final _recipeNotesCtrl = TextEditingController();
  final List<RecipeIngredientEntry> _recipeIngredients = [];
  List<InventoryItem> _availableInventory = [];
  bool _loadingInventory = false;
  String _ingredientSearch = '';
  final _ingredSearchCtrl = TextEditingController();

  // ── Global save ───────────────────────────────────────────
  bool _isSaving = false;
  String? _saveError;

  bool get _isEdit => widget.editItem != null;

  // ══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _stepAnim, curve: Curves.easeOutCubic));
    _stepAnim.forward();

    if (_isEdit) _prefill(widget.editItem!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _priceCtrl,
      _discountCtrl,
      _prepTimeCtrl,
      _servingCtrl,
      _caloriesCtrl,
      _proteinCtrl,
      _carbsCtrl,
      _fatCtrl,
      _fiberCtrl,
      _sodiumCtrl,
      _sugarCtrl,
      _recipeNotesCtrl,
      _ingredSearchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(SupabaseMenuItem item) {
    _nameCtrl.text = item.name;
    _descCtrl.text = item.description;
    _priceCtrl.text = item.price.toStringAsFixed(2);
    _discountCtrl.text = item.discountPrice?.toStringAsFixed(2) ?? '';
    _prepTimeCtrl.text = item.preparationTime.toString();
    _servingCtrl.text = item.servingSize ?? '';
    _isVeg = item.isVeg;
    _isAvailable = item.isAvailable;
    _isBestSeller = item.isBestSeller;
    _isFeatured = item.isFeatured;
    _isSpicy = item.isSpicy;
    _isNewArrival = item.isNewArrival;
    _rating = item.rating;
    // Nutrition
    _caloriesCtrl.text = item.calories?.toString() ?? '';
    _proteinCtrl.text = item.protein?.toString() ?? '';
    _carbsCtrl.text = item.carbs?.toString() ?? '';
    _fatCtrl.text = item.fat?.toString() ?? '';
    // Allergens — item.allergens is List<String>
    for (final id in item.allergens) {
      if (_allergens.containsKey(id.toLowerCase())) {
        _allergens[id.toLowerCase()] = true;
      }
    }
  }

  // ── Inventory load ────────────────────────────────────────
  Future<void> _loadInventory() async {
    if (!mounted) return;
    setState(() => _loadingInventory = true);
    try {
      final p = context.read<InventoryProvider>();
      if (!p.isInitialized) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return !p.isInitialized;
        });
      }
      if (p.filteredItems.isEmpty) await p.fetchItems();
      final items = p.filteredItems.where((i) => i.currentStock > 0).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted)
        setState(() {
          _availableInventory = items;
          _loadingInventory = false;
        });

      // ── Load existing recipe if editing ──────────────────────────────
      if (_isEdit && widget.editItem != null) {
        await _loadRecipe(widget.editItem!.id);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInventory = false);
    }
  }

  // ── Load existing recipe from database ───────────────────────────────
  Future<void> _loadRecipe(String menuItemId) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch the recipe for this menu item
      final recipeResponse = await supabase
          .from('recipes')
          .select()
          .eq('menu_item_id', menuItemId)
          .maybeSingle();

      if (recipeResponse == null) {
        log('ℹ️ No recipe found for menu item: $menuItemId');
        return;
      }

      // Parse ingredients from the recipe
      final ingredientsArray = recipeResponse['ingredients'] as List? ?? [];

      if (ingredientsArray.isEmpty) {
        log('ℹ️ Recipe has no ingredients for menu item: $menuItemId');
        return;
      }

      // Load recipe metadata
      final recipeNotes = recipeResponse['notes'] as String? ?? '';
      final nutritionalInfo =
          recipeResponse['nutritional_info'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          // Populate recipe ingredients from the saved data
          for (final ing in ingredientsArray) {
            try {
              final inventoryItemId = ing['inventory_item_id'] as String? ?? '';
              final ingredientName =
                  ing['inventory_item_name'] as String? ?? 'Unknown';
              final unit = ing['unit'] as String? ?? 'unit';
              final requiredQty =
                  double.tryParse(
                    ing['required_quantity']?.toString() ?? '0',
                  ) ??
                  0.0;
              final notes = ing['notes'] as String? ?? '';

              // Find the inventory item from available inventory
              InventoryItem? inventoryItem;
              try {
                inventoryItem = _availableInventory.firstWhere(
                  (item) => item.id == inventoryItemId,
                );
              } catch (e) {
                inventoryItem = null;
              }

              if (inventoryItem != null) {
                final entry = RecipeIngredientEntry(
                  item: inventoryItem,
                  requiredQty: requiredQty,
                  selectedUnit: unit,
                  notes: notes,
                );
                _validateEntry(entry);
                _recipeIngredients.add(entry);
              } else {
                log(
                  '⚠️ Inventory item not found: $inventoryItemId ($ingredientName)',
                );
              }
            } catch (e) {
              log('❌ Error parsing ingredient: $e');
            }
          }

          // Set recipe toggle ON if ingredients were loaded
          if (_recipeIngredients.isNotEmpty) {
            _hasRecipe = true;
            _recipeNotesCtrl.text = recipeNotes;

            // Load additional nutrition fields from recipe if not already set in menu item
            if (nutritionalInfo.isNotEmpty) {
              if (_proteinCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('protein_g')) {
                _proteinCtrl.text =
                    nutritionalInfo['protein_g']?.toString() ?? '';
              }
              if (_carbsCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('carbs_g')) {
                _carbsCtrl.text = nutritionalInfo['carbs_g']?.toString() ?? '';
              }
              if (_fatCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('fat_g')) {
                _fatCtrl.text = nutritionalInfo['fat_g']?.toString() ?? '';
              }
              if (_fiberCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('fiber_g')) {
                _fiberCtrl.text = nutritionalInfo['fiber_g']?.toString() ?? '';
              }
              if (_sodiumCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('sodium_mg')) {
                _sodiumCtrl.text =
                    nutritionalInfo['sodium_mg']?.toString() ?? '';
              }
              if (_sugarCtrl.text.isEmpty &&
                  nutritionalInfo.containsKey('sugar_g')) {
                _sugarCtrl.text = nutritionalInfo['sugar_g']?.toString() ?? '';
              }
            }

            log('✅ Loaded ${_recipeIngredients.length} ingredients for recipe');
          }
        });
      }
    } catch (e) {
      log('❌ Error loading recipe: $e');
    }
  }

  List<InventoryItem> get _filteredInventory {
    final q = _ingredientSearch.toLowerCase().trim();
    if (q.isEmpty) return _availableInventory;
    return _availableInventory
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Step navigation ───────────────────────────────────────
  void _nextStep() {
    if (_currentStep == 0 && !(_formKey.currentState?.validate() ?? false))
      return;
    if (_currentStep < _totalSteps - 1) {
      _stepAnim.forward(from: 0);
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _stepAnim.forward(from: 0);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Recipe ingredient helpers ─────────────────────────────
  void _addIngredient(InventoryItem item) {
    if (_recipeIngredients.any((e) => e.item.id == item.id)) return;
    final defaultUnit = _compatibleUnits(item.unit).first;
    setState(
      () => _recipeIngredients.add(
        RecipeIngredientEntry(item: item, selectedUnit: defaultUnit),
      ),
    );
  }

  void _removeIngredient(int idx) =>
      setState(() => _recipeIngredients.removeAt(idx));

  void _updateQty(int idx, String raw) {
    final qty = double.tryParse(raw.trim()) ?? 0;
    setState(() {
      final e = _recipeIngredients[idx];
      e.requiredQty = qty;
      _validateEntry(e);
    });
  }

  void _updateUnit(int idx, String unit) {
    setState(() {
      final e = _recipeIngredients[idx];
      e.selectedUnit = unit;
      _validateEntry(e);
    });
  }

  void _validateEntry(RecipeIngredientEntry e) {
    if (e.requiredQty <= 0) {
      e.error = 'Quantity must be greater than 0';
    } else if (e.qtyInBaseUnit > e.item.currentStock) {
      final av = _fmtQty(e.item.currentStock);
      final u = _unitLabel(e.item.unit);
      e.error = '⚠️ Insufficient stock — only $av $u available';
    } else {
      e.error = null;
    }
  }

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    final s = v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  bool get _recipeIsValid {
    if (!_hasRecipe) return true;
    if (_recipeIngredients.isEmpty) return false;
    return _recipeIngredients.every((e) => e.isValid);
  }

  List<String> get _selectedAllergenIds =>
      _allergens.entries.where((e) => e.value).map((e) => e.key).toList();

  // ══════════════════════════════════════════════════════════
  //  SAVE
  // ══════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _stepAnim.forward(from: 0);
      setState(() => _currentStep = 0);
      return;
    }
    if (_hasRecipe && !_recipeIsValid) {
      log('Error: Fix ingredient quantities before saving.');
      _showError('Fix ingredient quantities before saving.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final menu = context.read<SupabaseMenuProvider>();
      final inv = context.read<InventoryProvider>();

      final price = double.parse(_priceCtrl.text.trim());
      final discount = _discountCtrl.text.trim().isNotEmpty
          ? double.tryParse(_discountCtrl.text.trim())
          : null;
      final allergenList = _selectedAllergenIds;

      String? menuItemId;

      if (_isEdit) {
        menuItemId = widget.editItem!.id;
        await menu.updateItem(
          id: menuItemId,
          categoryId: widget.category.id,
          updates: {
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'price': price,
            'discount_price': discount,
            'is_veg': _isVeg,
            'is_available': _isAvailable,
            'is_best_seller': _isBestSeller,
            'is_featured': _isFeatured,
            'is_spicy': _isSpicy,
            'is_new_arrival': _isNewArrival,
            'preparation_time': int.tryParse(_prepTimeCtrl.text) ?? 15,
            'serving_size': _servingCtrl.text.trim().isEmpty
                ? null
                : _servingCtrl.text.trim(),
            'calories': int.tryParse(_caloriesCtrl.text),
            'protein': double.tryParse(_proteinCtrl.text),
            'carbs': double.tryParse(_carbsCtrl.text),
            'fat': double.tryParse(_fatCtrl.text),
            'allergens': allergenList,
            'rating': _rating,
          },
          imageFile: _imageFile,
          itemName: _nameCtrl.text.trim(),
        );
      } else {
        final created = await menu.createItem(
          categoryId: widget.category.id,
          name: _nameCtrl.text.trim(),
          price: price,
          isVeg: _isVeg,
          description: _descCtrl.text.trim(),
          discountPrice: discount,
          preparationTime: int.tryParse(_prepTimeCtrl.text) ?? 15,
          calories: int.tryParse(_caloriesCtrl.text),
          protein: double.tryParse(_proteinCtrl.text),
          carbs: double.tryParse(_carbsCtrl.text),
          fat: double.tryParse(_fatCtrl.text),
          allergens: allergenList,
          isAvailable: _isAvailable,
          isBestSeller: _isBestSeller,
          isFeatured: _isFeatured,
          isNewArrival: _isNewArrival,
          isSpicy: _isSpicy,
          rating: _rating,
          imageFile: _imageFile,
        );
        menuItemId = created.id;
      }

      // ── Recipe + inventory deduction ─────────────────────
      // Only deduct inventory on CREATION, not on edit
      if (_hasRecipe &&
          _recipeIngredients.isNotEmpty &&
          menuItemId != null &&
          menuItemId.isNotEmpty) {
        await _saveRecipe(menuItemId, menu, allergenList);

        // Only record inventory transactions for NEW items, not edits
        if (!_isEdit) {
          for (final entry in _recipeIngredients) {
            if (entry.isValid) {
              await inv.recordTransaction(
                itemId: entry.item.id,
                type: TransactionType.stockOut,
                quantity: entry.qtyInBaseUnit,
                note: 'Recipe: ${_nameCtrl.text.trim()}',
                updatedBy: menu.businessId,
              );
            }
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _isSaving = false;
          _saveError = e.toString();
        });
    }
  }

  Future<void> _saveRecipe(
    String menuItemId,
    SupabaseMenuProvider menu,
    List<String> allergenList,
  ) async {
    // Deterministic ID = one recipe per menu item; upsert will update on re-save
    final recipeId = 'recipe_$menuItemId';

    // Only include nutrition keys that the user actually filled in
    final Map<String, dynamic> nutrition = {};
    if (_caloriesCtrl.text.isNotEmpty)
      nutrition['calories'] = int.tryParse(_caloriesCtrl.text);
    if (_proteinCtrl.text.isNotEmpty)
      nutrition['protein_g'] = double.tryParse(_proteinCtrl.text);
    if (_carbsCtrl.text.isNotEmpty)
      nutrition['carbs_g'] = double.tryParse(_carbsCtrl.text);
    if (_fatCtrl.text.isNotEmpty)
      nutrition['fat_g'] = double.tryParse(_fatCtrl.text);
    if (_fiberCtrl.text.isNotEmpty)
      nutrition['fiber_g'] = double.tryParse(_fiberCtrl.text);
    if (_sodiumCtrl.text.isNotEmpty)
      nutrition['sodium_mg'] = double.tryParse(_sodiumCtrl.text);
    if (_sugarCtrl.text.isNotEmpty)
      nutrition['sugar_g'] = double.tryParse(_sugarCtrl.text);

    final recipeData = {
      // ── Identity ─────────────────────────────────────────
      // Use prefixed ID locally for offline-first tracking
      'id': recipeId,
      'business_id': menu.businessId,
      'menu_item_id': menuItemId, // Links to menu item (added via migration)
      'menu_item_name': _nameCtrl.text.trim(), // ← REQUIRED: was missing
      // ── Core (all existing columns) ──────────────────────
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'selling_price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
      'ingredients': _recipeIngredients.map((e) => e.toJson()).toList(),
      'preparation_time_minutes': int.tryParse(_prepTimeCtrl.text) ?? 15,
      'serving_size': _servingCtrl.text.trim().isEmpty
          ? null
          : _servingCtrl.text.trim(),
      'is_active': true,
      'is_featured': _isFeatured,
      'category': widget.category.name,
      'notes': _recipeNotesCtrl.text.trim().isEmpty
          ? null
          : _recipeNotesCtrl.text.trim(),
      // ── NEW columns (added via recipe_migration.sql) ──────
      'allergens': allergenList, // TEXT[]
      'nutritional_info': nutrition.isEmpty ? null : nutrition, // JSONB
      // ── Audit ────────────────────────────────────────────
      'created_by_uid': menu.businessId,
      'created_by_name': 'Menu System',
      'created_by_role': 'system',
    };

    // For Supabase API: convert to clean UUID (PostgreSQL requirement)
    final supabaseRecipeData = Map<String, dynamic>.from(recipeData)
      ..['id'] = menuItemId;

    // Hybrid offline-first pattern
    final _connectivity = ConnectivityService.instance;
    final _localDb = LocalDatabase.instance;

    try {
      // 1. Save to local cache
      await _localDb.upsertEntity(
        table: 'local_recipes',
        id: recipeId,
        businessId: menu.businessId,
        data: recipeData,
        syncStatus: _connectivity.isOnline
            ? LocalDatabase.syncSynced
            : LocalDatabase.syncPending,
        action: LocalDatabase.actionCreate,
      );

      // 2. Try API immediately if online
      if (_connectivity.isOnline) {
        try {
          await Supabase.instance.client
              .from('recipes')
              .upsert(supabaseRecipeData);
          log(
            '[Recipe] ✅ Recipe saved online: $recipeId → menu_item: $menuItemId',
          );
          // Already marked as synced locally
          return;
        } catch (e) {
          log('[Recipe] ⚠️ Online save failed: $e, falling back to queue');
          // Mark as pending for sync
          await _localDb.upsertEntity(
            table: 'local_recipes',
            id: recipeId,
            businessId: menu.businessId,
            data: recipeData,
            syncStatus: LocalDatabase.syncPending,
            action: LocalDatabase.actionCreate,
          );
          // Enqueue after API failure - use clean UUID for sync payload
          await _localDb.enqueue(
            id: const Uuid().v4(),
            entityType: 'recipe',
            entityId: recipeId,
            action: LocalDatabase.actionCreate,
            payload: supabaseRecipeData,
            businessId: menu.businessId,
          );
          return;
        }
      } else {
        // 3. Offline path — enqueue for sync with clean UUID payload
        await _localDb.enqueue(
          id: const Uuid().v4(),
          entityType: 'recipe',
          entityId: recipeId,
          action: LocalDatabase.actionCreate,
          payload: supabaseRecipeData,
          businessId: menu.businessId,
        );
      }

      log(
        '[Recipe] ✅ Recipe saved locally: $recipeId (${_connectivity.isOnline ? 'synced' : 'pending'})',
      );
    } catch (e, st) {
      log('[Recipe] ❌ _saveRecipe error: $e\n$st');
      rethrow;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    log('Error: $msg');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (x != null && mounted) setState(() => _imageFile = File(x.path));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(),
          _buildStepBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: IndexedStack(
                  index: _currentStep,
                  children: [_buildStep0(), _buildStep1(), _buildStep2()],
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevStep,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: _C.textPri,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Menu Item' : 'New Menu Item',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textPri,
                    letterSpacing: -0.4,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      widget.category.icon,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.category.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.textSec,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.brandLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.brand.withOpacity(0.3)),
            ),
            child: Text(
              'Step ${_currentStep + 1} / $_totalSteps',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _C.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step progress bar ─────────────────────────────────────
  Widget _buildStepBar() {
    const labels = ['Menu Details', 'Nutrition & Allergens', 'Recipe Builder'];
    const icons = [
      Icons.restaurant_menu_rounded,
      Icons.monitor_heart_outlined,
      Icons.science_outlined,
    ];
    const colors = [_C.brand, _C.indigo, _C.teal];

    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isDone = _currentStep > i;
          final isActive = _currentStep == i;
          final color = colors[i];
          return Expanded(
            child: Row(
              children: [
                // Dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? _C.stepDone
                        : isActive
                        ? color
                        : _C.stepIdle,
                    border: Border.all(
                      color: isDone
                          ? _C.stepDone
                          : isActive
                          ? color
                          : _C.stepIdle,
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : Icon(
                            icons[i],
                            color: isActive ? Colors.white : _C.textMut,
                            size: 15,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${i + 1}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? _C.stepDone
                              : isActive
                              ? color
                              : _C.textMut,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? _C.textPri : _C.textSec,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (i < _totalSteps - 1)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentStep > i ? _C.stepDone : _C.stepIdle,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 0 — MENU DETAILS
  // ══════════════════════════════════════════════════════════
  Widget _buildStep0() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Image
          _ImagePickerWidget(
            imageFile: _imageFile,
            existingUrl: _isEdit ? widget.editItem?.imageUrl : null,
            onTap: _pickImage,
          ),
          const SizedBox(height: 16),

          // Veg toggle
          _VegToggleWidget(
            isVeg: _isVeg,
            onChanged: (v) => setState(() => _isVeg = v),
          ),
          const SizedBox(height: 16),

          // Name
          _SectionCard(
            color: _C.brand,
            icon: Icons.restaurant_menu_rounded,
            title: 'Basic Information',
            child: Column(
              children: [
                _lbl('Item Name *'),
                const SizedBox(height: 6),
                _tf(
                  ctrl: _nameCtrl,
                  hint: 'e.g. Chicken Biryani',
                  icon: Icons.fastfood_outlined,
                  capitalization: TextCapitalization.words,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _lbl('Description'),
                const SizedBox(height: 6),
                _tf(
                  ctrl: _descCtrl,
                  hint: 'Short description of this dish...',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _lbl('Serving Size (optional)'),
                const SizedBox(height: 6),
                _tf(
                  ctrl: _servingCtrl,
                  hint: 'e.g. 1 plate (300g)',
                  icon: Icons.scale_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pricing
          _SectionCard(
            color: const Color(0xFF059669),
            icon: Icons.currency_rupee_rounded,
            title: 'Pricing',
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lbl('Price (₹) *'),
                      const SizedBox(height: 6),
                      _tf(
                        ctrl: _priceCtrl,
                        hint: '0.00',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null)
                            return 'Invalid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lbl('Discount (₹)'),
                      const SizedBox(height: 6),
                      _tf(
                        ctrl: _discountCtrl,
                        hint: 'Optional',
                        icon: Icons.local_offer_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Timing + Rating
          _SectionCard(
            color: const Color(0xFF7C3AED),
            icon: Icons.timer_outlined,
            title: 'Preparation & Rating',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl('Prep Time (min)'),
                          const SizedBox(height: 6),
                          _tf(
                            ctrl: _prepTimeCtrl,
                            hint: '15',
                            icon: Icons.timer_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _lbl('Rating'),
                const SizedBox(height: 8),
                _RatingSliderWidget(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Flags
          _SectionCard(
            color: _C.textSec,
            icon: Icons.tune_rounded,
            title: 'Item Options',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FlagChip(
                  emoji: '✅',
                  label: 'Available',
                  active: _isAvailable,
                  activeColor: _C.success,
                  onTap: () => setState(() => _isAvailable = !_isAvailable),
                ),
                _FlagChip(
                  emoji: '🔥',
                  label: 'Bestseller',
                  active: _isBestSeller,
                  activeColor: const Color(0xFFEA580C),
                  onTap: () => setState(() => _isBestSeller = !_isBestSeller),
                ),
                _FlagChip(
                  emoji: '⭐',
                  label: 'Featured',
                  active: _isFeatured,
                  activeColor: const Color(0xFFCA8A04),
                  onTap: () => setState(() => _isFeatured = !_isFeatured),
                ),
                _FlagChip(
                  emoji: '🆕',
                  label: 'New Arrival',
                  active: _isNewArrival,
                  activeColor: const Color(0xFF2563EB),
                  onTap: () => setState(() => _isNewArrival = !_isNewArrival),
                ),
                _FlagChip(
                  emoji: '🌶️',
                  label: 'Spicy',
                  active: _isSpicy,
                  activeColor: _C.danger,
                  onTap: () => setState(() => _isSpicy = !_isSpicy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 1 — NUTRITION & ALLERGENS
  // ══════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Nutrition info header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🧬', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutritional Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'All fields optional — per serving values recommended',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Calories (full width — most important)
        _SectionCard(
          color: const Color(0xFFEA580C),
          icon: Icons.local_fire_department_outlined,
          title: 'Energy',
          child: Column(
            children: [
              _lbl('Calories (kcal)'),
              const SizedBox(height: 6),
              _tf(
                ctrl: _caloriesCtrl,
                hint: 'e.g. 450',
                icon: Icons.local_fire_department_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Macros grid
        _SectionCard(
          color: const Color(0xFF0284C7),
          icon: Icons.pie_chart_outline_rounded,
          title: 'Macronutrients (per serving)',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _NutritionField(
                      ctrl: _proteinCtrl,
                      label: 'Protein',
                      unit: 'g',
                      emoji: '🥩',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NutritionField(
                      ctrl: _carbsCtrl,
                      label: 'Carbs',
                      unit: 'g',
                      emoji: '🍞',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _NutritionField(
                      ctrl: _fatCtrl,
                      label: 'Fat',
                      unit: 'g',
                      emoji: '🫙',
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NutritionField(
                      ctrl: _fiberCtrl,
                      label: 'Fiber',
                      unit: 'g',
                      emoji: '🌾',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _NutritionField(
                      ctrl: _sodiumCtrl,
                      label: 'Sodium',
                      unit: 'mg',
                      emoji: '🧂',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NutritionField(
                      ctrl: _sugarCtrl,
                      label: 'Sugar',
                      unit: 'g',
                      emoji: '🍬',
                      color: const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live nutrition bar preview
        if (_hasAnyNutrition) ...[
          const SizedBox(height: 14),
          _NutritionPreviewBar(
            calories: int.tryParse(_caloriesCtrl.text),
            protein: double.tryParse(_proteinCtrl.text),
            carbs: double.tryParse(_carbsCtrl.text),
            fat: double.tryParse(_fatCtrl.text),
          ),
        ],

        const SizedBox(height: 14),

        // Allergens
        _SectionCard(
          color: const Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
          title: 'Allergen Information',
          subtitle: 'Select all allergens present in this dish',
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kAllergens.map((a) {
                  final id = a['id']!;
                  final sel = _allergens[id] ?? false;
                  return _AllergenChip(
                    emoji: a['emoji']!,
                    label: a['label']!,
                    selected: sel,
                    onTap: () => setState(() => _allergens[id] = !sel),
                  );
                }).toList(),
              ),
              if (_selectedAllergenIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _C.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: _C.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contains: ${_selectedAllergenIds.map((id) => _kAllergens.firstWhere((a) => a['id'] == id)['label']).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasAnyNutrition =>
      _caloriesCtrl.text.isNotEmpty ||
      _proteinCtrl.text.isNotEmpty ||
      _carbsCtrl.text.isNotEmpty ||
      _fatCtrl.text.isNotEmpty;

  // ══════════════════════════════════════════════════════════
  //  STEP 2 — RECIPE BUILDER
  // ══════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Toggle
        _RecipeToggleBannerWidget(
          enabled: _hasRecipe,
          onToggle: (v) => setState(() => _hasRecipe = v),
        ),
        const SizedBox(height: 14),

        if (_hasRecipe) ...[
          // Recipe notes
          _SectionCard(
            color: _C.teal,
            icon: Icons.notes_rounded,
            title: 'Chef Notes (optional)',
            child: Column(
              children: [
                _tf(
                  ctrl: _recipeNotesCtrl,
                  hint:
                      'Special instructions, cooking tips, temperature, timing...',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Added ingredients list
          if (_recipeIngredients.isNotEmpty) ...[
            _lbl('Recipe Ingredients (${_recipeIngredients.length})'),
            const SizedBox(height: 10),
            ..._recipeIngredients.asMap().entries.map(
              (e) => _IngredientTileWidget(
                entry: e.value,
                index: e.key,
                onRemove: () => _removeIngredient(e.key),
                onQtyChanged: (v) => _updateQty(e.key, v),
                onUnitChanged: (u) => _updateUnit(e.key, u),
                fmtQty: _fmtQty,
              ),
            ),
            const SizedBox(height: 16),
            // Cost + nutrition roll-up
            _RecipeRollupCard(ingredients: _recipeIngredients, fmtQty: _fmtQty),
            const SizedBox(height: 16),
          ],

          // Ingredient picker
          _IngredientPickerCard(
            loading: _loadingInventory,
            inventory: _filteredInventory,
            addedIds: _recipeIngredients.map((e) => e.item.id).toSet(),
            searchCtrl: _ingredSearchCtrl,
            onSearchChanged: (v) => setState(() => _ingredientSearch = v),
            onAdd: _addIngredient,
            onReload: _loadInventory,
          ),
        ],

        if (!_hasRecipe)
          _InfoBox(
            emoji: '💡',
            text:
                'You can add a recipe later. The menu item will be saved without one.',
          ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saveError != null) ...[
            _ErrorBanner(
              msg: _saveError!,
              onDismiss: () => setState(() => _saveError = null),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (_currentStep > 0) ...[
                _OutlineButton(label: 'Back', onTap: _prevStep),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: isLast
                    ? _PrimaryButton(
                        label: _isEdit
                            ? 'Save Changes'
                            : 'Create Item & Recipe',
                        icon: Icons.check_rounded,
                        color: _C.teal,
                        isLoading: _isSaving,
                        onTap: _isSaving ? null : _save,
                      )
                    : _PrimaryButton(
                        label: _currentStep == 0
                            ? 'Next: Nutrition & Allergens'
                            : 'Next: Recipe Builder',
                        icon: Icons.arrow_forward_rounded,
                        color: _C.brand,
                        onTap: _nextStep,
                      ),
              ),
              if (_currentStep == 0) ...[
                const SizedBox(width: 10),
                _OutlineButton(
                  label: 'Save Now',
                  isLoading: _isSaving,
                  onTap: _isSaving ? null : _save,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────
  Widget _lbl(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _C.textSec,
      letterSpacing: 0.2,
    ),
  );

  Widget _tf({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    textCapitalization: capitalization,
    style: const TextStyle(
      fontSize: 14,
      color: _C.textPri,
      fontWeight: FontWeight.w500,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _C.textMut, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: _C.textMut),
      filled: true,
      fillColor: _C.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.danger, width: 1.5),
      ),
    ),
  );
} // end State

// ══════════════════════════════════════════════════════════════
//  SECTION CARD  — coloured header card wrapper
// ══════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
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

// ══════════════════════════════════════════════════════════════
//  NUTRITION FIELD  — compact labelled input
// ══════════════════════════════════════════════════════════════
class _NutritionField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, unit, emoji;
  final Color color;

  const _NutritionField({
    required this.ctrl,
    required this.label,
    required this.unit,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Text(unit, style: const TextStyle(fontSize: 10, color: _C.textMut)),
        ],
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '—',
          hintStyle: const TextStyle(color: _C.textMut, fontSize: 13),
          filled: true,
          fillColor: color.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  NUTRITION PREVIEW BAR
// ══════════════════════════════════════════════════════════════
class _NutritionPreviewBar extends StatelessWidget {
  final int? calories;
  final double? protein, carbs, fat;

  const _NutritionPreviewBar({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final total = (protein ?? 0) + (carbs ?? 0) + (fat ?? 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroChip(
                label: 'Calories',
                value: calories?.toString() ?? '—',
                unit: 'kcal',
                color: const Color(0xFFEA580C),
              ),
              _MacroChip(
                label: 'Protein',
                value: protein != null ? '${protein!.toStringAsFixed(1)}' : '—',
                unit: 'g',
                color: const Color(0xFF3B82F6),
              ),
              _MacroChip(
                label: 'Carbs',
                value: carbs != null ? '${carbs!.toStringAsFixed(1)}' : '—',
                unit: 'g',
                color: const Color(0xFFF59E0B),
              ),
              _MacroChip(
                label: 'Fat',
                value: fat != null ? '${fat!.toStringAsFixed(1)}' : '—',
                unit: 'g',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if ((protein ?? 0) > 0)
                    Expanded(
                      flex: ((protein! / total) * 100).round(),
                      child: Container(
                        height: 6,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  if ((carbs ?? 0) > 0)
                    Expanded(
                      flex: ((carbs! / total) * 100).round(),
                      child: Container(
                        height: 6,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  if ((fat ?? 0) > 0)
                    Expanded(
                      flex: ((fat! / total) * 100).round(),
                      child: Container(
                        height: 6,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MacroLegend(color: const Color(0xFF3B82F6), label: 'Protein'),
                const SizedBox(width: 12),
                _MacroLegend(color: const Color(0xFFF59E0B), label: 'Carbs'),
                const SizedBox(width: 12),
                _MacroLegend(color: const Color(0xFFEF4444), label: 'Fat'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.5,
        ),
      ),
      Text(unit, style: const TextStyle(fontSize: 9, color: Colors.white54)),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

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
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  ALLERGEN CHIP
// ══════════════════════════════════════════════════════════════
class _AllergenChip extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;

  const _AllergenChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _C.dangerBg : _C.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _C.danger : _C.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _C.danger : _C.textSec,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check_circle_rounded, size: 13, color: _C.danger),
          ],
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  INGREDIENT TILE  — qty + dynamic unit selector
// ══════════════════════════════════════════════════════════════
class _IngredientTileWidget extends StatefulWidget {
  final RecipeIngredientEntry entry;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<String> onQtyChanged;
  final ValueChanged<String> onUnitChanged;
  final String Function(double) fmtQty;

  const _IngredientTileWidget({
    required this.entry,
    required this.index,
    required this.onRemove,
    required this.onQtyChanged,
    required this.onUnitChanged,
    required this.fmtQty,
  });

  @override
  State<_IngredientTileWidget> createState() => _IngredientTileWidgetState();
}

class _IngredientTileWidgetState extends State<_IngredientTileWidget> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.entry.requiredQty > 0
          ? widget.fmtQty(widget.entry.requiredQty)
          : '',
    );
    _notesCtrl = TextEditingController(text: widget.entry.notes);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final hasError = e.error != null;
    final isValid = e.isValid;
    final units = _compatibleUnits(e.item.unit);
    final baseUnit = _unitLabel(e.item.unit);
    final stockStr = widget.fmtQty(e.item.currentStock);
    final remaining = e.item.currentStock - e.qtyInBaseUnit;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? _C.danger
              : isValid
              ? _C.success
              : _C.border,
          width: (hasError || isValid) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                // Emoji + name + availability
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    e.item.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _C.textPri,
                        ),
                      ),
                      Text(
                        'Stock: $stockStr $baseUnit  •  ₹${e.item.costPerUnit}/$baseUnit',
                        style: const TextStyle(fontSize: 11, color: _C.textSec),
                      ),
                    ],
                  ),
                ),
                // Remove
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _C.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _C.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Qty + unit row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                const Text(
                  'Qty:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.textSec,
                  ),
                ),
                const SizedBox(width: 8),
                // Quantity input
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: widget.onQtyChanged,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: hasError ? _C.danger : _C.textPri,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: _C.textMut),
                      filled: true,
                      fillColor: hasError
                          ? _C.dangerBg
                          : isValid
                          ? _C.successBg
                          : _C.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: hasError
                              ? _C.danger
                              : isValid
                              ? _C.success
                              : _C.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: hasError
                              ? _C.danger
                              : isValid
                              ? _C.success
                              : _C.border,
                          width: (hasError || isValid) ? 1.5 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: hasError ? _C.danger : _C.brand,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dynamic unit dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _C.tealLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.teal.withOpacity(0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: e.selectedUnit,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.teal,
                      ),
                      dropdownColor: _C.surface,
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: _C.teal,
                      ),
                      items: units
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                u,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _C.teal,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (u) {
                        if (u != null) widget.onUnitChanged(u);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                // Cost estimate
                if (e.isValid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _C.brandLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${(e.item.costPerUnit * e.qtyInBaseUnit).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.brand,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Error / success feedback ────────────────────────
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _C.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: _C.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isValid)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: _C.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'After use: ${widget.fmtQty(remaining)} $baseUnit remaining',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Ingredient notes ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextFormField(
              controller: _notesCtrl,
              style: const TextStyle(fontSize: 12, color: _C.textSec),
              onChanged: (v) => e.notes = v,
              decoration: InputDecoration(
                hintText: 'Ingredient note (e.g. finely chopped, roasted)...',
                hintStyle: const TextStyle(color: _C.textMut, fontSize: 12),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: _C.textMut,
                ),
                filled: true,
                fillColor: _C.bg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.teal, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RECIPE ROLLUP CARD  — totals summary
// ══════════════════════════════════════════════════════════════
class _RecipeRollupCard extends StatelessWidget {
  final List<RecipeIngredientEntry> ingredients;
  final String Function(double) fmtQty;

  const _RecipeRollupCard({required this.ingredients, required this.fmtQty});

  @override
  Widget build(BuildContext context) {
    final totalCost = ingredients.fold<double>(
      0,
      (s, e) => s + (e.item.costPerUnit * e.qtyInBaseUnit),
    );
    final validCount = ingredients.where((e) => e.isValid).length;
    final totalCount = ingredients.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5282)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recipe Summary',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${totalCost.toStringAsFixed(2)} estimated cost',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$validCount / $totalCount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'validated',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: validCount / totalCount,
                minHeight: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  validCount == totalCount ? _C.success : _C.brand,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INGREDIENT PICKER CARD
// ══════════════════════════════════════════════════════════════
class _IngredientPickerCard extends StatelessWidget {
  final bool loading;
  final List<InventoryItem> inventory;
  final Set<String> addedIds;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InventoryItem> onAdd;
  final VoidCallback onReload;

  const _IngredientPickerCard({
    required this.loading,
    required this.inventory,
    required this.addedIds,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _C.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _C.tealLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add from Inventory',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.teal,
                      ),
                    ),
                    Text(
                      'Only items with available stock shown',
                      style: TextStyle(fontSize: 11, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onReload,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: _C.teal,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search ingredients by name or category...',
                hintStyle: const TextStyle(color: _C.textMut, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _C.textMut,
                ),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _C.textMut,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: _C.bg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.teal, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        // List
        if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _C.teal)),
          )
        else if (inventory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 36,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  searchCtrl.text.isNotEmpty
                      ? 'No items match "${searchCtrl.text}"'
                      : 'No inventory items with available stock',
                  style: const TextStyle(fontSize: 13, color: _C.textMut),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: inventory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final item = inventory[i];
                return _InventoryPickerRow(
                  item: item,
                  isAdded: addedIds.contains(item.id),
                  onAdd: () => onAdd(item),
                );
              },
            ),
          ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  INVENTORY PICKER ROW
// ══════════════════════════════════════════════════════════════
class _InventoryPickerRow extends StatelessWidget {
  final InventoryItem item;
  final bool isAdded;
  final VoidCallback onAdd;

  const _InventoryPickerRow({
    required this.item,
    required this.isAdded,
    required this.onAdd,
  });

  Color get _statusColor {
    switch (item.status) {
      case StockStatus.inStock:
        return _C.success;
      case StockStatus.lowStock:
        return _C.warning;
      case StockStatus.critical:
        return _C.danger;
      default:
        return _C.textMut;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUnit = _unitLabel(item.unit);
    final stockStr = item.currentStock == item.currentStock.truncateToDouble()
        ? item.currentStock.toInt().toString()
        : item.currentStock.toStringAsFixed(2);
    final units = _compatibleUnits(item.unit);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAdded ? _C.tealLight : _C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAdded ? _C.teal : _C.border,
          width: isAdded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.textPri,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$stockStr $baseUnit',
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${item.category}  · ₹${item.costPerUnit}/$baseUnit',
                      style: const TextStyle(fontSize: 10, color: _C.textMut),
                    ),
                  ],
                ),
                // Show compatible units as small chips
                if (units.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Text(
                          'Units: ',
                          style: TextStyle(fontSize: 10, color: _C.textMut),
                        ),
                        ...units.map(
                          (u) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _C.teal.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _C.teal.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              u,
                              style: const TextStyle(
                                fontSize: 9,
                                color: _C.teal,
                                fontWeight: FontWeight.w700,
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isAdded
                ? Container(
                    key: const ValueKey('added'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _C.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Added',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('add'),
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _C.tealLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.teal.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: _C.teal, size: 13),
                          SizedBox(width: 3),
                          Text(
                            'Add',
                            style: TextStyle(
                              color: _C.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RECIPE TOGGLE BANNER
// ══════════════════════════════════════════════════════════════
class _RecipeToggleBannerWidget extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;
  const _RecipeToggleBannerWidget({
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: enabled
            ? const [Color(0xFF065F46), Color(0xFF047857)]
            : [_C.surface, _C.surfaceAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: enabled ? _C.teal : _C.border,
        width: enabled ? 0 : 1,
      ),
      boxShadow: enabled
          ? [
              BoxShadow(
                color: _C.teal.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : [],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: enabled ? Colors.white.withOpacity(0.15) : _C.tealLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            enabled ? '🧪' : '🍳',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enabled ? 'Recipe Builder Active' : 'Add a Recipe?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : _C.textPri,
                ),
              ),
              Text(
                enabled
                    ? 'Ingredients deducted from inventory on save'
                    : 'Link inventory ingredients to this dish',
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.white.withOpacity(0.75) : _C.textSec,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onToggle,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withOpacity(0.3),
          inactiveThumbColor: _C.textMut,
          inactiveTrackColor: _C.border,
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  IMAGE PICKER
// ══════════════════════════════════════════════════════════════
class _ImagePickerWidget extends StatelessWidget {
  final File? imageFile;
  final String? existingUrl;
  final VoidCallback onTap;
  const _ImagePickerWidget({
    this.imageFile,
    this.existingUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = imageFile != null || existingUrl != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: has ? _C.brand.withOpacity(0.4) : _C.border,
            width: has ? 1.5 : 1,
          ),
        ),
        child: has
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageFile != null
                        ? Image.file(imageFile!, fit: BoxFit.cover)
                        : Image.network(existingUrl!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add item photo',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  Text(
                    'JPEG / PNG up to 5 MB',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VEG TOGGLE
// ══════════════════════════════════════════════════════════════
class _VegToggleWidget extends StatelessWidget {
  final bool isVeg;
  final ValueChanged<bool> onChanged;
  const _VegToggleWidget({required this.isVeg, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _VegOpt(
        label: 'Vegetarian',
        dot: const Color(0xFF16A34A),
        selected: isVeg,
        onTap: () => onChanged(true),
      ),
      const SizedBox(width: 10),
      _VegOpt(
        label: 'Non-Veg',
        dot: const Color(0xFFB91C1C),
        selected: !isVeg,
        onTap: () => onChanged(false),
      ),
    ],
  );
}

class _VegOpt extends StatelessWidget {
  final String label;
  final Color dot;
  final bool selected;
  final VoidCallback onTap;
  const _VegOpt({
    required this.label,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? dot.withOpacity(0.08) : _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? dot : _C.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? dot : _C.textSec,
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  RATING SLIDER
// ══════════════════════════════════════════════════════════════
class _RatingSliderWidget extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _RatingSliderWidget({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _C.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.amber,
              inactiveTrackColor: _C.border,
              thumbColor: Colors.amber,
              overlayColor: Colors.amber.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 5,
              divisions: 8,
              onChanged: onChanged,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  FLAG CHIP
// ══════════════════════════════════════════════════════════════
class _FlagChip extends StatelessWidget {
  final String emoji, label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _FlagChip({
    required this.emoji,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? activeColor.withOpacity(0.10) : _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? activeColor : _C.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? activeColor : _C.textSec,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle_rounded, size: 13, color: activeColor),
          ],
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  SHARED MICRO WIDGETS
// ══════════════════════════════════════════════════════════════
class _InfoBox extends StatelessWidget {
  final String emoji, text;
  const _InfoBox({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _C.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: _C.textSec,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.msg, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _C.dangerBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.danger.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _C.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 12, color: _C.danger),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close, size: 14, color: _C.danger),
        ),
      ],
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: onTap == null ? color.withOpacity(0.5) : color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onTap != null
            ? [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  const _OutlineButton({
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: _C.textSec,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                color: _C.textSec,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}
