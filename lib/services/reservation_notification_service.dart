import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pos_app/models/table_modal.dart';

// ─────────────────────────────────────────────────────────────
//  NOTIFICATION IDs  (range partitions to avoid collision)
// ─────────────────────────────────────────────────────────────
//  1000–1999 : check-in reminders (30 min before)
//  2000–2999 : check-in reminders (15 min before)
//  3000–3999 : check-out warnings  (15 min before)
//  4000–4999 : long-seated alerts
// ─────────────────────────────────────────────────────────────

class ReservationNotificationService {
  static final ReservationNotificationService _instance =
      ReservationNotificationService._internal();
  factory ReservationNotificationService() => _instance;
  ReservationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Track which notifications have already been sent this session
  final Set<String> _sentKeys = {};

  // ── Android channel constants ─────────────────────────────
  static const _chCheckIn = AndroidNotificationDetails(
    'ch_checkin',
    'Check-in Reminders',
    channelDescription: 'Alerts before a guest is expected to arrive',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _chCheckOut = AndroidNotificationDetails(
    'ch_checkout',
    'Check-out Warnings',
    channelDescription: 'Alerts when a reservation is about to end',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _chLongSeated = AndroidNotificationDetails(
    'ch_long_seated',
    'Long-seated Alerts',
    channelDescription: 'Alerts when guests have been seated for too long',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    playSound: false,
    icon: '@mipmap/ic_launcher',
  );

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // ── Init ─────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // v20.x: `settings` is now a NAMED parameter
      await _plugin.initialize(settings: initSettings);

      _initialized = true;
      debugPrint('[Notif] Initialized successfully');
    } catch (e) {
      debugPrint('[Notif] Init error (non-fatal): $e');
    }
  }

  // ── Core send helper ─────────────────────────────────────
  Future<void> _send({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) async {
    if (!_initialized) return;
    try {
      final details = NotificationDetails(
        android: androidDetails,
        iOS: _iosDetails,
      );
      // v20.x: `id`, `title`, `body` are NAMED; `notificationDetails` stays positional
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[Notif] Send error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  CHECK TABLES — call this every minute from provider
  // ─────────────────────────────────────────────────────────
  Future<void> checkAll({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 120, // alert after 2 hours seated
  }) async {
    if (!_initialized) return;
    final now = DateTime.now();

    for (final table in tables) {
      // ── CHECK-IN reminders ──────────────────────────────
      final res = table.reservation;
      if (res != null && table.status == TableStatus.reserved) {
        final diffMins = res.reservedFor.difference(now).inMinutes;

        // 30-min reminder
        if (diffMins >= 28 && diffMins <= 32) {
          final key = 'checkin_30_${res.id}';
          if (!_sentKeys.contains(key)) {
            _sentKeys.add(key);
            await _send(
              id: 1000 + table.tableNumber,
              title: '🟡 Guest Arriving in 30 min — ${table.tableName}',
              body:
                  '${res.customerName} · ${res.guestCount} guests · ${res.timeLabel}'
                  '${businessName.isNotEmpty ? '\n$businessName' : ''}',
              androidDetails: _chCheckIn,
            );
          }
        }

        // 15-min reminder
        if (diffMins >= 13 && diffMins <= 17) {
          final key = 'checkin_15_${res.id}';
          if (!_sentKeys.contains(key)) {
            _sentKeys.add(key);
            await _send(
              id: 2000 + table.tableNumber,
              title: '🔔 Guest Arriving in 15 min — ${table.tableName}',
              body:
                  '${res.customerName} · ${res.guestCount} guests · ${res.timeLabel}'
                  '${businessName.isNotEmpty ? '\n$businessName' : ''}',
              androidDetails: _chCheckIn,
            );
          }
        }

        // ── CHECK-OUT warning (15 min before) ──────────────
        final minsToOut = res.minutesUntilCheckOut;
        if (minsToOut != null && minsToOut >= 13 && minsToOut <= 17) {
          final key = 'checkout_15_${res.id}';
          if (!_sentKeys.contains(key)) {
            _sentKeys.add(key);
            await _send(
              id: 3000 + table.tableNumber,
              title: '🔴 Reservation Ending in 15 min — ${table.tableName}',
              body:
                  '${res.customerName} · Check-out at ${res.checkOutTimeLabel}'
                  '${businessName.isNotEmpty ? '\n$businessName' : ''}',
              androidDetails: _chCheckOut,
            );
          }
        }
      }

      // ── LONG-SEATED alert ───────────────────────────────
      if (table.status == TableStatus.occupied && table.occupiedSince != null) {
        final seatedMins = now.difference(table.occupiedSince!).inMinutes;

        // Alert at exactly the threshold (within a 5-min window)
        if (seatedMins >= longSeatedMinutes &&
            seatedMins < longSeatedMinutes + 5) {
          final key = 'long_seated_${table.id}_${longSeatedMinutes}';
          if (!_sentKeys.contains(key)) {
            _sentKeys.add(key);
            final hrs = longSeatedMinutes ~/ 60;
            final label = hrs > 0 ? '${hrs}h' : '${longSeatedMinutes}m';
            await _send(
              id: 4000 + table.tableNumber,
              title: '⏱️ Long-seated Alert — ${table.tableName} ($label)',
              body:
                  '${table.currentCustomerName ?? 'Guest'} has been seated for $label'
                  '${businessName.isNotEmpty ? '\n$businessName' : ''}',
              androidDetails: _chLongSeated,
            );
          }
        }
      }
    }
  }

  /// Call when a reservation is cancelled/seated to clear its sent keys
  void clearReservationKeys(String reservationId) {
    _sentKeys.removeWhere((k) => k.contains(reservationId));
  }

  /// Reset all sent keys (e.g. on app restart)
  void resetSentKeys() => _sentKeys.clear();
}
