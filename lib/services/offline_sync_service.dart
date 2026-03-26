// lib/services/offline_sync_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  OFFLINE SYNC SERVICE
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
const _kInternalFields = {
  '_sync_status',
  '_action',
  'seats',
  'restaurant_tables',
  'reservation_data',
  'items',
};

// ── UUID validation ────────────────────────────────────────────────────────
final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool _isValidUuid(String? id) {
  if (id == null || id.trim().isEmpty) return false;
  return _uuidRegex.hasMatch(id.trim());
}

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
    // Purge any legacy queue entries that have non-UUID entity IDs for
    // inventory items — these were created before the generateId() fix and
    // will never succeed against a UUID primary-key column.
    _purgeBadInventoryQueueEntries();

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

  // ── Purge legacy bad-UUID inventory queue entries ─────────────────────────
  // Runs once at startup (and is a no-op after the first clean run).
  // Removes offline_queue rows whose payload carries a non-UUID "id" for
  // entity_type = 'inventory_item'.  Those rows were created by the old
  // generateId() that returned strings like "i9667".
  Future<void> _purgeBadInventoryQueueEntries() async {
    try {
      final rows = await _db.db.query(
        LocalDatabase.tQueue,
        where: 'entity_type = ?',
        whereArgs: [EntityType.inventoryItem],
      );

      final badIds = <String>[];
      for (final row in rows) {
        final entityId = row['entity_id'] as String? ?? '';
        if (!_isValidUuid(entityId)) {
          badIds.add(row['id'] as String);
        }

        // Also check the payload's "id" field in case entity_id was set
        // correctly but the payload itself carries the bad id.
        try {
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final payloadId = payload['id'] as String?;
          if (!_isValidUuid(payloadId)) {
            final queueId = row['id'] as String;
            if (!badIds.contains(queueId)) badIds.add(queueId);
          }
        } catch (_) {}
      }

      if (badIds.isEmpty) return;

      final placeholders = badIds.map((_) => '?').join(',');
      await _db.db.delete(
        LocalDatabase.tQueue,
        where: 'id IN ($placeholders)',
        whereArgs: badIds,
      );

      log(
        '[SyncService] 🧹 Purged ${badIds.length} bad-UUID inventory queue '
        'entries: $badIds',
      );

      // Also remove the matching bad-ID rows from local_inventory so the
      // item doesn't show up as a ghost in the UI.
      for (final row in rows) {
        if (!badIds.contains(row['id'] as String)) continue;
        try {
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final payloadId = payload['id'] as String?;
          if (payloadId != null && !_isValidUuid(payloadId)) {
            await _db.db.delete(
              LocalDatabase.tInventory,
              where: 'id = ?',
              whereArgs: [payloadId],
            );
            log(
              '[SyncService] 🧹 Removed ghost local inventory row: $payloadId',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SyncService] _purgeBadInventoryQueueEntries error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYLOAD SANITISATION
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> raw) {
    final clean = Map<String, dynamic>.from(raw);
    for (final k in _kInternalFields) {
      clean.remove(k);
    }
    clean.removeWhere(
      (key, value) => value == null && _isOptionalNullable(clean, key),
    );
    return clean;
  }

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

      // ── Guard: skip inventory items whose payload id is not a valid UUID.
      // This should not happen after the generateId() fix, but acts as a
      // safety net for any entries that slipped through before the purge ran.
      if (entityType == EntityType.inventoryItem) {
        final payloadId = rawPayload['id'] as String?;
        if (!_isValidUuid(payloadId)) {
          log(
            '[SyncService] 🧹 Skipping bad-UUID inventory queue entry '
            '$queueId (id=$payloadId) — marking synced to clear it',
          );
          await _db.markSynced(queueId);
          continue;
        }
      }

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
          log('[SyncService] ⚠ Gave up on conflicting order sync: $error');
          await _db.markSynced(queueId);

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
          } catch (_) {}

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

  Future<void> _syncTable(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      log('[SyncService] ⚠ _syncTable: missing id, skipping');
      return;
    }

    final clean = _cleanPayload(p);
    clean['updated_at'] = DateTime.now().toUtc().toIso8601String();

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('restaurant_tables')
            .select('id')
            .eq('id', id)
            .maybeSingle();

        if (existing != null) {
          log(
            '[SyncService] Table $id already exists on server, updating instead',
          );
          await _sb.from('restaurant_tables').update(clean).eq('id', id);
        } else {
          await _sb.from('restaurant_tables').insert(clean);
        }
        break;

      case LocalDatabase.actionUpdate:
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
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('menu_categories').update(clean).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('menu_categories')
            .update({'is_active': false})
            .eq('id', id);
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

    if (clean.containsKey('updated_at')) {
      clean['last_updated'] = clean.remove('updated_at');
    }

    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('inventory_items')
            .select('id, last_updated')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) {
          if (_localIsNewer(
            clean['last_updated'] as String?,
            existing['last_updated'] as String?,
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
            .select('last_updated')
            .eq('id', id)
            .maybeSingle();
        if (_localIsNewer(
          clean['last_updated'] as String?,
          remote?['last_updated'] as String?,
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

  // ── Helpers ───────────────────────────────────────────────────────────────
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
