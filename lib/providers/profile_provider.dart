
import 'dart:developer';
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
