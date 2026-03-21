// lib/models/order_modal.dart
// Full Order model — Supabase-backed
// v2: Added PaymentStatus, PaymentMode, bill fields

import 'package:flutter/material.dart';
import 'package:pos_app/utils/ist_utils.dart';

// ══════════════════════════════════════════════════════════════
//  PAYMENT STATUS
// ══════════════════════════════════════════════════════════════

enum PaymentStatus { unpaid, paid, partial, refunded }

extension PaymentStatusExt on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentStatus.unpaid:
        return '💳';
      case PaymentStatus.paid:
        return '✅';
      case PaymentStatus.partial:
        return '⚡';
      case PaymentStatus.refunded:
        return '↩️';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.unpaid:
        return const Color(0xFFDC2626);
      case PaymentStatus.paid:
        return const Color(0xFF059669);
      case PaymentStatus.partial:
        return const Color(0xFFD97706);
      case PaymentStatus.refunded:
        return const Color(0xFF6B7280);
    }
  }

  Color get bgColor {
    switch (this) {
      case PaymentStatus.unpaid:
        return const Color(0xFFFEF2F2);
      case PaymentStatus.paid:
        return const Color(0xFFECFDF5);
      case PaymentStatus.partial:
        return const Color(0xFFFEF3C7);
      case PaymentStatus.refunded:
        return const Color(0xFFF3F4F6);
    }
  }

  static PaymentStatus fromString(String? s) {
    switch (s) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PAYMENT MODE
// ══════════════════════════════════════════════════════════════

enum OrderPaymentMode { cash, upi, card, bank, complimentary }

extension OrderPaymentModeExt on OrderPaymentMode {
  String get value {
    switch (this) {
      case OrderPaymentMode.cash:
        return 'cash';
      case OrderPaymentMode.upi:
        return 'upi';
      case OrderPaymentMode.card:
        return 'card';
      case OrderPaymentMode.bank:
        return 'bank';
      case OrderPaymentMode.complimentary:
        return 'complimentary';
    }
  }

  String get label {
    switch (this) {
      case OrderPaymentMode.cash:
        return 'Cash';
      case OrderPaymentMode.upi:
        return 'UPI';
      case OrderPaymentMode.card:
        return 'Card';
      case OrderPaymentMode.bank:
        return 'Bank Transfer';
      case OrderPaymentMode.complimentary:
        return 'Complimentary';
    }
  }

  String get emoji {
    switch (this) {
      case OrderPaymentMode.cash:
        return '💵';
      case OrderPaymentMode.upi:
        return '📲';
      case OrderPaymentMode.card:
        return '💳';
      case OrderPaymentMode.bank:
        return '🏦';
      case OrderPaymentMode.complimentary:
        return '🎁';
    }
  }

  bool get requiresRef {
    switch (this) {
      case OrderPaymentMode.upi:
      case OrderPaymentMode.card:
      case OrderPaymentMode.bank:
        return true;
      default:
        return false;
    }
  }

  String get refHint {
    switch (this) {
      case OrderPaymentMode.upi:
        return 'UPI Transaction ID';
      case OrderPaymentMode.card:
        return 'Last 4 digits of card';
      case OrderPaymentMode.bank:
        return 'UTR / NEFT Reference';
      default:
        return 'Reference (optional)';
    }
  }

  static OrderPaymentMode fromString(String? s) {
    switch (s) {
      case 'upi':
        return OrderPaymentMode.upi;
      case 'card':
        return OrderPaymentMode.card;
      case 'bank':
        return OrderPaymentMode.bank;
      case 'complimentary':
        return OrderPaymentMode.complimentary;
      default:
        return OrderPaymentMode.cash;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ORDER STATUS
// ══════════════════════════════════════════════════════════════

enum OrderStatus { pending, preparing, ready, completed, cancelled }

extension OrderStatusExt on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '🕐';
      case OrderStatus.preparing:
        return '👨‍🍳';
      case OrderStatus.ready:
        return '✅';
      case OrderStatus.completed:
        return '🎉';
      case OrderStatus.cancelled:
        return '❌';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFE8860A);
      case OrderStatus.preparing:
        return const Color(0xFF0A7ADB);
      case OrderStatus.ready:
        return const Color(0xFF1A9C5B);
      case OrderStatus.completed:
        return const Color(0xFF6B7280);
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Color get bgColor {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFFFF4E0);
      case OrderStatus.preparing:
        return const Color(0xFFE0F0FF);
      case OrderStatus.ready:
        return const Color(0xFFE2F8ED);
      case OrderStatus.completed:
        return const Color(0xFFF3F4F6);
      case OrderStatus.cancelled:
        return const Color(0xFFFEF2F2);
    }
  }

  // ── v2: nextStatus is ONLY available after payment is confirmed ──
  // The UI must check order.paymentStatus == paid before calling advance
  OrderStatus? get nextStatus {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return null; // must pay first to complete
      default:
        return null;
    }
  }

  String get nextLabel {
    switch (this) {
      case OrderStatus.pending:
        return 'Start Preparing';
      case OrderStatus.preparing:
        return 'Mark Ready';
      case OrderStatus.ready:
        return 'Collect Payment';
      default:
        return '';
    }
  }

  static OrderStatus fromString(String s) {
    switch (s) {
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ORDER TYPE
// ══════════════════════════════════════════════════════════════

enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeExt on OrderType {
  String get value {
    switch (this) {
      case OrderType.dineIn:
        return 'dine_in';
      case OrderType.takeaway:
        return 'takeaway';
      case OrderType.delivery:
        return 'delivery';
    }
  }

  String get label {
    switch (this) {
      case OrderType.dineIn:
        return 'Dine In';
      case OrderType.takeaway:
        return 'Takeaway';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  String get emoji {
    switch (this) {
      case OrderType.dineIn:
        return '🍽️';
      case OrderType.takeaway:
        return '🛍️';
      case OrderType.delivery:
        return '🚚';
    }
  }

  static OrderType fromString(String s) {
    switch (s) {
      case 'takeaway':
        return OrderType.takeaway;
      case 'delivery':
        return OrderType.delivery;
      default:
        return OrderType.dineIn;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ORDER ITEM
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
    id: j['id'] as String? ?? '',
    orderId: j['order_id'] as String? ?? '',
    menuItemId: j['menu_item_id'] as String? ?? '',
    itemName: j['item_name'] as String? ?? '',
    itemPrice: (j['item_price'] as num? ?? 0).toDouble(),
    categoryName: j['category_name'] as String?,
    isVeg: j['is_veg'] as bool? ?? true,
    quantity: j['quantity'] as int? ?? 1,
    subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'menu_item_id': menuItemId,
    'item_name': itemName,
    'item_price': itemPrice,
    'category_name': categoryName,
    'is_veg': isVeg,
    'quantity': quantity,
    'subtotal': subtotal,
    'notes': notes,
  };
}

// ══════════════════════════════════════════════════════════════
//  CART ITEM
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
    menuItemId: menuItemId,
    itemName: itemName,
    itemPrice: itemPrice,
    categoryName: categoryName,
    isVeg: isVeg,
    quantity: quantity ?? this.quantity,
    notes: notes ?? this.notes,
  );
}

// ══════════════════════════════════════════════════════════════
//  ORDER  (Supabase-backed) — v2 with payment fields
// ══════════════════════════════════════════════════════════════

class Order {
  final String id;
  final int orderNumber;
  final String? billNumber;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final OrderPaymentMode? paymentMode;
  final String? paymentRef;
  final DateTime? paidAt;
  final String? paidByUid;
  final String? paidByName;
  final DateTime? billGeneratedAt;
  final OrderType orderType;

  // Table
  final String? tableId;
  final int? tableNumber;
  final String? tableSeatId;
  final String? seatLabel;

  // Customer
  final String? customerName;
  final String? customerPhone;

  // Financials
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double roundOff;
  final double totalAmount;
  final double taxRate;

  // Items
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
    this.billNumber,
    required this.status,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMode,
    this.paymentRef,
    this.paidAt,
    this.paidByUid,
    this.paidByName,
    this.billGeneratedAt,
    required this.orderType,
    this.tableId,
    this.tableNumber,
    this.tableSeatId,
    this.seatLabel,
    this.customerName,
    this.customerPhone,
    required this.subtotal,
    required this.taxAmount,
    this.discountAmount = 0,
    this.tipAmount = 0,
    this.roundOff = 0,
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

  // ── Computed ────────────────────────────────────────────────
  int get totalItems => items.fold(0, (s, i) => s + i.quantity);

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isUnpaid => paymentStatus == PaymentStatus.unpaid;

  /// Grand total = subtotal + tax + tip - discount + roundOff
  double get grandTotal =>
      subtotal + taxAmount + tipAmount - discountAmount + roundOff;

  String get timeLabel {
    // createdAt is already local (parsed via parseToIST in fromJson)
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${local.day}/${local.month}';
  }

  bool get isActive =>
      status == OrderStatus.pending || status == OrderStatus.preparing;

  Duration get elapsed => DateTime.now().difference(createdAt);

  // ── Deserialization ─────────────────────────────────────────
  factory Order.fromJson(Map<String, dynamic> j) {
    List<OrderItem> items = [];
    final rawItems = j['items'] ?? j['order_items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList();
    }

    return Order(
      id: j['id'] as String? ?? '',
      orderNumber: j['order_number'] as int? ?? 0,
      billNumber: j['bill_number'] as String?,
      status: OrderStatusExt.fromString(j['status'] as String? ?? ''),
      paymentStatus: PaymentStatusExt.fromString(
        j['payment_status'] as String?,
      ),
      paymentMode: OrderPaymentModeExt.fromString(j['payment_mode'] as String?),
      paymentRef: j['payment_ref'] as String?,
      paidAt: j['paid_at'] != null
          ? parseToIST(j['paid_at'] as String)
          : null,
      paidByUid: j['paid_by_uid'] as String?,
      paidByName: j['paid_by_name'] as String?,
      billGeneratedAt: j['bill_generated_at'] != null
          ? parseToIST(j['bill_generated_at'] as String)
          : null,
      orderType: OrderTypeExt.fromString(j['order_type'] as String? ?? ''),
      tableId: j['table_id'] as String?,
      tableNumber: j['table_number'] as int?,
      tableSeatId: j['table_seat_id'] as String?,
      seatLabel: j['seat_label'] as String?,
      customerName: j['customer_name'] as String?,
      customerPhone: j['customer_phone'] as String?,
      subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
      taxAmount: (j['tax_amount'] as num? ?? 0).toDouble(),
      discountAmount: (j['discount_amount'] as num? ?? 0).toDouble(),
      tipAmount: (j['tip_amount'] as num? ?? 0).toDouble(),
      roundOff: (j['round_off'] as num? ?? 0).toDouble(),
      totalAmount: (j['total_amount'] as num? ?? 0).toDouble(),
      taxRate: (j['tax_rate'] as num? ?? 5).toDouble(),
      items: items,
      notes: j['notes'] as String?,
      businessId: j['business_id'] as String? ?? '',
      businessName: j['business_name'] as String? ?? '',
      createdByUid: j['created_by_uid'] as String? ?? '',
      createdByName: j['created_by_name'] as String? ?? '',
      createdByRole: j['created_by_role'] as String? ?? 'staff',
      createdAt: j['created_at'] != null
          ? parseToIST(j['created_at'] as String)
          : DateTime.now(),
      startedAt: j['started_at'] != null
          ? parseToIST(j['started_at'] as String)
          : null,
      readyAt: j['ready_at'] != null
          ? parseToIST(j['ready_at'] as String)
          : null,
      completedAt: j['completed_at'] != null
          ? parseToIST(j['completed_at'] as String)
          : null,
      cancelledAt: j['cancelled_at'] != null
          ? parseToIST(j['cancelled_at'] as String)
          : null,
      updatedAt: j['updated_at'] != null
          ? parseToIST(j['updated_at'] as String)
          : null,
    );
  }

  Order copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    OrderPaymentMode? paymentMode,
    String? paymentRef,
    DateTime? paidAt,
    String? paidByUid,
    String? paidByName,
    DateTime? billGeneratedAt,
    String? tableSeatId,
    String? seatLabel,
    List<OrderItem>? items,
    double? tipAmount,
    double? discountAmount,
    DateTime? startedAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) => Order(
    id: id,
    orderNumber: orderNumber,
    billNumber: billNumber,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    paymentMode: paymentMode ?? this.paymentMode,
    paymentRef: paymentRef ?? this.paymentRef,
    paidAt: paidAt ?? this.paidAt,
    paidByUid: paidByUid ?? this.paidByUid,
    paidByName: paidByName ?? this.paidByName,
    billGeneratedAt: billGeneratedAt ?? this.billGeneratedAt,
    orderType: orderType,
    tableId: tableId,
    tableNumber: tableNumber,
    tableSeatId: tableSeatId ?? this.tableSeatId,
    seatLabel: seatLabel ?? this.seatLabel,
    customerName: customerName,
    customerPhone: customerPhone,
    subtotal: subtotal,
    taxAmount: taxAmount,
    discountAmount: discountAmount ?? this.discountAmount,
    tipAmount: tipAmount ?? this.tipAmount,
    roundOff: roundOff,
    totalAmount: totalAmount,
    taxRate: taxRate,
    items: items ?? this.items,
    notes: notes,
    businessId: businessId,
    businessName: businessName,
    createdByUid: createdByUid,
    createdByName: createdByName,
    createdByRole: createdByRole,
    createdAt: createdAt,
    startedAt: startedAt ?? this.startedAt,
    readyAt: readyAt ?? this.readyAt,
    completedAt: completedAt ?? this.completedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    updatedAt: updatedAt,
  );
}
