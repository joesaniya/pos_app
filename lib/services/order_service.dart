// lib/services/order_service.dart (fetchTableOrders fix only)
// ══════════════════════════════════════════════════════════════════════════════
//  PATCH: Replace only the fetchTableOrders() method in your existing
//  OrdersService class with this version.
//
//  FIX 1: fetchTableOrders() now uses fn_table_orders_v2 RPC which
//  applies session_id isolation — only the current guest's orders
//  are returned. Falls back to a direct query if the RPC doesn't
//  exist yet (safe during migration).
//
//  FIX 2: createOrder() partial-seat path no longer marks the whole
//  table as 'occupied' unless ALL seats are now occupied. This matches
//  the new fn_seat_guest_v2 server behaviour.
// ══════════════════════════════════════════════════════════════════════════════

// ─── DROP-IN REPLACEMENT for fetchTableOrders() ──────────────────────────────
//
//   Future<List<Order>> fetchTableOrders({
//     required String tableId,
//     required String businessId,
//   }) async { ... }
//
// ─────────────────────────────────────────────────────────────────────────────
//
// Paste the full updated class below into lib/services/order_service.dart,
// replacing the existing file content.

import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersService {
  OrdersService._();
  static final instance = OrdersService._();

  final _db = Supabase.instance.client;

  // ══════════════════════════════════════════════════════════
  //  ORDER NUMBER SEQUENCE
  //  Ensures order_number increments for each business when creating orders.
  Future<int> _getNextOrderNumber(String businessId) async {
    try {
      final latest = await _db
          .from('orders')
          .select('order_number')
          .eq('business_id', businessId)
          .order('order_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest is Map<String, dynamic>) {
        final raw = latest['order_number'];
        if (raw != null) {
          return (raw as num).toInt() + 1;
        }
      }
    } catch (e) {
      debugPrint('[OrdersService] _getNextOrderNumber error: $e');
    }

    return 1;
  }

  // ══════════════════════════════════════════════════════════
  //  FETCH ORDERS
  // ══════════════════════════════════════════════════════════

  Future<List<Order>> fetchTodayOrders({
    required String businessId,
    String? staffUid,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final istStartOfDay = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final istEndOfDay = istStartOfDay.add(const Duration(days: 1));
    final utcStart = istStartOfDay.subtract(
      const Duration(hours: 5, minutes: 30),
    );
    final utcEnd = istEndOfDay.subtract(const Duration(hours: 5, minutes: 30));

    var query = Supabase.instance.client
        .from('orders')
        .select('*, items:order_items(*)')
        .eq('business_id', businessId)
        .gte('created_at', utcStart.toIso8601String())
        .lt('created_at', utcEnd.toIso8601String());

    if (staffUid != null) {
      query = query.eq('created_by_uid', staffUid);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<List<Order>> fetchBusinessOrders({
    required String businessId,
    String? status,
    String? paymentStatus,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId);

    if (status != null) query = query.eq('status', status);
    if (paymentStatus != null) {
      query = query.eq('payment_status', paymentStatus);
    }
    if (from != null) query = query.gte('created_at', from.toIso8601String());
    if (to != null) query = query.lt('created_at', to.toIso8601String());

    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List)
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  bool _isTableIdUuid(String id) {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$',
    );
    return uuidRe.hasMatch(id);
  }

  // ── FIX: session-aware table orders ────────────────────────────────────────
  Future<List<Order>> fetchTableOrders({
    required String tableId,
    required String businessId,
  }) async {
    // Try the new session-aware RPC first (available after migration v8)
    if (_isTableIdUuid(tableId)) {
      try {
        final rpcData = await _db.rpc(
          'fn_table_orders_v2',
          params: {'p_table_id': tableId},
        );
        if (rpcData != null) {
          return (rpcData as List)
              .map((j) => Order.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (rpcError) {
        debugPrint(
          '[OrdersService] fn_table_orders_v2 RPC failed, using fallback: $rpcError',
        );
      }
    } else {
      debugPrint(
        '[OrdersService] tableId is not UUID, skipping fn_table_orders_v2 RPC: $tableId',
      );
    }

    // ── Fallback: direct query with session_id isolation ────────────────────
    // Step 1: get the current session_id from the table
    String? currentSession;
    try {
      final tableRow = await _db
          .from('restaurant_tables')
          .select('session_id')
          .eq('id', tableId)
          .maybeSingle();
      currentSession = tableRow?['session_id'] as String?;
    } catch (_) {}

    // Step 2: query active orders, filter by session
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId)
        .eq('table_id', tableId)
        .inFilter('status', ['pending', 'preparing', 'ready'])
        .order('created_at', ascending: true);

    final data = await query;
    final allOrders = (data as List)
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();

    // Step 3: filter by session_id if we have one
    if (currentSession != null && currentSession.isNotEmpty) {
      return allOrders.where((o) {
        // Include orders that match the current session OR have no session
        // (legacy orders created before session_id was added)
        return o.sessionId == null ||
            o.sessionId!.isEmpty ||
            o.sessionId == currentSession;
      }).toList();
    }

    return allOrders;
  }

  // ══════════════════════════════════════════════════════════
  //  FETCH SINGLE ORDER (for bill view)
  // ══════════════════════════════════════════════════════════

  Future<Order?> fetchOrder(String orderId) async {
    try {
      final data = await _db
          .from('vw_orders_with_items')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      if (data == null) return null;
      return Order.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[OrdersService] fetchOrder error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CREATE ORDER  (FIX: seat-level table status)
  // ══════════════════════════════════════════════════════════

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
    // ── DUPLICATE ORDER GUARD ────────────────────────────────────────────────
    if (tableSeatId != null && tableSeatId.isNotEmpty) {
      final existing = await _db
          .from('orders')
          .select('id')
          .eq('table_seat_id', tableSeatId)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .limit(1);
      if ((existing as List).isNotEmpty) {
        throw Exception(
          'An active order already exists for this seat. '
          'Complete or cancel it before placing a new one.',
        );
      }
    }

    if (tableId != null &&
        orderType == OrderType.dineIn &&
        (tableSeatId == null || tableSeatId.isEmpty)) {
      final existing = await _db
          .from('orders')
          .select('id')
          .eq('table_id', tableId)
          .isFilter('table_seat_id', null)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .limit(1);
      if ((existing as List).isNotEmpty) {
        throw Exception(
          'An active order already exists for this table. '
          'Add items to the existing order or complete it first.',
        );
      }
    }

    // ── SEAT LABEL LOOKUP ───────────────────────────────────────────────────
    String? seatLabel;
    if (tableSeatId != null && tableSeatId.isNotEmpty) {
      try {
        final seatRow = await _db
            .from('table_seats')
            .select('seat_label')
            .eq('id', tableSeatId)
            .maybeSingle();
        seatLabel = seatRow?['seat_label'] as String?;
      } catch (_) {}
    }

    // ── GET CURRENT SESSION ID ──────────────────────────────────────────────
    String? sessionId;
    if (tableId != null) {
      try {
        final tableRow = await _db
            .from('restaurant_tables')
            .select('session_id')
            .eq('id', tableId)
            .maybeSingle();
        sessionId = tableRow?['session_id'] as String?;
      } catch (_) {}
    }

    final subtotal = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;

    final orderNumber = await _getNextOrderNumber(businessId);

    final orderData = await (() async {
      try {
        return await _db
            .from('orders')
            .insert({
              'business_id': businessId,
              'business_name': businessName,
              'status': 'pending',
              'payment_status': 'unpaid',
              'order_type': orderType.value,
              'order_number': orderNumber,
              'table_id': tableId,
              'table_number': tableNumber,
              'table_seat_id': tableSeatId,
              'seat_label': seatLabel,
              'session_id': sessionId,
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
            })
            .select()
            .single();
      } on PostgrestException catch (e) {
        final details = e.details?.toString() ?? '';
        final message = e.message?.toString().toLowerCase() ?? '';

        if (e.code == '23505' ||
            details.contains('uq_active_seat_order') ||
            message.contains('duplicate key')) {
          throw Exception(
            'Cannot create order: an active order already exists for this seat/table. '
            'Please complete or cancel the existing order first.',
          );
        }
        rethrow;
      }
    })();

    final orderId = orderData['id'] as String;

    if (cartItems.isNotEmpty) {
      await _db
          .from('order_items')
          .insert(
            cartItems
                .map(
                  (c) => {
                    'order_id': orderId,
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
          );
    }

    // ── TABLE STATUS UPDATE — SEAT-AWARE (FIX) ─────────────────────────────
    if (tableId != null) {
      if (tableSeatId != null && tableSeatId.isNotEmpty) {
        // PARTIAL SEAT ORDER:
        // 1. Mark this specific seat as occupied
        await _db
            .from('table_seats')
            .update({'status': 'occupied'})
            .eq('id', tableSeatId);

        // 2. FIX: Check if ALL seats are now occupied before changing table status
        final seatRows = await _db
            .from('table_seats')
            .select('status')
            .eq('table_id', tableId);
        final allSeats = seatRows as List;
        final totalSeats = allSeats.length;
        final occupiedCount = allSeats
            .where((s) => (s['status'] as String?) == 'occupied')
            .length;
        final allOccupied = totalSeats > 0 && occupiedCount >= totalSeats;

        if (allOccupied) {
          // FIX: Only mark 'occupied' when ALL seats are taken
          await _db
              .from('restaurant_tables')
              .update({
                'current_order_id': orderId,
                'current_order_total': totalAmount,
                'current_customer_name': customerName,
                'status': 'occupied',
                'occupied_since': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', tableId);
        } else {
          // FIX: Some seats still free — only update financials, NOT status
          // This allows other guests to still book remaining seats
          await _db
              .from('restaurant_tables')
              .update({
                'current_order_id': orderId,
                'current_order_total': totalAmount,
                // Do NOT set status or current_customer_name here
              })
              .eq('id', tableId);
        }
      } else {
        // FULL TABLE ORDER: mark entire table occupied
        await _db
            .from('restaurant_tables')
            .update({
              'current_order_id': orderId,
              'current_order_total': totalAmount,
              'current_customer_name': customerName,
              'status': 'occupied',
              'occupied_since': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', tableId);
      }
    }

    final full = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();
    return Order.fromJson(full as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  CONFIRM PAYMENT → auto-completes order via DB trigger
  // ══════════════════════════════════════════════════════════

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
    final updateMap = <String, dynamic>{
      'payment_status': 'paid',
      'payment_mode': mode.value,
      'paid_by_uid': paidByUid,
      'paid_by_name': paidByName,
      'paid_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (paymentRef != null && paymentRef.isNotEmpty) {
      updateMap['payment_ref'] = paymentRef;
    }
    if (tipAmount != null && tipAmount > 0) {
      updateMap['tip_amount'] = tipAmount;
    }
    if (discountAmount != null && discountAmount > 0) {
      updateMap['discount_amount'] = discountAmount;
    }

    await _db.from('orders').update(updateMap).eq('id', orderId);

    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();
    return Order.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  UPDATE STATUS
  // ══════════════════════════════════════════════════════════

  Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String updatedByUid,
    required String updatedByName,
    required String businessId,
  }) async {
    assert(
      newStatus != OrderStatus.completed,
      'Use confirmPayment() to complete orders',
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final updateMap = <String, dynamic>{
      'status': newStatus.value,
      'updated_by_uid': updatedByUid,
      'updated_by_name': updatedByName,
    };

    switch (newStatus) {
      case OrderStatus.preparing:
        updateMap['started_at'] = now;
        break;
      case OrderStatus.ready:
        updateMap['ready_at'] = now;
        break;
      case OrderStatus.cancelled:
        updateMap['cancelled_at'] = now;
        break;
      default:
        break;
    }

    await _db.from('orders').update(updateMap).eq('id', orderId);

    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();
    return Order.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchUnreadNotifications({
    required String businessId,
    String? targetUid,
  }) async {
    var query = _db
        .from('order_notifications')
        .select()
        .eq('business_id', businessId)
        .eq('is_read', false);

    if (targetUid != null) {
      query = query.or('target_uid.is.null,target_uid.eq.$targetUid');
    }

    final data = await query.order('created_at', ascending: false).limit(50);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> markNotificationsRead({
    required String businessId,
    List<String>? ids,
  }) async {
    var query = _db
        .from('order_notifications')
        .update({'is_read': true})
        .eq('business_id', businessId);
    if (ids != null) query = query.inFilter('id', ids);
    await query;
  }

  // ══════════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════════

  RealtimeChannel subscribeToOrders({
    required String businessId,
    required void Function(Order order, String eventType) onEvent,
  }) {
    return _db
        .channel('orders:$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) async {
            try {
              final record = payload.newRecord;
              if (record.isEmpty) return;
              final full = await _db
                  .from('vw_orders_with_items')
                  .select()
                  .eq('id', record['id'])
                  .maybeSingle();
              if (full != null) {
                onEvent(
                  Order.fromJson(full as Map<String, dynamic>),
                  payload.eventType.name,
                );
              }
            } catch (e, st) {
              debugPrint('[OrdersService] realtime callback error: $e\n$st');
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToNotifications({
    required String businessId,
    required void Function(Map<String, dynamic>) onNotification,
  }) {
    return _db
        .channel('notifications:$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNotification(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  // ══════════════════════════════════════════════════════════
  //  ANALYTICS
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchRevenueSummary({
    required String businessId,
    required DateTime from,
    required DateTime to,
    String? staffUid,
  }) async {
    final data = await _db.rpc(
      'fn_revenue_summary',
      params: {
        'p_business_id': businessId,
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_staff_uid': staffUid,
      },
    );
    final row = (data as List).isNotEmpty
        ? data[0] as Map<String, dynamic>
        : {};
    return {
      'total_revenue': (row['total_revenue'] as num? ?? 0).toDouble(),
      'total_orders': (row['total_orders'] as num? ?? 0).toInt(),
      'avg_order': (row['avg_order'] as num? ?? 0).toDouble(),
      'completed': (row['completed'] as num? ?? 0).toInt(),
      'cancelled': (row['cancelled'] as num? ?? 0).toInt(),
    };
  }
}
