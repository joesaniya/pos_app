// lib/screens/orders/new_order_screen.dart
// FIXES:
// 1. businessId loaded from Firebase Firestore (not SharedPreferences which was always empty)
// 2. Memory leak fixed — mounted checks before every setState after async gaps
// 3. Removed duplicate commented-out code at bottom

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/orders_provider.dart';

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
    _load();
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

      setState(() {
        _categories = (cats as List).cast<Map<String, dynamic>>();
        _allMenuItems = (items as List).map((item) {
          final cat = item['menu_categories'] as Map<String, dynamic>? ?? {};
          return {
            ...Map<String, dynamic>.from(item as Map),
            'category_name': cat['name'] ?? '',
            'category_icon': cat['icon'] ?? '🍽️',
            'category_color': cat['color_hex'] ?? '#D4673A',
          };
        }).toList();
        _menuLoading = false;
      });
    } catch (e) {
      debugPrint('🛒 _loadMenu ERROR: $e');
      // ── MEMORY LEAK FIX: check mounted before setState ────────────────────
      if (!mounted) return;
      setState(() => _menuLoading = false);
    }
  }

  Future<void> _loadTables() async {
    if (_businessId.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('restaurant_tables')
          .select(
            'id, table_number, capacity, status, section, current_customer_name, table_seats(id, seat_label, status)',
          )
          .eq('business_id', _businessId)
          .eq('is_active', true)
          .order('table_number');

      // ── MEMORY LEAK FIX: check mounted before setState ────────────────────
      if (!mounted) return;
      setState(() => _tables = (data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('🛒 _loadTables ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CART OPERATIONS
  // ══════════════════════════════════════════════════════════

  void _addItem(Map<String, dynamic> item) {
    if (!(item['is_available'] as bool? ?? true)) return;
    final id = item['id'] as String;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity + 1);
      } else {
        _cart[id] = CartItem(
          menuItemId: id,
          itemName: item['name'] as String,
          itemPrice: (item['discount_price'] ?? item['price'] as num)
              .toDouble(),
          categoryName: item['category_name'] as String?,
          isVeg: item['is_veg'] as bool? ?? true,
        );
      }
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
  //  PLACE ORDER
  // ══════════════════════════════════════════════════════════

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      _snack('Add items to cart first');
      return;
    }
    if (_orderType == OrderType.dineIn && _selectedTableId == null) {
      _snack('Please select a table');
      return;
    }

    if (!mounted) return;
    setState(() => _placing = true);

    try {
      final prov = context.read<OrdersProvider>();
      await prov.createOrder(
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Failed to place order: $e');
    } finally {
      // ── MEMORY LEAK FIX: check mounted before setState ──────────────────
      if (mounted) setState(() => _placing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _showCart
                    ? _CartView(
                        key: const ValueKey('cart'),
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
                        onTypeChanged: (t) => setState(() {
                          _orderType = t;
                          if (t != OrderType.dineIn) {
                            _selectedTableId = null;
                            _selectedSeatId = null;
                            _selectedTableNumber = null;
                          }
                        }),
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
                        onPlaceOrder: _placeOrder,
                      )
                    : _MenuView(
                        key: const ValueKey('menu'),
                        categories: _categories,
                        items: filteredItems,
                        selectedCategory: _selectedCategory,
                        searchCtrl: _searchCtrl,
                        cart: _cart,
                        loading: _menuLoading,
                        onCategoryChanged: (c) =>
                            setState(() => _selectedCategory = c),
                        onSearchChanged: (q) =>
                            setState(() => _searchQuery = q),
                        onAdd: _addItem,
                        onRemove: (id) => _removeItem(id),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
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
          const Expanded(
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
                  'Select items from menu',
                  style: TextStyle(fontSize: 11, color: _C.textSec),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showCart = !_showCart),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                  onTap: onAdd,
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
                final isPartial = tSeats.isNotEmpty &&
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
                          isPartial
                              ? '$availCount/$cap free'
                              : '$cap seats',
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
            Builder(builder: (context) {
              final selectedTable = tables.firstWhere(
                (t) => t['id'] == selectedTableId,
                orElse: () => {},
              );
              final List<dynamic> seats = selectedTable['table_seats'] ?? [];
              if (seats.isEmpty) return const SizedBox.shrink();

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
            }),
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

        GestureDetector(
          onTap: placing ? null : onPlaceOrder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
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
// import 'package:flutter/material.dart';
// import 'package:pos_app/models/order_modal.dart';
// import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../providers/orders_provider.dart';

// class _C {
//   static const bg = Color(0xFFF6F6FB);
//   static const surface = Color(0xFFFFFFFF);
//   static const surfaceAlt = Color(0xFFF2F2F8);
//   static const border = Color(0xFFEAEAF4);
//   static const primary = Color(0xFF5A3FD6);
//   static const primaryL = Color(0xFFEDE9FF);
//   static const primaryD = Color(0xFF3D2AA0);
//   static const textPri = Color(0xFF1A1A2E);
//   static const textSec = Color(0xFF6B6B86);
//   static const textMute = Color(0xFFAAABBB);
//   static const occupied = Color(0xFFDC2626);
//   static const reserved = Color(0xFF7C3AED);
//   static const available = Color(0xFF059669);
//   static const cleaning = Color(0xFFD97706);
// }

// // ══════════════════════════════════════════════════════════════
// //  NEW ORDER SCREEN
// // ══════════════════════════════════════════════════════════════
// class NewOrderScreen extends StatefulWidget {
//   final String? preselectedTableId;
//   final int? preselectedTableNumber;

//   const NewOrderScreen({
//     Key? key,
//     this.preselectedTableId,
//     this.preselectedTableNumber,
//   }) : super(key: key);

//   @override
//   State<NewOrderScreen> createState() => _NewOrderScreenState();
// }

// class _NewOrderScreenState extends State<NewOrderScreen> {
//   String _businessId = '';

//   List<Map<String, dynamic>> _categories = [];
//   List<Map<String, dynamic>> _allMenuItems = [];
//   bool _menuLoading = true;

//   List<Map<String, dynamic>> _tables = [];

//   final Map<String, CartItem> _cart = {};

//   OrderType _orderType = OrderType.dineIn;
//   String? _selectedTableId;
//   int? _selectedTableNumber;
//   final _customerCtrl = TextEditingController();
//   final _phoneCtrl = TextEditingController();
//   final _noteCtrl = TextEditingController();
//   final _searchCtrl = TextEditingController();

//   String _selectedCategory = 'All';
//   String _searchQuery = '';
//   bool _showCart = false;
//   bool _placing = false;

//   List<CartItem> get cartItems => _cart.values.toList();
//   double get cartSubtotal => cartItems.fold(0.0, (s, i) => s + i.subtotal);
//   double get cartTax => cartSubtotal * 0.05;
//   double get cartTotal => cartSubtotal + cartTax;
//   int get cartCount => cartItems.fold(0, (s, i) => s + i.quantity);

//   List<Map<String, dynamic>> get filteredItems {
//     List<Map<String, dynamic>> items = _selectedCategory == 'All'
//         ? _allMenuItems
//         : _allMenuItems
//               .where((i) => i['category_name'] == _selectedCategory)
//               .toList();
//     if (_searchQuery.isNotEmpty) {
//       final q = _searchQuery.toLowerCase();
//       items = items
//           .where((i) => (i['name'] as String).toLowerCase().contains(q))
//           .toList();
//     }
//     items.sort((a, b) {
//       final aAvail = a['is_available'] as bool? ?? true;
//       final bAvail = b['is_available'] as bool? ?? true;
//       if (aAvail == bAvail) return 0;
//       return aAvail ? -1 : 1;
//     });
//     return items;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _selectedTableId = widget.preselectedTableId;
//     _selectedTableNumber = widget.preselectedTableNumber;
//     _load();
//   }

//   @override
//   void dispose() {
//     _customerCtrl.dispose();
//     _phoneCtrl.dispose();
//     _noteCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _load() async {
//     final prefs = await SharedPreferences.getInstance();
//     _businessId = prefs.getString('businessId') ?? '';
//     await Future.wait([_loadMenu(), _loadTables()]);
//   }

//   Future<void> _loadMenu() async {
//     if (_businessId.isEmpty) return;
//     try {
//       final cats = await Supabase.instance.client
//           .from('menu_categories')
//           .select('id, name, icon, color_hex')
//           .eq('business_id', _businessId)
//           .eq('is_active', true)
//           .order('display_order');

//       final items = await Supabase.instance.client
//           .from('menu_items')
//           .select(
//             'id, name, description, price, discount_price, is_veg, is_available, '
//             'is_featured, is_best_seller, preparation_time, category_id, '
//             'menu_categories!inner(name, icon, color_hex)',
//           )
//           .eq('business_id', _businessId)
//           .order('sort_order');

//       setState(() {
//         _categories = (cats as List).cast<Map<String, dynamic>>();
//         _allMenuItems = (items as List).map((item) {
//           final cat = item['menu_categories'] as Map<String, dynamic>? ?? {};
//           return {
//             ...Map<String, dynamic>.from(item as Map),
//             'category_name': cat['name'] ?? '',
//             'category_icon': cat['icon'] ?? '🍽️',
//             'category_color': cat['color_hex'] ?? '#D4673A',
//           };
//         }).toList();
//         _menuLoading = false;
//       });
//     } catch (e) {
//       setState(() => _menuLoading = false);
//     }
//   }

//   Future<void> _loadTables() async {
//     if (_businessId.isEmpty) return;
//     try {
//       final data = await Supabase.instance.client
//           .from('restaurant_tables')
//           .select(
//             'id, table_number, capacity, status, section, current_customer_name',
//           )
//           .eq('business_id', _businessId)
//           .eq('is_active', true)
//           .order('table_number');

//       setState(() => _tables = (data as List).cast<Map<String, dynamic>>());
//     } catch (_) {}
//   }

//   void _addItem(Map<String, dynamic> item) {
//     if (!(item['is_available'] as bool? ?? true)) return;
//     final id = item['id'] as String;
//     setState(() {
//       if (_cart.containsKey(id)) {
//         _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity + 1);
//       } else {
//         _cart[id] = CartItem(
//           menuItemId: id,
//           itemName: item['name'] as String,
//           itemPrice: (item['discount_price'] ?? item['price'] as num)
//               .toDouble(),
//           categoryName: item['category_name'] as String?,
//           isVeg: item['is_veg'] as bool? ?? true,
//         );
//       }
//     });
//   }

//   void _removeItem(String id) {
//     setState(() {
//       if (!_cart.containsKey(id)) return;
//       if (_cart[id]!.quantity <= 1) {
//         _cart.remove(id);
//       } else {
//         _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity - 1);
//       }
//     });
//   }

//   Future<void> _placeOrder() async {
//     if (_cart.isEmpty) {
//       _snack('Add items to cart first');
//       return;
//     }
//     if (_orderType == OrderType.dineIn && _selectedTableId == null) {
//       _snack('Please select a table');
//       return;
//     }
//     setState(() => _placing = true);
//     try {
//       final prov = context.read<OrdersProvider>();
//       await prov.createOrder(
//         cartItems: cartItems,
//         orderType: _orderType,
//         tableId: _selectedTableId,
//         tableNumber: _selectedTableNumber,
//         customerName: _customerCtrl.text.isEmpty ? null : _customerCtrl.text,
//         customerPhone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
//         notes: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
//       );
//       if (mounted) Navigator.pop(context);
//     } catch (e) {
//       _snack('Failed to place order: $e');
//     } finally {
//       if (mounted) setState(() => _placing = false);
//     }
//   }

//   void _snack(String msg) =>
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _C.bg,
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: AnimatedSwitcher(
//                 duration: const Duration(milliseconds: 250),
//                 child: _showCart
//                     ? _CartView(
//                         key: const ValueKey('cart'),
//                         cartItems: cartItems,
//                         orderType: _orderType,
//                         tables: _tables,
//                         selectedTableId: _selectedTableId,
//                         customerCtrl: _customerCtrl,
//                         phoneCtrl: _phoneCtrl,
//                         noteCtrl: _noteCtrl,
//                         cartSubtotal: cartSubtotal,
//                         cartTax: cartTax,
//                         cartTotal: cartTotal,
//                         placing: _placing,
//                         onTypeChanged: (t) => setState(() => _orderType = t),
//                         onTableSelected: (id, num) => setState(() {
//                           _selectedTableId = id;
//                           _selectedTableNumber = num;
//                         }),
//                         onAdd: _addItem,
//                         onRemove: (id) => _removeItem(id),
//                         onPlaceOrder: _placeOrder,
//                       )
//                     : _MenuView(
//                         key: const ValueKey('menu'),
//                         categories: _categories,
//                         items: filteredItems,
//                         selectedCategory: _selectedCategory,
//                         searchCtrl: _searchCtrl,
//                         cart: _cart,
//                         loading: _menuLoading,
//                         onCategoryChanged: (c) =>
//                             setState(() => _selectedCategory = c),
//                         onSearchChanged: (q) =>
//                             setState(() => _searchQuery = q),
//                         onAdd: _addItem,
//                         onRemove: (id) => _removeItem(id),
//                       ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//       child: Row(
//         children: [
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: _C.surfaceAlt,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: _C.border),
//               ),
//               child: const Icon(
//                 Icons.arrow_back_ios_new,
//                 size: 16,
//                 color: _C.textPri,
//               ),
//             ),
//           ),
//           const SizedBox(width: 14),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'New Order',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w900,
//                     color: _C.textPri,
//                   ),
//                 ),
//                 Text(
//                   'Select items from menu',
//                   style: TextStyle(fontSize: 11, color: _C.textSec),
//                 ),
//               ],
//             ),
//           ),
//           GestureDetector(
//             onTap: () => setState(() => _showCart = !_showCart),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 180),
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
//               decoration: BoxDecoration(
//                 color: _showCart ? _C.primaryL : _C.primary,
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               child: Row(
//                 children: [
//                   Icon(
//                     _showCart
//                         ? Icons.menu_book_rounded
//                         : Icons.shopping_cart_outlined,
//                     color: _showCart ? _C.primary : Colors.white,
//                     size: 18,
//                   ),
//                   const SizedBox(width: 6),
//                   Text(
//                     _showCart ? 'Menu' : 'Cart ($cartCount)',
//                     style: TextStyle(
//                       color: _showCart ? _C.primary : Colors.white,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   if (!_showCart && cartTotal > 0) ...[
//                     const SizedBox(width: 6),
//                     Text(
//                       '₹${cartTotal.toStringAsFixed(0)}',
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Table status helpers ─────────────────────────────────────────

// Color _tableStatusColor(String status) {
//   switch (status) {
//     case 'occupied':
//       return _C.occupied;
//     case 'reserved':
//       return _C.reserved;
//     case 'cleaning':
//       return _C.cleaning;
//     default:
//       return _C.available;
//   }
// }

// String _tableStatusEmoji(String status) {
//   switch (status) {
//     case 'occupied':
//       return '🍽️';
//     case 'reserved':
//       return '📅';
//     case 'cleaning':
//       return '🧹';
//     default:
//       return '✅';
//   }
// }

// /// ✅ FIXED LOGIC:
// /// available  → can take order (empty table)
// /// occupied   → can take order (extra items for seated guests)
// /// reserved   → can take order (guest arrived early / pre-order)
// /// cleaning   → CANNOT take order (table out of service)
// bool _tableIsSelectable(String status) => status != 'cleaning';

// // ══════════════════════════════════════════════════════════════
// //  MENU VIEW
// // ══════════════════════════════════════════════════════════════
// class _MenuView extends StatelessWidget {
//   final List<Map<String, dynamic>> categories;
//   final List<Map<String, dynamic>> items;
//   final String selectedCategory;
//   final TextEditingController searchCtrl;
//   final Map<String, CartItem> cart;
//   final bool loading;
//   final ValueChanged<String> onCategoryChanged;
//   final ValueChanged<String> onSearchChanged;
//   final ValueChanged<Map<String, dynamic>> onAdd;
//   final ValueChanged<String> onRemove;

//   const _MenuView({
//     Key? key,
//     required this.categories,
//     required this.items,
//     required this.selectedCategory,
//     required this.searchCtrl,
//     required this.cart,
//     required this.loading,
//     required this.onCategoryChanged,
//     required this.onSearchChanged,
//     required this.onAdd,
//     required this.onRemove,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (loading)
//       return const Center(child: CircularProgressIndicator(color: _C.primary));

//     final unavailableCount = items
//         .where((i) => !(i['is_available'] as bool? ?? true))
//         .length;

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
//           child: SizedBox(
//             height: 42,
//             child: TextField(
//               controller: searchCtrl,
//               onChanged: onSearchChanged,
//               style: const TextStyle(fontSize: 14, color: _C.textPri),
//               decoration: InputDecoration(
//                 hintText: 'Search dishes...',
//                 hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
//                 prefixIcon: const Icon(
//                   Icons.search_rounded,
//                   color: _C.textMute,
//                   size: 19,
//                 ),
//                 suffixIcon: searchCtrl.text.isNotEmpty
//                     ? GestureDetector(
//                         onTap: () {
//                           searchCtrl.clear();
//                           onSearchChanged('');
//                         },
//                         child: const Icon(
//                           Icons.close_rounded,
//                           size: 16,
//                           color: _C.textMute,
//                         ),
//                       )
//                     : null,
//                 filled: true,
//                 fillColor: _C.surface,
//                 contentPadding: EdgeInsets.zero,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.border),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.border),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.primary, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         SizedBox(
//           height: 40,
//           child: ListView(
//             scrollDirection: Axis.horizontal,
//             padding: const EdgeInsets.only(left: 16, right: 8),
//             children: [
//               _CatChip(
//                 label: 'All',
//                 isSelected: selectedCategory == 'All',
//                 onTap: () => onCategoryChanged('All'),
//               ),
//               ...categories.map(
//                 (c) => _CatChip(
//                   label: '${c['icon'] ?? '🍽️'} ${c['name']}',
//                   isSelected: selectedCategory == c['name'],
//                   onTap: () => onCategoryChanged(c['name'] as String),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         if (unavailableCount > 0)
//           Container(
//             margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//             decoration: BoxDecoration(
//               color: const Color(0xFFFFF4E0),
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(
//                 color: const Color(0xFFD97706).withOpacity(0.4),
//               ),
//             ),
//             child: Row(
//               children: [
//                 const Text('⚠️', style: TextStyle(fontSize: 13)),
//                 const SizedBox(width: 8),
//                 Text(
//                   '$unavailableCount item${unavailableCount > 1 ? 's' : ''} currently unavailable',
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: Color(0xFFB45309),
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         const SizedBox(height: 6),
//         Expanded(
//           child: items.isEmpty
//               ? const Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text('🍽️', style: TextStyle(fontSize: 44)),
//                       SizedBox(height: 12),
//                       Text(
//                         'No items found',
//                         style: TextStyle(color: _C.textSec),
//                       ),
//                     ],
//                   ),
//                 )
//               : ListView.separated(
//                   padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
//                   itemCount: items.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 8),
//                   itemBuilder: (_, i) {
//                     final item = items[i];
//                     final id = item['id'] as String;
//                     return _MenuTile(
//                       item: item,
//                       quantity: cart[id]?.quantity ?? 0,
//                       onAdd: () => onAdd(item),
//                       onRemove: () => onRemove(id),
//                     );
//                   },
//                 ),
//         ),
//       ],
//     );
//   }
// }

// class _CatChip extends StatelessWidget {
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;
//   const _CatChip({
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 8),
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 150),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//           decoration: BoxDecoration(
//             color: isSelected ? _C.primary : _C.surface,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: isSelected ? _C.primary : _C.border),
//           ),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w700,
//               color: isSelected ? Colors.white : _C.textSec,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _MenuTile extends StatelessWidget {
//   final Map<String, dynamic> item;
//   final int quantity;
//   final VoidCallback onAdd;
//   final VoidCallback onRemove;
//   const _MenuTile({
//     required this.item,
//     required this.quantity,
//     required this.onAdd,
//     required this.onRemove,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isAvailable = item['is_available'] as bool? ?? true;
//     final inCart = quantity > 0;
//     final isVeg = item['is_veg'] as bool? ?? true;
//     final vegColor = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
//     final price = (item['discount_price'] ?? item['price'] as num).toDouble();
//     final isBestseller = item['is_best_seller'] as bool? ?? false;

//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 150),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: isAvailable ? _C.surface : const Color(0xFFF8F8F8),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//           color: !isAvailable
//               ? const Color(0xFFE5E5E5)
//               : inCart
//               ? _C.primary.withOpacity(0.4)
//               : _C.border,
//           width: inCart ? 1.5 : 1,
//         ),
//         boxShadow: (inCart && isAvailable)
//             ? [
//                 BoxShadow(
//                   color: _C.primary.withOpacity(0.08),
//                   blurRadius: 8,
//                   offset: const Offset(0, 3),
//                 ),
//               ]
//             : [],
//       ),
//       child: Row(
//         children: [
//           Opacity(
//             opacity: isAvailable ? 1.0 : 0.4,
//             child: Container(
//               width: 14,
//               height: 14,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(3),
//                 border: Border.all(color: vegColor, width: 1.5),
//               ),
//               alignment: Alignment.center,
//               child: Container(
//                 width: 7,
//                 height: 7,
//                 decoration: BoxDecoration(
//                   color: vegColor,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Opacity(
//               opacity: isAvailable ? 1.0 : 0.5,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           item['name'] as String,
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w700,
//                             color: isAvailable ? _C.textPri : _C.textMute,
//                           ),
//                         ),
//                       ),
//                       if (!isAvailable)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFDC2626).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Text(
//                             'Unavailable',
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFFDC2626),
//                             ),
//                           ),
//                         )
//                       else if (isBestseller)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFFF6B35).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Text(
//                             '🔥 Best',
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFFFF6B35),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   if (item['description'] != null &&
//                       (item['description'] as String).isNotEmpty)
//                     Text(
//                       item['description'] as String,
//                       style: const TextStyle(fontSize: 11, color: _C.textMute),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   Text(
//                     item['category_name'] as String? ?? '',
//                     style: const TextStyle(fontSize: 10, color: _C.textMute),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Opacity(
//             opacity: isAvailable ? 1.0 : 0.4,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 if (item['discount_price'] != null)
//                   Text(
//                     '₹${(item['price'] as num).toStringAsFixed(0)}',
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: _C.textMute,
//                       decoration: TextDecoration.lineThrough,
//                     ),
//                   ),
//                 Text(
//                   '₹${price.toStringAsFixed(0)}',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w800,
//                     color: isAvailable ? _C.textPri : _C.textMute,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           if (!isAvailable)
//             Container(
//               width: 32,
//               height: 32,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFE5E5E5),
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               child: const Icon(
//                 Icons.block,
//                 color: Color(0xFFAAAAAA),
//                 size: 16,
//               ),
//             )
//           else if (quantity == 0)
//             GestureDetector(
//               onTap: onAdd,
//               child: Container(
//                 width: 32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color: _C.primary,
//                   borderRadius: BorderRadius.circular(9),
//                 ),
//                 child: const Icon(Icons.add, color: Colors.white, size: 18),
//               ),
//             )
//           else
//             Row(
//               children: [
//                 GestureDetector(
//                   onTap: onRemove,
//                   child: Container(
//                     width: 28,
//                     height: 28,
//                     decoration: BoxDecoration(
//                       color: _C.primaryL,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.remove,
//                       color: _C.primary,
//                       size: 16,
//                     ),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 28,
//                   child: Text(
//                     '$quantity',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: onAdd,
//                   child: Container(
//                     width: 28,
//                     height: 28,
//                     decoration: BoxDecoration(
//                       color: _C.primary,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(Icons.add, color: Colors.white, size: 16),
//                   ),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════
// //  CART VIEW
// // ══════════════════════════════════════════════════════════════
// class _CartView extends StatelessWidget {
//   final List<CartItem> cartItems;
//   final OrderType orderType;
//   final List<Map<String, dynamic>> tables;
//   final String? selectedTableId;
//   final TextEditingController customerCtrl, phoneCtrl, noteCtrl;
//   final double cartSubtotal, cartTax, cartTotal;
//   final bool placing;
//   final ValueChanged<OrderType> onTypeChanged;
//   final Function(String id, int num) onTableSelected;
//   final ValueChanged<Map<String, dynamic>> onAdd;
//   final ValueChanged<String> onRemove;
//   final VoidCallback onPlaceOrder;

//   const _CartView({
//     Key? key,
//     required this.cartItems,
//     required this.orderType,
//     required this.tables,
//     required this.selectedTableId,
//     required this.customerCtrl,
//     required this.phoneCtrl,
//     required this.noteCtrl,
//     required this.cartSubtotal,
//     required this.cartTax,
//     required this.cartTotal,
//     required this.placing,
//     required this.onTypeChanged,
//     required this.onTableSelected,
//     required this.onAdd,
//     required this.onRemove,
//     required this.onPlaceOrder,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (cartItems.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('🛒', style: TextStyle(fontSize: 52)),
//             SizedBox(height: 16),
//             Text(
//               'Cart is empty',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: _C.textPri,
//               ),
//             ),
//             SizedBox(height: 6),
//             Text(
//               'Go back to add items',
//               style: TextStyle(fontSize: 13, color: _C.textSec),
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
//       children: [
//         // Order type
//         _SectionLabel('Order Type'),
//         const SizedBox(height: 10),
//         Row(
//           children: OrderType.values.map((t) {
//             final isSel = orderType == t;
//             return Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: GestureDetector(
//                   onTap: () => onTypeChanged(t),
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 150),
//                     padding: const EdgeInsets.symmetric(vertical: 11),
//                     decoration: BoxDecoration(
//                       color: isSel ? _C.primaryL : _C.surface,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSel ? _C.primary : _C.border,
//                         width: isSel ? 1.5 : 1,
//                       ),
//                     ),
//                     child: Column(
//                       children: [
//                         Text(t.emoji, style: const TextStyle(fontSize: 18)),
//                         const SizedBox(height: 4),
//                         Text(
//                           t.label,
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: isSel ? _C.primary : _C.textSec,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//         const SizedBox(height: 16),

//         // ── TABLE PICKER ─────────────────────────────────────────
//         if (orderType == OrderType.dineIn) ...[
//           _SectionLabel('Select Table'),
//           const SizedBox(height: 6),

//           // Legend — 4 statuses, cleaning shown as disabled
//           Padding(
//             padding: const EdgeInsets.only(bottom: 10),
//             child: Wrap(
//               spacing: 14,
//               runSpacing: 4,
//               children: const [
//                 _LegendDot(color: _C.available, label: 'Available'),
//                 _LegendDot(color: _C.occupied, label: 'Occupied (can order)'),
//                 _LegendDot(color: _C.reserved, label: 'Reserved (can order)'),
//                 _LegendDot(color: _C.cleaning, label: 'Cleaning (no order)'),
//               ],
//             ),
//           ),

//           if (tables.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFEF2F2),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: const Color(0xFFDC2626).withOpacity(0.2),
//                 ),
//               ),
//               child: const Row(
//                 children: [
//                   Text('⚠️', style: TextStyle(fontSize: 16)),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'No tables found',
//                       style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Wrap(
//               spacing: 10,
//               runSpacing: 10,
//               children: tables.map((t) {
//                 final tid = t['id'] as String;
//                 final num = t['table_number'] as int;
//                 final cap = t['capacity'] as int;
//                 final status = t['status'] as String? ?? 'available';
//                 final customer = t['current_customer_name'] as String?;
//                 final isSel = selectedTableId == tid;
//                 final canSelect = _tableIsSelectable(
//                   status,
//                 ); // cleaning = false, rest = true
//                 final statusColor = _tableStatusColor(status);

//                 return GestureDetector(
//                   onTap: canSelect ? () => onTableSelected(tid, num) : null,
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 150),
//                     width: 82,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isSel
//                           ? _C.primary
//                           : !canSelect
//                           ? const Color(0xFFF5F5F5) // cleaning: greyed out
//                           : statusColor.withOpacity(0.08),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSel
//                             ? _C.primary
//                             : !canSelect
//                             ? const Color(0xFFDDDDDD) // cleaning: muted border
//                             : statusColor.withOpacity(0.5),
//                         width: isSel ? 2 : 1,
//                       ),
//                       boxShadow: isSel
//                           ? [
//                               BoxShadow(
//                                 color: _C.primary.withOpacity(0.3),
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ]
//                           : [],
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           _tableStatusEmoji(status),
//                           style: const TextStyle(fontSize: 14),
//                         ),
//                         const SizedBox(height: 3),
//                         Text(
//                           'T$num',
//                           style: TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w900,
//                             color: isSel
//                                 ? Colors.white
//                                 : !canSelect
//                                 ? _C
//                                       .textMute // cleaning: muted text
//                                 : statusColor,
//                           ),
//                         ),
//                         Text(
//                           '$cap seats',
//                           style: TextStyle(
//                             fontSize: 9,
//                             color: isSel ? Colors.white70 : _C.textMute,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 5,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: isSel
//                                 ? Colors.white.withOpacity(0.2)
//                                 : !canSelect
//                                 ? const Color(0xFFEEEEEE)
//                                 : statusColor.withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text(
//                             _statusLabel(status),
//                             style: TextStyle(
//                               fontSize: 8,
//                               fontWeight: FontWeight.w700,
//                               color: isSel
//                                   ? Colors.white
//                                   : !canSelect
//                                   ? _C.textMute
//                                   : statusColor,
//                             ),
//                           ),
//                         ),
//                         // Show customer name for occupied tables
//                         if (customer != null &&
//                             customer.isNotEmpty &&
//                             !isSel) ...[
//                           const SizedBox(height: 3),
//                           Text(
//                             customer,
//                             style: const TextStyle(
//                               fontSize: 8,
//                               color: _C.textMute,
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                             textAlign: TextAlign.center,
//                           ),
//                         ],
//                         // "Cleaning" lock icon hint
//                         if (!canSelect) ...[
//                           const SizedBox(height: 3),
//                           const Icon(
//                             Icons.lock_outline_rounded,
//                             size: 10,
//                             color: _C.textMute,
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           const SizedBox(height: 14),
//         ],

//         // Customer info
//         Row(
//           children: [
//             Expanded(
//               child: _Field(
//                 label: 'Customer Name',
//                 hint: 'Enter name',
//                 ctrl: customerCtrl,
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: _Field(label: 'Phone', hint: 'Optional', ctrl: phoneCtrl),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),

//         // Cart items
//         _SectionLabel('Cart (${cartItems.length} items)'),
//         const SizedBox(height: 10),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: cartItems.asMap().entries.map((e) {
//               final i = e.key;
//               final ci = e.value;
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 ci.itemName,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w700,
//                                   color: _C.textPri,
//                                 ),
//                               ),
//                               Text(
//                                 '₹${ci.itemPrice.toStringAsFixed(0)} each',
//                                 style: const TextStyle(
//                                   fontSize: 11,
//                                   color: _C.textMute,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Text(
//                           '₹${ci.subtotal.toStringAsFixed(0)}',
//                           style: const TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w800,
//                             color: _C.textPri,
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Row(
//                           children: [
//                             GestureDetector(
//                               onTap: () => onRemove(ci.menuItemId),
//                               child: Container(
//                                 width: 26,
//                                 height: 26,
//                                 decoration: BoxDecoration(
//                                   color: _C.primaryL,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(
//                                   Icons.remove,
//                                   color: _C.primary,
//                                   size: 14,
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               width: 28,
//                               child: Text(
//                                 '${ci.quantity}',
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w900,
//                                   color: _C.primary,
//                                 ),
//                               ),
//                             ),
//                             GestureDetector(
//                               onTap: () => onAdd({
//                                 'id': ci.menuItemId,
//                                 'name': ci.itemName,
//                                 'price': ci.itemPrice,
//                                 'is_veg': ci.isVeg,
//                                 'category_name': ci.categoryName,
//                                 'is_available': true,
//                               }),
//                               child: Container(
//                                 width: 26,
//                                 height: 26,
//                                 decoration: BoxDecoration(
//                                   color: _C.primary,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(
//                                   Icons.add,
//                                   color: Colors.white,
//                                   size: 14,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (i < cartItems.length - 1)
//                     const Divider(height: 1, color: _C.border),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),
//         const SizedBox(height: 14),

//         _Field(
//           label: 'Order Notes',
//           hint: 'Special instructions...',
//           ctrl: noteCtrl,
//         ),
//         const SizedBox(height: 18),

//         // Bill summary
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: _C.primaryL,
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Column(
//             children: [
//               _BillRow('Subtotal', '₹${cartSubtotal.toStringAsFixed(0)}'),
//               const SizedBox(height: 6),
//               _BillRow('Tax (5%)', '₹${cartTax.toStringAsFixed(0)}'),
//               const Divider(color: _C.border, height: 16),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Total',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                   Text(
//                     '₹${cartTotal.toStringAsFixed(0)}',
//                     style: const TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 18),

//         // Place order button
//         GestureDetector(
//           onTap: placing ? null : onPlaceOrder,
//           child: Container(
//             width: double.infinity,
//             padding: const EdgeInsets.symmetric(vertical: 17),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: placing
//                     ? [Colors.grey, Colors.grey.shade400]
//                     : [_C.primary, _C.primaryD],
//               ),
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: placing
//                   ? []
//                   : [
//                       BoxShadow(
//                         color: _C.primary.withOpacity(0.35),
//                         blurRadius: 16,
//                         offset: const Offset(0, 6),
//                       ),
//                     ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 if (placing) ...[
//                   const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       color: Colors.white,
//                       strokeWidth: 2,
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Placing Order...',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ] else ...[
//                   const Icon(
//                     Icons.check_circle_outline,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Place Order',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// String _statusLabel(String status) {
//   switch (status) {
//     case 'occupied':
//       return 'Occupied';
//     case 'reserved':
//       return 'Reserved';
//     case 'cleaning':
//       return 'Cleaning';
//     default:
//       return 'Free';
//   }
// }

// // ── Legend dot ───────────────────────────────────────────────────
// class _LegendDot extends StatelessWidget {
//   final Color color;
//   final String label;
//   const _LegendDot({required this.color, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 8,
//           height: 8,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         const SizedBox(width: 4),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 10,
//             color: _C.textSec,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Helpers ───────────────────────────────────────────────────────
// class _SectionLabel extends StatelessWidget {
//   final String text;
//   const _SectionLabel(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text.toUpperCase(),
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w800,
//       color: _C.textMute,
//       letterSpacing: 1.4,
//     ),
//   );
// }

// class _Field extends StatelessWidget {
//   final String label, hint;
//   final TextEditingController ctrl;
//   const _Field({required this.label, required this.hint, required this.ctrl});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             color: _C.textSec,
//             letterSpacing: 0.3,
//           ),
//         ),
//         const SizedBox(height: 6),
//         TextField(
//           controller: ctrl,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: _C.textPri,
//           ),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
//             filled: true,
//             fillColor: _C.surface,
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 14,
//               vertical: 12,
//             ),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.primary, width: 1.5),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _BillRow extends StatelessWidget {
//   final String label, value;
//   const _BillRow(this.label, this.value);
//   @override
//   Widget build(BuildContext context) => Row(
//     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//     children: [
//       Text(label, style: const TextStyle(fontSize: 13, color: _C.textSec)),
//       Text(
//         value,
//         style: const TextStyle(
//           fontSize: 13,
//           fontWeight: FontWeight.w700,
//           color: _C.textPri,
//         ),
//       ),
//     ],
//   );
// }

// /*
// import 'package:flutter/material.dart';
// import 'package:pos_app/models/order_modal.dart';
// import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../providers/orders_provider.dart';

// class _C {
//   static const bg = Color(0xFFF6F6FB);
//   static const surface = Color(0xFFFFFFFF);
//   static const surfaceAlt = Color(0xFFF2F2F8);
//   static const border = Color(0xFFEAEAF4);
//   static const primary = Color(0xFF5A3FD6);
//   static const primaryL = Color(0xFFEDE9FF);
//   static const primaryD = Color(0xFF3D2AA0);
//   static const textPri = Color(0xFF1A1A2E);
//   static const textSec = Color(0xFF6B6B86);
//   static const textMute = Color(0xFFAAABBB);
//   static const occupied = Color(0xFFDC2626);
//   static const reserved = Color(0xFF7C3AED);
//   static const available = Color(0xFF059669);
//   static const cleaning = Color(0xFFD97706);
// }

// // ══════════════════════════════════════════════════════════════
// //  NEW ORDER SCREEN
// // ══════════════════════════════════════════════════════════════
// class NewOrderScreen extends StatefulWidget {
//   final String? preselectedTableId;
//   final int? preselectedTableNumber;

//   const NewOrderScreen({
//     Key? key,
//     this.preselectedTableId,
//     this.preselectedTableNumber,
//   }) : super(key: key);

//   @override
//   State<NewOrderScreen> createState() => _NewOrderScreenState();
// }

// class _NewOrderScreenState extends State<NewOrderScreen> {
//   String _businessId = '';

//   List<Map<String, dynamic>> _categories = [];
//   // ALL items (available + unavailable) so we can show grayed-out unavailable ones
//   List<Map<String, dynamic>> _allMenuItems = [];
//   bool _menuLoading = true;

//   // ALL tables (not just available) so the staff can see the floor status
//   List<Map<String, dynamic>> _tables = [];

//   final Map<String, CartItem> _cart = {};

//   OrderType _orderType = OrderType.dineIn;
//   String? _selectedTableId;
//   int? _selectedTableNumber;
//   final _customerCtrl = TextEditingController();
//   final _phoneCtrl = TextEditingController();
//   final _noteCtrl = TextEditingController();
//   final _searchCtrl = TextEditingController();

//   String _selectedCategory = 'All';
//   String _searchQuery = '';
//   bool _showCart = false;
//   bool _placing = false;

//   // ── Computed ─────────────────────────────────────────────────
//   List<CartItem> get cartItems => _cart.values.toList();
//   double get cartSubtotal => cartItems.fold(0.0, (s, i) => s + i.subtotal);
//   double get cartTax => cartSubtotal * 0.05;
//   double get cartTotal => cartSubtotal + cartTax;
//   int get cartCount => cartItems.fold(0, (s, i) => s + i.quantity);

//   /// Returns ALL items in the selected category/search — including unavailable
//   List<Map<String, dynamic>> get filteredItems {
//     List<Map<String, dynamic>> items = _selectedCategory == 'All'
//         ? _allMenuItems
//         : _allMenuItems
//               .where((i) => i['category_name'] == _selectedCategory)
//               .toList();
//     if (_searchQuery.isNotEmpty) {
//       final q = _searchQuery.toLowerCase();
//       items = items
//           .where((i) => (i['name'] as String).toLowerCase().contains(q))
//           .toList();
//     }
//     // Sort: available first, unavailable at the bottom
//     items.sort((a, b) {
//       final aAvail = a['is_available'] as bool? ?? true;
//       final bAvail = b['is_available'] as bool? ?? true;
//       if (aAvail == bAvail) return 0;
//       return aAvail ? -1 : 1;
//     });
//     return items;
//   }

//   // ── Lifecycle ─────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     _selectedTableId = widget.preselectedTableId;
//     _selectedTableNumber = widget.preselectedTableNumber;
//     _load();
//   }

//   @override
//   void dispose() {
//     _customerCtrl.dispose();
//     _phoneCtrl.dispose();
//     _noteCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _load() async {
//     final prefs = await SharedPreferences.getInstance();
//     _businessId = prefs.getString('businessId') ?? '';
//     await Future.wait([_loadMenu(), _loadTables()]);
//   }

//   Future<void> _loadMenu() async {
//     if (_businessId.isEmpty) return;
//     try {
//       final cats = await Supabase.instance.client
//           .from('menu_categories')
//           .select('id, name, icon, color_hex')
//           .eq('business_id', _businessId)
//           .eq('is_active', true)
//           .order('display_order');

//       // Fetch ALL items — including unavailable — so we can show them grayed out
//       final items = await Supabase.instance.client
//           .from('menu_items')
//           .select(
//             'id, name, description, price, discount_price, is_veg, is_available, '
//             'is_featured, is_best_seller, preparation_time, category_id, '
//             'menu_categories!inner(name, icon, color_hex)',
//           )
//           .eq('business_id', _businessId)
//           .order('sort_order');

//       setState(() {
//         _categories = (cats as List).cast<Map<String, dynamic>>();
//         _allMenuItems = (items as List).map((item) {
//           final cat = item['menu_categories'] as Map<String, dynamic>? ?? {};
//           return {
//             ...Map<String, dynamic>.from(item as Map),
//             'category_name': cat['name'] ?? '',
//             'category_icon': cat['icon'] ?? '🍽️',
//             'category_color': cat['color_hex'] ?? '#D4673A',
//           };
//         }).toList();
//         _menuLoading = false;
//       });
//     } catch (e) {
//       setState(() => _menuLoading = false);
//     }
//   }

//   Future<void> _loadTables() async {
//     if (_businessId.isEmpty) return;
//     try {
//       // Load ALL active tables (available, occupied, reserved, cleaning)
//       final data = await Supabase.instance.client
//           .from('restaurant_tables')
//           .select(
//             'id, table_number, capacity, status, section, current_customer_name',
//           )
//           .eq('business_id', _businessId)
//           .eq('is_active', true)
//           .order('table_number');

//       setState(() => _tables = (data as List).cast<Map<String, dynamic>>());
//     } catch (_) {}
//   }

//   // ── Cart operations ───────────────────────────────────────────
//   void _addItem(Map<String, dynamic> item) {
//     // Guard: do not add unavailable items
//     if (!(item['is_available'] as bool? ?? true)) return;

//     final id = item['id'] as String;
//     setState(() {
//       if (_cart.containsKey(id)) {
//         _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity + 1);
//       } else {
//         _cart[id] = CartItem(
//           menuItemId: id,
//           itemName: item['name'] as String,
//           itemPrice: (item['discount_price'] ?? item['price'] as num)
//               .toDouble(),
//           categoryName: item['category_name'] as String?,
//           isVeg: item['is_veg'] as bool? ?? true,
//         );
//       }
//     });
//   }

//   void _removeItem(String id) {
//     setState(() {
//       if (!_cart.containsKey(id)) return;
//       if (_cart[id]!.quantity <= 1) {
//         _cart.remove(id);
//       } else {
//         _cart[id] = _cart[id]!.copyWith(quantity: _cart[id]!.quantity - 1);
//       }
//     });
//   }

//   Future<void> _placeOrder() async {
//     if (_cart.isEmpty) {
//       _snack('Add items to cart first');
//       return;
//     }
//     if (_orderType == OrderType.dineIn && _selectedTableId == null) {
//       _snack('Please select a table');
//       return;
//     }

//     setState(() => _placing = true);

//     try {
//       final prov = context.read<OrdersProvider>();
//       await prov.createOrder(
//         cartItems: cartItems,
//         orderType: _orderType,
//         tableId: _selectedTableId,
//         tableNumber: _selectedTableNumber,
//         customerName: _customerCtrl.text.isEmpty ? null : _customerCtrl.text,
//         customerPhone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
//         notes: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
//       );
//       if (mounted) Navigator.pop(context);
//     } catch (e) {
//       _snack('Failed to place order: $e');
//     } finally {
//       if (mounted) setState(() => _placing = false);
//     }
//   }

//   void _snack(String msg) =>
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _C.bg,
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: AnimatedSwitcher(
//                 duration: const Duration(milliseconds: 250),
//                 child: _showCart
//                     ? _CartView(
//                         key: const ValueKey('cart'),
//                         cartItems: cartItems,
//                         orderType: _orderType,
//                         tables: _tables, // ALL tables
//                         selectedTableId: _selectedTableId,
//                         customerCtrl: _customerCtrl,
//                         phoneCtrl: _phoneCtrl,
//                         noteCtrl: _noteCtrl,
//                         cartSubtotal: cartSubtotal,
//                         cartTax: cartTax,
//                         cartTotal: cartTotal,
//                         placing: _placing,
//                         onTypeChanged: (t) => setState(() => _orderType = t),
//                         onTableSelected: (id, num) => setState(() {
//                           _selectedTableId = id;
//                           _selectedTableNumber = num;
//                         }),
//                         onAdd: _addItem,
//                         onRemove: (id) => _removeItem(id),
//                         onPlaceOrder: _placeOrder,
//                       )
//                     : _MenuView(
//                         key: const ValueKey('menu'),
//                         categories: _categories,
//                         items: filteredItems,
//                         selectedCategory: _selectedCategory,
//                         searchCtrl: _searchCtrl,
//                         cart: _cart,
//                         loading: _menuLoading,
//                         onCategoryChanged: (c) =>
//                             setState(() => _selectedCategory = c),
//                         onSearchChanged: (q) =>
//                             setState(() => _searchQuery = q),
//                         onAdd: _addItem,
//                         onRemove: (id) => _removeItem(id),
//                       ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//       child: Row(
//         children: [
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: _C.surfaceAlt,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: _C.border),
//               ),
//               child: const Icon(
//                 Icons.arrow_back_ios_new,
//                 size: 16,
//                 color: _C.textPri,
//               ),
//             ),
//           ),
//           const SizedBox(width: 14),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'New Order',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w900,
//                     color: _C.textPri,
//                   ),
//                 ),
//                 Text(
//                   'Select items from menu',
//                   style: TextStyle(fontSize: 11, color: _C.textSec),
//                 ),
//               ],
//             ),
//           ),
//           GestureDetector(
//             onTap: () => setState(() => _showCart = !_showCart),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 180),
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
//               decoration: BoxDecoration(
//                 color: _showCart ? _C.primaryL : _C.primary,
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               child: Row(
//                 children: [
//                   Icon(
//                     _showCart
//                         ? Icons.menu_book_rounded
//                         : Icons.shopping_cart_outlined,
//                     color: _showCart ? _C.primary : Colors.white,
//                     size: 18,
//                   ),
//                   const SizedBox(width: 6),
//                   Text(
//                     _showCart ? 'Menu' : 'Cart ($cartCount)',
//                     style: TextStyle(
//                       color: _showCart ? _C.primary : Colors.white,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   if (!_showCart && cartTotal > 0) ...[
//                     const SizedBox(width: 6),
//                     Text(
//                       '₹${cartTotal.toStringAsFixed(0)}',
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Table status helpers ─────────────────────────────────────────
// Color _tableStatusColor(String status) {
//   switch (status) {
//     case 'occupied':
//       return _C.occupied;
//     case 'reserved':
//       return _C.reserved;
//     case 'cleaning':
//       return _C.cleaning;
//     default:
//       return _C.available;
//   }
// }

// String _tableStatusEmoji(String status) {
//   switch (status) {
//     case 'occupied':
//       return '🍽️';
//     case 'reserved':
//       return '📅';
//     case 'cleaning':
//       return '🧹';
//     default:
//       return '✅';
//   }
// }

// bool _tableIsSelectable(String status) => status == 'available';

// // ══════════════════════════════════════════════════════════════
// //  MENU VIEW
// // ══════════════════════════════════════════════════════════════
// class _MenuView extends StatelessWidget {
//   final List<Map<String, dynamic>> categories;
//   final List<Map<String, dynamic>> items;
//   final String selectedCategory;
//   final TextEditingController searchCtrl;
//   final Map<String, CartItem> cart;
//   final bool loading;
//   final ValueChanged<String> onCategoryChanged;
//   final ValueChanged<String> onSearchChanged;
//   final ValueChanged<Map<String, dynamic>> onAdd;
//   final ValueChanged<String> onRemove;

//   const _MenuView({
//     Key? key,
//     required this.categories,
//     required this.items,
//     required this.selectedCategory,
//     required this.searchCtrl,
//     required this.cart,
//     required this.loading,
//     required this.onCategoryChanged,
//     required this.onSearchChanged,
//     required this.onAdd,
//     required this.onRemove,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (loading)
//       return const Center(child: CircularProgressIndicator(color: _C.primary));

//     final unavailableCount = items
//         .where((i) => !(i['is_available'] as bool? ?? true))
//         .length;

//     return Column(
//       children: [
//         // Search
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
//           child: SizedBox(
//             height: 42,
//             child: TextField(
//               controller: searchCtrl,
//               onChanged: onSearchChanged,
//               style: const TextStyle(fontSize: 14, color: _C.textPri),
//               decoration: InputDecoration(
//                 hintText: 'Search dishes...',
//                 hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
//                 prefixIcon: const Icon(
//                   Icons.search_rounded,
//                   color: _C.textMute,
//                   size: 19,
//                 ),
//                 suffixIcon: searchCtrl.text.isNotEmpty
//                     ? GestureDetector(
//                         onTap: () {
//                           searchCtrl.clear();
//                           onSearchChanged('');
//                         },
//                         child: const Icon(
//                           Icons.close_rounded,
//                           size: 16,
//                           color: _C.textMute,
//                         ),
//                       )
//                     : null,
//                 filled: true,
//                 fillColor: _C.surface,
//                 contentPadding: EdgeInsets.zero,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.border),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.border),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: _C.primary, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         // Category chips
//         SizedBox(
//           height: 40,
//           child: ListView(
//             scrollDirection: Axis.horizontal,
//             padding: const EdgeInsets.only(left: 16, right: 8),
//             children: [
//               _CatChip(
//                 label: 'All',
//                 isSelected: selectedCategory == 'All',
//                 onTap: () => onCategoryChanged('All'),
//               ),
//               ...categories.map(
//                 (c) => _CatChip(
//                   label: '${c['icon'] ?? '🍽️'} ${c['name']}',
//                   isSelected: selectedCategory == c['name'],
//                   onTap: () => onCategoryChanged(c['name'] as String),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // Unavailable notice banner
//         if (unavailableCount > 0)
//           Container(
//             margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//             decoration: BoxDecoration(
//               color: const Color(0xFFFFF4E0),
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(
//                 color: const Color(0xFFD97706).withOpacity(0.4),
//               ),
//             ),
//             child: Row(
//               children: [
//                 const Text('⚠️', style: TextStyle(fontSize: 13)),
//                 const SizedBox(width: 8),
//                 Text(
//                   '$unavailableCount item${unavailableCount > 1 ? 's' : ''} currently unavailable — shown below but cannot be added',
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: Color(0xFFB45309),
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         const SizedBox(height: 6),
//         // Items list
//         Expanded(
//           child: items.isEmpty
//               ? const Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text('🍽️', style: TextStyle(fontSize: 44)),
//                       SizedBox(height: 12),
//                       Text(
//                         'No items found',
//                         style: TextStyle(color: _C.textSec),
//                       ),
//                     ],
//                   ),
//                 )
//               : ListView.separated(
//                   padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
//                   itemCount: items.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 8),
//                   itemBuilder: (_, i) {
//                     final item = items[i];
//                     final id = item['id'] as String;
//                     return _MenuTile(
//                       item: item,
//                       quantity: cart[id]?.quantity ?? 0,
//                       onAdd: () => onAdd(item),
//                       onRemove: () => onRemove(id),
//                     );
//                   },
//                 ),
//         ),
//       ],
//     );
//   }
// }

// class _CatChip extends StatelessWidget {
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;
//   const _CatChip({
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 8),
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 150),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//           decoration: BoxDecoration(
//             color: isSelected ? _C.primary : _C.surface,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: isSelected ? _C.primary : _C.border),
//           ),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w700,
//               color: isSelected ? Colors.white : _C.textSec,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Menu tile — handles available & unavailable states ───────────
// class _MenuTile extends StatelessWidget {
//   final Map<String, dynamic> item;
//   final int quantity;
//   final VoidCallback onAdd;
//   final VoidCallback onRemove;
//   const _MenuTile({
//     required this.item,
//     required this.quantity,
//     required this.onAdd,
//     required this.onRemove,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isAvailable = item['is_available'] as bool? ?? true;
//     final inCart = quantity > 0;
//     final isVeg = item['is_veg'] as bool? ?? true;
//     final vegColor = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
//     final price = (item['discount_price'] ?? item['price'] as num).toDouble();
//     final isBestseller = item['is_best_seller'] as bool? ?? false;

//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 150),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         // Grayed out background for unavailable items
//         color: isAvailable ? _C.surface : const Color(0xFFF8F8F8),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//           color: !isAvailable
//               ? const Color(0xFFE5E5E5)
//               : inCart
//               ? _C.primary.withOpacity(0.4)
//               : _C.border,
//           width: inCart ? 1.5 : 1,
//         ),
//         boxShadow: (inCart && isAvailable)
//             ? [
//                 BoxShadow(
//                   color: _C.primary.withOpacity(0.08),
//                   blurRadius: 8,
//                   offset: const Offset(0, 3),
//                 ),
//               ]
//             : [],
//       ),
//       child: Row(
//         children: [
//           // Veg indicator
//           Opacity(
//             opacity: isAvailable ? 1.0 : 0.4,
//             child: Container(
//               width: 14,
//               height: 14,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(3),
//                 border: Border.all(color: vegColor, width: 1.5),
//               ),
//               alignment: Alignment.center,
//               child: Container(
//                 width: 7,
//                 height: 7,
//                 decoration: BoxDecoration(
//                   color: vegColor,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Opacity(
//               opacity: isAvailable ? 1.0 : 0.5,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           item['name'] as String,
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w700,
//                             color: isAvailable ? _C.textPri : _C.textMute,
//                             decoration: isAvailable
//                                 ? null
//                                 : TextDecoration.none,
//                           ),
//                         ),
//                       ),
//                       if (!isAvailable)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFDC2626).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Text(
//                             'Unavailable',
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFFDC2626),
//                             ),
//                           ),
//                         )
//                       else if (isBestseller)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFFF6B35).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Text(
//                             '🔥 Best',
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.w700,
//                               color: Color(0xFFFF6B35),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   if (item['description'] != null &&
//                       (item['description'] as String).isNotEmpty)
//                     Text(
//                       item['description'] as String,
//                       style: const TextStyle(fontSize: 11, color: _C.textMute),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   Text(
//                     item['category_name'] as String? ?? '',
//                     style: const TextStyle(fontSize: 10, color: _C.textMute),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           // Price column
//           Opacity(
//             opacity: isAvailable ? 1.0 : 0.4,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 if (item['discount_price'] != null)
//                   Text(
//                     '₹${(item['price'] as num).toStringAsFixed(0)}',
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: _C.textMute,
//                       decoration: TextDecoration.lineThrough,
//                     ),
//                   ),
//                 Text(
//                   '₹${price.toStringAsFixed(0)}',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w800,
//                     color: isAvailable ? _C.textPri : _C.textMute,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           // Add / qty controls — disabled for unavailable items
//           if (!isAvailable)
//             Container(
//               width: 32,
//               height: 32,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFE5E5E5),
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               child: const Icon(
//                 Icons.block,
//                 color: Color(0xFFAAAAAA),
//                 size: 16,
//               ),
//             )
//           else if (quantity == 0)
//             GestureDetector(
//               onTap: onAdd,
//               child: Container(
//                 width: 32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color: _C.primary,
//                   borderRadius: BorderRadius.circular(9),
//                 ),
//                 child: const Icon(Icons.add, color: Colors.white, size: 18),
//               ),
//             )
//           else
//             Row(
//               children: [
//                 GestureDetector(
//                   onTap: onRemove,
//                   child: Container(
//                     width: 28,
//                     height: 28,
//                     decoration: BoxDecoration(
//                       color: _C.primaryL,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.remove,
//                       color: _C.primary,
//                       size: 16,
//                     ),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 28,
//                   child: Text(
//                     '$quantity',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: onAdd,
//                   child: Container(
//                     width: 28,
//                     height: 28,
//                     decoration: BoxDecoration(
//                       color: _C.primary,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(Icons.add, color: Colors.white, size: 16),
//                   ),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════
// //  CART VIEW
// // ══════════════════════════════════════════════════════════════
// class _CartView extends StatelessWidget {
//   final List<CartItem> cartItems;
//   final OrderType orderType;
//   final List<Map<String, dynamic>> tables;
//   final String? selectedTableId;
//   final TextEditingController customerCtrl, phoneCtrl, noteCtrl;
//   final double cartSubtotal, cartTax, cartTotal;
//   final bool placing;
//   final ValueChanged<OrderType> onTypeChanged;
//   final Function(String id, int num) onTableSelected;
//   final ValueChanged<Map<String, dynamic>> onAdd;
//   final ValueChanged<String> onRemove;
//   final VoidCallback onPlaceOrder;

//   const _CartView({
//     Key? key,
//     required this.cartItems,
//     required this.orderType,
//     required this.tables,
//     required this.selectedTableId,
//     required this.customerCtrl,
//     required this.phoneCtrl,
//     required this.noteCtrl,
//     required this.cartSubtotal,
//     required this.cartTax,
//     required this.cartTotal,
//     required this.placing,
//     required this.onTypeChanged,
//     required this.onTableSelected,
//     required this.onAdd,
//     required this.onRemove,
//     required this.onPlaceOrder,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (cartItems.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('🛒', style: TextStyle(fontSize: 52)),
//             SizedBox(height: 16),
//             Text(
//               'Cart is empty',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: _C.textPri,
//               ),
//             ),
//             SizedBox(height: 6),
//             Text(
//               'Go back to add items',
//               style: TextStyle(fontSize: 13, color: _C.textSec),
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
//       children: [
//         // Order type selector
//         _SectionLabel('Order Type'),
//         const SizedBox(height: 10),
//         Row(
//           children: OrderType.values.map((t) {
//             final isSel = orderType == t;
//             return Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: GestureDetector(
//                   onTap: () => onTypeChanged(t),
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 150),
//                     padding: const EdgeInsets.symmetric(vertical: 11),
//                     decoration: BoxDecoration(
//                       color: isSel ? _C.primaryL : _C.surface,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSel ? _C.primary : _C.border,
//                         width: isSel ? 1.5 : 1,
//                       ),
//                     ),
//                     child: Column(
//                       children: [
//                         Text(t.emoji, style: const TextStyle(fontSize: 18)),
//                         const SizedBox(height: 4),
//                         Text(
//                           t.label,
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: isSel ? _C.primary : _C.textSec,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//         const SizedBox(height: 16),

//         // ── TABLE PICKER (dine-in only) ───────────────────────────
//         if (orderType == OrderType.dineIn) ...[
//           _SectionLabel('Select Table'),
//           const SizedBox(height: 4),
//           // Legend
//           Padding(
//             padding: const EdgeInsets.only(bottom: 8),
//             child: Row(
//               children: [
//                 _LegendDot(color: _C.available, label: 'Available'),
//                 const SizedBox(width: 12),
//                 _LegendDot(color: _C.occupied, label: 'Occupied'),
//                 const SizedBox(width: 12),
//                 _LegendDot(color: _C.reserved, label: 'Reserved'),
//                 const SizedBox(width: 12),
//                 _LegendDot(color: _C.cleaning, label: 'Cleaning'),
//               ],
//             ),
//           ),
//           if (tables.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFEF2F2),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: const Color(0xFFDC2626).withOpacity(0.2),
//                 ),
//               ),
//               child: const Row(
//                 children: [
//                   Text('⚠️', style: TextStyle(fontSize: 16)),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'No tables found',
//                       style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             // Wrap so all tables are visible (not just a horizontal scroll)
//             Wrap(
//               spacing: 10,
//               runSpacing: 10,
//               children: tables.map((t) {
//                 final tid = t['id'] as String;
//                 final num = t['table_number'] as int;
//                 final cap = t['capacity'] as int;
//                 final status = t['status'] as String? ?? 'available';
//                 final customer = t['current_customer_name'] as String?;
//                 final isSel = selectedTableId == tid;
//                 final canSelect = _tableIsSelectable(status);
//                 final statusColor = _tableStatusColor(status);

//                 return GestureDetector(
//                   onTap: canSelect ? () => onTableSelected(tid, num) : null,
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 150),
//                     width: 80,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isSel
//                           ? _C.primary
//                           : canSelect
//                           ? _C.surface
//                           : statusColor.withOpacity(0.07),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isSel
//                             ? _C.primary
//                             : canSelect
//                             ? _C.border
//                             : statusColor.withOpacity(0.5),
//                         width: isSel ? 2 : 1,
//                       ),
//                       boxShadow: isSel
//                           ? [
//                               BoxShadow(
//                                 color: _C.primary.withOpacity(0.3),
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ]
//                           : [],
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         // Status emoji
//                         Text(
//                           _tableStatusEmoji(status),
//                           style: const TextStyle(fontSize: 14),
//                         ),
//                         const SizedBox(height: 3),
//                         Text(
//                           'T$num',
//                           style: TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w900,
//                             color: isSel
//                                 ? Colors.white
//                                 : (canSelect ? _C.textPri : statusColor),
//                           ),
//                         ),
//                         Text(
//                           '$cap seats',
//                           style: TextStyle(
//                             fontSize: 9,
//                             color: isSel ? Colors.white70 : _C.textMute,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 5,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: isSel
//                                 ? Colors.white.withOpacity(0.2)
//                                 : statusColor.withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text(
//                             status == 'available'
//                                 ? 'Free'
//                                 : status[0].toUpperCase() + status.substring(1),
//                             style: TextStyle(
//                               fontSize: 8,
//                               fontWeight: FontWeight.w700,
//                               color: isSel ? Colors.white : statusColor,
//                             ),
//                           ),
//                         ),
//                         // Show customer name if occupied
//                         if (customer != null && !isSel) ...[
//                           const SizedBox(height: 2),
//                           Text(
//                             customer,
//                             style: const TextStyle(
//                               fontSize: 8,
//                               color: _C.textMute,
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                             textAlign: TextAlign.center,
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           const SizedBox(height: 14),
//         ],

//         // Customer info
//         Row(
//           children: [
//             Expanded(
//               child: _Field(
//                 label: 'Customer Name',
//                 hint: 'Enter name',
//                 ctrl: customerCtrl,
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: _Field(label: 'Phone', hint: 'Optional', ctrl: phoneCtrl),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),

//         // Cart items
//         _SectionLabel('Cart (${cartItems.length} items)'),
//         const SizedBox(height: 10),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: cartItems.asMap().entries.map((e) {
//               final i = e.key;
//               final ci = e.value;
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 ci.itemName,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w700,
//                                   color: _C.textPri,
//                                 ),
//                               ),
//                               Text(
//                                 '₹${ci.itemPrice.toStringAsFixed(0)} each',
//                                 style: const TextStyle(
//                                   fontSize: 11,
//                                   color: _C.textMute,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Text(
//                           '₹${ci.subtotal.toStringAsFixed(0)}',
//                           style: const TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w800,
//                             color: _C.textPri,
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Row(
//                           children: [
//                             GestureDetector(
//                               onTap: () => onRemove(ci.menuItemId),
//                               child: Container(
//                                 width: 26,
//                                 height: 26,
//                                 decoration: BoxDecoration(
//                                   color: _C.primaryL,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(
//                                   Icons.remove,
//                                   color: _C.primary,
//                                   size: 14,
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               width: 28,
//                               child: Text(
//                                 '${ci.quantity}',
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w900,
//                                   color: _C.primary,
//                                 ),
//                               ),
//                             ),
//                             GestureDetector(
//                               onTap: () => onAdd({
//                                 'id': ci.menuItemId,
//                                 'name': ci.itemName,
//                                 'price': ci.itemPrice,
//                                 'is_veg': ci.isVeg,
//                                 'category_name': ci.categoryName,
//                                 'is_available': true,
//                               }),
//                               child: Container(
//                                 width: 26,
//                                 height: 26,
//                                 decoration: BoxDecoration(
//                                   color: _C.primary,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(
//                                   Icons.add,
//                                   color: Colors.white,
//                                   size: 14,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (i < cartItems.length - 1)
//                     const Divider(height: 1, color: _C.border),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),
//         const SizedBox(height: 14),

//         // Notes
//         _Field(
//           label: 'Order Notes',
//           hint: 'Special instructions...',
//           ctrl: noteCtrl,
//         ),
//         const SizedBox(height: 18),

//         // Bill summary
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: _C.primaryL,
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Column(
//             children: [
//               _BillRow('Subtotal', '₹${cartSubtotal.toStringAsFixed(0)}'),
//               const SizedBox(height: 6),
//               _BillRow('Tax (5%)', '₹${cartTax.toStringAsFixed(0)}'),
//               const Divider(color: _C.border, height: 16),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Total',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                   Text(
//                     '₹${cartTotal.toStringAsFixed(0)}',
//                     style: const TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 18),

//         // Place order button
//         GestureDetector(
//           onTap: placing ? null : onPlaceOrder,
//           child: Container(
//             width: double.infinity,
//             padding: const EdgeInsets.symmetric(vertical: 17),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: placing
//                     ? [Colors.grey, Colors.grey.shade400]
//                     : [_C.primary, _C.primaryD],
//               ),
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: placing
//                   ? []
//                   : [
//                       BoxShadow(
//                         color: _C.primary.withOpacity(0.35),
//                         blurRadius: 16,
//                         offset: const Offset(0, 6),
//                       ),
//                     ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 if (placing) ...[
//                   const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       color: Colors.white,
//                       strokeWidth: 2,
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Placing Order...',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ] else ...[
//                   const Icon(
//                     Icons.check_circle_outline,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Place Order',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

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
                child: Icon(Icons.person, size: 14, color: isSelected ? Colors.white : iconColor),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : (status == 'occupied' ? _C.occupied : _C.textPri),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// // ── Legend dot for table status ──────────────────────────────────
// class _LegendDot extends StatelessWidget {
//   final Color color;
//   final String label;
//   const _LegendDot({required this.color, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 8,
//           height: 8,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         const SizedBox(width: 4),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 10,
//             color: _C.textSec,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Helpers ───────────────────────────────────────────────────────
// class _SectionLabel extends StatelessWidget {
//   final String text;
//   const _SectionLabel(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text.toUpperCase(),
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w800,
//       color: _C.textMute,
//       letterSpacing: 1.4,
//     ),
//   );
// }

// class _Field extends StatelessWidget {
//   final String label, hint;
//   final TextEditingController ctrl;
//   const _Field({required this.label, required this.hint, required this.ctrl});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             color: _C.textSec,
//             letterSpacing: 0.3,
//           ),
//         ),
//         const SizedBox(height: 6),
//         TextField(
//           controller: ctrl,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: _C.textPri,
//           ),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: const TextStyle(color: _C.textMute, fontSize: 13),
//             filled: true,
//             fillColor: _C.surface,
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 14,
//               vertical: 12,
//             ),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: _C.primary, width: 1.5),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _BillRow extends StatelessWidget {
//   final String label, value;
//   const _BillRow(this.label, this.value);
//   @override
//   Widget build(BuildContext context) => Row(
//     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//     children: [
//       Text(label, style: const TextStyle(fontSize: 13, color: _C.textSec)),
//       Text(
//         value,
//         style: const TextStyle(
//           fontSize: 13,
//           fontWeight: FontWeight.w700,
//           color: _C.textPri,
//         ),
//       ),
//     ],
//   );
// }
// */
