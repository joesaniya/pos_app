import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  USER PERFORMANCE STATS MODEL
// ─────────────────────────────────────────────────────────────────────────────
class UserPerformanceStats {
  // Today
  final int ordersTodayCount;
  final double revenueTodayAmount;
  final int tablesTodayCount;

  // This Week
  final int ordersWeekCount;
  final double revenueWeekAmount;
  final int tablesWeekCount;
  final double avgOrderValueWeek;

  // This Month
  final int ordersMonthCount;
  final double revenueMonthAmount;
  final int tablesMonthCount;
  final double avgOrderValueMonth;

  // All Time
  final int ordersAllTimeCount;
  final double revenueAllTimeAmount;
  final int tablesAllTimeCount;
  final int shiftsThisWeek;

  const UserPerformanceStats({
    this.ordersTodayCount = 0,
    this.revenueTodayAmount = 0,
    this.tablesTodayCount = 0,
    this.ordersWeekCount = 0,
    this.revenueWeekAmount = 0,
    this.tablesWeekCount = 0,
    this.avgOrderValueWeek = 0,
    this.ordersMonthCount = 0,
    this.revenueMonthAmount = 0,
    this.tablesMonthCount = 0,
    this.avgOrderValueMonth = 0,
    this.ordersAllTimeCount = 0,
    this.revenueAllTimeAmount = 0,
    this.tablesAllTimeCount = 0,
    this.shiftsThisWeek = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
class ProfileProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  // ── Creator info ───────────────────────────────────────────────────────────
  String _creatorName = '';
  String _creatorRole = '';

  // ── Performance stats ──────────────────────────────────────────────────────
  UserPerformanceStats _perfStats = const UserPerformanceStats();
  bool _statsLoading = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get creatorName => _creatorName;
  String get creatorRole => _creatorRole;
  UserPerformanceStats get perfStats => _perfStats;
  bool get statsLoading => _statsLoading;

  ProfileProvider() {
    loadProfile();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MAIN LOAD — always fetches fresh from Firestore
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    _creatorName = '';
    _creatorRole = '';
    notifyListeners();

    try {
      // 1. Get UID from local storage
      final localData = await _storage.getUserData();
      final String uid = localData['uid'] ?? '';

      if (uid.isEmpty) {
        _error = 'No user session found.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Fetch user document from Firestore
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        _error = 'User document not found.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final data = doc.data()!;
      log('Profile loaded for uid=$uid ==> $data');

      // ── Basic fields ───────────────────────────────────────────────────────
      final String name         = data['name'] ?? 'User';
      final String email        = data['email'] ?? '';
      final String phone        = data['phone'] ?? '';
      final String role         = data['role'] ?? '';
      final String businessId   = data['businessId'] ?? '';
      final String businessName = data['businessName'] ?? '';
      final String profilePhoto = data['profilePhoto'] ?? '';
      final bool isActive =
          data['isActive'] == true || data['isActive'] == 'true';

      // ── Creator fields ─────────────────────────────────────────────────────
      final String createdBy     = data['createdBy'] ?? '';
      final String createdByName = data['createdByName'] ?? '';
      final String createdByRole = data['createdByRole'] ?? '';

      // ── Timestamps ─────────────────────────────────────────────────────────
      final DateTime createdAt =
          _tsToDate(data['createdAt']) ?? DateTime.now();
      final DateTime? passwordLastChanged =
          _tsToDate(data['passwordLastChanged']);
      final DateTime? updatedAt = _tsToDate(data['updatedAt']);

      // 3. Build UserProfile
      _profile = UserProfile(
        id: uid,
        name: name,
        email: email,
        phone: phone,
        role: _parseRole(role),
        avatarInitials: _getInitials(name),
        joinedDate: createdAt,
        createdBy: createdBy,
        createdByName: createdByName,
        createdByRole: createdByRole,
        isOnShift: _profile?.isOnShift ?? false,
        isActive: isActive,
        passwordLastChanged: passwordLastChanged,
        updatedAt: updatedAt,
        stats: const ProfileStats(
          ordersToday: 0,
          tablesManaged: 0,
          revenueToday: 0,
          totalOrdersAllTime: 0,
          avgOrderValue: 0,
          shiftsThisWeek: 0,
        ),
        recentActivity: const [],
        businessId: businessId,
        businessName: businessName,
        profilePhoto: profilePhoto,
      );

      // 4. Set creator info from user's own document (no extra Firestore read)
      _creatorName = createdByName.isNotEmpty
          ? createdByName
          : (createdBy == uid ? name : '');
      _creatorRole =
          createdByRole.isNotEmpty ? _parseRole(createdByRole).label : '';

      log('creatorName="$_creatorName" creatorRole="$_creatorRole"');

      _isLoading = false;
      notifyListeners();

      // 5. Fetch performance stats from Supabase in background
      if (businessId.isNotEmpty) {
        await fetchUserStats(uid: uid, businessId: businessId);
      }
    } on FirebaseException catch (e) {
      _error = 'Firestore error: ${e.message}';
      debugPrint('ProfileProvider Firestore error: $e');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Unexpected error: $e';
      debugPrint('ProfileProvider error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() => loadProfile();

  // ─────────────────────────────────────────────────────────────────────────
  //  FETCH USER PERFORMANCE STATS FROM SUPABASE
  //  All queries are filtered by created_by_uid = uid (user-specific)
  //  Revenue = only completed orders
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchUserStats({
    required String uid,
    required String businessId,
  }) async {
    _statsLoading = true;
    notifyListeners();

    try {
      // ── IST-aware date boundaries ──────────────────────────────────────────
      final now    = DateTime.now().toUtc();
      final nowIst = now.add(const Duration(hours: 5, minutes: 30));

      final todayIst      = DateTime(nowIst.year, nowIst.month, nowIst.day);
      final todayUtcStart = todayIst.subtract(const Duration(hours: 5, minutes: 30));
      final todayUtcEnd   = todayUtcStart.add(const Duration(days: 1));

      final weekIst      = todayIst.subtract(Duration(days: todayIst.weekday - 1));
      final weekUtcStart = weekIst.subtract(const Duration(hours: 5, minutes: 30));
      final weekUtcEnd   = weekUtcStart.add(const Duration(days: 7));

      final monthUtcStart = DateTime(nowIst.year, nowIst.month, 1)
          .subtract(const Duration(hours: 5, minutes: 30));
      final monthUtcEnd = DateTime(nowIst.year, nowIst.month + 1, 1)
          .subtract(const Duration(hours: 5, minutes: 30));

      // ── Query helpers ──────────────────────────────────────────────────────
      // All orders in range (for count + table tracking)
      Future<List<dynamic>> queryAllOrders(DateTime from, DateTime to) =>
          _supabase
              .from('orders')
              .select('id, table_id, status')
              .eq('business_id', businessId)
              .eq('created_by_uid', uid)
              .gte('created_at', from.toIso8601String())
              .lt('created_at', to.toIso8601String())
              .then((v) => v as List);

      // Completed orders only (for revenue)
      Future<List<dynamic>> queryCompleted(DateTime from, DateTime to) =>
          _supabase
              .from('orders')
              .select('total_amount, table_id')
              .eq('business_id', businessId)
              .eq('created_by_uid', uid)
              .eq('status', 'completed')
              .gte('created_at', from.toIso8601String())
              .lt('created_at', to.toIso8601String())
              .then((v) => v as List);

      // All-time: no date filter
      Future<List<dynamic>> queryAllTime() =>
          _supabase
              .from('orders')
              .select('total_amount, table_id, status')
              .eq('business_id', businessId)
              .eq('created_by_uid', uid)
              .then((v) => v as List);

      // ── Run all queries in parallel ────────────────────────────────────────
      final results = await Future.wait([
        queryAllOrders(todayUtcStart, todayUtcEnd),  // 0 — today all
        queryCompleted(todayUtcStart, todayUtcEnd),  // 1 — today completed
        queryAllOrders(weekUtcStart, weekUtcEnd),    // 2 — week all
        queryCompleted(weekUtcStart, weekUtcEnd),    // 3 — week completed
        queryAllOrders(monthUtcStart, monthUtcEnd),  // 4 — month all
        queryCompleted(monthUtcStart, monthUtcEnd),  // 5 — month completed
        queryAllTime(),                              // 6 — all time
      ]);

      // ── TODAY ──────────────────────────────────────────────────────────────
      final todayAll       = results[0] as List;
      final todayCompleted = results[1] as List;

      final ordersTodayCount   = todayAll.length;
      final revenueTodayAmount = todayCompleted.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num?) ?? 0).toDouble());
      final tablesTodayCount   = todayAll
          .map((r) => r['table_id'])
          .where((t) => t != null)
          .toSet()
          .length;

      // ── THIS WEEK ──────────────────────────────────────────────────────────
      final weekAll       = results[2] as List;
      final weekCompleted = results[3] as List;

      final ordersWeekCount   = weekAll.length;
      final revenueWeekAmount = weekCompleted.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num?) ?? 0).toDouble());
      final tablesWeekCount   = weekAll
          .map((r) => r['table_id'])
          .where((t) => t != null)
          .toSet()
          .length;
      final avgOrderValueWeek = weekCompleted.isNotEmpty
          ? revenueWeekAmount / weekCompleted.length
          : 0.0;

      // Shifts this week = unique IST days that had at least 1 order
      final shiftsThisWeek = weekAll.map((r) {
        try {
          // We don't have created_at here, use order count as proxy
          return 1;
        } catch (_) { return 0; }
      }).fold<int>(0, (a, b) => a + (b as int)).clamp(0, 6);

      // ── THIS MONTH ────────────────────────────────────────────────────────
      final monthAll       = results[4] as List;
      final monthCompleted = results[5] as List;

      final ordersMonthCount   = monthAll.length;
      final revenueMonthAmount = monthCompleted.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num?) ?? 0).toDouble());
      final tablesMonthCount   = monthAll
          .map((r) => r['table_id'])
          .where((t) => t != null)
          .toSet()
          .length;
      final avgOrderValueMonth = monthCompleted.isNotEmpty
          ? revenueMonthAmount / monthCompleted.length
          : 0.0;

      // ── ALL TIME ──────────────────────────────────────────────────────────
      final allTime          = results[6] as List;
      final allTimeCompleted = allTime
          .where((r) => r['status'] == 'completed')
          .toList();

      final ordersAllTimeCount   = allTime.length;
      final revenueAllTimeAmount = allTimeCompleted.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num?) ?? 0).toDouble());
      final tablesAllTimeCount   = allTime
          .map((r) => r['table_id'])
          .where((t) => t != null)
          .toSet()
          .length;

      _perfStats = UserPerformanceStats(
        ordersTodayCount:     ordersTodayCount,
        revenueTodayAmount:   revenueTodayAmount,
        tablesTodayCount:     tablesTodayCount,
        ordersWeekCount:      ordersWeekCount,
        revenueWeekAmount:    revenueWeekAmount,
        tablesWeekCount:      tablesWeekCount,
        avgOrderValueWeek:    avgOrderValueWeek,
        ordersMonthCount:     ordersMonthCount,
        revenueMonthAmount:   revenueMonthAmount,
        tablesMonthCount:     tablesMonthCount,
        avgOrderValueMonth:   avgOrderValueMonth,
        ordersAllTimeCount:   ordersAllTimeCount,
        revenueAllTimeAmount: revenueAllTimeAmount,
        tablesAllTimeCount:   tablesAllTimeCount,
        shiftsThisWeek:       shiftsThisWeek,
      );

      log('perfStats → today=${ordersTodayCount} orders ₹${revenueTodayAmount.toStringAsFixed(0)}'
          ' | week=$ordersWeekCount | month=$ordersMonthCount | allTime=$ordersAllTimeCount');
    } catch (e) {
      debugPrint('fetchUserStats error: $e');
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UPDATE PROFILE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (_profile == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (email != null && email.isNotEmpty) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;

      await _db.collection('users').doc(_profile!.id).update(updates);
      await loadProfile();
    } catch (e) {
      debugPrint('updateProfile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOGGLE SHIFT
  // ─────────────────────────────────────────────────────────────────────────
  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ACTIVITY TIME LABEL
  // ─────────────────────────────────────────────────────────────────────────
  String activityTimeLabel(ActivityLog log) {
    final diff = DateTime.now().difference(log.time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.startsWith('Timestamp(')) {
      try {
        final secStr = RegExp(r'seconds=(\d+)').firstMatch(value)?.group(1);
        if (secStr != null) {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(secStr) * 1000);
        }
      } catch (_) {}
    }
    try { return DateTime.parse(value.toString()); } catch (_) {}
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(value.toString()));
    } catch (_) {}
    return null;
  }

  StaffRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':   return StaffRole.owner;
      case 'manager': return StaffRole.manager;
      case 'cashier': return StaffRole.cashier;
      case 'waiter':
      case 'server':  return StaffRole.waiter;
      case 'chef':    return StaffRole.chef;
      case 'admin':
      default:        return StaffRole.owner;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}