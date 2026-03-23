import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/repositories/profile_repository.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:pos_app/services/storage_service.dart';

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

      // 2. Fetch user profile from Repository
      final userProfile = await ProfileRepository.instance.loadProfile(uid);

      if (userProfile == null) {
        _error = 'User document not found.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      log(
        'Profile loaded for uid=$uid ==> ${userProfile['name'] ?? 'Unknown'}',
      );

      // ── Basic fields ───────────────────────────────────────────────────────
      final String name = userProfile['name'] as String? ?? '';
      final String email = userProfile['email'] as String? ?? '';
      final String phone = userProfile['phone'] as String? ?? '';
      final String role = userProfile['role'] as String? ?? 'staff';
      final String businessId = userProfile['businessId'] as String? ?? '';
      final String businessName = userProfile['businessName'] as String? ?? '';
      final String profilePhoto = userProfile['profilePhoto'] as String? ?? '';
      final bool isActive = userProfile['isActive'] as bool? ?? true;

      // ── Creator fields ─────────────────────────────────────────────────────
      final String createdBy = userProfile['createdBy'] as String? ?? '';
      final String createdByName =
          userProfile['createdByName'] as String? ?? '';
      final String createdByRole =
          userProfile['createdByRole'] as String? ?? '';

      // ── Timestamps ─────────────────────────────────────────────────────────
      final DateTime createdAt = userProfile['joinedDate'] != null
          ? DateTime.parse(userProfile['joinedDate'] as String)
          : DateTime.now();
      final DateTime? passwordLastChanged =
          userProfile['passwordLastChanged'] != null
          ? DateTime.parse(userProfile['passwordLastChanged'] as String)
          : null;
      final DateTime? updatedAt = userProfile['updatedAt'] != null
          ? DateTime.parse(userProfile['updatedAt'] as String)
          : null;

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
      _creatorRole = createdByRole.isNotEmpty
          ? _parseRole(createdByRole).label
          : '';

      log('creatorName="$_creatorName" creatorRole="$_creatorRole"');

      _isLoading = false;
      notifyListeners();

      // 5. Fetch performance stats from Supabase in background
      if (businessId.isNotEmpty) {
        await fetchUserStats(uid: uid, businessId: businessId);
      }
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
      // Delegate stats fetching to ProfileRepository
      final stats = await ProfileRepository.instance.fetchUserPerformanceStats(
        uid: uid,
        businessId: businessId,
      );

      _perfStats = UserPerformanceStats(
        ordersTodayCount: stats['ordersTodayCount'] as int,
        revenueTodayAmount: stats['revenueTodayAmount'] as double,
        tablesTodayCount: stats['tablesTodayCount'] as int,
        ordersWeekCount: stats['ordersWeekCount'] as int,
        revenueWeekAmount: stats['revenueWeekAmount'] as double,
        tablesWeekCount: stats['tablesWeekCount'] as int,
        avgOrderValueWeek: stats['avgOrderValueWeek'] as double,
        ordersMonthCount: stats['ordersMonthCount'] as int,
        revenueMonthAmount: stats['revenueMonthAmount'] as double,
        tablesMonthCount: stats['tablesMonthCount'] as int,
        avgOrderValueMonth: stats['avgOrderValueMonth'] as double,
        ordersAllTimeCount: stats['ordersAllTimeCount'] as int,
        revenueAllTimeAmount: stats['revenueAllTimeAmount'] as double,
        tablesAllTimeCount: stats['tablesAllTimeCount'] as int,
        shiftsThisWeek: stats['shiftsThisWeek'] as int,
      );

      log('perfStats → fetched');
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
      final Map<String, dynamic> updates = {};

      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (email != null && email.isNotEmpty) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;

      await ProfileRepository.instance.updateProfile(_profile!.id, updates);
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
  // _tsToDate removed as it is handled in Repository

  StaffRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return StaffRole.owner;
      case 'manager':
        return StaffRole.manager;
      case 'cashier':
        return StaffRole.cashier;
      case 'waiter':
      case 'server':
        return StaffRole.waiter;
      case 'chef':
        return StaffRole.chef;
      case 'admin':
      default:
        return StaffRole.owner;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
