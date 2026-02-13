import 'package:flutter/material.dart';
import 'package:pos_app/providers/page_switcher_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'tables_screen.dart';
import 'menu_screen.dart';
import 'inventory_screen.dart';

class PageSwitcher extends StatelessWidget {
  const PageSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PageSwitcherProvider>(
      builder: (context, navigationProvider, _) {
        return Scaffold(
          body: IndexedStack(
            index: navigationProvider.selectedIndex,
            children: const [
              DashboardScreen(),
              OrdersScreen(),
              TablesScreen(),
              MenuScreen(),
              InventoryScreen(),
            ],
          ),
          bottomNavigationBar: const BottomNavBar(),
        );
      },
    );
  }
}

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
                  _NavItem(
                    index: 4,
                    icon: Icons.inventory_2,
                    label: 'Inventory',
                    isSelected: navigationProvider.selectedIndex == 4,
                    onTap: () => navigationProvider.setSelectedIndex(4),
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
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
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