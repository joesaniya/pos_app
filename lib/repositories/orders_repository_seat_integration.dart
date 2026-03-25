// lib/repositories/orders_repository_seat_updates.dart
// ══════════════════════════════════════════════════════════════════════════════
//  ORDERS REPOSITORY - SEAT-LEVEL UPDATES
//  ⚠️ INTEGRATE THESE METHODS INTO existing orders_repository.dart
//  Adds seat-level order creation, filtering, and tracking
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/repositories/seat_repository.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/*
ADD THESE METHODS TO lib/repositories/orders_repository.dart:
*/

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT-LEVEL ORDER CREATION
// ══════════════════════════════════════════════════════════════════════════════

// NOTE: These methods reference private members that exist in OrdersRepository:
// - _uuid (const Uuid())
// - _local (LocalDatabase.instance)
// - _connectivity (ConnectivityService.instance)
// - _sb (Supabase.instance.client)
// - _getNextLocalOrderNumber(businessId) - existing private method
// - _seatRepo (SeatRepository.instance)

/// Create an order for a specific seat (walk-in seat assignment)
Future<Map<String, dynamic>> createSeatOrder({
  required String tableId,
  required String seatId,
  required String businessId,
  required String createdByUid,
  required String createdByName,
  Map<String, dynamic>? items,
  String? notes,
  String? discountCode,
  double discount = 0,
  /* requires: _uuid, _local, _connectivity, _sb, _getNextLocalOrderNumber */
}) async {
  // NOTE: This is example code - add to OrdersRepository class
  // try {
  //   final _uuid = const Uuid();
  //   final _local = LocalDatabase.instance;
  //   final _connectivity = ConnectivityService.instance;
  //   final _sb = Supabase.instance.client;
  //
  //   final orderId = _uuid.v4();
  //   final orderData = {
  //     'id': orderId,
  //     'business_id': businessId,
  //     'table_id': tableId,
  //     'table_seat_id': seatId,
  //     'order_number': await _getNextLocalOrderNumber(businessId),
  //     'status': 'pending',
  //     'payment_status': 'unpaid',
  //     'subtotal': 0,
  //     'tax_amount': 0,
  //     'discount': discount,
  //     'discount_code': discountCode,
  //     'total_amount': 0,
  //     'created_by_uid': createdByUid,
  //     'created_by_name': createdByName,
  //     'notes': notes,
  //     'created_at': DateTime.now().toUtc().toIso8601String(),
  //     'updated_at': DateTime.now().toUtc().toIso8601String(),
  //   };
  //
  //   // Save locally first
  //   await _local.upsertEntity(
  //     table: LocalDatabase.tOrders,
  //     id: orderId,
  //     businessId: businessId,
  //     data: orderData,
  //     syncStatus: LocalDatabase.syncPending,
  //     action: LocalDatabase.actionCreate,
  //   );
  //
  //   // Try sync if online
  //   if (_connectivity.isOnline) {
  //     try {
  //       await _sb.from('orders').insert(orderData);
  //       await _local.upsertEntity(
  //         table: LocalDatabase.tOrders,
  //         id: orderId,
  //         businessId: businessId,
  //         data: orderData,
  //         syncStatus: LocalDatabase.syncSynced,
  //         action: LocalDatabase.actionCreate,
  //       );
  //       log('[OrdersRepo] ✅ Seat order created and synced');
  //     } catch (e) {
  //       log('[OrdersRepo] Online sync failed, queued for later: $e');
  //     }
  //   }
  //
  //   return {
  //     'success': true,
  //     'order_id': orderId,
  //     'message': 'Order created for seat',
  //   };
  // } catch (e) {
  //   log('[OrdersRepo] Error creating seat order: $e');
  //   return {'success': false, 'error': e.toString()};
  // }
  return {'success': false, 'error': 'Method stub - add to OrdersRepository'};
}

// ══════════════════════════════════════════════════════════════════════════════
//  GET SEAT-LEVEL ORDERS
// ══════════════════════════════════════════════════════════════════════════════

