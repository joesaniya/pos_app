// lib/utils/promo_code_access_control.dart
// ══════════════════════════════════════════════════════════════════════════════
//  PROMO CODE MANAGEMENT - ROLE-BASED ACCESS CONTROL (RBAC)
// ══════════════════════════════════════════════════════════════════════════════
//
// This utility provides centralized role-based access control for the
// Promo Code Management feature across the entire application.
//
// Authorized Roles (highest to lowest privilege):
//   1. system   - 👑 System Admin (absolute access)
//   2. owner    - 👑 Business Owner (full access)
//   3. admin    - ⚡ Admin (full access)
//   4. manager  - 👔 Manager (full access)
//
// Restricted Roles:
//   - cashier, waiter, chef, staff, etc. (no access - hidden/disabled)

/// Utility class for Promo Code Management access control
class PromoCodeAccessControl {
  // Authorized roles that can access Promo Code Management
  static const List<String> _authorizedRoles = [
    'system',
    'owner',
    'admin',
    'manager',
  ];

  /// Check if a user role is authorized to manage promo codes
  ///
  /// Returns true if the role is in the authorized list (case-insensitive)
  /// Returns false otherwise (including null/empty roles)
  static bool canManagePromoCodes(String? userRole) {
    if (userRole == null || userRole.isEmpty) return false;
    return _authorizedRoles.contains(userRole.toLowerCase());
  }

  /// Check if Promo Code Management should be visible in UI
  ///
  /// This is used for conditional rendering in the Profile screen menu.
  /// Unauthorized users will not see the option at all.
  static bool isPromoManagementVisible(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if Promo Code Management should be enabled (clickable)
  ///
  /// This is used for button/menu item enable/disable state.
  /// When disabled and visible, the option appears greyed out.
  static bool isPromoManagementEnabled(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Get user-friendly explanation for why access is denied
  ///
  /// Used for tooltips when hovering over disabled menu items.
  /// Returns appropriate message based on role type.
  static String getAccessDeniedReason(String? userRole) {
    if (userRole == null || userRole.isEmpty) {
      return 'Please log in to access this feature.';
    }

    final roleName = userRole.toLowerCase();
    return 'Promo Code Management is available only for:\n'
        'Owner, Manager, Admin, or System Admin roles.\n'
        'Current role: ${_getRoleDisplayName(roleName)}';
  }

  /// Get display name for a role with emoji
  ///
  /// Used in error messages, tooltips, and debug logs.
  static String _getRoleDisplayName(String role) {
    switch (role) {
      case 'owner':
        return '👑 Owner';
      case 'system':
        return '👑 System Admin';
      case 'admin':
        return '⚡ Admin';
      case 'manager':
        return '👔 Manager';
      case 'cashier':
        return '🧾 Cashier';
      case 'waiter':
      case 'server':
        return '🍽️ Waiter/Server';
      case 'chef':
        return '👨‍🍳 Chef';
      case 'staff':
        return '👤 Staff';
      default:
        return '👤 $role';
    }
  }

  /// Get color indicator for authorization status
  ///
  /// Used for UI styling of menu items.
  /// Green for authorized, grey for restricted.
  static String getAuthorizationColor(String? userRole) {
    return canManagePromoCodes(userRole) ? 'authorized' : 'restricted';
  }

  /// Validate role before allowing action in backend
  ///
  /// Called by PromoCodeService before performing CRUD operations.
  /// Returns error message if unauthorized, null if authorized.
  static String? validateAccessForBackendAction(String? userRole) {
    if (!canManagePromoCodes(userRole)) {
      return 'UNAUTHORIZED: User role "$userRole" is not authorized to manage promo codes.';
    }
    return null; // null means authorized
  }

  /// Check if user can view all promo codes
  /// (All authorized roles have this permission)
  static bool canViewAllPromoCodes(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if user can create new promo codes
  /// (All authorized roles have this permission)
  static bool canCreatePromoCode(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if user can edit promo codes
  /// (All authorized roles have this permission)
  static bool canEditPromoCode(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if user can delete promo codes
  /// (All authorized roles have this permission)
  static bool canDeletePromoCode(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if user can deactivate/activate promo codes
  /// (All authorized roles have this permission)
  static bool canDeactivatePromoCode(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Check if user can view analytics for promo codes
  /// (All authorized roles have this permission)
  static bool canViewPromoAnalytics(String? userRole) {
    return canManagePromoCodes(userRole);
  }

  /// Get list of all authorized roles for documentation/reference
  static List<String> getAuthorizedRoles() {
    return List<String>.unmodifiable(_authorizedRoles);
  }

  /// Log access attempt for audit trail
  ///
  /// Can be extended to log which user attempted which action.
  static void logAccessAttempt(
    String? userRole,
    String action,
    bool authorized,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    final status = authorized ? '✅ ALLOWED' : '❌ DENIED';
    print(
      '[PromoCodeRBAC] $status | '
      'Role: $userRole | '
      'Action: $action | '
      'Time: $timestamp',
    );
  }
}
