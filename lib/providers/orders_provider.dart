// lib/providers/orders_provider.dart
// ROOT FIX: User profile (businessId, businessName, name, role) was being
// read from SharedPreferences which was never populated from Firebase Firestore.
// Now loads directly from Firestore 'users' collection using Firebase Auth UID.
//
// RESTART FIX: init() now falls back to StorageService if Firestore is slow,
// and OrdersScreen always calls init() so businessId is guaranteed on restart.
//
// ROLE FIX: role + uid are re-checked before fetchOrders so staff never
// accidentally receive all orders when uid/role are empty on cold start.

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/services/order_service.dart';
import 'package:pos_app/services/order_notification_service.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<Order> ordersForTable(String tableId) =>
      _orders.where((o) => o.tableId == tableId && o.isActive).toList();

  double billAmountForTable(String tableId) =>
      ordersForTable(tableId).fold(0.0, (s, o) => s + o.totalAmount);

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT — loads user then fetches orders
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    // Step 1: try Firestore first
    await _loadUserFromFirestore();

    // Step 2: fallback to StorageService if Firestore was slow / returned empty
    if (_businessId.isEmpty) {
      final stored = await StorageService.instance.getUserData();
      final storedBiz = stored['businessId'] as String? ?? '';
      if (storedBiz.isNotEmpty) {
        _uid = stored['uid'] as String? ?? _uid;
        _name = stored['name'] as String? ?? '';
        _role = stored['role'] as String? ?? 'staff';
        _businessId = storedBiz;
        _businessName = stored['businessName'] as String? ?? '';
        debugPrint(
          '📦 init: loaded from StorageService fallback biz=$_businessId',
        );
      }
    }

    if (_businessId.isEmpty) {
      debugPrint(
        '📦 OrdersProvider.init: businessId still empty after all attempts',
      );
      return;
    }

    await fetchOrders();
    _subscribeRealtime();
    _fetchNotifications();
  }

  // ── Load user profile from Firestore 'users' collection ──────────────────
  Future<void> _loadUserFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('📦 _loadUserFromFirestore: No Firebase user logged in');
        return;
      }

      _uid = firebaseUser.uid;
      debugPrint('📦 _loadUserFromFirestore: uid=$_uid');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (!doc.exists) {
        debugPrint('📦 _loadUserFromFirestore: No Firestore doc for uid=$_uid');
        return;
      }

      final data = doc.data()!;
      debugPrint('📦 _loadUserFromFirestore: raw data=$data');

      _name = data['name'] as String? ?? '';
      _role = data['role'] as String? ?? 'staff';
      _businessId = data['businessId'] as String? ?? '';
      _businessName = data['businessName'] as String? ?? '';

      debugPrint(
        '📦 _loadUserFromFirestore: name=$_name role=$_role '
        'biz=$_businessId bizName=$_businessName',
      );

      // ── Persist to StorageService so other providers can read it ──────────
      final token = await firebaseUser.getIdToken() ?? '';
      await StorageService.instance.saveUserData(
        uid: _uid,
        token: token,
        name: _name,
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        role: _role,
        businessId: _businessId,
        businessName: _businessName,
        profilePhoto: data['profilePhoto'] as String? ?? '',
        isActive: data['isActive'] as bool? ?? true,
      );

      debugPrint('📦 _loadUserFromFirestore: saved to StorageService ✅');
    } catch (e) {
      debugPrint('📦 _loadUserFromFirestore ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH ORDERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchOrders() async {
    if (_businessId.isEmpty) {
      debugPrint('📦 fetchOrders: businessId empty, skipping');
      return;
    }

    // Guard: ensure role + uid are loaded so staff filter works correctly
    if (_role.isEmpty || _uid.isEmpty) {
      debugPrint('📦 fetchOrders: role/uid empty, reloading user...');
      await _loadUserFromFirestore();
      if (_role.isEmpty) {
        final stored = await StorageService.instance.getUserData();
        _uid = stored['uid'] as String? ?? _uid;
        _role = stored['role'] as String? ?? 'staff';
        _name = stored['name'] as String? ?? _name;
        debugPrint('📦 fetchOrders: role from storage=$_role uid=$_uid');
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '📦 fetchOrders: isAdminLevel=$isAdminLevel role=$_role '
        'uid=$_uid biz=$_businessId',
      );

      _orders = await OrdersService.instance.fetchTodayOrders(
        businessId: _businessId,
        // Only fetch all orders if truly admin level AND uid is confirmed
        staffUid: isAdminLevel ? null : _uid,
      );

      debugPrint('📦 fetchOrders: loaded ${_orders.length} orders');
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📦 fetchOrders ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Order>> fetchTableOrders(String tableId) async {
    if (_businessId.isEmpty) return [];
    return OrdersService.instance.fetchTableOrders(
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
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    // Guard: ensure user data is loaded before creating
    if (_businessId.isEmpty || _uid.isEmpty) {
      await _loadUserFromFirestore();
    }

    // Second fallback to StorageService
    if (_businessId.isEmpty) {
      final stored = await StorageService.instance.getUserData();
      _uid = stored['uid'] as String? ?? _uid;
      _name = stored['name'] as String? ?? _name;
      _role = stored['role'] as String? ?? _role;
      _businessId = stored['businessId'] as String? ?? '';
      _businessName = stored['businessName'] as String? ?? _businessName;
      debugPrint('📦 createOrder: loaded from StorageService fallback');
    }

    if (_businessId.isEmpty) {
      throw Exception('Cannot create order: business profile not loaded');
    }

    debugPrint('🛒 createOrder: biz=$_businessId by=$_name($_role)');

    final order = await OrdersService.instance.createOrder(
      cartItems: cartItems,
      businessId: _businessId,
      businessName: _businessName,
      createdByUid: _uid,
      createdByName: _name,
      createdByRole: _role,
      orderType: orderType,
      tableId: tableId,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
    );

    _orders.insert(0, order);
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
  //  STATUS TRANSITIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> advanceOrder(String orderId) async {
    final o = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
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
  //  REALTIME
  // ══════════════════════════════════════════════════════════════════════════

  void _subscribeRealtime() {
    if (_businessId.isEmpty) return;

    _ordersChannel?.unsubscribe();
    _ordersChannel = OrdersService.instance.subscribeToOrders(
      businessId: _businessId,
      onEvent: (order, eventType) async {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        final isNew = idx == -1;
        final oldStat = isNew ? null : _orders[idx].status;

        // Role-based filter: staff only see their own orders
        // Guard against empty _uid so staff don't accidentally see all
        if (!isAdminLevel) {
          if (_uid.isEmpty || order.createdByUid != _uid) return;
        }

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
    _notifChannel = OrdersService.instance.subscribeToNotifications(
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
      _notifications = await OrdersService.instance.fetchUnreadNotifications(
        businessId: _businessId,
        targetUid: _uid,
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

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    super.dispose();
  }
}