/// Get all active orders for a specific seat
/// NOTE: Add this method to OrdersRepository class
/// Requires: _connectivity, _sb, _local
Future<List<Map<String, dynamic>>> getSeatOrders(
  String seatId, {
  bool activeOnly = true,
  /* requires: _connectivity, _sb, _local */
}) async {
  // return []; // Implementation:
  // if (_connectivity.isOnline) {
  //   try {
  //     var query = _sb.from('orders').select().eq('table_seat_id', seatId);
  //     if (activeOnly) {
  //       query = query.inFilter('status', ['pending', 'preparing', 'ready']);
  //     }
  //     final response = await query.order('created_at', ascending: false);
  //     if (response is List) {
  //       return List<Map<String, dynamic>>.from(response);
  //     }
  //   } catch (e) {
  //     log('[OrdersRepo] Online seat order fetch failed: $e');
  //   }
  // }
  // return await _local.getOrders(
  //   whereExtra: 'table_seat_id = ? ${activeOnly ? 'AND status IN (?, ?, ?)' : ''}',
  //   whereExtraArgs: activeOnly ? [seatId, 'pending', 'preparing', 'ready'] : [seatId],
  // );
  return [];
}

/// Get complete order items for a seat
/// NOTE: Add this method to OrdersRepository class
/// Requires: getSeatOrders(), _connectivity, _sb, _local
Future<List<Map<String, dynamic>>> getSeatOrderItems(String seatId) async {
  // return []; // Implementation:
  // final orders = await getSeatOrders(seatId);
  // final orderIds = orders.map((o) => o['id']).toList();
  // if (orderIds.isEmpty) return [];
  // if (_connectivity.isOnline) {
  //   try {
  //     final response = await _sb
  //         .from('order_items')
  //         .select('*')
  //         .inFilter('order_id', orderIds);
  //     if (response is List) {
  //       return List<Map<String, dynamic>>.from(response);
  //     }
  //   } catch (e) {
  //     log('[OrdersRepo] Online item fetch failed: $e');
  //   }
  // }
  // return await _local.getOrderItems(orderIds);
  return [];
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPLETE SEAT ORDERS
// ══════════════════════════════════════════════════════════════════════════════

/// Complete all orders for a seat and mark seat as cleared
/// NOTE: Add this method to OrdersRepository class
/// Requires: getSeatOrders(), _connectivity, _sb, updateOrder
Future<Map<String, dynamic>> completeSeatOrders({
  required String seatId,
  required String tableId,
  required String paymentMethod,
  double? paidAmount,
}) async {
  // Implementation:
  // try {
  //   final now = DateTime.now().toUtc();
  //   var completedCount = 0;
  //   final orders = await getSeatOrders(seatId, activeOnly: true);
  //   for (final order in orders) {
  //     final orderId = order['id'];
  //     await updateOrder(
  //       orderId: orderId,
  //       updates: {
  //         'status': 'completed',
  //         'payment_status': 'paid',
  //         'payment_method': paymentMethod,
  //         'completed_at': now.toIso8601String(),
  //       },
  //     );
  //     completedCount++;
  //   }
  //   if (_connectivity.isOnline) {
  //     try {
  //       await _sb.rpc('fn_clear_seat', params: {'p_table_id': tableId, 'p_seat_id': seatId});
  //     } catch (e) {
  //       log('[OrdersRepo] Seat clear RPC failed: $e');
  //     }
  //   }
  //   log('[OrdersRepo] ✅ Completed $completedCount orders for seat');
  //   return {'success': true, 'completed_orders': completedCount, 'message': 'Seat orders completed'};
  // } catch (e) {
  //   log('[OrdersRepo] Error completing seat orders: $e');
  //   return {'success': false, 'error': e.toString()};
  // }
  return {'success': false, 'error': 'Method stub - add to OrdersRepository'};
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT ORDER SUMMARY
// ══════════════════════════════════════════════════════════════════════════════

/// Get comprehensive summary for a seat (bill, duration, items)
/// NOTE: Add this method to OrdersRepository class
/// Requires: _seatRepo
Future<Map<String, dynamic>> getSeatSummary(String seatId) async {
  // Implementation:
  // try {
  //   final durationResult = await _seatRepo.getSeatDuration(seatId);
  //   final billResult = await _seatRepo.getSeatBill(seatId);
  //   final items = await getSeatOrderItems(seatId);
  //   return {
  //     'success': true,
  //     'seat_info': durationResult,
  //     'bill': billResult,
  //     'items_count': items.length,
  //     'items': items,
  //   };
  // } catch (e) {
  //   log('[OrdersRepo] Error getting seat summary: $e');
  //   return {'success': false, 'error': e.toString()};
  // }
  return {'success': false, 'error': 'Method stub - add to OrdersRepository'};
}

// ══════════════════════════════════════════════════════════════════════════════
//  OFFLINE SEAT ORDER SUPPORT
// ══════════════════════════════════════════════════════════════════════════════

/// Sync pending seat orders to Supabase when coming online
/// NOTE: Add this method to OrdersRepository class
/// Requires: _connectivity, _local, _sb
Future<void> syncPendingSeatOrders(String businessId) async {
  // Implementation:
  // try {
  //   if (!_connectivity.isOnline) return;
  //   final pendingOrders = await _local.getOrders(
  //     businessId: businessId,
  //     whereExtra: 'table_seat_id IS NOT NULL AND _sync_status = ?',
  //     whereExtraArgs: [LocalDatabase.syncPending],
  //   );
  //   for (final order in pendingOrders) {
  //     try {
  //       await _sb.from('orders').insert(order);
  //       await _local.upsertEntity(
  //         table: LocalDatabase.tOrders,
  //         id: order['id'],
  //         businessId: businessId,
  //         data: order,
  //         syncStatus: LocalDatabase.syncSynced,
  //         action: LocalDatabase.actionCreate,
  //       );
  //       log('[OrdersRepo] ✅ Synced seat order');
  //     } catch (e) {
  //       log('[OrdersRepo] Failed to sync order: $e');
  //     }
  //   }
  // } catch (e) {
  //   log('[OrdersRepo] Error syncing pending seat orders: $e');
  // }
}

/// Clear local seat orders after successful payment/checkout
/// NOTE: Add this method to OrdersRepository class
/// Requires: _local
Future<void> clearSeatOrdersLocally({
  required String seatId,
  required String businessId,
}) async {
  // Implementation:
  // try {
  //   await _local.updateOrders(
  //     where: 'table_seat_id = ?',
  //     whereArgs: [seatId],
  //     updates: {
  //       'status': 'completed',
  //       'payment_status': 'paid',
  //       'updated_at': DateTime.now().toUtc().toIso8601String(),
  //     },
  //   );
  //   log('[OrdersRepo] ✅ Cleared seat orders locally');
  // } catch (e) {
  //   log('[OrdersRepo] Error clearing seat orders: $e');
  // }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INTEGRATION NOTES
// ══════════════════════════════════════════════════════════════════════════════

/*
INSTRUCTIONS FOR INTEGRATION:

1. Add a reference to SeatRepository at the top:
   final _seatRepo = SeatRepository.instance;

2. Add these methods to the OrdersRepository class

3. Update createOrder() to support seat-level creation:
   if (tableData?['seatId'] != null) {
     return await createSeatOrder(...);
   }

4. Update getTableOrders() to filter by session:
   - Get session_id from restaurant_tables
   - Filter orders by session_id if provided

5. When clearing a seat, use completeSeatOrders() instead of clearTableOrdersLocally()

6. Ensure offline sync handles seat-level orders separately

7. Test workflow:
   - Create table with capacity 4 → 4 seats auto-created
   - Seat guest at seat A
   - Create order for seat A
   - View bill for seat A
   - Pay and clear seat A
   - Verify other seats unaffected
*/
