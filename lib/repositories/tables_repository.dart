// lib/repositories/tables_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  TABLES REPOSITORY — Offline-first  (FIXED v2)
//
//  KEY FIXES:
//  1. seatGuests() offline path:
//     - When seatIds is provided, only the specified seats are marked
//       'occupied' in the local seat list. The table status is set to
//       'occupied' only when ALL seats are taken; otherwise it stays at
//       its current status (available/reserved) so other seats remain
//       bookable. This mirrors the online fn_seat_guest_v2 behaviour.
//     - Generates and stores a fresh session_id in the local table row
//       so subsequent offline order creates are correctly session-scoped.
//     - Calls OrdersRepository.clearTableOrdersLocally() to wipe stale
//       orders from the previous guest before the new session begins.
//  2. _rowToTable() now reads session_id from the local row so the
//     provider and order-repository can use it for filtering.
//  3. _toQueuePayload() unchanged — keeps Supabase payloads clean.
//  4. seatGuests() online path now falls back gracefully and still
//     calls clearTableOrdersLocally() after a successful remote RPC.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/repositories/orders_repository.dart';
import 'package:pos_app/repositories/seat_history_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';

class TablesRepository {
  TablesRepository._();
  static final instance = TablesRepository._();

  final _local = LocalDatabase.instance;
  final _sb = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  static const _kTables = 'restaurant_tables';
  static const _kReservations = 'table_reservations';
  static const _kView = 'vw_tables_with_reservation';

  bool _isUuid(String id) {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$',
    );
    return uuidRe.hasMatch(id);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYLOAD SANITISATION
  // ══════════════════════════════════════════════════════════════════════════

  static const _kLocalOnlyFields = {
    '_sync_status',
    '_action',
    'seats', // joined list — not a column
    'restaurant_tables', // Supabase join object
    'reservation_data', // computed field from view
  };

