import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_item.dart';


class MenuProvider extends ChangeNotifier {
  List<MenuItem> _menuItems = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Starters',
    'Main Course',
    'Desserts',
    'Beverages',
    'Specials',
  ];

  List<MenuItem> get menuItems => _getFilteredItems();
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  MenuProvider() {
    _initializeMenu();
  }

  void _initializeMenu() {
    _menuItems = [
      MenuItem(
        id: 'M001',
        name: 'Paneer Tikka',
        category: 'Starters',
        price: 280,
        description: 'Grilled cottage cheese with Indian spices',
        available: true,
      ),
      MenuItem(
        id: 'M002',
        name: 'Butter Chicken',
        category: 'Main Course',
        price: 420,
        description: 'Creamy tomato-based chicken curry',
        available: true,
      ),
      MenuItem(
        id: 'M003',
        name: 'Gulab Jamun',
        category: 'Desserts',
        price: 120,
        description: 'Sweet milk balls in sugar syrup',
        available: true,
      ),
      MenuItem(
        id: 'M004',
        name: 'Mango Lassi',
        category: 'Beverages',
        price: 150,
        description: 'Refreshing mango yogurt drink',
        available: true,
      ),
      MenuItem(
        id: 'M005',
        name: 'Veg Biryani',
        category: 'Main Course',
        price: 320,
        description: 'Aromatic rice with mixed vegetables',
        available: false,
      ),
      MenuItem(
        id: 'M006',
        name: 'Chicken Tandoori',
        category: 'Starters',
        price: 380,
        description: 'Clay oven roasted chicken',
        available: true,
      ),
      MenuItem(
        id: 'M007',
        name: 'Dal Makhani',
        category: 'Main Course',
        price: 240,
        description: 'Creamy black lentils',
        available: true,
      ),
    ];
    notifyListeners();
  }

  List<MenuItem> _getFilteredItems() {
    var filtered = _menuItems;

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((item) => item.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void addMenuItem(MenuItem item) {
    _menuItems.add(item);
    notifyListeners();
  }

  void updateMenuItem(String id, MenuItem updatedItem) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _menuItems[index] = updatedItem;
      notifyListeners();
    }
  }

  void toggleAvailability(String id) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _menuItems[index] = MenuItem(
        id: _menuItems[index].id,
        name: _menuItems[index].name,
        category: _menuItems[index].category,
        price: _menuItems[index].price,
        description: _menuItems[index].description,
        available: !_menuItems[index].available,
        image: _menuItems[index].image,
      );
      notifyListeners();
    }
  }

  void deleteMenuItem(String id) {
    _menuItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}