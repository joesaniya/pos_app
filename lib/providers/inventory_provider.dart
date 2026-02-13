import 'package:flutter/material.dart';

class InventoryItem {
  final String name;
  final int quantity;
  final String unit;
  final String status;
  final String lastUpdated;

  InventoryItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.lastUpdated,
  });
}

class InventoryProvider extends ChangeNotifier {
  final List<InventoryItem> _inventoryItems = [
    InventoryItem(
      name: 'Fresh Salmon',
      quantity: 25,
      unit: 'kg',
      status: 'good',
      lastUpdated: '2 hours ago',
    ),
    InventoryItem(
      name: 'Tomatoes',
      quantity: 8,
      unit: 'kg',
      status: 'low',
      lastUpdated: '5 hours ago',
    ),
    InventoryItem(
      name: 'Pasta',
      quantity: 150,
      unit: 'packs',
      status: 'good',
      lastUpdated: '1 day ago',
    ),
    InventoryItem(
      name: 'Olive Oil',
      quantity: 3,
      unit: 'liters',
      status: 'critical',
      lastUpdated: '3 hours ago',
    ),
    InventoryItem(
      name: 'Chicken',
      quantity: 40,
      unit: 'kg',
      status: 'good',
      lastUpdated: '4 hours ago',
    ),
    InventoryItem(
      name: 'Lettuce',
      quantity: 12,
      unit: 'kg',
      status: 'low',
      lastUpdated: '6 hours ago',
    ),
  ];

  List<InventoryItem> get inventoryItems => _inventoryItems;

  int get totalItemsCount => _inventoryItems.length;

  int get lowStockCount =>
      _inventoryItems.where((item) => item.status == 'low').length;

  int get criticalStockCount =>
      _inventoryItems.where((item) => item.status == 'critical').length;

  void updateItemQuantity(String itemName, int newQuantity) {
    final index = _inventoryItems.indexWhere((item) => item.name == itemName);
    if (index != -1) {
      String newStatus = 'good';
      if (newQuantity < 5) {
        newStatus = 'critical';
      } else if (newQuantity < 15) {
        newStatus = 'low';
      }

      _inventoryItems[index] = InventoryItem(
        name: _inventoryItems[index].name,
        quantity: newQuantity,
        unit: _inventoryItems[index].unit,
        status: newStatus,
        lastUpdated: 'Just now',
      );
      notifyListeners();
    }
  }
}