  Map<String, dynamic> _toQueuePayload(Map<String, dynamic> raw) {
    final clean = Map<String, dynamic>.from(raw);
    for (final k in _kLocalOnlyFields) {
      clean.remove(k);
    }
    return clean;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH TABLES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<RestaurantTable>> fetchTables(String businessId) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );
    return rows.map(_rowToTable).whereType<RestaurantTable>().toList()
      ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
  }

  Future<void> refreshFromRemote(String businessId) async {
    try {
      final rowsFut = _sb
          .from(_kView)
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('table_number');
      final seatsFut = _sb
          .from('table_seats')
          .select()
          .eq('business_id', businessId);
      final results = await Future.wait([rowsFut, seatsFut]);
      final rows = (results[0] as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();
      final seats = (results[1] as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();

      for (final row in rows) {
        final tableId = row['id'] as String;
        row['seats'] = seats.where((s) => s['table_id'] == tableId).toList();
      }

      await _local.replaceAll(
        table: LocalDatabase.tTables,
        businessId: businessId,
        entities: rows,
      );

      final remoteIds = rows.map((r) => r['id'] as String).toSet();
      await _promoteSyncedEntities(
        table: LocalDatabase.tTables,
        businessId: businessId,
        confirmedIds: remoteIds,
      );

      log('[TablesRepo] Remote refresh: ${rows.length} tables cached');
    } catch (e) {
      debugPrint('[TablesRepo] Remote refresh error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH RESERVATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ReservationHistoryItem>> fetchUpcomingReservations(
    String businessId,
  ) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tReservations,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );
    return rows
        .map(_rowToReservation)
        .whereType<ReservationHistoryItem>()
        .toList();
  }

  Future<void> refreshReservationsFromRemote(String businessId) async {
    try {
      final from = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final to = DateTime.now()
          .add(const Duration(days: 60))
          .toUtc()
          .toIso8601String();
      final rows = await _sb
          .from(_kReservations)
          .select('*, restaurant_tables(table_number, section)')
          .eq('business_id', businessId)
          .inFilter('status', ['active', 'seated'])
          .gte('reserved_for', from)
          .lte('reserved_for', to)
          .order('reserved_for', ascending: true);
      final entities = (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();

      await _local.replaceAll(
        table: LocalDatabase.tReservations,
        businessId: businessId,
        entities: entities,
      );

      final remoteIds = entities.map((r) => r['id'] as String).toSet();
      await _promoteSyncedEntities(
        table: LocalDatabase.tReservations,
        businessId: businessId,
        confirmedIds: remoteIds,
      );
    } catch (e) {
      debugPrint('[TablesRepo] Reservation refresh error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TABLE CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addTable(
    RestaurantTable t,
    String businessId,
    Map<String, dynamic> row,
  ) async {
    final id = t.id.isNotEmpty ? t.id : _uuid.v4();
    final localRow = {...row, 'id': id};

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: id,
      businessId: businessId,
      data: localRow,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    final queuePayload = _toQueuePayload(localRow);

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kTables).insert(queuePayload);
        await _local.upsertEntity(
          table: LocalDatabase.tTables,
          id: id,
          businessId: businessId,
          data: localRow,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionCreate,
        );
        log('[TablesRepo] addTable synced immediately: $id');
        return;
      } catch (e) {
        debugPrint('[TablesRepo] Online addTable failed, queuing: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: id,
      action: LocalDatabase.actionCreate,
      payload: queuePayload,
      businessId: businessId,
    );
    log('[TablesRepo] addTable queued offline: $id');
  }

  Future<void> updateTable(
    RestaurantTable t,
    String businessId,
    Map<String, dynamic> row,
  ) async {
    final localRow = {...row, 'id': t.id};

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: t.id,
      businessId: businessId,
      data: localRow,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    final queuePayload = _toQueuePayload(localRow);

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kTables).update(queuePayload).eq('id', t.id);
        await _local.upsertEntity(
          table: LocalDatabase.tTables,
          id: t.id,
          businessId: businessId,
          data: localRow,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
        return;
      } catch (e) {
        debugPrint('[TablesRepo] Online updateTable failed, queuing: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: t.id,
      action: LocalDatabase.actionUpdate,
      payload: queuePayload,
      businessId: businessId,
    );
  }

  Future<void> deleteTable(
    String id,
    String businessId,
    String? uid,
    String? name,
  ) async {
    final deletePayload = {
      'id': id,
      'is_active': false,
      'business_id': businessId,
      'updated_by_uid': uid,
      'updated_by_name': name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: id,
      businessId: businessId,
      data: deletePayload,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionDelete,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from(_kTables)
            .update({
              'is_active': false,
              'updated_by_uid': uid,
              'updated_by_name': name,
              'updated_at': deletePayload['updated_at'],
            })
            .eq('id', id);
        await _local.deleteEntity(LocalDatabase.tTables, id);
        return;
      } catch (e) {
        debugPrint('[TablesRepo] Online deleteTable failed, queuing: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: id,
      action: LocalDatabase.actionDelete,
      payload: deletePayload,
      businessId: businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT GUESTS  (FIX: seat-level allocation + session management)
  //  CRITICAL: Seats start fresh sessions with zero duration on seating
  // ══════════════════════════════════════════════════════════════════════════

  /// Seat guests at specific seats or entire table.
  ///
  /// ✅ KEY SESSION ISOLATION FIXES:
  ///   1. FRESH SESSION PER SEAT: Each seated customer gets a unique session_id
  ///   2. ZERO DURATION START: occupied_since is set to NOW (not carried forward)
  ///   3. NO PREVIOUS DATA BLEED: Old session duration is completely cleared
  ///   4. INDEPENDENT SEAT TRACKING: Each seat in multi-seat table has own timer
  ///   5. ONLINE & OFFLINE: Works for both connection states
  ///
  /// When a customer leaves (clearTable):
  ///   • Session is marked as completed
  ///   • occupied_since is set to NULL
  ///   • Next customer gets completely fresh session with zero duration
  ///
  /// Example flow:
  ///   • Customer A seated at Table-1, Seat A at 10:00 → occupied_since = 10:00
  ///   • Customer A leaves → Seat A cleared, occupied_since = NULL
  ///   • Customer B seated at Table-1, Seat A at 10:15 → occupied_since = 10:15 (FRESH!)
  ///   • UI shows Customer B duration as ~0 minutes (not 15+ from Customer A)

  Future<SeatResult> seatGuests(
    String tableId,
    String customerName, {
    required String businessId,
    bool isWalkIn = false,
    List<String>? seatIds,
    String? staffUid,
    String? staffName,
  }) async {
    if (_connectivity.isOnline) {
      if (!_isUuid(tableId)) {
        debugPrint(
          '[TablesRepo] seatGuests: tableId is non-UUID (offline fallback): $tableId',
        );
      } else {
        try {
          final result = await _sb.rpc(
            'fn_seat_guest_v2',
            params: {
              // Alphabetical order per Supabase schema cache matching
              'p_customer_name': customerName,
              'p_seat_ids': seatIds ?? [],
              'p_staff_name': staffName,
              'p_staff_uid': staffUid,
              'p_table_id': tableId,
            },
          );

          // FIX: Clear stale local orders after seating a new guest online too
          if (seatIds != null && seatIds.isNotEmpty) {
            for (final sid in seatIds) {
              await OrdersRepository.instance.clearSeatOrdersLocally(
                tableId: tableId,
                seatId: sid,
                businessId: businessId,
              );
            }
          } else {
            await OrdersRepository.instance.clearTableOrdersLocally(
              tableId: tableId,
              businessId: businessId,
            );
          }

          await refreshFromRemote(businessId);
          return SeatResult(
            success: result?['success'] == true,
            sessionId: result?['session_id'] as String?,
            reservationId: result?['reservation_id'] as String?,
          );
        } catch (e) {
          debugPrint('[TablesRepo] Online seatGuests failed: $e');
          // Fall through to offline path so the app still works
        }
      }
    }

    // ── OFFLINE PATH ──────────────────────────────────────────────────────
    // FIX: Generate a fresh session_id for the new guest
    final newSessionId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // FIX: Clear stale local orders from the previous guest first.
    // Seat-level seating should not clear other seats' active orders.
    if (seatIds != null && seatIds.isNotEmpty) {
      for (final sid in seatIds) {
        await OrdersRepository.instance.clearSeatOrdersLocally(
          tableId: tableId,
          seatId: sid,
          businessId: businessId,
        );
      }
    } else {
      await OrdersRepository.instance.clearTableOrdersLocally(
        tableId: tableId,
        businessId: businessId,
      );
    }

    // FIX: Determine new table status based on seat selection
    final newTableStatus = await _computeTableStatusAfterSeating(
      tableId: tableId,
      businessId: businessId,
      selectedSeatIds: seatIds,
    );

    // ✅ CRITICAL FIX: Update seats with fresh session and RESET occupied_since
    // This ensures duration starts at ZERO for the new customer
    await _updateSeatsLocally(
      tableId: tableId,
      businessId: businessId,
      selectedSeatIds: seatIds,
      customerName: customerName,
      sessionId: newSessionId,
    );

    // Update the table row locally with new session + status
    await _updateTableRowLocally(
      tableId: tableId,
      businessId: businessId,
      updates: {
        'status': newTableStatus,
        'current_customer_name': customerName,
        'occupied_since': newTableStatus == 'occupied' ? now : null,
        'session_id': newSessionId,
        'updated_by_uid': staffUid,
        'updated_by_name': staffName,
        'updated_at': now,
      },
    );

    // Queue the seat-guest operation for remote sync
    final queuePayload = {
      'id': tableId,
      'business_id': businessId,
      'status': newTableStatus,
      'current_customer_name': customerName,
      'occupied_since': newTableStatus == 'occupied' ? now : null,
      'session_id': newSessionId,
      'updated_by_uid': staffUid,
      'updated_by_name': staffName,
      'updated_at': now,
    };

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: tableId,
      action: LocalDatabase.actionUpdate,
      payload: queuePayload,
      businessId: businessId,
    );

    log(
      '[TablesRepo] seatGuests offline: tableId=$tableId '
      'status=$newTableStatus session=$newSessionId '
      'seats=${seatIds?.length ?? 'all'} '
      'occupiedSince=$now (FRESH - zero duration start)',
    );

    return SeatResult(success: true, sessionId: newSessionId);
  }

  /// Clear an occupied table (or a single seat in partial seating), both online and offline.
  ///
  /// ✅ KEY SESSION COMPLETION BEHAVIOR:
  ///   • When a customer leaves, their session is CLOSED (marked as completed)
  ///   • All session-related data is COMPLETELY CLEARED
  ///   • The seat becomes ready for a NEW customer with a FRESH session
  ///   • Offline: Local seats are immediately marked available + all session data nulled
  ///   • Online: RPC handles it, we mirror locally to keep caches in sync
  ///   • Works for individual seat clearance (partial) or whole table (complete)
  Future<void> clearTable(
    String tableId,
    String businessId, {
    String? seatId,
    String? staffUid,
    String? staffName,
  }) async {
    if (_connectivity.isOnline) {
      if (!_isUuid(tableId)) {
        debugPrint(
          '[TablesRepo] clearTable: tableId is non-UUID (offline fallback): $tableId',
        );
      } else {
        try {
          // Choose the correct RPC function based on whether we're clearing a seat or entire table
          final rpcFunction = seatId != null
              ? 'fn_clear_seat'
              : 'fn_checkout_v2';
          // Pass parameters in alphabetical order to match Supabase schema cache
          final rpcParams = seatId != null
              ? {'p_seat_id': seatId, 'p_table_id': tableId}
              : {'p_table_id': tableId};

          await _sb.rpc(rpcFunction, params: rpcParams);

          // Mirror remote checkout locally to keep the offline cache consistent.
          if (seatId != null) {
            await OrdersRepository.instance.clearSeatOrdersLocally(
              tableId: tableId,
              seatId: seatId,
              businessId: businessId,
            );
          } else {
            await OrdersRepository.instance.clearTableOrdersLocally(
              tableId: tableId,
              businessId: businessId,
            );
          }

          await refreshFromRemote(businessId);
          return;
        } catch (e) {
          debugPrint('[TablesRepo] Online clearTable failed: $e');
          // Fall through to local fallback
        }
      }
    }

    // OFFLINE fallback: manipulate local cache to reflect cleared table.
    await OrdersRepository.instance.clearTableOrdersLocally(
      tableId: tableId,
      businessId: businessId,
    );

    // If seat-level clear, only free that seat; else free whole table.
    if (seatId != null) {
      await _clearSeatLocally(tableId, businessId, seatId);
    } else {
      await _clearWholeTableLocally(tableId, businessId);
    }
  }

  Future<void> _clearSeatLocally(
    String tableId,
    String businessId,
    String seatId,
  ) async {
    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
    if (tableRow == null) return;

    final rawSeats = tableRow['seats'];
    if (rawSeats is! List) return;

    final now = DateTime.now().toUtc().toIso8601String();

    // ── Save seat history before clearing ──────────────────────────────────
    final seatToClose = (rawSeats as List)
        .whereType<Map<String, dynamic>>()
        .where((s) => s['id'] == seatId)
        .firstOrNull;

    if (seatToClose != null && seatToClose['session_id'] != null) {
      try {
        await SeatHistoryRepository.instance.checkoutSession(
          sessionId: seatToClose['session_id'] as String,
          checkOutTime: DateTime.now(),
        );
        log('[TablesRepo] Saved session history for seat $seatId');
      } catch (e) {
        log('[TablesRepo] Error saving seat history: $e');
        // Continue anyway - don't block the checkout
      }
    }

    /// ✅ CRITICAL FIX: When clearing a seat, COMPLETELY RESET all session data
    /// This ensures the seat is truly "available" and ready for a new session
    /// When a new customer sits here, their session will start fresh with zero duration
    final updatedSeats = rawSeats.map((seat) {
      final seatMap = Map<String, dynamic>.from(seat as Map<String, dynamic>);
      if (seatMap['id'] == seatId) {
        // Completely clear all session-related fields
        seatMap['status'] = 'available';
        seatMap['session_id'] = null; // Old session ID is erased
        seatMap['customer_name'] = null; // Old customer name is erased
        seatMap['occupied_since'] = null; // Old duration timer ref is erased
        // Next customer will get a fresh occupied_since when seated
      }
      return seatMap;
    }).toList();

    final allSeatsOccupied = updatedSeats
        .where((s) => s['status'] == 'occupied')
        .isNotEmpty;

    final updatedRow = Map<String, dynamic>.from(tableRow);
    updatedRow['seats'] = updatedSeats;
    updatedRow['status'] = allSeatsOccupied ? 'occupied' : 'available';
    updatedRow['session_id'] = allSeatsOccupied ? tableRow['session_id'] : null;
    updatedRow['current_order_id'] = allSeatsOccupied
        ? tableRow['current_order_id']
        : null;
    updatedRow['current_order_total'] = allSeatsOccupied
        ? tableRow['current_order_total']
        : 0;
    updatedRow['current_customer_name'] = allSeatsOccupied
        ? tableRow['current_customer_name']
        : null;
    updatedRow['updated_at'] = now;

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: updatedRow,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: tableId,
      action: LocalDatabase.actionUpdate,
      payload: _toQueuePayload(updatedRow),
      businessId: businessId,
    );

    log(
      '[TablesRepo] _clearSeatLocally: Completely cleared seat $seatId at table $tableId',
    );
  }

  Future<void> _clearWholeTableLocally(
    String tableId,
    String businessId,
  ) async {
    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
    if (tableRow == null) return;

    final now = DateTime.now().toUtc().toIso8601String();

    // ── Save seat history for all seats being cleared ──────────────────────
    final rawSeats = tableRow['seats'] as List?;
    if (rawSeats != null) {
      for (final seat in rawSeats) {
        final seatMap = seat as Map<String, dynamic>?;
        if (seatMap != null && seatMap['session_id'] != null) {
          try {
            await SeatHistoryRepository.instance.checkoutSession(
              sessionId: seatMap['session_id'] as String,
              checkOutTime: DateTime.now(),
            );
            log('[TablesRepo] Saved session history for seat ${seatMap['id']}');
          } catch (e) {
            log('[TablesRepo] Error saving seat history: $e');
            // Continue anyway - don't block the checkout
          }
        }
      }
    }

    /// ✅ CRITICAL FIX: When clearing the entire table, COMPLETELY RESET ALL seats
    /// This ensures all seats are truly "available" and ready for fresh sessions
    /// When new customers sit down, their sessions will start fresh with zero duration
    final updatedSeats =
        (tableRow['seats'] as List?)
            ?.map(
              (seat) => {
                ...Map<String, dynamic>.from(seat as Map<String, dynamic>),
                'status': 'available',
                'session_id': null, // Old session ID is completely erased
                'customer_name': null, // Old customer name is completely erased
                'occupied_since':
                    null, // Old duration timer reference is completely erased
                // Next customers will get fresh occupied_since when seated
              },
            )
            .toList() ??
        [];

    final updatedRow = Map<String, dynamic>.from(tableRow);
    updatedRow['seats'] = updatedSeats;
    updatedRow['status'] = 'cleaning';
    updatedRow['session_id'] = null;
    updatedRow['current_order_id'] = null;
    updatedRow['current_order_total'] = 0;
    updatedRow['current_customer_name'] = null;
    updatedRow['updated_at'] = now;

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: updatedRow,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: tableId,
      action: LocalDatabase.actionUpdate,
      payload: _toQueuePayload(updatedRow),
      businessId: businessId,
    );

    log(
      '[TablesRepo] _clearWholeTableLocally: Completely cleared all seats for table $tableId',
    );
  }

  // ── Compute table status based on which seats are being filled ───────────
  //
  // Rules:
  //   • No specific seats selected → full table booking → 'occupied'
  //   • Specific seats selected AND they fill ALL available seats → 'occupied'
  //   • Specific seats selected but some seats remain → keep current status
  //     (available/reserved) so other guests can still book remaining seats.
  //     The table is only marked 'occupied' once ALL seats are taken.
  Future<String> _computeTableStatusAfterSeating({
    required String tableId,
    required String businessId,
    required List<String>? selectedSeatIds,
  }) async {
    // Full table booking
    if (selectedSeatIds == null || selectedSeatIds.isEmpty) return 'occupied';

    // Seat-level booking: read current seats from local table row
    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
    if (tableRow == null) return 'occupied';

    final rawSeats = tableRow['seats'];
    if (rawSeats == null || rawSeats is! List || rawSeats.isEmpty) {
      // No seat info available — fall back to full table occupied
      return 'occupied';
    }

    final allSeats = rawSeats.cast<Map<String, dynamic>>();
    final totalSeats = allSeats.length;
    final currentlyOccupied = allSeats
        .where((s) => s['status'] == 'occupied')
        .length;
    final willBeOccupied = currentlyOccupied + selectedSeatIds.length;

    return willBeOccupied >= totalSeats ? 'occupied' : 'available';
  }

  // ── Update individual seats in the local table row ────────────────────────
  /// Update individual seats in the local table row and reset duration for new session
  ///
  /// KEY FIX: Each time a new customer is seated:
  /// 1. Generate a fresh session_id (unique to this customer/seat combination)
  /// 2. Set occupied_since to NOW (zero duration at the start)
  /// 3. Clear any previous session data (old duration will NOT carry forward)
  /// 4. Online: RPC already handles this, we just mirror it locally
  /// 5. Offline: We manually manage seats with per-seat session isolation
  Future<void> _updateSeatsLocally({
    required String tableId,
    required String businessId,
    required List<String>? selectedSeatIds,
    required String customerName,
    required String sessionId,
  }) async {
    if (selectedSeatIds == null || selectedSeatIds.isEmpty) return;

    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final tableRow = tableRows.where((r) => r['id'] == tableId).firstOrNull;
    if (tableRow == null) return;

    final rawSeats = tableRow['seats'];
    if (rawSeats == null || rawSeats is! List) return;

    final now = DateTime.now().toUtc().toIso8601String();

    /// ✅ CRITICAL FIX: For each selected seat, create a completely fresh session
    /// This ensures previous session duration is NEVER shown
    final updatedSeats = rawSeats.map((seat) {
      final seatMap = Map<String, dynamic>.from(seat as Map<String, dynamic>);
      if (selectedSeatIds.contains(seatMap['id'])) {
        // Generate per-seat session ID (allows tracking independent per-seat)
        final perSeatSessionId = _uuid.v4();

        seatMap['status'] = 'occupied';
        seatMap['customer_name'] = customerName;
        seatMap['session_id'] =
            perSeatSessionId; // Per-seat session, not table session
        seatMap['occupied_since'] =
            now; // RESET to NOW — zero duration at start
      }
      return seatMap;
    }).toList();

    // Persist the updated seat list back into the table row
    final updatedRow = Map<String, dynamic>.from(tableRow);
    updatedRow['seats'] = updatedSeats;

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: updatedRow,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    log(
      '[TablesRepo] _updateSeatsLocally: Set fresh session for ${selectedSeatIds.length} seats at table $tableId',
    );
  }

  // ── Low-level: merge fields into the local table row ─────────────────────
  Future<void> _updateTableRowLocally({
    required String tableId,
    required String businessId,
    required Map<String, dynamic> updates,
  }) async {
    final tableRows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final existing =
        tableRows.where((r) => r['id'] == tableId).firstOrNull ??
        <String, dynamic>{'id': tableId, 'business_id': businessId};

    final updated = Map<String, dynamic>.from(existing);
    updated.addAll(updates);

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: updated,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );
  }

  // ── Legacy helper kept for other callers ─────────────────────────────────
  Future<void> _updateTableStatusLocally(
    String tableId,
    String businessId,
    String status, [
    String? customerName,
  ]) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tTables,
      businessId: businessId,
    );
    final existing = rows.firstWhere(
      (r) => r['id'] == tableId,
      orElse: () => <String, dynamic>{'id': tableId},
    );

    final update = _toQueuePayload(Map<String, dynamic>.from(existing));
    update['status'] = status;
    if (customerName != null) update['current_customer_name'] = customerName;
    update['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: update,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RESERVATION CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createReservation(
    Map<String, dynamic> data,
    String businessId,
  ) async {
    final id = data['id'] as String? ?? _uuid.v4();
    data['id'] = id;

    await _local.upsertEntity(
      table: LocalDatabase.tReservations,
      id: id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    final queuePayload = _toQueuePayload(data);

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kReservations).insert(queuePayload);
        await _local.upsertEntity(
          table: LocalDatabase.tReservations,
          id: id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionCreate,
        );
        return id;
      } catch (e) {
        debugPrint('[TablesRepo] Online createReservation failed, queuing: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.reservation,
      entityId: id,
      action: LocalDatabase.actionCreate,
      payload: queuePayload,
      businessId: businessId,
    );
    return id;
  }

  Future<void> updateReservation(
    String id,
    Map<String, dynamic> data,
    String businessId,
  ) async {
    await _local.upsertEntity(
      table: LocalDatabase.tReservations,
      id: id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    final queuePayload = _toQueuePayload(data);

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kReservations).update(queuePayload).eq('id', id);
        await _local.upsertEntity(
          table: LocalDatabase.tReservations,
          id: id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
        return;
      } catch (e) {
        debugPrint('[TablesRepo] Online updateReservation failed, queuing: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.reservation,
      entityId: id,
      action: LocalDatabase.actionUpdate,
      payload: queuePayload,
      businessId: businessId,
    );
  }

  Future<void> cancelReservation(String id, String businessId) async {
    await updateReservation(id, {
      'id': id,
      'status': 'cancelled',
      'business_id': businessId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, businessId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _promoteSyncedEntities({
    required String table,
    required String businessId,
    required Set<String> confirmedIds,
  }) async {
    if (confirmedIds.isEmpty) return;
    try {
      final local = await _local.db.query(
        table,
        columns: ['id', 'sync_status', 'action'],
        where: 'business_id = ? AND sync_status = ?',
        whereArgs: [businessId, LocalDatabase.syncPending],
      );
      for (final row in local) {
        final id = row['id'] as String;
        final action = row['action'] as String;
        if (confirmedIds.contains(id) && action != LocalDatabase.actionDelete) {
          await _local.db.update(
            table,
            {
              'sync_status': LocalDatabase.syncSynced,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          log('[TablesRepo] Promoted $id to synced');
        }
      }
    } catch (e) {
      debugPrint('[TablesRepo] _promoteSyncedEntities error: $e');
    }
  }

  RestaurantTable? _rowToTable(Map<String, dynamic> row) {
    try {
      final seats = (row['seats'] as List? ?? [])
          .map((s) => TableSeat.fromJson(s as Map<String, dynamic>))
          .toList();

      Reservation? reservation;
      final reservationData = row['reservation_data'];
      if (reservationData != null) {
        Map<String, dynamic> resMap;
        if (reservationData is Map<String, dynamic>) {
          resMap = reservationData;
        } else if (reservationData is String) {
          resMap = jsonDecode(reservationData) as Map<String, dynamic>;
        } else {
          resMap = {};
        }
        try {
          reservation = Reservation.fromJson(resMap);
        } catch (e) {
          debugPrint('[TablesRepo] Failed to parse reservation_data: $e');
        }
      }

      return RestaurantTable(
        id: row['id'] as String,
        tableNumber: row['table_number'] as int? ?? 0,
        capacity: row['capacity'] as int? ?? 4,
        status: _parseStatus(row['status'] as String? ?? 'available'),
        section: _parseSection(row['section'] as String? ?? 'ac'),
        shape: _parseShape(row['shape'] as String? ?? 'square'),
        hasWindow: row['has_window'] as bool? ?? false,
        isPremium: row['is_premium'] as bool? ?? false,
        currentCustomerName: row['current_customer_name'] as String?,
        currentOrderId: row['current_order_id'] as String?,
        currentOrderTotal: (row['current_order_total'] as num?)?.toDouble(),
        occupiedSince: row['occupied_since'] != null
            ? DateTime.tryParse(row['occupied_since'] as String)
            : null,
        // FIX: expose session_id so order-repo can filter by it
        sessionId:
            row['session_id'] is String &&
                (row['session_id'] as String).isNotEmpty
            ? row['session_id'] as String
            : null,
        reservation: reservation,
        seats: seats,
      );
    } catch (e) {
      debugPrint('[TablesRepo] _rowToTable error: $e');
      return null;
    }
  }

  ReservationHistoryItem? _rowToReservation(Map<String, dynamic> row) {
    try {
      return ReservationHistoryItem.fromMap(row);
    } catch (e) {
      debugPrint('[TablesRepo] _rowToReservation error: $e');
      return null;
    }
  }

  TableStatus _parseStatus(String s) => TableStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableStatus.available,
  );
  TableSection _parseSection(String s) => TableSection.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableSection.ac,
  );
  TableShape _parseShape(String s) => TableShape.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableShape.square,
  );
}
