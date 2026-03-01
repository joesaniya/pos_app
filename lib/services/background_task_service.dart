// // lib/services/background_task_service.dart
// // ══════════════════════════════════════════════════════════════════════════════
// //  BACKGROUND TASK SERVICE  — v3
// // ══════════════════════════════════════════════════════════════════════════════

// import 'dart:developer';
// import 'dart:typed_data';

// import 'package:flutter/widgets.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest_all.dart' as tzData;
// import 'package:workmanager/workmanager.dart';
// import 'package:pos_app/config/app_config.dart';
// import 'order_notification_service.dart';

// const kBgTask = 'pos_bg_checks';
// const kBgTag = 'pos_bg_tag';
// const _kSentKeys = '_notif_sent_keys';

// // ── Notification channels ─────────────────────────────────────────────────────
// // FIX: _chReady uses Int64List.fromList which is not const — use `final` instead.

// const _chNewOrder = AndroidNotificationDetails(
//   'ch_new_order',
//   'New Orders',
//   channelDescription: 'Fires when a new order is placed',
//   importance: Importance.max,
//   priority: Priority.max,
//   playSound: true,
//   enableVibration: true,
//   icon: '@mipmap/ic_launcher',
//   channelShowBadge: true,
//   groupKey: 'com.pos.orders',
//   visibility: NotificationVisibility.public,
//   category: AndroidNotificationCategory.message,
// );

// const _chStatus = AndroidNotificationDetails(
//   'ch_order_status',
//   'Order Status Updates',
//   channelDescription: 'Status changes for existing orders',
//   importance: Importance.high,
//   priority: Priority.high,
//   playSound: true,
//   icon: '@mipmap/ic_launcher',
//   channelShowBadge: true,
//   groupKey: 'com.pos.orders',
// );

// // FIX: `final` (not `const`) because Int64List.fromList is not a constant expression.
// final _chReady = AndroidNotificationDetails(
//   'ch_order_ready',
//   'Order Ready',
//   channelDescription: 'Fires when an order is ready to serve',
//   importance: Importance.max,
//   priority: Priority.max,
//   playSound: true,
//   enableVibration: true,
//   vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
//   icon: '@mipmap/ic_launcher',
//   channelShowBadge: true,
//   groupKey: 'com.pos.orders',
//   visibility: NotificationVisibility.public,
//   category: AndroidNotificationCategory.alarm,
// );

// const _chCancelled = AndroidNotificationDetails(
//   'ch_order_cancel',
//   'Cancelled Orders',
//   channelDescription: 'Fires when an order is cancelled',
//   importance: Importance.high,
//   priority: Priority.high,
//   playSound: true,
//   icon: '@mipmap/ic_launcher',
//   groupKey: 'com.pos.orders',
// );

// const _chCheckOut = AndroidNotificationDetails(
//   'ch_checkout',
//   'Check-out Warnings',
//   channelDescription: 'Alerts when a reservation is ending soon',
//   importance: Importance.max,
//   priority: Priority.max,
//   playSound: true,
//   enableVibration: true,
//   icon: '@mipmap/ic_launcher',
//   channelShowBadge: true,
// );

// const _chCheckIn = AndroidNotificationDetails(
//   'ch_checkin',
//   'Check-in Reminders',
//   channelDescription: 'Alerts when a guest is about to arrive',
//   importance: Importance.high,
//   priority: Priority.high,
//   playSound: true,
//   icon: '@mipmap/ic_launcher',
// );

// const _chLongSeated = AndroidNotificationDetails(
//   'ch_long_seated',
//   'Long-seated Alerts',
//   channelDescription: 'Alerts when guests have been seated too long',
//   importance: Importance.defaultImportance,
//   priority: Priority.defaultPriority,
//   playSound: false,
//   icon: '@mipmap/ic_launcher',
// );

// const _iosCritical = DarwinNotificationDetails(
//   presentAlert: true,
//   presentBadge: true,
//   presentSound: true,
//   interruptionLevel: InterruptionLevel.timeSensitive,
// );
// const _iosHigh = DarwinNotificationDetails(
//   presentAlert: true,
//   presentBadge: true,
//   presentSound: true,
// );
// const _iosNormal = DarwinNotificationDetails(
//   presentAlert: true,
//   presentSound: false,
// );

// // ─────────────────────────────────────────────────────────────────────────────
// //  TOP-LEVEL WORKMANAGER CALLBACK
// // ─────────────────────────────────────────────────────────────────────────────

// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((taskName, inputData) async {
//     log('[BG] ▶ Task: $taskName');
//     try {
//       WidgetsFlutterBinding.ensureInitialized();
//       if (taskName == kBgTask) await _runAllChecks();
//       log('[BG] ✅ Done: $taskName');
//       return true;
//     } catch (e, st) {
//       log('[BG] ❌ Error: $e\n$st');
//       return false;
//     }
//   });
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  MAIN BACKGROUND CHECK
// // ─────────────────────────────────────────────────────────────────────────────

// Future<void> _runAllChecks() async {
//   // ── 1. Bootstrap ──────────────────────────────────────────────────────────
//   final plugin = FlutterLocalNotificationsPlugin();
//   tzData.initializeTimeZones();
//   try {
//     tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
//   } catch (_) {
//     tz.setLocalLocation(tz.UTC);
//   }

//   // FIX: use named parameter `settings:` and drop `const` from
//   // InitializationSettings (DarwinInitializationSettings is not const).
//   await plugin.initialize(
//     settings: InitializationSettings(
//       android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
//       iOS: const DarwinInitializationSettings(),
//     ),
//   );

//   // ── 2. Load context ───────────────────────────────────────────────────────
//   final prefs = await SharedPreferences.getInstance();
//   final businessId = prefs.getString('businessId') ?? '';
//   final businessName = prefs.getString('businessName') ?? '';
//   log('[BG] businessId=$businessId');

//   if (businessId.isEmpty) {
//     log('[BG] No businessId — skipping');
//     return;
//   }

//   // ── 3. Dedup store ────────────────────────────────────────────────────────
//   final today = _todayKey();
//   final rawKeys = prefs.getStringList(_kSentKeys) ?? [];
//   final sentKeys = rawKeys.where((k) => k.startsWith(today)).toSet();

//   // ── 4. Supabase init ──────────────────────────────────────────────────────
//   await _ensureSupabase();
//   final sb = Supabase.instance.client;
//   final now = DateTime.now();
//   final biz = businessName.isNotEmpty ? '\n$businessName' : '';

//   // ══════════════════════════════════════════════════════════════════════════
//   //  ① ORDER NOTIFICATIONS
//   // ══════════════════════════════════════════════════════════════════════════

//   final notifRows = await sb
//       .from('order_notifications')
//       .select(
//         'id, order_id, type, title, body, is_read, created_at, '
//         'orders(order_number, order_type, table_number, customer_name, '
//         'total_amount, status)',
//       )
//       .eq('business_id', businessId)
//       .eq('is_read', false)
//       .order('created_at', ascending: true)
//       .limit(30);

//   final List<String> processedNotifIds = [];

//   for (final row in (notifRows as List)) {
//     final notifId = row['id'] as String? ?? '';
//     if (notifId.isEmpty) continue;
//     final key = '${today}_bgnotif_$notifId';
//     if (sentKeys.contains(key)) continue;
//     sentKeys.add(key);

//     final type = row['type'] as String? ?? 'new_order';
//     final title = row['title'] as String? ?? '';
//     final body = row['body'] as String? ?? businessName;
//     final orderData = row['orders'] as Map<String, dynamic>?;
//     final orderNum = (orderData?['order_number'] as int?) ?? 0;
//     final tableNum = orderData?['table_number'] as int?;
//     final orderType = orderData?['order_type'] as String? ?? 'dine_in';
//     final customer = orderData?['customer_name'] as String?;
//     final amount = (orderData?['total_amount'] as num?)?.toDouble();
//     final orderId = row['order_id'] as String? ?? '';

//     final tableInfo = tableNum != null ? ' • Table $tableNum' : '';
//     final custInfo = customer != null && customer.isNotEmpty
//         ? ' • $customer'
//         : '';
//     final amtInfo = amount != null ? ' • ₹${amount.toStringAsFixed(0)}' : '';

//     final typeEmoji = switch (orderType) {
//       'takeaway' => '🥡',
//       'delivery' => '🛵',
//       _ => '🍽️',
//     };

//     switch (type) {
//       case 'new_order':
//         await plugin.show(
//           id: 10000 + orderNum,
//           title: '$typeEmoji New Order #$orderNum$tableInfo',
//           body: '$businessName$custInfo$amtInfo',
//           notificationDetails: NotificationDetails(
//             android: _chNewOrder,
//             iOS: _iosCritical,
//           ),
//           payload: 'order:$orderId',
//         );
//         log('[BG] 🆕 New order #$orderNum');

