// lib/repositories/orders_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  ORDERS REPOSITORY — Offline-first
//  All writes go to local SQLite first, then sync to Supabase when online.
// ══════════════════════════════════════════════════════════════════════════════

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
  final _sb = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  //  Always returns from local DB. Triggers remote refresh if online.
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Order>> fetchTodayOrders({
    required String businessId,
    String? staffUid,
  }) async {
    // Build today's IST date boundaries
    final nowUtc  = DateTime.now().toUtc();
    final nowIst  = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final startIS = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final endIS   = startIS.add(const Duration(days: 1));

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
      final remoteOrders = await _remote.fetchTodayOrders(businessId: businessId);
      for (final order in remoteOrders) {
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
    String? customerName,
    String? customerPhone,
    String? notes,
    double taxRate = 5.0,
  }) async {
    if (_connectivity.isOnline) {
      // ONLINE: call Supabase directly (existing flow), then cache result
      try {
        final order = await _remote.createOrder(
          cartItems:       cartItems,
          businessId:      businessId,
          businessName:    businessName,
          createdByUid:    createdByUid,
          createdByName:   createdByName,
          createdByRole:   createdByRole,
          orderType:       orderType,
          tableId:         tableId,
          tableNumber:     tableNumber,
          tableSeatId:     tableSeatId,
          customerName:    customerName,
          customerPhone:   customerPhone,
          notes:           notes,
          taxRate:         taxRate,
        );
        // Cache for offline reads
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
        debugPrint('[OrdersRepo] Online create failed, falling back to offline: $e');
      }
    }

    // OFFLINE: generate local ID and store locally
    final subtotal    = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount   = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;
    final localId     = _uuid.v4();
    final now         = DateTime.now().toUtc().toIso8601String();

    final orderMap = <String, dynamic>{
      'id':                localId,
      'business_id':       businessId,
      'business_name':     businessName,
      'status':            OrderStatus.pending.value,
      'payment_status':    PaymentStatus.unpaid.value,
      'order_type':        orderType.value,
      'table_id':          tableId,
      'table_number':      tableNumber,
      'table_seat_id':     tableSeatId,
      'customer_name':     customerName,
      'customer_phone':    customerPhone,
      'subtotal':          subtotal,
      'tax_amount':        taxAmount,
      'tax_rate':          taxRate,
      'total_amount':      totalAmount,
      'notes':             notes,
      'created_by_uid':    createdByUid,
      'created_by_name':   createdByName,
      'created_by_role':   createdByRole,
      'created_at':        now,
      'updated_at':        now,
      'items':             cartItems.map((c) => {
        'order_id':       localId,
        'menu_item_id':   c.menuItemId,
        'item_name':      c.itemName,
        'item_price':     c.itemPrice,
        'category_name':  c.categoryName,
        'is_veg':         c.isVeg,
        'quantity':       c.quantity,
        'subtotal':       c.subtotal,
        'notes':          c.notes,
      }).toList(),
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
      'id':               orderId,
      'status':           newStatus.value,
      'updated_by_uid':   updatedByUid,
      'updated_by_name':  updatedByName,
      'updated_at':       now,
    };

    if (newStatus == OrderStatus.preparing) payload['started_at']   = now;
    if (newStatus == OrderStatus.ready)     payload['ready_at']     = now;
    if (newStatus == OrderStatus.cancelled) payload['cancelled_at'] = now;

    if (_connectivity.isOnline) {
      try {
        return await _remote.updateOrderStatus(
          orderId:       orderId,
          newStatus:     newStatus,
          updatedByUid:  updatedByUid,
          updatedByName: updatedByName,
          businessId:    businessId,
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
          orderId:        orderId,
          mode:           mode,
          paidByUid:      paidByUid,
          paidByName:     paidByName,
          businessId:     businessId,
          paymentRef:     paymentRef,
          tipAmount:      tipAmount,
          discountAmount: discountAmount,
        );
      } catch (_) {}
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id':             orderId,
      'payment_status': 'paid',
      'payment_mode':   mode.value,
      'paid_by_uid':    paidByUid,
      'paid_by_name':   paidByName,
      'paid_at':        now,
      'updated_at':     now,
      if (paymentRef != null)     'payment_ref':     paymentRef,
      if (tipAmount != null)      'tip_amount':      tipAmount,
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
  }) => _remote.subscribeToNotifications(businessId: businessId, onNotification: onNotification);

  Future<List<Map<String, dynamic>>> fetchUnreadNotifications({
    required String businessId,
    String? targetUid,
  }) => _remote.fetchUnreadNotifications(businessId: businessId, targetUid: targetUid);

  Future<void> markNotificationsRead({required String businessId}) =>
      _remote.markNotificationsRead(businessId: businessId);

  Future<List<Order>> fetchTableOrders({
    required String tableId,
    required String businessId,
  }) => _remote.fetchTableOrders(tableId: tableId, businessId: businessId);

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
    'id':               id,
    'business_id':      businessId,
    'business_name':    businessName,
    'status':           status.value,
    'payment_status':   paymentStatus.value,
    'order_type':       orderType.value,
    'table_id':         tableId,
    'table_number':     tableNumber,
    'table_seat_id':    tableSeatId,
    'seat_label':       seatLabel,
    'customer_name':    customerName,
    'customer_phone':   customerPhone,
    'subtotal':         subtotal,
    'tax_amount':       taxAmount,
    'tax_rate':         taxRate,
    'total_amount':     totalAmount,
    'tip_amount':       tipAmount,
    'discount_amount':  discountAmount,
    'notes':            notes,
    'created_by_uid':   createdByUid,
    'created_by_name':  createdByName,
    'created_by_role':  createdByRole,
    'created_at':       createdAt.toUtc().toIso8601String(),
    'updated_at':       (updatedAt ?? createdAt).toUtc().toIso8601String(),
    'items':            items.map((i) => {
      'id':           i.id,
      'order_id':     id,
      'menu_item_id': i.menuItemId,
      'item_name':    i.itemName,
      'item_price':   i.itemPrice,
      'category_name': i.categoryName,
      'is_veg':       i.isVeg,
      'quantity':     i.quantity,
      'subtotal':     i.subtotal,
      'notes':        i.notes,
    }).toList(),
  };
}
