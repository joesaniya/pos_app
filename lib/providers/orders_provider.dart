
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/services/order_service.dart';
import 'package:pos_app/services/order_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersProvider extends ChangeNotifier {
  // ── User context ──────────────────────────────────────────────────────────
  String _uid          = '';
  String _name         = '';
  String _role         = '';
  String _businessId   = '';
  String _businessName = '';

  // ── State ─────────────────────────────────────────────────────────────────
  List<Order>               _orders       = [];
  bool                      _isLoading    = false;
  String?                   _error;
  OrderStatus?              _filterStatus;
  int                       _unreadCount  = 0;
  List<Map<String, dynamic>> _notifications = [];

  // ── Realtime ──────────────────────────────────────────────────────────────
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _notifChannel;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool   get isLoading   => _isLoading;
  String? get error      => _error;
  OrderStatus? get filterStatus => _filterStatus;
  int    get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  String get userName    => _name;
  String get userRole    => _role;
  String get businessId  => _businessId;
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
          OrderStatus.preparing: 0, OrderStatus.pending: 1,
          OrderStatus.ready: 2,     OrderStatus.completed: 3,
          OrderStatus.cancelled: 4,
        };
        final pa = priority[a.status] ?? 5;
        final pb = priority[b.status] ?? 5;
        if (pa != pb) return pa.compareTo(pb);
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  int    countByStatus(OrderStatus s) => _orders.where((o) => o.status == s).length;
  int    get todayTotal               => _orders.length;
  double get todayRevenue             => _orders
      .where((o) => o.status == OrderStatus.completed)
      .fold(0.0, (s, o) => s + o.totalAmount);

  List<Order> ordersForTable(String tableId) =>
      _orders.where((o) => o.tableId == tableId && o.isActive).toList();

  double billAmountForTable(String tableId) =>
      ordersForTable(tableId).fold(0.0, (s, o) => s + o.totalAmount);

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUser();
    await fetchOrders();
    _subscribeRealtime();
    _fetchNotifications();
  }

  Future<void> _loadUser() async {
    final prefs   = await SharedPreferences.getInstance();
    _uid          = prefs.getString('uid')          ?? '';
    _name         = prefs.getString('name')         ?? '';
    _role         = prefs.getString('role')         ?? '';
    _businessId   = prefs.getString('businessId')   ?? '';
    _businessName = prefs.getString('businessName') ?? '';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchOrders() async {
    if (_businessId.isEmpty) return;
    _isLoading = true; _error = null; notifyListeners();
    try {
      _orders = isAdminLevel
          ? await OrdersService.instance.fetchTodayOrders(businessId: _businessId)
          : await OrdersService.instance.fetchTodayOrders(
                businessId: _businessId, staffUid: _uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Order>> fetchTableOrders(String tableId) async {
    if (_businessId.isEmpty) return [];
    return OrdersService.instance.fetchTableOrders(
        tableId: tableId, businessId: _businessId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTER
  // ══════════════════════════════════════════════════════════════════════════

  void setFilter(OrderStatus? s) { _filterStatus = s; notifyListeners(); }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE ORDER — fires foreground notification immediately
  // ══════════════════════════════════════════════════════════════════════════

  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required OrderType orderType,
    String? tableId,
    int?    tableNumber,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final order = await OrdersService.instance.createOrder(
      cartItems:     cartItems,
      businessId:    _businessId,
      businessName:  _businessName,
      createdByUid:  _uid,
      createdByName: _name,
      createdByRole: _role,
      orderType:     orderType,
      tableId:       tableId,
      tableNumber:   tableNumber,
      customerName:  customerName,
      customerPhone: customerPhone,
      notes:         notes,
    );

    _orders.insert(0, order);
    notifyListeners();

    // ── Fire foreground notification immediately after order is created ────
    // This handles the FOREGROUND case. Background handled by WorkManager.
    await OrderNotificationService.instance.notifyNewOrder(
      orderId:      order.id,
      orderNumber:  order.orderNumber,
      orderType:    order.orderType.value,
      businessName: _businessName,
      tableNumber:  tableNumber,
      customerName: customerName,
      totalAmount:  order.totalAmount,
    );

    return order;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATUS TRANSITIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> advanceOrder(String orderId) async {
    final o = _orders.firstWhere((o) => o.id == orderId,
        orElse: () => throw Exception('Order not found'));
    final next = o.status.nextStatus;
    if (next == null) return;
    await _updateStatus(orderId, next);
  }

  Future<void> cancelOrder(String orderId) async {
    await _updateStatus(orderId, OrderStatus.cancelled);
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final oldStatus = idx != -1 ? _orders[idx].status : null;

      final updated = await OrdersService.instance.updateOrderStatus(
        orderId:       orderId,
        newStatus:     newStatus,
        updatedByUid:  _uid,
        updatedByName: _name,
        businessId:    _businessId,
      );

      if (idx != -1) { _orders[idx] = updated; notifyListeners(); }

      // ── Foreground status-change notification ───────────────────────────
      if (oldStatus != null) {
        await OrderNotificationService.instance.notifyStatusChange(
          orderId:      orderId,
          orderNumber:  updated.orderNumber,
          oldStatus:    oldStatus.value,
          newStatus:    newStatus.value,
          businessName: _businessName,
          tableNumber:  updated.tableNumber,
          customerName: updated.customerName,
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME SUBSCRIPTION
  //  Handles events from OTHER devices/users in the foreground.
  //  When another staff member creates an order, this device gets notified.
  // ══════════════════════════════════════════════════════════════════════════

  void _subscribeRealtime() {
    if (_businessId.isEmpty) return;

    _ordersChannel?.unsubscribe();
    _ordersChannel = OrdersService.instance.subscribeToOrders(
      businessId: _businessId,
      onEvent: (order, eventType) async {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        final isNew = idx == -1;
        final oldStatus = isNew ? null : _orders[idx].status;

        if (isNew) {
          _orders.insert(0, order);
        } else {
          _orders[idx] = order;
        }
        notifyListeners();

        // ── Notify for events coming from OTHER users ─────────────────────
        // We skip orders created by self (already notified in createOrder)
        if (order.createdByUid != _uid) {
          if (isNew || eventType == 'INSERT') {
            // New order from another device
            await OrderNotificationService.instance.notifyNewOrder(
              orderId:      order.id,
              orderNumber:  order.orderNumber,
              orderType:    order.orderType.value,
              businessName: _businessName,
              tableNumber:  order.tableNumber,
              customerName: order.customerName,
              totalAmount:  order.totalAmount,
            );
          } else if (!isNew && oldStatus != null && oldStatus != order.status) {
            // Status changed on another device
            await OrderNotificationService.instance.notifyStatusChange(
              orderId:      order.id,
              orderNumber:  order.orderNumber,
              oldStatus:    oldStatus.value,
              newStatus:    order.status.value,
              businessName: _businessName,
              tableNumber:  order.tableNumber,
              customerName: order.customerName,
            );
          }
        }
      },
    );

    // ── Notification channel subscription ────────────────────────────────
    _notifChannel?.unsubscribe();
    _notifChannel = OrdersService.instance.subscribeToNotifications(
      businessId: _businessId,
      onNotification: (notif) async {
        _notifications.insert(0, notif);
        _unreadCount++;
        notifyListeners();

        // Also fire local push from the realtime notif record
        // This covers the case where a DB trigger inserts into order_notifications
        // and we pick it up here while foregrounded
        await OrderNotificationService.instance.processNotificationRecord(
          notif, _businessName);
      },
    );
  }

  Future<void> _fetchNotifications() async {
    if (_businessId.isEmpty) return;
    try {
      _notifications = await OrdersService.instance.fetchUnreadNotifications(
          businessId: _businessId, targetUid: _uid);
      _unreadCount = _notifications.length;
      notifyListeners();

      // Fire any unread notifications that we missed while the app was closed
      // (covers the brief gap between last WorkManager run and app open)
      for (final notif in _notifications) {
        await OrderNotificationService.instance.processNotificationRecord(
            notif, _businessName);
      }
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    await OrdersService.instance.markNotificationsRead(businessId: _businessId);
    _unreadCount = 0;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    super.dispose();
  }
}


/*
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class OrdersProvider extends ChangeNotifier {
  // ── User context ────────────────────────────────────────
  String _uid = '';
  String _name = '';
  String _role = '';
  String _businessId = '';
  String _businessName = '';

  // ── State ───────────────────────────────────────────────
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  OrderStatus? _filterStatus;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];

  // ── Realtime ────────────────────────────────────────────
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _notifChannel;

  // ── Getters ─────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderStatus? get filterStatus => _filterStatus;
  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  String get userName => _name;
  String get userRole => _role;
  String get businessId => _businessId;

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
          OrderStatus.pending:   1,
          OrderStatus.ready:     2,
          OrderStatus.completed: 3,
          OrderStatus.cancelled: 4,
        };
        final pa = priority[a.status] ?? 5;
        final pb = priority[b.status] ?? 5;
        if (pa != pb) return pa.compareTo(pb);
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  int countByStatus(OrderStatus s) => _orders.where((o) => o.status == s).length;

  int get todayTotal => _orders.length;

  double get todayRevenue => _orders
      .where((o) => o.status == OrderStatus.completed)
      .fold(0.0, (s, o) => s + o.totalAmount);

  /// Orders for a specific table (active only)
  List<Order> ordersForTable(String tableId) =>
      _orders.where((o) => o.tableId == tableId && o.isActive).toList();

  double billAmountForTable(String tableId) =>
      ordersForTable(tableId).fold(0.0, (s, o) => s + o.totalAmount);

  // ══════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════
  Future<void> init() async {
    await _loadUser();
    await fetchOrders();
    _subscribeRealtime();
    _fetchNotifications();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _uid          = prefs.getString('uid') ?? '';
    _name         = prefs.getString('name') ?? '';
    _role         = prefs.getString('role') ?? '';
    _businessId   = prefs.getString('businessId') ?? '';
    _businessName = prefs.getString('businessName') ?? '';
  }

  // ══════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════
  Future<void> fetchOrders() async {
    if (_businessId.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isAdminLevel) {
        _orders = await OrdersService.instance.fetchTodayOrders(
          businessId: _businessId,
        );
      } else {
        _orders = await OrdersService.instance.fetchTodayOrders(
          businessId: _businessId,
          staffUid:   _uid,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Order>> fetchTableOrders(String tableId) async {
    if (_businessId.isEmpty) return [];
    return OrdersService.instance.fetchTableOrders(
      tableId:    tableId,
      businessId: _businessId,
    );
  }

  // ══════════════════════════════════════════════════════
  //  FILTER
  // ══════════════════════════════════════════════════════
  void setFilter(OrderStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  //  CREATE ORDER
  // ══════════════════════════════════════════════════════
  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required OrderType orderType,
    String? tableId,
    int? tableNumber,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final order = await OrdersService.instance.createOrder(
      cartItems:      cartItems,
      businessId:     _businessId,
      businessName:   _businessName,
      createdByUid:   _uid,
      createdByName:  _name,
      createdByRole:  _role,
      orderType:      orderType,
      tableId:        tableId,
      tableNumber:    tableNumber,
      customerName:   customerName,
      customerPhone:  customerPhone,
      notes:          notes,
    );

    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  // ══════════════════════════════════════════════════════
  //  STATUS TRANSITIONS
  // ══════════════════════════════════════════════════════
  Future<void> advanceOrder(String orderId) async {
    final o = _orders.firstWhere((o) => o.id == orderId, orElse: () => throw Exception('Order not found'));
    final next = o.status.nextStatus;
    if (next == null) return;
    await _updateStatus(orderId, next);
  }

  Future<void> cancelOrder(String orderId) async {
    await _updateStatus(orderId, OrderStatus.cancelled);
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      final updated = await OrdersService.instance.updateOrderStatus(
        orderId:        orderId,
        newStatus:      newStatus,
        updatedByUid:   _uid,
        updatedByName:  _name,
        businessId:     _businessId,
      );

      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════
  void _subscribeRealtime() {
    if (_businessId.isEmpty) return;

    _ordersChannel?.unsubscribe();
    _ordersChannel = OrdersService.instance.subscribeToOrders(
      businessId: _businessId,
      onEvent: (order, eventType) {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx != -1) {
          _orders[idx] = order;
        } else {
          // New order from another device/user
          _orders.insert(0, order);
        }
        notifyListeners();
      },
    );

    _notifChannel?.unsubscribe();
    _notifChannel = OrdersService.instance.subscribeToNotifications(
      businessId: _businessId,
      onNotification: (notif) {
        _notifications.insert(0, notif);
        _unreadCount++;
        notifyListeners();
      },
    );
  }

  Future<void> _fetchNotifications() async {
    if (_businessId.isEmpty) return;
    try {
      _notifications = await OrdersService.instance.fetchUnreadNotifications(
        businessId: _businessId,
        targetUid:  _uid,
      );
      _unreadCount = _notifications.length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    await OrdersService.instance.markNotificationsRead(businessId: _businessId);
    _unreadCount = 0;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  //  DISPOSE
  // ══════════════════════════════════════════════════════
  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    super.dispose();
  }
}*/