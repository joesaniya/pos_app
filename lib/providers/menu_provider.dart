import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_item.dart';



class MenuProvider extends ChangeNotifier {
  String _selectedCategory = 'All';

  final List<MenuItem> _menuItems = [
    MenuItem(
      name: 'Grilled Salmon',
      price: 24.99,
      category: 'Main Course',
      available: true,
    ),
    MenuItem(
      name: 'Caesar Salad',
      price: 12.50,
      category: 'Appetizers',
      available: true,
    ),
    MenuItem(
      name: 'Chocolate Cake',
      price: 8.99,
      category: 'Desserts',
      available: true,
    ),
    MenuItem(
      name: 'Iced Coffee',
      price: 4.50,
      category: 'Beverages',
      available: true,
    ),
    MenuItem(
      name: 'Beef Steak',
      price: 32.00,
      category: 'Main Course',
      available: false,
    ),
    MenuItem(
      name: 'Chicken Wings',
      price: 15.99,
      category: 'Appetizers',
      available: true,
    ),
    MenuItem(
      name: 'Tiramisu',
      price: 7.50,
      category: 'Desserts',
      available: true,
    ),
  ];

  String get selectedCategory => _selectedCategory;
  List<MenuItem> get menuItems => _menuItems;

  List<MenuItem> get filteredItems {
    if (_selectedCategory == 'All') {
      return _menuItems;
    }
    return _menuItems
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleItemAvailability(String itemName) {
    final index = _menuItems.indexWhere((item) => item.name == itemName);
    if (index != -1) {
      _menuItems[index] = MenuItem(
        name: _menuItems[index].name,
        price: _menuItems[index].price,
        category: _menuItems[index].category,
        available: !_menuItems[index].available,
      );
      notifyListeners();
    }
  }
}