class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String? image;
  final bool available;
  final String description;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.image,
    this.available = true,
    this.description = '',
  });
}

class OrderItem {
  final MenuItem menuItem;
  int quantity;
  String? specialInstructions;

  OrderItem({
    required this.menuItem,
    this.quantity = 1,
    this.specialInstructions,
  });

  double get totalPrice => menuItem.price * quantity;
}

class Order {
  final String id;
  final String tableNumber;
  final List<OrderItem> items;
  final DateTime orderTime;
  OrderStatus status;
  final String? customerName;

  Order({
    required this.id,
    required this.tableNumber,
    required this.items,
    required this.orderTime,
    this.status = OrderStatus.pending,
    this.customerName,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.totalPrice);
}

enum OrderStatus {
  pending,
  preparing,
  ready,
  served,
  completed,
  cancelled
}

class TableInfo {
  final String number;
  final int capacity;
  TableStatus status;
  Order? currentOrder;

  TableInfo({
    required this.number,
    required this.capacity,
    this.status = TableStatus.empty,
    this.currentOrder,
  });
}

enum TableStatus {
  empty,
  reserved,
  occupied
}

class InventoryItem {
  final String id;
  final String name;
  final String unit;
  double quantity;
  final double minQuantity;
  final double price;
  final String? category;

  InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minQuantity,
    required this.price,
    this.category,
  });

  bool get isLowStock => quantity <= minQuantity;
}

class RevenueData {
  final DateTime date;
  final double amount;

  RevenueData({required this.date, required this.amount});
}