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
//  3000–3999 : check-out 15-min
//  4000–4999 : long-seated
//  5000–5999 : check-in 20-min
//  6000–6999 : check-in 5-min
//  7000–7999 : check-out 30-min
//  7500–7999 : check-out 5-min
//  8000–8999 : CANCELLATION / NO-SHOW
//  9000–9999 : WALK-IN SLOT WARNING
// 10000–10999: AUTO-EXPIRY (slot passed, guest never arrived)
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
  static int checkOutId(int t) => 3000 + t;
  static int checkOut5Id(int t) => 7500 + t;
  static int longSeatedId(int t) => 4000 + t;
  static int cancellationId(int t) => 8000 + t;
  static int walkInWarningId(int t) => 9000 + t;
  static int expiryId(int t) => 10000 + t; // auto-expiry notification

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

  // NEW: Cancellation channel — high importance so it fires in silent/night mode
  static const _chCancellation = AndroidNotificationDetails(
    'ch_cancellation',
    'Reservation Cancellations',
    channelDescription: 'Alerts when a reservation or order is cancelled',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
    // Bypass DND on Android 13+ for critical operational alerts
    fullScreenIntent: false,
  );

  // NEW: Walk-in slot warning — high importance
  static const _chWalkInWarning = AndroidNotificationDetails(
    'ch_walkin_warning',
    'Walk-in Slot Warnings',
    channelDescription: 'Alerts when a walk-in session is near a reservation slot',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  // NEW: Auto-expiry channel — high importance, fires even in silent mode
  static const _chExpiry = AndroidNotificationDetails(
    'ch_expiry',
    'Expired Reservations',
    channelDescription: 'Alerts when a reservation expires because the guest never arrived',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
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

  // NEW: iOS cancellation — time-sensitive to bypass Focus/Silent mode
  static const _iosCancellation = DarwinNotificationDetails(
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
  //  PUBLIC: Schedule all reminders for a reservation
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> scheduleReservationReminders({
    required RestaurantTable table,
    required Reservation reservation,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    await cancelReservationScheduled(reservation.id, table.tableNumber);

    final t = table.tableNumber;
    final tName = table.tableName;
    final resTime = reservation.reservedFor;
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';
    final arrInfo =
        '${reservation.customerName} · '
        '${reservation.guestCount} guests · '
        '${reservation.timeLabel}$biz';

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
      id: checkIn5Id(t),
      title: '🚨 Guest arriving in 5 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 5)),
      androidDetails: _chCheckIn,
    );

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
  //  NEW: sendCancellationNotification
  //
  //  Fires immediately when a reservation is cancelled or marked no-show.
  //  Uses Importance.max + InterruptionLevel.timeSensitive so it fires
  //  even in silent/night mode on both Android and iOS.
  //
  //  reason: 'cancelled' | 'no_show'
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sendCancellationNotification({
    required int tableNumber,
    required String customerName,
    required String reason,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final tName = 'T${tableNumber.toString().padLeft(2, '0')}';
    final biz = businessName.isNotEmpty ? ' · $businessName' : '';

    final String title;
    final String body;

    if (reason == 'no_show') {
      title = '👻 No-show — $tName';
      body = '$customerName did not arrive. Table is now free.$biz';
    } else {
      title = '✖️ Reservation cancelled — $tName';
      body = 'Booking for $customerName has been cancelled. Table is now free.$biz';
    }

    // Use a unique key so we don't suppress if same table cancels twice
    final key =
        '${_today}_cancel_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
    await _markSent(key);

    await _sendNow(
      id: cancellationId(tableNumber),
      title: title,
      body: body,
      androidDetails: _chCancellation,
      iosDetails: _iosCancellation,
    );

    log('[Notif] ✖️ Cancellation sent for $tName ($reason)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NEW: sendExpiryNotification
  //
  //  Fires when a reservation is auto-expired because:
  //    - The guest never checked in (check_in IS NULL)
  //    - The reserved time slot has completely passed
  //
  //  Uses Importance.high so it fires in silent/night mode.
  //  The message clearly tells staff the table is now free.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sendExpiryNotification({
    required int tableNumber,
    required String customerName,
    required DateTime reservedFor,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final tName = 'T${tableNumber.toString().padLeft(2, '0')}';
    final biz = businessName.isNotEmpty ? ' · $businessName' : '';

    // Format the reservation time for the notification body
    final h = reservedFor.hour;
    final m = reservedFor.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final timeStr = '$h12:$m $suf';

    // Use a timestamp-based key so repeated expiries for same table always fire
    final key =
        '${_today}_expiry_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
    await _markSent(key);

    await _sendNow(
      id: expiryId(tableNumber),
      title: '⏰ Reservation expired — $tName is now free',
      body:
          '$customerName (booked $timeStr) did not arrive. '
          'Table is available.$biz',
      androidDetails: _chExpiry,
      iosDetails: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    log('[Notif] ⏰ Expiry notification sent for $tName ($customerName at $timeStr)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NEW: sendWalkInSlotWarning
  //
  //  Fires when a walk-in guest is seated at a table that has an upcoming
  //  reservation today. Warns staff of the deadline.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sendWalkInSlotWarning({
    required int tableNumber,
    required String customerName,
    required DateTime reservationTime,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final tName = 'T${tableNumber.toString().padLeft(2, '0')}';
    final biz = businessName.isNotEmpty ? ' · $businessName' : '';
    final h = reservationTime.hour;
    final m = reservationTime.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final timeStr = '$h12:$m $suf';

    await _sendNow(
      id: walkInWarningId(tableNumber),
      title: '⚠️ Walk-in seated — $tName has a reservation at $timeStr',
      body:
          '$customerName seated. Next reservation at $timeStr — '
          'ensure table is free before then.$biz',
      androidDetails: _chWalkInWarning,
      iosDetails: _iosCancellation,
    );

    // Also schedule a 15-min-before warning for the walk-in staff
    final warnAt = reservationTime.subtract(const Duration(minutes: 15));
    if (warnAt.isAfter(DateTime.now())) {
      await _scheduleAt(
        id: walkInWarningId(tableNumber) + 500,
        title: '🚨 Clear $tName in 15 min — reservation arriving',
        body:
            'Walk-in on $tName must finish. '
            'Reservation for ${reservationTime.hour > 12 ? reservationTime.hour - 12 : reservationTime.hour}:$m $suf arriving.$biz',
        fireAt: warnAt,
        androidDetails: _chWalkInWarning,
        iosDetails: _iosCancellation,
      );
      log('[Notif] ⚠️ Walk-in 15-min warning scheduled for $tName at $warnAt');
    }

    log('[Notif] ⚠️ Walk-in slot warning sent for $tName');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC: checkAll()
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

      // ── 2. Walk-in near reservation slot warning ─────────────────────────
      // If a table is occupied (walk-in) AND has an upcoming reservation today,
      // warn staff when the walk-in is getting close to the reserved slot.
      if (table.status == TableStatus.occupied && table.reservation != null) {
        final res = table.reservation!;
        final minsUntilRes = res.reservedFor.difference(now).inMinutes;

        // Warn at 20 min, 10 min before the reservation starts
        if (minsUntilRes > 0 && minsUntilRes <= 20) {
          final key = '${_today}_walkin_warn_${table.id}_${minsUntilRes ~/ 10}';
          if (!_hasSent(key)) {
            await _markSent(key);
            final h = res.reservedFor.hour;
            final m = res.reservedFor.minute.toString().padLeft(2, '0');
            final suf = h >= 12 ? 'PM' : 'AM';
            final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
            await _sendNow(
              id: walkInWarningId(table.tableNumber),
              title: '⚠️ ${table.tableName}: reservation in ${minsUntilRes}m!',
              body:
                  'Walk-in still seated. ${res.customerName} reserved for $h12:$m $suf.$biz',
              androidDetails: _chWalkInWarning,
              iosDetails: _iosCancellation,
            );
          }
        }
      }

      // ── 3. Re-schedule checkout alarms (safety net) ───────────────────────
      final res = table.reservation;
      if (res != null && res.checkOut != null) {
        final coTime = res.checkOut!;
        final minsLeft = coTime.difference(now).inMinutes;

        if (minsLeft > 0 && minsLeft <= 35) {
          final tName = table.tableName;
          final coInfo =
              '${res.customerName} · '
              'Check-out at ${res.checkOutTimeLabel}$biz';

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

  Future<void> checkLongSeated({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) => checkAll(
    tables: tables,
    businessName: businessName,
    longSeatedMinutes: longSeatedMinutes,
  );

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
    await _cancelId(walkInWarningId(tableNumber));
    await _cancelId(walkInWarningId(tableNumber) + 500);
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

  static AndroidNotificationDetails get longSeatedChannel => _chLongSeated;
  static AndroidNotificationDetails get checkOutChannel => _chCheckOut;
  static AndroidNotificationDetails get cancellationChannel => _chCancellation;
}


/*

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
//  3000–3999 : check-out 15-min
//  4000–4999 : long-seated
//  5000–5999 : check-in 20-min
//  6000–6999 : check-in 5-min
//  7000–7999 : check-out 30-min
//  7500–7999 : check-out 5-min
//  8000–8999 : CANCELLATION / NO-SHOW  ← NEW
//  9000–9999 : WALK-IN SLOT WARNING    ← NEW
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
  static int checkOutId(int t) => 3000 + t;
  static int checkOut5Id(int t) => 7500 + t;
  static int longSeatedId(int t) => 4000 + t;
  static int cancellationId(int t) => 8000 + t; // ← NEW
  static int walkInWarningId(int t) => 9000 + t; // ← NEW

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

  // NEW: Cancellation channel — high importance so it fires in silent/night mode
  static const _chCancellation = AndroidNotificationDetails(
    'ch_cancellation',
    'Reservation Cancellations',
    channelDescription: 'Alerts when a reservation or order is cancelled',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    channelShowBadge: true,
    // Bypass DND on Android 13+ for critical operational alerts
    fullScreenIntent: false,
  );

  // NEW: Walk-in slot warning — high importance
  static const _chWalkInWarning = AndroidNotificationDetails(
    'ch_walkin_warning',
    'Walk-in Slot Warnings',
    channelDescription:
        'Alerts when a walk-in session is near a reservation slot',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
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

  // NEW: iOS cancellation — time-sensitive to bypass Focus/Silent mode
  static const _iosCancellation = DarwinNotificationDetails(
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
  //  PUBLIC: Schedule all reminders for a reservation
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> scheduleReservationReminders({
    required RestaurantTable table,
    required Reservation reservation,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    await cancelReservationScheduled(reservation.id, table.tableNumber);

    final t = table.tableNumber;
    final tName = table.tableName;
    final resTime = reservation.reservedFor;
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';
    final arrInfo =
        '${reservation.customerName} · '
        '${reservation.guestCount} guests · '
        '${reservation.timeLabel}$biz';

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
      id: checkIn5Id(t),
      title: '🚨 Guest arriving in 5 min — $tName',
      body: arrInfo,
      fireAt: resTime.subtract(const Duration(minutes: 5)),
      androidDetails: _chCheckIn,
    );

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
  //  NEW: sendCancellationNotification
  //
  //  Fires immediately when a reservation is cancelled or marked no-show.
  //  Uses Importance.max + InterruptionLevel.timeSensitive so it fires
  //  even in silent/night mode on both Android and iOS.
  //
  //  reason: 'cancelled' | 'no_show'
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sendCancellationNotification({
    required int tableNumber,
    required String customerName,
    required String reason,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final tName = 'T${tableNumber.toString().padLeft(2, '0')}';
    final biz = businessName.isNotEmpty ? ' · $businessName' : '';

    final String title;
    final String body;

    if (reason == 'no_show') {
      title = '👻 No-show — $tName';
      body = '$customerName did not arrive. Table is now free.$biz';
    } else {
      title = '✖️ Reservation cancelled — $tName';
      body =
          'Booking for $customerName has been cancelled. Table is now free.$biz';
    }

    // Use a unique key so we don't suppress if same table cancels twice
    final key =
        '${_today}_cancel_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
    await _markSent(key);

    await _sendNow(
      id: cancellationId(tableNumber),
      title: title,
      body: body,
      androidDetails: _chCancellation,
      iosDetails: _iosCancellation,
    );

    log('[Notif] ✖️ Cancellation sent for $tName ($reason)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NEW: sendWalkInSlotWarning
  //
  //  Fires when a walk-in guest is seated at a table that has an upcoming
  //  reservation today. Warns staff of the deadline.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sendWalkInSlotWarning({
    required int tableNumber,
    required String customerName,
    required DateTime reservationTime,
    required String businessName,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final tName = 'T${tableNumber.toString().padLeft(2, '0')}';
    final biz = businessName.isNotEmpty ? ' · $businessName' : '';
    final h = reservationTime.hour;
    final m = reservationTime.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final timeStr = '$h12:$m $suf';

    await _sendNow(
      id: walkInWarningId(tableNumber),
      title: '⚠️ Walk-in seated — $tName has a reservation at $timeStr',
      body:
          '$customerName seated. Next reservation at $timeStr — '
          'ensure table is free before then.$biz',
      androidDetails: _chWalkInWarning,
      iosDetails: _iosCancellation,
    );

    // Also schedule a 15-min-before warning for the walk-in staff
    final warnAt = reservationTime.subtract(const Duration(minutes: 15));
    if (warnAt.isAfter(DateTime.now())) {
      await _scheduleAt(
        id: walkInWarningId(tableNumber) + 500,
        title: '🚨 Clear $tName in 15 min — reservation arriving',
        body:
            'Walk-in on $tName must finish. '
            'Reservation for ${reservationTime.hour > 12 ? reservationTime.hour - 12 : reservationTime.hour}:$m $suf arriving.$biz',
        fireAt: warnAt,
        androidDetails: _chWalkInWarning,
        iosDetails: _iosCancellation,
      );
      log('[Notif] ⚠️ Walk-in 15-min warning scheduled for $tName at $warnAt');
    }

    log('[Notif] ⚠️ Walk-in slot warning sent for $tName');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC: checkAll()
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

      // ── 2. Walk-in near reservation slot warning ─────────────────────────
      // If a table is occupied (walk-in) AND has an upcoming reservation today,
      // warn staff when the walk-in is getting close to the reserved slot.
      if (table.status == TableStatus.occupied && table.reservation != null) {
        final res = table.reservation!;
        final minsUntilRes = res.reservedFor.difference(now).inMinutes;

        // Warn at 20 min, 10 min before the reservation starts
        if (minsUntilRes > 0 && minsUntilRes <= 20) {
          final key = '${_today}_walkin_warn_${table.id}_${minsUntilRes ~/ 10}';
          if (!_hasSent(key)) {
            await _markSent(key);
            final h = res.reservedFor.hour;
            final m = res.reservedFor.minute.toString().padLeft(2, '0');
            final suf = h >= 12 ? 'PM' : 'AM';
            final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
            await _sendNow(
              id: walkInWarningId(table.tableNumber),
              title: '⚠️ ${table.tableName}: reservation in ${minsUntilRes}m!',
              body:
                  'Walk-in still seated. ${res.customerName} reserved for $h12:$m $suf.$biz',
              androidDetails: _chWalkInWarning,
              iosDetails: _iosCancellation,
            );
          }
        }
      }

      // ── 3. Re-schedule checkout alarms (safety net) ───────────────────────
      final res = table.reservation;
      if (res != null && res.checkOut != null) {
        final coTime = res.checkOut!;
        final minsLeft = coTime.difference(now).inMinutes;

        if (minsLeft > 0 && minsLeft <= 35) {
          final tName = table.tableName;
          final coInfo =
              '${res.customerName} · '
              'Check-out at ${res.checkOutTimeLabel}$biz';

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

  Future<void> checkLongSeated({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 240,
  }) => checkAll(
    tables: tables,
    businessName: businessName,
    longSeatedMinutes: longSeatedMinutes,
  );

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
    await _cancelId(walkInWarningId(tableNumber));
    await _cancelId(walkInWarningId(tableNumber) + 500);
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

  static AndroidNotificationDetails get longSeatedChannel => _chLongSeated;
  static AndroidNotificationDetails get checkOutChannel => _chCheckOut;
  static AndroidNotificationDetails get cancellationChannel => _chCancellation;
}
*/