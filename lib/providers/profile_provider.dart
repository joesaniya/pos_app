import 'dart:developer';

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

  // ── Creator info (read directly from the user's own document) ─
  String _creatorName = '';
  String _creatorRole = '';

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get creatorName => _creatorName;
  String get creatorRole => _creatorRole;

  ProfileProvider() {
    loadProfile();
  }

  // ─────────────────────────────────────────────────────────
  //  MAIN LOAD — always fetches fresh from Firestore
  // ─────────────────────────────────────────────────────────
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

      // ── Basic fields ──────────────────────────────────────
      final String name = data['name'] ?? 'User';
      final String email = data['email'] ?? '';
      final String phone = data['phone'] ?? '';
      final String role = data['role'] ?? '';
      final String businessId = data['businessId'] ?? '';
      final String businessName = data['businessName'] ?? '';
      final String profilePhoto = data['profilePhoto'] ?? '';
      final bool isActive =
          data['isActive'] == true || data['isActive'] == 'true';

      // ── Creator fields — stored on the user's OWN document ─
      // These were written at account-creation time by CreateAccountProvider
      // so we never need to read another user's document.
      final String createdBy = data['createdBy'] ?? '';
      final String createdByName = data['createdByName'] ?? '';
      final String createdByRole = data['createdByRole'] ?? '';

      // ── Timestamps ────────────────────────────────────────
      final DateTime createdAt = _tsToDate(data['createdAt']) ?? DateTime.now();
      final DateTime? passwordLastChanged = _tsToDate(
        data['passwordLastChanged'],
      );
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

      // 4. Set creator info directly from the user's own document
      //    ✅ No extra Firestore read — no permission issues
      _creatorName = createdByName.isNotEmpty
          ? createdByName
          : (createdBy == uid ? name : ''); // fallback: self-registered
      _creatorRole = createdByRole.isNotEmpty
          ? _parseRole(createdByRole).label
          : '';

      log('creatorName="$_creatorName" creatorRole="$_creatorRole"');

      _isLoading = false;
      notifyListeners();
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

  // ─────────────────────────────────────────────────────────
  //  UPDATE PROFILE
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
      await loadProfile();
    } catch (e) {
      debugPrint('updateProfile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  TOGGLE SHIFT
  // ─────────────────────────────────────────────────────────
  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  //  ACTIVITY TIME LABEL
  // ─────────────────────────────────────────────────────────
  String activityTimeLabel(ActivityLog log) {
    final diff = DateTime.now().difference(log.time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────
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
    try {
      return DateTime.parse(value.toString());
    } catch (_) {}
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


/*import 'dart:developer';

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

  // ── Creator info fetched separately ───────────────────────────
  String _creatorName = '';
  String _creatorRole = '';
  bool _isLoadingCreator = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get creatorName => _creatorName;
  String get creatorRole => _creatorRole;
  bool get isLoadingCreator => _isLoadingCreator;

  ProfileProvider() {
    loadProfile();
  }

  // ─────────────────────────────────────────────────────────
  //  MAIN LOAD — always fetches fresh from Firestore
  // ─────────────────────────────────────────────────────────
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
      log('Profile data for cre ${data['createdBy']}==> $data');
      final String name = data['name'] ?? 'User';
      final String email = data['email'] ?? '';
      final String phone = data['phone'] ?? '';
      final String role = data['role'] ?? '';
      final String businessId = data['businessId'] ?? '';
      final String businessName = data['businessName'] ?? '';
      final String createdBy = data['createdBy'] ?? '';
      final String createdByName = data['createdByName'] ?? 'System';
      final String createdByRole = data['createdByRole'] ?? 'System';
      final String profilePhoto = data['profilePhoto'] ?? '';
      final bool isActive =
          data['isActive'] == true || data['isActive'] == 'true';

      final DateTime createdAt = _tsToDate(data['createdAt']) ?? DateTime.now();
      final DateTime? passwordLastChanged = _tsToDate(
        data['passwordLastChanged'],
      );
      final DateTime? updatedAt = _tsToDate(data['updatedAt']);

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

      _isLoading = false;
      notifyListeners();

      // 3. Now fetch creator name+role in background (non-blocking)
      //    This does a second Firestore read using the createdBy UID
      if (createdBy.isNotEmpty) {
        _fetchCreatorInfo(createdBy, currentUserId: uid);
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

  // ─────────────────────────────────────────────────────────
  //  FETCH CREATOR INFO
  //  Looks up the createdBy UID in Firestore to get name + role
  // ─────────────────────────────────────────────────────────
  Future<void> _fetchCreatorInfo(
    String creatorUid, {
    required String currentUserId,
  }) async {
    // If creator is the same person (owner who registered themselves)
    if (creatorUid == currentUserId) {
      _creatorName = _profile?.name ?? '';
      _creatorRole = _profile?.role.label ?? '';
      notifyListeners();
      return;
    }

    _isLoadingCreator = true;
    notifyListeners();

    try {
      final doc = await _db.collection('users').doc(creatorUid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _creatorName = data['name'] ?? '';
        _creatorRole = _parseRole(data['role'] ?? '').label;
      } else {
        _creatorName = 'Unknown';
        _creatorRole = '';
      }
    } catch (e) {
      debugPrint('_fetchCreatorInfo error: $e');
      _creatorName = 'Unknown';
      _creatorRole = '';
    } finally {
      _isLoadingCreator = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() => loadProfile();

  // ─────────────────────────────────────────────────────────
  //  UPDATE PROFILE
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
      await loadProfile();
    } catch (e) {
      debugPrint('updateProfile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  TOGGLE SHIFT
  // ─────────────────────────────────────────────────────────
  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────
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
    try {
      return DateTime.parse(value.toString());
    } catch (_) {}
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
      case 'server':
        return StaffRole.waiter;
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
*/