// lib/providers/supabase_menu_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/models/menu_item.dart';

import 'package:pos_app/services/menu_services.dart';

enum MenuLoadState { idle, loading, loaded, error }

class SupabaseMenuProvider extends ChangeNotifier {
  final MenuSupabaseService _svc = MenuSupabaseService();

  // ── State ────────────────────────────────────────────────────
  MenuLoadState _categoryState = MenuLoadState.idle;
  MenuLoadState _itemState = MenuLoadState.idle;
  String? _error;

  List<SupabaseMenuCategory> _categories = [];
  final Map<String, List<SupabaseMenuItem>> _itemsCache = {};

  // Real-time subscriptions
  StreamSubscription? _categorySub;
  StreamSubscription? _itemSub;

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

      _userUid = fbUser.uid;
      _userEmail = fbUser.email;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fbUser.uid)
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
      _categories = await _svc.getCategories(_businessId);
      for (final cat in _categories) {
        await _loadItems(cat.id);
        cat.itemCount = _itemsCache[cat.id]?.length ?? 0;
      }
      _categoryState = MenuLoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _categoryState = MenuLoadState.error;
    }
    notifyListeners();
  }

  void subscribeCategories() {
    _categorySub?.cancel();
    _categorySub = _svc.watchCategories(_businessId).listen((cats) {
      _categories = cats;
      notifyListeners();
    });
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
      final cat = await _svc.createCategory(
        name: name,
        description: description,
        icon: icon,
        colorHex: colorHex,
        displayOrder: displayOrder,
        businessId: _businessId,
        businessName: _businessName,
        createdByUid: _userUid,
        createdByName: _userName,
        createdByEmail: _userEmail,
        createdByRole: _userRole,
        createdByPhone: _userPhone,
        imageFile: imageFile,
      );

      cat.itemCount = 0;
      _itemsCache[cat.id] = [];
      _categories.add(cat);
      _categoryState = MenuLoadState.loaded;
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
      final updated = await _svc.updateCategory(
        id: id,
        updates: updates,
        updatedByUid: _userUid,
        updatedByName: _userName,
        updatedByRole: _userRole,
        imageFile: imageFile,
        businessId: _businessId,
        categoryName: categoryName ?? '',
      );

      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx != -1) {
        updated.itemCount = _categories[idx].itemCount;
        _categories[idx] = updated;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deactivateCategory(String id) async {
    try {
      await _svc.deactivateCategory(
        id: id,
        updatedByUid: _userUid,
        updatedByName: _userName,
      );
      _categories.removeWhere((c) => c.id == id);
      _itemsCache.remove(id);
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
    final items = await _svc.getItemsByCategory(categoryId);
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
    } catch (e) {
      _error = e.toString();
      _itemState = MenuLoadState.error;
    }
    notifyListeners();
  }

  void subscribeItems(String categoryId) {
    _itemSub?.cancel();
    _itemSub = _svc.watchItems(categoryId).listen((items) {
      _itemsCache[categoryId] = items;
      final catIdx = _categories.indexWhere((c) => c.id == categoryId);
      if (catIdx != -1) _categories[catIdx].itemCount = items.length;
      notifyListeners();
    });
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
    final item = await _svc.createItem(
      categoryId: categoryId,
      name: name,
      price: price,
      isVeg: isVeg,
      businessId: _businessId,
      businessName: _businessName,
      createdByUid: _userUid,
      createdByName: _userName,
      createdByEmail: _userEmail,
      createdByRole: _userRole,
      createdByPhone: _userPhone,
      description: description,
      discountPrice: discountPrice,
      ingredients: ingredients,
      allergens: allergens,
      preparationTime: preparationTime,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      isAvailable: isAvailable,
      isBestSeller: isBestSeller,
      isFeatured: isFeatured,
      isNewArrival: isNewArrival,
      isSpicy: isSpicy,
      rating: rating,
      imageFile: imageFile,
    );

    _itemsCache.putIfAbsent(categoryId, () => []).add(item);
    final catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx != -1) _categories[catIdx].itemCount++;
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
    final updated = await _svc.updateItem(
      id: id,
      updates: updates,
      updatedByUid: _userUid,
      updatedByName: _userName,
      updatedByRole: _userRole,
      imageFile: imageFile,
      businessId: _businessId,
      itemName: itemName,
    );
    final list = _itemsCache[categoryId];
    if (list != null) {
      final idx = list.indexWhere((i) => i.id == id);
      if (idx != -1) list[idx] = updated;
    }
    notifyListeners();
  }

  Future<void> toggleAvailability({
    required String id,
    required String categoryId,
    required bool isAvailable,
  }) async {
    await _svc.toggleAvailability(
      id: id,
      isAvailable: isAvailable,
      updatedByUid: _userUid,
      updatedByName: _userName,
    );
    final list = _itemsCache[categoryId];
    if (list != null) {
      final idx = list.indexWhere((i) => i.id == id);
      if (idx != -1) {
        final old = list[idx];
        list[idx] = SupabaseMenuItem(
          id: old.id,
          categoryId: old.categoryId,
          name: old.name,
          description: old.description,
          price: old.price,
          discountPrice: old.discountPrice,
          imageUrl: old.imageUrl,
          isAvailable: isAvailable,
          isVeg: old.isVeg,
          isFeatured: old.isFeatured,
          isBestSeller: old.isBestSeller,
          isNewArrival: old.isNewArrival,
          isSpicy: old.isSpicy,
          preparationTime: old.preparationTime,
          calories: old.calories,
          protein: old.protein,
          carbs: old.carbs,
          fat: old.fat,
          allergens: old.allergens,
          tags: old.tags,
          ingredients: old.ingredients,
          rating: old.rating,
          sortOrder: old.sortOrder,
          businessId: old.businessId,
          businessName: old.businessName,
          createdByUid: old.createdByUid,
          createdByName: old.createdByName,
          updatedByUid: _userUid,
          updatedByName: _userName,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  Future<void> deleteItem({
    required String id,
    required String categoryId,
    String? imageUrl,
  }) async {
    await _svc.deleteItem(id);
    if (imageUrl != null) await _svc.deleteImage(imageUrl);
    _itemsCache[categoryId]?.removeWhere((i) => i.id == id);
    final catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx != -1 && _categories[catIdx].itemCount > 0) {
      _categories[catIdx].itemCount--;
    }
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
    _itemSub?.cancel();
    super.dispose();
  }
}
