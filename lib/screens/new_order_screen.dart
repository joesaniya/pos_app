// lib/screens/orders/new_order_screen.dart
// FIXES:
// 1. businessId loaded from Firebase Firestore (not SharedPreferences which was always empty)
// 2. Memory leak fixed — mounted checks before every setState after async gaps
// 3. Removed duplicate commented-out code at bottom

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/utils/ist_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/connectivity_service.dart';
import '../../database/local_database.dart';
import '../../services/inventory_deduction_service.dart';
import '../../widgets/stock_validation_dialog.dart';

class _C {
  static const bg = Color(0xFFF6F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border = Color(0xFFEAEAF4);
  static const primary = Color(0xFF5A3FD6);
  static const primaryL = Color(0xFFEDE9FF);
  static const primaryD = Color(0xFF3D2AA0);
  static const textPri = Color(0xFF1A1A2E);
  static const textSec = Color(0xFF6B6B86);
  static const textMute = Color(0xFFAAABBB);
  static const occupied = Color(0xFFDC2626);
  static const reserved = Color(0xFF7C3AED);
  static const available = Color(0xFF059669);
  static const cleaning = Color(0xFFD97706);
  static const partial = Color(0xFFE8860A);
}

// ══════════════════════════════════════════════════════════════
//  WORKFLOW STEPS — STRICT SEQUENTIAL ORDER (TABLE-FIRST DESIGN)
// ══════════════════════════════════════════════════════════════
enum OrderWorkflowStep {
  tableSelection, // Step 1: Select table (mandatory for dine-in, enforced entry point)
  seatConfirmation, // Step 2: Auto-select seats based on table occupancy & confirm
  menuSelection, // Step 3: Build cart from menu (only after table/seat confirmation)
  deliveryTiming, // Step 4: Select delivery/order timing
  orderPreview, // Step 5: Preview order with table, items, customer details
  orderPlacement, // Step 6: Place/process order
}

// ══════════════════════════════════════════════════════════════
//  NEW ORDER SCREEN
// ══════════════════════════════════════════════════════════════
class NewOrderScreen extends StatefulWidget {
  final String? preselectedTableId;
  final int? preselectedTableNumber;

  const NewOrderScreen({
    Key? key,
    this.preselectedTableId,
    this.preselectedTableNumber,
  }) : super(key: key);

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  // ── Workflow control ──────────────────────────────────────
  OrderWorkflowStep _currentStep = OrderWorkflowStep.tableSelection;

  // ── User context (from Firebase) ──────────────────────────
  String _businessId = '';
  String _businessName = '';
  String _uid = '';
  String _userName = '';
  String _userRole = '';

  // ── Menu & tables ─────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allMenuItems = [];
  List<Map<String, dynamic>> _tables = [];
  bool _menuLoading = true;
  bool _isOnline = true;
  bool _isLoadingOfflineData = false;

  // ── Cart ──────────────────────────────────────────────────
  final Map<String, CartItem> _cart = {};

  // ── Order options ─────────────────────────────────────────
  OrderType _orderType = OrderType.dineIn;
  String? _selectedTableId;
  int? _selectedTableNumber;
  String? _selectedSeatId;
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showCart = false;
  bool _placing = false;

  // ── Seat & Delivery Selection ─────────────────────────────
  bool _tableAutoSelectedSeats = false;
  String? _selectedDeliveryTiming;

  // ── Computed ──────────────────────────────────────────────
  List<CartItem> get cartItems => _cart.values.toList();
  double get cartSubtotal => cartItems.fold(0.0, (s, i) => s + i.subtotal);
  double get cartTax => cartSubtotal * 0.05;
  double get cartTotal => cartSubtotal + cartTax;
  int get cartCount => cartItems.fold(0, (s, i) => s + i.quantity);

