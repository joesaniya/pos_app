// lib/services/offline_sync_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  OFFLINE SYNC SERVICE
//  Processes the offline queue when connectivity is restored.
//  Uses exponential backoff, last-write-wins conflict resolution.
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
    // Sync on connectivity restore
    _connectSub = _connectivity.onConnected.listen(
      (_) => processPendingQueue(),
    );

    // Also sync now if already online
    if (_connectivity.isOnline) {
      Future.delayed(const Duration(seconds: 2), processPendingQueue);
    }

    // Periodic sync every 5 minutes as a safety net
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_connectivity.isOnline && !_isSyncing) processPendingQueue();
    });

    log('[SyncService] ✅ Started');
  }

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
      final payload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;

      try {
        await _dispatch(entityType, action, payload);
        await _db.markSynced(queueId);
        log('[SyncService] ✅ Synced $action on $entityType (${payload['id']})');
      } catch (e) {
        final backoffSeconds = _backoff(attempts);
        final error = e.toString();
        await _db.markFailed(queueId, error);
        log(
          '[SyncService] ❌ Failed ($attempts attempts, retry in ${backoffSeconds}s): $entityType → $e',
        );
        // Brief pause before retrying next item
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
      // ── ORDERS ─────────────────────────────────────────────────────────────
      case EntityType.order:
        await _syncOrder(action, payload);
        break;
      case EntityType.orderStatus:
        await _syncOrderStatus(payload);
        break;
      case EntityType.orderPayment:
        await _syncOrderPayment(payload);
        break;

      // ── TABLES ────────────────────────────────────────────────────────────
      case EntityType.table:
        await _syncTable(action, payload);
        break;
      case EntityType.reservation:
        await _syncReservation(action, payload);
        break;

      // ── MENU ──────────────────────────────────────────────────────────────
      case EntityType.menuItem:
        await _syncMenuItem(action, payload);
        break;

      // ── INVENTORY ─────────────────────────────────────────────────────────
      case EntityType.inventoryItem:
        await _syncInventoryItem(action, payload);
        break;
      case EntityType.stockTx:
        await _syncStockTransaction(payload);
        break;

      // ── SUPPLIERS ─────────────────────────────────────────────────────────
      case EntityType.supplier:
        await _syncSupplier(action, payload);
        break;
      case EntityType.supplierPayment:
        await _syncSupplierPayment(action, payload);
        break;
      case EntityType.supplierDelivery:
        await _syncSupplierDelivery(action, payload);
        break;

      // ── PROFILE ───────────────────────────────────────────────────────────
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
    switch (action) {
      case LocalDatabase.actionCreate:
        // Check if already exists (avoid duplicate from optimistic insert)
        final existing = await _sb
            .from('orders')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return; // already synced
        // Insert order
        final orderData = Map<String, dynamic>.from(p)..remove('items');
        await _sb.from('orders').insert(orderData);
        // Insert order items
        final items = (p['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (items.isNotEmpty) {
          await _sb.from('order_items').insert(items);
        }
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('orders').update(p..remove('items')).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('orders').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncOrderStatus(Map<String, dynamic> p) async {
    await _sb
        .from('orders')
        .update({
          'status': p['status'],
          'updated_by_uid': p['updated_by_uid'],
          'updated_by_name': p['updated_by_name'],
          if (p['started_at'] != null) 'started_at': p['started_at'],
          if (p['ready_at'] != null) 'ready_at': p['ready_at'],
          if (p['cancelled_at'] != null) 'cancelled_at': p['cancelled_at'],
        })
        .eq('id', p['id'] as String);
  }

  Future<void> _syncOrderPayment(Map<String, dynamic> p) async {
    await _sb
        .from('orders')
        .update({
          'payment_status': 'paid',
          'payment_mode': p['payment_mode'],
          'paid_by_uid': p['paid_by_uid'],
          'paid_by_name': p['paid_by_name'],
          'paid_at': p['paid_at'],
          if (p['payment_ref'] != null) 'payment_ref': p['payment_ref'],
          if (p['tip_amount'] != null) 'tip_amount': p['tip_amount'],
          if (p['discount_amount'] != null)
            'discount_amount': p['discount_amount'],
        })
        .eq('id', p['id'] as String);
  }

  Future<void> _syncTable(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('restaurant_tables')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('restaurant_tables').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        // Last-write-wins: compare updated_at
        final remote = await _sb
            .from('restaurant_tables')
            .select('updated_at')
            .eq('id', id)
            .maybeSingle();
        if (_localIsNewer(
          p['updated_at'] as String?,
          remote?['updated_at'] as String?,
        )) {
          await _sb.from('restaurant_tables').update(p).eq('id', id);
        }
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('restaurant_tables')
            .update({'is_active': false})
            .eq('id', id);
        break;
    }
  }

  Future<void> _syncReservation(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('table_reservations')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('table_reservations').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('table_reservations').update(p).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb
            .from('table_reservations')
            .update({'status': 'cancelled'})
            .eq('id', id);
        break;
    }
  }

  Future<void> _syncMenuItem(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('menu_items')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('menu_items').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('menu_items').update(p).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('menu_items').update({'is_active': false}).eq('id', id);
        break;
    }
  }

  Future<void> _syncInventoryItem(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('inventory_items')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) {
          // Conflict: update if local is newer
          final remote = await _sb
              .from('inventory_items')
              .select('updated_at')
              .eq('id', id)
              .maybeSingle();
          if (_localIsNewer(
            p['updated_at'] as String?,
            remote?['updated_at'] as String?,
          )) {
            await _sb.from('inventory_items').update(p).eq('id', id);
          }
          return;
        }
        await _sb.from('inventory_items').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        final remote = await _sb
            .from('inventory_items')
            .select('updated_at')
            .eq('id', id)
            .maybeSingle();
        if (_localIsNewer(
          p['updated_at'] as String?,
          remote?['updated_at'] as String?,
        )) {
          await _sb.from('inventory_items').update(p).eq('id', id);
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
    final existing = await _sb
        .from('stock_transactions')
        .select('id')
        .eq('id', p['id'] as String)
        .maybeSingle();
    if (existing != null) return;
    await _sb.from('stock_transactions').insert(p);
  }

  Future<void> _syncSupplier(String action, Map<String, dynamic> p) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('suppliers')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('suppliers').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('suppliers').update(p).eq('id', id);
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
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('supplier_payments')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('supplier_payments').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('supplier_payments').update(p).eq('id', id);
        break;
    }
  }

  Future<void> _syncSupplierDelivery(
    String action,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as String;
    switch (action) {
      case LocalDatabase.actionCreate:
        final existing = await _sb
            .from('supplier_deliveries')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return;
        await _sb.from('supplier_deliveries').insert(p);
        break;
      case LocalDatabase.actionUpdate:
        await _sb.from('supplier_deliveries').update(p).eq('id', id);
        break;
      case LocalDatabase.actionDelete:
        await _sb.from('supplier_deliveries').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncProfile(Map<String, dynamic> p) async {
    final uid = p['uid'] as String? ?? p['id'] as String?;
    if (uid == null) return;
    final updates = Map<String, dynamic>.from(p)..remove('uid');
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
      return true; // default: apply local change
    }
  }

  // ── Exponential backoff: 2^attempts seconds, max 60s ─────────────────────
  int _backoff(int attempts) => min(pow(2, attempts).toInt(), 60);

  void dispose() {
    _connectSub?.cancel();
  }
}
