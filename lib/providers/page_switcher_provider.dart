import 'package:flutter/material.dart';
import 'package:pos_app/services/storage_service.dart';

class PageSwitcherProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  String _role = '';

  int get selectedIndex => _selectedIndex;
  String get role => _role;

  // Roles that can access Inventory
  static const List<String> _inventoryAllowedRoles = [
    'system',
    'admin',
    'manager',
    'owner',
  ];

  bool get canAccessInventory => _inventoryAllowedRoles.contains(_role.toLowerCase());

  Future<void> loadRole() async {
    final data = await StorageService.instance.getUserData();
    _role = data['role'] ?? '';
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    // Guard: if server tries to go to inventory (index 4), block it
    if (index == 4 && !canAccessInventory) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
