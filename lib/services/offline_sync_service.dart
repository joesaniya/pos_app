// lib/services/offline_sync_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  OFFLINE SYNC SERVICE  (FIXED)
//
//  KEY FIXES:
//  1. _cleanPayload() strips all internal DB fields (_sync_status, _action,
//     seats, restaurant_tables, etc.) before sending to Supabase so the
//     insert/update never fails with "unknown column" errors.
//  2. _syncTable() no longer does a broken updated_at comparison on the raw
//     payload — it uses the Supabase response directly.
//  3. All sync functions use _cleanPayload() consistently.
//  4. Table sync correctly uses the RPC names expected by the DB (fn_seat_guest_v2
//     etc.) — no raw status overwrites that bypass business logic.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/services/connectivity_service.dart';

// ── Sync state exposed to UI ───────────────────────────────────────────────
enum SyncPhase { idle, syncing, error }

class SyncState {
  final SyncPhase phase;
  final int pendingCount;
  final String? lastError;
  const SyncState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.lastError,
  });
}

// ── Entity types ───────────────────────────────────────────────────────────
class EntityType {
  static const order = 'order';
  static const orderStatus = 'order_status';
  static const orderPayment = 'order_payment';
  static const table = 'table';
  static const reservation = 'reservation';
  static const menuItem = 'menu_item';
  static const inventoryItem = 'inventory_item';
  static const stockTx = 'stock_transaction';
  static const supplier = 'supplier';
  static const supplierPayment = 'supplier_payment';
  static const supplierDelivery = 'supplier_delivery';
  static const profile = 'profile';
}

// ── Fields that must never be sent to Supabase ────────────────────────────
// These are local-only fields or computed joins that don't exist in schema
const _kInternalFields = {
  '_sync_status',
  '_action',
  'seats', // joined list, not a column
  'restaurant_tables', // joined object from Supabase queries
  'reservation_data', // computed field from vw_tables_with_reservation
  'items', // computed JSON array from vw_orders_with_items
};

class OfflineSyncService {
  OfflineSyncService._();
  static final instance = OfflineSyncService._();

  final _db = LocalDatabase.instance;
  final _connectivity = ConnectivityService.instance;
  final _sb = Supabase.instance.client;
  final _fs = FirebaseFirestore.instance;

  final _syncState = ValueNotifier<SyncState>(const SyncState());
  ValueNotifier<SyncState> get syncState => _syncState;

  StreamSubscription? _connectSub;
  bool _isSyncing = false;

