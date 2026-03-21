// lib/services/orders_service.dart
// v2: Added confirmPayment() — the only way to complete an order

import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersService {
  OrdersService._();
  static final instance = OrdersService._();

  final _db = Supabase.instance.client;

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

  Future<List<Order>> fetchTableOrders({
    required String tableId,
    required String businessId,
  }) async {
    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId)
        .eq('table_id', tableId)
        .inFilter('status', ['pending', 'preparing', 'ready'])
        .order('created_at', ascending: true);

    return (data as List)
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();
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
  //  CREATE ORDER
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
    String? customerName,
    String? customerPhone,
    String? notes,
    double taxRate = 5.0,
  }) async {
    // ── DUPLICATE ORDER GUARD ────────────────────────────────────────────────
    // Guard A: Per-seat orders — check for an existing active order on that seat.
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

    // Guard B: Whole-table dine-in orders — check for an existing active
    // order on the table that has no seat ID assigned (same level of order).
    // This prevents duplicate whole-table orders from double-taps.
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

    // ── SEAT LABEL LOOKUP (for per-seat orders) ─────────────────────────────
    String? seatLabel;
    if (tableSeatId != null && tableSeatId.isNotEmpty) {
      try {
        final seatRow = await _db
            .from('table_seats')
            .select('seat_label')
            .eq('id', tableSeatId)
            .maybeSingle();
        seatLabel = seatRow?['seat_label'] as String?;
      } catch (_) {
        // non-fatal: proceed without seat label
      }
    }

    final subtotal = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;

    final orderData = await _db
        .from('orders')
        .insert({
          'business_id': businessId,
          'business_name': businessName,
          'status': 'pending',
          'payment_status': 'unpaid', // always starts unpaid
          'order_type': orderType.value,
          'table_id': tableId,
          'table_number': tableNumber,
          'table_seat_id': tableSeatId,
          'seat_label': seatLabel,
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

    // ── TABLE STATUS UPDATE — SEAT-AWARE ──────────────────────────────────
    if (tableId != null) {
      if (tableSeatId != null && tableSeatId.isNotEmpty) {
        // PARTIAL SEAT ORDER:
        // 1. Mark this specific seat as occupied
        await _db
            .from('table_seats')
            .update({'status': 'occupied'})
            .eq('id', tableSeatId);

        // 2. Check if ALL seats are now occupied
        final seatRows = await _db
            .from('table_seats')
            .select('status')
            .eq('table_id', tableId);
        final allOccupied = (seatRows as List)
            .every((s) => (s['status'] as String?) == 'occupied');

        if (allOccupied) {
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
          // Partial: update order metadata, keep table status unchanged
          // (leave as 'available' or 'partial' so other seats are bookable)
          await _db
              .from('restaurant_tables')
              .update({
                'current_order_id': orderId,
                'current_order_total': totalAmount,
              })
              .eq('id', tableId);
        }
      } else {
        // FULL TABLE ORDER: mark entire table occupied as before
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

    // The DB trigger fn_auto_complete_on_payment will:
    // 1. Set paid_at
    // 2. Set bill_generated_at
    // 3. Auto-set status = 'completed'
    await _db.from('orders').update(updateMap).eq('id', orderId);

    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();
    return Order.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  UPDATE STATUS (kitchen flow — pending→preparing→ready)
  //  NOTE: 'completed' is NOT allowed here; use confirmPayment()
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
