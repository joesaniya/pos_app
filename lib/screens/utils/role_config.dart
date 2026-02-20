import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class RoleConfig {
  final String value;
  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final Color light;
  final Color border;
  final String tag;

  const RoleConfig({
    required this.value,
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.light,
    required this.border,
    required this.tag,
  });

  static const List<RoleConfig> all = [
    RoleConfig(
      value: 'admin',
      label: 'Admin',
      caption: 'Full control over staff, reports & settings',
      icon: Icons.shield_rounded,
      color: Color(0xFF1B4332),
      light: Color(0xFFEAF3EE),
      border: Color(0xFFB7D9C4),
      tag: 'ALL ACCESS',
    ),
    RoleConfig(
      value: 'manager',
      label: 'Manager',
      caption: 'Oversee team performance and sales reports',
      icon: Icons.leaderboard_rounded,
      color: Color(0xFF2C5282),
      light: Color(0xFFEBF0FA),
      border: Color(0xFFB3C8EE),
      tag: 'OVERSIGHT',
    ),
    RoleConfig(
      value: 'server',
      label: 'Server',
      caption: 'Handle orders, tables and daily billing',
      icon: Icons.room_service_rounded,
      color: Color(0xFF92400E),
      light: Color(0xFFFBF4EA),
      border: Color(0xFFE8C99A),
      tag: 'OPERATIONS',
    ),
  ];

  static RoleConfig? fromValue(String value) {
    try {
      return all.firstWhere((r) => r.value == value);
    } catch (_) {
      return null;
    }
  }
}