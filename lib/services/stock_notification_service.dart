// lib/services/stock_notification_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  STOCK NOTIFICATION SERVICE
//  - Role-based push (admin + manager only)
//  - Supabase realtime listener for in-app alerts
//  - Local notification display
//  - Notification history log
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/services/storage_service.dart';

// ─── Notification Channels ────────────────────────────────────────────────────
const _chCritical = AndroidNotificationDetails(
  'ch_stock_critical',
  'Critical Stock Alerts',
  channelDescription: 'Fires when an item is critically low or out of stock',
  importance: Importance.max,
  priority: Priority.max,
  playSound: true,
  enableVibration: true,
  icon: '@mipmap/ic_launcher',
  channelShowBadge: true,
  visibility: NotificationVisibility.public,
  category: AndroidNotificationCategory.alarm,
);

const _chWarning = AndroidNotificationDetails(
  'ch_stock_warning',
  'Low Stock Warnings',
  channelDescription: 'Fires when an item reaches minimum stock level',
  importance: Importance.high,
  priority: Priority.high,
  playSound: true,
  enableVibration: true,
  icon: '@mipmap/ic_launcher',
  channelShowBadge: true,
);

const _chRestock = AndroidNotificationDetails(
  'ch_stock_restock',
  'Restock Notifications',
  channelDescription: 'Fires when an item has been restocked',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  playSound: true,
  icon: '@mipmap/ic_launcher',
);

const _iosCritical = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  interruptionLevel: InterruptionLevel.timeSensitive,
);
const _iosWarning = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
);
const _iosNormal = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: false,
  presentSound: false,
);

// ─────────────────────────────────────────────────────────────────────────────
class StockNotificationService {
  StockNotificationService._();
  static final StockNotificationService instance = StockNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _channel;

  // Callbacks for UI
  VoidCallback? onNewNotification;

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
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