//       case 'ready':
//         await plugin.show(
//           id: 12000 + orderNum,
//           title: '✅ READY — Order #$orderNum$tableInfo',
//           body: '$businessName$custInfo • Ready to serve!',
//           notificationDetails: NotificationDetails(
//             android: _chReady,
//             iOS: _iosCritical,
//           ),
//           payload: 'order:$orderId',
//         );
//         log('[BG] ✅ Order #$orderNum ready');

//       case 'cancelled':
//         await plugin.show(
//           id: 13000 + orderNum,
//           title: '❌ Cancelled — Order #$orderNum$tableInfo',
//           body: '$businessName$custInfo',
//           notificationDetails: NotificationDetails(
//             android: _chCancelled,
//             iOS: _iosNormal,
//           ),
//           payload: 'order:$orderId',
//         );
//         log('[BG] ❌ Order #$orderNum cancelled');

//       case 'status_change':
//       default:
//         await plugin.show(
//           id: 11000 + orderNum,
//           title: title.isNotEmpty ? title : '🔄 Order #$orderNum',
//           body: body,
//           notificationDetails: NotificationDetails(
//             android: _chStatus,
//             iOS: _iosNormal,
//           ),
//           payload: 'order:$orderId',
//         );
//         log('[BG] 🔄 Order #$orderNum status change');
//     }

//     processedNotifIds.add(notifId);
//   }

//   if (processedNotifIds.isNotEmpty) {
//     await sb
//         .from('order_notifications')
//         .update({'is_read': true})
//         .inFilter('id', processedNotifIds)
//         .catchError((_) {});
//   }

//   // ══════════════════════════════════════════════════════════════════════════
//   //  ② LONG-SEATED ALERTS
//   // ══════════════════════════════════════════════════════════════════════════

//   final cutoff4h = now
//       .subtract(const Duration(hours: 4))
//       .toUtc()
//       .toIso8601String();

//   final occupiedRows = await sb
//       .from('restaurant_tables')
//       .select('id, table_number, occupied_since, current_customer_name')
//       .eq('business_id', businessId)
//       .eq('status', 'occupied')
//       .eq('is_active', true)
//       .lt('occupied_since', cutoff4h);

//   for (final row in (occupiedRows as List)) {
//     final tableNum = row['table_number'] as int;
//     final tableId = row['id'] as String;
//     final guestName = (row['current_customer_name'] as String?) ?? 'Guest';
//     final occupiedSince = DateTime.parse(
//       row['occupied_since'] as String,
//     ).toLocal();
//     final seatedMins = now.difference(occupiedSince).inMinutes;

//     const longMin = 240;
//     if (seatedMins >= longMin) {
//       final bucket = ((seatedMins - longMin) ~/ 30) * 30;
//       final totalMins = longMin + bucket;
//       final h = totalMins ~/ 60;
//       final m = totalMins % 60;
//       final label = m > 0 ? '${h}h ${m}m' : '${h}h';
//       final key = '${today}_ls_${tableId}_$totalMins';

//       if (!sentKeys.contains(key)) {
//         sentKeys.add(key);
//         await plugin.show(
//           id: 4000 + tableNum,
//           title: '⏱️ Long stay — Table $tableNum ($label)',
//           body: '$guestName seated for $label$biz',
//           notificationDetails: const NotificationDetails(
//             android: _chLongSeated,
//             iOS: _iosNormal,
//           ),
//         );
//         log('[BG] ⏱️ Long-seated → T$tableNum ($label)');
//       }
//     }
//   }

//   // ══════════════════════════════════════════════════════════════════════════
//   //  ③ CHECK-IN REMINDERS
//   // ══════════════════════════════════════════════════════════════════════════

//   final in35 = now.add(const Duration(minutes: 35)).toUtc().toIso8601String();
//   final nowUtc = now.toUtc().toIso8601String();

//   final checkInRows = await sb
//       .from('table_reservations')
//       .select(
//         'id, customer_name, guest_count, reserved_for, restaurant_tables(table_number)',
//       )
//       .eq('business_id', businessId)
//       .inFilter('status', ['active'])
//       .gte('reserved_for', nowUtc)
//       .lte('reserved_for', in35);

//   for (final row in (checkInRows as List)) {
//     final tableData = row['restaurant_tables'];
//     final tableNum = (tableData?['table_number'] ?? 0) as int;
//     final tName = 'T${tableNum.toString().padLeft(2, '0')}';
//     final guestName = (row['customer_name'] as String?) ?? 'Guest';
//     final guestCount = (row['guest_count'] ?? 0) as int;
//     final resTime = DateTime.parse(row['reserved_for'] as String).toLocal();
//     final minsToArr = resTime.difference(now).inMinutes;
//     final timeLabel = _fmtTime(resTime);
//     final body = '$guestName · $guestCount guests · $timeLabel$biz';

