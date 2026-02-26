import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pos_app/models/table_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION ID RANGES  (prevents collision across tables)
//
//  1000–1999 : check-in reminder  ~30 min before arrival
//  2000–2999 : check-in reminder  ~15 min before arrival
//  3000–3999 : check-out warning  ~15 min before check-out
//  4000–4999 : long-seated alert  (repeats every 30 min after threshold)
//
//  IDs are  base + tableNumber  so each table gets its own slot.
// ─────────────────────────────────────────────────────────────────────────────
class ReservationNotificationService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final ReservationNotificationService _instance =
      ReservationNotificationService._internal();
  factory ReservationNotificationService() => _instance;
  ReservationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Tracks keys that have already fired this session → no duplicate pops.
  final Set<String> _sentKeys = {};

  // ── Android channel definitions ──────────────────────────────────────────
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

  // ── Initialize ───────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // v20.x: `settings` is a NAMED parameter
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

      // Android 13+ (API 33) — request POST_NOTIFICATIONS permission at runtime
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
      debugPrint('[Notif] ✅ Initialized successfully');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Init error (non-fatal): $e');
    }
  }

  // ── Core send helper ─────────────────────────────────────────────────────
  Future<void> _send({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) async {
    if (!_initialized) return;
    try {
      // v20.x: id / title / body / notificationDetails are all NAMED parameters
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: _ios,
        ),
      );
      debugPrint('[Notif] ✅ Sent "$title"');
    } catch (e) {
      debugPrint('[Notif] ⚠️ Send error: $e');
    }
  }

  // ── De-duplicated notify ─────────────────────────────────────────────────
  Future<void> _maybeNotify({
    required String key,
    required bool active,
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails androidDetails,
  }) async {
    if (!active) return;
    if (_sentKeys.contains(key)) return;
    _sentKeys.add(key);
    await _send(id: id, title: title, body: body, androidDetails: androidDetails);
  }

  // ── Main scan — called every minute by TablesProvider ───────────────────
  Future<void> checkAll({
    required List<RestaurantTable> tables,
    required String businessName,
    int longSeatedMinutes = 120,
  }) async {
    // Auto-initialize if missed (defensive)
    if (!_initialized) {
      await initialize();
      if (!_initialized) return; // still failed, abort
    }

    final now = DateTime.now();
    final biz = businessName.isNotEmpty ? '\n$businessName' : '';

    for (final table in tables) {
      final res = table.reservation;

      // ─── CHECK-IN reminders ────────────────────────────────────────────
      // Only applies to tables with status = reserved AND reservation is today
      if (res != null && table.status == TableStatus.reserved) {
        final diffMins = res.reservedFor.difference(now).inMinutes;

        // ~30 min before  (window: 28–32 min)
        await _maybeNotify(
          key: 'ci30_${res.id}',
          active: diffMins >= 28 && diffMins <= 32,
          id: 1000 + table.tableNumber,
          title: '🟡 Guest in ~30 min — ${table.tableName}',
          body:
              '${res.customerName} · ${res.guestCount} guests · ${res.timeLabel}$biz',
          androidDetails: _chCheckIn,
        );

        // ~15 min before  (window: 13–17 min)
        await _maybeNotify(
          key: 'ci15_${res.id}',
          active: diffMins >= 13 && diffMins <= 17,
          id: 2000 + table.tableNumber,
          title: '🔔 Guest in ~15 min — ${table.tableName}',
          body:
              '${res.customerName} · ${res.guestCount} guests · ${res.timeLabel}$biz',
          androidDetails: _chCheckIn,
        );

        // ─── CHECK-OUT warning (~15 min before check-out) ─────────────
        final minsToOut = res.minutesUntilCheckOut;
        await _maybeNotify(
          key: 'co15_${res.id}',
          active: minsToOut != null && minsToOut >= 13 && minsToOut <= 17,
          id: 3000 + table.tableNumber,
          title: '🔴 Reservation ending in 15 min — ${table.tableName}',
          body:
              '${res.customerName} · Check-out at ${res.checkOutTimeLabel}$biz',
          androidDetails: _chCheckOut,
        );
      }

      // ─── LONG-SEATED alert ─────────────────────────────────────────────
      // Fires at threshold, then re-fires every 30 min (2h → 2h30 → 3h…)
      if (table.status == TableStatus.occupied && table.occupiedSince != null) {
        final seatedMins = now.difference(table.occupiedSince!).inMinutes;

        if (seatedMins >= longSeatedMinutes) {
          // Bucket = 0 at threshold, 30 after 30 more min, 60 after 60 more, …
          final bucket = ((seatedMins - longSeatedMinutes) ~/ 30) * 30;
          final totalMins = longSeatedMinutes + bucket;
          final h = totalMins ~/ 60;
          final m = totalMins % 60;
          final label = m > 0 ? '${h}h ${m}m' : '${h}h';
          final key = 'ls_${table.id}_$totalMins';

          await _maybeNotify(
            key: key,
            active: true,
            id: 4000 + table.tableNumber,
            title: '⏱️ Long stay — ${table.tableName} ($label)',
            body:
                '${table.currentCustomerName ?? 'Guest'} seated for $label$biz',
            androidDetails: _chLongSeated,
          );
        }
      }
    }
  }

  // ── Lifecycle helpers ────────────────────────────────────────────────────

  /// Call when a reservation is cancelled, marked no-show, or guest is seated.
  /// Clears that reservation's notification keys so they can re-fire if needed.
  void clearReservationKeys(String reservationId) {
    _sentKeys.removeWhere((k) => k.contains(reservationId));
    debugPrint('[Notif] Cleared keys for reservation $reservationId');
  }

  /// Reset ALL sent keys — call on new business day or app restart.
  void resetSentKeys() => _sentKeys.clear();
}