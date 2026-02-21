// lib/screens/utils/user_profile.dart

import 'package:flutter/material.dart';

enum StaffRole { owner, manager, cashier, waiter, chef }

extension StaffRoleLabel on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.owner:
        return 'Owner';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.cashier:
        return 'Cashier';
      case StaffRole.waiter:
        return 'Waiter';
      case StaffRole.chef:
        return 'Chef';
    }
  }

  String get emoji {
    switch (this) {
      case StaffRole.owner:
        return '👑';
      case StaffRole.manager:
        return '💼';
      case StaffRole.cashier:
        return '🧾';
      case StaffRole.waiter:
        return '🍽️';
      case StaffRole.chef:
        return '👨‍🍳';
    }
  }

  Color get color {
    switch (this) {
      case StaffRole.owner:
        return const Color(0xFF6366F1);
      case StaffRole.manager:
        return const Color(0xFF1A56DB);
      case StaffRole.cashier:
        return const Color(0xFF0D9488);
      case StaffRole.waiter:
        return const Color(0xFF10B981);
      case StaffRole.chef:
        return const Color(0xFFF59E0B);
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
  final String id; // uid
  final String name;
  final String email;
  final String phone;
  final StaffRole role;
  final String? avatarInitials;
  final DateTime joinedDate; // createdAt
  final String createdBy; // createdBy (uid of creator)
  final bool isOnShift;
  final bool isActive;
  final ProfileStats stats;
  final List<ActivityLog> recentActivity;

  // Business
  final String businessId;
  final String businessName;
  final String profilePhoto;

  // Timestamps
  final DateTime? passwordLastChanged;
  final DateTime? updatedAt;

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
    this.createdBy = '',
    required this.isOnShift,
    this.isActive = true,
    required this.stats,
    required this.recentActivity,
    this.businessId = '',
    this.businessName = '',
    this.profilePhoto = '',
    this.passwordLastChanged,
    this.updatedAt,
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
    bool? isActive,
    DateTime? passwordLastChanged,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      avatarInitials: avatarInitials,
      joinedDate: joinedDate,
      createdBy: createdBy,
      isOnShift: isOnShift ?? this.isOnShift,
      isActive: isActive ?? this.isActive,
      stats: stats,
      recentActivity: recentActivity,
      businessId: businessId,
      businessName: businessName,
      profilePhoto: profilePhoto,
      passwordLastChanged: passwordLastChanged ?? this.passwordLastChanged,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      language: language ?? this.language,
    );
  }

  // ── Computed getters ──────────────────────────────────────

  String get formattedJoinDate => _fmt(joinedDate);

  String get tenureLabel {
    final diff = DateTime.now().difference(joinedDate);
    final months = (diff.inDays / 30).floor();
    if (months < 1) return '${diff.inDays}d';
    if (months < 12) return '${months}mo';
    final years = (months / 12).floor();
    return '${years}yr';
  }

  /// Formats passwordLastChanged for display — returns null if not set
  String? get passwordLastChangedLabel =>
      passwordLastChanged != null ? _fmtFull(passwordLastChanged!) : null;

  /// Formats updatedAt for display — returns null if not set
  String? get updatedAtLabel => updatedAt != null ? _fmtFull(updatedAt!) : null;

  static String _fmt(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.year}';
  }

  static String _fmtFull(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