//     if (minsToArr > 25 && minsToArr <= 35) {
//       final k = '${today}_ci30_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 1000 + tableNum,
//           title: '🟡 Guest arriving in 30 min — $tName',
//           body: body,
//           fireAt: resTime.subtract(const Duration(minutes: 30)),
//           android: _chCheckIn,
//           ios: _iosNormal,
//         );
//       }
//     }
//     if (minsToArr > 10 && minsToArr <= 22) {
//       final k = '${today}_ci15_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 2000 + tableNum,
//           title: '🔔 Guest arriving in 15 min — $tName',
//           body: body,
//           fireAt: resTime.subtract(const Duration(minutes: 15)),
//           android: _chCheckIn,
//           ios: _iosNormal,
//         );
//       }
//     }
//     if (minsToArr > 0 && minsToArr <= 10) {
//       final k = '${today}_ci5_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 6000 + tableNum,
//           title: '🚨 Guest arriving in 5 min — $tName',
//           body: body,
//           fireAt: resTime.subtract(const Duration(minutes: 5)),
//           android: _chCheckIn,
//           ios: _iosNormal,
//         );
//       }
//     }
//   }

//   // ══════════════════════════════════════════════════════════════════════════
//   //  ④ CHECK-OUT WARNINGS
//   // ══════════════════════════════════════════════════════════════════════════

//   final in35co = now.add(const Duration(minutes: 35)).toUtc().toIso8601String();

//   final checkOutRows = await sb
//       .from('table_reservations')
//       .select('id, customer_name, check_out, restaurant_tables(table_number)')
//       .eq('business_id', businessId)
//       .inFilter('status', ['active', 'seated'])
//       .not('check_out', 'is', null)
//       .gte('check_out', nowUtc)
//       .lte('check_out', in35co);

//   for (final row in (checkOutRows as List)) {
//     final tableData = row['restaurant_tables'];
//     final tableNum = (tableData?['table_number'] ?? 0) as int;
//     final tName = 'T${tableNum.toString().padLeft(2, '0')}';
//     final guestName = (row['customer_name'] as String?) ?? 'Guest';
//     final checkOutDt = DateTime.parse(row['check_out'] as String).toLocal();
//     final minsLeft = checkOutDt.difference(now).inMinutes;
//     final coLabel = _fmtTime(checkOutDt);
//     final body = '$guestName · Check-out at $coLabel$biz';

//     if (minsLeft > 28) {
//       final k = '${today}_co30_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 7000 + tableNum,
//           title: '🟡 Reservation ending in 30 min — $tName',
//           body: body,
//           fireAt: checkOutDt.subtract(const Duration(minutes: 30)),
//           android: _chCheckOut,
//           ios: _iosHigh,
//         );
//       }
//     }
//     if (minsLeft > 13 && minsLeft <= 18) {
//       final k = '${today}_co15_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 3000 + tableNum,
//           title: '🔴 Reservation ending in 15 min — $tName',
//           body: body,
//           fireAt: checkOutDt.subtract(const Duration(minutes: 15)),
//           android: _chCheckOut,
//           ios: _iosHigh,
//         );
//       }
//     }
//     if (minsLeft > 5 && minsLeft <= 10) {
//       final k = '${today}_co5_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await _bgSchedule(
//           plugin,
//           id: 7500 + tableNum,
//           title: '🚨 Reservation ending in 5 min — $tName',
//           body: body,
//           fireAt: checkOutDt.subtract(const Duration(minutes: 5)),
//           android: _chCheckOut,
//           ios: _iosHigh,
//         );
//       }
//     } else if (minsLeft >= 0 && minsLeft <= 5) {
//       final k = '${today}_co5now_${row['id']}';
//       if (!sentKeys.contains(k)) {
//         sentKeys.add(k);
//         await plugin.show(
//           id: 7500 + tableNum,
//           title: '🚨 Reservation ending in 5 min — $tName',
//           body: body,
//           notificationDetails: const NotificationDetails(
//             android: _chCheckOut,
//             iOS: _iosHigh,
//           ),
//         );
//         log('[BG] 🚨 5-min checkout immediate → $tName');
//       }
//     }
//   }

//   // ── Checkouts happening RIGHT NOW ─────────────────────────────────────────
//   final justPassed = now
//       .subtract(const Duration(minutes: 1))
//       .toUtc()
//       .toIso8601String();

//   final nowRows = await sb
//       .from('table_reservations')
//       .select('id, customer_name, restaurant_tables(table_number)')
//       .eq('business_id', businessId)
//       .inFilter('status', ['active', 'seated'])
//       .not('check_out', 'is', null)
//       .gte('check_out', justPassed)
//       .lte('check_out', nowUtc);

