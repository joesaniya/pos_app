import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_item.dart';


class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _items = [];
  String _searchQuery = '';
  String _filterOption = 'All';

  List<InventoryItem> get items => _getFilteredItems();
  String get searchQuery => _searchQuery;
  String get filterOption => _filterOption;
  int get lowStockCount => _items.where((item) => item.isLowStock).length;

  InventoryProvider() {
    _initializeInventory();
  }

  void _initializeInventory() {
    _items = [
      InventoryItem(
        id: 'INV001',
        name: 'Tomatoes',
        unit: 'kg',
        quantity: 15.5,
        minQuantity: 10,
        price: 40,
        category: 'Vegetables',
      ),
      InventoryItem(
        id: 'INV002',
        name: 'Chicken',
        unit: 'kg',
        quantity: 8,
        minQuantity: 12,
        price: 280,
        category: 'Meat',
      ),
      InventoryItem(
        id: 'INV003',
        name: 'Rice',
        unit: 'kg',
        quantity: 45,
        minQuantity: 20,
        price: 60,
        category: 'Grains',
      ),
      InventoryItem(
        id: 'INV004',
        name: 'Milk',
        unit: 'L',
        quantity: 5,
        minQuantity: 15,
        price: 55,
        category: 'Dairy',
      ),
      InventoryItem(
        id: 'INV005',
        name: 'Onions',
        unit: 'kg',
        quantity: 25,
        minQuantity: 10,
        price: 35,
        category: 'Vegetables',
      ),
      InventoryItem(
        id: 'INV006',
        name: 'Paneer',
        unit: 'kg',
        quantity: 3,
        minQuantity: 8,
        price: 320,
        category: 'Dairy',
      ),
    ];
    notifyListeners();
  }

  List<InventoryItem> _getFilteredItems() {
    var filtered = _items;

    // Filter by low stock
    if (_filterOption == 'Low Stock') {
      filtered = filtered.where((item) => item.isLowStock).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (item.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    return filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterOption(String option) {
    _filterOption = option;
    notifyListeners();
  }

  void addInventoryItem(InventoryItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateStock(String id, double additionalQuantity) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index].quantity += additionalQuantity;
      notifyListeners();
    }
  }

  void updateInventoryItem(String id, InventoryItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = updatedItem;
      notifyListeners();
    }
  }

  void deleteInventoryItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}