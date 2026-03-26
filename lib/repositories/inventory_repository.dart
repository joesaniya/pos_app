// lib/repositories/inventory_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  INVENTORY REPOSITORY — Offline-first
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';

class InventoryRepository {
  InventoryRepository._();
  static final instance = InventoryRepository._();

  final _local = LocalDatabase.instance;
  final _sb = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ── FIX: UUID validation helper ───────────────────────────────────────────
  // Reuses the same regex already in inventory_modal.dart so the rule is
  // consistent everywhere.  A local copy avoids a cross-file import cycle.
  bool _isValidUuid(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id.trim());
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<InventoryItem>> fetchItems(String businessId) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tInventory,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );
    return rows.map(_rowToItem).whereType<InventoryItem>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> refreshFromRemote(String businessId) async {
    try {
      final rows = await _sb
          .from('inventory_items')
          .select('*, stock_transactions(*)')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');
      final items = (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();
      await _local.replaceAll(
        table: LocalDatabase.tInventory,
        businessId: businessId,
        entities: items,
      );
      log('[InventoryRepo] Remote refresh: ${items.length} items cached');
    } catch (e) {
      debugPrint('[InventoryRepo] Remote refresh error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADD ITEM
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addItem({
    required InventoryItem item,
    required String businessId,
    required String userUid,
    required String userName,
    required String userRole,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // ── FIX: only use item.id if it is already a valid UUID, otherwise
    //   generate a fresh one.  The old check `item.id.isNotEmpty` passed
    //   through sentinel strings like "i9667" which Postgres rejects.
    final id = _isValidUuid(item.id) ? item.id : _uuid.v4();

    final data = {
      ...item.toJson(businessId),
      'id': id,
      'created_at': now,
      'last_updated': now,
    };

    // Local first
    await _local.upsertEntity(
      table: LocalDatabase.tInventory,
      id: id,
      businessId: businessId,
      data: data,
      syncStatus: _connectivity.isOnline
          ? LocalDatabase.syncSynced
          : LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    if (_connectivity.isOnline) {
      try {
        final inserted = await _sb
            .from('inventory_items')
            .insert(data)
            .select()
            .single();
        final insertedId = (inserted as Map)['id'] as String;
        // Log initial stock transaction
        await _sb.from('stock_transactions').insert({
          'item_id': insertedId,
          'business_id': businessId,
          'transaction_type': 'stock_in',
          'quantity': item.currentStock,
          'stock_before': 0,
          'stock_after': item.currentStock,
          'unit': item.unit.dbValue,
          'note': 'Initial stock entry',
          'updated_by_uid': userUid,
          'updated_by_name': userName,
          'updated_by_role': userRole,
          'supplier_id': isValidSupplierId(item.supplierId)
              ? item.supplierId
              : null,
        });
        return true;
      } catch (e) {
        debugPrint('[InventoryRepo] Online addItem failed: $e');
      }
    }

    // Queue for sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.inventoryItem,
      entityId: id,
      action: LocalDatabase.actionCreate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE ITEM
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> updateItem({
    required InventoryItem item,
    required String businessId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = {...item.toJson(businessId), 'last_updated': now};

    await _local.upsertEntity(
      table: LocalDatabase.tInventory,
      id: item.id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('inventory_items')
            .update(data)
            .eq('id', item.id)
            .eq('business_id', businessId);
        return true;
      } catch (e) {
        debugPrint('[InventoryRepo] Online updateItem failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.inventoryItem,
      entityId: item.id,
      action: LocalDatabase.actionUpdate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE ITEM
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteItem(String id, String businessId) async {
    await _local.upsertEntity(
      table: LocalDatabase.tInventory,
      id: id,
      businessId: businessId,
      data: {'id': id, 'is_active': false},
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionDelete,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('inventory_items')
            .update({'is_active': false})
            .eq('id', id)
            .eq('business_id', businessId);
        return;
      } catch (_) {}
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.inventoryItem,
      entityId: id,
      action: LocalDatabase.actionDelete,
      payload: {'id': id, 'business_id': businessId},
      businessId: businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RECORD STOCK TRANSACTION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> recordTransaction({
    required String itemId,
    required TransactionType type,
    required double quantity,
    required double stockBefore,
    required double stockAfter,
    required StockUnit unit,
    required String note,
    required String businessId,
    required String userUid,
    required String userName,
    required String userRole,
    double? costPerUnit,
  }) async {
    final txId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final txMap = {
      'id': txId,
      'item_id': itemId,
      'business_id': businessId,
      'transaction_type': type.dbValue,
      'quantity': quantity,
      'stock_before': stockBefore,
      'stock_after': stockAfter,
      'unit': unit.dbValue,
      'cost_per_unit': costPerUnit,
      'total_cost': costPerUnit != null ? costPerUnit * quantity : null,
      'note': note,
      'updated_by_uid': userUid,
      'updated_by_name': userName,
      'updated_by_role': userRole,
      'created_at': now,
    };

    if (_connectivity.isOnline) {
      try {
        await _sb.from('stock_transactions').insert(txMap);
        return;
      } catch (e) {
        debugPrint('[InventoryRepo] Online recordTransaction failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.stockTx,
      entityId: txId,
      action: LocalDatabase.actionCreate,
      payload: txMap,
      businessId: businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME SUBSCRIPTION
  // ══════════════════════════════════════════════════════════════════════════

  void subscribeRealtime(String businessId, VoidCallback onRefresh) {
    _sb
        .channel('inventory_realtime_$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (_) => onRefresh(),
        )
        .subscribe();
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  InventoryItem? _rowToItem(Map<String, dynamic> row) {
    try {
      return InventoryItem.fromJson(row);
    } catch (e) {
      debugPrint('[InventoryRepo] Parse error: $e');
      return null;
    }
  }
}