//   for (final row in (nowRows as List)) {
//     final tableData = row['restaurant_tables'];
//     final tableNum = (tableData?['table_number'] ?? 0) as int;
//     final tName = 'T${tableNum.toString().padLeft(2, '0')}';
//     final guestName = (row['customer_name'] as String?) ?? 'Guest';
//     final key = '${today}_coNow_${row['id']}';

//     if (!sentKeys.contains(key)) {
//       sentKeys.add(key);
//       await plugin.show(
//         id: 3000 + tableNum,
//         title: '🔴 Checkout time reached — $tName',
//         body: '$guestName · It\'s time to check out$biz',
//         notificationDetails: const NotificationDetails(
//           android: _chCheckOut,
//           iOS: _iosHigh,
//         ),
//       );
//       log('[BG] 🔴 Checkout NOW → $tName');
//     }
//   }

//   // ── Persist dedup keys ────────────────────────────────────────────────────
//   final cleaned = sentKeys.where((k) => k.startsWith(today)).toList();
//   await prefs.setStringList(_kSentKeys, cleaned);
//   log('[BG] 💾 Saved ${cleaned.length} sent-keys');
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  HELPERS
// // ─────────────────────────────────────────────────────────────────────────────

// Future<void> _bgSchedule(
//   FlutterLocalNotificationsPlugin plugin, {
//   required int id,
//   required String title,
//   required String body,
//   required DateTime fireAt,
//   required AndroidNotificationDetails android,
//   required DarwinNotificationDetails ios,
// }) async {
//   if (fireAt.isBefore(DateTime.now())) {
//     log('[BG] ⏭ Past — skipped: "$title"');
//     return;
//   }
//   try {
//     await plugin.zonedSchedule(
//       id: id,
//       title: title,
//       body: body,
//       scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
//       notificationDetails: NotificationDetails(android: android, iOS: ios),
//       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//     );
//     log('[BG] ⏰ Scheduled id=$id "$title" → $fireAt');
//   } catch (e) {
//     log('[BG] ⚠️ Schedule error id=$id: $e');
//   }
// }

// Future<void> _ensureSupabase() async {
//   try {
//     Supabase.instance.client;
//   } catch (_) {
//     await Supabase.initialize(
//       url: AppConfig.supabaseUrl,
//       anonKey: AppConfig.supabaseAnonKey,
//     );
//     log('[BG] Supabase initialized');
//   }
// }

// String _todayKey() {
//   final n = DateTime.now();
//   return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
//       '${n.day.toString().padLeft(2, '0')}';
// }

// String _fmtTime(DateTime dt) {
//   final h = dt.hour;
//   final m = dt.minute.toString().padLeft(2, '0');
//   final s = h >= 12 ? 'PM' : 'AM';
//   final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
//   return '$h12:$m $s';
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  BackgroundTaskService  — public API
// // ─────────────────────────────────────────────────────────────────────────────

// class BackgroundTaskService {
//   BackgroundTaskService._();

//   static Future<void> initialize() async {
//     await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
//     await _register();
//   }

//   static Future<void> _register() async {
//     await Workmanager().cancelByTag(kBgTag);
//     await Workmanager().registerPeriodicTask(
//       kBgTask,
//       kBgTask,
//       tag: kBgTag,
//       frequency: const Duration(minutes: 15),
//       existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
//       constraints: Constraints(
//         networkType: NetworkType.connected,
//         requiresBatteryNotLow: false,
//       ),
//       backoffPolicy: BackoffPolicy.linear,
//       backoffPolicyDelay: const Duration(seconds: 30),
//     );
//     log(
//       '[BG] ✅ Registered (15 min) — orders + long-seated + check-in + check-out',
//     );
//   }

//   static Future<void> cancelAll() async {
//     await Workmanager().cancelByTag(kBgTag);
//     log('[BG] Background tasks cancelled');
//   }

//   static Future<void> restart() => _register();
// }

//correct notification fworking for table
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:workmanager/workmanager.dart';
import 'package:pos_app/config/app_config.dart';

