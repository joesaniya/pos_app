import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:pos_app/services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProfileProvider() {
    loadProfile();
  }

  // ─────────────────────────────────────────────────────────
  //  MAIN LOAD — always fetches fresh from Firestore
  // ─────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Get UID from local storage (only thing we need stored locally)
      final localData = await _storage.getUserData();
      final String uid = localData['uid'] ?? '';

      if (uid.isEmpty) {
        _error = 'No user session found.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Fetch complete user document from Firestore
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        _error = 'User document not found.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final data = doc.data()!;

      // 3. Parse all fields
      final String name = data['name'] ?? 'User';
      final String email = data['email'] ?? '';
      final String phone = data['phone'] ?? '';
      final String role = data['role'] ?? '';
      final String businessId = data['businessId'] ?? '';
      final String businessName = data['businessName'] ?? '';
      final String createdBy = data['createdBy'] ?? '';
      final String profilePhoto = data['profilePhoto'] ?? '';
      final bool isActive =
          data['isActive'] == true || data['isActive'] == 'true';

      // 4. Parse Firestore Timestamps
      final DateTime createdAt = _tsToDate(data['createdAt']) ?? DateTime.now();
      final DateTime? passwordLastChanged = _tsToDate(
        data['passwordLastChanged'],
      );
      final DateTime? updatedAt = _tsToDate(data['updatedAt']);

      // 5. Build profile
      _profile = UserProfile(
        id: uid,
        name: name,
        email: email,
        phone: phone,
        role: _parseRole(role),
        avatarInitials: _getInitials(name),
        joinedDate: createdAt,
        createdBy: createdBy,
        isOnShift: _profile?.isOnShift ?? false, // preserve shift state
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
    } on FirebaseException catch (e) {
      _error = 'Firestore error: ${e.message}';
      debugPrint('ProfileProvider Firestore error: $e');
    } catch (e) {
      _error = 'Unexpected error: $e';
      debugPrint('ProfileProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() => loadProfile();

  // ─────────────────────────────────────────────────────────
  //  UPDATE PROFILE — writes to Firestore then reloads
  // ─────────────────────────────────────────────────────────
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

      // Reload fresh data from Firestore
      await loadProfile();
    } catch (e) {
      debugPrint('updateProfile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  TOGGLE SHIFT — local only (not persisted to Firestore)
  // ─────────────────────────────────────────────────────────
  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────

  /// Converts Firestore Timestamp, ISO string, or epoch millis → DateTime
  DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;

    // Native Firestore Timestamp object
    if (value is Timestamp) {
      return value.toDate();
    }

    // Timestamp toString: "Timestamp(seconds=..., nanoseconds=...)"
    if (value is String && value.startsWith('Timestamp(')) {
      try {
        final secStr = RegExp(r'seconds=(\d+)').firstMatch(value)?.group(1);
        if (secStr != null) {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(secStr) * 1000);
        }
      } catch (_) {}
    }

    // ISO 8601
    try {
      return DateTime.parse(value.toString());
    } catch (_) {}

    // Epoch millis
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(value.toString()));
    } catch (_) {}

    return null;
  }

  StaffRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return StaffRole.owner;
      case 'manager':
        return StaffRole.manager;
      case 'cashier':
        return StaffRole.cashier;
      case 'waiter':
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

  String activityTimeLabel(ActivityLog log) {
    final diff = DateTime.now().difference(log.time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}



/*import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:pos_app/services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  UserProfile? _profile;
  bool _isLoading = true;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    _loadProfileFromStorage();
  }

  Future<void> _loadProfileFromStorage() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _storage.getUserData();

      final String name = data['name'] ?? 'User';
      final StaffRole role = _parseRole(data['role'] ?? '');
      final String initials = _getInitials(name);

      // ── Parse all timestamp fields from storage ──────────
      // Firestore timestamps are stored as ISO strings or millis
      final DateTime? passwordLastChanged = _parseDateTime(
        data['passwordLastChanged'],
      );
      final DateTime? updatedAt = _parseDateTime(data['updatedAt']);
      final DateTime createdAt =
          _parseDateTime(data['createdAt']) ?? DateTime.now();

      final bool isActive =
          data['isActive'] == true || data['isActive'] == 'true';

      _profile = UserProfile(
        id: data['uid'] ?? '',
        name: name,
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        role: role,
        avatarInitials: initials,
        joinedDate: createdAt,
        createdBy: data['createdBy'] ?? '',
        isOnShift: false,
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
        businessId: data['businessId'] ?? '',
        businessName: data['businessName'] ?? '',
        profilePhoto: data['profilePhoto'] ?? '',
      );
    } catch (e) {
      debugPrint('ProfileProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() => _loadProfileFromStorage();

  // ── Helpers ──────────────────────────────────────────────

  StaffRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return StaffRole.owner;
      case 'manager':
        return StaffRole.manager;
      case 'cashier':
        return StaffRole.cashier;
      case 'waiter':
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

  /// Safely parse Firestore Timestamp strings, ISO strings, or epoch millis.
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    // Firestore Timestamp toString: "Timestamp(seconds=..., nanoseconds=...)"
    if (value is String && value.startsWith('Timestamp(')) {
      try {
        final secStr = RegExp(r'seconds=(\d+)').firstMatch(value)?.group(1);
        if (secStr != null) {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(secStr) * 1000);
        }
      } catch (_) {}
    }
    // ISO 8601
    try {
      return DateTime.parse(value.toString());
    } catch (_) {}
    // Epoch millis
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(value.toString()));
    } catch (_) {}
    return null;
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (_profile == null) return;
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    _profile = _profile!.copyWith(
      name: name,
      email: email,
      phone: phone,
      updatedAt: DateTime.now(),
    );
    final stored = await _storage.getUserData();
    await _storage.saveUserData(
      uid: _profile!.id,
      token: await _storage.getAuthToken() ?? '',
      name: _profile!.name,
      email: _profile!.email,
      phone: _profile!.phone,
      role: stored['role'] ?? '',
      businessId: _profile!.businessId,
      businessName: _profile!.businessName,
      profilePhoto: _profile!.profilePhoto.isEmpty
          ? null
          : _profile!.profilePhoto,
    );
    _isLoading = false;
    notifyListeners();
  }

  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  String activityTimeLabel(ActivityLog log) {
    final diff = DateTime.now().difference(log.time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
*/