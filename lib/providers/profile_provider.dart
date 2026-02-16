import 'package:flutter/material.dart';
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