const kLongSeatedTask = 'long_seated_check';
const kLongSeatedTag = 'reservation_checks';
const _kSentKeys = '_notif_sent_keys';

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION CHANNELS (must match reservation_notification_service.dart)
// ─────────────────────────────────────────────────────────────────────────────
const _chCheckOut = AndroidNotificationDetails(
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

const _chCheckIn = AndroidNotificationDetails(
  'ch_checkin',
  'Check-in Reminders',
  channelDescription: 'Alerts when a guest is about to arrive',
  importance: Importance.high,
  priority: Priority.high,
  playSound: true,
  icon: '@mipmap/ic_launcher',
);

const _chLongSeated = AndroidNotificationDetails(
  'ch_long_seated',
  'Long-seated Alerts',
  channelDescription: 'Alerts when guests have been seated too long',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  playSound: false,
  icon: '@mipmap/ic_launcher',
);

const _iosHigh = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  interruptionLevel: InterruptionLevel.timeSensitive,
);
const _iosNormal = DarwinNotificationDetails(
  presentAlert: true,
  presentSound: false,
);

// ─────────────────────────────────────────────────────────────────────────────
//  TOP-LEVEL WORKMANAGER CALLBACK
//  Must be top-level + @pragma to survive tree-shaking in release builds.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    log('[BG] ▶ Task: $taskName');
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (taskName == kLongSeatedTask) {
        await _runBackgroundChecks();
      }
      log('[BG] ✅ Done: $taskName');
      return true;
    } catch (e, st) {
      log('[BG] ❌ Error: $e\n$st');
      return false;
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN BACKGROUND CHECK FUNCTION
//  Runs every ~15 minutes by WorkManager.
//  Handles ALL notification types so nothing is missed in killed state.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runBackgroundChecks() async {
  // ── 1. Bootstrap notifications + timezone ────────────────────────────────
  final plugin = FlutterLocalNotificationsPlugin();
  tzData.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  // ── 2. Load context from SharedPreferences ────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final businessId = prefs.getString('businessId') ?? '';
  final businessName = prefs.getString('businessName') ?? '';
  log('[BG] businessId=$businessId');

  if (businessId.isEmpty) {
    log('[BG] No businessId — user not logged in, skipping');
    return;
  }

  // ── 3. Load sent-key dedup store ──────────────────────────────────────────
  final today = _todayKey();
  final rawKeys = prefs.getStringList(_kSentKeys) ?? [];
  final sentKeys = rawKeys.where((k) => k.startsWith(today)).toSet();

  // ── 4. Bootstrap Supabase ─────────────────────────────────────────────────
  await _ensureSupabase();
  final sb = Supabase.instance.client;
  final now = DateTime.now();
  final biz = businessName.isNotEmpty ? '\n$businessName' : '';

  // ── 5. Long-seated check (occupied 4+ hours) ──────────────────────────────
  final cutoff4h = now
      .subtract(const Duration(hours: 4))
      .toUtc()
      .toIso8601String();

  final occupiedRows = await sb
      .from('restaurant_tables')
      .select('id, table_number, occupied_since, current_customer_name')
      .eq('business_id', businessId)
      .eq('status', 'occupied')
      .eq('is_active', true)
      .lt('occupied_since', cutoff4h);

  for (final row in (occupiedRows as List)) {
    final tableNum = row['table_number'] as int;
    final tableId = row['id'] as String;
    final guestName = (row['current_customer_name'] as String?) ?? 'Guest';
    final occupiedSince = DateTime.parse(
      row['occupied_since'] as String,
    ).toLocal();
    final seatedMins = now.difference(occupiedSince).inMinutes;

    const longMin = 240;
    if (seatedMins >= longMin) {
      final bucket = ((seatedMins - longMin) ~/ 30) * 30;
      final totalMins = longMin + bucket;
      final h = totalMins ~/ 60, m = totalMins % 60;
      final label = m > 0 ? '${h}h ${m}m' : '${h}h';
      final key = '${today}_ls_${tableId}_$totalMins';

      if (!sentKeys.contains(key)) {
        sentKeys.add(key);
        await plugin.show(
          id: 4000 + tableNum,
          title: '⏱️ Long stay — Table $tableNum ($label)',
          body: '$guestName seated for $label$biz',
          notificationDetails: const NotificationDetails(
            android: _chLongSeated,
            iOS: _iosNormal,
          ),
        );
        log('[BG] 🔔 Long-seated → T$tableNum ($label)');
      }
    }
  }

  // ── 6. Upcoming check-in reminders ────────────────────────────────────────
  // Re-schedule check-in alarms for reservations arriving in the next 35 min.
  // This is the WorkManager safety net in case the OS cleared the alarm.
  final in35 = now.add(const Duration(minutes: 35)).toUtc().toIso8601String();
  final nowUtc = now.toUtc().toIso8601String();

  final checkInRows = await sb
      .from('table_reservations')
      .select(
        'id, customer_name, guest_count, reserved_for, '
        'restaurant_tables(table_number)',
      )
      .eq('business_id', businessId)
      .inFilter('status', ['active'])
      .gte('reserved_for', nowUtc)
      .lte('reserved_for', in35);

  for (final row in (checkInRows as List)) {
    final tableData = row['restaurant_tables'];
    final tableNum = (tableData?['table_number'] ?? 0) as int;
    final tName = 'T${tableNum.toString().padLeft(2, '0')}';
    final guestName = (row['customer_name'] as String?) ?? 'Guest';
    final guestCount = (row['guest_count'] ?? 0) as int;
    // ✅ FIX: Use UTC+5:30 (IST) instead of device timezone (.toLocal())
    // The background isolate may run on any device timezone, but the business
    // is in IST, so we must pin the offset for correct time display in notifications.
    final resTime = DateTime.parse(row['reserved_for'] as String)
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30));
    final resTime_ = DateTime(
      resTime.year, resTime.month, resTime.day, resTime.hour, resTime.minute,
      resTime.second,
    );
    final minsToArr = resTime_.difference(now).inMinutes;
    final timeLabel = _fmtTime(resTime_);
    final body = '$guestName · $guestCount guests · $timeLabel$biz';

    if (minsToArr > 25 && minsToArr <= 35) {
      final k = '${today}_ci30_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 1000 + tableNum,
          title: '🟡 Guest arriving in 30 min — $tName',
          body: body,
          fireAt: resTime_.subtract(const Duration(minutes: 30)),
          android: _chCheckIn,
          ios: _iosNormal,
        );
      }
    }
    if (minsToArr > 10 && minsToArr <= 22) {
      final k = '${today}_ci15_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 2000 + tableNum,
          title: '🔔 Guest arriving in 15 min — $tName',
          body: body,
          fireAt: resTime_.subtract(const Duration(minutes: 15)),
          android: _chCheckIn,
          ios: _iosNormal,
        );
      }
    }
    if (minsToArr <= 10 && minsToArr > 0) {
      final k = '${today}_ci5_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 6000 + tableNum,
          title: '🚨 Guest arriving in 5 min — $tName',
          body: body,
          fireAt: resTime_.subtract(const Duration(minutes: 5)),
          android: _chCheckIn,
          ios: _iosNormal,
        );
      }
    }
  }

  // ── 7. Checkout reminders (THE KEY FIX for killed-state) ─────────────────
  // Query reservations with check_out in the next 35 minutes.
  // We re-schedule (or fire immediately) all checkout alarms here.
  // This runs every 15 min so even if OEM cleared the alarm, it gets reset.
  final in35co = now.add(const Duration(minutes: 35)).toUtc().toIso8601String();

  final checkOutRows = await sb
      .from('table_reservations')
      .select(
        'id, customer_name, check_out, '
        'restaurant_tables(table_number)',
      )
      .eq('business_id', businessId)
      .inFilter('status', ['active', 'seated'])
      .not('check_out', 'is', null)
      .gte('check_out', nowUtc)
      .lte('check_out', in35co);

  for (final row in (checkOutRows as List)) {
    final tableData = row['restaurant_tables'];
    final tableNum = (tableData?['table_number'] ?? 0) as int;
    final tName = 'T${tableNum.toString().padLeft(2, '0')}';
    final guestName = (row['customer_name'] as String?) ?? 'Guest';
    // ✅ FIX: Use UTC+5:30 (IST) fixed offset for correct display
    final rawCo = DateTime.parse(row['check_out'] as String)
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30));
    final checkOutDt = DateTime(
      rawCo.year, rawCo.month, rawCo.day, rawCo.hour, rawCo.minute, rawCo.second,
    );
    final minsLeft = checkOutDt.difference(now).inMinutes;
    final coLabel = _fmtTime(checkOutDt);
    final body = '$guestName · Check-out at $coLabel$biz';

    log('[BG] 🕐 Checkout in ${minsLeft}min — $tName');

    // 30-min alarm
    if (minsLeft > 28) {
      final k = '${today}_co30_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 7000 + tableNum,
          title: '🟡 Reservation ending in 30 min — $tName',
          body: body,
          fireAt: checkOutDt.subtract(const Duration(minutes: 30)),
          android: _chCheckOut,
          ios: _iosHigh,
        );
      }
    }

    // 15-min alarm
    if (minsLeft > 13 && minsLeft <= 18) {
      final k = '${today}_co15_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 3000 + tableNum,
          title: '🔴 Reservation ending in 15 min — $tName',
          body: body,
          fireAt: checkOutDt.subtract(const Duration(minutes: 15)),
          android: _chCheckOut,
          ios: _iosHigh,
        );
      }
    }

    // 5-min: schedule if 6-10 min left, fire immediately if ≤5 min
    if (minsLeft > 5 && minsLeft <= 10) {
      final k = '${today}_co5_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await _bgSchedule(
          plugin,
          id: 7500 + tableNum,
          title: '🚨 Reservation ending in 5 min — $tName',
          body: body,
          fireAt: checkOutDt.subtract(const Duration(minutes: 5)),
          android: _chCheckOut,
          ios: _iosHigh,
        );
      }
    } else if (minsLeft >= 0 && minsLeft <= 5) {
      final k = '${today}_co5_${row['id']}';
      if (!sentKeys.contains(k)) {
        sentKeys.add(k);
        await plugin.show(
          id: 7500 + tableNum,
          title: '🚨 Reservation ending in 5 min — $tName',
          body: body,
          notificationDetails: const NotificationDetails(
            android: _chCheckOut,
            iOS: _iosHigh,
          ),
        );
        log('[BG] 🚨 5-min checkout immediate → $tName');
      }
    }
  }

  // ── 8. Also check for checkouts happening RIGHT NOW (within last 1 min) ──
  final justPassed = now
      .subtract(const Duration(minutes: 1))
      .toUtc()
      .toIso8601String();

  final nowRows = await sb
      .from('table_reservations')
      .select(
        'id, customer_name, check_out, '
        'restaurant_tables(table_number)',
      )
      .eq('business_id', businessId)
      .inFilter('status', ['active', 'seated'])
      .not('check_out', 'is', null)
      .gte('check_out', justPassed)
      .lte('check_out', nowUtc);

  for (final row in (nowRows as List)) {
    final tableData = row['restaurant_tables'];
    final tableNum = (tableData?['table_number'] ?? 0) as int;
    final tName = 'T${tableNum.toString().padLeft(2, '0')}';
    final guestName = (row['customer_name'] as String?) ?? 'Guest';
    final key = '${today}_coNow_${row['id']}';

    if (!sentKeys.contains(key)) {
      sentKeys.add(key);
      await plugin.show(
        id: 3000 + tableNum,
        title: '🔴 Checkout time reached — $tName',
        body: '$guestName · It\'s time to check out$biz',
        notificationDetails: const NotificationDetails(
          android: _chCheckOut,
          iOS: _iosHigh,
        ),
      );
      log('[BG] 🔴 Checkout NOW → $tName');
    }
  }

  // ── 9. Persist sent-keys (keeps only today's) ─────────────────────────────
  final cleaned = sentKeys.where((k) => k.startsWith(today)).toList();
  await prefs.setStringList(_kSentKeys, cleaned);
  log('[BG] 💾 Saved ${cleaned.length} sent-keys');
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPER: Schedule a future notification from background isolate
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _bgSchedule(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required String body,
  required DateTime fireAt,
  required AndroidNotificationDetails android,
  required DarwinNotificationDetails ios,
}) async {
  if (fireAt.isBefore(DateTime.now())) {
    log('[BG] ⏭ Past — skipped: "$title"');
    return;
  }
  try {
    await plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    log('[BG] ⏰ Scheduled id=$id "$title" → $fireAt');
  } catch (e) {
    log('[BG] ⚠️ Schedule error id=$id: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUPABASE LAZY INIT
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _ensureSupabase() async {
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    log('[BG] Supabase initialized');
  }
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

String _fmtTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final suf = h >= 12 ? 'PM' : 'AM';
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$h12:$m $suf';
}

// ─────────────────────────────────────────────────────────────────────────────
//  BackgroundTaskService
//  Call initialize() from main() BEFORE runApp().
// ─────────────────────────────────────────────────────────────────────────────
class BackgroundTaskService {
  BackgroundTaskService._();

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await _register();
  }

  static Future<void> _register() async {
    await Workmanager().cancelByTag(kLongSeatedTag);

    await Workmanager().registerPeriodicTask(
      kLongSeatedTask,
      kLongSeatedTask,
      tag: kLongSeatedTag,
      // 15 min is the Android minimum for periodic tasks.
      // Covers: long-seated + check-in + check-out in all states.
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );

    log(
      '[BG] ✅ Registered (15 min) — handles long-seated + check-in + check-out',
    );
  }

  /// Call on logout to stop background checks
  static Future<void> cancelAll() async {
    await Workmanager().cancelByTag(kLongSeatedTag);
    log('[BG] Background tasks cancelled');
  }

  /// Call after login to restart checks
  static Future<void> restart() => _register();
}
