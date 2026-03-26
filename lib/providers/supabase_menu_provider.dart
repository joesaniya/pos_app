import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/models/menu_item.dart';

import 'package:pos_app/services/menu_services.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:pos_app/repositories/menu_repository.dart';

enum MenuLoadState { idle, loading, loaded, error }

/// Sync state for menu operations
enum MenuSyncState { idle, syncing, synced, failed }

class SupabaseMenuProvider extends ChangeNotifier {
  final MenuSupabaseService _svc = MenuSupabaseService();
  final MenuRepository _repo = MenuRepository.instance;

  // ── State ────────────────────────────────────────────────────
  MenuLoadState _categoryState = MenuLoadState.idle;
  MenuLoadState _itemState = MenuLoadState.idle;
  String? _error;

  final MenuSyncState _syncState = MenuSyncState.idle;
  int _pendingSyncCount = 0;

  List<SupabaseMenuCategory> _categories = [];
  final Map<String, List<SupabaseMenuItem>> _itemsCache = {};

  // Real-time subscriptions
  StreamSubscription? _categorySub;
  // Per-category item subscriptions — keyed by categoryId so
  // navigating between categories doesn't orphan old channels.
  final Map<String, StreamSubscription> _itemSubs = {};

  // Current user from Firebase
  String _businessId = '';
  String _businessName = '';
  String _userUid = '';
  String _userName = '';
  String? _userEmail;
  String? _userRole;
  String? _userPhone;

  // ── Getters ──────────────────────────────────────────────────
  MenuLoadState get categoryState => _categoryState;
  MenuLoadState get itemState => _itemState;
  String? get error => _error;
  List<SupabaseMenuCategory> get categories => _categories;
  String get businessId => _businessId;

  /// Exposed so the UI can gate add/edit/delete controls by role.
  String? get userRole => _userRole;

  /// Offline-first sync status
  MenuSyncState get syncState => _syncState;
  int get pendingSyncCount => _pendingSyncCount;
  bool get hasOfflineChanges => _pendingSyncCount > 0;

  List<SupabaseMenuItem> itemsForCategory(String categoryId) =>
      _itemsCache[categoryId] ?? [];

  List<SupabaseMenuItem> get allItems =>
      _itemsCache.values.expand((e) => e).toList();

