// lib/providers/inventory_provider.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/services/other_supplier_services.dart';
import 'package:pos_app/repositories/inventory_repository.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/services/stock_notification_service.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:uuid/uuid.dart'; // ← ADD THIS IMPORT

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

  // ── FIX: UUID generator ────────────────────────────────────────────────────
  final _uuid = const Uuid();

  // ── Fallback mechanisms ────────────────────────────────────────────────────
  Timer? _periodicRefreshTimer;
  StreamSubscription? _connectivitySubscription;

  static const _allowedRoles = ['owner', 'system', 'manager', 'admin'];
  bool get canManageStock => _allowedRoles.contains(_userRole.toLowerCase());
  bool get isInitialized => _isInitialized;

  final List<InventoryItem> _items = [];

  InventoryProvider() {
    _init();
  }

  // ── Init ───────────────────────────────────────────────────────────────────
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
        '[InventoryProvider] Init — businessId=$_businessId '
        'role=$_userRole name=$_userName',
      );

      if (_businessId.isNotEmpty) {
        await fetchItems();
        _subscribeRealtime();
        _setupPeriodicRefresh();
        _setupConnectivityMonitoring();
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

  /// Setup periodic refresh every 30 seconds as a fallback for realtime listener
  void _setupPeriodicRefresh() {
    if (_periodicRefreshTimer != null) return; // Already setup

    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      if (_businessId.isNotEmpty) {
        try {
          debugPrint('[InventoryProvider] 🔄 Periodic refresh triggered');
          await fetchItems();
        } catch (e) {
          debugPrint('[InventoryProvider] Periodic refresh error: $e');
        }
      }
    });
    debugPrint('[InventoryProvider] ✅ Periodic refresh setup (30s interval)');
  }

  /// Monitor network connectivity and re-subscribe when coming online
  void _setupConnectivityMonitoring() {
    final connectivity = ConnectivityService.instance;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.onStatusChange.listen((status) {
      if (status == NetworkStatus.online) {
        debugPrint(
          '[InventoryProvider] 📡 Back online — re-subscribing to realtime',
        );
        _subscribeRealtime(); // Re-subscribe when coming back online
        fetchItems(); // Force refresh to catch missed updates
      }
    });
  }

  // ── Getters ────────────────────────────────────────────────────────────────
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

  /// Raw unfiltered list — used by SupplierStockHistoryTab.
  List<InventoryItem> get allItems => List.unmodifiable(_items);

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

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> fetchItems() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final items = await InventoryRepository.instance.fetchItems(_businessId);
      _items.clear();
      _items.addAll(items);
      debugPrint('[InventoryProvider] Fetched ${_items.length} items');
    } catch (e) {
      _errorMessage = 'Failed to load inventory: $e';
      debugPrint('[InventoryProvider] fetchItems error: $e');
    }
    _isLoading = false;
    notifyListeners();

    // ── Double-fetch for offline-first ─────────────────────────────────────────
    if (ConnectivityService.instance.isOnline && _businessId.isNotEmpty) {
      try {
        await InventoryRepository.instance.refreshFromRemote(_businessId);
        final freshItems = await InventoryRepository.instance.fetchItems(
          _businessId,
        );
        _items.clear();
        _items.addAll(freshItems);
        notifyListeners();
      } catch (e) {
        debugPrint('[InventoryProvider] Remote refresh error: $e');
      }
    }
  }

  // ── Realtime ───────────────────────────────────────────────────────────────
  void _subscribeRealtime() {
    InventoryRepository.instance.subscribeRealtime(
      _businessId,
      () => fetchItems(),
    );
  }

  // ── Add Item ───────────────────────────────────────────────────────────────
  Future<bool> addItem(InventoryItem item) async {
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
      final resolvedSupplierId = await OtherSupplierService.instance
          .resolveOrCreate(
            businessId: _businessId,
            supplierName: item.supplier,
            existingId: item.supplierId,
          );

      final itemToInsert = resolvedSupplierId != null
          ? item.copyWith(supplierId: resolvedSupplierId)
          : item;

      final data = itemToInsert.toJson(_businessId);
      debugPrint('[InventoryProvider] Inserting item: $data');

      await InventoryRepository.instance.addItem(
        item: itemToInsert,
        businessId: _businessId,
        userUid: _userUid,
        userName: _userName,
        userRole: _userRole,
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

  // ── Update Item ────────────────────────────────────────────────────────────
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
      final resolvedSupplierId = await OtherSupplierService.instance
          .resolveOrCreate(
            businessId: _businessId,
            supplierName: updated.supplier,
            existingId: updated.supplierId,
          );

      final itemToUpdate = resolvedSupplierId != null
          ? updated.copyWith(supplierId: resolvedSupplierId)
          : updated;

      await InventoryRepository.instance.updateItem(
        item: itemToUpdate,
        businessId: _businessId,
      );

      final idx = _items.indexWhere((i) => i.id == updated.id);
      if (idx != -1) _items[idx] = itemToUpdate;
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

  // ── Delete Item ────────────────────────────────────────────────────────────
  Future<void> deleteItem(String id) async {
    if (!canManageStock) return;
    _isLoading = true;
    notifyListeners();
    try {
      await InventoryRepository.instance.deleteItem(id, _businessId);
      _items.removeWhere((i) => i.id == id);
    } catch (e) {
      _errorMessage = 'Failed to delete item: $e';
      debugPrint('[InventoryProvider] deleteItem error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Record Transaction ─────────────────────────────────────────────────────
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

      await InventoryRepository.instance.recordTransaction(
        itemId: itemId,
        type: type,
        quantity: quantity,
        stockBefore: item.currentStock,
        stockAfter: newStock,
        unit: item.unit,
        note: note,
        businessId: _businessId,
        userUid: _userUid,
        userName: _userName,
        userRole: _userRole,
      );

      // Optimistic local update.
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
      log('Recorded transaction: $tx');
      _items[idx] = item.copyWith(
        currentStock: newStock,
        lastUpdated: DateTime.now(),
        transactions: [tx, ...item.transactions],
      );

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

  // ── FIX: generateId now returns a proper UUID ──────────────────────────────
  String generateId() => _uuid.v4();

  // ── Local seed (no Supabase) ───────────────────────────────────────────────
  // ignore: unused_element
  void _seedLocal() {
    _items.addAll([
      InventoryItem(
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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
        id: _uuid.v4(),
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

  // ── Cleanup ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    // Cancel periodic refresh timer
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
    debugPrint('[InventoryProvider] ✅ Periodic refresh timer cancelled');

    // Cancel connectivity monitoring subscription
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[InventoryProvider] ✅ Connectivity subscription cancelled');

    // Cleanup realtime subscriptions
    InventoryRepository.instance.unsubscribeAll();

    super.dispose();
  }
}
