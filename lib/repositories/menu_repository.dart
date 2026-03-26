import 'dart:developer';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/services/offline_sync_service.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MenuRepository {
  static final MenuRepository instance = MenuRepository._internal();
  MenuRepository._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  CATEGORIES — OFFLINE FIRST
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all categories for a business — offline first with sync.
  /// Returns local cache immediately, then triggers background refresh if online.
  Future<List<SupabaseMenuCategory>> fetchCategories(String businessId) async {
    try {
      if (businessId.isEmpty) return [];

      // Step 1: Load from local cache immediately
      final localRows = await _localDb.getEntities(
        table: LocalDatabase.tMenuCategories,
        businessId: businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      final categories = localRows
          .map((row) {
            try {
              return SupabaseMenuCategory.fromJson(row);
            } catch (e) {
              log('[MenuRepo] Error parsing category: $e');
              return null;
            }
          })
          .whereType<SupabaseMenuCategory>()
          .toList();

      log(
        '[MenuRepo] 📦 Loaded ${categories.length} categories from local cache',
      );

      // Step 2: Trigger background remote refresh if online
      if (_connectivity.isOnline && categories.isNotEmpty) {
        _refreshCategoriesInBackground(businessId);
      } else if (categories.isEmpty && _connectivity.isOnline) {
        // First time load — fetch from remote
        return await _fetchCategoriesFromRemote(businessId);
      }

      return categories;
    } catch (e, st) {
      log('[MenuRepo] ❌ fetchCategories error: $e\n$st');
      return [];
    }
  }

  /// Fetch categories from Supabase and cache locally
  Future<List<SupabaseMenuCategory>> _fetchCategoriesFromRemote(
    String businessId,
  ) async {
    try {
      final rows = await _supabase
          .from('menu_categories')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('display_order');

      final categories = (rows as List)
          .map((e) => SupabaseMenuCategory.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final cat in categories) {
        await _localDb.upsertEntity(
          table: LocalDatabase.tMenuCategories,
          id: cat.id,
          businessId: businessId,
          data: cat.toJson(),
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
      }

      log('[MenuRepo] 🔄 Synced ${categories.length} categories from remote');
      return categories;
    } catch (e) {
      log('[MenuRepo] ❌ Remote sync error: $e');
      rethrow;
    }
  }

  /// Background refresh — doesn't block UI
  void _refreshCategoriesInBackground(String businessId) {
    Future.microtask(() async {
      try {
        await _fetchCategoriesFromRemote(businessId);
      } catch (e) {
        log('[MenuRepo] Background sync failed (non-critical): $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE CATEGORY — OFFLINE + SYNC
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new category locally and enqueue for sync
  Future<SupabaseMenuCategory> createCategory({
    required String businessId,
    required String businessName,
    required String name,
    required String description,
    required String icon,
    required String colorHex,
    required int displayOrder,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
    String? createdByPhone,
  }) async {
    try {
      final categoryId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final category = SupabaseMenuCategory(
        id: categoryId,
        name: name,
        description: description,
        icon: icon,
        colorHex: colorHex,
        displayOrder: displayOrder,
        isActive: true,
        imageUrl: null,
        businessId: businessId,
        businessName: businessName,
        createdByUid: createdByUid,
        createdByName: createdByName,
        createdByEmail: createdByEmail,
        createdByRole: createdByRole,
        createdByPhone: createdByPhone,
        createdAt: now,
        updatedAt: now,
      );

      // Save to local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: category.toJson(),
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionCreate,
      );

      // Enqueue for sync
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: 'menu_category',
        entityId: categoryId,
        action: LocalDatabase.actionCreate,
        payload: {...category.toJson(), 'business_id': businessId},
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Category created locally: $categoryId (sync pending)');
      return category;
    } catch (e, st) {
      log('[MenuRepo] ❌ createCategory error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE CATEGORY — OFFLINE + SYNC
  // ══════════════════════════════════════════════════════════════════════════

  /// Update a category locally and enqueue for sync
  Future<void> updateCategory({
    required String categoryId,
    required String businessId,
    required Map<String, dynamic> updates,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
  }) async {
    try {
      // Get current category from local cache
      final rows = await _localDb.getEntities(
        table: LocalDatabase.tMenuCategories,
        businessId: businessId,
      );

      final catRow = rows.firstWhere(
        (r) => r['id'] == categoryId,
        orElse: () => <String, dynamic>{},
      );

      if (catRow.isEmpty) {
        throw Exception('Category not found locally: $categoryId');
      }

      // Merge updates
      final updated = {
        ...catRow,
        ...updates,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'updated_by_role': updatedByRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Remove internal fields before saving
      updated.remove('_sync_status');
      updated.remove('_action');

      // Save to local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: updated,
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionUpdate,
      );

      // Enqueue for sync
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: 'menu_category',
        entityId: categoryId,
        action: LocalDatabase.actionUpdate,
        payload: {...updated, 'id': categoryId, 'business_id': businessId},
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Category updated locally: $categoryId (sync pending)');
    } catch (e, st) {
      log('[MenuRepo] ❌ updateCategory error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE CATEGORY — SOFT DELETE WITH SYNC
  // ══════════════════════════════════════════════════════════════════════════

  /// Soft delete a category (mark as inactive) and enqueue for sync
  Future<void> deleteCategory({
    required String categoryId,
    required String businessId,
    required String deletedByUid,
    required String deletedByName,
  }) async {
    try {
      // Mark as deleted in local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: {'is_active': false},
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionDelete,
      );

      // Enqueue for sync
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: 'menu_category',
        entityId: categoryId,
        action: LocalDatabase.actionDelete,
        payload: {
          'id': categoryId,
          'business_id': businessId,
          'is_active': false,
          'updated_by_uid': deletedByUid,
          'updated_by_name': deletedByName,
        },
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Category deleted locally: $categoryId (sync pending)');
    } catch (e, st) {
      log('[MenuRepo] ❌ deleteCategory error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MENU ITEMS — OFFLINE FIRST
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all menu items for a category — offline first with sync
  Future<List<SupabaseMenuItem>> fetchItemsForCategory(
    String businessId,
    String categoryId,
  ) async {
    try {
      // Load from local cache
      final localRows = await _localDb.getEntities(
        table: LocalDatabase.tMenuItems,
        businessId: businessId,
        whereExtra: 'category = ? AND action != ?',
        whereExtraArgs: [categoryId, LocalDatabase.actionDelete],
      );

      final items = localRows
          .map((row) {
            try {
              return SupabaseMenuItem.fromJson(row);
            } catch (e) {
              log('[MenuRepo] Error parsing menu item: $e');
              return null;
            }
          })
          .whereType<SupabaseMenuItem>()
          .toList();

      // Trigger background refresh if online
      if (_connectivity.isOnline && items.isNotEmpty) {
        _refreshItemsInBackground(businessId, categoryId);
      } else if (items.isEmpty && _connectivity.isOnline) {
        return await _fetchItemsFromRemote(businessId, categoryId);
      }

      return items;
    } catch (e, st) {
      log('[MenuRepo] ❌ fetchItemsForCategory error: $e\n$st');
      return [];
    }
  }

  Future<List<SupabaseMenuItem>> _fetchItemsFromRemote(
    String businessId,
    String categoryId,
  ) async {
    try {
      final rows = await _supabase
          .from('menu_items')
          .select()
          .eq('business_id', businessId)
          .eq('category_id', categoryId)
          .order('sort_order');

      final items = (rows as List)
          .map((e) => SupabaseMenuItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final item in items) {
        await _localDb.upsertEntity(
          table: LocalDatabase.tMenuItems,
          id: item.id,
          businessId: businessId,
          data: item.toUpdateMap(),
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
          extraColumns: {'category': categoryId},
        );
      }

      return items;
    } catch (e) {
      log('[MenuRepo] ❌ Remote sync error: $e');
      rethrow;
    }
  }

  void _refreshItemsInBackground(String businessId, String categoryId) {
    Future.microtask(() async {
      try {
        await _fetchItemsFromRemote(businessId, categoryId);
      } catch (e) {
        log('[MenuRepo] Background sync failed: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE MENU ITEM — OFFLINE + SYNC
  // ══════════════════════════════════════════════════════════════════════════

  Future<SupabaseMenuItem> createMenuItem({
    required String businessId,
    required String businessName,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
    String? createdByPhone,
    double? discountPrice,
    String? imageUrl,
    bool isVeg = true,
    bool isFeatured = false,
    bool isBestSeller = false,
    bool isNewArrival = false,
    bool isAvailable = true,
    bool isSpicy = false,
    int preparationTime = 15,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? servingSize,
    List<String> allergens = const [],
    List<String> tags = const [],
    List<String> ingredients = const [],
    int sortOrder = 0,
    double rating = 4.0,
  }) async {
    try {
      final itemId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final item = SupabaseMenuItem(
        id: itemId,
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        discountPrice: discountPrice,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
        isVeg: isVeg,
        isSpicy: isSpicy,
        isFeatured: isFeatured,
        isBestSeller: isBestSeller,
        isNewArrival: isNewArrival,
        preparationTime: preparationTime,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        servingSize: servingSize,
        allergens: allergens,
        tags: tags,
        ingredients: ingredients,
        rating: rating,
        sortOrder: sortOrder,
        businessId: businessId,
        businessName: businessName,
        createdByUid: createdByUid,
        createdByName: createdByName,
        createdByEmail: createdByEmail,
        createdByRole: createdByRole,
        createdByPhone: createdByPhone,
        createdAt: now,
        updatedAt: now,
      );

      // Save to local cache — use toJson() to preserve ALL fields including category_id
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuItems,
        id: itemId,
        businessId: businessId,
        data: item.toJson(),
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionCreate,
        extraColumns: {'category': categoryId},
      );

      // Enqueue for sync with complete data
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: EntityType.menuItem,
        entityId: itemId,
        action: LocalDatabase.actionCreate,
        payload: {
          ...item.toJson(),
          'id': itemId,
          'category_id':
              categoryId, // ✅ EXPLICIT — ensure present for constraint
          'business_id': businessId,
        },
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Menu item created locally: $itemId (sync pending)');
      return item;
    } catch (e, st) {
      log('[MenuRepo] ❌ createMenuItem error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE MENU ITEM — OFFLINE + SYNC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> updateMenuItem({
    required String itemId,
    required String businessId,
    required String categoryId,
    required Map<String, dynamic> updates,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
  }) async {
    try {
      // Get current item from local cache
      final rows = await _localDb.getEntities(
        table: LocalDatabase.tMenuItems,
        businessId: businessId,
      );

      final itemRow = rows.firstWhere(
        (r) => r['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );

      if (itemRow.isEmpty) {
        throw Exception('Menu item not found locally: $itemId');
      }

      // Merge updates
      final updated = {
        ...itemRow,
        ...updates,
        'category_id':
            categoryId, // ✅ EXPLICIT — preserve category_id after merge
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'updated_by_role': updatedByRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Remove internal fields
      updated.remove('_sync_status');
      updated.remove('_action');

      // Save to local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuItems,
        id: itemId,
        businessId: businessId,
        data: updated,
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionUpdate,
        extraColumns: {'category': categoryId},
      );

      // Enqueue for sync with category_id explicitly included
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: EntityType.menuItem,
        entityId: itemId,
        action: LocalDatabase.actionUpdate,
        payload: {
          ...updated,
          'id': itemId,
          'category_id':
              categoryId, // ✅ EXPLICIT — ensure never lost in sync payload
          'business_id': businessId,
        },
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Menu item updated locally: $itemId (sync pending)');
    } catch (e, st) {
      log('[MenuRepo] ❌ updateMenuItem error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE MENU ITEM — SOFT DELETE WITH SYNC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteMenuItem({
    required String itemId,
    required String businessId,
    required String categoryId,
    required String deletedByUid,
    required String deletedByName,
  }) async {
    try {
      // Mark as deleted in local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuItems,
        id: itemId,
        businessId: businessId,
        data: {'is_available': false},
        syncStatus: LocalDatabase.syncPending,
        action: LocalDatabase.actionDelete,
        extraColumns: {'category': categoryId},
      );

      // Enqueue for sync
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: EntityType.menuItem,
        entityId: itemId,
        action: LocalDatabase.actionDelete,
        payload: {
          'id': itemId,
          'business_id': businessId,
          'is_available': false,
          'updated_by_uid': deletedByUid,
          'updated_by_name': deletedByName,
        },
        businessId: businessId,
      );

      log('[MenuRepo] ✅ Menu item deleted locally: $itemId (sync pending)');
    } catch (e, st) {
      log('[MenuRepo] ❌ deleteMenuItem error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEGACY SUPPORT — Compatible with existing code
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch Menu Items (legacy support)
  Future<List<MenuItem>> fetchMenuItems(String businessId) async {
    List<MenuItem> items = [];
    final localData = await _localDb.getEntities(
      table: LocalDatabase.tMenuItems,
      businessId: businessId,
    );
    bool hasLocalRecords = false;

    for (final row in localData) {
      hasLocalRecords = true;
      try {
        items.add(MenuItem.fromJson(row));
      } catch (e) {
        // parsing error
      }
    }

    if (!hasLocalRecords) {
      // Fetch from Supabase if local is empty
      try {
        final rows = await _supabase
            .from('menu_items')
            .select('*')
            .eq('business_id', businessId)
            .eq('is_active', true)
            .order('name');

        await _localDb.replaceAll(
          table: LocalDatabase.tMenuItems,
          businessId: businessId,
          entities: (rows as List)
              .map((r) => r as Map<String, dynamic>)
              .toList(),
        );

        for (final row in (rows as List)) {
          final item = MenuItem.fromJson(row as Map<String, dynamic>);
          items.add(item);
        }
      } catch (e) {
        // Fallback to empty list
      }
    } else {
      // Trigger background refresh
      _refreshBackground(businessId);
    }

    return items;
  }

  Future<void> _refreshBackground(String businessId) async {
    try {
      final rows = await _supabase
          .from('menu_items')
          .select('*')
          .eq('business_id', businessId)
          .eq('is_active', true);

      await _localDb.replaceAll(
        table: LocalDatabase.tMenuItems,
        businessId: businessId,
        entities: (rows as List).map((r) => r as Map<String, dynamic>).toList(),
      );
    } catch (_) {
      // Background refresh failed, silent error
    }
  }

  /// Save Menu Item (legacy support)
  Future<void> saveMenuItem(
    MenuItem item,
    String businessId, {
    required bool isCreate,
  }) async {
    final data = item.toJson();

    await _localDb.upsertEntity(
      table: LocalDatabase.tMenuItems,
      id: item.id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: isCreate
          ? LocalDatabase.actionCreate
          : LocalDatabase.actionUpdate,
    );

    await _localDb.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.menuItem,
      entityId: item.id,
      action: isCreate
          ? LocalDatabase.actionCreate
          : LocalDatabase.actionUpdate,
      payload: {...data, 'business_id': businessId},
      businessId: businessId,
    );
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────
  void subscribeRealtime(String businessId, void Function() onUpdate) {
    _supabase
        .channel('menu_rt_$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}

/// Extended EntityType to include menu categories
extension MenuEntityType on EntityType {
  static const menuCategory = 'menu_category';
}