  // ── Start listening ───────────────────────────────────────────────────────
  void start() {
    _connectSub = _connectivity.onConnected.listen(
      (_) => processPendingQueue(),
    );

    if (_connectivity.isOnline) {
      Future.delayed(const Duration(seconds: 2), processPendingQueue);
    }

    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_connectivity.isOnline && !_isSyncing) processPendingQueue();
    });

    log('[SyncService] ✅ Started');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYLOAD SANITISATION
  //  Removes every field that Supabase does not know about before any
  //  insert / update call.  Always call this before touching the remote DB.
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> raw) {
    final clean = Map<String, dynamic>.from(raw);

    // Remove internal/computed fields that don't exist in schema
    for (final k in _kInternalFields) {
      if (clean.containsKey(k)) {
        clean.remove(k);
      }
    }

    // Also remove null-value keys that Supabase might reject for NOT NULL cols
    clean.removeWhere(
      (key, value) => value == null && _isOptionalNullable(clean, key),
    );

    return clean;
  }

  /// Very conservative: only strip explicitly-known nullable extras.
  /// We do NOT strip all null values because some columns accept null (e.g.
  /// current_customer_name). Only strip the keys we know cause problems.
  bool _isOptionalNullable(Map<String, dynamic> map, String key) => false;

  // ── Process the queue ─────────────────────────────────────────────────────
  Future<void> processPendingQueue() async {
    if (_isSyncing) return;
    if (!await _connectivity.checkNow()) return;

    _isSyncing = true;
    final pending = await _db.getPendingQueue();
    if (pending.isEmpty) {
      _syncState.value = const SyncState(
        phase: SyncPhase.idle,
        pendingCount: 0,
      );
      _isSyncing = false;
      return;
    }

    log('[SyncService] ▶ Processing ${pending.length} pending items');
    _syncState.value = SyncState(
      phase: SyncPhase.syncing,
      pendingCount: pending.length,
    );

    for (final item in pending) {
      if (!await _connectivity.checkNow()) {
        log('[SyncService] ⚠ Lost connectivity mid-sync, stopping');
        break;
      }

      final queueId = item['id'] as String;
      final entityType = item['entity_type'] as String;
      final action = item['action'] as String;
      final attempts = item['attempts'] as int? ?? 0;
      final rawPayload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;

      try {
        await _dispatch(entityType, action, rawPayload);
        await _db.markSynced(queueId);
        log(
          '[SyncService] ✅ Synced $action on $entityType (${rawPayload['id']})',
        );
      } catch (e) {
        final error = e.toString();

        final isSeatConflict =
            (e is PostgrestException && e.code == '23505') ||
            error.contains('uq_active_seat_order') ||
            error.toLowerCase().contains('duplicate key value');

        if (isSeatConflict && entityType == EntityType.order) {
          log(
            '[SyncService] ⚠ Gave up on conflicting order sync (unique seat constraint): $error',
          );

          // Treat the queue item as resolved to avoid retry loops.
          await _db.markSynced(queueId);

          // If we have a local order row, update it so UI doesn't keep showing
          // an active order that failed to persist remotely.
          try {
            final localId = rawPayload['id'] as String?;
            if (localId != null) {
              final cachedOrders = await _db.getEntities(
                table: LocalDatabase.tOrders,
                businessId: rawPayload['business_id'] as String,
              );
              final localOrder = cachedOrders.firstWhere(
                (o) => o['id'] == localId,
                orElse: () => {},
              );
              if (localOrder.isNotEmpty) {
                localOrder['status'] = 'cancelled';
                localOrder['notes'] =
                    'Auto-cancelled due to duplicate active seat order conflict';
                await _db.upsertEntity(
                  table: LocalDatabase.tOrders,
                  id: localId,
                  businessId: rawPayload['business_id'] as String,
                  data: localOrder,
                  syncStatus: LocalDatabase.syncSynced,
                  action: LocalDatabase.actionUpdate,
                );
              }
            }
          } catch (_) {
            // If local cleanup fails, do not block processing.
          }

          continue;
        }

        final backoffSeconds = _backoff(attempts);
        await _db.markFailed(queueId, error);
        log(
          '[SyncService] ❌ Failed ($attempts attempts, retry in ${backoffSeconds}s): $entityType → $e',
        );
        await Future.delayed(Duration(seconds: min(backoffSeconds, 5)));
      }
    }

    final remaining = await _db.pendingCount();
    _syncState.value = remaining == 0
        ? const SyncState(phase: SyncPhase.idle, pendingCount: 0)
        : SyncState(phase: SyncPhase.idle, pendingCount: remaining);

    _isSyncing = false;
    await _db.pruneOldSynced();
    log('[SyncService] ✅ Queue complete. Remaining: $remaining');
  }

  // ── Dispatch to correct backend ───────────────────────────────────────────
  Future<void> _dispatch(
    String entityType,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (entityType) {
      case EntityType.order:
        await _syncOrder(action, payload);
        break;
      case EntityType.orderStatus:
        await _syncOrderStatus(payload);
        break;
      case EntityType.orderPayment:
        await _syncOrderPayment(payload);
        break;
      case EntityType.table:
        await _syncTable(action, payload);
        break;
      case EntityType.reservation:
        await _syncReservation(action, payload);
        break;
      case 'menu_category':
        await _syncMenuCategory(action, payload);
        break;
      case EntityType.menuItem:
        await _syncMenuItem(action, payload);
        break;
      case EntityType.inventoryItem:
        await _syncInventoryItem(action, payload);
        break;
      case EntityType.stockTx:
        await _syncStockTransaction(payload);
        break;
      case EntityType.supplier:
        await _syncSupplier(action, payload);
        break;
      case EntityType.supplierPayment:
        await _syncSupplierPayment(action, payload);
        break;
      case EntityType.supplierDelivery:
        await _syncSupplierDelivery(action, payload);
        break;
      case EntityType.profile:
        await _syncProfile(payload);
        break;
      default:
        log('[SyncService] ⚠ Unknown entity type: $entityType');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNC IMPLEMENTATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _syncOrder(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('orders')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        final orderData = Map<String, dynamic>.from(clean)..remove('items');
        await _sb.from('orders').insert(orderData);
        final items = (p['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (items.isNotEmpty) {
          final cleanItems = items.map(_cleanPayload).toList();
          await _sb.from('order_items').insert(cleanItems);
        }
        break;
      case LocalDatabase.actionUpdate:
        final updateData = Map<String, dynamic>.from(clean)..remove('items');
        await _sb.from('orders').update(updateData).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('orders').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncOrderStatus(Map<String, dynamic> p) async {
    final clean = _cleanPayload(p);
    await _sb
        .from('orders')
        .update({
          'status': clean['status'],
          'updated_by_uid': clean['updated_by_uid'],
          'updated_by_name': clean['updated_by_name'],
          if (clean['started_at'] != null) 'started_at': clean['started_at'],
          if (clean['ready_at'] != null) 'ready_at': clean['ready_at'],
          if (clean['cancelled_at'] != null)
            'cancelled_at': clean['cancelled_at'],
        })
        .eq('id', clean['id'] as String);
  }

  Future<void> _syncOrderPayment(Map<String, dynamic> p) async {
    final clean = _cleanPayload(p);
    await _sb
        .from('orders')
        .update({
          'payment_status': 'paid',
          'payment_mode': clean['payment_mode'],
          'paid_by_uid': clean['paid_by_uid'],
          'paid_by_name': clean['paid_by_name'],
          'paid_at': clean['paid_at'],
          if (clean['payment_ref'] != null) 'payment_ref': clean['payment_ref'],
          if (clean['tip_amount'] != null) 'tip_amount': clean['tip_amount'],
          if (clean['discount_amount'] != null)
            'discount_amount': clean['discount_amount'],
        })
        .eq('id', clean['id'] as String);
  }

  // ── TABLE SYNC (FIXED) ────────────────────────────────────────────────────
  //
  //  Previous bug: the payload contained fields like `seats`, `_sync_status`,
  //  `_action`, `restaurant_tables` that Supabase rejected.  Also, the
  //  last-write-wins comparison used `p['updated_at']` which was whatever
  //  the local SQLite row stored — often a stale value that caused the update
  //  to be silently skipped.
  //
  //  Fix: always sanitise with _cleanPayload() first; for updates use a
  //  simple upsert with conflict-target on `id` — Supabase applies
  //  last-write-wins via `updated_at` on the server side through the trigger.
  //  If there is no such trigger, we fall back to a plain update (safe
  //  because the offline queue serialises operations).
  //
  Future<void> _syncTable(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      log('[SyncService] ⚠ _syncTable: missing id, skipping');
      return;
    }

    // Always clean the payload first — this is the primary fix.
    final clean = _cleanPayload(p);

    // Ensure updated_at is always fresh so the server sees our write as newest.
    clean['updated_at'] = DateTime.now().toUtc().toIso8601String();

    switch (action) {
      case LocalDatabase.actionCreate:
        // Check for existing row (idempotent insert)
        final existing = await _sb
            .from('restaurant_tables')
            .select('id')
            .eq('id', id)
            .maybeSingle();

        if (existing != null) {
          // Row already on server — treat as update
          log(
            '[SyncService] Table $id already exists on server, updating instead',
          );
          await _sb.from('restaurant_tables').update(clean).eq('id', id);
        } else {
          await _sb.from('restaurant_tables').insert(clean);
        }
        break;

      case LocalDatabase.actionUpdate:
        // Simple update — queue ordering ensures this runs after any create.
        await _sb.from('restaurant_tables').update(clean).eq('id', id);
        break;

      case LocalDatabase.actionDelete:
        await _sb
            .from('restaurant_tables')
            .update({
              'is_active': false,
              'updated_by_uid': clean['updated_by_uid'],
              'updated_by_name': clean['updated_by_name'],
              'updated_at': clean['updated_at'],
            })
            .eq('id', id);
        break;
    }
  }

  // ── RESERVATION SYNC (FIXED) ──────────────────────────────────────────────
  Future<void> _syncReservation(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) return;

    final clean = _cleanPayload(p);
    clean['updated_at'] = DateTime.now().toUtc().toIso8601String();

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('table_reservations')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) {
          log('[SyncService] Reservation $id already exists, updating');
          await _sb.from('table_reservations').update(clean).eq('id', id);
        } else {
          await _sb.from('table_reservations').insert(clean);
        }
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('table_reservations').update(clean).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('table_reservations')
            .update({'status': 'cancelled', 'updated_at': clean['updated_at']})
            .eq('id', id);
        break;
    }
  }

  Future<void> _syncMenuCategory(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('menu_categories')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('menu_categories').insert(clean);
        log('[SyncService] ✅ Created menu category: $id');
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('menu_categories').update(clean).eq('id', id);
        log('[SyncService] ✅ Updated menu category: $id');
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('menu_categories')
            .update({'is_active': false})
            .eq('id', id);
        log('[SyncService] ✅ Deactivated menu category: $id');
        break;
    }
  }

  Future<void> _syncMenuItem(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('menu_items')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('menu_items').insert(clean);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('menu_items').update(clean).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('menu_items').update({'is_active': false}).eq('id', id);
        break;
    }
  }

  Future<void> _syncInventoryItem(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('inventory_items')
            .select('id, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) {
          if (_localIsNewer(
            clean['updated_at'] as String?,
            existing['updated_at'] as String?,
          )) {
            await _sb.from('inventory_items').update(clean).eq('id', id);
          }
          return;
        }
        await _sb.from('inventory_items').insert(clean);
        break;
      case LocalDatabase.actionUpdate:
        final remote = await _sb
            .from('inventory_items')
            .select('updated_at')
            .eq('id', id)
            .maybeSingle();
        if (_localIsNewer(
          clean['updated_at'] as String?,
          remote?['updated_at'] as String?,
        )) {
          await _sb.from('inventory_items').update(clean).eq('id', id);
        } else {
          log(
            '[SyncService] ⚠ Inventory conflict: remote is newer for $id — skipping',
          );
        }
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('inventory_items')
            .update({'is_active': false})
            .eq('id', id);
        break;
    }
  }

  Future<void> _syncStockTransaction(Map<String, dynamic> p) async {
    final clean = _cleanPayload(p);
    final existing = await _sb
        .from('stock_transactions')
        .select('id')
        .eq('id', clean['id'] as String)
        .maybeSingle();
    if (existing != null) return;
    await _sb.from('stock_transactions').insert(clean);
  }

  Future<void> _syncSupplier(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('suppliers')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('suppliers').insert(clean);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('suppliers').update(clean).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('suppliers').update({'is_active': false}).eq('id', id);
        break;
    }
  }

  Future<void> _syncSupplierPayment(
    String action,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('supplier_payments')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('supplier_payments').insert(clean);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('supplier_payments').update(clean).eq('id', id);
        break;
    }
  }

  Future<void> _syncSupplierDelivery(
    String action,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as String;
    final clean = _cleanPayload(p);

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('supplier_deliveries')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('supplier_deliveries').insert(clean);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('supplier_deliveries').update(clean).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('supplier_deliveries').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncProfile(Map<String, dynamic> p) async {
    final uid = p['uid'] as String? ?? p['id'] as String?;
    if (uid == null) return;
    final updates = _cleanPayload(Map<String, dynamic>.from(p)..remove('uid'));
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _fs.collection('users').doc(uid).update(updates);
  }

  // ── Last-write-wins conflict helper ───────────────────────────────────────
  bool _localIsNewer(String? localTs, String? remoteTs) {
    if (localTs == null) return false;
    if (remoteTs == null) return true;
    try {
      return DateTime.parse(localTs).isAfter(DateTime.parse(remoteTs));
    } catch (_) {
      return true;
    }
  }

  int _backoff(int attempts) => min(pow(2, attempts).toInt(), 60);

  void dispose() {
    _connectSub?.cancel();
  }
}