  // ════════════════════════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUserContext();
    if (_businessId.isEmpty) return;
    await loadCategories();
  }

  Future<void> _loadUserContext() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) return;

      final storedData = await StorageService.instance.getUserData();
      final String canonicalUid = storedData['uid'] as String? ?? fbUser.uid;
      _userUid = canonicalUid;
      _userEmail = fbUser.email;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userUid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _businessId = data['businessId'] as String? ?? '';
        _businessName = data['businessName'] as String? ?? '';
        _userName = data['name'] as String? ?? fbUser.displayName ?? '';
        _userRole = data['role'] as String? ?? 'staff';
        _userPhone = data['phone'] as String?;
      }

      // Notify so role badge in header updates immediately after login.
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user context: $e';
    }
  }

  // ════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ════════════════════════════════════════════════════════════

  Future<void> loadCategories() async {
    _categoryState = MenuLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      // Offline-first: Load from local cache, with background sync if online
      _categories = await _repo.fetchCategories(_businessId);

      for (final cat in _categories) {
        await _loadItems(cat.id);
        cat.itemCount = _itemsCache[cat.id]?.length ?? 0;
      }
      _categoryState = MenuLoadState.loaded;

      debugPrint(
        '[MenuProvider] ✅ Loaded ${_categories.length} categories (offline-first)',
      );
    } catch (e) {
      _error = e.toString();
      _categoryState = MenuLoadState.error;
      debugPrint('[MenuProvider] ❌ Load error: $e');
    }
    notifyListeners();
  }

  void subscribeCategories() {
    _categorySub?.cancel();
    _categorySub = _svc
        .watchCategories(_businessId)
        .listen(
          (cats) {
            _categories = cats;
            notifyListeners();
          },
          onError: (e) {
            // Channel error (WebSocket drop, protocol error, etc.)
            // Log silently and schedule a reconnect — do NOT rethrow.
            debugPrint('[SupabaseMenuProvider] category channel error: $e');
            Future.delayed(const Duration(seconds: 3), () {
              if (_businessId.isNotEmpty) subscribeCategories();
            });
          },
          cancelOnError: false, // keep the subscription alive on error
        );
  }

  Future<void> createCategory({
    required String name,
    required String description,
    required String icon,
    required String colorHex,
    int displayOrder = 0,
    File? imageFile,
  }) async {
    try {
      // Offline-first: Create locally and enqueue for sync
      final cat = await _repo.createCategory(
        businessId: _businessId,
        businessName: _businessName,
        name: name,
        description: description,
        icon: icon,
        colorHex: colorHex,
        displayOrder: displayOrder,
        createdByUid: _userUid,
        createdByName: _userName,
        createdByEmail: _userEmail,
        createdByRole: _userRole,
        createdByPhone: _userPhone,
      );

      cat.itemCount = 0;
      _itemsCache[cat.id] = [];
      _categories.add(cat);
      _categoryState = MenuLoadState.loaded;
      _pendingSyncCount++;

      debugPrint(
        '[MenuProvider] ✅ Category created locally (pending sync): ${cat.id}',
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _categoryState = MenuLoadState.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCategory({
    required String id,
    required Map<String, dynamic> updates,
    File? imageFile,
    String? categoryName,
  }) async {
    try {
      // Offline-first: Update locally and enqueue for sync
      await _repo.updateCategory(
        categoryId: id,
        businessId: _businessId,
        updates: updates,
        updatedByUid: _userUid,
        updatedByName: _userName,
        updatedByRole: _userRole,
      );

      // Reload from cache
      final cats = await _repo.fetchCategories(_businessId);
      final updated = cats.firstWhere(
        (c) => c.id == id,
        orElse: () => _categories.firstWhere((c) => c.id == id),
      );

      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx != -1) {
        updated.itemCount = _categories[idx].itemCount;
        _categories[idx] = updated;
      }
      _pendingSyncCount++;

      debugPrint(
        '[MenuProvider] ✅ Category updated locally (pending sync): $id',
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deactivateCategory(String id) async {
    try {
      // Offline-first: Mark as deleted locally and enqueue for sync
      await _repo.deleteCategory(
        categoryId: id,
        businessId: _businessId,
        deletedByUid: _userUid,
        deletedByName: _userName,
      );

      _categories.removeWhere((c) => c.id == id);
      _itemsCache.remove(id);
      _pendingSyncCount++;

      debugPrint(
        '[MenuProvider] ✅ Category deleted locally (pending sync): $id',
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  ITEMS
  // ════════════════════════════════════════════════════════════

  Future<void> _loadItems(String categoryId) async {
    // Offline-first: Load from local cache with background sync
    final items = await _repo.fetchItemsForCategory(_businessId, categoryId);
    _itemsCache[categoryId] = items;
  }

  Future<void> loadItemsForCategory(String categoryId) async {
    _itemState = MenuLoadState.loading;
    notifyListeners();
    try {
      await _loadItems(categoryId);
      final catIdx = _categories.indexWhere((c) => c.id == categoryId);
      if (catIdx != -1) {
        _categories[catIdx].itemCount = _itemsCache[categoryId]?.length ?? 0;
      }
      _itemState = MenuLoadState.loaded;
      debugPrint(
        '[MenuProvider] ✅ Loaded ${_itemsCache[categoryId]?.length ?? 0} items for category (offline-first)',
      );
    } catch (e) {
      _error = e.toString();
      _itemState = MenuLoadState.error;
      debugPrint('[MenuProvider] ❌ Load items error: $e');
    }
    notifyListeners();
  }

  void subscribeItems(String categoryId) {
    // If already subscribed to this category, skip — don't create duplicates.
    if (_itemSubs.containsKey(categoryId)) return;

    _itemSubs[categoryId] = _svc
        .watchItems(categoryId)
        .listen(
          (items) {
            _itemsCache[categoryId] = items;
            final catIdx = _categories.indexWhere((c) => c.id == categoryId);
            if (catIdx != -1) _categories[catIdx].itemCount = items.length;
            notifyListeners();
          },
          onError: (e) {
            // Swallow the RealtimeSubscribeException — remove stale sub
            // and reconnect after a short delay.
            debugPrint(
              '[SupabaseMenuProvider] item channel error ($categoryId): $e',
            );
            _itemSubs.remove(categoryId)?.cancel();
            Future.delayed(const Duration(seconds: 3), () {
              subscribeItems(categoryId);
            });
          },
          cancelOnError: false,
        );
  }

  /// Unsubscribe from a specific category's realtime channel.
  /// Call this in the subcategory screen's dispose() to free Supabase channels.
  void unsubscribeItems(String categoryId) {
    _itemSubs.remove(categoryId)?.cancel();
  }

  Future<SupabaseMenuItem> createItem({
    required String categoryId,
    required String name,
    required double price,
    required bool isVeg,
    String description = '',
    double? discountPrice,
    List<String> ingredients = const [],
    List<String> allergens = const [],
    int preparationTime = 15,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    bool isAvailable = true,
    bool isBestSeller = false,
    bool isFeatured = false,
    bool isNewArrival = false,
    bool isSpicy = false,
    double rating = 4.0,
    File? imageFile,
  }) async {
    // Offline-first: Create locally and enqueue for sync
    final item = await _repo.createMenuItem(
      businessId: _businessId,
      businessName: _businessName,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      createdByUid: _userUid,
      createdByName: _userName,
      createdByEmail: _userEmail,
      createdByRole: _userRole,
      createdByPhone: _userPhone,
      discountPrice: discountPrice,
      isVeg: isVeg,
      isFeatured: isFeatured,
      isBestSeller: isBestSeller,
      isAvailable: isAvailable,
      preparationTime: preparationTime,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      allergens: allergens,
      ingredients: ingredients,
      isSpicy: isSpicy,
    );

    _itemsCache.putIfAbsent(categoryId, () => []).add(item);
    final catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx != -1) _categories[catIdx].itemCount++;
    _pendingSyncCount++;

    debugPrint(
      '[MenuProvider] ✅ Menu item created locally (pending sync): ${item.id}',
    );
    notifyListeners();
    return item;
  }

  Future<void> updateItem({
    required String id,
    required String categoryId,
    required Map<String, dynamic> updates,
    File? imageFile,
    String? itemName,
  }) async {
    // Offline-first: Update locally and enqueue for sync
    await _repo.updateMenuItem(
      itemId: id,
      businessId: _businessId,
      categoryId: categoryId,
      updates: updates,
      updatedByUid: _userUid,
      updatedByName: _userName,
      updatedByRole: _userRole,
    );

    // Reload from cache
    final items = await _repo.fetchItemsForCategory(_businessId, categoryId);
    _itemsCache[categoryId] = items;
    _pendingSyncCount++;

    debugPrint(
      '[MenuProvider] ✅ Menu item updated locally (pending sync): $id',
    );
    notifyListeners();
  }

  Future<void> toggleAvailability({
    required String id,
    required String categoryId,
    required bool isAvailable,
  }) async {
    // Offline-first: Update locally
    await updateItem(
      id: id,
      categoryId: categoryId,
      updates: {'is_available': isAvailable},
    );
  }

  Future<void> deleteItem({
    required String id,
    required String categoryId,
    String? imageUrl,
  }) async {
    // Offline-first: Delete locally and enqueue for sync
    await _repo.deleteMenuItem(
      itemId: id,
      businessId: _businessId,
      categoryId: categoryId,
      deletedByUid: _userUid,
      deletedByName: _userName,
    );

    _itemsCache[categoryId]?.removeWhere((i) => i.id == id);
    final catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx != -1 && _categories[catIdx].itemCount > 0) {
      _categories[catIdx].itemCount--;
    }
    _pendingSyncCount++;

    debugPrint(
      '[MenuProvider] ✅ Menu item deleted locally (pending sync): $id',
    );
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  //  SEARCH
  // ════════════════════════════════════════════════════════════

  Future<List<SupabaseMenuItem>> searchItems(String query) async {
    if (query.trim().isEmpty) return [];
    return _svc.searchItems(businessId: _businessId, query: query);
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    for (final sub in _itemSubs.values) {
      sub.cancel();
    }
    _itemSubs.clear();
    super.dispose();
  }
}
