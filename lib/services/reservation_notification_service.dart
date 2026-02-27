// ignore_for_file: avoid_print

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:pos_app/models/table_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  zonedSchedule() signature in THIS version (from the error message):
//
//  Future<void> zonedSchedule({
//    required int id,
//    required TZDateTime scheduledDate,         ← named, NOT positional
//    required NotificationDetails notificationDetails,
//    required AndroidScheduleMode androidScheduleMode,
//    String? title,
//    String? body,
//    ...
//  })
//
//  show() and cancel() are also ALL named in this version.
// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION ID RANGES
//  1000–1999 : check-in ~30 min
//  2000–2999 : check-in ~15 min
//  3000–3999 : check-out ~15 min
//  4000–4999 : long-seated (runtime)
//  5000–5999 : check-in ~20 min
// ─────────────────────────────────────────────────────────────────────────────

class ReservationNotificationService {
  static final ReservationNotificationService _instance =
      ReservationNotificationService._internal();
  factory ReservationNotificationService() => _instance;
  ReservationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzInitialized = false;

  final Set<String> _sentKeys = {};

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── ID helpers ────────────────────────────────────────────────────────────
  static int checkIn30Id(int t) => 1000 + t;
  static int checkIn20Id(int t) => 5000 + t;
  static int checkIn15Id(int t) => 2000 + t;
  static int checkOutId(int t) => 3000 + t;
  static int longSeatedId(int t) => 4000 + t;

