// lib/repositories/tables_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  TABLES REPOSITORY — Offline-first
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/providers/tables_provider.dart';
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

      // FIX: replaceAll now preserves pending/unsynced local rows — see LocalDatabase
      await _local.replaceAll(
        table: LocalDatabase.tTables,
        businessId: businessId,
        entities: rows,
      );

      // After a successful remote refresh, promote any pending rows for IDs
      // that are now confirmed on the server to 'synced'.
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

      // FIX: same safe merge — pending reservations created offline are preserved
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
    final payload = {...row, 'id': id};

    // FIX: always write locally first as 'pending/create' so the entity
    // is visible immediately and survives a replaceAll while unsynced.
    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: id,
      businessId: businessId,
      data: payload,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kTables).insert(payload);
        // Mark the local row as synced — no need to enqueue
        await _local.upsertEntity(
          table: LocalDatabase.tTables,
          id: id,
          businessId: businessId,
          data: payload,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionCreate,
        );
        log('[TablesRepo] addTable synced immediately: $id');
        return;
      } catch (e) {
        debugPrint('[TablesRepo] Online addTable failed, queuing: $e');
        // Fall through to enqueue below
      }
    }

    // Offline (or online attempt failed) — enqueue for later sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: id,
      action: LocalDatabase.actionCreate,
      payload: payload,
      businessId: businessId,
    );
    log('[TablesRepo] addTable queued offline: $id');
  }

  Future<void> updateTable(
    RestaurantTable t,
    String businessId,
    Map<String, dynamic> row,
  ) async {
    // FIX: always persist locally first
    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: t.id,
      businessId: businessId,
      data: row,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionUpdate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kTables).update(row).eq('id', t.id);
        await _local.upsertEntity(
          table: LocalDatabase.tTables,
          id: t.id,
          businessId: businessId,
          data: row,
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
      payload: row,
      businessId: businessId,
    );
  }

  Future<void> deleteTable(
    String id,
    String businessId,
    String? uid,
    String? name,
  ) async {
    // Mark as deleted locally first
    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: id,
      businessId: businessId,
      data: {'id': id, 'is_active': false},
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
            })
            .eq('id', id);
        // Hard-delete the local row now that the server knows about it
        await _local.deleteEntity(LocalDatabase.tTables, id);
        return;
      } catch (_) {}
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: id,
      action: LocalDatabase.actionDelete,
      payload: {'id': id, 'is_active': false, 'business_id': businessId},
      businessId: businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATUS OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

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
      try {
        final result = await _sb.rpc(
          'fn_seat_guest_v2',
          params: {
            'p_table_id': tableId,
            'p_customer_name': customerName,
            'p_staff_uid': staffUid,
            'p_staff_name': staffName,
            if (seatIds != null) 'p_seat_ids': seatIds,
          },
        );
        await refreshFromRemote(businessId);
        return SeatResult(
          success: result?['success'] == true,
          sessionId: result?['session_id'] as String?,
          reservationId: result?['reservation_id'] as String?,
        );
      } catch (e) {
        debugPrint('[TablesRepo] Online seatGuests failed: $e');
      }
    }

    await _updateTableStatusLocally(
      tableId,
      businessId,
      'occupied',
      customerName,
    );
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.table,
      entityId: tableId,
      action: LocalDatabase.actionUpdate,
      payload: {
        'id': tableId,
        'business_id': businessId,
        'status': 'occupied',
        'current_customer_name': customerName,
        'occupied_since': DateTime.now().toUtc().toIso8601String(),
        'updated_by_uid': staffUid,
        'updated_by_name': staffName,
      },
      businessId: businessId,
    );
    return SeatResult(success: true);
  }

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
    final row = rows.firstWhere(
      (r) => r['id'] == tableId,
      orElse: () => <String, dynamic>{'id': tableId},
    );
    row['status'] = status;
    if (customerName != null) row['current_customer_name'] = customerName;
    await _local.upsertEntity(
      table: LocalDatabase.tTables,
      id: tableId,
      businessId: businessId,
      data: row,
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

    // Always write locally first
    await _local.upsertEntity(
      table: LocalDatabase.tReservations,
      id: id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kReservations).insert(data);
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
      payload: data,
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

    if (_connectivity.isOnline) {
      try {
        await _sb.from(_kReservations).update(data).eq('id', id);
        await _local.upsertEntity(
          table: LocalDatabase.tReservations,
          id: id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionUpdate,
        );
        return;
      } catch (_) {}
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.reservation,
      entityId: id,
      action: LocalDatabase.actionUpdate,
      payload: data,
      businessId: businessId,
    );
  }

  Future<void> cancelReservation(String id, String businessId) async {
    await updateReservation(id, {
      'id': id,
      'status': 'cancelled',
      'business_id': businessId,
    }, businessId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// After a successful remote refresh, promote any local 'pending' rows
  /// whose IDs are now confirmed on the server to 'synced'. This prevents
  /// entities from staying in pending state indefinitely after a background
  /// sync resolves them.
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
