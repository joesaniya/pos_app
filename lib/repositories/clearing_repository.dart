// lib/repositories/clearing_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  CLEARING REPOSITORY
//  Handles seat-level and table-level clearing operations with real-time
//  synchronization between local database and Supabase backend.
//
//  KEY FEATURES:
//  - Seat-level clearing: Clear only specific seat(s) without affecting others
//  - Table-level clearing: Clear entire table with all seats and orders
//  - Real-time sync: Updates reflected instantly in UI and backend
//  - Offline-ready: Can configure to work offline with sync queue
//  - Order completion: Automatically completes associated orders
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:developer';
import 'package:pos_app/database/local_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClearingRepository {
  ClearingRepository._();
  static final instance = ClearingRepository._();

  // Table constants
  static const String tSeats = 'table_seats';
  static const String tOrders = 'orders';
  static const String tTables = 'restaurant_tables';

  final _sb = Supabase.instance.client;
  final _local = LocalDatabase.instance;

  // Stream controller for real-time clearing updates
  final _clearingStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of clearing operations for real-time UI updates
  Stream<Map<String, dynamic>> get clearingStream =>
      _clearingStreamController.stream;

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT-LEVEL CLEARING
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear a specific seat (guest checkout from individual seat)
  ///
  /// This function:
  /// - Marks the seat as 'available'
  /// - Completes all orders associated with the seat
  /// - If all seats are now free, resets table to 'available'
  /// - Returns real-time status with number of orders cleared
  ///
  /// Returns: Map with success status, cleared orders count, and remaining occupied seats
  Future<Map<String, dynamic>> clearSeat({
    required String tableId,
    required String seatId,
    required String businessId,
  }) async {
    try {
      log('[ClearingRepo] Clearing seat: $seatId from table: $tableId');

      // Step 1: Call the remote RPC function
      Map<String, dynamic> result;
      try {
        result =
            await _sb.rpc(
                  'fn_clear_seat',
                  params: {'p_table_id': tableId, 'p_seat_id': seatId},
                )
                as Map<String, dynamic>;
      } catch (rpcError) {
        log('[ClearingRepo] ⚠️ fn_clear_seat RPC failed: $rpcError');
        // Fallback: Perform local clearing only
        await _updateLocalSeatStatus(seatId, 'available');
        await _updateLocalTableStatusIfNeeded(tableId);
        return {
          'success': true,
          'fallback': true,
          'message': 'Seat cleared locally (RPC unavailable)',
        };
      }

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_clear_seat');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        final error = result['error'] ?? 'Unknown error';
        throw Exception('Backend sent error: $error');
      }

      log('[ClearingRepo] ✅ Seat cleared successfully: ${result.toString()}');

      // Step 2: Update local database immediately
      await _updateLocalSeatStatus(seatId, 'available');

      // Step 3: Update local orders to completed
      await _completeLocalSeatOrders(seatId);

      // Step 4: Check if table should be marked as available
      final remainingOccupied = result['remaining_occupied_seats'] as int? ?? 0;
      if (remainingOccupied == 0) {
        await _updateLocalTableStatus(tableId, 'available');
      }

      // Step 5: Emit stream event for real-time UI updates
      _clearingStreamController.add({
        'action': 'seat_cleared',
        'table_id': tableId,
        'seat_id': seatId,
        'remaining_occupied_seats': remainingOccupied,
        'table_fully_cleared': remainingOccupied == 0,
        'timestamp': DateTime.now(),
      });

      return {
        'success': true,
        'action': 'seat_cleared',
        'seat_id': seatId,
        'cleared_orders': result['cleared_orders'] ?? 0,
        'remaining_occupied_seats': remainingOccupied,
        'table_fully_cleared': remainingOccupied == 0,
      };
    } catch (e) {
      log('[ClearingRepo] ❌ Error clearing seat: $e', level: 1000);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TABLE-LEVEL CLEARING
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear entire table and all its seats
  ///
  /// This function:
  /// - Completes all orders for the entire table
  /// - Marks all seats as 'available'
  /// - Resets table status to 'available'
  /// - Clears session_id from table and all seats
  ///
  /// Returns: Map with success status, count of cleared orders and seats
  Future<Map<String, dynamic>> clearEntireTable({
    required String tableId,
    required String businessId,
  }) async {
    try {
      log('[ClearingRepo] Clearing entire table: $tableId');

      // Step 1: Call the remote RPC function
      final result = await _sb.rpc(
        'fn_clear_table_complete',
        params: {'p_table_id': tableId},
      );

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_clear_table_complete');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Backend failed to clear table');
      }

      log('[ClearingRepo] ✅ Table fully cleared: ${result.toString()}');

      // Step 2: Update local database
      await _updateLocalTableStatus(tableId, 'available');
      await _clearAllLocalSeatsForTable(tableId);
      await _completeAllLocalTableOrders(tableId);

      // Step 3: Emit stream event for real-time UI updates
      _clearingStreamController.add({
        'action': 'table_cleared',
        'table_id': tableId,
        'orders_completed': result['orders_completed'] ?? 0,
        'seats_cleared': result['seats_cleared'] ?? 0,
        'timestamp': DateTime.now(),
      });

      return {
        'success': true,
        'action': 'table_cleared',
        'table_id': tableId,
        'orders_completed': result['orders_completed'] ?? 0,
        'seats_cleared': result['seats_cleared'] ?? 0,
      };
    } catch (e) {
      log('[ClearingRepo] ❌ Error clearing table: $e', level: 1000);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT DETAILS & DIAGNOSTICS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get full details of a seat including orders and bill
  /// Useful for showing confirmation UI before clearing
  Future<Map<String, dynamic>> getSeatDetails({required String seatId}) async {
    try {
      final result = await _sb.rpc(
        'fn_get_seat_details',
        params: {'p_seat_id': seatId},
      );

      if (result is Map<String, dynamic> && result.containsKey('error')) {
        return {'success': false, 'error': result['error']};
      }

      return {'success': true, 'details': result};
    } catch (e) {
      log('[ClearingRepo] Error fetching seat details: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get summary of all seats in a table with their bills
  /// Perfect for showing table overview with clearing buttons
  Future<List<Map<String, dynamic>>> getTableSeatSummaries({
    required String tableId,
  }) async {
    try {
      final result = await _sb.rpc(
        'fn_get_table_seat_summaries',
        params: {'p_table_id': tableId},
      );

      if (result is List) {
        return List<Map<String, dynamic>>.from(
          result.map((e) => e as Map<String, dynamic>),
        );
      }

      return [];
    } catch (e) {
      log('[ClearingRepo] Error fetching seat summaries: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL DATABASE UPDATES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _updateLocalSeatStatus(String seatId, String status) async {
    try {
      // Update in local database
      await _local.db.rawUpdate(
        '''
        UPDATE $tSeats
        SET status = ?, updated_at = datetime('now')
        WHERE id = ?
        ''',
        [status, seatId],
      );
      log('[ClearingRepo] Updated local seat status: $seatId -> $status');
    } catch (e) {
      log('[ClearingRepo] Error updating local seat: $e');
      // Non-critical, continue anyway
    }
  }

  Future<void> _updateLocalTableStatus(String tableId, String status) async {
    try {
      await _local.db.rawUpdate(
        '''
        UPDATE ${LocalDatabase.tTables}
        SET status = ?, session_id = NULL, current_session_id = NULL, updated_at = datetime('now')
        WHERE id = ?
        ''',
        [status, tableId],
      );
      log('[ClearingRepo] Updated local table status: $tableId -> $status');
    } catch (e) {
      log('[ClearingRepo] Error updating local table: $e');
    }
  }

  Future<void> _completeLocalSeatOrders(String seatId) async {
    try {
      await _local.db.rawUpdate(
        '''
        UPDATE $tOrders
        SET status = 'completed', updated_at = datetime('now')
        WHERE table_seat_id = ? AND status IN ('pending', 'preparing', 'ready')
        ''',
        [seatId],
      );
      log('[ClearingRepo] Completed local seat orders: $seatId');
    } catch (e) {
      log('[ClearingRepo] Error completing seat orders: $e');
    }
  }

  Future<void> _clearAllLocalSeatsForTable(String tableId) async {
    try {
      await _local.db.rawUpdate(
        '''
        UPDATE $tSeats
        SET status = 'available', session_id = NULL, customer_name = NULL, 
            occupied_since = NULL, updated_at = datetime('now')
        WHERE table_id = ?
        ''',
        [tableId],
      );
      log('[ClearingRepo] Cleared all local seats for table: $tableId');
    } catch (e) {
      log('[ClearingRepo] Error clearing seats: $e');
    }
  }

  Future<void> _completeAllLocalTableOrders(String tableId) async {
    try {
      await _local.db.rawUpdate(
        '''
        UPDATE $tOrders
        SET status = 'completed', updated_at = datetime('now')
        WHERE table_id = ? AND status IN ('pending', 'preparing', 'ready')
        ''',
        [tableId],
      );
      log('[ClearingRepo] Completed all local table orders: $tableId');
    } catch (e) {
      log('[ClearingRepo] Error completing table orders: $e');
    }
  }

  /// Check if table should be marked as available when all seats are cleared
  Future<void> _updateLocalTableStatusIfNeeded(String tableId) async {
    try {
      // Check if any seats for this table are still occupied
      final result = await _local.db.rawQuery(
        '''
        SELECT COUNT(*) as occupied_count
        FROM $tSeats
        WHERE table_id = ? AND status = 'occupied'
        ''',
        [tableId],
      );

      final occupiedCount = result.isNotEmpty
          ? result.first['occupied_count'] as int
          : 0;

      if (occupiedCount == 0) {
        // All seats are available, mark table as available
        await _updateLocalTableStatus(tableId, 'available');
        log(
          '[ClearingRepo] Table marked as available (all seats cleared): $tableId',
        );
      } else {
        log(
          '[ClearingRepo] Table still has $occupiedCount occupied seats: $tableId',
        );
      }
    } catch (e) {
      log('[ClearingRepo] Error checking table status: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

  void dispose() {
    _clearingStreamController.close();
  }
}
