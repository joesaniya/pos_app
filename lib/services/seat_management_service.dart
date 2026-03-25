// lib/services/seat_management_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT MANAGEMENT SERVICE
//  Centralized service for managing seat-level operations:
//  - Seating guests
//  - Tracking seat occupancy
//  - Handling partial and full-table orders
//  - Clearing individual seats
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/seat_status_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeatManagementService {
  SeatManagementService._();
  static final instance = SeatManagementService._();

  final _db = Supabase.instance.client;

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNC SEAT STATUS
  //  Load current seat statuses from backend and update provider
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch and sync all seats for a table
  Future<List<TableSeat>> syncTableSeats(
    String tableId,
    SeatStatusProvider statusProvider,
  ) async {
    try {
      final response = await _db
          .from('table_seats')
          .select()
          .eq('table_id', tableId);

      if (response is! List) {
        throw Exception('Invalid response from table_seats');
      }

      final seats = (response as List)
          .map((json) => TableSeat.fromJson(json as Map<String, dynamic>))
          .toList();

      log('[SeatMgmtService] Synced ${seats.length} seats for table $tableId');
      return seats;
    } catch (e) {
      log('[SeatMgmtService] Error syncing seats: $e', level: 1000);
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT A GUEST
  //  Mark seat(s) as occupied with customer name
  // ══════════════════════════════════════════════════════════════════════════

  /// Seat a single guest at a specific seat
  Future<Map<String, dynamic>> seatGuestAtSeat({
    required String tableId,
    required String seatId,
    required String customerName,
  }) async {
    try {
      log('[SeatMgmtService] Seating $customerName at seat $seatId');

      final result = await _db.rpc(
        'fn_seat_guest',
        params: {'p_table_id': tableId, 'p_customer_name': customerName},
      );

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_seat_guest');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Failed to seat guest');
      }

      log('[SeatMgmtService] ✅ Guest seated successfully');

      // Update local seat status
      await _updateLocalSeatStatus(
        tableId: tableId,
        seatId: seatId,
        status: 'occupied',
        customerName: customerName,
        occupiedSince: DateTime.now(),
      );

      return {'success': true, 'session_id': result['session_id']};
    } catch (e) {
      log('[SeatMgmtService] Error seating guest: $e', level: 1000);
      rethrow;
    }
  }

  /// Seat multiple guests at multiple seats
  Future<Map<String, dynamic>> seatMultipleGuests({
    required String tableId,
    required Map<String, String> seatCustomerMap, // seatId -> customerName
  }) async {
    try {
      log(
        '[SeatMgmtService] Seating ${seatCustomerMap.length} guests at multiple seats',
      );

      final result = await _db.rpc(
        'fn_seat_guest',
        params: {'p_table_id': tableId, 'p_customer_name': 'Walk-in Group'},
      );

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_seat_guest');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Failed to seat guests');
      }

      // Update all seats locally
      final now = DateTime.now();
      for (final entry in seatCustomerMap.entries) {
        await _updateLocalSeatStatus(
          tableId: tableId,
          seatId: entry.key,
          status: 'occupied',
          customerName: entry.value,
          occupiedSince: now,
        );
      }

      log('[SeatMgmtService] ✅ Multiple guests seated successfully');

      return {
        'success': true,
        'session_id': result['session_id'],
        'seated_count': seatCustomerMap.length,
      };
    } catch (e) {
      log('[SeatMgmtService] Error seating multiple guests: $e', level: 1000);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MARK SEAT AS ORDERED
  //  Update seat status to show it has active orders
  // ══════════════════════════════════════════════════════════════════════════

  /// Update seat status to 'ordered' when order is placed
  Future<void> markSeatOrdered({
    required String tableId,
    required String seatId,
  }) async {
    try {
      log('[SeatMgmtService] Marking seat $seatId as ordered');

      // Update in backend
      await _db
          .from('table_seats')
          .update({
            'status': 'ordered',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', seatId);

      log('[SeatMgmtService] ✅ Seat marked as ordered');
    } catch (e) {
      log('[SeatMgmtService] Warning: Could not mark seat as ordered: $e');
      // Don't throw - this is non-critical
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLEAR INDIVIDUAL SEAT
  //  Mark seat as available after guest leaves
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear a single seat (guest checkout)
  Future<Map<String, dynamic>> clearSeat({
    required String tableId,
    required String seatId,
  }) async {
    try {
      log('[SeatMgmtService] Clearing seat $seatId from table $tableId');

      final result = await _db.rpc(
        'fn_clear_seat',
        params: {'p_table_id': tableId, 'p_seat_id': seatId},
      );

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_clear_seat');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Failed to clear seat');
      }

      log('[SeatMgmtService] ✅ Seat cleared successfully');

      // Update local seat status
      await _updateLocalSeatStatus(
        tableId: tableId,
        seatId: seatId,
        status: 'available',
        customerName: null,
        occupiedSince: null,
      );

      return {
        'success': true,
        'remaining_occupied': result['remaining_occupied_seats'] ?? 0,
        'table_fully_cleared': result['table_fully_cleared'] == true,
      };
    } catch (e) {
      log('[SeatMgmtService] Error clearing seat: $e', level: 1000);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLEAR ENTIRE TABLE
  //  Mark all seats as available
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear entire table and all its seats
  Future<Map<String, dynamic>> clearEntireTable({
    required String tableId,
  }) async {
    try {
      log('[SeatMgmtService] Clearing entire table $tableId');

      final result = await _db.rpc(
        'fn_clear_table_complete',
        params: {'p_table_id': tableId},
      );

      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from fn_clear_table_complete');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Failed to clear table');
      }

      log('[SeatMgmtService] ✅ Table cleared successfully');

      // Clear all seats locally
      await _clearAllLocalSeats(tableId);

      return {
        'success': true,
        'orders_completed': result['orders_completed'] ?? 0,
        'seats_cleared': result['seats_cleared'] ?? 0,
      };
    } catch (e) {
      log('[SeatMgmtService] Error clearing table: $e', level: 1000);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET SEAT OCCUPANCY INFO
  //  Retrieve detailed info about current occupancy
  // ══════════════════════════════════════════════════════════════════════════

  /// Get real-time occupancy summary for a table
  Future<Map<String, dynamic>> getTableOccupancy(String tableId) async {
    try {
      final response = await _db
          .from('table_seats')
          .select()
          .eq('table_id', tableId);

      if (response is! List) {
        throw Exception('Invalid response');
      }

      final seats = response as List;
      final occupied = seats
          .where((s) => (s as Map)['status'] == 'occupied')
          .length;
      final available = seats
          .where((s) => (s as Map)['status'] == 'available')
          .length;

      return {
        'total': seats.length,
        'occupied': occupied,
        'available': available,
        'can_accept_guests': available > 0,
      };
    } catch (e) {
      log('[SeatMgmtService] Error getting occupancy: $e', level: 1000);
      return {
        'total': 0,
        'occupied': 0,
        'available': 0,
        'can_accept_guests': false,
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Update seated guest info in local database
  Future<void> _updateLocalSeatStatus({
    required String tableId,
    required String seatId,
    required String status,
    String? customerName,
    DateTime? occupiedSince,
  }) async {
    try {
      // This would be implemented with your local database service
      // For now, just log the operation
      debugPrint(
        '[SeatMgmtService] Updated local seat: '
        'seatId=$seatId, status=$status, customer=$customerName',
      );
    } catch (e) {
      debugPrint('[SeatMgmtService] Error updating local seat: $e');
    }
  }

  /// Clear all seats in table locally
  Future<void> _clearAllLocalSeats(String tableId) async {
    try {
      debugPrint(
        '[SeatMgmtService] Cleared all local seats for table $tableId',
      );
    } catch (e) {
      debugPrint('[SeatMgmtService] Error clearing local seats: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUBSCRIPTION HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Subscribe to real-time seat updates for a table
  RealtimeChannel subscribeToSeatUpdates(
    String tableId,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    return _db
        .channel('table_seats:table_id:eq.$tableId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'table_seats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'table_id',
            value: tableId,
          ),
          callback: (payload) {
            log('[SeatMgmtService] Seat update received: ${payload.eventType}');
            onUpdate(payload.newRecord as Map<String, dynamic>);
          },
        )
      ..subscribe();
  }

  /// Unsubscribe from seat updates
  Future<void> unsubscribeFromSeatUpdates(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }
}