  // ── Android channel definitions ───────────────────────────────────────────
  static const _chCheckIn = AndroidNotificationDetails(
    'ch_checkin',
    'Check-in Reminders',
    channelDescription: 'Alerts when a guest is about to arrive',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _chCheckOut = AndroidNotificationDetails(
    'ch_checkout',
    'Check-out Warnings',
    channelDescription: 'Alerts when a reservation is ending soon',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _chLongSeated = AndroidNotificationDetails(
    'ch_long_seated',
    'Long-seated Alerts',
    channelDescription: 'Alerts when guests have been seated too long',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    playSound: false,
    icon: '@mipmap/ic_launcher',
  );

  static const _ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!_tzInitialized) {
        tzData.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        } catch (_) {
          tz.setLocalLocation(tz.UTC);
        }
        _tzInitialized = true;
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();

      _initialized = true;
      debugPrint('[Notif] ✅ Initialized');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Init error: $e');
    }
  }

  // ── Schedule (fires even when app is killed) ──────────────────────────────
  //
  //  Using ALL named parameters as shown in the error:
  //    required int id
  //    required TZDateTime scheduledDate
  //    required NotificationDetails notificationDetails
  //    required AndroidScheduleMode androidScheduleMode
  //    String? title
  //    String? body
  //
  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required AndroidNotificationDetails androidDetails,
  }) async {
    if (!_initialized) return;
    if (fireAt.isBefore(DateTime.now())) {
      debugPrint('[Notif] ⏭ Skipped past time: "$title"');
      return;
    }
    try {
      final tzTime = tz.TZDateTime.from(fireAt, tz.local);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: _ios,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // exactAllowWhileIdle → fires even during Android Doze mode
      );
      log('[Notif] ⏰ Scheduled "$title" at $fireAt');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Schedule error: $e');
    }
  }

  // ── Immediate send (long-seated, called from WorkManager + foreground) ────
  Future<void> sendImmediate({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: _ios,
        ),
      );
      debugPrint('[Notif] 🔔 Sent: "$title"');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Send error: $e');
    }
  }

  // ── Cancel a single scheduled notification ────────────────────────────────
  Future<void> _cancelId(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Schedule all reminders for a reservation
  //  Call from TablesProvider.addReservation() and updateReservation()
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> scheduleReservationReminders({
    required RestaurantTable table,
    required Reservation reservation,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    // Cancel old alarms first (handles edits)
    await cancelReservationScheduled(reservation.id, table.tableNumber);

    final resTime = reservation.reservedFor;
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';
    final tName = table.tableName;
    final guestInfo =
        '${reservation.customerName} · ${reservation.guestCount} guests · ${reservation.timeLabel}$biz';

    // 30-min check-in reminder
    await _scheduleAt(
      id: checkIn30Id(table.tableNumber),
      title: '🟡 Guest arriving in 30 min — $tName',
      body: guestInfo,
      fireAt: resTime.subtract(const Duration(minutes: 30)),
      androidDetails: _chCheckIn,
    );

    // 20-min check-in reminder
    await _scheduleAt(
      id: checkIn20Id(table.tableNumber),
      title: '🟠 Guest arriving in 20 min — $tName',
      body: guestInfo,
      fireAt: resTime.subtract(const Duration(minutes: 20)),
      androidDetails: _chCheckIn,
    );

    // 15-min check-in reminder
    await _scheduleAt(
      id: checkIn15Id(table.tableNumber),
      title: '🔔 Guest arriving in 15 min — $tName',
      body: guestInfo,
      fireAt: resTime.subtract(const Duration(minutes: 15)),
      androidDetails: _chCheckIn,
    );

    await _scheduleAt(
      id: checkIn15Id(table.tableNumber),
      title: '🔔 Guest arriving in 5 min — $tName',
      body: guestInfo,
      fireAt: resTime.subtract(const Duration(minutes: 5)),
      androidDetails: _chCheckIn,
    );

    // 15-min check-out warning
    if (reservation.checkOut != null) {
      await _scheduleAt(
        id: checkOutId(table.tableNumber),
        title: '🔴 Reservation ending in 15 min — $tName',
        body:
            '${reservation.customerName} · Check-out at ${reservation.checkOutTimeLabel}$biz',
        fireAt: reservation.checkOut!.subtract(const Duration(minutes: 15)),
        androidDetails: _chCheckOut,
      );
    }

    debugPrint('[Notif] ✅ All alarms set for reservation ${reservation.id}');
  }

  // ── Cancel all OS alarms for a reservation ────────────────────────────────
  Future<void> cancelReservationScheduled(
    String reservationId,
    int tableNumber,
  ) async {
    await _cancelId(checkIn30Id(tableNumber));
    await _cancelId(checkIn20Id(tableNumber));
    await _cancelId(checkIn15Id(tableNumber));
    await _cancelId(checkOutId(tableNumber));
    debugPrint('[Notif] 🗑️ Cancelled alarms for table $tableNumber');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Long-seated check — called by WorkManager (background) + foreground timer
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> checkLongSeated({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final now = DateTime.now();
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';

    for (final table in tables) {
      if (table.status == TableStatus.occupied && table.occupiedSince != null) {
        final seatedMins = now.difference(table.occupiedSince!).inMinutes;
        if (seatedMins >= longSeatedMinutes) {
          final bucket = ((seatedMins - longSeatedMinutes) ~/ 30) * 30;
          final totalMins = longSeatedMinutes + bucket;
          final h = totalMins ~/ 60;
          final m = totalMins % 60;
          final label = m > 0 ? '${h}h ${m}m' : '${h}h';
          final key = '${_today}_ls_${table.id}_$totalMins';

          if (!_sentKeys.contains(key)) {
            _sentKeys.add(key);
            await sendImmediate(
              id: longSeatedId(table.tableNumber),
              title: '⏱️ Long stay — ${table.tableName} ($label)',
              body:
                  '${table.currentCustomerName ?? 'Guest'} seated for $label$biz',
              androidDetails: _chLongSeated,
            );
          }
        }
      }
    }
  }

  // Legacy alias — keeps TablesProvider.checkAll() calls working
  Future<void> checkAll({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) => checkLongSeated(
    tables: tables,
    businessName: businessName,
    longSeatedMinutes: longSeatedMinutes,
  );

  void clearReservationKeys(String reservationId) =>
      _sentKeys.removeWhere((k) => k.contains(reservationId));

  void resetSentKeys() => _sentKeys.clear();

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notif] Cancelled all');
  }

  // Expose channel for WorkManager background isolate
  static AndroidNotificationDetails get longSeatedChannel => _chLongSeated;
}
