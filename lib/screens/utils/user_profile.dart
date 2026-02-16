enum StaffRole { owner, manager, cashier, waiter, chef }

extension StaffRoleLabel on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.owner:   return 'Owner';
      case StaffRole.manager: return 'Manager';
      case StaffRole.cashier: return 'Cashier';
      case StaffRole.waiter:  return 'Waiter';
      case StaffRole.chef:    return 'Chef';
    }
  }

  String get emoji {
    switch (this) {
      case StaffRole.owner:   return '👑';
      case StaffRole.manager: return '💼';
      case StaffRole.cashier: return '🧾';
      case StaffRole.waiter:  return '🍽️';
      case StaffRole.chef:    return '👨‍🍳';
    }
  }
}

class ActivityLog {
  final String title;
  final String subtitle;
  final DateTime time;
  final String icon;

  const ActivityLog({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });
}

class ProfileStats {
  final int ordersToday;
  final int tablesManaged;
  final double revenueToday;
  final int totalOrdersAllTime;
  final double avgOrderValue;
  final int shiftsThisWeek;

  const ProfileStats({
    required this.ordersToday,
    required this.tablesManaged,
    required this.revenueToday,
    required this.totalOrdersAllTime,
    required this.avgOrderValue,
    required this.shiftsThisWeek,
  });
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final StaffRole role;
  final String? avatarInitials;
  final DateTime joinedDate;
  final bool isOnShift;
  final ProfileStats stats;
  final List<ActivityLog> recentActivity;

  // Settings
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool darkModeEnabled;
  final String language;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarInitials,
    required this.joinedDate,
    required this.isOnShift,
    required this.stats,
    required this.recentActivity,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.darkModeEnabled = false,
    this.language = 'English',
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? darkModeEnabled,
    String? language,
    bool? isOnShift,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      avatarInitials: avatarInitials,
      joinedDate: joinedDate,
      isOnShift: isOnShift ?? this.isOnShift,
      stats: stats,
      recentActivity: recentActivity,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      language: language ?? this.language,
    );
  }

  String get formattedJoinDate {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[joinedDate.month - 1]} ${joinedDate.year}';
  }

  String get tenureLabel {
    final diff = DateTime.now().difference(joinedDate);
    final months = (diff.inDays / 30).floor();
    if (months < 1) return '${diff.inDays} days';
    if (months < 12) return '$months month${months > 1 ? 's' : ''}';
    final years = (months / 12).floor();
    return '$years year${years > 1 ? 's' : ''}';
  }
}