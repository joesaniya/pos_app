import 'dart:convert';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/services/offline_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MenuRepository {
  static final MenuRepository instance = MenuRepository._internal();
  MenuRepository._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // ── Fetch Menu Items ───────────────────────────────────────────────────────
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
        // Fallback to empty list or local items handled above
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

  // ── Insert/Update ──────────────────────────────────────────────────────────
  Future<void> saveMenuItem(
    MenuItem item,
    String businessId, {
    required bool isCreate,
  }) async {
    final data = item.toJson();

    // Save to local cache
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

    // Enqueue for sync
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

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deleteMenuItem(String itemId, String businessId) async {
    // Mark as deleted in local DB
    await _localDb.upsertEntity(
      table: LocalDatabase.tMenuItems,
      id: itemId,
      businessId: businessId,
      data: {'is_active': false},
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionDelete,
    );

    // Enqueue for sync
    await _localDb.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.menuItem,
      entityId: itemId,
      action: LocalDatabase.actionDelete,
      payload: {'id': itemId, 'business_id': businessId, 'is_active': false},
      businessId: businessId,
    );
  }
}
