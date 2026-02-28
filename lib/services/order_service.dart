// lib/services/orders_service.dart
// Supabase backend service for all order operations

import 'package:pos_app/models/order_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersService {
  OrdersService._();
  static final instance = OrdersService._();

  final _db = Supabase.instance.client;

  // ══════════════════════════════════════════════════════
  //  FETCH ORDERS
  // ══════════════════════════════════════════════════════

  /// All orders for a business (admin/manager view)
  Future<List<Order>> fetchBusinessOrders({
    required String businessId,
    String? status,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId);

    if (status != null) query = query.eq('status', status);
    if (from != null)   query = query.gte('created_at', from.toIso8601String());
    if (to != null)     query = query.lt('created_at', to.toIso8601String());

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Orders for a specific staff member
  Future<List<Order>> fetchStaffOrders({
    required String businessId,
    required String staffUid,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId)
        .eq('created_by_uid', staffUid);

    if (status != null) query = query.eq('status', status);
    if (from != null)   query = query.gte('created_at', from.toIso8601String());
    if (to != null)     query = query.lt('created_at', to.toIso8601String());

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Active orders for a specific table
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

    return (data as List).map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Today's orders for a business — used for live order screen
  Future<List<Order>> fetchTodayOrders({
    required String businessId,
    String? staffUid, // null = all staff
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String());

    if (staffUid != null) query = query.eq('created_by_uid', staffUid);

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════════
  //  CREATE ORDER
  // ══════════════════════════════════════════════════════
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
    String? customerName,
    String? customerPhone,
    String? notes,
    double taxRate = 5.0,
  }) async {
    // Calculate financials
    final subtotal = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;

    // Insert order
    final orderData = await _db.from('orders').insert({
      'business_id':      businessId,
      'business_name':    businessName,
      'status':           'pending',
      'order_type':       orderType.value,
      'table_id':         tableId,
      'table_number':     tableNumber,
      'customer_name':    customerName,
      'customer_phone':   customerPhone,
      'subtotal':         subtotal,
      'tax_amount':       taxAmount,
      'tax_rate':         taxRate,
      'total_amount':     totalAmount,
      'notes':            notes,
      'created_by_uid':   createdByUid,
      'created_by_name':  createdByName,
      'created_by_role':  createdByRole,
    }).select().single();

    final orderId = orderData['id'] as String;

    // Insert order items
    if (cartItems.isNotEmpty) {
      await _db.from('order_items').insert(
        cartItems.map((c) => {
          'order_id':      orderId,
          'menu_item_id':  c.menuItemId,
          'item_name':     c.itemName,
          'item_price':    c.itemPrice,
          'category_name': c.categoryName,
          'is_veg':        c.isVeg,
          'quantity':      c.quantity,
          'subtotal':      c.subtotal,
          'notes':         c.notes,
        }).toList(),
      );
    }

    // If dine-in, update the table's current order info
    if (tableId != null) {
      await _db.from('restaurant_tables').update({
        'current_order_id':    orderId,
        'current_order_total': totalAmount,
        'current_customer_name': customerName,
        'status':              'occupied',
        'occupied_since':      DateTime.now().toIso8601String(),
      }).eq('id', tableId);
    }

    // Fetch the full order with items
    final full = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();

    return Order.fromJson(full as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════
  //  UPDATE STATUS
  // ══════════════════════════════════════════════════════
  Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String updatedByUid,
    required String updatedByName,
    required String businessId,
  }) async {
    final now = DateTime.now().toIso8601String();

    final updateMap = <String, dynamic>{
      'status':           newStatus.value,
      'updated_by_uid':   updatedByUid,
      'updated_by_name':  updatedByName,
    };

    switch (newStatus) {
      case OrderStatus.preparing:
        updateMap['started_at'] = now;
        break;
      case OrderStatus.ready:
        updateMap['ready_at'] = now;
        break;
      case OrderStatus.completed:
        updateMap['completed_at'] = now;
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

  // ══════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════
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
    List<String>? ids, // null = mark all
  }) async {
    var query = _db
        .from('order_notifications')
        .update({'is_read': true})
        .eq('business_id', businessId);

    if (ids != null) query = query.inFilter('id', ids);

    await query;
  }

  // ══════════════════════════════════════════════════════
  //  REAL-TIME SUBSCRIPTION
  // ══════════════════════════════════════════════════════

  /// Subscribe to order changes for a business.
  /// Returns a [RealtimeChannel] — call `.unsubscribe()` on dispose.
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

              // Fetch full order with items
              final full = await _db
                  .from('vw_orders_with_items')
                  .select()
                  .eq('id', record['id'])
                  .maybeSingle();

              if (full != null) {
                onEvent(Order.fromJson(full as Map<String, dynamic>), payload.eventType.name);
              }
            } catch (e) {
              // ignore realtime errors silently
            }
          },
        )
        .subscribe();
  }

  /// Subscribe to notifications for a business
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

  // ══════════════════════════════════════════════════════
  //  ANALYTICS
  // ══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> fetchRevenueSummary({
    required String businessId,
    required DateTime from,
    required DateTime to,
    String? staffUid,
  }) async {
    final data = await _db.rpc('fn_revenue_summary', params: {
      'p_business_id': businessId,
      'p_from':        from.toIso8601String(),
      'p_to':          to.toIso8601String(),
      'p_staff_uid':   staffUid,
    });

    final row = (data as List).isNotEmpty
        ? data[0] as Map<String, dynamic>
        : <String, dynamic>{};

    return {
      'total_revenue': (row['total_revenue'] as num? ?? 0).toDouble(),
      'total_orders':  (row['total_orders'] as num? ?? 0).toInt(),
      'avg_order':     (row['avg_order'] as num? ?? 0).toDouble(),
      'completed':     (row['completed'] as num? ?? 0).toInt(),
      'cancelled':     (row['cancelled'] as num? ?? 0).toInt(),
    };
  }

  Future<List<Map<String, dynamic>>> fetchEmployeeAnalytics({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _db
        .from('orders')
        .select('created_by_uid, created_by_name, created_by_role, total_amount, table_id, status')
        .eq('business_id', businessId)
        .gte('created_at', from.toIso8601String())
        .lt('created_at', to.toIso8601String());

    // Group by employee in Dart
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final row in (data as List)) {
      final uid = row['created_by_uid'] as String? ?? 'unknown';
      if (!grouped.containsKey(uid)) {
        grouped[uid] = {
          'uid':     uid,
          'name':    row['created_by_name'] ?? 'Unknown',
          'role':    row['created_by_role'] ?? 'staff',
          'orders':  0,
          'revenue': 0.0,
          'tables':  <String?>{},
        };
      }
      grouped[uid]!['orders'] = (grouped[uid]!['orders'] as int) + 1;
      grouped[uid]!['revenue'] = (grouped[uid]!['revenue'] as double) +
          ((row['total_amount'] as num? ?? 0).toDouble());
      (grouped[uid]!['tables'] as Set<String?>).add(row['table_id'] as String?);
    }

    return grouped.values.map((e) => {
      'uid':     e['uid'],
      'name':    e['name'],
      'role':    e['role'],
      'orders':  e['orders'],
      'revenue': e['revenue'],
      'tables':  (e['tables'] as Set<String?>).where((t) => t != null).length,
    }).toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  }
}