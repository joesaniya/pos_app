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
    // 1. Return from local cache first
    final cached = await _local.getProfile(uid);

    // 2. Refresh from Firestore in background if online
    if (_connectivity.isOnline) {
      _refreshFromFirestore(uid).catchError((_) {});
    }

    return cached;
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
      // Today's stats
      final todayStart = DateTime.now()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc()
          .toIso8601String();
      final now = DateTime.now().toUtc().toIso8601String();

      // This week start (Monday)
      final now_dt = DateTime.now();
      final weekStart = now_dt
          .subtract(Duration(days: now_dt.weekday - 1))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc()
          .toIso8601String();

      // This month start
      final monthStart = DateTime(
        now_dt.year,
        now_dt.month,
        1,
      ).toUtc().toIso8601String();

      // Fetch orders data for all time
      final allTimeOrders = await sb
          .from('orders')
          .select(
            'COUNT(*) as total_count, COALESCE(SUM(total_amount), 0) as total_amount, COUNT(DISTINCT table_id) as table_count',
          )
          .eq('business_id', businessId)
          .eq('created_by_uid', uid)
          .eq('status', 'completed');

      // Today's completed orders
      final todayOrders = await sb
          .from('orders')
          .select(
            'COUNT(*) as total_count, COALESCE(SUM(total_amount), 0) as total_amount, COUNT(DISTINCT table_id) as table_count',
          )
          .eq('business_id', businessId)
          .eq('created_by_uid', uid)
          .eq('status', 'completed')
          .gte('created_at', todayStart)
          .lte('created_at', now);

      // Week's completed orders
      final weekOrders = await sb
          .from('orders')
          .select(
            'COUNT(*) as total_count, COALESCE(SUM(total_amount), 0) as total_amount, COUNT(DISTINCT table_id) as table_count',
          )
          .eq('business_id', businessId)
          .eq('created_by_uid', uid)
          .eq('status', 'completed')
          .gte('created_at', weekStart)
          .lte('created_at', now);

      // Month's completed orders
      final monthOrders = await sb
          .from('orders')
          .select(
            'COUNT(*) as total_count, COALESCE(SUM(total_amount), 0) as total_amount, COUNT(DISTINCT table_id) as table_count',
          )
          .eq('business_id', businessId)
          .eq('created_by_uid', uid)
          .eq('status', 'completed')
          .gte('created_at', monthStart)
          .lte('created_at', now);

      final all = allTimeOrders.isNotEmpty ? allTimeOrders[0] : {};
      final today = todayOrders.isNotEmpty ? todayOrders[0] : {};
      final week = weekOrders.isNotEmpty ? weekOrders[0] : {};
      final month = monthOrders.isNotEmpty ? monthOrders[0] : {};

      // Fetch shifts this week
      final shiftsWeek = await sb
          .from('shifts')
          .select('COUNT(*) as shift_count')
          .eq('business_id', businessId)
          .eq('staff_uid', uid)
          .gte('start_time', weekStart)
          .lte('start_time', now);

      final shiftCount = shiftsWeek.isNotEmpty
          ? (shiftsWeek[0]['shift_count'] as int? ?? 0)
          : 0;

      return {
        'ordersTodayCount': (today['total_count'] as int?) ?? 0,
        'revenueTodayAmount':
            ((today['total_amount'] as num?)?.toDouble() ?? 0.0),
        'tablesTodayCount': (today['table_count'] as int?) ?? 0,
        'ordersWeekCount': (week['total_count'] as int?) ?? 0,
        'revenueWeekAmount':
            ((week['total_amount'] as num?)?.toDouble() ?? 0.0),
        'tablesWeekCount': (week['table_count'] as int?) ?? 0,
        'avgOrderValueWeek':
            week['total_count'] != null && (week['total_count'] as int) > 0
            ? ((week['total_amount'] as num?)?.toDouble() ?? 0.0) /
                  (week['total_count'] as int)
            : 0.0,
        'ordersMonthCount': (month['total_count'] as int?) ?? 0,
        'revenueMonthAmount':
            ((month['total_amount'] as num?)?.toDouble() ?? 0.0),
        'tablesMonthCount': (month['table_count'] as int?) ?? 0,
        'avgOrderValueMonth':
            month['total_count'] != null && (month['total_count'] as int) > 0
            ? ((month['total_amount'] as num?)?.toDouble() ?? 0.0) /
                  (month['total_count'] as int)
            : 0.0,
        'ordersAllTimeCount': (all['total_count'] as int?) ?? 0,
        'revenueAllTimeAmount':
            ((all['total_amount'] as num?)?.toDouble() ?? 0.0),
        'tablesAllTimeCount': (all['table_count'] as int?) ?? 0,
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
