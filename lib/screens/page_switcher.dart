import 'package:flutter/material.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/page_switcher_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/profile_screen.dart';
import 'package:pos_app/screens/tables_screen/tables_screen1.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/widgets/sync_status_widget.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'package:pos_app/screens/subscription_expired_screen.dart';
import 'menu_screen.dart';
import 'inventory_screen.dart';
import 'expenses_screen.dart';

class PageSwitcher extends StatefulWidget {
  const PageSwitcher({Key? key}) : super(key: key);

  @override
  State<PageSwitcher> createState() => _PageSwitcherState();
}

class _PageSwitcherState extends State<PageSwitcher> {
  bool _validating = true;
  bool _sessionValid = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final authProvider = context.read<AppAuthenticationProvider>();
      final valid = await authProvider.validateSession();

      if (!mounted) return;

      if (!valid) {
        if (authProvider.subscriptionExpired) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const SubscriptionExpiredScreen(),
            ),
            (route) => false,
          );
          return;
        }

        final wasDeactivated = authProvider.wasDeactivated;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        if (wasDeactivated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your account has been deactivated. Please contact your admin.',
                ),
                backgroundColor: Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
        return;
      }

      await context.read<PageSwitcherProvider>().loadRole();

      if (!mounted) return;
      setState(() {
        _sessionValid = true;
        _validating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_validating) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1847C4)),
        ),
      );
    }

    if (!_sessionValid) {
      return const LoginScreen();
    }

    return Consumer<AppAuthenticationProvider>(
      builder: (context, auth, child) {
        if (auth.wasDeactivated || auth.subscriptionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (auth.wasDeactivated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your account has been deactivated. Please contact your admin.',
                  ),
                  backgroundColor: Color(0xFFE11D48),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            } else if (auth.subscriptionExpired) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionExpiredScreen(),
                ),
                (route) => false,
              );
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFFF4F7FF),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1847C4)),
            ),
          );
        }

        return child!;
      },
      child: Consumer<PageSwitcherProvider>(
        builder: (context, navigationProvider, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F7FF),
            // ── Network Sync Banner fixed at very top, above everything ──────
            body: Column(
              children: [
                // Sits above SafeArea intentionally — banner is flush to top
                const NetworkSyncTrackerBar(),
                // Everything else respects safe area
                Expanded(
                  child: SafeArea(
                    top: false, // banner already handles top spacing
                    child: IndexedStack(
                      index: navigationProvider.selectedIndex,
                      children: [
                        const DashboardScreen(),
                        const OrdersScreen(),
                        const TablesScreen(),
                        const MenuScreen(),
                        if (navigationProvider.canAccessInventory)
                          const InventoryScreen()
                        else
                          const SizedBox.shrink(),
                        if (navigationProvider.canAccessExpenses)
                          const ExpensesScreen()
                        else
                          const SizedBox.shrink(),
                        const ProfileScreen(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: const BottomNavBar(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PageSwitcherProvider>(
      builder: (context, navigationProvider, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppSizes.paddingSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: navigationProvider.selectedIndex == 0,
                    onTap: () => navigationProvider.setSelectedIndex(0),
                  ),
                  _NavItem(
                    index: 1,
                    icon: Icons.receipt_long,
                    label: 'Orders',
                    isSelected: navigationProvider.selectedIndex == 1,
                    onTap: () => navigationProvider.setSelectedIndex(1),
                  ),
                  _NavItem(
                    index: 2,
                    icon: Icons.table_restaurant,
                    label: 'Tables',
                    isSelected: navigationProvider.selectedIndex == 2,
                    onTap: () => navigationProvider.setSelectedIndex(2),
                  ),
                  _NavItem(
                    index: 3,
                    icon: Icons.restaurant_menu,
                    label: 'Menu',
                    isSelected: navigationProvider.selectedIndex == 3,
                    onTap: () => navigationProvider.setSelectedIndex(3),
                  ),
                  if (navigationProvider.canAccessInventory)
                    _NavItem(
                      index: 4,
                      icon: Icons.inventory_2,
                      label: 'Inventory',
                      isSelected: navigationProvider.selectedIndex == 4,
                      onTap: () => navigationProvider.setSelectedIndex(4),
                    ),
                  if (navigationProvider.canAccessExpenses)
                    _NavItem(
                      index: 5,
                      icon: Icons.receipt,
                      label: 'Expenses',
                      isSelected: navigationProvider.selectedIndex == 5,
                      onTap: () => navigationProvider.setSelectedIndex(5),
                    ),
                  _NavItem(
                    index: 6,
                    icon: Icons.person,
                    label: 'Profile',
                    isSelected: navigationProvider.selectedIndex == 6,
                    onTap: () => navigationProvider.setSelectedIndex(6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    Key? key,
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingSmall),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusMedium,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/*import 'package:flutter/material.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/page_switcher_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/profile_screen.dart';
import 'package:pos_app/screens/tables_screen/tables_screen1.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/widgets/sync_status_widget.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'package:pos_app/screens/subscription_expired_screen.dart';
import 'menu_screen.dart';
import 'inventory_screen.dart';

class PageSwitcher extends StatefulWidget {
  const PageSwitcher({Key? key}) : super(key: key);

  @override
  State<PageSwitcher> createState() => _PageSwitcherState();
}

class _PageSwitcherState extends State<PageSwitcher> {
  bool _validating = true;
  bool _sessionValid = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // ── 1. Validate session against Firestore ──────────────────
      // This blocks deactivated accounts from auto-logging in on
      // refresh even if Firebase still has a local session cached.
      final authProvider = context.read<AppAuthenticationProvider>();
      final valid = await authProvider.validateSession();

      if (!mounted) return;

      if (!valid) {
        // Check if failed due to subscription expiry
        if (authProvider.subscriptionExpired) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionExpiredScreen()),
            (route) => false,
          );
          return;
        }

        // Deactivated or deleted — redirect to login
        final wasDeactivated = authProvider.wasDeactivated;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        if (wasDeactivated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your account has been deactivated. Please contact your admin.',
                ),
                backgroundColor: Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
        return;
      }

      // ── 2. Load role for nav bar visibility ───────────────────
      await context.read<PageSwitcherProvider>().loadRole();

      if (!mounted) return;
      setState(() {
        _sessionValid = true;
        _validating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Show splash while validating session ──────────────────────
    if (_validating) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1847C4)),
        ),
      );
    }

    if (!_sessionValid) {
      return const LoginScreen();
    }

    // ── Main app — also watch for mid-session deactivation ────────
    return Consumer<AppAuthenticationProvider>(
      builder: (context, auth, child) {
        // Real-time deactivation: session watcher fired mid-session
        if (auth.wasDeactivated || auth.subscriptionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (auth.wasDeactivated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your account has been deactivated. Please contact your admin.',
                  ),
                  backgroundColor: Color(0xFFE11D48),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            } else if (auth.subscriptionExpired) {
               Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionExpiredScreen()),
                (route) => false,
              );
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFFF4F7FF),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1847C4)),
            ),
          );
        }

        return child!;
      },
      // ── Your original Scaffold — completely unchanged ──────────
      child: Consumer<PageSwitcherProvider>(
        builder: (context, navigationProvider, _) {
          return Scaffold(
            body: Column(
              children: [
                // ── Network & Sync status tracker bar ────────────────────
                const NetworkSyncTrackerBar(),
                // ── Main page content ────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: navigationProvider.selectedIndex,
                    children: [
                      const DashboardScreen(),
                      const OrdersScreen(),
                      const TablesScreen(),
                      const MenuScreen(),
                      if (navigationProvider.canAccessInventory)
                        const InventoryScreen()
                      else
                        const SizedBox.shrink(),
                      const ProfileScreen(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: const BottomNavBar(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM NAV BAR — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PageSwitcherProvider>(
      builder: (context, navigationProvider, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppSizes.paddingSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: navigationProvider.selectedIndex == 0,
                    onTap: () => navigationProvider.setSelectedIndex(0),
                  ),
                  _NavItem(
                    index: 1,
                    icon: Icons.receipt_long,
                    label: 'Orders',
                    isSelected: navigationProvider.selectedIndex == 1,
                    onTap: () => navigationProvider.setSelectedIndex(1),
                  ),
                  _NavItem(
                    index: 2,
                    icon: Icons.table_restaurant,
                    label: 'Tables',
                    isSelected: navigationProvider.selectedIndex == 2,
                    onTap: () => navigationProvider.setSelectedIndex(2),
                  ),
                  _NavItem(
                    index: 3,
                    icon: Icons.restaurant_menu,
                    label: 'Menu',
                    isSelected: navigationProvider.selectedIndex == 3,
                    onTap: () => navigationProvider.setSelectedIndex(3),
                  ),
                  if (navigationProvider.canAccessInventory)
                    _NavItem(
                      index: 4,
                      icon: Icons.inventory_2,
                      label: 'Inventory',
                      isSelected: navigationProvider.selectedIndex == 4,
                      onTap: () => navigationProvider.setSelectedIndex(4),
                    ),
                  _NavItem(
                    index: 5,
                    icon: Icons.person,
                    label: 'Profile',
                    isSelected: navigationProvider.selectedIndex == 5,
                    onTap: () => navigationProvider.setSelectedIndex(5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV ITEM — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    Key? key,
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingSmall),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusMedium,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/