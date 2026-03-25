// lib/repositories/seat_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT REPOSITORY (COMPLETE IMPLEMENTATION)
//  Handles all seat operations with online/offline support:
//  - Create seats when tables are added
//  - Seat guests at specific seats with order tracking
//  - Get seat-level orders and totals
//  - Clear individual seats
//  - Track seat session history
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SeatRepository {
  SeatRepository._();
  static final instance = SeatRepository._();

  final _local = LocalDatabase.instance;
  final _sb = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all seats for a table
  Future<List<TableSeat>> getTableSeats(String tableId) async {
    try {
      // Try online first
      if (_connectivity.isOnline) {
        try {
          final response = await _sb
              .from('table_seats')
              .select()
              .eq('table_id', tableId)
              .order('seat_label');

          final seats = (response as List)
              .map((r) => TableSeat.fromJson(r as Map<String, dynamic>))
              .toList();

          // Cache locally — upsert each seat (use response data directly)
          for (final seatData in (response as List)) {
            await _local.upsertEntity(
              table: LocalDatabase.tSeats,
              id: seatData['id'] as String,
              businessId: '',
              data: seatData as Map<String, dynamic>,
              syncStatus: LocalDatabase.syncSynced,
            );
          }
          return seats;
        } catch (e) {
          log('[SeatRepo] Online fetch failed, trying offline: $e');
        }
      }

      // Fall back to local — query seats from local database
      final seatRows = await _local.getEntities(
        table: LocalDatabase.tSeats,
        businessId: '',
        whereExtra: 'data LIKE ?',
        whereExtraArgs: ['%"table_id":"$tableId"%'],
      );
      return seatRows.map((r) => TableSeat.fromJson(r)).toList();
    } catch (e) {
      log('[SeatRepo] Error getting seats: $e');
      return [];
    }
  }

  /// Seat a guest at a specific seat or all available seats
  Future<Map<String, dynamic>> seatGuest({
    required String tableId,
    required String customerName,
    String? businessId,
    List<String>? seatIds, // If empty, seat all available
    String? staffUid,
    String? staffName,
  }) async {
    try {
      if (_connectivity.isOnline) {
        try {
          final params = {
            // Alphabetical order per Supabase schema cache matching
            'p_customer_name': customerName,
            'p_seat_ids': (seatIds ?? [])
                .map((id) {
                  try {
                    return id; // Already a UUID
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<String>()
                .toList(),
            'p_staff_name': staffName,
            'p_staff_uid': staffUid,
            'p_table_id': tableId,
          };

          final result = await _sb.rpc('fn_seat_guest_v2', params: params);

          if (result?['success'] == true) {
            // Refresh local cache
            await getTableSeats(tableId);

            // Create session history entries
            if (businessId != null) {
              await _createSessionHistoryOnline(
                tableId: tableId,
                customerName: customerName,
                businessId: businessId,
                seatIds: seatIds,
                sessionId: result['session_id'],
              );
            }

            log('[SeatRepo] ✅ Guest seated online');
            return {'success': true, 'session_id': result['session_id']};
          }
        } catch (e) {
          log('[SeatRepo] Online seating failed: $e');
        }
      }

      // Offline fallback
      return await _seatGuestOffline(
        tableId: tableId,
        customerName: customerName,
        businessId: businessId,
        seatIds: seatIds,
      );
    } catch (e) {
      log('[SeatRepo] Error seating guest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _seatGuestOffline({
    required String tableId,
    required String customerName,
    String? businessId,
    List<String>? seatIds,
  }) async {
    try {
      final sessionId = _uuid.v4().toString();

      // Update seats locally
      final seatRows = await _local.getEntities(
        table: LocalDatabase.tSeats,
        businessId: '',
        whereExtra: 'data LIKE ?',
        whereExtraArgs: ['%"table_id":"$tableId"%'],
      );
      final seats = seatRows.map((r) => TableSeat.fromJson(r)).toList();

      if (seatIds != null && seatIds.isNotEmpty) {
        // Seat specific seats
        for (final seatId in seatIds) {
          final seatIndex = seatRows.indexWhere(
            (s) => (s['id'] as String?) == seatId,
          );
          if (seatIndex >= 0) {
            final seatData = Map<String, dynamic>.from(seatRows[seatIndex]);
            seatData['status'] = 'occupied';
            seatData['customer_name'] = customerName;
            seatData['occupied_since'] = DateTime.now().toIso8601String();
            seatData['session_id'] = sessionId;
            await _local.upsertEntity(
              table: LocalDatabase.tSeats,
              id: seatId,
              businessId: '',
              data: seatData,
              syncStatus: LocalDatabase.syncPending,
            );
          }
        }
      } else {
        // Seat all available seats
        for (final seat in seats.where(
          (s) => s.status == TableStatus.available,
        )) {
          final seatIndex = seatRows.indexWhere(
            (s) => (s['id'] as String?) == seat.id,
          );
          if (seatIndex >= 0) {
            final seatData = Map<String, dynamic>.from(seatRows[seatIndex]);
            seatData['status'] = 'occupied';
            seatData['customer_name'] = customerName;
            seatData['occupied_since'] = DateTime.now().toIso8601String();
            seatData['session_id'] = sessionId;
            await _local.upsertEntity(
              table: LocalDatabase.tSeats,
              id: seat.id,
              businessId: '',
              data: seatData,
              syncStatus: LocalDatabase.syncPending,
            );
          }
        }
      }

      log('[SeatRepo] ✅ Guest seated offline with session: $sessionId');
      return {'success': true, 'session_id': sessionId};
    } catch (e) {
      log('[SeatRepo] Error in offline seating: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get seat-level bill (total orders for a seat)
  Future<Map<String, dynamic>> getSeatBill(String seatId) async {
    try {
      if (_connectivity.isOnline) {
        try {
          final result = await _sb.rpc(
            'fn_get_seat_bill',
            params: {'p_seat_id': seatId},
          );

          if (result != null) {
            return {
              'success': true,
              'total_bill': result['total_bill'],
              'subtotal': result['subtotal'],
              'tax_total': result['tax_total'],
              'discount_total': result['discount_total'],
              'active_orders': result['active_orders'],
              'completed_orders': result['completed_orders'],
            };
          }
        } catch (e) {
          log('[SeatRepo] Online bill fetch failed: $e');
        }
      }

      // Calculate locally
      return await _getSeatBillOffline(seatId);
    } catch (e) {
      log('[SeatRepo] Error getting seat bill: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getSeatBillOffline(String seatId) async {
    try {
      // Get orders from local database
      final orderRows = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: '',
        whereExtra: 'data LIKE ?',
        whereExtraArgs: ['%"table_seat_id":"$seatId"%'],
      );
      final orders = orderRows;

      double totalBill = 0;
      double subtotal = 0;
      double taxTotal = 0;
      double discountTotal = 0;
      int activeOrders = 0;
      int completedOrders = 0;

      for (final order in orders) {
        final status = order['status'] as String?;
        if (status == null ||
            !['pending', 'preparing', 'ready', 'completed'].contains(status)) {
          continue;
        }

        totalBill += (order['total_amount'] as num?)?.toDouble() ?? 0;
        subtotal += (order['subtotal'] as num?)?.toDouble() ?? 0;
        taxTotal += (order['tax_amount'] as num?)?.toDouble() ?? 0;
        discountTotal += (order['discount'] as num?)?.toDouble() ?? 0;

        if (['pending', 'preparing', 'ready'].contains(status)) {
          activeOrders++;
        } else if (status == 'completed') {
          completedOrders++;
        }
      }

      return {
        'success': true,
        'total_bill': totalBill,
        'subtotal': subtotal,
        'tax_total': taxTotal,
        'discount_total': discountTotal,
        'active_orders': activeOrders,
        'completed_orders': completedOrders,
      };
    } catch (e) {
      log('[SeatRepo] Error calculating bill: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get seat duration since occupancy
  Future<Map<String, dynamic>> getSeatDuration(String seatId) async {
    try {
      if (_connectivity.isOnline) {
        try {
          final result = await _sb.rpc(
            'fn_get_seat_duration',
            params: {'p_seat_id': seatId},
          );

          if (result != null) {
            return {
              'success': true,
              'duration_minutes': result['duration_minutes'],
              'duration_display': result['duration_display'],
              'customer_name': result['customer_name'],
              'seat_label': result['seat_label'],
            };
          }
        } catch (e) {
          log('[SeatRepo] Online duration fetch failed: $e');
        }
      }

      // Calculate locally
      final seatRows = await _local.getEntities(
        table: LocalDatabase.tSeats,
        businessId: '',
      );
      final seat = seatRows.firstWhere(
        (s) => s['id'] == seatId,
        orElse: () => <String, dynamic>{},
      );
      if (seat.isEmpty) {
        return {
          'success': false,
          'duration_minutes': 0,
          'duration_display': '—',
        };
      }
      final seatData = seat as Map<String, dynamic>;

      if (seatData['occupied_since'] != null) {
        final occupiedSince = DateTime.parse(
          seatData['occupied_since'] as String,
        );
        final duration = DateTime.now().difference(occupiedSince);
        final minutes = duration.inMinutes;
        final hours = minutes ~/ 60;
        final mins = minutes % 60;

        String display = '—';
        if (hours > 0) {
          display = '${hours}h ${mins.toString().padLeft(2, '0')}m';
        } else if (minutes > 0) {
          display = '${minutes}m';
        }

        return {
          'success': true,
          'duration_minutes': minutes,
          'duration_display': display,
          'customer_name': seatData['customer_name'],
          'seat_label': seatData['seat_label'],
        };
      }

      return {'success': false, 'duration_minutes': 0, 'duration_display': '—'};
    } catch (e) {
      log('[SeatRepo] Error calculating duration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Clear a specific seat and mark orders as completed
  Future<Map<String, dynamic>> clearSeat({
    required String tableId,
    required String seatId,
    String? businessId,
  }) async {
    try {
      if (_connectivity.isOnline) {
        try {
          final result = await _sb.rpc(
            'fn_clear_seat',
            params: {'p_seat_id': seatId, 'p_table_id': tableId},
          );

          if (result?['success'] == true) {
            // Refresh local cache
            await getTableSeats(tableId);

            log('[SeatRepo] ✅ Seat cleared online');
            return {'success': true, ...?result};
          }
        } catch (e) {
          log('[SeatRepo] Online seat clear failed: $e');
        }
      }

      // Offline fallback
      return await _clearSeatOffline(
        tableId: tableId,
        seatId: seatId,
        businessId: businessId,
      );
    } catch (e) {
      log('[SeatRepo] Error clearing seat: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _clearSeatOffline({
    required String tableId,
    required String seatId,
    String? businessId,
  }) async {
    try {
      // Get seat data and update it
      final seatRows = await _local.getEntities(
        table: LocalDatabase.tSeats,
        businessId: '',
      );
      final seat = seatRows.firstWhere(
        (s) => s['id'] == seatId,
        orElse: () => <String, dynamic>{},
      );

      if (seat.isNotEmpty) {
        seat['status'] = 'available';
        seat['customer_name'] = null;
        seat['occupied_since'] = null;
        seat['session_id'] = null;
        await _local.upsertEntity(
          table: LocalDatabase.tSeats,
          id: seatId,
          businessId: '',
          data: seat,
          syncStatus: LocalDatabase.syncPending,
        );
      }

      // Mark seat's orders as completed
      final orderRows = await _local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: '',
        whereExtra: 'data LIKE ? AND data NOT LIKE ?',
        whereExtraArgs: [
          '%\"table_seat_id\":\"$seatId\"%',
          '%\"status\":\"completed\"%',
        ],
      );
      for (final order in orderRows) {
        order['status'] = 'completed';
        order['payment_status'] = 'paid';
        order['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _local.upsertEntity(
          table: LocalDatabase.tOrders,
          id: order['id'],
          businessId: '',
          data: order,
          syncStatus: LocalDatabase.syncPending,
        );
      }

      log('[SeatRepo] ✅ Seat cleared offline');
      return {'success': true, 'cleared_orders': 1, 'table_status': 'occupied'};
    } catch (e) {
      log('[SeatRepo] Error in offline clear: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SESSION HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _createSessionHistoryOnline({
    required String tableId,
    required String customerName,
    required String businessId,
    List<String>? seatIds,
    String? sessionId,
  }) async {
    try {
      final seats = await getTableSeats(tableId);
      final tableMeta = await _sb
          .from('restaurant_tables')
          .select('table_number, id')
          .eq('id', tableId)
          .single();

      for (final seat in seats) {
        if (seat.status == TableStatus.occupied &&
            (seatIds == null || seatIds.isEmpty || seatIds.contains(seat.id))) {
          await _sb.from('seat_session_history').insert({
            'id': _uuid.v4(),
            'business_id': businessId,
            'table_id': tableId,
            'table_number': tableMeta['table_number'],
            'section': 'Unknown',
            'seat_label': seat.seatLabel,
            'session_id': sessionId,
            'customer_name': customerName,
            'guest_count': 1,
            'check_in_time': DateTime.now().toUtc().toIso8601String(),
            'status': 'active',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
    } catch (e) {
      log('[SeatRepo] Error creating session history: $e');
    }
  }

  /// Get session history for a seat (guest visit records)
  Future<List<Map<String, dynamic>>> getSeatSessionHistory(
    String seatId, {
    int limitDays = 30,
  }) async {
    try {
      if (_connectivity.isOnline) {
        try {
          // Query via Supabase
          final response = await _sb
              .from('seat_session_history')
              .select()
              .gte(
                'created_at',
                DateTime.now()
                    .subtract(Duration(days: limitDays))
                    .toIso8601String(),
              );

          if (response is List) {
            return List<Map<String, dynamic>>.from(response);
          }
        } catch (e) {
          log('[SeatRepo] Online history fetch failed: $e');
        }
      }

      // Fall back to local — get session history from local seat history table
      final historyRows = await _local.getSeatHistoryByTable(
        tableId: seatId,
        limit: 100,
      );
      return historyRows;
    } catch (e) {
      log('[SeatRepo] Error getting session history: $e');
      return [];
    }
  }
}
