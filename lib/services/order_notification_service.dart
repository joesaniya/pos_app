// lib/services/order_notification_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  ORDER NOTIFICATION SERVICE  — v2
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderNotificationService {
  OrderNotificationService._();
  static final OrderNotificationService instance = OrderNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Set<String> _sentKeys = {};
  static const _kSentKeys = '_order_notif_keys';

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CHANNEL DEFINITIONS
  //  NOTE: _chReady uses Int64List.fromList which is not a const expression,
  //  so it must be `static final` (not `static const`).
  // ─────────────────────────────────────────────────────────────────────────

  static const _chNewOrder = AndroidNotificationDetails(
    'ch_new_order',
    'New Orders',
    channelDescription: 'Fires when a new order is placed',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
    groupKey: 'com.pos.orders',
    setAsGroupSummary: false,
    ticker: 'New order received',
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.message,
  );

  static const _chStatus = AndroidNotificationDetails(
    'ch_order_status',
    'Order Status Updates',
    channelDescription: 'Status changes for existing orders',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
    groupKey: 'com.pos.orders',
  );

  // FIX: `static final` instead of `static const` because Int64List.fromList
  // is not a constant expression.
  static final _chReady = AndroidNotificationDetails(
    'ch_order_ready',
    'Order Ready',
    channelDescription: 'Fires when an order is ready to serve',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
    groupKey: 'com.pos.orders',
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
  );

  static const _chCancelled = AndroidNotificationDetails(
    'ch_order_cancel',
    'Cancelled Orders',
    channelDescription: 'Fires when an order is cancelled',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
    groupKey: 'com.pos.orders',
  );

  static const _chGroupSummary = AndroidNotificationDetails(
    'ch_new_order',
    'New Orders',
    channelDescription: 'Order notifications summary',
    importance: Importance.min,
    priority: Priority.low,
    groupKey: 'com.pos.orders',
    setAsGroupSummary: true,
  );

  static const _iosCritical = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );
  static const _iosNormal = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  INITIALIZE
  //  FIX: pass `settings:` named parameter; remove `const` from
  //  InitializationSettings (DarwinInitializationSettings is not const).
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        // FIX: use named parameter `settings:` and drop `const`
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
        onDidReceiveBackgroundNotificationResponse: _onBgTap,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _loadSentKeys();
      _initialized = true;
      debugPrint('[OrderNotif] ✅ Initialized');
    } catch (e) {
      debugPrint('[OrderNotif] ⚠️ Init error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SENT-KEY PERSISTENCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadSentKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kSentKeys) ?? [];
      _sentKeys = raw.where((k) => k.startsWith(_today)).toSet();
    } catch (_) {
      _sentKeys = {};
    }
  }

  Future<void> _persistSentKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kSentKeys,
        _sentKeys.where((k) => k.startsWith(_today)).toList(),
      );
    } catch (_) {}
  }

  bool _hasSent(String key) => _sentKeys.contains(key);
  Future<void> _markSent(String k) async {
    _sentKeys.add(k);
    await _persistSentKeys();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CORE SEND
  //  FIX: plugin.show() uses named `id:` parameter (not positional).
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _send({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails android,
    DarwinNotificationDetails? ios,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: ios ?? _iosNormal,
        ),
        payload: payload,
      );
      await _plugin.show(
        id: 10,
        title: 'Orders',
        body: '',
        notificationDetails: const NotificationDetails(
          android: _chGroupSummary,
        ),
      );
      log('[OrderNotif] 🔔 Sent: "$title"');
    } catch (e) {
      debugPrint('[OrderNotif] ⚠️ Send error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> notifyNewOrder({
    required String orderId,
    required int orderNumber,
    required String orderType,
    required String businessName,
    int? tableNumber,
    String? customerName,
    double? totalAmount,
  }) async {
    final key = '${_today}_new_$orderId';
    if (_hasSent(key)) return;
    await _markSent(key);

    final typeEmoji = switch (orderType) {
      'takeaway' => '🥡',
      'delivery' => '🛵',
      _ => '🍽️',
    };
    final tableInfo = tableNumber != null ? ' • Table $tableNumber' : '';
    final custInfo = customerName != null && customerName.isNotEmpty
        ? ' • $customerName'
        : '';
    final amtInfo = totalAmount != null
        ? ' • ₹${totalAmount.toStringAsFixed(0)}'
        : '';

    await _send(
      id: 10000 + orderNumber,
      title: '$typeEmoji New Order #$orderNumber$tableInfo',
      body: '$businessName$custInfo$amtInfo',
      android: _chNewOrder,
      ios: _iosCritical,
      payload: 'order:$orderId',
    );
  }

  Future<void> notifyStatusChange({
    required String orderId,
    required int orderNumber,
    required String oldStatus,
    required String newStatus,
    required String businessName,
    int? tableNumber,
    String? customerName,
  }) async {
    if (newStatus == 'completed') return;

    final key = '${_today}_status_${orderId}_$newStatus';
    if (_hasSent(key)) return;
    await _markSent(key);

    final tableInfo = tableNumber != null ? ' (Table $tableNumber)' : '';
    final custInfo = customerName != null && customerName.isNotEmpty
        ? ' • $customerName'
        : '';

    switch (newStatus) {
      case 'preparing':
        await _send(
          id: 11000 + orderNumber,
          title: '👨‍🍳 Preparing — Order #$orderNumber$tableInfo',
          body: '$businessName$custInfo • Kitchen started',
          android: _chStatus,
          payload: 'order:$orderId',
        );

      case 'ready':
        await _send(
          id: 12000 + orderNumber,
          title: '✅ READY — Order #$orderNumber$tableInfo',
          body: '$businessName$custInfo • Ready to serve!',
          android: _chReady,
          ios: _iosCritical,
          payload: 'order:$orderId',
        );

      case 'cancelled':
        await _send(
          id: 13000 + orderNumber,
          title: '❌ Cancelled — Order #$orderNumber$tableInfo',
          body: '$businessName$custInfo • Order was cancelled',
          android: _chCancelled,
          payload: 'order:$orderId',
        );

      default:
        await _send(
          id: 11000 + orderNumber,
          title: '🔄 Order #$orderNumber → ${newStatus.toUpperCase()}',
          body: '$businessName$custInfo',
          android: _chStatus,
          payload: 'order:$orderId',
        );
    }
  }

  Future<void> processNotificationRecord(
    Map<String, dynamic> record,
    String businessName,
  ) async {
    final type = record['type'] as String? ?? 'new_order';
    final orderId = record['order_id'] as String? ?? '';
    final title = record['title'] as String? ?? '';
    final body = record['body'] as String? ?? businessName;
    final orderNum = _parseOrderNum(title);

    switch (type) {
      case 'new_order':
        await _send(
          id: 10000 + orderNum,
          title: '🆕 $title',
          body: body,
          android: _chNewOrder,
          ios: _iosCritical,
          payload: 'order:$orderId',
        );

      case 'ready':
        await _send(
          id: 12000 + orderNum,
          title: '✅ $title',
          body: body,
          android: _chReady,
          ios: _iosCritical,
          payload: 'order:$orderId',
        );

      case 'cancelled':
        await _send(
          id: 13000 + orderNum,
          title: '❌ $title',
          body: body,
          android: _chCancelled,
          payload: 'order:$orderId',
        );

      default:
        await _send(
          id: 11000 + orderNum,
          title: title,
          body: body,
          android: _chStatus,
          payload: 'order:$orderId',
        );
    }
  }

  Future<void> processUnreadFromBackground({
    required List<Map<String, dynamic>> unreadRows,
    required String businessName,
    required String businessId,
  }) async {
    if (!_initialized) await initialize();
    if (unreadRows.isEmpty) return;

    for (final row in unreadRows) {
      final id = row['id'] as String? ?? '';
      if (id.isEmpty) continue;
      final key = '${_today}_bgnotif_$id';
      if (_hasSent(key)) continue;
      await _markSent(key);
      await processNotificationRecord(row, businessName);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  int _parseOrderNum(String title) {
    final m = RegExp(r'#(\d+)').firstMatch(title);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  Future<void> cancelOrder(int orderNumber) async {
    await _plugin.cancel(id: 10000 + orderNumber);
    await _plugin.cancel(id: 11000 + orderNumber);
    await _plugin.cancel(id: 12000 + orderNumber);
    await _plugin.cancel(id: 13000 + orderNumber);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[OrderNotif] Cancelled all');
  }

  void clearSentKeys() {
    _sentKeys.clear();
    _persistSentKeys();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAP HANDLERS
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void _onBgTap(NotificationResponse response) {
  log('[OrderNotif] Background tap: ${response.payload}');
}

void _onTap(NotificationResponse response) {
  log('[OrderNotif] Foreground tap: ${response.payload}');
  // TODO: NavigationService.instance.navigateTo('/orders', args: orderId);
}
