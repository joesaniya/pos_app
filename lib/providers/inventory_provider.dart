// lib/providers/inventory_provider.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/services/stock_notification_service.dart';
import 'package:pos_app/services/storage_service.dart';

enum InventorySortBy { name, stockLowHigh, stockHighLow, lastUpdated, value }

enum InventoryFilter { all, inStock, lowStock, critical, outOfStock }

class InventoryProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedCategory = 'All';
  InventorySortBy _sortBy = InventorySortBy.name;
  InventoryFilter _filter = InventoryFilter.all;
  bool _isLoading = false;
  bool _isInitialized = false;
  String _errorMessage = '';
  String _businessId = '';
  String _userUid = '';
  String _userName = '';
  String _userRole = '';

  static const _allowedRoles = ['owner', 'system', 'manager', 'admin'];
  bool get canManageStock => _allowedRoles.contains(_userRole.toLowerCase());
  bool get isInitialized => _isInitialized;

  final List<InventoryItem> _items = [];

  InventoryProvider() {
    _init();
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await StorageService.instance.getUserData();
      _businessId = userData['businessId'] as String? ?? '';
      _userUid = userData['uid'] as String? ?? '';
      _userName = userData['name'] as String? ?? 'Unknown';
      _userRole = userData['role'] as String? ?? '';

      debugPrint(
        '[InventoryProvider] Init — businessId=$_businessId role=$_userRole name=$_userName',
      );

      if (_businessId.isNotEmpty) {
        await fetchItems();
        _subscribeRealtime();
      } else {
        log('local item seed');
        // _seedLocal();
      }
    } catch (e) {
      _errorMessage = 'Init failed: $e';
      debugPrint('[InventoryProvider] _init error: $e');
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  InventorySortBy get sortBy => _sortBy;
  InventoryFilter get activeFilter => _filter;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get userRole => _userRole;
  String get userName => _userName;

  List<String> get categories {
    final cats = _items.map((e) => e.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  List<InventoryItem> get filteredItems {
    var result = List<InventoryItem>.from(_items);

    if (_selectedCategory != 'All') {
      result = result.where((i) => i.category == _selectedCategory).toList();
    }

    if (_filter != InventoryFilter.all) {
      result = result.where((i) {
        switch (_filter) {
          case InventoryFilter.inStock:
            return i.status == StockStatus.inStock;
          case InventoryFilter.lowStock:
            return i.status == StockStatus.lowStock;
          case InventoryFilter.critical:
            return i.status == StockStatus.critical;
          case InventoryFilter.outOfStock:
            return i.status == StockStatus.outOfStock;
          default:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.category.toLowerCase().contains(q) ||
                i.supplier.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_sortBy) {
      case InventorySortBy.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case InventorySortBy.stockLowHigh:
        result.sort((a, b) => a.stockPercent.compareTo(b.stockPercent));
        break;
      case InventorySortBy.stockHighLow:
        result.sort((a, b) => b.stockPercent.compareTo(a.stockPercent));
        break;
      case InventorySortBy.lastUpdated:
        result.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case InventorySortBy.value:
        result.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
    }

    return result;
  }

  int get totalItems => _items.length;
  int get lowStockCount => _items
      .where(
        (i) =>
            i.status == StockStatus.lowStock ||
            i.status == StockStatus.critical,
      )
      .length;
  int get outOfStockCount =>
      _items.where((i) => i.status == StockStatus.outOfStock).length;
  double get totalInventoryValue => _items.fold(0, (s, i) => s + i.totalValue);

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategory(String c) {
    _selectedCategory = c;
    notifyListeners();
  }

  void setSortBy(InventorySortBy s) {
    _sortBy = s;
    notifyListeners();
  }

  void setFilter(InventoryFilter f) {
    _filter = f;
    notifyListeners();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> fetchItems() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final rows = await Supabase.instance.client
          .from('inventory_items')
          .select('''
            *,
            stock_transactions (
              id, transaction_type, quantity, stock_before, stock_after,
              unit, cost_per_unit, note, updated_by_name, updated_by_role, created_at
            )
          ''')
          .eq('business_id', _businessId)
          .eq('is_active', true)
          .order('name');

      _items.clear();
      for (final row in (rows as List)) {
        _items.add(InventoryItem.fromJson(row as Map<String, dynamic>));
      }
      debugPrint('[InventoryProvider] Fetched ${_items.length} items');
    } catch (e) {
      _errorMessage = 'Failed to load inventory: $e';
      debugPrint('[InventoryProvider] fetchItems error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Realtime ──────────────────────────────────────────────────────────────
  void _subscribeRealtime() {
    Supabase.instance.client
        .channel('inventory_realtime_$_businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: _businessId,
          ),
          callback: (_) => fetchItems(),
        )
        .subscribe();
  }

  // ── Add Item ──────────────────────────────────────────────────────────────
  Future<bool> addItem(InventoryItem item) async {
    // Wait for init if called before provider is ready
    if (!_isInitialized) {
      debugPrint('[InventoryProvider] addItem — waiting for init...');
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !_isInitialized;
      });
    }

    if (!canManageStock) {
      _errorMessage = 'You do not have permission to manage stock.';
      notifyListeners();
      return false;
    }

    if (_businessId.isEmpty) {
      _errorMessage = 'Business ID not found. Please re-login.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final data = item.toJson(_businessId);
      debugPrint('[InventoryProvider] Inserting item: $data');

      final inserted = await Supabase.instance.client
          .from('inventory_items')
          .insert(data)
          .select()
          .single();

      // Log initial stock-in transaction
      await _insertTransaction(
        itemId: inserted['id'] as String,
        type: TransactionType.stockIn,
        qty: item.currentStock,
        before: 0,
        after: item.currentStock,
        unit: item.unit,
        note: 'Initial stock entry',
        costPerUnit: item.costPerUnit,
      );

      await fetchItems();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add item: $e';
      debugPrint('[InventoryProvider] addItem error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Update Item ───────────────────────────────────────────────────────────
  Future<bool> updateItem(InventoryItem updated) async {
    if (!canManageStock) {
      _errorMessage = 'You do not have permission to manage stock.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final data = updated.toJson(_businessId);
      await Supabase.instance.client
          .from('inventory_items')
          .update(data)
          .eq('id', updated.id)
          .eq('business_id', _businessId); // extra safety

      final idx = _items.indexWhere((i) => i.id == updated.id);
      if (idx != -1) _items[idx] = updated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update item: $e';
      debugPrint('[InventoryProvider] updateItem error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Delete Item ───────────────────────────────────────────────────────────
  Future<void> deleteItem(String id) async {
    if (!canManageStock) return;
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('inventory_items')
          .update({'is_active': false})
          .eq('id', id)
          .eq('business_id', _businessId);
      _items.removeWhere((i) => i.id == id);
    } catch (e) {
      _errorMessage = 'Failed to delete item: $e';
      debugPrint('[InventoryProvider] deleteItem error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Record Transaction ────────────────────────────────────────────────────
  Future<void> recordTransaction({
    required String itemId,
    required TransactionType type,
    required double quantity,
    required String note,
    required String updatedBy,
  }) async {
    if (!canManageStock) return;
    _isLoading = true;
    notifyListeners();

    try {
      final idx = _items.indexWhere((i) => i.id == itemId);
      if (idx == -1) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final item = _items[idx];
      final prevStatus = item.status;

      // Calculate stock delta
      final double delta;
      switch (type) {
        case TransactionType.stockIn:
          delta = quantity;
          break;
        case TransactionType.adjustment:
          delta = quantity;
          break;
        case TransactionType.stockOut:
        case TransactionType.waste:
          delta = -quantity;
          break;
      }

      final newStock = (item.currentStock + delta).clamp(0.0, item.maxCapacity);

      // Update DB — trigger will auto-update stock_status
      await Supabase.instance.client
          .from('inventory_items')
          .update({'current_stock': newStock})
          .eq('id', itemId)
          .eq('business_id', _businessId);

      // Insert transaction record
      await _insertTransaction(
        itemId: itemId,
        type: type,
        qty: quantity,
        before: item.currentStock,
        after: newStock,
        unit: item.unit,
        note: note,
      );

      // Optimistic local update
      final tx = StockTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        quantity: quantity,
        stockBefore: item.currentStock,
        stockAfter: newStock,
        unit: item.unit,
        date: DateTime.now(),
        note: note,
        updatedBy: _userName,
        updatedByRole: _userRole,
      );

      _items[idx] = item.copyWith(
        currentStock: newStock,
        lastUpdated: DateTime.now(),
        transactions: [tx, ...item.transactions],
      );

      // Local notification if status changed
      final newItem = _items[idx];
      if (newItem.status != prevStatus) {
        await StockNotificationService.instance.checkAndNotify(
          item: newItem,
          previousStatus: prevStatus,
          businessId: _businessId,
        );
      }
    } catch (e) {
      _errorMessage = 'Failed to record transaction: $e';
      debugPrint('[InventoryProvider] recordTransaction error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Insert Transaction Row ────────────────────────────────────────────────
  Future<void> _insertTransaction({
    required String itemId,
    required TransactionType type,
    required double qty,
    required double before,
    required double after,
    required StockUnit unit,
    required String note,
    double? costPerUnit,
  }) async {
    await Supabase.instance.client.from('stock_transactions').insert({
      'item_id': itemId,
      'business_id': _businessId,
      'transaction_type': type.dbValue,
      'quantity': qty,
      'stock_before': before,
      'stock_after': after,
      'unit': unit.label,
      'cost_per_unit': costPerUnit,
      'total_cost': costPerUnit != null ? costPerUnit * qty : null,
      'note': note,
      'updated_by_uid': _userUid,
      'updated_by_name': _userName,
      'updated_by_role': _userRole,
    });
  }

  String generateId() => 'i${DateTime.now().millisecondsSinceEpoch % 10000}';

  // ── Local seed (no Supabase) ───────────────────────────────────────────────
  void _seedLocal() {
    _items.addAll([
      InventoryItem(
        id: 'i01',
        name: 'Rice Batter',
        category: 'Grains',
        emoji: '🍚',
        currentStock: 45,
        minThreshold: 10,
        maxCapacity: 100,
        unit: StockUnit.kg,
        costPerUnit: 25,
        supplier: 'Sri Annapoorna Traders',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      InventoryItem(
        id: 'i02',
        name: 'Urad Dal',
        category: 'Pulses',
        emoji: '🫘',
        currentStock: 8,
        minThreshold: 10,
        maxCapacity: 50,
        unit: StockUnit.kg,
        costPerUnit: 120,
        supplier: 'Murugan Pulses',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      InventoryItem(
        id: 'i03',
        name: 'Coconut Oil',
        category: 'Oils',
        emoji: '🥥',
        currentStock: 0,
        minThreshold: 5,
        maxCapacity: 30,
        unit: StockUnit.litre,
        costPerUnit: 180,
        supplier: 'Kerala Fresh',
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      ),
      InventoryItem(
        id: 'i04',
        name: 'Fresh Tomatoes',
        category: 'Vegetables',
        emoji: '🍅',
        currentStock: 12,
        minThreshold: 5,
        maxCapacity: 40,
        unit: StockUnit.kg,
        costPerUnit: 40,
        supplier: 'Santhosh Vegetables',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      InventoryItem(
        id: 'i05',
        name: 'Ghee',
        category: 'Dairy',
        emoji: '🧈',
        currentStock: 3,
        minThreshold: 5,
        maxCapacity: 20,
        unit: StockUnit.kg,
        costPerUnit: 600,
        supplier: 'Aavin Dairy',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      InventoryItem(
        id: 'i06',
        name: 'Toor Dal',
        category: 'Pulses',
        emoji: '🫘',
        currentStock: 35,
        minThreshold: 10,
        maxCapacity: 60,
        unit: StockUnit.kg,
        costPerUnit: 110,
        supplier: 'Murugan Pulses',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      InventoryItem(
        id: 'i07',
        name: 'Onions',
        category: 'Vegetables',
        emoji: '🧅',
        currentStock: 25,
        minThreshold: 8,
        maxCapacity: 50,
        unit: StockUnit.kg,
        costPerUnit: 35,
        supplier: 'Santhosh Vegetables',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      InventoryItem(
        id: 'i08',
        name: 'Mustard Seeds',
        category: 'Spices',
        emoji: '🌱',
        currentStock: 2,
        minThreshold: 1,
        maxCapacity: 10,
        unit: StockUnit.kg,
        costPerUnit: 90,
        supplier: 'Spice Garden',
        lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);
    notifyListeners();
  }
}

/*import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_modal.dart';


enum InventorySortBy { name, stockLowHigh, stockHighLow, lastUpdated, value }

enum InventoryFilter { all, inStock, lowStock, critical, outOfStock }

class InventoryProvider extends ChangeNotifier {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  InventorySortBy _sortBy = InventorySortBy.name;
  InventoryFilter _filter = InventoryFilter.all;
  bool _isLoading = false;

  final List<InventoryItem> _items = [
    InventoryItem(
      id: 'i01',
      name: 'Rice Batter',
      category: 'Grains',
      emoji: '🍚',
      currentStock: 45,
      minThreshold: 10,
      maxCapacity: 100,
      unit: StockUnit.kg,
      costPerUnit: 25,
      supplier: 'Sri Annapoorna Traders',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      transactions: [
        StockTransaction(
          id: 't1',
          type: TransactionType.stockIn,
          quantity: 20,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(hours: 2)),
          note: 'Morning delivery',
          updatedBy: 'Arjun K',
        ),
        StockTransaction(
          id: 't2',
          type: TransactionType.stockOut,
          quantity: 5,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(hours: 5)),
          note: 'Used for dosa prep',
          updatedBy: 'Chef Ravi',
        ),
      ],
    ),
    InventoryItem(
      id: 'i02',
      name: 'Urad Dal',
      category: 'Pulses',
      emoji: '🫘',
      currentStock: 8,
      minThreshold: 10,
      maxCapacity: 50,
      unit: StockUnit.kg,
      costPerUnit: 120,
      supplier: 'Murugan Pulses',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
      transactions: [
        StockTransaction(
          id: 't3',
          type: TransactionType.stockIn,
          quantity: 30,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(days: 3)),
          note: 'Weekly restock',
          updatedBy: 'Arjun K',
        ),
        StockTransaction(
          id: 't4',
          type: TransactionType.stockOut,
          quantity: 22,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(hours: 6)),
          note: 'Idli & Dosa production',
          updatedBy: 'Chef Ravi',
        ),
      ],
    ),
    InventoryItem(
      id: 'i03',
      name: 'Coconut Oil',
      category: 'Oils',
      emoji: '🥥',
      currentStock: 0,
      minThreshold: 5,
      maxCapacity: 30,
      unit: StockUnit.litre,
      costPerUnit: 180,
      supplier: 'Kerala Fresh',
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      transactions: [
        StockTransaction(
          id: 't5',
          type: TransactionType.stockOut,
          quantity: 5,
          unit: StockUnit.litre,
          date: DateTime.now().subtract(const Duration(days: 1)),
          note: 'Last batch used',
          updatedBy: 'Chef Ravi',
        ),
      ],
    ),
    InventoryItem(
      id: 'i04',
      name: 'Fresh Tomatoes',
      category: 'Vegetables',
      emoji: '🍅',
      currentStock: 12,
      minThreshold: 5,
      maxCapacity: 40,
      unit: StockUnit.kg,
      costPerUnit: 40,
      supplier: 'Santhosh Vegetables',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
      transactions: [
        StockTransaction(
          id: 't6',
          type: TransactionType.stockIn,
          quantity: 15,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(hours: 1)),
          note: 'Fresh morning delivery',
          updatedBy: 'Arjun K',
        ),
      ],
    ),
    InventoryItem(
      id: 'i05',
      name: 'Ghee',
      category: 'Dairy',
      emoji: '🧈',
      currentStock: 3,
      minThreshold: 5,
      maxCapacity: 20,
      unit: StockUnit.kg,
      costPerUnit: 600,
      supplier: 'Aavin Dairy',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
      transactions: [
        StockTransaction(
          id: 't7',
          type: TransactionType.waste,
          quantity: 0.5,
          unit: StockUnit.kg,
          date: DateTime.now().subtract(const Duration(hours: 3)),
          note: 'Expired batch discarded',
          updatedBy: 'Chef Ravi',
        ),
      ],
    ),
    InventoryItem(
      id: 'i06',
      name: 'Toor Dal',
      category: 'Pulses',
      emoji: '🫘',
      currentStock: 35,
      minThreshold: 10,
      maxCapacity: 60,
      unit: StockUnit.kg,
      costPerUnit: 110,
      supplier: 'Murugan Pulses',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    InventoryItem(
      id: 'i07',
      name: 'Onions',
      category: 'Vegetables',
      emoji: '🧅',
      currentStock: 25,
      minThreshold: 8,
      maxCapacity: 50,
      unit: StockUnit.kg,
      costPerUnit: 35,
      supplier: 'Santhosh Vegetables',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    InventoryItem(
      id: 'i08',
      name: 'Mustard Seeds',
      category: 'Spices',
      emoji: '🌱',
      currentStock: 2,
      minThreshold: 1,
      maxCapacity: 10,
      unit: StockUnit.kg,
      costPerUnit: 90,
      supplier: 'Spice Garden',
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    ),
    InventoryItem(
      id: 'i09',
      name: 'Sunflower Oil',
      category: 'Oils',
      emoji: '🌻',
      currentStock: 18,
      minThreshold: 10,
      maxCapacity: 50,
      unit: StockUnit.litre,
      costPerUnit: 130,
      supplier: 'Gold Drop Oils',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    InventoryItem(
      id: 'i10',
      name: 'Milk',
      category: 'Dairy',
      emoji: '🥛',
      currentStock: 20,
      minThreshold: 10,
      maxCapacity: 40,
      unit: StockUnit.litre,
      costPerUnit: 55,
      supplier: 'Aavin Dairy',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    InventoryItem(
      id: 'i11',
      name: 'Green Chilli',
      category: 'Vegetables',
      emoji: '🌶️',
      currentStock: 1,
      minThreshold: 2,
      maxCapacity: 10,
      unit: StockUnit.kg,
      costPerUnit: 60,
      supplier: 'Santhosh Vegetables',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    InventoryItem(
      id: 'i12',
      name: 'Curry Leaves',
      category: 'Herbs',
      emoji: '🌿',
      currentStock: 0.5,
      minThreshold: 0.2,
      maxCapacity: 3,
      unit: StockUnit.kg,
      costPerUnit: 80,
      supplier: 'Local Market',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  // ─── Getters ────────────────────────────────────────────────
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  InventorySortBy get sortBy => _sortBy;
  InventoryFilter get activeFilter => _filter;
  bool get isLoading => _isLoading;

  List<String> get categories {
    final cats = _items.map((e) => e.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  List<InventoryItem> get filteredItems {
    var result = List<InventoryItem>.from(_items);

    // Category filter
    if (_selectedCategory != 'All') {
      result = result.where((i) => i.category == _selectedCategory).toList();
    }
    // Status filter
    if (_filter != InventoryFilter.all) {
      result = result.where((i) {
        switch (_filter) {
          case InventoryFilter.inStock:
            return i.status == StockStatus.inStock;
          case InventoryFilter.lowStock:
            return i.status == StockStatus.lowStock;
          case InventoryFilter.critical:
            return i.status == StockStatus.critical;
          case InventoryFilter.outOfStock:
            return i.status == StockStatus.outOfStock;
          default:
            return true;
        }
      }).toList();
    }
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.category.toLowerCase().contains(q) ||
                i.supplier.toLowerCase().contains(q),
          )
          .toList();
    }
    // Sort
    switch (_sortBy) {
      case InventorySortBy.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case InventorySortBy.stockLowHigh:
        result.sort((a, b) => a.stockPercent.compareTo(b.stockPercent));
        break;
      case InventorySortBy.stockHighLow:
        result.sort((a, b) => b.stockPercent.compareTo(a.stockPercent));
        break;
      case InventorySortBy.lastUpdated:
        result.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case InventorySortBy.value:
        result.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
    }
    return result;
  }

  // Summary stats
  int get totalItems => _items.length;
  int get lowStockCount => _items
      .where(
        (i) =>
            i.status == StockStatus.lowStock ||
            i.status == StockStatus.critical,
      )
      .length;
  int get outOfStockCount =>
      _items.where((i) => i.status == StockStatus.outOfStock).length;
  double get totalInventoryValue => _items.fold(0, (s, i) => s + i.totalValue);

  // ─── Mutations ──────────────────────────────────────────────
  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategory(String c) {
    _selectedCategory = c;
    notifyListeners();
  }

  void setSortBy(InventorySortBy s) {
    _sortBy = s;
    notifyListeners();
  }

  void setFilter(InventoryFilter f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> addItem(InventoryItem item) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _items.add(item);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateItem(InventoryItem updated) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _items.indexWhere((i) => i.id == updated.id);
    if (idx != -1) _items[idx] = updated;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _items.removeWhere((i) => i.id == id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> recordTransaction({
    required String itemId,
    required TransactionType type,
    required double quantity,
    required String note,
    required String updatedBy,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      final item = _items[idx];
      final delta = (type == TransactionType.stockIn)
          ? quantity
          : (type == TransactionType.adjustment ? quantity : -quantity);
      final newStock = (item.currentStock + delta).clamp(0.0, item.maxCapacity);
      final tx = StockTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        quantity: quantity,
        unit: item.unit,
        date: DateTime.now(),
        note: note,
        updatedBy: updatedBy,
      );
      _items[idx] = item.copyWith(
        currentStock: newStock,
        lastUpdated: DateTime.now(),
        transactions: [tx, ...item.transactions],
      );
    }
    _isLoading = false;
    notifyListeners();
  }

  String generateId() => 'i${DateTime.now().millisecondsSinceEpoch % 10000}';
}
*/
