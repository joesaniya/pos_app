// ignore_for_file: avoid_print

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:pos_app/models/table_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION ID RANGES
//  1000–1999 : check-in 30-min
//  2000–2999 : check-in 15-min
//  3000–3999 : check-out 15-min  ← primary checkout alarm
//  4000–4999 : long-seated
//  5000–5999 : check-in 20-min
//  6000–6999 : check-in 5-min
//  7000–7999 : check-out 30-min
//  7500–7999 : check-out 5-min
//
//  HOW NOTIFICATIONS WORK IN ALL STATES:
//
//  ┌─────────────────┬────────────────────────────────────────────────────┐
//  │ App state       │ Mechanism                                          │
//  ├─────────────────┼────────────────────────────────────────────────────┤
//  │ Foreground      │ _notifTimer (1-min) in TablesProvider calls        │
//  │                 │ checkAll() → sends long-seated immediately AND      │
//  │                 │ re-schedules any missing checkout alarms            │
//  ├─────────────────┼────────────────────────────────────────────────────┤
//  │ Background      │ WorkManager 15-min task runs _runChecks() which    │
//  │                 │ re-queries Supabase and re-schedules missing alarms │
//  ├─────────────────┼────────────────────────────────────────────────────┤
//  │ Killed/         │ OS fires zonedSchedule(exactAllowWhileIdle) alarms  │
//  │ Terminated      │ already set. WorkManager wakes app in bg every 15m │
//  │                 │ to re-schedule any that were cleared by OEM.        │
//  └─────────────────┴────────────────────────────────────────────────────┘
//
//  KEY FIX for "checkout not firing when killed":
//  • Importance.max + Priority.max on the checkout channel (OEM requirement)
//  • SharedPreferences-backed sent-key store (survives app restarts)
//  • checkAll() now also calls _ensureCheckoutAlarms() so the foreground
//    timer re-schedules checkout if the OS cleared it
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

  // ── Sent-key store backed by SharedPreferences so it survives restarts ───
  // In-memory cache for fast lookups; synced to prefs on write.
  Set<String> _sentKeys = {};
  static const _kSentKeys = '_notif_sent_keys';

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ── Notification ID helpers ───────────────────────────────────────────────
  static int checkIn30Id(int t) => 1000 + t;
  static int checkIn20Id(int t) => 5000 + t;
  static int checkIn15Id(int t) => 2000 + t;
  static int checkIn5Id(int t) => 6000 + t;
  static int checkOut30Id(int t) => 7000 + t;
  static int checkOutId(int t) => 3000 + t; // 15-min
  static int checkOut5Id(int t) => 7500 + t;
  static int longSeatedId(int t) => 4000 + t;

  // ── Channel definitions ───────────────────────────────────────────────────
  static const _chCheckIn = AndroidNotificationDetails(
    'ch_checkin',
    'Check-in Reminders',
    channelDescription: 'Alerts when a guest is about to arrive',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  // CRITICAL: Importance.max so OEMs (Samsung/Xiaomi/OPPO) don't suppress
  // this alarm when the app is killed.
  static const _chCheckOut = AndroidNotificationDetails(
    'ch_checkout',
    'Check-out Warnings',
    channelDescription: 'Alerts when a reservation is ending soon',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
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

  static const _iosCheckOut = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
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

      // Load persisted sent-keys so we don't re-fire after restart
      await _loadSentKeys();

      _initialized = true;
      debugPrint('[Notif] ✅ Initialized');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Init error: $e');
    }
  }

  // ── Sent-key persistence ──────────────────────────────────────────────────
  Future<void> _loadSentKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kSentKeys) ?? [];
      // Only keep today's keys to prevent unbounded growth
      _sentKeys = raw.where((k) => k.startsWith(_today)).toSet();
    } catch (e) {
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

  Future<void> _markSent(String key) async {
    _sentKeys.add(key);
    await _persistSentKeys();
  }

  // ── Core: schedule a future notification ─────────────────────────────────
  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required AndroidNotificationDetails androidDetails,
    DarwinNotificationDetails? iosDetails,
  }) async {
    if (!_initialized) return;
    if (fireAt.isBefore(DateTime.now())) {
      debugPrint('[Notif] ⏭ Past — skipped: "$title"');
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails ?? _ios,
        ),
        // exactAllowWhileIdle = fires even in Doze/killed state
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      log('[Notif] ⏰ Scheduled id=$id "$title" → $fireAt');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Schedule error id=$id: $e');
    }
  }

  // ── Core: send immediately ────────────────────────────────────────────────
  Future<void> _sendNow({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
    DarwinNotificationDetails? iosDetails,
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
          iOS: iosDetails ?? _ios,
        ),
      );
      debugPrint('[Notif] 🔔 Sent: "$title"');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Send error: $e');
    }
  }

  Future<void> _cancelId(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC: Schedule all reminders when a reservation is created/updated
  //  Called by TablesProvider.addReservation() & updateReservation()
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> scheduleReservationReminders({
    required RestaurantTable table,
    required Reservation reservation,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    // Cancel previous alarms for this table (handles edits)
    await cancelReservationScheduled(reservation.id, table.tableNumber);

    final t = table.tableNumber;
    final tName = table.tableName;
    final resTime = reservation.reservedFor;
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';
    final arrInfo =
        '${reservation.customerName} · '
        '${reservation.guestCount} guests · '
        '${reservation.timeLabel}$biz';

    // ── Check-in alarms ───────────────────────────────────────────────────
    await _scheduleAt(
      id: checkIn30Id(t),
      title: '🟡 Guest arriving in 30 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 30)),
      androidDetails: _chCheckIn,
    );
    await _scheduleAt(
      id: checkIn20Id(t),
      title: '🟠 Guest arriving in 20 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 20)),
      androidDetails: _chCheckIn,
    );
    await _scheduleAt(
      id: checkIn15Id(t),
      title: '🔔 Guest arriving in 15 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 15)),
      androidDetails: _chCheckIn,
    );
    await _scheduleAt(
      id: checkIn5Id(t), // ← uses dedicated ID, not checkIn15Id
      title: '🚨 Guest arriving in 5 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 5)),
      androidDetails: _chCheckIn,
    );

    // ── Check-out alarms ─────────────────────────────────────────────────
    if (reservation.checkOut != null) {
      final coTime = reservation.checkOut!;
      final coInfo =
          '${reservation.customerName} · '
          'Check-out at ${reservation.checkOutTimeLabel}$biz';

      await _scheduleAt(
        id: checkOut30Id(t),
        title: '🟡 Reservation ending in 30 min — $tName',
        body: coInfo,
        fireAt: coTime.subtract(const Duration(minutes: 30)),
        androidDetails: _chCheckOut,
        iosDetails: _iosCheckOut,
      );
      await _scheduleAt(
        id: checkOutId(t),
        title: '🔴 Reservation ending in 15 min — $tName',
        body: coInfo,
        fireAt: coTime.subtract(const Duration(minutes: 15)),
        androidDetails: _chCheckOut,
        iosDetails: _iosCheckOut,
      );
      await _scheduleAt(
        id: checkOut5Id(t),
        title: '🚨 Reservation ending in 5 min — $tName',
        body: coInfo,
        fireAt: coTime.subtract(const Duration(minutes: 5)),
        androidDetails: _chCheckOut,
        iosDetails: _iosCheckOut,
      );

      log('[Notif] ✅ Checkout alarms set for $tName at $coTime');
    }

    log('[Notif] ✅ All alarms set for reservation ${reservation.id}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC: checkAll()
  //  Called by TablesProvider every 1 minute (foreground timer).
  //
  //  Does TWO things:
  //  1. Long-seated immediate alerts  (same as before)
  //  2. Re-schedules checkout alarms  (NEW — ensures checkout works even
  //     if the OS cleared the zonedSchedule alarm after an app kill)
  //
  //  The `tables` list contains RestaurantTable objects which already have
  //  the Reservation attached (including checkOut).  We use those to
  //  re-schedule without a Supabase query.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> checkAll({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final now = DateTime.now();
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';

    for (final table in tables) {
      // ── 1. Long-seated immediate alert ──────────────────────────────────
      if (table.status == TableStatus.occupied && table.occupiedSince != null) {
        final seatedMins = now.difference(table.occupiedSince!).inMinutes;
        if (seatedMins >= longSeatedMinutes) {
          final bucket = ((seatedMins - longSeatedMinutes) ~/ 30) * 30;
          final totalMins = longSeatedMinutes + bucket;
          final h = totalMins ~/ 60;
          final m = totalMins % 60;
          final label = m > 0 ? '${h}h ${m}m' : '${h}h';
          final key = '${_today}_ls_${table.id}_$totalMins';

          if (!_hasSent(key)) {
            await _markSent(key);
            await _sendNow(
              id: longSeatedId(table.tableNumber),
              title: '⏱️ Long stay — ${table.tableName} ($label)',
              body:
                  '${table.currentCustomerName ?? 'Guest'} seated for $label$biz',
              androidDetails: _chLongSeated,
            );
          }
        }
      }

      // ── 2. Re-schedule checkout alarms (safety net) ───────────────────
      // Why: OEMs (Samsung/Xiaomi/OPPO) can clear scheduled exact alarms
      // when the app is force-stopped or updated.  We re-schedule here
      // from the foreground timer so alarms are always live while app runs.
      // The background WorkManager task does the same when app is killed.
      final res = table.reservation;
      if (res != null && res.checkOut != null) {
        final coTime = res.checkOut!;
        final minsLeft = coTime.difference(now).inMinutes;

        // Only act if checkout is still in the future and within 35 min
        if (minsLeft > 0 && minsLeft <= 35) {
          final tName = table.tableName;
          final coInfo =
              '${res.customerName} · '
              'Check-out at ${res.checkOutTimeLabel}$biz';

          // 30-min alarm
          if (minsLeft > 30) {
            final k = '${_today}_co30_${res.id}';
            if (!_hasSent(k)) {
              await _scheduleAt(
                id: checkOut30Id(table.tableNumber),
                title: '🟡 Reservation ending in 30 min — $tName',
                body: coInfo,
                fireAt: coTime.subtract(const Duration(minutes: 30)),
                androidDetails: _chCheckOut,
                iosDetails: _iosCheckOut,
              );
            }
          }

          // 15-min alarm
          if (minsLeft > 15) {
            final k = '${_today}_co15_${res.id}';
            if (!_hasSent(k)) {
              await _scheduleAt(
                id: checkOutId(table.tableNumber),
                title: '🔴 Reservation ending in 15 min — $tName',
                body: coInfo,
                fireAt: coTime.subtract(const Duration(minutes: 15)),
                androidDetails: _chCheckOut,
                iosDetails: _iosCheckOut,
              );
            }
          }

          // 5-min alarm or immediate
          if (minsLeft <= 5) {
            final k = '${_today}_co5_${res.id}';
            if (!_hasSent(k)) {
              await _markSent(k);
              await _sendNow(
                id: checkOut5Id(table.tableNumber),
                title: '🚨 Reservation ending in 5 min — $tName',
                body: coInfo,
                androidDetails: _chCheckOut,
                iosDetails: _iosCheckOut,
              );
            }
          } else if (minsLeft <= 10) {
            final k = '${_today}_co5_${res.id}';
            if (!_hasSent(k)) {
              await _scheduleAt(
                id: checkOut5Id(table.tableNumber),
                title: '🚨 Reservation ending in 5 min — $tName',
                body: coInfo,
                fireAt: coTime.subtract(const Duration(minutes: 5)),
                androidDetails: _chCheckOut,
                iosDetails: _iosCheckOut,
              );
            }
          }
        }

        // Also fire immediately when checkout time is NOW (within 1 min past)
        if (minsLeft >= -1 && minsLeft <= 0) {
          final k = '${_today}_coNow_${res.id}';
          if (!_hasSent(k)) {
            await _markSent(k);
            await _sendNow(
              id: checkOutId(table.tableNumber),
              title: '🔴 Reservation check-out time — ${table.tableName}',
              body: '${res.customerName} · checkout time reached$biz',
              androidDetails: _chCheckOut,
              iosDetails: _iosCheckOut,
            );
          }
        }
      }
    }
  }

  // ── Legacy alias ──────────────────────────────────────────────────────────
  Future<void> checkLongSeated({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) => checkAll(
    tables: tables,
    businessName: businessName,
    longSeatedMinutes: longSeatedMinutes,
  );

  // ── sendImmediate (public — used by background isolate) ───────────────────
  Future<void> sendImmediate({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) => _sendNow(
    id: id,
    title: title,
    body: body,
    androidDetails: androidDetails,
  );

  // ── Cancel all alarms for one reservation ─────────────────────────────────
  Future<void> cancelReservationScheduled(
    String reservationId,
    int tableNumber,
  ) async {
    await _cancelId(checkIn30Id(tableNumber));
    await _cancelId(checkIn20Id(tableNumber));
    await _cancelId(checkIn15Id(tableNumber));
    await _cancelId(checkIn5Id(tableNumber));
    await _cancelId(checkOut30Id(tableNumber));
    await _cancelId(checkOutId(tableNumber));
    await _cancelId(checkOut5Id(tableNumber));
    debugPrint('[Notif] 🗑️ Cancelled all alarms for table $tableNumber');
  }

  void clearReservationKeys(String reservationId) {
    _sentKeys.removeWhere((k) => k.contains(reservationId));
    _persistSentKeys();
  }

  void resetSentKeys() {
    _sentKeys.clear();
    _persistSentKeys();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notif] Cancelled all');
  }

  // Expose channels for background isolate
  static AndroidNotificationDetails get longSeatedChannel => _chLongSeated;
  static AndroidNotificationDetails get checkOutChannel => _chCheckOut;
}

/*// ignore_for_file: avoid_print

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
*/