  List<Map<String, dynamic>> get filteredItems {
    List<Map<String, dynamic>> items = _selectedCategory == 'All'
        ? _allMenuItems
        : _allMenuItems
              .where((i) => i['category_name'] == _selectedCategory)
              .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) => (i['name'] as String).toLowerCase().contains(q))
          .toList();
    }

    items.sort((a, b) {
      final aA = a['is_available'] as bool? ?? true;
      final bA = b['is_available'] as bool? ?? true;
      if (aA == bA) return 0;
      return aA ? -1 : 1;
    });
    return items;
  }

  // ══════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _selectedTableId = widget.preselectedTableId;
    _selectedTableNumber = widget.preselectedTableNumber;

    // If table is pre-selected, move to seat confirmation step
    if (_selectedTableId != null) {
      _currentStep = OrderWorkflowStep.seatConfirmation;
    }

    _setupConnectivityListener();
    _load();
  }

  void _setupConnectivityListener() {
    final connectivity = ConnectivityService.instance;
    _isOnline = connectivity.isOnline;

    connectivity.onStatusChange.listen((status) {
      if (!mounted) return;
      final wasOffline = !_isOnline;
      _isOnline = status == NetworkStatus.online;

      if (wasOffline && _isOnline) {
        // Just came online — reload fresh data from Supabase
        debugPrint('🛒 Came online, refreshing menu and tables');
        if (mounted) {
          setState(() => _menuLoading = true);
          Future.wait([_loadMenu(), _loadTables()]);
        }
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  //  LOAD — Firebase first, then Supabase
  // ══════════════════════════════════════════════════════════

  Future<void> _load() async {
    // Step 1: Load user profile from Firebase Firestore
    await _loadUserFromFirestore();

    // Step 2: Guard — don't fetch Supabase data if widget gone
    if (!mounted) return;

    if (_businessId.isEmpty) {
      debugPrint('🛒 NewOrderScreen: businessId empty after Firestore load');
      if (mounted) setState(() => _menuLoading = false);
      return;
    }

    // Step 3: Load menu + tables in parallel
    await Future.wait([_loadMenu(), _loadTables()]);
  }

  /// Load businessId, name, role from Firestore 'users' collection
  Future<void> _loadUserFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('🛒 No Firebase user logged in');
        return;
      }

      _uid = firebaseUser.uid;
      debugPrint('🛒 _loadUserFromFirestore: uid=$_uid');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (!doc.exists) {
        debugPrint('🛒 No Firestore profile for uid=$_uid');
        return;
      }

      final data = doc.data()!;
      // Don't call setState here — just update fields, widget not built yet
      _businessId = data['businessId'] as String? ?? '';
      _businessName = data['businessName'] as String? ?? '';
      _userName = data['name'] as String? ?? '';
      _userRole = data['role'] as String? ?? 'staff';

      debugPrint(
        '🛒 Firestore loaded: biz=$_businessId name=$_userName role=$_userRole',
      );
    } catch (e) {
      debugPrint('🛒 _loadUserFromFirestore ERROR: $e');
    }
  }

  Future<void> _loadMenu() async {
    if (_businessId.isEmpty) return;

    if (_isOnline) {
      // ── ONLINE: Load from Supabase ────────────────────────────────────────
      try {
        final cats = await Supabase.instance.client
            .from('menu_categories')
            .select('id, name, icon, color_hex')
            .eq('business_id', _businessId)
            .eq('is_active', true)
            .order('display_order');

        final items = await Supabase.instance.client
            .from('menu_items')
            .select(
              'id, name, description, price, discount_price, is_veg, is_available, '
              'is_featured, is_best_seller, preparation_time, category_id, '
              'menu_categories!inner(name, icon, color_hex)',
            )
            .eq('business_id', _businessId)
            .order('sort_order');

        // ── MEMORY LEAK FIX: check mounted before setState ────────────────────
        if (!mounted) return;

        // ── CACHE TO LOCAL DATABASE for offline use ────────────────────────────
        final processedItems = (items as List).map((item) {
          final cat = item['menu_categories'] as Map<String, dynamic>? ?? {};
          return {
            ...Map<String, dynamic>.from(item as Map),
            'category_name': cat['name'] ?? '',
            'category_icon': cat['icon'] ?? '🍽️',
            'category_color': cat['color_hex'] ?? '#D4673A',
          };
        }).toList();

        // Save to local DB in background (don't wait for it)
        _cacheMenuItemsLocally(processedItems);

        setState(() {
          _categories = (cats as List).cast<Map<String, dynamic>>();
          _allMenuItems = processedItems;
          _menuLoading = false;
        });
      } catch (e) {
        debugPrint('🛒 _loadMenu ERROR (Online): $e');
        // Fall back to offline
        await _loadMenuOffline();
      }
    } else {
      // ── OFFLINE: Load from LocalDatabase ──────────────────────────────────
      await _loadMenuOffline();
    }
  }

  /// Cache menu items to local database for offline use
  Future<void> _cacheMenuItemsLocally(List<Map<String, dynamic>> items) async {
    try {
      final localDb = LocalDatabase.instance;
      if (!localDb.isInitialized) await localDb.init();

      for (final item in items) {
        final itemId = item['id'] as String? ?? '';
        if (itemId.isEmpty) continue;

        // Store the full item data with category info for offline access
        await localDb.upsertEntity(
          table: LocalDatabase.tMenuItems,
          id: itemId,
          businessId: _businessId,
          data: {
            'id': item['id'],
            'name': item['name'],
            'description': item['description'],
            'price': item['price'],
            'discount_price': item['discount_price'],
            'is_veg': item['is_veg'],
            'is_available': item['is_available'],
            'is_featured': item['is_featured'],
            'is_best_seller': item['is_best_seller'],
            'preparation_time': item['preparation_time'],
            'category_id': item['category_id'],
            'category_name': item['category_name'],
            'category_icon': item['category_icon'],
            'category_color': item['category_color'],
          },
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
      }
      debugPrint(
        '🛒 Cached ${items.length} menu items to local DB for offline use',
      );
    } catch (e) {
      debugPrint('🛒 _cacheMenuItemsLocally ERROR: $e');
    }
  }

  Future<void> _loadMenuOffline() async {
    if (_businessId.isEmpty) return;
    try {
      if (!mounted) setState(() => _isLoadingOfflineData = true);

      final localDb = LocalDatabase.instance;
      if (!localDb.isInitialized) await localDb.init();

      // Load menu items from local database
      final localItems = await localDb.getEntities(
        table: LocalDatabase.tMenuItems,
        businessId: _businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      if (!mounted) return;

      if (localItems.isEmpty) {
        // No cached data available
        debugPrint('⚠️ No cached menu items found for offline mode');
        setState(() {
          _categories = [];
          _allMenuItems = [];
          _menuLoading = false;
          _isLoadingOfflineData = false;
        });
        return;
      }

      // Build categories and items from local cached data
      final categoriesSet = <String, Map<String, dynamic>>{};
      final processedItems = <Map<String, dynamic>>[];

      for (final item in localItems) {
        // Each item already has category_name, category_icon, category_color
        // from when it was cached online
        final categoryName = item['category_name'] as String? ?? 'Other';
        final categoryIcon = item['category_icon'] as String? ?? '🍽️';
        final categoryColor = item['category_color'] as String? ?? '#D4673A';

        // Store category for later
        if (!categoriesSet.containsKey(categoryName)) {
          categoriesSet[categoryName] = {
            'name': categoryName,
            'id': categoryName.toLowerCase().replaceAll(' ', '_'),
            'icon': categoryIcon,
            'color_hex': categoryColor,
          };
        }

        // Ensure all required fields exist for display
        processedItems.add({
          ...item,
          'category_name': categoryName,
          'category_icon': categoryIcon,
          'category_color': categoryColor,
        });
      }

      // Convert categories map to list
      final localCats = categoriesSet.values.toList();

      if (!mounted) return;

      setState(() {
        _categories = localCats;
        _allMenuItems = processedItems;
        _menuLoading = false;
        _isLoadingOfflineData = false;
      });

      debugPrint(
        '✅ Menu loaded offline: ${localItems.length} items, ${localCats.length} categories',
      );
    } catch (e) {
      debugPrint('🛒 _loadMenuOffline ERROR: $e');
      if (!mounted) return;
      setState(() {
        _menuLoading = false;
        _isLoadingOfflineData = false;
      });
    }
  }

  Future<void> _loadTables() async {
    if (_businessId.isEmpty) return;

    if (_isOnline) {
      // ── ONLINE: Load from Supabase ────────────────────────────────────────
      try {
        final data = await Supabase.instance.client
            .from('restaurant_tables')
            .select(
              'id, table_number, capacity, status, section, current_customer_name, table_seats(id, seat_label, status), table_reservations(id, customer_name, check_in, check_out, status)',
            )
            .eq('business_id', _businessId)
            .eq('is_active', true)
            .order('table_number');

        // ── MEMORY LEAK FIX: check mounted before setState ────────────────────
        if (!mounted) return;
        setState(() => _tables = (data as List).cast<Map<String, dynamic>>());
      } catch (e) {
        debugPrint('🛒 _loadTables ERROR (Online): $e');
        // Fall back to offline
        await _loadTablesOffline();
      }
    } else {
      // ── OFFLINE: Load from LocalDatabase ──────────────────────────────────
      await _loadTablesOffline();
    }
  }

  Future<void> _loadTablesOffline() async {
    if (_businessId.isEmpty) return;
    try {
      final localDb = LocalDatabase.instance;

      // Load tables from local database
      final localTables = await localDb.getEntities(
        table: LocalDatabase.tTables,
        businessId: _businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      if (!mounted) return;

      setState(() => _tables = localTables);
      debugPrint('🛒 Tables loaded offline: ${localTables.length} tables');
    } catch (e) {
      debugPrint('🛒 _loadTablesOffline ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CART OPERATIONS WITH INVENTORY VALIDATION
  // ══════════════════════════════════════════════════════════

  void _addItem(Map<String, dynamic> item) async {
    log('add item call:$item');
    if (!(item['is_available'] as bool? ?? true)) {
      _snack('❌ Item is not available');
      return;
    }

    final id = item['id'] as String;
    final itemName = item['name'] as String;
    final nextQuantity = _getNextQuantityForItem(id);

    // ✓ STEP 1: Validate stock before adding to cart
    debugPrint('📦 Validating stock for $itemName (qty: $nextQuantity)...');
    final inventoryService = InventoryDeductionService();
    final validation = await inventoryService.validateStock(id, nextQuantity);

    if (!mounted) return;

    if (!validation.isValid) {
      if (validation.maxAllowedQuantity == 0) {
        // ✗ NO STOCK AVAILABLE
        _snack('❌ ${validation.getUserMessage()}');
        debugPrint('❌ Item out of stock: $itemName');
        return;
      }

      // ⚠️ PARTIAL STOCK AVAILABLE — Show adjustment dialog
      debugPrint(
        '⚠️ Partial stock for $itemName: can make ${validation.maxAllowedQuantity}',
      );

      final adjustedQuantity = await _showAdjustmentDialog(
        itemName: itemName,
        requestedQuantity: nextQuantity,
        validationResult: validation,
      );

      if (!mounted || adjustedQuantity == null || adjustedQuantity <= 0) {
        debugPrint('ℹ️ User cancelled adjustment');
        return;
      }

      // ✓ User adjusted — add with new quantity
      setState(() {
        _cart[id] = CartItem(
          menuItemId: id,
          itemName: itemName,
          itemPrice: (item['discount_price'] ?? item['price'] as num)
              .toDouble(),
          categoryName: item['category_name'] as String?,
          isVeg: item['is_veg'] as bool? ?? true,
          quantity: adjustedQuantity,
        );
      });

      _snack('✅ Added $adjustedQuantity $itemName to cart (stock limited)');
      return;
    }

    // ✅ STOCK IS SUFFICIENT — Add to cart normally
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity + 1);
      } else {
        _cart[id] = CartItem(
          menuItemId: id,
          itemName: itemName,
          itemPrice: (item['discount_price'] ?? item['price'] as num)
              .toDouble(),
          categoryName: item['category_name'] as String?,
          isVeg: item['is_veg'] as bool? ?? true,
        );
      }
    });

    _snack('✅ Added to cart');
  }

  int _getNextQuantityForItem(String menuItemId) {
    return (_cart[menuItemId]?.quantity ?? 0) + 1;
  }

  /// Show adjustment dialog and return the adjusted quantity (or null if cancelled)
  Future<int?> _showAdjustmentDialog({
    required String itemName,
    required int requestedQuantity,
    required StockValidationResult validationResult,
  }) async {
    return showStockValidationDialog(
      context,
      itemName: itemName,
      requestedQuantity: requestedQuantity,
      validationResult: validationResult,
      onAdjusted: () {
        // Callback when user clicks "Adjust"
        debugPrint('✅ User accepted adjustment to max quantity');
      },
    ).then((accepted) {
      if (accepted == true) {
        return validationResult.maxAllowedQuantity;
      }
      return null;
    });
  }

  void _removeItem(String id) {
    setState(() {
      if (!_cart.containsKey(id)) return;
      if (_cart[id]!.quantity <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity - 1);
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  TABLE SELECTION MODAL
  // ══════════════════════════════════════════════════════════

  /// Opens table selection modal for dine-in orders
  void _showTableSelectionModal() {
    if (_orderType != OrderType.dineIn) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        color: _C.surface,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Table for Dine-In Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _C.textPri,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please choose a table to proceed',
              style: TextStyle(fontSize: 13, color: _C.textSec),
            ),
            const SizedBox(height: 20),
            if (_tables.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tables available',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _tables.map((t) {
                      final tid = t['id'] as String;
                      final num = t['table_number'] as int;
                      final cap = t['capacity'] as int;
                      final status = t['status'] as String? ?? 'available';
                      final canSelect = _tableIsSelectable(status);
                      final sColor = _tableStatusColor(status);

                      return GestureDetector(
                        onTap: canSelect
                            ? () {
                                setState(() {
                                  _selectedTableId = tid;
                                  _selectedTableNumber = num;
                                  _selectedSeatId = null;
                                });
                                Navigator.pop(ctx);
                              }
                            : null,
                        child: Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: !canSelect
                                ? const Color(0xFFF5F5F5)
                                : sColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !canSelect
                                  ? const Color(0xFFDDDDDD)
                                  : sColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tableStatusEmoji(status),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'T$num',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: !canSelect ? _C.textMute : sColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$cap seats',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: !canSelect ? _C.textMute : sColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_selectedTableId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Confirm Selection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _C.textMute.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Select a table to continue',
                      style: TextStyle(
                        color: _C.textMute,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PLACE ORDER WITH INVENTORY VALIDATION & DEDUCTION
  // ══════════════════════════════════════════════════════════



  // ══════════════════════════════════════════════════════════
  //  PLACE ORDER WITH INVENTORY VALIDATION & DEDUCTION
  // ══════════════════════════════════════════════════════════

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      _snack('🛒 Add items to cart first');
      return;
    }
    if (_orderType == OrderType.dineIn && _selectedTableId == null) {
      _snack('📍 Please select a table before placing order');
      return;
    }

    // Synchronous guard — must be set BEFORE any await to prevent double-fire
    if (_placing) return;
    _placing = true;
    if (mounted) setState(() {});

    try {
      // ✓ STEP 1: Final inventory validation before order placement
      debugPrint('🔐 Validating inventory before order placement...');
      final inventoryService = InventoryDeductionService();
      bool hasStockIssue = false;
      String? stockIssueItem;

      for (final item in cartItems) {
        final validation = await inventoryService.validateStock(
          item.menuItemId,
          item.quantity,
        );

        if (!validation.isValid) {
          hasStockIssue = true;
          stockIssueItem = item.itemName;

          // Show detailed error popup instead of just throwing
          if (mounted) {
            final shouldRetry =
                await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Stock Changed!'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The stock for ${item.itemName} has been updated since you added it to cart.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (validation.maxAllowedQuantity > 0)
                          Text(
                            'You can prepare a maximum of ${validation.maxAllowedQuantity} items.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                          )
                        else
                          Text(
                            'This item is now out of stock.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel Order'),
                      ),
                      if (validation.maxAllowedQuantity > 0)
                        ElevatedButton(
                          onPressed: () {
                            // Adjust cart and retry
                            setState(() {
                              if (validation.maxAllowedQuantity > 0) {
                                final cartItem = _cart[item.menuItemId];
                                if (cartItem != null) {
                                  _cart[item.menuItemId] = cartItem.copyWith(
                                    quantity: validation.maxAllowedQuantity,
                                  );
                                }
                              }
                            });
                            Navigator.pop(ctx, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: Text(
                            'Adjust to ${validation.maxAllowedQuantity}',
                          ),
                        ),
                    ],
                  ),
                ) ??
                false;

            if (shouldRetry) {
              // Retry the whole process
              _placing = false;
              if (mounted) setState(() {});
              return _placeOrder();
            }
          }

          throw Exception(
            'Stock validation failed: ${validation.getUserMessage()}',
          );
        }
      }

      if (!mounted) return;

      // ✓ STEP 2: Create order
      debugPrint('📝 Creating order...');
      final prov = context.read<OrdersProvider>();
      final order = await prov.createOrder(
        cartItems: cartItems,
        orderType: _orderType,
        tableId: _selectedTableId,
        tableNumber: _selectedTableNumber,
        tableSeatId: _selectedSeatId,
        customerName: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (!mounted) return;

      // ✓ STEP 3: Deduct inventory after successful order creation
      debugPrint('📦 Deducting inventory for order ${order.id}...');
      if (_isOnline) {
        try {
          await inventoryService.deductInventoryForOrder(
            order.id,
            order.orderNumber,
            _businessId,
            cartItems
                .map(
                  (c) => {
                    'menu_item_id': c.menuItemId,
                    'item_name': c.itemName,
                    'quantity': c.quantity,
                  },
                )
                .toList(),
          );
          debugPrint('✅ Inventory deducted successfully for order ${order.id}');
        } catch (e) {
          debugPrint(
            '⚠️  Inventory deduction failed (order still created): $e',
          );
          if (mounted) {
            _snack(
              '⚠️  Order #${order.orderNumber} created but inventory deduction failed. Will retry when online.',
            );
          }
        }
      } else {
        debugPrint(
          '⚠️  Offline mode: Inventory deduction will be performed when online',
        );
      }

      // ✓ STEP 4: Refresh InventoryProvider to show updated quantities immediately
      if (mounted && _isOnline) {
        try {
          final inventoryProv = context.read<InventoryProvider>();
          await inventoryProv.fetchItems();
          debugPrint(
            '✅ InventoryProvider refreshed — UI will show updated quantities',
          );
        } catch (e) {
          debugPrint('⚠️  Failed to refresh InventoryProvider UI: $e');
          // Failure is non-critical — real-time listeners will catch updates
        }
      }

      if (mounted) {
        if (!_isOnline) {
          _snack('✅ Order created offline. Will sync when online.');
        } else {
          _snack('✅ Order #${order.orderNumber} placed & inventory updated');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      final msg = _isOnline
          ? 'Failed to place order: $e'
          : 'Offline: Could not create order: $e';
      _snack(msg);
      debugPrint('❌ Order placement error: $e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD — MAIN ENTRY POINT — ENFORCES WORKFLOW SEQUENCE
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Only allow back if at first step (table selection)
        if (_currentStep == OrderWorkflowStep.tableSelection) {
          return true; // Allow exit
        }
        // Otherwise, go back one step
        _stepBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header with back button and cart toggle ──────────────────
              _buildHeader(),

              // ── Main content area — changes based on workflow step ────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Control: Back button behavior based on workflow step
  void _stepBack() {
    setState(() {
      switch (_currentStep) {
        case OrderWorkflowStep.seatConfirmation:
          // Go back to table selection
          _currentStep = OrderWorkflowStep.tableSelection;
          _selectedTableId = null;
          _selectedTableNumber = null;
          _selectedSeatId = null;
          _tableAutoSelectedSeats = false;
          break;
        case OrderWorkflowStep.menuSelection:
          // Go back to seat confirmation
          _currentStep = OrderWorkflowStep.seatConfirmation;
          _cart.clear();
          break;
        case OrderWorkflowStep.deliveryTiming:
          // Go back to menu selection
          _currentStep = OrderWorkflowStep.menuSelection;
          _showCart = false;
          break;
        case OrderWorkflowStep.orderPreview:
          // Go back to delivery timing
          _currentStep = OrderWorkflowStep.deliveryTiming;
          _showCart = false;
          break;
        case OrderWorkflowStep.orderPlacement:
          // Go back to order preview
          _currentStep = OrderWorkflowStep.orderPreview;
          break;
        case OrderWorkflowStep.tableSelection:
          // Already at first step — exit handled by WillPopScope
          break;
      }
    });
  }

  /// Build content based on current workflow step
  Widget _buildStepContent() {
    switch (_currentStep) {
      case OrderWorkflowStep.tableSelection:
        return _buildTableSelectionStep();

      case OrderWorkflowStep.seatConfirmation:
        return _buildSeatConfirmationStep();

      case OrderWorkflowStep.menuSelection:
        return _buildMenuSelectionStep();

      case OrderWorkflowStep.deliveryTiming:
        return _buildDeliveryTimingStep();

      case OrderWorkflowStep.orderPreview:
        return _buildOrderPreviewStep();

      case OrderWorkflowStep.orderPlacement:
        // This is usually not shown as a separate screen — orders are placed
        // and flow exits. But keep it for safety.
        return const Center(
          child: CircularProgressIndicator(color: _C.primary),
        );
    }
  }

  /// STEP 1: Table Selection (mandatory entry point, no menu shown)
  Widget _buildTableSelectionStep() {
    return Column(
      children: [
        Container(
          color: _C.surface,
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Text(
                '📍 Step 1: Select Table',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              Spacer(),
              Chip(
                label: Text('Mandatory', style: TextStyle(fontSize: 11)),
                backgroundColor: Color(0xFFDC2626),
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildTableSelectionFooter(),
        ),
      ],
    );
  }

  /// STEP 2: Seat Confirmation (after table auto-selection)
  Widget _buildSeatConfirmationStep() {
    if (_selectedTableId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: _C.textMute),
            const SizedBox(height: 16),
            const Text(
              'Table not selected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPri),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _stepBack(),
              child: const Text(
                'Go back and select a table',
                style: TextStyle(fontSize: 13, color: _C.primary),
              ),
            ),
          ],
        ),
      );
    }

    final table = _tables.firstWhere(
      (t) => t['id'] == _selectedTableId,
      orElse: () => {},
    );
    final tableNumber = _selectedTableNumber ?? 0;
    final seats = (table['table_seats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final occupiedSeats = seats.where((s) => s['status'] == 'occupied').toList();
    final isFullyOccupied = seats.isNotEmpty && occupiedSeats.length == seats.length;
    final isPartiallyOccupied = occupiedSeats.isNotEmpty && occupiedSeats.length < seats.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.primaryL,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.primary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '🪑',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 2: Confirm Seat Selection',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.textPri,
                        ),
                      ),
                      Text(
                        'Table T$tableNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _C.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isFullyOccupied)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: _C.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Table is fully occupied. New order will be for the entire table.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPartiallyOccupied)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: _C.partial, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Table is partially occupied. Auto-selected first occupied seat.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.partial,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: _C.available, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Table is available. You can book the entire table or individual seats.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.available,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Seat Selection
        if (seats.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.primaryL,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No individual seats defined. Entire table is reserved for this order.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Seat(s)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_selectedSeatId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.primary),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Whole Table',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...seats.map((seat) {
                      final seatId = seat['id'] as String;
                      final seatLabel = seat['seat_label'] as String? ?? 'Unknown';
                      final seatStatus = seat['status'] as String? ?? 'available';
                      final isSelected = _selectedSeatId == seatId;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedSeatId = seatId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? _C.primary : _C.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _C.primary : _C.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.check_circle, color: Colors.white, size: 16),
                                ),
                              Text(
                                'Seat $seatLabel',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : _C.textPri,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                seatStatus == 'occupied' ? '🍽️' : '✅',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ],
          ),
        const SizedBox(height: 20),

        // Edit Selection Option
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: GestureDetector(
            onTap: () => setState(() => _currentStep = OrderWorkflowStep.tableSelection),
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, color: _C.textSec, size: 16),
                SizedBox(width: 8),
                Text(
                  'Change table selection',
                  style: TextStyle(
                    fontSize: 12,
                    color: _C.textSec,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Confirm Button
        GestureDetector(
          onTap: _proceedToMenuSelection,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Confirm & Browse Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// STEP 4: Delivery/Order Timing Selection
  Widget _buildDeliveryTimingStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          color: _C.surface,
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Text(
                '⏰ Step 4: Order Timing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              Spacer(),
              Chip(
                label: Text('Select', style: TextStyle(fontSize: 11)),
                backgroundColor: Color(0xFF059669),
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'When should this order be prepared?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _C.textPri,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _selectedDeliveryTiming = 'now'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _selectedDeliveryTiming == 'now' ? _C.primaryL : _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDeliveryTiming == 'now' ? _C.primary : _C.border,
                width: _selectedDeliveryTiming == 'now' ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: _selectedDeliveryTiming == 'now' ? _C.primary : _C.textSec,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prepare Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedDeliveryTiming == 'now' ? _C.primary : _C.textPri,
                        ),
                      ),
                      Text(
                        'Immediate preparation',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedDeliveryTiming == 'now' ? _C.primary : _C.textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedDeliveryTiming == 'now')
                  Icon(
                    Icons.check_circle,
                    color: _C.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Proceed to Preview Button
        GestureDetector(
          onTap: () {
            if (_selectedDeliveryTiming == null) {
              _snack('⏰ Please select order timing');
              return;
            }
            _proceedToOrderPreview();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _selectedDeliveryTiming != null ? _C.primary : _C.textMute.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _selectedDeliveryTiming != null ? Colors.white : _C.textMute,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Review Order',
                  style: TextStyle(
                    color: _selectedDeliveryTiming != null ? Colors.white : _C.textMute,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Table selection footer — shows available tables
  Widget _buildTableSelectionFooter() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: _C.border),
          const SizedBox(height: 12),
          const Text(
            'Select a Table to Begin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _C.textPri,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a table to start a new order',
            style: TextStyle(fontSize: 13, color: _C.textSec),
          ),
          const SizedBox(height: 16),
          if (_tables.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                ),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No tables available',
                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tables.map((t) {
                  final tid = t['id'] as String;
                  final num = t['table_number'] as int;
                  final cap = t['capacity'] as int;
                  final status = t['status'] as String? ?? 'available';
                  final canSelect = _tableIsSelectable(status);
                  final sColor = _tableStatusColor(status);
                  final isSelected = _selectedTableId == tid;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: canSelect ? () => _selectTable(tid, num) : null,
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: !canSelect
                              ? const Color(0xFFF5F5F5)
                              : isSelected
                              ? _C.primaryL
                              : sColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !canSelect
                                ? const Color(0xFFDDDDDD)
                                : isSelected
                                ? _C.primary
                                : sColor.withOpacity(0.5),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tableStatusEmoji(status),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'T$num',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: !canSelect
                                    ? _C.textMute
                                    : isSelected
                                    ? _C.primary
                                    : sColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$cap seats',
                              style: TextStyle(
                                fontSize: 10,
                                color: !canSelect ? _C.textMute : sColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          if (_selectedTableId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onTap: () => _proceedToSeatConfirmation(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirm & Select Seats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _C.textMute.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select a table to continue',
                    style: TextStyle(
                      color: _C.textMute,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Select table and enable confirmation
  void _selectTable(String tableId, int tableNumber) {
    setState(() {
      _selectedTableId = tableId;
      _selectedTableNumber = tableNumber;
      _selectedSeatId = null;
    });
  }

  /// Proceed from table selection to seat confirmation
  void _proceedToSeatConfirmation() {
    setState(() {
      _currentStep = OrderWorkflowStep.seatConfirmation;
      _showCart = false;
      // Auto-select seats based on table occupancy
      _autoSelectSeatsForTable();
    });
  }

  /// Auto-select seats based on table occupancy status
  void _autoSelectSeatsForTable() {
    if (_selectedTableId == null) return;

    final table = _tables.firstWhere(
      (t) => t['id'] == _selectedTableId,
      orElse: () => {},
    );

    if (table.isEmpty) return;

    final seats = (table['table_seats'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (seats.isEmpty) {
      // No seats defined — set to null (whole table)
      _selectedSeatId = null;
      _tableAutoSelectedSeats = true;
      return;
    }

    // Check occupancy: count occupied seats
    final occupiedSeats = seats.where((s) => s['status'] == 'occupied').toList();
    final totalSeats = seats.length;
    final isFullyOccupied = occupiedSeats.length == totalSeats;
    final isPartiallyOccupied = occupiedSeats.isNotEmpty && occupiedSeats.length < totalSeats;

    if (isFullyOccupied) {
      // Fully occupied: entire table is the order destination
      _selectedSeatId = null;
      _tableAutoSelectedSeats = true;
    } else if (isPartiallyOccupied) {
      // Partially occupied: auto-select first occupied seat for placing additional order
      final firstOccupiedSeat = occupiedSeats.first;
      _selectedSeatId = firstOccupiedSeat['id'] as String?;
      _tableAutoSelectedSeats = true;
    } else {
      // Available table: no auto-selection needed
      _selectedSeatId = null;
      _tableAutoSelectedSeats = false;
    }
  }

  /// Proceed from seat confirmation to menu selection
  void _proceedToMenuSelection() {
    setState(() {
      _currentStep = OrderWorkflowStep.menuSelection;
      _showCart = false;
    });
  }

  /// Proceed from menu selection to delivery timing
  void _proceedToDeliveryTiming() {
    if (_cart.isEmpty) {
      _snack('🛒 Add items to cart first');
      return;
    }
    setState(() {
      _currentStep = OrderWorkflowStep.deliveryTiming;
      _showCart = false;
    });
  }

  /// Proceed from delivery timing to order preview
  void _proceedToOrderPreview() {
    setState(() {
      _currentStep = OrderWorkflowStep.orderPreview;
    });
  }

  /// STEP 2: Menu Selection & Cart Building
  Widget _buildMenuSelectionStep() {
    return Column(
      children: [
        Container(
          color: _C.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '🍽️ Step 3: Browse Menu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              Spacer(),
              if (_selectedTableNumber != null)
                Chip(
                  label: Text(
                    'Table T${_selectedTableNumber}${_selectedSeatId != null ? ' • Seat' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _C.primary,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _showCart
              ? _CartView(
                  key: const ValueKey('cart_in_menu_step'),
                  cartItems: cartItems,
                  orderType: _orderType,
                  tables: _tables,
                  selectedTableId: _selectedTableId,
                  selectedSeatId: _selectedSeatId,
                  customerCtrl: _customerCtrl,
                  phoneCtrl: _phoneCtrl,
                  noteCtrl: _noteCtrl,
                  cartSubtotal: cartSubtotal,
                  cartTax: cartTax,
                  cartTotal: cartTotal,
                  placing: _placing,
                  onTypeChanged: (t) {
                    setState(() => _orderType = t);
                  },
                  onTableSelected: (id, num) => setState(() {
                    if (_selectedTableId != id) {
                      _selectedSeatId = null;
                    }
                    _selectedTableId = id;
                    _selectedTableNumber = num;
                  }),
                  onSeatSelected: (id) => setState(() {
                    _selectedSeatId = id;
                  }),
                  onAdd: _addItem,
                  onRemove: (id) => _removeItem(id),
                  onPlaceOrder: _proceedToDeliveryTiming,
                  showBackButton: true,
                  onBack: () => setState(() => _showCart = false),
                )
              : _MenuView(
                  key: const ValueKey('menu_in_menu_step'),
                  categories: _categories,
                  items: filteredItems,
                  selectedCategory: _selectedCategory,
                  searchCtrl: _searchCtrl,
                  cart: _cart,
                  loading: _menuLoading,
                  onCategoryChanged: (c) =>
                      setState(() => _selectedCategory = c),
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  onAdd: _addItem,
                  onRemove: (id) => _removeItem(id),
                ),
        ),
      ],
    );
  }

  /// STEP 5: Order Preview with all details
  Widget _buildOrderPreviewStep() {
    return _OrderPreviewView(
      key: const ValueKey('order_preview'),
      selectedTableId: _selectedTableId,
      selectedTableNumber: _selectedTableNumber,
      tables: _tables,
      cartItems: cartItems,
      cartSubtotal: cartSubtotal,
      cartTax: cartTax,
      cartTotal: cartTotal,
      orderType: _orderType,
      customerCtrl: _customerCtrl,
      phoneCtrl: _phoneCtrl,
      noteCtrl: _noteCtrl,
      placing: _placing,
      onTypeChanged: (t) => setState(() => _orderType = t),
      onPlaceOrder: _placeOrder,
      onBack: () =>
          setState(() => _currentStep = OrderWorkflowStep.deliveryTiming),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off, color: Color(0xFFD97706), size: 16),
                  SizedBox(width: 8),
                  Text(
                    '📵 You are offline. Orders will sync when online.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
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
                      'New Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _C.textPri,
                      ),
                    ),
                    Text(
                      _isLoadingOfflineData
                          ? 'Loading offline menu...'
                          : _isOnline
                          ? 'Select items from menu'
                          : 'Offline mode - locked data',
                      style: const TextStyle(fontSize: 11, color: _C.textSec),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showCart = !_showCart),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _showCart ? _C.primaryL : _C.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showCart
                            ? Icons.menu_book_rounded
                            : Icons.shopping_cart_outlined,
                        color: _showCart ? _C.primary : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showCart ? 'Menu' : 'Cart ($cartCount)',
                        style: TextStyle(
                          color: _showCart ? _C.primary : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!_showCart && cartTotal > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${cartTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Table status helpers ──────────────────────────────────────────

Color _tableStatusColor(String status) {
  switch (status) {
    case 'occupied':
      return _C.occupied;
    case 'reserved':
      return _C.reserved;
    case 'cleaning':
      return _C.cleaning;
    default:
      return _C.available;
  }
}

String _tableStatusEmoji(String status) {
  switch (status) {
    case 'occupied':
      return '🍽️';
    case 'reserved':
      return '📅';
    case 'cleaning':
      return '🧹';
    default:
      return '✅';
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'occupied':
      return 'Occupied';
    case 'reserved':
      return 'Reserved';
    case 'cleaning':
      return 'Cleaning';
    default:
      return 'Free';
  }
}

// available, occupied, reserved → can take order
// cleaning → cannot
bool _tableIsSelectable(String status) => status != 'cleaning';

// ══════════════════════════════════════════════════════════════
//  MENU VIEW
// ══════════════════════════════════════════════════════════════
class _MenuView extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final String selectedCategory;
  final TextEditingController searchCtrl;
  final Map<String, CartItem> cart;
  final bool loading;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onAdd;
  final ValueChanged<String> onRemove;
  final Widget? footerWidget;

  const _MenuView({
    Key? key,
    required this.categories,
    required this.items,
    required this.selectedCategory,
    required this.searchCtrl,
    required this.cart,
    required this.loading,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onRemove,
    this.footerWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(child: CircularProgressIndicator(color: _C.primary));

    final unavailableCount = items
        .where((i) => !(i['is_available'] as bool? ?? true))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14, color: _C.textPri),
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _C.textMute,
                  size: 19,
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
                          color: _C.textMute,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: _C.surface,
                contentPadding: EdgeInsets.zero,
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
                  borderSide: const BorderSide(color: _C.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            children: [
              _CatChip(
                label: 'All',
                isSelected: selectedCategory == 'All',
                onTap: () => onCategoryChanged('All'),
              ),
              ...categories.map(
                (c) => _CatChip(
                  label: '${c['icon'] ?? '🍽️'} ${c['name']}',
                  isSelected: selectedCategory == c['name'],
                  onTap: () => onCategoryChanged(c['name'] as String),
                ),
              ),
            ],
          ),
        ),
        if (unavailableCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD97706).withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Text(
                  '$unavailableCount item${unavailableCount > 1 ? 's' : ''} currently unavailable',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🍽️', style: TextStyle(fontSize: 44)),
                      SizedBox(height: 12),
                      Text(
                        'No items found',
                        style: TextStyle(color: _C.textSec),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final id = item['id'] as String;
                    return _MenuTile(
                      item: item,
                      quantity: cart[id]?.quantity ?? 0,
                      onAdd: () => onAdd(item),
                      onRemove: () => onRemove(id),
                    );
                  },
                ),
        ),
        // ── Footer widget for table selection or other actions ────
        if (footerWidget != null) footerWidget!,
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.isSelected,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _C.primary : _C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _C.primary : _C.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _C.textSec,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _MenuTile({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = item['is_available'] as bool? ?? true;
    final inCart = quantity > 0;
    final isVeg = item['is_veg'] as bool? ?? true;
    final vegColor = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    final price = (item['discount_price'] ?? item['price'] as num).toDouble();
    final isBest = item['is_best_seller'] as bool? ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? _C.surface : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !isAvailable
              ? const Color(0xFFE5E5E5)
              : inCart
              ? _C.primary.withOpacity(0.4)
              : _C.border,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: (inCart && isAvailable)
            ? [
                BoxShadow(
                  color: _C.primary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Opacity(
            opacity: isAvailable ? 1.0 : 0.4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: vegColor, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: vegColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: isAvailable ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isAvailable ? _C.textPri : _C.textMute,
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '🔥 Best',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if ((item['description'] as String? ?? '').isNotEmpty)
                    Text(
                      item['description'] as String,
                      style: const TextStyle(fontSize: 11, color: _C.textMute),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    item['category_name'] as String? ?? '',
                    style: const TextStyle(fontSize: 10, color: _C.textMute),
                  ),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: isAvailable ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item['discount_price'] != null)
                  Text(
                    '₹${(item['price'] as num).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.textMute,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isAvailable ? _C.textPri : _C.textMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!isAvailable)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.block,
                color: Color(0xFFAAAAAA),
                size: 16,
              ),
            )
          else if (quantity == 0)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _C.primaryL,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: _C.primary,
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  // ✓ Handle async onAdd (don't await, fire-and-forget with error capture)
                  onTap: () async {
                    try {
                      onAdd();
                    } catch (e) {
                      debugPrint('❌ Add item error: $e');
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CART VIEW
// ══════════════════════════════════════════════════════════════
class _CartView extends StatelessWidget {
  final List<CartItem> cartItems;
  final OrderType orderType;
  final List<Map<String, dynamic>> tables;
  final String? selectedTableId;
  final String? selectedSeatId;
  final TextEditingController customerCtrl, phoneCtrl, noteCtrl;
  final double cartSubtotal, cartTax, cartTotal;
  final bool placing;
  final ValueChanged<OrderType> onTypeChanged;
  final Function(String id, int num) onTableSelected;
  final Function(String? id) onSeatSelected;
  final ValueChanged<Map<String, dynamic>> onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback onPlaceOrder;
  final bool showBackButton;
  final VoidCallback? onBack;

  const _CartView({
    Key? key,
    required this.cartItems,
    required this.orderType,
    required this.tables,
    required this.selectedTableId,
    required this.selectedSeatId,
    required this.customerCtrl,
    required this.phoneCtrl,
    required this.noteCtrl,
    required this.cartSubtotal,
    required this.cartTax,
    required this.cartTotal,
    required this.placing,
    required this.onTypeChanged,
    required this.onTableSelected,
    required this.onSeatSelected,
    required this.onAdd,
    required this.onRemove,
    required this.onPlaceOrder,
    this.showBackButton = false,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛒', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text(
              'Cart is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.textPri,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Go back to add items',
              style: TextStyle(fontSize: 13, color: _C.textSec),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── ALLOCATION DISPLAY BANNER ──────────────────────────────────────
        if (orderType == OrderType.dineIn && selectedTableId != null)
          _AllocationDisplayBanner(
            tableId: selectedTableId,
            tables: tables,
            seatId: selectedSeatId,
          ),
        const SizedBox(height: 16),

        _SectionLabel('Order Type'),
        const SizedBox(height: 10),
        Row(
          children: OrderType.values.map((t) {
            final isSel = orderType == t;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSel ? _C.primaryL : _C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? _C.primary : _C.border,
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSel ? _C.primary : _C.textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        if (orderType == OrderType.dineIn) ...[
          _SectionLabel('Select Table'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: const [
                _LegendDot(color: _C.available, label: 'Available'),
                _LegendDot(color: _C.partial, label: 'Partial (seats free)'),
                _LegendDot(color: _C.occupied, label: 'Occupied (can order)'),
                _LegendDot(color: _C.reserved, label: 'Reserved (can order)'),
                _LegendDot(color: _C.cleaning, label: 'Cleaning (no order)'),
              ],
            ),
          ),
          if (tables.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                ),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No tables found',
                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: tables.map((t) {
                final tid = t['id'] as String;
                final num = t['table_number'] as int;
                final cap = t['capacity'] as int;
                final status = t['status'] as String? ?? 'available';
                final customer = t['current_customer_name'] as String?;
                final isSel = selectedTableId == tid;
                final canSelect = _tableIsSelectable(status);

                // ── Partial occupancy detection ──────────────────────
                final List<dynamic> tSeats =
                    (t['table_seats'] as List?)?.cast<dynamic>() ?? [];
                final occupiedCount = tSeats
                    .where((s) => (s as Map)['status'] == 'occupied')
                    .length;
                final isPartial =
                    tSeats.isNotEmpty &&
                    occupiedCount > 0 &&
                    occupiedCount < tSeats.length;
                final availCount = tSeats.length - occupiedCount;

                // Partial tables use amber; otherwise use status colour
                final sColor = isPartial
                    ? _C.partial
                    : _tableStatusColor(status);

                return GestureDetector(
                  onTap: canSelect ? () => onTableSelected(tid, num) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 82,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? _C.primary
                          : !canSelect
                          ? const Color(0xFFF5F5F5)
                          : isPartial
                          ? const Color(0xFFFFF4E0)
                          : sColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel
                            ? _C.primary
                            : !canSelect
                            ? const Color(0xFFDDDDDD)
                            : sColor.withOpacity(isPartial ? 0.7 : 0.5),
                        width: isSel ? 2 : (isPartial ? 1.5 : 1),
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: _C.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPartial ? '⚡' : _tableStatusEmoji(status),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'T$num',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isSel
                                ? Colors.white
                                : !canSelect
                                ? _C.textMute
                                : sColor,
                          ),
                        ),
                        // Show available/total when partial; capacity otherwise
                        Text(
                          isPartial ? '$availCount/$cap free' : '$cap seats',
                          style: TextStyle(
                            fontSize: 9,
                            color: isSel
                                ? Colors.white70
                                : isPartial
                                ? _C.partial
                                : _C.textMute,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white.withOpacity(0.2)
                                : !canSelect
                                ? const Color(0xFFEEEEEE)
                                : sColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPartial ? 'Partial' : _statusLabel(status),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.white
                                  : !canSelect
                                  ? _C.textMute
                                  : sColor,
                            ),
                          ),
                        ),
                        if (customer != null &&
                            customer.isNotEmpty &&
                            !isSel) ...[
                          const SizedBox(height: 3),
                          Text(
                            customer,
                            style: const TextStyle(
                              fontSize: 8,
                              color: _C.textMute,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (!canSelect) ...[
                          const SizedBox(height: 3),
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 10,
                            color: _C.textMute,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),

          if (selectedTableId != null) ...[
            Builder(
              builder: (context) {
                final selectedTable = tables.firstWhere(
                  (t) => t['id'] == selectedTableId,
                  orElse: () => {},
                );
                final List<dynamic> seats = selectedTable['table_seats'] ?? [];

                // ✅ Check if table has an active reservation (between check-in and check-out)
                // If reservation is active, don't show seat selection
                final tableStatus =
                    selectedTable['status'] as String? ?? 'available';
                final reservations =
                    (selectedTable['table_reservations'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final now = nowIST();

                bool isReservationActive = false;
                if (reservations.isNotEmpty && tableStatus == 'reserved') {
                  for (var reservation in reservations) {
                    final checkInStr = reservation['check_in'] as String?;
                    final checkOutStr = reservation['check_out'] as String?;

                    if (checkInStr != null && checkOutStr != null) {
                      try {
                        final checkIn = parseToIST(checkInStr);
                        final checkOut = parseToIST(checkOutStr);
                        // Check if current time is between check-in and check-out
                        if (now.isAfter(checkIn) && now.isBefore(checkOut)) {
                          isReservationActive = true;
                          break;
                        }
                      } catch (e) {
                        // If date parsing fails, continue to next reservation
                        continue;
                      }
                    }
                  }
                }

                // ✅ Don't show seat selection if reservation is currently active
                if (isReservationActive) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE8860A).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text('⏰', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Table is reserved. Seats cannot be individually selected during active reservation.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ✅ Show seat selection for all other cases
                if (seats.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.primaryL,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.primary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('ℹ️', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No individual seats defined. Booking entire table.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _C.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Select Seat (Optional)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SeatChip(
                          label: 'Whole Table',
                          isSelected: selectedSeatId == null,
                          onTap: () => onSeatSelected(null),
                        ),
                        ...seats.map((s) {
                          final sid = s['id'] as String;
                          final sl = s['seat_label'] as String;
                          final status = s['status'] as String? ?? 'available';
                          final isSel = selectedSeatId == sid;

                          return _SeatChip(
                            label: 'Seat $sl',
                            isSelected: isSel,
                            status: status,
                            onTap: () => onSeatSelected(sid),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),
          ],
        ],

        Row(
          children: [
            Expanded(
              child: _Field(
                label: 'Customer Name',
                hint: 'Enter name',
                ctrl: customerCtrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field(label: 'Phone', hint: 'Optional', ctrl: phoneCtrl),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _SectionLabel('Cart (${cartItems.length} items)'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: cartItems.asMap().entries.map((e) {
              final i = e.key;
              final ci = e.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ci.itemName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _C.textPri,
                                ),
                              ),
                              Text(
                                '₹${ci.itemPrice.toStringAsFixed(0)} each',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${ci.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _C.textPri,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => onRemove(ci.menuItemId),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: _C.primaryL,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: _C.primary,
                                  size: 14,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${ci.quantity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: _C.primary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => onAdd({
                                'id': ci.menuItemId,
                                'name': ci.itemName,
                                'price': ci.itemPrice,
                                'is_veg': ci.isVeg,
                                'category_name': ci.categoryName,
                                'is_available': true,
                              }),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: _C.primary,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i < cartItems.length - 1)
                    const Divider(height: 1, color: _C.border),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        _Field(
          label: 'Order Notes',
          hint: 'Special instructions...',
          ctrl: noteCtrl,
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.primaryL,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _BillRow('Subtotal', '₹${cartSubtotal.toStringAsFixed(0)}'),
              const SizedBox(height: 6),
              _BillRow('Tax (5%)', '₹${cartTax.toStringAsFixed(0)}'),
              const Divider(color: _C.border, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                  Text(
                    '₹${cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── TABLE SELECTION WARNING FOR DINE-IN ────────────────────────────────
        if (orderType == OrderType.dineIn && selectedTableId == null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table Selection Required',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Please select a table from the list above',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        GestureDetector(
          onTap:
              (placing ||
                  (orderType == OrderType.dineIn && selectedTableId == null))
              ? null
              : onPlaceOrder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    (placing ||
                        (orderType == OrderType.dineIn &&
                            selectedTableId == null))
                    ? [Colors.grey, Colors.grey.shade400]
                    : [_C.primary, _C.primaryD],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  (placing ||
                      (orderType == OrderType.dineIn &&
                          selectedTableId == null))
                  ? []
                  : [
                      BoxShadow(
                        color: _C.primary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (placing) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Placing Order...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else if (orderType == OrderType.dineIn &&
                    selectedTableId == null) ...[
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Select Table to Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Place Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ORDER PREVIEW VIEW — STEP 3 (Final review before placing)
// ══════════════════════════════════════════════════════════════
class _OrderPreviewView extends StatelessWidget {
  final String? selectedTableId;
  final int? selectedTableNumber;
  final List<Map<String, dynamic>> tables;
  final List<CartItem> cartItems;
  final double cartSubtotal, cartTax, cartTotal;
  final OrderType orderType;
  final TextEditingController customerCtrl, phoneCtrl, noteCtrl;
  final bool placing;
  final ValueChanged<OrderType> onTypeChanged;
  final VoidCallback onPlaceOrder;
  final VoidCallback onBack;

  const _OrderPreviewView({
    Key? key,
    required this.selectedTableId,
    required this.selectedTableNumber,
    required this.tables,
    required this.cartItems,
    required this.cartSubtotal,
    required this.cartTax,
    required this.cartTotal,
    required this.orderType,
    required this.customerCtrl,
    required this.phoneCtrl,
    required this.noteCtrl,
    required this.placing,
    required this.onTypeChanged,
    required this.onPlaceOrder,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectedTable = selectedTableId != null
        ? tables.firstWhere(
            (t) => t['id'] == selectedTableId,
            orElse: () => <String, dynamic>{},
          )
        : null;

    return Column(
      children: [
        Container(
          color: _C.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '✅ Step 3: Confirm Order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.primaryL,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: _C.primary, size: 18),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Table Details (if dine-in) ────────────────────────────
              if (orderType == OrderType.dineIn && selectedTable != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.primaryL,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dine-In Order',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _C.textSec,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Table T${selectedTableNumber} (${selectedTable['capacity']} seats)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _C.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Order Type Selection ──────────────────────────────────
              _SectionLabel('Order Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: OrderType.values.map((type) {
                  final isSelected = orderType == type;
                  return GestureDetector(
                    onTap: () => onTypeChanged(type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _C.primary : _C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _C.primary : _C.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _orderTypeEmoji(type),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _orderTypeLabel(type),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : _C.textPri,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Items Summary ─────────────────────────────────────────
              _SectionLabel('Order Items (${cartItems.length})'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: List.generate(cartItems.length, (i) {
                    final item = cartItems[i];
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _C.textPri,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.itemPrice.toStringAsFixed(0)} × ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _C.textSec,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _C.primary,
                              ),
                            ),
                          ],
                        ),
                        if (i < cartItems.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: _C.border),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // ── Customer Details ──────────────────────────────────────
              _SectionLabel('Customer Details (Optional)'),
              const SizedBox(height: 10),
              _Field(
                label: 'Customer Name',
                hint: 'Enter name...',
                ctrl: customerCtrl,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Phone Number',
                hint: 'Enter phone...',
                ctrl: phoneCtrl,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Order Notes',
                hint: 'Special instructions...',
                ctrl: noteCtrl,
              ),
              const SizedBox(height: 24),

              // ── Bill Summary ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.primaryL,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.primary, width: 1),
                ),
                child: Column(
                  children: [
                    _BillRow('Subtotal', '₹${cartSubtotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    _BillRow('Tax (5%)', '₹${cartTax.toStringAsFixed(0)}'),
                    const Divider(color: _C.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _C.primary,
                          ),
                        ),
                        Text(
                          '₹${cartTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _C.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Place Order Button ────────────────────────────────────
              GestureDetector(
                onTap: placing ? null : onPlaceOrder,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: placing
                          ? [Colors.grey, Colors.grey.shade400]
                          : [_C.primary, _C.primaryD],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: placing
                        ? []
                        : [
                            BoxShadow(
                              color: _C.primary.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (placing) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Placing Order...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Confirm & Place Order',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Back Button ──────────────────────────────────────────
              GestureDetector(
                onTap: placing ? null : onBack,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, color: _C.textSec, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Back to Menu',
                        style: TextStyle(
                          color: _C.textSec,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _orderTypeEmoji(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return '🍽️';
      case OrderType.delivery:
        return '🚚';
      case OrderType.takeaway:
        return '🛍️';
    }
  }

  String _orderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'Dine-In';
      case OrderType.delivery:
        return 'Delivery';
      case OrderType.takeaway:
        return 'Takeaway';
    }
  }
}

// ── Legend dot ────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _C.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: _C.textMute,
      letterSpacing: 1.4,
    ),
  );
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  const _Field({required this.label, required this.hint, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _C.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _C.textPri,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: _C.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label, value;
  const _BillRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: _C.textSec)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _C.textPri,
        ),
      ),
    ],
  );
}

class _AllocationDisplayBanner extends StatelessWidget {
  final String? tableId;
  final List<Map<String, dynamic>> tables;
  final String? seatId;

  const _AllocationDisplayBanner({
    required this.tableId,
    required this.tables,
    this.seatId,
  });

  @override
  Widget build(BuildContext context) {
    if (tableId == null) {
      return const SizedBox.shrink();
    }

    // Find the selected table
    final selectedTable = tables.firstWhere(
      (t) => t['id'] == tableId,
      orElse: () => {},
    );

    if (selectedTable.isEmpty) {
      return const SizedBox.shrink();
    }

    final tableNum = selectedTable['table_number'] as int? ?? 0;
    final tableStatus = selectedTable['status'] as String? ?? 'available';
    final totalSeats = (selectedTable['table_seats'] as List?)?.length ?? 0;

    // Find selected seat details if provided
    String? selectedSeatLabel;
    if (seatId != null && seatId!.isNotEmpty) {
      final seats = selectedTable['table_seats'] as List? ?? [];
      try {
        final seat = seats.firstWhere(
          (s) => (s as Map)['id'] == seatId,
          orElse: () => {},
        );
        if ((seat as Map).isNotEmpty) {
          selectedSeatLabel = seat['seat_label'] as String?;
        }
      } catch (_) {}
    }

    final statusColor = _tableStatusColor(tableStatus);
    final statusEmoji = _tableStatusEmoji(tableStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status and Table Number
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(statusEmoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TABLE ${tableNum.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      '$totalSeats seats available • ${_statusLabel(tableStatus)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _C.textMute,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Seat selection info if a specific seat is selected
          if (selectedSeatLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('🪗 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      'Seat $selectedSeatLabel is allocated to this order',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '📋 Whole table is allocated',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper methods from _CartView
  Color _tableStatusColor(String status) {
    switch (status) {
      case 'available':
        return _C.available;
      case 'occupied':
        return _C.occupied;
      case 'reserved':
        return _C.reserved;
      case 'cleaning':
        return _C.cleaning;
      default:
        return _C.textMute;
    }
  }

  String _tableStatusEmoji(String status) {
    switch (status) {
      case 'available':
        return '✅';
      case 'occupied':
        return '🍽️';
      case 'reserved':
        return '📅';
      case 'cleaning':
        return '🧹';
      default:
        return '❓';
    }
  }

  String _statusLabel(String status) {
    if (status == 'available') return 'Available';
    if (status == 'occupied') return 'Occupied (can order)';
    if (status == 'reserved') return 'Reserved (can order)';
    if (status == 'cleaning') return 'Cleaning';
    return 'Unknown';
  }
}

class _SeatChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final String? status;
  final VoidCallback onTap;

  const _SeatChip({
    required this.label,
    required this.isSelected,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = _C.surface;
    Color borderColor = _C.border;
    Color iconColor = _C.textSec;

    if (status == 'occupied') {
      bgColor = _C.occupied.withOpacity(0.08);
      borderColor = _C.occupied.withOpacity(0.3);
      iconColor = _C.occupied;
    } else if (status == 'available') {
      bgColor = _C.available.withOpacity(0.08);
      borderColor = _C.available.withOpacity(0.3);
      iconColor = _C.available;
    }

    if (isSelected) {
      bgColor = _C.primary;
      borderColor = _C.primary;
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'occupied')
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: isSelected ? Colors.white : iconColor,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (status == 'occupied' ? _C.occupied : _C.textPri),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
