// lib/repositories/orders_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  ORDERS REPOSITORY — Offline-first  (FIXED v2)
//
//  KEY FIXES:
//  1. fetchTableOrders() now has an offline fallback that reads from local
//     SQLite, filters by table_id + active statuses + current session_id so
//     old guests' orders never bleed through.
//  2. clearTableOrdersLocally() is called by TablesRepository.seatGuests()
//     whenever a new guest is seated — it marks every previous local order
//     for that table as 'completed' so they disappear from the active view.
//  3. refreshOrdersFromRemote() now stores session_id in the local cache so
//     the session filter above works correctly after a remote sync.
//  4. createOrder() stores session_id in the local order map so offline
//     orders can be session-filtered too.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';
import 'package:pos_app/services/order_service.dart';

class OrdersRepository {
  OrdersRepository._();
  static final instance = OrdersRepository._();

  final _local = LocalDatabase.instance;
  final _remote = OrdersService.instance;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH TODAY'S ORDERS
  //  Always returns from local DB. Triggers remote refresh if online.
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Order>> fetchTodayOrders({
    required String businessId,
    String? staffUid,
  }) async {
    // Build today's IST date boundaries
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final startIS = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final endIS = startIS.add(const Duration(days: 1));

    // Read from local cache
    final localRows = await _local.getEntities(
      table: LocalDatabase.tOrders,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );

    // Filter to today IST
    final orders = localRows.map(_rowToOrder).whereType<Order>().where((o) {
      final t = o.createdAt;
      return t.isAfter(startIS) && t.isBefore(endIS);
    }).toList();

    return orders..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Pull orders from Supabase and update local cache.
  Future<void> refreshOrdersFromRemote({required String businessId}) async {
    try {
      final remoteOrders = await _remote.fetchTodayOrders(
        businessId: businessId,
      );
      for (final order in remoteOrders) {
        // FIX: include session_id in the sync map so offline filtering works
        final data = order.toSyncMap();
        await _local.upsertEntity(
          table: LocalDatabase.tOrders,
          id: order.id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
      }
      log('[OrdersRepo] Remote refresh: ${remoteOrders.length} orders cached');
    } catch (e) {
      debugPrint('[OrdersRepo] Remote refresh error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH TABLE ORDERS  (FIX: offline fallback + session isolation)
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns only the *active* orders for a specific table.
  ///
  /// Online  → queries the Supabase view which already enforces session
  ///           isolation via `vw_active_table_orders`.
  /// Offline → reads from local SQLite cache, filters by:
  ///             • table_id == [tableId]
  ///             • status in (pending, preparing, ready)
  ///             • session_id == current table session  (prevents old orders
  ///               from showing after a new guest is seated)
  Future<List<Order>> fetchTableOrders({
    required String tableId,
    required String businessId,
  }) async {
    if (_connectivity.isOnline) {
      try {
        // Online path — delegates to remote service
        final orders = await _remote.fetchTableOrders(
          tableId: tableId,
          businessId: businessId,
        );
        // Cache the results locally so offline reads are up to date
        for (final o in orders) {
          await _local.upsertEntity(
            table: LocalDatabase.tOrders,
            id: o.id,
            businessId: businessId,
            data: o.toSyncMap(),
            syncStatus: LocalDatabase.syncSynced,
            action: LocalDatabase.actionUpdate,
          );
        }
        return orders;
      } catch (e) {
        debugPrint(
          '[OrdersRepo] Online fetchTableOrders failed, falling back: $e',
        );
        // Fall through to offline path
      }
    }

    // ── OFFLINE PATH ──────────────────────────────────────────────────────
    // 1. Determine the current session_id for this table from local cache
    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
    final currentSessionId = tableRow?['session_id'] as String?;

    // 2. Read all local orders and filter
    final localRows = await _local.getEntities(
      table: LocalDatabase.tOrders,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );

    final activeStatuses = {'pending', 'preparing', 'ready'};

    final orders = localRows.map(_rowToOrder).whereType<Order>().where((o) {
      // Must belong to this table
      if (o.tableId != tableId) return false;

      // Must be in an active status
      if (!activeStatuses.contains(o.status.value)) return false;

      // FIX: Session isolation — only show orders from the *current* session.
      // If we have a session_id for the table, only show orders that match it.
      // If we don't have a session_id (e.g. first offline seating), show all
      // active orders for this table (safe because previous orders were cleared
      // in clearTableOrdersLocally() when the guest was seated).
      if (currentSessionId != null && currentSessionId.isNotEmpty) {
        final orderSession = o.sessionId;
        if (orderSession != null &&
            orderSession.isNotEmpty &&
            orderSession != currentSessionId) {
          return false; // belongs to a previous guest session
        }
      }

      return true;
    }).toList();

    orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return orders;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLEAR STALE TABLE ORDERS  (FIX: called when new guest is seated)
  // ══════════════════════════════════════════════════════════════════════════

  /// Marks all locally-cached active orders for [tableId] as 'completed'
  /// so they don't appear when a new guest is seated at the same table.
  ///
  /// This mirrors what `fn_checkout` / `fn_seat_guest` do on the server:
  /// the server sets `status = 'completed'` on all session-scoped orders
  /// when a table is cleared. Offline, we do it locally.
  Future<void> clearTableOrdersLocally({
    required String tableId,
    required String businessId,
  }) async {
    try {
      final localRows = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      final activeStatuses = {'pending', 'preparing', 'ready'};
      final now = DateTime.now().toUtc().toIso8601String();

      for (final row in localRows) {
        final status = row['status'] as String? ?? '';
        if (row['table_id'] == tableId && activeStatuses.contains(status)) {
          // Mark as completed locally
          final updated = Map<String, dynamic>.from(row);
          updated['status'] = 'completed';
          updated['completed_at'] = now;
          updated['updated_at'] = now;

          await _local.upsertEntity(
            table: LocalDatabase.tOrders,
            id: row['id'] as String,
            businessId: businessId,
            data: updated,
            syncStatus: LocalDatabase.syncSynced,
            // Don't re-queue — the server already handled this via fn_checkout
            action: LocalDatabase.actionUpdate,
          );
        }
      }

      log('[OrdersRepo] Cleared stale orders for table $tableId');
    } catch (e) {
      debugPrint('[OrdersRepo] clearTableOrdersLocally error: $e');
    }
  }

  /// Clears only active orders for a specific seat, preserving other seats' orders
  Future<void> clearSeatOrdersLocally({
    required String tableId,
    required String seatId,
    required String businessId,
  }) async {
    try {
      final localRows = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      final activeStatuses = {'pending', 'preparing', 'ready'};
      final now = DateTime.now().toUtc().toIso8601String();

      for (final row in localRows) {
        final status = row['status'] as String? ?? '';
        if (row['table_id'] == tableId &&
            row['table_seat_id'] == seatId &&
            activeStatuses.contains(status)) {
          final updated = Map<String, dynamic>.from(row);
          updated['status'] = 'completed';
          updated['payment_status'] = 'paid';
          updated['completed_at'] = now;
          updated['updated_at'] = now;

          await _local.upsertEntity(
            table: LocalDatabase.tOrders,
            id: row['id'] as String,
            businessId: businessId,
            data: updated,
            syncStatus: LocalDatabase.syncSynced,
            action: LocalDatabase.actionUpdate,
          );
        }
      }

      log(
        '[OrdersRepo] Cleared stale orders for seat $seatId on table $tableId',
      );
    } catch (e) {
      debugPrint('[OrdersRepo] clearSeatOrdersLocally error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ORDER NUMBER SEQUENCE (LOCAL FALLBACK)
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> _getNextLocalOrderNumber(String businessId) async {
    try {
      final rows = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: businessId,
      );
      var maxOrderNum = 0;
      for (final row in rows) {
        final numValue = row['order_number'] as int?;
        if (numValue != null && numValue > maxOrderNum) {
          maxOrderNum = numValue;
        }
      }
      return maxOrderNum + 1;
    } catch (e) {
      debugPrint('[OrdersRepo] _getNextLocalOrderNumber error: $e');
      return 1;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE ORDER
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required String businessId,
    required String businessName,
    required String createdByUid,
    required String createdByName,
    required String createdByRole,
    required OrderType orderType,
    String? tableId,
    int? tableNumber,
    String? tableSeatId,
    String? seatLabel,
    String? customerName,
    String? customerPhone,
    String? notes,
    double taxRate = 5.0,
  }) async {
    if (_connectivity.isOnline) {
      // ONLINE: call Supabase directly (existing flow), then cache result
      try {
        final order = await _remote.createOrder(
          cartItems: cartItems,
          businessId: businessId,
          businessName: businessName,
          createdByUid: createdByUid,
          createdByName: createdByName,
          createdByRole: createdByRole,
          orderType: orderType,
          tableId: tableId,
          tableNumber: tableNumber,
          tableSeatId: tableSeatId,
          seatLabel: seatLabel,
          customerName: customerName,
          customerPhone: customerPhone,
          notes: notes,
          taxRate: taxRate,
        );
        // Cache for offline reads (FIX: toSyncMap now includes session_id)
        await _local.upsertEntity(
          table: LocalDatabase.tOrders,
          id: order.id,
          businessId: businessId,
          data: order.toSyncMap(),
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionCreate,
        );
        return order;
      } catch (e) {
        debugPrint(
          '[OrdersRepo] Online create failed, falling back to offline: $e',
        );
      }
    }

    // OFFLINE: check for active table/seat conflict in local cache
    if (tableSeatId != null && tableSeatId.isNotEmpty) {
      final allOrders = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      final activeStatuses = {
        OrderStatus.pending.value,
        OrderStatus.preparing.value,
        OrderStatus.ready.value,
      };

      final existingSeat = allOrders.where((row) {
        final orderData = row['data'] as String?;
        if (orderData == null) return false;

        try {
          final decoded = jsonDecode(orderData) as Map<String, dynamic>;
          final seatId = decoded['table_seat_id'] as String?;
          final status = decoded['status'] as String?;

          return seatId == tableSeatId && activeStatuses.contains(status);
        } catch (e) {
          return false;
        }
      }).toList();

      if (existingSeat.isNotEmpty) {
        throw Exception(
          'An active order already exists for this seat. Complete or cancel it before creating a new one.',
        );
      }
    }

    if (tableId != null &&
        orderType == OrderType.dineIn &&
        (tableSeatId == null || tableSeatId.isEmpty)) {
      final allOrders = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      final activeStatuses = {
        OrderStatus.pending.value,
        OrderStatus.preparing.value,
        OrderStatus.ready.value,
      };

      final existingTable = allOrders.where((row) {
        final orderData = row['data'] as String?;
        if (orderData == null) return false;

        try {
          final decoded = jsonDecode(orderData) as Map<String, dynamic>;
          final tId = decoded['table_id'] as String?;
          final seatId = decoded['table_seat_id'] as String?;
          final status = decoded['status'] as String?;

          return tId == tableId &&
              (seatId == null || seatId.isEmpty) &&
              activeStatuses.contains(status);
        } catch (e) {
          return false;
        }
      }).toList();

      if (existingTable.isNotEmpty) {
        throw Exception(
          'An active order already exists for this table. Add items to it or checkout the existing order first.',
        );
      }
    }

    // OFFLINE: generate local ID and store locally
    final subtotal = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;
    final localId = _uuid.v4();
    final orderNumber = await _getNextLocalOrderNumber(businessId);
    final now = DateTime.now().toUtc().toIso8601String();

    // FIX: Read the current session_id from the local table cache so the
    // order is correctly session-scoped even when offline.
    String? sessionId;
    if (tableId != null) {
      final tableRows = await _local.getEntities(
        table: LocalDatabase.tTables,
        businessId: businessId,
      );
      final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
      sessionId = tableRow?['session_id'] as String?;
    }

    final orderMap = <String, dynamic>{
      'id': localId,
      'business_id': businessId,
      'business_name': businessName,
      'order_number': orderNumber,
      'status': OrderStatus.pending.value,
      'payment_status': PaymentStatus.unpaid.value,
      'order_type': orderType.value,
      'table_id': tableId,
      'table_number': tableNumber,
      'table_seat_id': tableSeatId,
      'seat_label': seatLabel, // FIX: store seat label
      'session_id': sessionId, // FIX: persist session_id
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'tax_rate': taxRate,
      'total_amount': totalAmount,
      'notes': notes,
      'created_by_uid': createdByUid,
      'created_by_name': createdByName,
      'created_by_role': createdByRole,
      'created_at': now,
      'updated_at': now,
      'items': cartItems
          .map(
            (c) => {
              'order_id': localId,
              'menu_item_id': c.menuItemId,
              'item_name': c.itemName,
              'item_price': c.itemPrice,
              'category_name': c.categoryName,
              'is_veg': c.isVeg,
              'quantity': c.quantity,
              'subtotal': c.subtotal,
              'notes': c.notes,
            },
          )
          .toList(),
    };

    // Save locally
    await _local.upsertEntity(
      table: LocalDatabase.tOrders,
      id: localId,
      businessId: businessId,
      data: orderMap,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    // Queue for sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.order,
      entityId: localId,
      action: LocalDatabase.actionCreate,
      payload: orderMap,
      businessId: businessId,
    );

    // Build and return Order object from local data
    return Order.fromJson(orderMap);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE ORDER STATUS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String updatedByUid,
    required String updatedByName,
    required String businessId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': orderId,
      'status': newStatus.value,
      'updated_by_uid': updatedByUid,
      'updated_by_name': updatedByName,
      'updated_at': now,
    };

    if (newStatus == OrderStatus.preparing) payload['started_at'] = now;
    if (newStatus == OrderStatus.ready) payload['ready_at'] = now;
    if (newStatus == OrderStatus.cancelled) payload['cancelled_at'] = now;

    if (_connectivity.isOnline) {
      try {
        return await _remote.updateOrderStatus(
          orderId: orderId,
          newStatus: newStatus,
          updatedByUid: updatedByUid,
          updatedByName: updatedByName,
          businessId: businessId,
        );
      } catch (_) {}
    }

    // Offline: update local cache
    await _updateLocalOrderField(orderId, businessId, payload);

    // Queue for sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.orderStatus,
      entityId: orderId,
      action: LocalDatabase.actionUpdate,
      payload: payload,
      businessId: businessId,
    );

    return _buildOrderFromLocal(orderId, businessId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIRM PAYMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> confirmPayment({
    required String orderId,
    required OrderPaymentMode mode,
    required String paidByUid,
    required String paidByName,
    required String businessId,
    String? paymentRef,
    double? tipAmount,
    double? discountAmount,
  }) async {
    if (_connectivity.isOnline) {
      try {
        return await _remote.confirmPayment(
          orderId: orderId,
          mode: mode,
          paidByUid: paidByUid,
          paidByName: paidByName,
          businessId: businessId,
          paymentRef: paymentRef,
          tipAmount: tipAmount,
          discountAmount: discountAmount,
        );
      } catch (_) {}
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': orderId,
      'payment_status': 'paid',
      'payment_mode': mode.value,
      'paid_by_uid': paidByUid,
      'paid_by_name': paidByName,
      'paid_at': now,
      'updated_at': now,
      if (paymentRef != null) 'payment_ref': paymentRef,
      if (tipAmount != null) 'tip_amount': tipAmount,
      if (discountAmount != null) 'discount_amount': discountAmount,
    };

    await _updateLocalOrderField(orderId, businessId, payload);

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.orderPayment,
      entityId: orderId,
      action: LocalDatabase.actionUpdate,
      payload: payload,
      businessId: businessId,
    );

    return _buildOrderFromLocal(orderId, businessId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME (delegate to remote service)
  // ══════════════════════════════════════════════════════════════════════════

  RealtimeChannel subscribeToOrders({
    required String businessId,
    required void Function(Order order, String eventType) onEvent,
  }) => _remote.subscribeToOrders(businessId: businessId, onEvent: onEvent);

  RealtimeChannel subscribeToNotifications({
    required String businessId,
    required void Function(Map<String, dynamic>) onNotification,
  }) => _remote.subscribeToNotifications(
    businessId: businessId,
    onNotification: onNotification,
  );

  Future<List<Map<String, dynamic>>> fetchUnreadNotifications({
    required String businessId,
    String? targetUid,
  }) => _remote.fetchUnreadNotifications(
    businessId: businessId,
    targetUid: targetUid,
  );

  Future<void> markNotificationsRead({required String businessId}) =>
      _remote.markNotificationsRead(businessId: businessId);

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _updateLocalOrderField(
    String orderId,
    String businessId,
    Map<String, dynamic> fields,
  ) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tOrders,
      businessId: businessId,
    );
    final existing = rows.firstWhere(
      (r) => r['id'] == orderId,
      orElse: () => <String, dynamic>{},
    );
    if (existing.isEmpty) return;
    existing.addAll(fields);
    await _local.upsertEntity(
      table: LocalDatabase.tOrders,
      id: orderId,
      businessId: businessId,
      data: existing,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );
  }

  Future<Order> _buildOrderFromLocal(String orderId, String businessId) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tOrders,
      businessId: businessId,
    );
    final row = rows.firstWhere(
      (r) => r['id'] == orderId,
      orElse: () => <String, dynamic>{'id': orderId},
    );
    return Order.fromJson(row);
  }

  Order? _rowToOrder(Map<String, dynamic> row) {
    try {
      return Order.fromJson(row);
    } catch (e) {
      debugPrint('[OrdersRepo] Parse error: $e');
      return null;
    }
  }
}

// ── Sync map extension on Order ────────────────────────────────────────────
extension OrderSyncMap on Order {
  Map<String, dynamic> toSyncMap() => {
    'id': id,
    'business_id': businessId,
    'business_name': businessName,
    'status': status.value,
    'payment_status': paymentStatus.value,
    'order_type': orderType.value,
    'table_id': tableId,
    'table_number': tableNumber,
    'table_seat_id': tableSeatId,
    'seat_label': seatLabel,
    'session_id': sessionId, // FIX: always include session_id in sync map
    'order_number': orderNumber,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'tax_rate': taxRate,
    'total_amount': totalAmount,
    'tip_amount': tipAmount,
    'discount_amount': discountAmount,
    'notes': notes,
    'created_by_uid': createdByUid,
    'created_by_name': createdByName,
    'created_by_role': createdByRole,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
    'items': items
        .map(
          (i) => {
            'id': i.id,
            'order_id': id,
            'menu_item_id': i.menuItemId,
            'item_name': i.itemName,
            'item_price': i.itemPrice,
            'category_name': i.categoryName,
            'is_veg': i.isVeg,
            'quantity': i.quantity,
            'subtotal': i.subtotal,
            'notes': i.notes,
          },
        )
        .toList(),
  };
}
