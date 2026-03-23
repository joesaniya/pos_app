// lib/providers/orders_provider.dart
// v2: confirmPayment() replaces direct status advancement for 'ready' orders

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/repositories/orders_repository.dart';
import 'package:pos_app/services/order_notification_service.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/services/connectivity_service.dart';

class OrdersProvider extends ChangeNotifier {
  // ── User context ──────────────────────────────────────────────────────────
  String _uid = '';
  String _name = '';
  String _role = '';
  String _businessId = '';
  String _businessName = '';

  // ── State ─────────────────────────────────────────────────────────────────
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  OrderStatus? _filterStatus;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];

  // ── Realtime ──────────────────────────────────────────────────────────────
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _notifChannel;

  /// IDs of orders that we just created optimistically.
  /// The realtime INSERT callback should skip these to prevent duplicates.
  final Set<String> _pendingOptimisticIds = {};

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderStatus? get filterStatus => _filterStatus;
  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  String get userName => _name;
  String get userRole => _role;
  String get businessId => _businessId;
  String get businessName => _businessName;

  bool get isAdminLevel =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  List<Order> get allOrders => List.unmodifiable(_orders);

  List<Order> get filteredOrders {
    final list = _filterStatus == null
        ? _orders
        : _orders.where((o) => o.status == _filterStatus).toList();
    return [...list]..sort((a, b) {
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
      .fold(0.0, (s, o) => s + o.totalAmount);

  /// Unpaid orders that are ready — need payment collection
  List<Order> get pendingPaymentOrders => _orders
      .where(
        (o) =>
            o.status == OrderStatus.ready &&
            o.paymentStatus == PaymentStatus.unpaid,
      )
      .toList();

  int get pendingPaymentCount => pendingPaymentOrders.length;

  List<Order> ordersForTable(String tableId) =>
      _orders.where((o) => o.tableId == tableId && o.isActive).toList();

  double billAmountForTable(String tableId) =>
      ordersForTable(tableId).fold(0.0, (s, o) => s + o.totalAmount);

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUserFromFirestore();

    if (_businessId.isEmpty) {
      final stored = await StorageService.instance.getUserData();
      final storedBiz = stored['businessId'] as String? ?? '';
      if (storedBiz.isNotEmpty) {
        _uid = stored['uid'] as String? ?? _uid;
        _name = stored['name'] as String? ?? '';
        _role = stored['role'] as String? ?? 'staff';
        _businessId = storedBiz;
        _businessName = stored['businessName'] as String? ?? '';
      }
    }

    if (_businessId.isEmpty) return;

    await fetchOrders();
    _subscribeRealtime();
    _fetchNotifications();
  }

  Future<void> _loadUserFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final storedData = await StorageService.instance.getUserData();
      
      _uid = storedData['uid'] as String? ?? firebaseUser?.uid ?? '';
      _name = storedData['name'] as String? ?? '';
      _role = storedData['role'] as String? ?? 'staff';
      _businessId = storedData['businessId'] as String? ?? '';
      _businessName = storedData['businessName'] as String? ?? '';
    } catch (e) {
      debugPrint('📦 _loadUserFromFirestore ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchOrders() async {
    if (_businessId.isEmpty) return;

    if (_uid.isEmpty) {
      await _loadUserFromFirestore();
      if (_uid.isEmpty) {
        final stored = await StorageService.instance.getUserData();
        _uid = stored['uid'] as String? ?? _uid;
        _role = stored['role'] as String? ?? 'staff';
        _name = stored['name'] as String? ?? _name;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await OrdersRepository.instance.fetchTodayOrders(
        businessId: _businessId,
        staffUid: null,
      );
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📦 fetchOrders ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // ── Double-fetch for offline-first ─────────────────────────────────────────
    if (ConnectivityService.instance.isOnline && _businessId.isNotEmpty) {
      try {
        await OrdersRepository.instance.refreshOrdersFromRemote(businessId: _businessId);
        _orders = await OrdersRepository.instance.fetchTodayOrders(
          businessId: _businessId,
          staffUid: null,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('📦 Remote refresh error: $e');
      }
    }
  }

  Future<List<Order>> fetchTableOrders(String tableId) async {
    if (_businessId.isEmpty) return [];
    return OrdersRepository.instance.fetchTableOrders(
      tableId: tableId,
      businessId: _businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTER
  // ══════════════════════════════════════════════════════════════════════════

  void setFilter(OrderStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE ORDER
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required OrderType orderType,
    String? tableId,
    int? tableNumber,
    String? tableSeatId,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    if (_businessId.isEmpty || _uid.isEmpty) await _loadUserFromFirestore();

    if (_businessId.isEmpty) {
      final stored = await StorageService.instance.getUserData();
      _uid = stored['uid'] as String? ?? _uid;
      _name = stored['name'] as String? ?? _name;
      _role = stored['role'] as String? ?? _role;
      _businessId = stored['businessId'] as String? ?? '';
      _businessName = stored['businessName'] as String? ?? _businessName;
    }

    if (_businessId.isEmpty) {
      throw Exception('Cannot create order: business profile not loaded');
    }

    final order = await OrdersRepository.instance.createOrder(
      cartItems: cartItems,
      businessId: _businessId,
      businessName: _businessName,
      createdByUid: _uid,
      createdByName: _name,
      createdByRole: _role,
      orderType: orderType,
      tableId: tableId,
      tableNumber: tableNumber,
      tableSeatId: tableSeatId,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
    );

    // Mark this ID so the realtime callback skips the INSERT event for it
    _pendingOptimisticIds.add(order.id);

    // Optimistic insert at front of list (dedup guard in realtime handler)
    final alreadyPresent = _orders.any((o) => o.id == order.id);
    if (!alreadyPresent) {
      _orders.insert(0, order);
    }
    notifyListeners();

    await OrderNotificationService.instance.notifyNewOrder(
      orderId: order.id,
      orderNumber: order.orderNumber,
      orderType: order.orderType.value,
      businessName: _businessName,
      tableNumber: tableNumber,
      customerName: customerName,
      totalAmount: order.totalAmount,
    );

    return order;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADVANCE ORDER STATUS (kitchen flow: pending → preparing → ready)
  //  NOTE: 'ready' → 'completed' requires payment via confirmPayment()
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> advanceOrder(String orderId) async {
    final o = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
    final next = o.status.nextStatus;
    if (next == null) return; // 'ready' has no next — must pay first
    await _updateStatus(orderId, next);
  }

  Future<void> cancelOrder(String orderId) async {
    await _updateStatus(orderId, OrderStatus.cancelled);
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final oldStatus = idx != -1 ? _orders[idx].status : null;

      final updated = await OrdersRepository.instance.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        updatedByUid: _uid,
        updatedByName: _name,
        businessId: _businessId,
      );

      if (idx != -1) {
        _orders[idx] = updated;
        notifyListeners();
      }

      if (oldStatus != null) {
        await OrderNotificationService.instance.notifyStatusChange(
          orderId: orderId,
          orderNumber: updated.orderNumber,
          oldStatus: oldStatus.value,
          newStatus: newStatus.value,
          businessName: _businessName,
          tableNumber: updated.tableNumber,
          customerName: updated.customerName,
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIRM PAYMENT → auto-completes order
  //  This is the ONLY way to complete an order
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> confirmPayment({
    required String orderId,
    required OrderPaymentMode mode,
    String? paymentRef,
    double? tipAmount,
    double? discountAmount,
  }) async {
    try {
      final updated = await OrdersRepository.instance.confirmPayment(
        orderId: orderId,
        mode: mode,
        paidByUid: _uid,
        paidByName: _name,
        businessId: _businessId,
        paymentRef: paymentRef,
        tipAmount: tipAmount,
        discountAmount: discountAmount,
      );

      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
        notifyListeners();
      }

      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════════════════════════

  void _subscribeRealtime() {
    if (_businessId.isEmpty) return;

    _ordersChannel?.unsubscribe();
    _ordersChannel = OrdersRepository.instance.subscribeToOrders(
      businessId: _businessId,
      onEvent: (order, eventType) async {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        final isNew = idx == -1;

        // Consume the optimistic token if present — but ALWAYS apply the full
        // server record (which carries seat_label and other view-computed fields)
        // so the UI updates immediately without a manual refresh.
        if (_pendingOptimisticIds.contains(order.id)) {
          _pendingOptimisticIds.remove(order.id);
        }

        final oldStat = isNew ? null : _orders[idx].status;

        if (isNew) {
          _orders.insert(0, order);
        } else {
          _orders[idx] = order;
        }
        notifyListeners();

        if (order.createdByUid != _uid) {
          if (isNew || eventType == 'INSERT') {
            await OrderNotificationService.instance.notifyNewOrder(
              orderId: order.id,
              orderNumber: order.orderNumber,
              orderType: order.orderType.value,
              businessName: _businessName,
              tableNumber: order.tableNumber,
              customerName: order.customerName,
              totalAmount: order.totalAmount,
            );
          } else if (!isNew && oldStat != null && oldStat != order.status) {
            await OrderNotificationService.instance.notifyStatusChange(
              orderId: order.id,
              orderNumber: order.orderNumber,
              oldStatus: oldStat.value,
              newStatus: order.status.value,
              businessName: _businessName,
              tableNumber: order.tableNumber,
              customerName: order.customerName,
            );
          }
        }
      },
    );

    _notifChannel?.unsubscribe();
    _notifChannel = OrdersRepository.instance.subscribeToNotifications(
      businessId: _businessId,
      onNotification: (notif) async {
        _notifications.insert(0, notif);
        _unreadCount++;
        notifyListeners();
        await OrderNotificationService.instance.processNotificationRecord(
          notif,
          _businessName,
        );
      },
    );
  }

  Future<void> _fetchNotifications() async {
    if (_businessId.isEmpty) return;
    try {
      _notifications = await OrdersRepository.instance.fetchUnreadNotifications(
        businessId: _businessId,
        targetUid: _uid,
      );
      _unreadCount = _notifications.length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    await OrdersRepository.instance.markNotificationsRead(businessId: _businessId);
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    super.dispose();
  }
}