      _initialized = true;
      log('[StockNotif] ✅ Initialized');
    } catch (e) {
      debugPrint('[StockNotif] Init error: $e');
    }
  }

  // ── Start Realtime Listener ───────────────────────────────────────────────
  /// Call after login. Only subscribes if the user is admin or manager.
  Future<void> startListening() async {
    if (!_initialized) await initialize();

    final userData = await StorageService.instance.getUserData();
    final role = userData['role'] as String? ?? '';
    final businessId = userData['businessId'] as String? ?? '';

    // Role gate — only admin and manager receive stock notifications
    if (!['admin', 'manager'].contains(role.toLowerCase())) {
      log('[StockNotif] Role "$role" not eligible for stock alerts');
      return;
    }

    if (businessId.isEmpty) {
      log('[StockNotif] No businessId — skipping realtime');
      return;
    }

    _channel?.unsubscribe();

    _channel = Supabase.instance.client
        .channel('stock_notifs_$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'stock_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            _handleNewNotification(row);
          },
        )
        .subscribe();

    log('[StockNotif] ✅ Realtime listening for businessId=$businessId role=$role');
  }

  void stopListening() {
    _channel?.unsubscribe();
    _channel = null;
    log('[StockNotif] Stopped realtime listener');
  }

  // ── Handle incoming notification ──────────────────────────────────────────
  Future<void> _handleNewNotification(Map<String, dynamic> row) async {
    final notif = StockNotificationRecord.fromJson(row);
    log('[StockNotif] 🔔 New alert: ${notif.title}');

    await _sendLocalNotification(notif);
    onNewNotification?.call();
  }

  // ── Send local notification ───────────────────────────────────────────────
  Future<void> _sendLocalNotification(StockNotificationRecord notif) async {
    if (!_initialized) return;

    final (android, ios, notifId) = switch (notif.severity) {
      NotificationSeverity.critical => (_chCritical, _iosCritical, 20000),
      NotificationSeverity.warning  => (_chWarning, _iosWarning, 21000),
      _                             => (_chRestock, _iosNormal, 22000),
    };

    final id = notifId + (notif.itemName.hashCode.abs() % 1000);

    try {
      await _plugin.show(
        id: id,
        title: notif.title,
        body: notif.body,
        notificationDetails: NotificationDetails(android: android, iOS: ios),
        payload: 'stock:${notif.itemId ?? ""}',
      );
      log('[StockNotif] 📲 Local notif sent: ${notif.title}');
    } catch (e) {
      debugPrint('[StockNotif] Send error: $e');
    }
  }

  // ── Manual trigger (e.g. after stock update in foreground) ─────────────────
  Future<void> checkAndNotify({
    required InventoryItem item,
    required StockStatus previousStatus,
    required String businessId,
  }) async {
    final newStatus = item.status;
    if (newStatus == previousStatus) return;

    // DB trigger handles creating the record; we just fire local notif here
    // for immediate foreground feedback
    String title, body;
    NotificationSeverity severity;

    switch (newStatus) {
      case StockStatus.outOfStock:
        title    = '❌ Out of Stock: ${item.name}';
        body     = '${item.name} is completely out of stock. Immediate reorder needed.';
        severity = NotificationSeverity.critical;
        break;
      case StockStatus.critical:
        title    = '🔴 Critical Stock: ${item.name}';
        body     = '${item.name} is critically low: ${item.stockDisplay} (Min: ${item.minThreshold.toInt()} ${item.unit.label})';
        severity = NotificationSeverity.critical;
        break;
      case StockStatus.lowStock:
        title    = '⚠️ Low Stock: ${item.name}';
        body     = '${item.name} is running low: ${item.stockDisplay} (Min: ${item.minThreshold.toInt()} ${item.unit.label})';
        severity = NotificationSeverity.warning;
        break;
      case StockStatus.inStock:
        if (previousStatus == StockStatus.outOfStock || previousStatus == StockStatus.critical) {
          title    = '✅ Restocked: ${item.name}';
          body     = '${item.name} has been restocked: ${item.stockDisplay}';
          severity = NotificationSeverity.info;
        } else {
          return;
        }
        break;
    }

    final fakeRecord = StockNotificationRecord(
      id:           'local_${DateTime.now().millisecondsSinceEpoch}',
      businessId:   businessId,
      itemId:       item.id,
      itemName:     item.name,
      type:         _statusToType(newStatus),
      title:        title,
      body:         body,
      currentStock: item.currentStock,
      minThreshold: item.minThreshold,
      unit:         item.unit.label,
      severity:     severity,
      isRead:       false,
      sentAt:       DateTime.now(),
    );

    await _sendLocalNotification(fakeRecord);
  }

  StockNotificationType _statusToType(StockStatus s) {
    switch (s) {
      case StockStatus.critical:    return StockNotificationType.critical;
      case StockStatus.outOfStock:  return StockNotificationType.outOfStock;
      case StockStatus.inStock:     return StockNotificationType.restock;
      default:                      return StockNotificationType.lowStock;
    }
  }

  // ── Fetch notification history ────────────────────────────────────────────
  Future<List<StockNotificationRecord>> fetchHistory({
    required String businessId,
    int limit = 50,
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from('stock_notifications')
          .select()
          .eq('business_id', businessId)
          .order('sent_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((r) => StockNotificationRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[StockNotif] fetchHistory error: $e');
      return [];
    }
  }

  // ── Mark notifications as read ────────────────────────────────────────────
  Future<void> markAllRead(String businessId) async {
    try {
      await Supabase.instance.client
          .from('stock_notifications')
          .update({'is_read': true})
          .eq('business_id', businessId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[StockNotif] markAllRead error: $e');
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('stock_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[StockNotif] markRead error: $e');
    }
  }

  // ── Get unread count ──────────────────────────────────────────────────────
  Future<int> getUnreadCount(String businessId) async {
    try {
      final res = await Supabase.instance.client
          .from('stock_notifications')
          .select('id')
          .eq('business_id', businessId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ── Register device token ─────────────────────────────────────────────────
  Future<void> registerDeviceToken({
    required String businessId,
    required String userUid,
    required String userRole,
    required String fcmToken,
    String platform = 'android',
  }) async {
    // Only admin and manager get registered
    if (!['admin', 'manager'].contains(userRole.toLowerCase())) return;

    try {
      await Supabase.instance.client
          .from('notification_device_tokens')
          .upsert({
            'business_id': businessId,
            'user_uid':    userUid,
            'user_role':   userRole,
            'fcm_token':   fcmToken,
            'platform':    platform,
            'is_active':   true,
            'updated_at':  DateTime.now().toIso8601String(),
          }, onConflict: 'fcm_token');
      log('[StockNotif] Device token registered for $userRole');
    } catch (e) {
      debugPrint('[StockNotif] registerDeviceToken error: $e');
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

// ─── Tap Handlers ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void _onBgTap(NotificationResponse response) {
  log('[StockNotif] Background tap: ${response.payload}');
}

void _onTap(NotificationResponse response) {
  log('[StockNotif] Foreground tap: ${response.payload}');
}