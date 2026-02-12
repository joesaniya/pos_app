import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_item.dart';


class OrdersProvider extends ChangeNotifier {
  List<Order> _orders = [];
  String _searchQuery = '';
  OrderStatus? _filterStatus;

  List<Order> get orders => _getFilteredOrders();
  String get searchQuery => _searchQuery;
  OrderStatus? get filterStatus => _filterStatus;

  OrdersProvider() {
    _initializeOrders();
  }

  void _initializeOrders() {
    _orders = [
      Order(
        id: 'ORD001',
        tableNumber: '1',
        items: [],
        orderTime: DateTime.now().subtract(const Duration(minutes: 15)),
        status: OrderStatus.preparing,
        customerName: 'John Doe',
      ),
      Order(
        id: 'ORD002',
        tableNumber: '3',
        items: [],
        orderTime: DateTime.now().subtract(const Duration(minutes: 30)),
        status: OrderStatus.ready,
      ),
      Order(
        id: 'ORD003',
        tableNumber: '5',
        items: [],
        orderTime: DateTime.now().subtract(const Duration(minutes: 45)),
        status: OrderStatus.pending,
        customerName: 'Sarah Smith',
      ),
      Order(
        id: 'ORD004',
        tableNumber: '7',
        items: [],
        orderTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: OrderStatus.preparing,
      ),
      Order(
        id: 'ORD005',
        tableNumber: '12',
        items: [],
        orderTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: OrderStatus.pending,
        customerName: 'Mike Johnson',
      ),
    ];
    notifyListeners();
  }

  List<Order> _getFilteredOrders() {
    var filtered = _orders;

    // Filter by status
    if (_filterStatus != null) {
      filtered = filtered.where((order) => order.status == _filterStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        return order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               order.tableNumber.contains(_searchQuery) ||
               (order.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    return filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterStatus(OrderStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      _orders[index].status = newStatus;
      notifyListeners();
    }
  }

  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void deleteOrder(String orderId) {
    _orders.removeWhere((order) => order.id == orderId);
    notifyListeners();
  }

  int getOrderCountByStatus(OrderStatus status) {
    return _orders.where((order) => order.status == status).length;
  }
}