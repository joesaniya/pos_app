import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:pos_app/services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  UserProfile? _profile;
  bool _isLoading = true; // starts true so skeleton shows immediately
  bool _isEditing = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;

  ProfileProvider() {
    _loadProfileFromStorage();
  }

  // ── Load from SharedPreferences ───────────────────────────
  Future<void> _loadProfileFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _storage.getUserData();

      final String name = data['name'] ?? 'User';
      final StaffRole role = _parseRole(data['role'] ?? '');
      final String initials = _getInitials(name);

      _profile = UserProfile(
        id: data['uid'] ?? '',
        name: name,
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        role: role,
        avatarInitials: initials,
        joinedDate:
            DateTime.now(), // swap in stored createdAt if you persist it
        isOnShift: false,
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
      debugPrint('ProfileProvider._loadProfileFromStorage error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call this after login to refresh the profile without recreating the provider.
  Future<void> reloadProfile() => _loadProfileFromStorage();

  // ── Helpers ───────────────────────────────────────────────
  StaffRole _parseRole(String role) {
    log(' Parsing role: $role');
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
        return StaffRole.owner; // 'admin' maps to owner/full access
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ── Actions ───────────────────────────────────────────────
  void setEditing(bool value) {
    _isEditing = value;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (_profile == null) return;
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _profile = _profile!.copyWith(name: name, email: email, phone: phone);

    // Persist updated values back to SharedPreferences
    final storedData = await _storage.getUserData();
    await _storage.saveUserData(
      uid: _profile!.id,
      token: await _storage.getAuthToken() ?? '',
      name: _profile!.name,
      email: _profile!.email,
      phone: _profile!.phone,
      role: storedData['role'] ?? '',
      businessId: _profile!.businessId,
      businessName: _profile!.businessName,
      profilePhoto: _profile!.profilePhoto.isEmpty
          ? null
          : _profile!.profilePhoto,
    );

    _isLoading = false;
    _isEditing = false;
    notifyListeners();
  }

  void toggleShift() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(isOnShift: !_profile!.isOnShift);
    notifyListeners();
  }

  void toggleNotifications() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      notificationsEnabled: !_profile!.notificationsEnabled,
    );
    notifyListeners();
  }

  void toggleSound() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(soundEnabled: !_profile!.soundEnabled);
    notifyListeners();
  }

  void toggleDarkMode() {
    if (_profile == null) return;
    _profile = _profile!.copyWith(darkModeEnabled: !_profile!.darkModeEnabled);
    notifyListeners();
  }

  String _formatActivityTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String activityTimeLabel(ActivityLog log) => _formatActivityTime(log.time);
}
/*import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  late UserProfile _profile;
  bool _isLoading = false;
  bool _isEditing = false;

  ProfileProvider() {
    _profile = UserProfile(
      id: 'usr_001',
      name: 'Esther Jenslin',
      email: 'esther.jenslin@srisoftwarez.in',
      phone: '+91 98765 43210',
      role: StaffRole.manager,
      avatarInitials: 'EJ',
      joinedDate: DateTime(2022, 3, 15),
      isOnShift: true,
      stats: const ProfileStats(
        ordersToday: 24,
        tablesManaged: 8,
        revenueToday: 18450.0,
        totalOrdersAllTime: 3842,
        avgOrderValue: 485.0,
        shiftsThisWeek: 5,
      ),
      recentActivity: [
        ActivityLog(
          title: 'Order #4523 completed',
          subtitle: 'Table 1 · ₹1,250',
          time: DateTime.now().subtract(const Duration(minutes: 12)),
          icon: '✅',
        ),
        ActivityLog(
          title: 'Table 3 reserved',
          subtitle: 'Mike Johnson · 2:00 PM',
          time: DateTime.now().subtract(const Duration(minutes: 28)),
          icon: '📅',
        ),
        ActivityLog(
          title: 'New item added to menu',
          subtitle: 'Ghee Roast Dosa · ₹140',
          time: DateTime.now().subtract(const Duration(hours: 1)),
          icon: '🍽️',
        ),
        ActivityLog(
          title: 'Shift started',
          subtitle: 'Check-in at 9:00 AM',
          time: DateTime.now().subtract(const Duration(hours: 3)),
          icon: '🕐',
        ),
        ActivityLog(
          title: 'Order #4519 completed',
          subtitle: 'Table 6 · ₹850',
          time: DateTime.now().subtract(const Duration(hours: 4)),
          icon: '✅',
        ),
      ],
    );
  }

  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;

  void setEditing(bool value) {
    _isEditing = value;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Simulate network call
    await Future.delayed(const Duration(milliseconds: 600));

    _profile = _profile.copyWith(name: name, email: email, phone: phone);
    _isLoading = false;
    _isEditing = false;
    notifyListeners();
  }

  void toggleShift() {
    _profile = _profile.copyWith(isOnShift: !_profile.isOnShift);
    notifyListeners();
  }

  void toggleNotifications() {
    _profile = _profile.copyWith(
      notificationsEnabled: !_profile.notificationsEnabled,
    );
    notifyListeners();
  }

  void toggleSound() {
    _profile = _profile.copyWith(soundEnabled: !_profile.soundEnabled);
    notifyListeners();
  }

  void toggleDarkMode() {
    _profile = _profile.copyWith(darkModeEnabled: !_profile.darkModeEnabled);
    notifyListeners();
  }

  String _formatActivityTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String activityTimeLabel(ActivityLog log) => _formatActivityTime(log.time);
}
*/