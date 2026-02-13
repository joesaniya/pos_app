import 'package:flutter/material.dart';

class Order {
  final String id;
  final String table;
  final int items;
  final double amount;
  final String status;
  final String time;

  Order({
    required this.id,
    required this.table,
    required this.items,
    required this.amount,
    required this.status,
    required this.time,
  });
}

class OrdersProvider extends ChangeNotifier {
  String _selectedFilter = 'All';

  final List<Order> _orders = [
    Order(
      id: '#ORD-1234',
      table: 'T1',
      items: 3,
      amount: 145.50,
      status: 'preparing',
      time: '10 min',
    ),
    Order(
      id: '#ORD-1235',
      table: 'T3',
      items: 2,
      amount: 89.00,
      status: 'served',
      time: '25 min',
    ),
    Order(
      id: '#ORD-1236',
      table: 'T5',
      items: 5,
      amount: 234.75,
      status: 'preparing',
      time: '5 min',
    ),
    Order(
      id: '#ORD-1237',
      table: 'T7',
      items: 1,
      amount: 45.00,
      status: 'pending',
      time: '2 min',
    ),
    Order(
      id: '#ORD-1238',
      table: 'T2',
      items: 4,
      amount: 178.00,
      status: 'served',
      time: '35 min',
    ),
    Order(
      id: '#ORD-1239',
      table: 'T4',
      items: 2,
      amount: 92.50,
      status: 'pending',
      time: '1 min',
    ),
  ];

  String get selectedFilter => _selectedFilter;
  List<Order> get orders => _orders;

  List<Order> get filteredOrders {
    if (_selectedFilter == 'All') {
      return _orders;
    }
    return _orders
        .where((o) => o.status.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void addOrder(Order order) {
    _orders.add(order);
    notifyListeners();
  }

  void updateOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      // Create a new order with updated status
      final updatedOrder = Order(
        id: _orders[index].id,
        table: _orders[index].table,
        items: _orders[index].items,
        amount: _orders[index].amount,
        status: newStatus,
        time: _orders[index].time,
      );
      _orders[index] = updatedOrder;
      notifyListeners();
    }
  }
}