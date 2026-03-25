// lib/repositories/profile_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  PROFILE REPOSITORY — Offline-first
//  Reads from local cache, writes to Firestore when online (or queues).
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';
import 'package:pos_app/services/storage_service.dart';

class ProfileRepository {
  ProfileRepository._();
  static final instance = ProfileRepository._();

  final _local = LocalDatabase.instance;
  final _fs = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  LOAD PROFILE
  //  Returns cached profile immediately; fires Firestore fetch in background.
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> loadProfile(String uid) async {
    final cached = await _local.getProfile(uid);

    if (cached != null) {
      if (_connectivity.isOnline) {
        _refreshFromFirestore(uid).catchError((_) {});
      }
      return cached;
    }

    if (_connectivity.isOnline) {
      return await _refreshFromFirestore(uid);
    }

    return null;
  }

  Future<Map<String, dynamic>?> refreshProfile(String uid) async {
    if (!_connectivity.isOnline) {
      return _local.getProfile(uid);
    }
    return _refreshFromFirestore(uid);
  }

  Future<Map<String, dynamic>?> _refreshFromFirestore(String uid) async {
    try {
      final doc = await _fs.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      // Convert Timestamp to ISO string for local storage
      final serialized = _serializeFirestoreData(data);
      serialized['uid'] = uid;
      await _local.saveProfile(uid, serialized);
      log('[ProfileRepo] Refreshed from Firestore for uid=$uid');
      return serialized;
    } catch (e) {
      debugPrint('[ProfileRepo] Firestore refresh error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE PROFILE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> updateProfile(String uid, Map<String, dynamic> updates) async {
    // 1. Update local cache immediately
    await _local.updateProfileField(uid, updates);

    if (_connectivity.isOnline) {
      try {
        final fsUpdates = Map<String, dynamic>.from(updates);
        fsUpdates['updatedAt'] = FieldValue.serverTimestamp();
        await _fs.collection('users').doc(uid).update(fsUpdates);
        // Refresh local cache with server data
        await _refreshFromFirestore(uid);
        return;
      } catch (e) {
        debugPrint('[ProfileRepo] Online updateProfile failed: $e');
      }
    }

    // Queue for sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.profile,
      entityId: uid,
      action: LocalDatabase.actionUpdate,
      payload: {...updates, 'uid': uid},
    );
    log('[ProfileRepo] Profile update queued for uid=$uid');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOAD USER DATA FROM STORAGE (SharedPreferences cache)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUserDataFromStorage() =>
      StorageService.instance.getUserData();

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH USER PERFORMANCE STATS FROM SUPABASE
  //  All queries are filtered by created_by_uid = uid (user-specific)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchUserPerformanceStats({
    required String uid,
    required String businessId,
  }) async {
    final sb = Supabase.instance.client;

    try {
      final nowDt = DateTime.now();

      // Today's stats
      final todayStartDt = nowDt
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc();

      // This week start (Monday)
      final weekStartDt = nowDt
          .subtract(Duration(days: nowDt.weekday - 1))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc();

      // This month start
      final monthStartDt = DateTime(nowDt.year, nowDt.month, 1).toUtc();

      // Fetch all completed orders for this user to compute aggregates locally
      final List<dynamic> orders = await sb
          .from('orders')
          .select('id, total_amount, table_id, created_at')
          .eq('business_id', businessId)
          .eq('created_by_uid', uid)
          .eq('status', 'completed');

      int ordersTodayCount = 0;
      double revenueTodayAmount = 0.0;
      final Set<String> tablesToday = {};

      int ordersWeekCount = 0;
      double revenueWeekAmount = 0.0;
      final Set<String> tablesWeek = {};

      int ordersMonthCount = 0;
      double revenueMonthAmount = 0.0;
      final Set<String> tablesMonth = {};

      int ordersAllTimeCount = 0;
      double revenueAllTimeAmount = 0.0;
      final Set<String> tablesAllTime = {};

      for (final order in orders) {
        final createdAtStr = order['created_at'] as String?;
        if (createdAtStr == null) continue;
        final createdAt = DateTime.parse(createdAtStr).toUtc();
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final tableId = order['table_id']?.toString();

        ordersAllTimeCount++;
        revenueAllTimeAmount += amount;
        if (tableId != null) tablesAllTime.add(tableId);

        if (createdAt.isAfter(monthStartDt) ||
            createdAt.isAtSameMomentAs(monthStartDt)) {
          ordersMonthCount++;
          revenueMonthAmount += amount;
          if (tableId != null) tablesMonth.add(tableId);
        }

        if (createdAt.isAfter(weekStartDt) ||
            createdAt.isAtSameMomentAs(weekStartDt)) {
          ordersWeekCount++;
          revenueWeekAmount += amount;
          if (tableId != null) tablesWeek.add(tableId);
        }

        if (createdAt.isAfter(todayStartDt) ||
            createdAt.isAtSameMomentAs(todayStartDt)) {
          ordersTodayCount++;
          revenueTodayAmount += amount;
          if (tableId != null) tablesToday.add(tableId);
        }
      }

      // NOTE: Shifts table not implemented yet - return 0 for now
      final shiftCount = 0;

      return {
        'ordersTodayCount': ordersTodayCount,
        'revenueTodayAmount': revenueTodayAmount,
        'tablesTodayCount': tablesToday.length,
        'ordersWeekCount': ordersWeekCount,
        'revenueWeekAmount': revenueWeekAmount,
        'tablesWeekCount': tablesWeek.length,
        'avgOrderValueWeek': ordersWeekCount > 0
            ? revenueWeekAmount / ordersWeekCount
            : 0.0,
        'ordersMonthCount': ordersMonthCount,
        'revenueMonthAmount': revenueMonthAmount,
        'tablesMonthCount': tablesMonth.length,
        'avgOrderValueMonth': ordersMonthCount > 0
            ? revenueMonthAmount / ordersMonthCount
            : 0.0,
        'ordersAllTimeCount': ordersAllTimeCount,
        'revenueAllTimeAmount': revenueAllTimeAmount,
        'tablesAllTimeCount': tablesAllTime.length,
        'shiftsThisWeek': shiftCount,
      };
    } catch (e) {
      debugPrint('[ProfileRepo] fetchUserPerformanceStats error: $e');
      // Return default stats on error
      return {
        'ordersTodayCount': 0,
        'revenueTodayAmount': 0.0,
        'tablesTodayCount': 0,
        'ordersWeekCount': 0,
        'revenueWeekAmount': 0.0,
        'tablesWeekCount': 0,
        'avgOrderValueWeek': 0.0,
        'ordersMonthCount': 0,
        'revenueMonthAmount': 0.0,
        'tablesMonthCount': 0,
        'avgOrderValueMonth': 0.0,
        'ordersAllTimeCount': 0,
        'revenueAllTimeAmount': 0.0,
        'tablesAllTimeCount': 0,
        'shiftsThisWeek': 0,
      };
    }
  }

  Map<String, dynamic> _serializeFirestoreData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Timestamp) {
        result[entry.key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        result[entry.key] = _serializeFirestoreData(
          value.cast<String, dynamic>(),
        );
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }
}
