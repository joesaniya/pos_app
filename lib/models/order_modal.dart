// lib/models/order_model.dart
// Full Order model — Supabase-backed

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════

enum OrderStatus { pending, preparing, ready, completed, cancelled }

extension OrderStatusExt on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:   return 'pending';
      case OrderStatus.preparing: return 'preparing';
      case OrderStatus.ready:     return 'ready';
      case OrderStatus.completed: return 'completed';
      case OrderStatus.cancelled: return 'cancelled';
    }
  }

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

  Color get color {
    switch (this) {
      case OrderStatus.pending:   return const Color(0xFFE8860A);
      case OrderStatus.preparing: return const Color(0xFF0A7ADB);
      case OrderStatus.ready:     return const Color(0xFF1A9C5B);
      case OrderStatus.completed: return const Color(0xFF6B7280);
      case OrderStatus.cancelled: return const Color(0xFFDC2626);
    }
  }

  Color get bgColor {
    switch (this) {
      case OrderStatus.pending:   return const Color(0xFFFFF4E0);
      case OrderStatus.preparing: return const Color(0xFFE0F0FF);
      case OrderStatus.ready:     return const Color(0xFFE2F8ED);
      case OrderStatus.completed: return const Color(0xFFF3F4F6);
      case OrderStatus.cancelled: return const Color(0xFFFEF2F2);
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

  static OrderStatus fromString(String s) {
    switch (s) {
      case 'preparing': return OrderStatus.preparing;
      case 'ready':     return OrderStatus.ready;
      case 'completed': return OrderStatus.completed;
      case 'cancelled': return OrderStatus.cancelled;
      default:          return OrderStatus.pending;
    }
  }
}

enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeExt on OrderType {
  String get value {
    switch (this) {
      case OrderType.dineIn:   return 'dine_in';
      case OrderType.takeaway: return 'takeaway';
      case OrderType.delivery: return 'delivery';
    }
  }

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

  static OrderType fromString(String s) {
    switch (s) {
      case 'takeaway': return OrderType.takeaway;
      case 'delivery': return OrderType.delivery;
      default:         return OrderType.dineIn;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ORDER ITEM  (line item in an order)
// ══════════════════════════════════════════════════════════════
class OrderItem {
  final String id;
  final String orderId;
  final String menuItemId;
  final String itemName;
  final double itemPrice;
  final String? categoryName;
  final bool isVeg;
  final int quantity;
  final double subtotal;
  final String? notes;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.itemName,
    required this.itemPrice,
    this.categoryName,
    required this.isVeg,
    required this.quantity,
    required this.subtotal,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id:           j['id'] as String? ?? '',
        orderId:      j['order_id'] as String? ?? '',
        menuItemId:   j['menu_item_id'] as String? ?? '',
        itemName:     j['item_name'] as String? ?? '',
        itemPrice:    (j['item_price'] as num? ?? 0).toDouble(),
        categoryName: j['category_name'] as String?,
        isVeg:        j['is_veg'] as bool? ?? true,
        quantity:     j['quantity'] as int? ?? 1,
        subtotal:     (j['subtotal'] as num? ?? 0).toDouble(),
        notes:        j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'order_id':      orderId,
        'menu_item_id':  menuItemId,
        'item_name':     itemName,
        'item_price':    itemPrice,
        'category_name': categoryName,
        'is_veg':        isVeg,
        'quantity':      quantity,
        'subtotal':      subtotal,
        'notes':         notes,
      };
}

// ══════════════════════════════════════════════════════════════
//  CART ITEM  (transient, pre-order)
// ══════════════════════════════════════════════════════════════
class CartItem {
  final String menuItemId;
  final String itemName;
  final double itemPrice;
  final String? categoryName;
  final bool isVeg;
  int quantity;
  String? notes;

  CartItem({
    required this.menuItemId,
    required this.itemName,
    required this.itemPrice,
    this.categoryName,
    required this.isVeg,
    this.quantity = 1,
    this.notes,
  });

  double get subtotal => itemPrice * quantity;

  CartItem copyWith({int? quantity, String? notes}) => CartItem(
        menuItemId:   menuItemId,
        itemName:     itemName,
        itemPrice:    itemPrice,
        categoryName: categoryName,
        isVeg:        isVeg,
        quantity:     quantity ?? this.quantity,
        notes:        notes ?? this.notes,
      );
}

// ══════════════════════════════════════════════════════════════
//  ORDER  (Supabase-backed)
// ══════════════════════════════════════════════════════════════
class Order {
  final String id;
  final int orderNumber;
  final OrderStatus status;
  final OrderType orderType;

  // Table
  final String? tableId;
  final int? tableNumber;

  // Customer
  final String? customerName;
  final String? customerPhone;

  // Financials
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final double taxRate;

  // Items (populated via join / vw_orders_with_items)
  final List<OrderItem> items;

  // Notes
  final String? notes;

  // Business
  final String businessId;
  final String businessName;

  // Staff
  final String createdByUid;
  final String createdByName;
  final String createdByRole;

  // Timestamps
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.orderType,
    this.tableId,
    this.tableNumber,
    this.customerName,
    this.customerPhone,
    required this.subtotal,
    required this.taxAmount,
    this.discountAmount = 0,
    required this.totalAmount,
    this.taxRate = 5.0,
    this.items = const [],
    this.notes,
    required this.businessId,
    required this.businessName,
    required this.createdByUid,
    required this.createdByName,
    this.createdByRole = 'staff',
    required this.createdAt,
    this.startedAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.updatedAt,
  });

  // ── Computed ────────────────────────────────────────────
  int get totalItems => items.fold(0, (s, i) => s + i.quantity);

  String get timeLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  bool get isActive =>
      status == OrderStatus.pending || status == OrderStatus.preparing;

  Duration get elapsed => DateTime.now().difference(createdAt);

  // ── Deserialization ─────────────────────────────────────
  factory Order.fromJson(Map<String, dynamic> j) {
    // Items can come as JSON array from the view
    List<OrderItem> items = [];
    final rawItems = j['items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList();
    }

    return Order(
      id:               j['id'] as String? ?? '',
      orderNumber:      j['order_number'] as int? ?? 0,
      status:           OrderStatusExt.fromString(j['status'] as String? ?? ''),
      orderType:        OrderTypeExt.fromString(j['order_type'] as String? ?? ''),
      tableId:          j['table_id'] as String?,
      tableNumber:      j['table_number'] as int?,
      customerName:     j['customer_name'] as String?,
      customerPhone:    j['customer_phone'] as String?,
      subtotal:         (j['subtotal'] as num? ?? 0).toDouble(),
      taxAmount:        (j['tax_amount'] as num? ?? 0).toDouble(),
      discountAmount:   (j['discount_amount'] as num? ?? 0).toDouble(),
      totalAmount:      (j['total_amount'] as num? ?? 0).toDouble(),
      taxRate:          (j['tax_rate'] as num? ?? 5).toDouble(),
      items:            items,
      notes:            j['notes'] as String?,
      businessId:       j['business_id'] as String? ?? '',
      businessName:     j['business_name'] as String? ?? '',
      createdByUid:     j['created_by_uid'] as String? ?? '',
      createdByName:    j['created_by_name'] as String? ?? '',
      createdByRole:    j['created_by_role'] as String? ?? 'staff',
      createdAt:        DateTime.parse(j['created_at'] as String? ?? DateTime.now().toIso8601String()),
      startedAt:        j['started_at'] != null ? DateTime.parse(j['started_at'] as String) : null,
      readyAt:          j['ready_at'] != null ? DateTime.parse(j['ready_at'] as String) : null,
      completedAt:      j['completed_at'] != null ? DateTime.parse(j['completed_at'] as String) : null,
      cancelledAt:      j['cancelled_at'] != null ? DateTime.parse(j['cancelled_at'] as String) : null,
      updatedAt:        j['updated_at'] != null ? DateTime.parse(j['updated_at'] as String) : null,
    );
  }

  Order copyWith({
    OrderStatus? status,
    List<OrderItem>? items,
    DateTime? startedAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) => Order(
        id:             id,
        orderNumber:    orderNumber,
        status:         status ?? this.status,
        orderType:      orderType,
        tableId:        tableId,
        tableNumber:    tableNumber,
        customerName:   customerName,
        customerPhone:  customerPhone,
        subtotal:       subtotal,
        taxAmount:      taxAmount,
        discountAmount: discountAmount,
        totalAmount:    totalAmount,
        taxRate:        taxRate,
        items:          items ?? this.items,
        notes:          notes,
        businessId:     businessId,
        businessName:   businessName,
        createdByUid:   createdByUid,
        createdByName:  createdByName,
        createdByRole:  createdByRole,
        createdAt:      createdAt,
        startedAt:      startedAt ?? this.startedAt,
        readyAt:        readyAt ?? this.readyAt,
        completedAt:    completedAt ?? this.completedAt,
        cancelledAt:    cancelledAt ?? this.cancelledAt,
        updatedAt:      updatedAt,
      );
}