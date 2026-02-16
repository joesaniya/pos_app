import 'package:pos_app/models/menu_item.dart';

enum OrderStatus { pending, preparing, ready, completed, cancelled }

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:   return 'Pending';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.ready:     return 'Ready';
      case OrderStatus.completed: return 'Completed';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:   return '🕐';
      case OrderStatus.preparing: return '👨‍🍳';
      case OrderStatus.ready:     return '✅';
      case OrderStatus.completed: return '🎉';
      case OrderStatus.cancelled: return '❌';
    }
  }

  OrderStatus? get nextStatus {
    switch (this) {
      case OrderStatus.pending:   return OrderStatus.preparing;
      case OrderStatus.preparing: return OrderStatus.ready;
      case OrderStatus.ready:     return OrderStatus.completed;
      default: return null;
    }
  }

  String get nextLabel {
    switch (this) {
      case OrderStatus.pending:   return 'Start Preparing';
      case OrderStatus.preparing: return 'Mark Ready';
      case OrderStatus.ready:     return 'Complete Order';
      default: return '';
    }
  }
}

enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeExt on OrderType {
  String get label {
    switch (this) {
      case OrderType.dineIn:   return 'Dine In';
      case OrderType.takeaway: return 'Takeaway';
      case OrderType.delivery: return 'Delivery';
    }
  }

  String get emoji {
    switch (this) {
      case OrderType.dineIn:   return '🍽️';
      case OrderType.takeaway: return '🛍️';
      case OrderType.delivery: return '🚚';
    }
  }
}

class OrderLineItem {
  final MenuItem menuItem;
  final int quantity;
  final String? note;

  const OrderLineItem({
    required this.menuItem,
    required this.quantity,
    this.note,
  });

  double get subtotal => menuItem.price * quantity;

  OrderLineItem copyWith({int? quantity, String? note}) => OrderLineItem(
        menuItem: menuItem,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
      );
}

class Order {
  final String id;
  final int orderNumber;
  final OrderStatus status;
  final OrderType type;
  final List<OrderLineItem> items;
  final String? tableNumber;
  final String? customerName;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.type,
    required this.items,
    this.tableNumber,
    this.customerName,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.notes,
  });

  // ✅ FIXED (0 → 0.0)
  double get subtotal =>
      items.fold(0.0, (s, i) => s + i.subtotal);

  double get tax => subtotal * 0.05;

  double get total => subtotal + tax;

  int get totalItems =>
      items.fold(0, (s, i) => s + i.quantity);

  String get timeLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    return '${diff.inHours}h ago';
  }

  String get durationLabel {
    if (startedAt == null) return '—';
    final end = completedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }

  Order copyWith({
    OrderStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    List<OrderLineItem>? items,
    String? notes,
  }) =>
      Order(
        id: id,
        orderNumber: orderNumber,
        status: status ?? this.status,
        type: type,
        items: items ?? this.items,
        tableNumber: tableNumber,
        customerName: customerName,
        createdAt: createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        notes: notes ?? this.notes,
      );
}