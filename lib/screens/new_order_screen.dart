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
import 'package:pos_app/services/order_service.dart';
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
  tableSelection, // Step 1: Select table + inline seat selection (mandatory entry point)
  menuSelection, // Step 2: Build cart from menu (only after table/seat confirmation)
  orderPreview, // Step 3: Preview order with dining type, items, customer details
  orderPlacement, // Step 4: Place/process order
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
  int? _tableCapacity;
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showCart = false;
  bool _placing = false;

  // ── Seat Selection (Multiple seats support) ────────────────
  Set<String> _selectedSeatIds = {};
  Set<String> _initiallyAssignedSeatIds = {};
  bool _tableSeatSelectionFetched = false;

  // ── Seamless Workflow: Existing Order Support ──────────────
  Order? _existingOrder; // When continuing with existing order
  bool _isContinuingExistingOrder =
      false; // Flag: adding items to existing order
  List<OrderItem> _existingOrderItemsSnapshot =
      []; // Original items for reference
  bool _hasCheckedForExistingOrder = false; // Prevent duplicate checks

  // ── Computed ──────────────────────────────────────────────
  List<CartItem> get cartItems => _cart.values.toList();
  double get cartSubtotal => cartItems.fold(0.0, (s, i) => s + i.subtotal);
  double get cartTax => cartSubtotal * 0.05;
  double get cartTotal => cartSubtotal + cartTax;
  int get cartCount => cartItems.fold(0, (s, i) => s + i.quantity);

  // ── Seat Selection Computed ───────────────────────────────
  int get selectedSeatCount => _selectedSeatIds.length;
  int get initiallyAssignedSeatCount => _initiallyAssignedSeatIds.length;
  int get newlyAddedSeatCount => _selectedSeatIds
      .where((s) => !_initiallyAssignedSeatIds.contains(s))
      .length;
  String? get primarySelectedSeatId =>
      _selectedSeatIds.isEmpty ? null : _selectedSeatIds.first;
  bool get isWholeTableSelected => _selectedSeatIds.isEmpty;
  bool get hasTableCapacityExceeded =>
      _tableCapacity != null && _selectedSeatIds.length > _tableCapacity!;

  List<Map<String, dynamic>> get filteredItems {
    List<Map<String, dynamic>> items = _selectedCategory == 'All'
        ? _allMenuItems
        : _allMenuItems
              .where((i) => i['category_name'] == _selectedCategory)
              .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where(
            (i) => ((i['name'] as String?) ?? '').toLowerCase().contains(q),
          )
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

    // If table is pre-selected, start at table selection (now includes seat selection)
    if (_selectedTableId != null) {
      _currentStep = OrderWorkflowStep.tableSelection;
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
  //  SEAT SELECTION - PRE-FETCH AND PRE-SELECT OCCUPIED SEATS
  // ══════════════════════════════════════════════════════════

  /// Fetch and pre-select occupied seats for the selected table
  Future<void> _fetchAndPreSelectSeats() async {
    log('Fetch and Pre-select seats');
    if (_selectedTableId == null || _selectedTableId!.isEmpty) return;

    try {
      final table = await Supabase.instance.client
          .from('restaurant_tables')
          .select(
            'table_seats(id, seat_label, status, session_id, customer_name)',
          )
          .eq('id', _selectedTableId!)
          .single();

      if (!mounted) return;

      final seats =
          (table['table_seats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final occupiedSeats = seats
          .where((s) => s['status'] == 'occupied')
          .toList();

      setState(() {
        // Pre-select all initially occupied seats
        _selectedSeatIds = occupiedSeats
            .map((s) => (s['id'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _initiallyAssignedSeatIds = Set<String>.from(_selectedSeatIds);
        _tableSeatSelectionFetched = true;
      });

      debugPrint(
        '🪑 Pre-selected ${_selectedSeatIds.length} occupied seats for table $_selectedTableNumber',
      );

      // ✨ NEW: Check for existing active order on this table
      if (!mounted) return;
      await _checkForExistingOrderAndShowModal();
    } catch (e) {
      debugPrint('🪑 ERROR fetching seats: $e');
      // If offline or error, just continue with empty selection
      if (!mounted) return;
      setState(() {
        _selectedSeatIds.clear();
        _initiallyAssignedSeatIds.clear();
        _tableSeatSelectionFetched = true;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAMLESS WORKFLOW: Check for existing active orders (NEW FEATURE)
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if there's an existing active order for this table and show options
  Future<void> _checkForExistingOrderAndShowModal() async {
    if (_selectedTableId == null ||
        _selectedTableId!.isEmpty ||
        _hasCheckedForExistingOrder) {
      return;
    }

    setState(() => _hasCheckedForExistingOrder = true);

    try {
      debugPrint(
        '🔍 Checking for existing active order on table $_selectedTableId...',
      );

      // Use the new OrdersService method to check for existing orders
      final ordersService = OrdersService.instance;
      final existingOrder = await ordersService.getActiveOrderForTable(
        tableId: _selectedTableId!,
        businessId: _businessId,
        tableSeatId: primarySelectedSeatId,
      );

      if (!mounted || existingOrder == null) {
        debugPrint('✓ No existing active order found — starting fresh');
        // No existing order, proceed to menu selection
        if (mounted) {
          setState(() => _currentStep = OrderWorkflowStep.menuSelection);
        }
        return;
      }

      // Found existing order — show modal with options
      debugPrint(
        '✨ Found existing active order #${existingOrder.orderNumber} with ${existingOrder.items.length} items',
      );

      if (mounted) {
        _showExistingOrderModal(existingOrder);
      }
    } catch (e) {
      debugPrint('⚠️  Error checking for existing orders: $e');
      // Silently continue — this is non-critical
      if (mounted) {
        setState(() => _currentStep = OrderWorkflowStep.menuSelection);
      }
    }
  }

  /// Show modal with options when existing order is found
  void _showExistingOrderModal(Order existingOrder) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        title: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Continue Existing Order?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _C.textPri,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Current order summary ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.primaryL,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${existingOrder.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _C.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: existingOrder.status.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            existingOrder.status.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${existingOrder.items.length} items • ₹${existingOrder.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: _C.textSec),
                    ),
                    const SizedBox(height: 8),
                    // Show first 3 items
                    ...existingOrder.items
                        .take(3)
                        .map(
                          (item) => Text(
                            '  • ${item.itemName} (×${item.quantity})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _C.textSec,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    if (existingOrder.items.length > 3)
                      Text(
                        '  • +${existingOrder.items.length - 3} more items',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Description ────────────────────────────────────────────
              const Text(
                'You can:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '✅ Add more items to this order (seamless continuation)\n'
                '👁️ View full order details\n'
                '⚠️ Create a new order on another table',
                style: TextStyle(fontSize: 11, color: _C.textSec, height: 1.6),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Start fresh — user wants a new order
              _resetForNewOrder();
            },
            child: const Text(
              'New Order',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // View the existing order
              _viewExistingOrder(existingOrder);
            },
            child: const Text(
              'View Order',
              style: TextStyle(color: _C.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
            onPressed: () {
              Navigator.pop(ctx);
              // Continue with existing order
              _continueWithExistingOrder(existingOrder);
            },
            child: const Text(
              'Add Items',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reset state to start a completely new order
  void _resetForNewOrder() {
    setState(() {
      _existingOrder = null;
      _isContinuingExistingOrder = false;
      _existingOrderItemsSnapshot = [];
      _hasCheckedForExistingOrder = false;
      _cart.clear();
      _currentStep = OrderWorkflowStep.menuSelection;
    });
    _snack('🔄 Starting a new order');
  }

  /// Show existing order details — separate screen/modal
  void _viewExistingOrder(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        title: Text(
          'Order #${order.orderNumber}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _C.textPri,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.itemName} ×${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.textPri,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${item.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.textPri,
                    ),
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _continueWithExistingOrder(order);
            },
            child: const Text(
              'Add Items',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Continue with existing order — switch to add-items mode
  void _continueWithExistingOrder(Order existingOrder) {
    setState(() {
      _existingOrder = existingOrder;
      _isContinuingExistingOrder = true;
      _existingOrderItemsSnapshot = List<OrderItem>.from(existingOrder.items);
      _cart.clear(); // Clear cart to show only NEW items being added
      _currentStep = OrderWorkflowStep.menuSelection;
    });

    debugPrint(
      '✨ Continuing with order #${existingOrder.orderNumber}. Ready to add items.',
    );
    _snack(
      '✨ Adding items to order #${existingOrder.orderNumber}. Seamless continuation!',
    );
  }

  /// Toggle seat selection on/off
  void _toggleSeatSelection(String seatId) {
    setState(() {
      if (_selectedSeatIds.contains(seatId)) {
        _selectedSeatIds.remove(seatId);
      } else {
        _selectedSeatIds.add(seatId);
      }
    });
    debugPrint('🪑 Toggled seat $seatId. Selected: ${_selectedSeatIds.length}');
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

    final id = (item['id'] as String?) ?? '';
    final itemName = (item['name'] as String?) ?? '';
    if (id.isEmpty || itemName.isEmpty) {
      _snack('❌ Item data is incomplete');
      return;
    }
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
                      final tid = (t['id'] as String?) ?? '';
                      final num = (t['table_number'] as int?) ?? 0;
                      final cap = (t['capacity'] as int?) ?? 0;
                      if (tid.isEmpty || num <= 0)
                        return const SizedBox.shrink();
                      final status = t['status'] as String? ?? 'available';
                      final canSelect = _tableIsSelectable(status);
                      final sColor = _tableStatusColor(status);

                      return GestureDetector(
                        onTap: canSelect
                            ? () {
                                setState(() {
                                  _selectedTableId = tid;
                                  _selectedTableNumber = num;
                                  _tableCapacity = cap;
                                  _tableSeatSelectionFetched = false;
                                  _selectedSeatIds.clear();
                                  _initiallyAssignedSeatIds.clear();
                                });
                                Navigator.pop(ctx);
                                _fetchAndPreSelectSeats();
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

      // ✓ STEP 2: Create or add items to order
      debugPrint(
        _isContinuingExistingOrder
            ? '➕ Adding items to existing order ${_existingOrder!.id}...'
            : '📝 Creating new order...',
      );

      final prov = context.read<OrdersProvider>();
      final order = _isContinuingExistingOrder && _existingOrder != null
          ? await prov.addItemsToExistingOrder(
              orderId: _existingOrder!.id,
              newItems: cartItems,
              updatedNotes: _noteCtrl.text.trim().isNotEmpty
                  ? _noteCtrl.text.trim()
                  : null,
            )
          : await prov.createOrder(
              cartItems: cartItems,
              orderType: _orderType,
              tableId: _selectedTableId,
              tableNumber: _selectedTableNumber,
              tableSeatId: primarySelectedSeatId,
              customerName: _customerCtrl.text.trim().isEmpty
                  ? null
                  : _customerCtrl.text.trim(),
              customerPhone: _phoneCtrl.text.trim().isEmpty
                  ? null
                  : _phoneCtrl.text.trim(),
              notes: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            );

      if (!mounted) return;

      // ✓ STEP 3: Deduct inventory after successful order creation/update
      debugPrint(
        _isContinuingExistingOrder
            ? '📦 Deducting inventory for new items on order ${order.id}...'
            : '📦 Deducting inventory for order ${order.id}...',
      );

      // ✅ GUARD: Validate order has id before attempting inventory deduction
      if (order.id.isEmpty) {
        debugPrint(
          '⚠️  Order id is empty, skipping inventory deduction. '
          'Order likely not fully created yet.',
        );
      } else if (_isOnline) {
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
          debugPrint(
            _isContinuingExistingOrder
                ? '✅ Inventory deducted for new items on order ${order.id}'
                : '✅ Inventory deducted successfully for order ${order.id}',
          );
        } catch (e) {
          debugPrint(
            '⚠️  Inventory deduction failed (order still updated): $e',
          );
          if (mounted) {
            _snack(
              _isContinuingExistingOrder
                  ? '⚠️  Items added to order #${order.orderNumber} but inventory deduction failed. Will retry when online.'
                  : '⚠️  Order #${order.orderNumber} created but inventory deduction failed. Will retry when online.',
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
          _snack(
            _isContinuingExistingOrder
                ? '✅ Items added offline. Will sync when online.'
                : '✅ Order created offline. Will sync when online.',
          );
        } else {
          _snack(
            _isContinuingExistingOrder
                ? '✅ ✨ Items added seamlessly to order #${order.orderNumber}'
                : '✅ Order #${order.orderNumber} placed & inventory updated',
          );
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
        case OrderWorkflowStep.menuSelection:
          // Go back to table selection (keep table/seat selection)
          _currentStep = OrderWorkflowStep.tableSelection;
          _cart.clear();
          break;
        case OrderWorkflowStep.orderPreview:
          // Go back to menu selection
          _currentStep = OrderWorkflowStep.menuSelection;
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

      case OrderWorkflowStep.menuSelection:
        return _buildMenuSelectionStep();

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
        Expanded(child: _buildTableSelectionFooter()),
      ],
    );
  }

  /// Table selection footer — shows available tables
  Widget _buildTableSelectionFooter() {
    return Container(
      color: _C.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // ── Header with description ──────────────────────────────────
          const Text(
            'Choose Your Table',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _C.textPri,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a table to start a new order',
            style: TextStyle(
              fontSize: 13,
              color: _C.textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // ── Status Legend ─────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusBadge('Available', _C.available),
                const SizedBox(width: 12),
                _buildStatusBadge('Occupied', _C.occupied),
                const SizedBox(width: 12),
                _buildStatusBadge('Reserved', _C.reserved),
                const SizedBox(width: 12),
                _buildStatusBadge('Cleaning', _C.cleaning),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Table Grid ────────────────────────────────────────────────
          if (_tables.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 12),
                  const Text(
                    'No tables available',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _tables.length,
              itemBuilder: (context, idx) {
                final t = _tables[idx];
                final tid = (t['id'] as String?) ?? '';
                final num = (t['table_number'] as int?) ?? 0;
                final cap = (t['capacity'] as int?) ?? 0;
                if (tid.isEmpty || num <= 0) return const SizedBox.shrink();
                final status = t['status'] as String? ?? 'available';
                final seats =
                    (t['table_seats'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
                final occupiedSeats = seats
                    .where((s) => s['status'] == 'occupied')
                    .toList();
                final occupancyPct = seats.isNotEmpty
                    ? ((occupiedSeats.length / seats.length) * 100).toInt()
                    : 0;
                final canSelect = _tableIsSelectable(status);
                final sColor = _tableStatusColor(status);
                final isSelected = _selectedTableId == tid;

                return GestureDetector(
                  onTap: canSelect
                      ? () {
                          setState(() {
                            _selectedTableId = tid;
                            _selectedTableNumber = num;
                            _tableCapacity = cap;
                            _tableSeatSelectionFetched = false;
                            _selectedSeatIds.clear();
                            _initiallyAssignedSeatIds.clear();
                          });
                          _fetchAndPreSelectSeats();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: !canSelect
                          ? const Color(0xFFF9FAFB)
                          : isSelected
                          ? _C.primaryL
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !canSelect
                            ? const Color(0xFFE5E7EB)
                            : isSelected
                            ? _C.primary
                            : sColor.withOpacity(0.3),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: _C.primary.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canSelect
                            ? () {
                                setState(() {
                                  _selectedTableId = tid;
                                  _selectedTableNumber = num;
                                  _tableCapacity = cap;
                                  _tableSeatSelectionFetched = false;
                                  _selectedSeatIds.clear();
                                  _initiallyAssignedSeatIds.clear();
                                });
                                _fetchAndPreSelectSeats();
                              }
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ── Top row: Emoji + Status Badge ────────────
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _tableStatusEmoji(status),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _C.primary,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Selected',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: sColor,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // ── Table number (medium) ──────────────────────
                              Text(
                                'T$num',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: !canSelect
                                      ? _C.textMute
                                      : isSelected
                                      ? _C.primary
                                      : _C.textPri,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // ── Capacity ──────────────────────────────────
                              Row(
                                children: [
                                  Icon(
                                    Icons.chair,
                                    size: 12,
                                    color: !canSelect ? _C.textMute : sColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$cap',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: !canSelect ? _C.textMute : sColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // ── Compact Seat Preview ──────────────────────
                              if (seats.isNotEmpty)
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildCompactSeatPreview(seats, tid),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          child: LinearProgressIndicator(
                                            value:
                                                occupiedSeats.length /
                                                seats.length,
                                            minHeight: 5,
                                            backgroundColor: _C.border,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  occupiedSeats.isEmpty
                                                      ? _C.available
                                                      : occupancyPct.toInt() ==
                                                            100
                                                      ? _C.occupied
                                                      : _C.partial,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // ── Bottom: Action indicator ──────────────────
                              if (canSelect)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _C.primary
                                        : _C.primaryL,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? _C.primary
                                          : _C.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Select',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : _C.primary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Unavailable',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _C.textMute,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),

          // ── CTA Button ─────────────────────────────────────────────────
          if (_selectedTableId != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_C.primary, _C.primary.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _proceedToMenuSelection(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue to Seats & Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _C.textMute.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.textMute.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: _C.textMute, size: 18),
                  const SizedBox(width: 8),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Build status badge for legend
  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build compact seat preview for table cards
  Widget _buildCompactSeatPreview(
    List<Map<String, dynamic>> seats,
    String tableId,
  ) {
    if (seats.isEmpty) {
      return const SizedBox.shrink();
    }

    final occupiedSeats = seats
        .where((s) => s['status'] == 'occupied')
        .toList();
    final totalSeats = seats.length;
    final isFullyOccupied = occupiedSeats.length == totalSeats;
    final isPartiallyOccupied =
        occupiedSeats.isNotEmpty && occupiedSeats.length < totalSeats;

    String? autoSelectedSeatId;
    bool showWholeTable = false;

    if (isFullyOccupied) {
      showWholeTable = true;
    } else if (isPartiallyOccupied && occupiedSeats.isNotEmpty) {
      autoSelectedSeatId = occupiedSeats.first['id'] as String?;
    }

    final gridCols = totalSeats <= 4 ? totalSeats : (totalSeats <= 9 ? 3 : 4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _C.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.border.withOpacity(0.3)),
      ),
      child: GridView.count(
        crossAxisCount: gridCols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 0.8,
        children: seats.map((seat) {
          final seatId = seat['id'] as String?;
          final seatLabel = seat['seat_label'] as String? ?? '?';
          final seatStatus = seat['status'] as String? ?? 'available';
          final isOccupied = seatStatus == 'occupied';
          final isAutoSelected =
              autoSelectedSeatId == seatId || (showWholeTable && isOccupied);

          return Container(
            decoration: BoxDecoration(
              color: isAutoSelected
                  ? _C.primary
                  : isOccupied
                  ? _C.occupied.withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isAutoSelected
                    ? _C.primary
                    : isOccupied
                    ? _C.occupied.withOpacity(0.3)
                    : _C.border,
                width: isAutoSelected ? 1.5 : 0.8,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                seatLabel,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isAutoSelected
                      ? Colors.white
                      : isOccupied
                      ? _C.occupied
                      : _C.textSec,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Proceed from table+seat selection to menu selection
  void _proceedToMenuSelection() {
    if (_selectedTableId == null) {
      _snack('📍 Please select a table first');
      return;
    }
    setState(() {
      _currentStep = OrderWorkflowStep.menuSelection;
      _showCart = false;
    });
  }

  /// Proceed from menu selection to order preview
  void _proceedToOrderPreview() {
    if (_cart.isEmpty) {
      _snack('🛒 Add items to cart first');
      return;
    }
    setState(() {
      _currentStep = OrderWorkflowStep.orderPreview;
      _showCart = false;
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
                '🍽️ Step 2: Browse Menu',
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
                    'Table T${_selectedTableNumber}${selectedSeatCount > 0 ? ' • ${selectedSeatCount} Seat${selectedSeatCount != 1 ? 's' : ''}' : ''}',
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
                  selectedSeatIds: _selectedSeatIds,
                  initiallyAssignedSeatIds: _initiallyAssignedSeatIds,
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
                      _selectedSeatIds.clear();
                      _initiallyAssignedSeatIds.clear();
                    }
                    _selectedTableId = id;
                    _selectedTableNumber = num;
                  }),
                  onAdd: _addItem,
                  onRemove: (id) => _removeItem(id),
                  onSeatSelected: _toggleSeatSelection,
                  onPlaceOrder: _proceedToOrderPreview,
                  showBackButton: true,
                  onBack: () => setState(() => _showCart = false),
                  // ✨ NEW: Pass existing order context
                  existingOrder: _existingOrder,
                  isContinuingExistingOrder: _isContinuingExistingOrder,
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
          setState(() => _currentStep = OrderWorkflowStep.menuSelection),
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
                  onTap: () =>
                      onCategoryChanged((c['name'] as String?) ?? 'All'),
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
                    final id = (item['id'] as String?) ?? '';
                    if (id.isEmpty) return const SizedBox.shrink();
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
                          (item['name'] as String?) ?? 'Unknown Item',
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
                  if (((item['description'] as String?) ?? '').isNotEmpty)
                    Text(
                      (item['description'] as String?) ?? '',
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
  final Set<String> selectedSeatIds;
  final Set<String> initiallyAssignedSeatIds;
  final TextEditingController customerCtrl, phoneCtrl, noteCtrl;
  final double cartSubtotal, cartTax, cartTotal;
  final bool placing;
  final ValueChanged<OrderType> onTypeChanged;
  final Function(String id, int num) onTableSelected;
  final ValueChanged<Map<String, dynamic>> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String>? onSeatSelected;
  final VoidCallback onPlaceOrder;
  final bool showBackButton;
  final VoidCallback? onBack;
  // ✨ NEW: Seamless order continuation context
  final Order? existingOrder;
  final bool isContinuingExistingOrder;

  const _CartView({
    Key? key,
    required this.cartItems,
    required this.orderType,
    required this.tables,
    required this.selectedTableId,
    required this.selectedSeatIds,
    required this.initiallyAssignedSeatIds,
    required this.customerCtrl,
    required this.phoneCtrl,
    required this.noteCtrl,
    required this.cartSubtotal,
    required this.cartTax,
    required this.cartTotal,
    required this.placing,
    required this.onTypeChanged,
    required this.onTableSelected,
    required this.onAdd,
    required this.onRemove,
    this.onSeatSelected,
    required this.onPlaceOrder,
    this.showBackButton = false,
    this.onBack,
    // ✨ NEW: Optional existing order parameters
    this.existingOrder,
    this.isContinuingExistingOrder = false,
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
            seatIds: selectedSeatIds,
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
                final tid = (t['id'] as String?) ?? '';
                final num = (t['table_number'] as int?) ?? 0;
                final cap = (t['capacity'] as int?) ?? 0;
                if (tid.isEmpty || num <= 0) return const SizedBox.shrink();
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
                    // ── Seat Selection Header ─────────────────────────────
                    Row(
                      children: [
                        Icon(Icons.event_seat, size: 18, color: _C.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Select Seats',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.textPri,
                            ),
                          ),
                        ),
                        if (selectedSeatIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _C.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${selectedSeatIds.length}/${seats.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Legend ────────────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _C.occupied.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _C.occupied.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _C.occupied,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Initially Occupied',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _C.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _C.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _C.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _C.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Selected for Order',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _C.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _C.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _C.border),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Available',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _C.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Interactive Seat Grid ────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.border),
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: seats.length <= 4
                              ? seats.length
                              : seats.length <= 9
                              ? 3
                              : 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: seats.length,
                        itemBuilder: (context, seatIndex) {
                          final seat =
                              (seats[seatIndex] as Map<String, dynamic>);
                          final seatId = seat['id'] as String? ?? '';
                          final seatLabel =
                              seat['seat_label'] as String? ??
                              'S${seatIndex + 1}';

                          final isPreSelected = initiallyAssignedSeatIds
                              .contains(seatId);
                          final isCurrentlySelected = selectedSeatIds.contains(
                            seatId,
                          );

                          return GestureDetector(
                            onTap: onSeatSelected != null
                                ? () => onSeatSelected!(seatId)
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isCurrentlySelected
                                    ? _C.primary
                                    : isPreSelected
                                    ? _C.occupied.withOpacity(0.15)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrentlySelected
                                      ? _C.primary
                                      : isPreSelected
                                      ? _C.occupied.withOpacity(0.4)
                                      : _C.border,
                                  width: isCurrentlySelected ? 2 : 1.5,
                                ),
                                boxShadow: [
                                  if (isCurrentlySelected)
                                    BoxShadow(
                                      color: _C.primary.withOpacity(0.2),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onSeatSelected != null
                                      ? () => onSeatSelected!(seatId)
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_seat,
                                            size: 24,
                                            color: isCurrentlySelected
                                                ? Colors.white
                                                : isPreSelected
                                                ? _C.occupied
                                                : _C.textSec,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            seatLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isCurrentlySelected
                                                  ? Colors.white
                                                  : isPreSelected
                                                  ? _C.occupied
                                                  : _C.textPri,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isCurrentlySelected && !isPreSelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: _C.primary,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      if (isPreSelected && !isCurrentlySelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: _C.occupied,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Text(
                                              '👤',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Info text ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _C.primaryL,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('ℹ️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedSeatIds.isEmpty
                                  ? 'Tap seats to add them to your order'
                                  : 'You have selected ${selectedSeatIds.length} seat${selectedSeatIds.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

        _SectionLabel(
          isContinuingExistingOrder
              ? '✨ Continuing Order #${existingOrder?.orderNumber}'
              : 'Cart (${cartItems.length} items)',
        ),
        const SizedBox(height: 10),

        // ── EXISTING ORDER ITEMS (if continuing) ────────────────────────────
        if (isContinuingExistingOrder && existingOrder != null) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _C.primary.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: _C.primaryL,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '📋 Original Items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '(reference only)',
                        style: TextStyle(
                          fontSize: 10,
                          color: _C.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Items
                ...existingOrder!.items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _C.textSec,
                                    ),
                                  ),
                                  Text(
                                    '₹${item.itemPrice.toStringAsFixed(0)} each',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _C.textMute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _C.textSec,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _C.primaryL,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '×${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _C.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < existingOrder!.items.length - 1)
                        Divider(height: 1, color: _C.border.withOpacity(0.3)),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── NEW ITEMS BEING ADDED ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isContinuingExistingOrder
                  ? Colors.green.withOpacity(0.3)
                  : _C.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Header for new items (only if continuing)
              if (isContinuingExistingOrder)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '✨ New Items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '(being added)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF059669),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // Actual cart items
              ...cartItems.asMap().entries.map((e) {
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
            ],
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
  final Set<String> seatIds;

  const _AllocationDisplayBanner({
    required this.tableId,
    required this.tables,
    required this.seatIds,
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
    List<String> selectedSeatLabels = [];
    if (seatIds.isNotEmpty) {
      final seats = selectedTable['table_seats'] as List? ?? [];
      for (final seatId in seatIds) {
        try {
          final seat = seats.firstWhere(
            (s) => (s as Map)['id'] == seatId,
            orElse: () => {},
          );
          if ((seat as Map).isNotEmpty) {
            final label = seat['seat_label'] as String?;
            if (label != null) selectedSeatLabels.add(label);
          }
        } catch (_) {}
      }
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

          // Seat selection info if specific seats are selected
          if (selectedSeatLabels.isNotEmpty) ...[
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
                  const Text('🪑 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      selectedSeatLabels.length == 1
                          ? 'Seat ${selectedSeatLabels.first} allocated'
                          : '${selectedSeatLabels.length} seats: ${selectedSeatLabels.join(', ')} allocated',
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
