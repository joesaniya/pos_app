import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import '../models/menu_item.dart';

class OrdersProvider extends ChangeNotifier {
  OrderStatus? _filterStatus; // null = all
  final List<Order> _orders = [];
  int _nextOrderNum = 4524;

  OrdersProvider() {
    _seedOrders();
  }

  // ── Getters ───────────────────────────────────────────────
  OrderStatus? get filterStatus => _filterStatus;

  List<Order> get allOrders => List.unmodifiable(_orders);

  List<Order> get filteredOrders {
    final list = _filterStatus == null
        ? _orders
        : _orders.where((o) => o.status == _filterStatus).toList();
    // Sort: active first, then by newest
    return list..sort((a, b) {
      const priority = {
        OrderStatus.preparing: 0,
        OrderStatus.pending: 1,
        OrderStatus.ready: 2,
        OrderStatus.completed: 3,
        OrderStatus.cancelled: 4,
      };
      final pa = priority[a.status] ?? 5;
      final pb = priority[b.status] ?? 5;
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  int countByStatus(OrderStatus s) =>
      _orders.where((o) => o.status == s).length;

  int get todayTotal => _orders.length;
  double get todayRevenue => _orders
      .where((o) => o.status == OrderStatus.completed)
      .fold(0.0, (s, o) => s + o.total);

  // ── Mutations ─────────────────────────────────────────────
  void setFilter(OrderStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  Future<Order> createOrder({
    required OrderType type,
    required List<OrderLineItem> items,
    String? tableNumber,
    String? customerName,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final order = Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: _nextOrderNum++,
      status: OrderStatus.pending,
      type: type,
      items: items,
      tableNumber: tableNumber,
      customerName: customerName,
      createdAt: DateTime.now(),
      notes: notes,
    );
    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  void updateStatus(String orderId, OrderStatus newStatus) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final o = _orders[idx];
    _orders[idx] = o.copyWith(
      status: newStatus,
      startedAt: newStatus == OrderStatus.preparing
          ? DateTime.now()
          : o.startedAt,
      completedAt:
          (newStatus == OrderStatus.completed ||
              newStatus == OrderStatus.cancelled)
          ? DateTime.now()
          : o.completedAt,
    );
    notifyListeners();
  }

  void cancelOrder(String orderId) =>
      updateStatus(orderId, OrderStatus.cancelled);

  void advanceOrder(String orderId) {
    final o = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception(),
    );
    final next = o.status.nextStatus;
    if (next != null) updateStatus(orderId, next);
  }

  // ── Seed data ─────────────────────────────────────────────
  void _seedOrders() {
    _orders.addAll([
      Order(
        id: 'ord_001',
        orderNumber: 4523,
        status: OrderStatus.preparing,
        type: OrderType.dineIn,
        tableNumber: '2',
        customerName: 'Jane Smith',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        items: [
          OrderLineItem(
            menuItem: _item('Butter Chicken', 280, false),
            quantity: 1,
          ),
          OrderLineItem(
            menuItem: _item('Chicken Biryani', 250, false),
            quantity: 2,
          ),
          OrderLineItem(
            menuItem: _item('Paneer Tikka', 220, true),
            quantity: 1,
          ),
        ],
      ),
      Order(
        id: 'ord_002',
        orderNumber: 4522,
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableNumber: '8',
        customerName: 'Mike Johnson',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        items: [
          OrderLineItem(menuItem: _item('Idli Sambar', 60, true), quantity: 3),
          OrderLineItem(menuItem: _item('Masala Dosa', 100, true), quantity: 2),
          OrderLineItem(
            menuItem: _item('Filter Coffee', 50, true),
            quantity: 3,
          ),
        ],
      ),
      Order(
        id: 'ord_003',
        orderNumber: 4521,
        status: OrderStatus.ready,
        type: OrderType.takeaway,
        customerName: 'Priya S',
        createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
        startedAt: DateTime.now().subtract(const Duration(minutes: 28)),
        items: [
          OrderLineItem(
            menuItem: _item('Ghee Roast Dosa', 140, true),
            quantity: 1,
          ),
          OrderLineItem(
            menuItem: _item('Filter Coffee', 50, true),
            quantity: 2,
          ),
        ],
      ),
      Order(
        id: 'ord_004',
        orderNumber: 4520,
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableNumber: '5',
        customerName: 'Rahul M',
        createdAt: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 10),
        ),
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        completedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        items: [
          OrderLineItem(
            menuItem: _item('Palak Paneer', 180, true),
            quantity: 1,
          ),
          OrderLineItem(menuItem: _item('Garlic Naan', 40, true), quantity: 4),
          OrderLineItem(menuItem: _item('Mango Lassi', 90, true), quantity: 2),
        ],
      ),
    ]);
  }

  MenuItem _item(String name, double price, bool isVeg) => MenuItem(
    id: name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    price: price,
    category: 'Various',
    subcategory: 'All',
    available: true,
    isVeg: isVeg,
  );
}
