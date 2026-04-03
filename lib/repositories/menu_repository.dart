import 'dart:developer';
import 'package:flutter/foundation.dart';
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

      // Skip local database on web platform
      if (kIsWeb) {
        return await _fetchCategoriesFromRemote(businessId);
      }

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

      // Cache locally (skip on web — no local database)
      if (!kIsWeb) {
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
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _fetchCategoriesFromRemote(businessId);
      } catch (e) {
        log('[MenuRepo] Background sync failed (non-critical): $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE CATEGORY — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new category — tries API first if online, falls back to queue
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

      final categoryJson = category.toJson();

      // 1. Save to local cache (always, for offline safety)
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: categoryJson,
        syncStatus: _connectivity.isOnline
            ? LocalDatabase
                  .syncSynced // Will update if API succeeds
            : LocalDatabase.syncPending, // Will be queued for sync
        action: LocalDatabase.actionCreate,
      );

      // 2. Try API immediately if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.from('menu_categories').insert({
            ...categoryJson,
            'business_id': businessId,
          });

          log('[MenuRepo] ✅ Category created online: $categoryId');
          // Already marked as synced locally, so we're done
          return category;
        } catch (e) {
          log(
            '[MenuRepo] ⚠️ Online creation failed: $e, falling back to queue',
          );
          // Mark as pending for sync
          await _localDb.upsertEntity(
            table: LocalDatabase.tMenuCategories,
            id: categoryId,
            businessId: businessId,
            data: categoryJson,
            syncStatus: LocalDatabase.syncPending,
            action: LocalDatabase.actionCreate,
          );
        }
      }

      // 3. Always enqueue for sync as fallback
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: 'menu_category',
        entityId: categoryId,
        action: LocalDatabase.actionCreate,
        payload: {...categoryJson, 'business_id': businessId},
        businessId: businessId,
      );

      log(
        '[MenuRepo] ✅ Category created locally: $categoryId (${_connectivity.isOnline ? 'synced' : 'pending'})',
      );
      return category;
    } catch (e, st) {
      log('[MenuRepo] ❌ createCategory error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE CATEGORY — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
  // ══════════════════════════════════════════════════════════════════════════

  /// Update a category — tries API first if online, falls back to queue
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

      // Merge updates with audit info
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

      // ✅ STEP 1: Save to local cache IMMEDIATELY (optimistic)
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: updated,
        syncStatus: LocalDatabase.syncSynced, // Optimistic: mark as synced
        action: LocalDatabase.actionUpdate,
      );

      // ✅ STEP 2: Queue for sync (always, as fallback)
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: 'menu_category',
        entityId: categoryId,
        action: LocalDatabase.actionUpdate,
        payload: {...updated, 'id': categoryId, 'business_id': businessId},
        businessId: businessId,
      );

      log(
        '[MenuRepo] ✅ Category updated locally: $categoryId (sync in background)',
      );

      // ✅ STEP 3: Return IMMEDIATELY
      // (Provider will handle notifying listeners)

      // ✅ STEP 4: Sync to backend in background
      if (_connectivity.isOnline) {
        _syncCategoryUpdateInBackground(categoryId, businessId, updates);
      }
    } catch (e, st) {
      log('[MenuRepo] ❌ updateCategory error: $e\n$st');
      rethrow;
    }
  }

  /// Sync category update to backend in background (non-blocking)
  void _syncCategoryUpdateInBackground(
    String categoryId,
    String businessId,
    Map<String, dynamic> updates,
  ) {
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _supabase
            .from('menu_categories')
            .update(updates)
            .eq('id', categoryId)
            .eq('business_id', businessId);
        log('[MenuRepo] ✅ Category update synced to backend: $categoryId');
      } catch (e) {
        log('[MenuRepo] ⚠️ Background sync failed, will retry from queue: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE CATEGORY — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
  // ══════════════════════════════════════════════════════════════════════════

  /// Soft delete a category — tries API first if online, falls back to queue
  Future<void> deleteCategory({
    required String categoryId,
    required String businessId,
    required String deletedByUid,
    required String deletedByName,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // ✅ STEP 1: Mark as deleted in local cache IMMEDIATELY (optimistic)
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuCategories,
        id: categoryId,
        businessId: businessId,
        data: {
          'is_active': false,
          'updated_by_uid': deletedByUid,
          'updated_by_name': deletedByName,
          'updated_at': now,
        },
        syncStatus: LocalDatabase.syncSynced, // Optimistic
        action: LocalDatabase.actionDelete,
      );

      // ✅ STEP 2: Queue for sync (always, as fallback)
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

      log(
        '[MenuRepo] ✅ Category deleted locally: $categoryId (sync in background)',
      );

      // ✅ STEP 3: Return IMMEDIATELY
      // (Provider will handle notifying listeners)

      // ✅ STEP 4: Sync to backend in background
      if (_connectivity.isOnline) {
        _syncCategoryDeleteInBackground(categoryId, businessId);
      }
    } catch (e, st) {
      log('[MenuRepo] ❌ deleteCategory error: $e\n$st');
      rethrow;
    }
  }

  /// Sync category delete to backend in background (non-blocking)
  void _syncCategoryDeleteInBackground(String categoryId, String businessId) {
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _supabase
            .from('menu_categories')
            .update({'is_active': false})
            .eq('id', categoryId)
            .eq('business_id', businessId);
        log('[MenuRepo] ✅ Category delete synced to backend: $categoryId');
      } catch (e) {
        log('[MenuRepo] ⚠️ Background sync failed, will retry from queue: $e');
      }
    });
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
      // Skip local database on web platform
      if (kIsWeb) {
        return await _fetchItemsFromRemote(businessId, categoryId);
      }

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
          .eq('is_active', true)
          .order('sort_order');

      final items = (rows as List)
          .map((e) => SupabaseMenuItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache locally with complete JSON representation (skip on web)
      if (!kIsWeb) {
        for (final item in items) {
          await _localDb.upsertEntity(
            table: LocalDatabase.tMenuItems,
            id: item.id,
            businessId: businessId,
            data: item.toJson(),
            syncStatus: LocalDatabase.syncSynced,
            action: LocalDatabase.actionUpdate,
            extraColumns: {'category': categoryId},
          );
        }
      }

      return items;
    } catch (e) {
      log('[MenuRepo] ❌ Remote sync error: $e');
      rethrow;
    }
  }

  void _refreshItemsInBackground(String businessId, String categoryId) {
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _fetchItemsFromRemote(businessId, categoryId);
      } catch (e) {
        log('[MenuRepo] Background sync failed: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE MENU ITEM — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
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
        isActive: true,
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

      final itemJson = {
        ...item.toJson(),
        'id': itemId,
        'category_id': categoryId,
        'business_id': businessId,
      };

      // On web: Create directly in Supabase (no local caching)
      if (kIsWeb) {
        try {
          await _supabase.from('menu_items').insert(itemJson);
          log('[MenuRepo] ✅ Menu item created on web: $itemId');
          return item;
        } catch (e) {
          log('[MenuRepo] ❌ Web creation failed: $e');
          rethrow;
        }
      }

      // 1. Save to local cache
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuItems,
        id: itemId,
        businessId: businessId,
        data: item.toJson(),
        syncStatus: _connectivity.isOnline
            ? LocalDatabase
                  .syncSynced // Will update if API succeeds
            : LocalDatabase.syncPending, // Will be queued for sync
        action: LocalDatabase.actionCreate,
        extraColumns: {'category': categoryId},
      );

      // 2. Try API immediately if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.from('menu_items').insert(itemJson);

          log('[MenuRepo] ✅ Menu item created online: $itemId');
          // Already marked as synced locally — don't enqueue on success
          return item;
        } catch (e) {
          log(
            '[MenuRepo] ⚠️ Online creation failed: $e, falling back to queue',
          );
          // Mark as pending for sync
          await _localDb.upsertEntity(
            table: LocalDatabase.tMenuItems,
            id: itemId,
            businessId: businessId,
            data: item.toJson(),
            syncStatus: LocalDatabase.syncPending,
            action: LocalDatabase.actionCreate,
            extraColumns: {'category': categoryId},
          );
          // Enqueue after API failure
          await _localDb.enqueue(
            id: _uuid.v4(),
            entityType: 'menu_item',
            entityId: itemId,
            action: LocalDatabase.actionCreate,
            payload: itemJson,
            businessId: businessId,
          );
          return item; // Return after queueing
        }
      } else {
        // 3. Offline path — enqueue for sync
        await _localDb.enqueue(
          id: _uuid.v4(),
          entityType: 'menu_item',
          entityId: itemId,
          action: LocalDatabase.actionCreate,
          payload: itemJson,
          businessId: businessId,
        );
      }

      log(
        '[MenuRepo] ✅ Menu item created locally: $itemId (${_connectivity.isOnline ? 'synced' : 'pending'})',
      );
      return item;
    } catch (e, st) {
      log('[MenuRepo] ❌ createMenuItem error: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE MENU ITEM — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
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
      // On web: Update directly in Supabase (no local caching)
      if (kIsWeb) {
        try {
          final updateData = {
            ...updates,
            'updated_by_uid': updatedByUid,
            'updated_by_name': updatedByName,
            'updated_by_role': updatedByRole,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          await _supabase
              .from('menu_items')
              .update(updateData)
              .eq('id', itemId);
          log('[MenuRepo] ✅ Menu item updated on web: $itemId');
          return;
        } catch (e) {
          log('[MenuRepo] ❌ Web update failed: $e');
          rethrow;
        }
      }

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

      // Merge updates with audit info
      final updated = {
        ...itemRow,
        ...updates,
        'category_id': categoryId,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'updated_by_role': updatedByRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Remove internal fields
      updated.remove('_sync_status');
      updated.remove('_action');

      // ✅ STEP 1: Save to local cache IMMEDIATELY (optimistic)
      await _localDb.upsertEntity(
        table: LocalDatabase.tMenuItems,
        id: itemId,
        businessId: businessId,
        data: updated,
        syncStatus: LocalDatabase.syncSynced, // Optimistic
        action: LocalDatabase.actionUpdate,
        extraColumns: {'category': categoryId},
      );

      // ✅ STEP 2: Queue for sync (always, as fallback)
      await _localDb.enqueue(
        id: _uuid.v4(),
        entityType: EntityType.menuItem,
        entityId: itemId,
        action: LocalDatabase.actionUpdate,
        payload: {
          ...updated,
          'id': itemId,
          'category_id': categoryId,
          'business_id': businessId,
        },
        businessId: businessId,
      );

      log(
        '[MenuRepo] ✅ Menu item updated locally: $itemId (sync in background)',
      );

      // ✅ STEP 3: Return IMMEDIATELY
      // (Provider will handle notifying listeners)

      // ✅ STEP 4: Sync to backend in background
      if (_connectivity.isOnline) {
        _syncMenuItemUpdateInBackground(itemId, businessId, updates);
      }
    } catch (e, st) {
      log('[MenuRepo] ❌ updateMenuItem error: $e\n$st');
      rethrow;
    }
  }

  /// Sync menu item update to backend in background (non-blocking)
  void _syncMenuItemUpdateInBackground(
    String itemId,
    String businessId,
    Map<String, dynamic> updates,
  ) {
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _supabase
            .from('menu_items')
            .update(updates)
            .eq('id', itemId)
            .eq('business_id', businessId);
        log('[MenuRepo] ✅ Menu item update synced to backend: $itemId');
      } catch (e) {
        log('[MenuRepo] ⚠️ Background sync failed, will retry from queue: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE MENU ITEM — HYBRID (ONLINE-FIRST + OFFLINE FALLBACK)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteMenuItem({
    required String itemId,
    required String businessId,
    required String categoryId,
    required String deletedByUid,
    required String deletedByName,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Skip local cache on web
      if (!kIsWeb) {
        // ✅ STEP 1: Mark as deleted in local cache IMMEDIATELY (optimistic)
        await _localDb.upsertEntity(
          table: LocalDatabase.tMenuItems,
          id: itemId,
          businessId: businessId,
          data: {
            'is_active': false,
            'updated_by_uid': deletedByUid,
            'updated_by_name': deletedByName,
            'updated_at': now,
          },
          syncStatus: LocalDatabase.syncSynced, // Optimistic
          action: LocalDatabase.actionDelete,
          extraColumns: {'category': categoryId},
        );

        // ✅ STEP 2: Queue for sync (always, as fallback)
        await _localDb.enqueue(
          id: _uuid.v4(),
          entityType: EntityType.menuItem,
          entityId: itemId,
          action: LocalDatabase.actionDelete,
          payload: {
            'id': itemId,
            'business_id': businessId,
            'is_active': false,
            'updated_by_uid': deletedByUid,
            'updated_by_name': deletedByName,
          },
          businessId: businessId,
        );
      }

      log(
        '[MenuRepo] ✅ Menu item deleted${kIsWeb ? ' (web, remote only)' : ' locally'}: $itemId',
      );

      // ✅ STEP 3: Return IMMEDIATELY
      // (Provider will handle notifying listeners)

      // ✅ STEP 4: Sync to backend in background (or directly on web)
      if (_connectivity.isOnline || kIsWeb) {
        if (kIsWeb) {
          // On web, delete directly
          await _supabase
              .from('menu_items')
              .update({'is_active': false})
              .eq('id', itemId);
        } else {
          _syncMenuItemDeleteInBackground(itemId, businessId);
        }
      }
    } catch (e, st) {
      log('[MenuRepo] ❌ deleteMenuItem error: $e\n$st');
      rethrow;
    }
  }

  /// Sync menu item delete to backend in background (non-blocking)
  void _syncMenuItemDeleteInBackground(String itemId, String businessId) {
    if (kIsWeb) return; // Skip background sync on web
    Future.microtask(() async {
      try {
        await _supabase
            .from('menu_items')
            .update({'is_active': false})
            .eq('id', itemId)
            .eq('business_id', businessId);
        log('[MenuRepo] ✅ Menu item delete synced to backend: $itemId');
      } catch (e) {
        log('[MenuRepo] ⚠️ Background sync failed, will retry from queue: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEGACY SUPPORT — Compatible with existing code
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch Menu Items (legacy support)
  Future<List<MenuItem>> fetchMenuItems(String businessId) async {
    List<MenuItem> items = [];

    // On native platforms, try local cache first
    if (!kIsWeb) {
      try {
        final localData = await _localDb.getEntities(
          table: LocalDatabase.tMenuItems,
          businessId: businessId,
        );

        for (final row in localData) {
          try {
            items.add(MenuItem.fromJson(row));
          } catch (e) {
            // parsing error
          }
        }

        if (items.isNotEmpty) {
          // Trigger background refresh in background
          _refreshMenuItemsInBackground(businessId);
          return items;
        }
      } catch (e) {
        debugPrint('[MenuRepo] Local fetch failed: $e');
      }
    }

    // Fetch from Supabase (either on web or if local was empty)
    try {
      final rows = await _supabase
          .from('menu_items')
          .select('*')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      for (final row in (rows as List)) {
        try {
          final item = MenuItem.fromJson(row as Map<String, dynamic>);
          items.add(item);
        } catch (e) {
          debugPrint('[MenuRepo] Parse error: $e');
        }
      }

      // Cache to local on native platforms
      if (!kIsWeb) {
        await _localDb.replaceAll(
          table: LocalDatabase.tMenuItems,
          businessId: businessId,
          entities: (rows as List)
              .map((r) => r as Map<String, dynamic>)
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('[MenuRepo] Remote fetch failed: $e');
    }

    return items;
  }

  Future<void> _refreshMenuItemsInBackground(String businessId) async {
    if (kIsWeb) return; // Skip background sync on web
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

    // Save to local database only on native platforms
    if (!kIsWeb) {
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
    } else {
      // On web, send to remote directly
      try {
        if (isCreate) {
          await _supabase.from('menu_items').insert({
            ...data,
            'business_id': businessId,
          });
        } else {
          await _supabase.from('menu_items').update(data).eq('id', item.id);
        }
      } catch (e) {
        log('[MenuRepo] Web saveMenuItem error: $e');
        rethrow;
      }
    }
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────
  void subscribeRealtime(String businessId, void Function() onUpdate) {
    // Skip realtime subscriptions on web
    if (kIsWeb) {
      log('[MenuRepo] Skipping realtime subscription on web');
      return;
    }

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
