// lib/database/local_database.dart
// ══════════════════════════════════════════════════════════════════════════════
//  LOCAL DATABASE — SQLite via sqflite
//  Single source of truth for offline-first POS architecture.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();

  Database? _db;
  Database get db {
    if (_db == null)
      throw StateError('LocalDatabase not initialized. Call init() first.');
    return _db!;
  }

  bool get isInitialized => _db != null;

  static const _dbName = 'pos_app_offline.db';
  static const _dbVersion = 2;

  // ── Table names ────────────────────────────────────────────────────────────
  static const tQueue = 'offline_queue';
  static const tOrders = 'local_orders';
  static const tTables = 'local_tables';
  static const tSeats = 'table_seats';
  static const tReservations = 'local_reservations';
  static const tMenuItems = 'local_menu_items';
  static const tInventory = 'local_inventory';
  static const tSuppliers = 'local_suppliers';
  static const tProfile = 'local_profile';
  static const tSyncMeta = 'sync_meta';
  static const tSeatHistory = 'local_seat_history';

  // ── Sync status values ─────────────────────────────────────────────────────
  static const syncPending = 'pending';
  static const syncSynced = 'synced';
  static const syncFailed = 'failed';

  // ── Action types ───────────────────────────────────────────────────────────
  static const actionCreate = 'create';
  static const actionUpdate = 'update';
  static const actionDelete = 'delete';

  // ── Max retry attempts before giving up ───────────────────────────────────
  static const maxAttempts = 5;

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_db != null) return;
    try {
      final dbPath = p.join(await getDatabasesPath(), _dbName);
      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) => db.rawQuery('PRAGMA journal_mode=WAL'),
      );
      log('[LocalDB] ✅ Initialized at $dbPath');
    } catch (e, st) {
      log('[LocalDB] ❌ Init error: $e\n$st');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createQueueTable);
    await db.execute(_createOrdersTable);
    await db.execute(_createTablesTable);
    await db.execute(_createReservationsTable);
    await db.execute(_createMenuItemsTable);
    await db.execute(_createInventoryTable);
    await db.execute(_createSuppliersTable);
    await db.execute(_createProfileTable);
    await db.execute(_createSyncMetaTable);
    await db.execute(_createSeatHistoryTable);
    log('[LocalDB] ✅ All tables created (v$version)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log('[LocalDB] Upgrading v$oldVersion → v$newVersion');

    // v1 → v2: Add local_seat_history table
    if (oldVersion < 2) {
      try {
        await db.execute(_createSeatHistoryTable);
        log('[LocalDB] ✅ Created local_seat_history table during upgrade');
      } catch (e) {
        log('[LocalDB] Note: local_seat_history may already exist: $e');
      }
    }

    // Future migrations go here
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TABLE DDL
  // ══════════════════════════════════════════════════════════════════════════

  static const _createQueueTable =
      '''
    CREATE TABLE IF NOT EXISTS $tQueue (
      id           TEXT PRIMARY KEY,
      entity_type  TEXT NOT NULL,
      entity_id    TEXT NOT NULL,
      action       TEXT NOT NULL CHECK(action IN ('create','update','delete')),
      payload      TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'pending',
      attempts     INTEGER NOT NULL DEFAULT 0,
      last_error   TEXT,
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL,
      business_id  TEXT
    )
  ''';

  static const _createOrdersTable =
      '''
    CREATE TABLE IF NOT EXISTS $tOrders (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'pending',
      action       TEXT NOT NULL DEFAULT 'create',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createTablesTable =
      '''
    CREATE TABLE IF NOT EXISTS $tTables (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'synced',
      action       TEXT NOT NULL DEFAULT 'update',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createReservationsTable =
      '''
    CREATE TABLE IF NOT EXISTS $tReservations (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      table_id     TEXT,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'pending',
      action       TEXT NOT NULL DEFAULT 'create',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createMenuItemsTable =
      '''
    CREATE TABLE IF NOT EXISTS $tMenuItems (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      category     TEXT,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'synced',
      action       TEXT NOT NULL DEFAULT 'create',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createInventoryTable =
      '''
    CREATE TABLE IF NOT EXISTS $tInventory (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'pending',
      action       TEXT NOT NULL DEFAULT 'create',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createSuppliersTable =
      '''
    CREATE TABLE IF NOT EXISTS $tSuppliers (
      id           TEXT PRIMARY KEY,
      business_id  TEXT NOT NULL,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'pending',
      action       TEXT NOT NULL DEFAULT 'create',
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createProfileTable =
      '''
    CREATE TABLE IF NOT EXISTS $tProfile (
      id           TEXT PRIMARY KEY,
      data         TEXT NOT NULL,
      sync_status  TEXT NOT NULL DEFAULT 'synced',
      updated_at   TEXT NOT NULL
    )
  ''';

  static const _createSyncMetaTable =
      '''
    CREATE TABLE IF NOT EXISTS $tSyncMeta (
      key          TEXT PRIMARY KEY,
      value        TEXT NOT NULL
    )
  ''';

  static const _createSeatHistoryTable =
      '''
    CREATE TABLE IF NOT EXISTS $tSeatHistory (
      id                TEXT PRIMARY KEY,
      session_id        TEXT UNIQUE NOT NULL,
      business_id       TEXT NOT NULL,
      table_id          TEXT NOT NULL,
      table_number      INTEGER NOT NULL,
      section           TEXT NOT NULL,
      seat_label        TEXT NOT NULL,
      customer_name     TEXT,
      guest_count       INTEGER NOT NULL DEFAULT 1,
      check_in_time     TEXT NOT NULL,
      check_out_time    TEXT,
      duration_seconds  INTEGER,
      status            TEXT NOT NULL DEFAULT 'active',
      notes             TEXT,
      created_at        TEXT NOT NULL,
      updated_at        TEXT,
      sync_status       TEXT NOT NULL DEFAULT 'pending'
    )
  ''';

  // ══════════════════════════════════════════════════════════════════════════
  //  OFFLINE QUEUE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> enqueue({
    required String id,
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
    String? businessId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(tQueue, {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': jsonEncode(payload),
      'sync_status': syncPending,
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
      'business_id': businessId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    log('[LocalDB] 📤 Enqueued $action on $entityType/$entityId');
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    return db.query(
      tQueue,
      where: '(sync_status = ? OR sync_status = ?) AND attempts < ?',
      whereArgs: [syncPending, syncFailed, maxAttempts],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markSynced(String queueId) async {
    await db.update(
      tQueue,
      {
        'sync_status': syncSynced,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<void> markFailed(String queueId, String error) async {
    final rows = await db.query(tQueue, where: 'id = ?', whereArgs: [queueId]);
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as int? ?? 0) + 1;
    await db.update(
      tQueue,
      {
        'sync_status': attempts >= maxAttempts ? syncFailed : syncPending,
        'attempts': attempts,
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<int> pendingCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tQueue WHERE sync_status = ? OR (sync_status = ? AND attempts < ?)',
      [syncPending, syncFailed, maxAttempts],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> pruneOldSynced() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .toUtc()
        .toIso8601String();
    await db.delete(
      tQueue,
      where: 'sync_status = ? AND updated_at < ?',
      whereArgs: [syncSynced, cutoff],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GENERIC ENTITY CACHE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> upsertEntity({
    required String table,
    required String id,
    required String businessId,
    required Map<String, dynamic> data,
    String syncStatus = syncSynced,
    String action = actionUpdate,
    Map<String, dynamic>? extraColumns,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = <String, dynamic>{
      'id': id,
      'business_id': businessId,
      'data': jsonEncode(data),
      'sync_status': syncStatus,
      'action': action,
      'created_at': now,
      'updated_at': now,
    };
    if (extraColumns != null) row.addAll(extraColumns);
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getEntities({
    required String table,
    required String businessId,
    String? whereExtra,
    List<dynamic>? whereExtraArgs,
  }) async {
    final where = whereExtra != null
        ? 'business_id = ? AND $whereExtra'
        : 'business_id = ?';
    final args = whereExtra != null
        ? [businessId, ...?whereExtraArgs]
        : [businessId];
    final rows = await db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) {
      final decoded = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      decoded['_sync_status'] = row['sync_status'];
      decoded['_action'] = row['action'];

      if (!decoded.containsKey('id') || decoded['id'] == null) {
        decoded['id'] = row['id'];
      }
      if (!decoded.containsKey('business_id') ||
          decoded['business_id'] == null) {
        decoded['business_id'] = row['business_id'];
      }
      return decoded;
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FIX: replaceAll — preserves unsynced (pending/failed) rows
  // ══════════════════════════════════════════════════════════════════════════
  //
  //  THE BUG: The original replaceAll did DELETE WHERE business_id = ? then
  //  re-inserted only rows that came from the remote. Any locally-created
  //  entity that hadn't synced yet (sync_status = 'pending', action = 'create')
  //  was permanently wiped — even though it existed in the offline queue.
  //
  //  THE FIX: We only delete rows that are already fully synced. Rows still
  //  pending or failed are left untouched. Remote rows are then merged in via
  //  INSERT OR IGNORE (so pending-local rows win on conflict). Finally, for
  //  rows that exist both locally (synced) and remotely, we overwrite the
  //  local data with the fresh remote payload.
  //
  Future<void> replaceAll({
    required String table,
    required String businessId,
    required List<Map<String, dynamic>> entities,
    String? idField,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final remoteIds = entities
        .map((e) => e[idField ?? 'id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    await db.transaction((txn) async {
      // 1. Delete synced rows whose IDs did NOT come back from remote
      //    (they were deleted server-side). Leave pending/failed rows alone.
      if (remoteIds.isNotEmpty) {
        final placeholders = List.filled(remoteIds.length, '?').join(',');
        await txn.rawDelete(
          '''DELETE FROM $table
             WHERE business_id = ?
               AND sync_status = ?
               AND id NOT IN ($placeholders)''',
          [businessId, syncSynced, ...remoteIds],
        );
      } else {
        // Remote returned nothing — only wipe synced rows, keep pending
        await txn.delete(
          table,
          where: 'business_id = ? AND sync_status = ?',
          whereArgs: [businessId, syncSynced],
        );
      }

      // 2. Upsert each remote row:
      //    • If a pending-local row exists for this id → skip (local wins until synced)
      //    • If a synced row exists → overwrite with fresh remote data
      //    • If no row exists → insert as synced
      for (final entity in entities) {
        final id = entity[idField ?? 'id'] as String? ?? '';
        if (id.isEmpty) continue;

        // Check if a pending/failed local row already exists for this id
        final existing = await txn.query(
          table,
          columns: ['sync_status'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final status = existing.first['sync_status'] as String?;
          if (status == syncPending || status == syncFailed) {
            // Local unsynced data is authoritative — do not overwrite
            log('[LocalDB] Skipping remote overwrite for pending row: $id');
            continue;
          }
        }

        // Safe to write the remote row
        await txn.insert(table, {
          'id': id,
          'business_id': businessId,
          'data': jsonEncode(entity),
          'sync_status': syncSynced,
          'action': actionUpdate,
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteEntity(String table, String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFILE (single-row table)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> saveProfile(String uid, Map<String, dynamic> data) async {
    await db.insert(tProfile, {
      'id': uid,
      'data': jsonEncode(data),
      'sync_status': syncSynced,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final rows = await db.query(tProfile, where: 'id = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  Future<void> updateProfileField(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final existing = await getProfile(uid);
    if (existing == null) return;
    existing.addAll(fields);
    await db.update(
      tProfile,
      {
        'data': jsonEncode(existing),
        'sync_status': syncPending,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [uid],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNC META
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> setSyncMeta(String key, String value) async {
    await db.insert(tSyncMeta, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSyncMeta(String key) async {
    final rows = await db.query(tSyncMeta, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT HISTORY OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> insertSeatHistory(Map<String, dynamic> data) async {
    await db.insert(
      tSeatHistory,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    log('[LocalDB] Inserted seat history: ${data['session_id']}');
  }

  Future<void> updateSeatHistory(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    await db.update(
      tSeatHistory,
      data,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    log('[LocalDB] Updated seat history: $sessionId');
  }

  Future<Map<String, dynamic>?> getSeatHistoryBySessionId(
    String sessionId,
  ) async {
    final results = await db.query(
      tSeatHistory,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<List<Map<String, dynamic>>> getSeatHistoryByTableAndSeat({
    required String tableId,
    required String seatLabel,
    int limit = 50,
    int offset = 0,
  }) async {
    return db.query(
      tSeatHistory,
      where: 'table_id = ? AND seat_label = ?',
      whereArgs: [tableId, seatLabel],
      orderBy: 'check_in_time DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getSeatHistoryByTable({
    required String tableId,
    int limit = 100,
    int offset = 0,
  }) async {
    return db.query(
      tSeatHistory,
      where: 'table_id = ?',
      whereArgs: [tableId],
      orderBy: 'check_in_time DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getSeatHistoryByCustomer({
    required String businessId,
    required String customerName,
    int limit = 50,
    int offset = 0,
  }) async {
    return db.query(
      tSeatHistory,
      where: 'business_id = ? AND customer_name = ?',
      whereArgs: [businessId, customerName],
      orderBy: 'check_in_time DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getSeatHistoryByDate({
    required String businessId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).toUtc().toIso8601String();
    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toUtc().toIso8601String();

    return db.query(
      tSeatHistory,
      where: 'business_id = ? AND check_in_time >= ? AND check_in_time <= ?',
      whereArgs: [businessId, dayStart, dayEnd],
      orderBy: 'check_in_time DESC',
    );
  }

  Future<void> clearOldSeatHistory({
    required String businessId,
    required String beforeDate,
  }) async {
    await db.delete(
      tSeatHistory,
      where: 'business_id = ? AND check_in_time < ?',
      whereArgs: [businessId, beforeDate],
    );
    log('[LocalDB] Cleared old seat history before $beforeDate');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PENDING QUEUE FOR SYNC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addToPendingQueue({
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        'q_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(tQueue, {
      'id': id,
      'entity_type': entityType,
      'entity_id': payload['id'] ?? payload['session_id'] ?? 'unknown',
      'action': action,
      'payload': jsonEncode(payload),
      'sync_status': syncPending,
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLOSE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @visibleForTesting
  Future<void> deleteAll() async {
    final tables = [
      tQueue,
      tOrders,
      tTables,
      tReservations,
      tMenuItems,
      tInventory,
      tSuppliers,
      tProfile,
      tSeatHistory,
    ];
    for (final t in tables) {
      await db.delete(t);
    }
  }
}
