import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:workmanager/workmanager.dart';
import 'package:pos_app/config/app_config.dart'; // ← your AppConfig file path

const kLongSeatedTask = 'long_seated_check';
const kLongSeatedTag = 'reservation_checks';

// ─────────────────────────────────────────────────────────────────────────────
//  TOP-LEVEL CALLBACK
//  Must be top-level (not inside a class).
//  @pragma prevents tree-shaking in release builds.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print('[BG] Task started: $taskName');
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (taskName == kLongSeatedTask) {
        await _runLongSeatedCheck();
      }
      print('[BG] Task done: $taskName');
      return true;
    } catch (e) {
      print('[BG] Task error: $e');
      return false;
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  BACKGROUND LONG-SEATED CHECK
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runLongSeatedCheck() async {
  // 1. Init notifications
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

  // 2. Get businessId saved at login from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final businessId = prefs.getString('businessId') ?? '';
  final businessName = prefs.getString('businessName') ?? '';
  log('[BG] Loaded businessId: $businessId, businessName: $businessName');
  if (businessId.isEmpty) {
    print('[BG] No businessId in prefs — user not logged in, skipping');
    return;
  }

  // 3. Init Supabase using AppConfig (no hardcoded strings needed)
  await _ensureSupabase();

  // 4. Query tables occupied more than 4 hours
  final now = DateTime.now();
  final cutoff = now
      .subtract(const Duration(hours: 4))
      .toUtc()
      .toIso8601String();

  final rows = await Supabase.instance.client
      .from('restaurant_tables')
      .select('id, table_number, occupied_since, current_customer_name')
      .eq('business_id', businessId)
      .eq('status', 'occupied')
      .eq('is_active', true)
      .lt('occupied_since', cutoff);

  // 5. Fire notification for each long-seated table
  final today = _todayKey();
  final sentKeys = List<String>.from(
    prefs.getStringList('_bg_notif_keys') ?? [],
  );

  for (final row in (rows as List)) {
    final tableNum = row['table_number'] as int;
    final tableId = row['id'] as String;
    final guestName = (row['current_customer_name'] as String?) ?? 'Guest';
    final occupiedSince = DateTime.parse(
      row['occupied_since'] as String,
    ).toLocal();

    final seatedMins = now.difference(occupiedSince).inMinutes;
    const longSeatedMinutes = 240; // 4 hours

    if (seatedMins >= longSeatedMinutes) {
      final bucket = ((seatedMins - longSeatedMinutes) ~/ 30) * 30;
      final totalMins = longSeatedMinutes + bucket;
      final h = totalMins ~/ 60;
      final m = totalMins % 60;
      final label = m > 0 ? '${h}h ${m}m' : '${h}h';
      final key = '${today}_ls_${tableId}_$totalMins';
      final biz = businessName.isNotEmpty ? '\n$businessName' : '';

      if (!sentKeys.contains(key)) {
        await plugin.show(
          id: 4000 + tableNum,
          title: '⏱️ Long stay — Table $tableNum ($label)',
          body: '$guestName seated for $label$biz',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'ch_long_seated',
              'Long-seated Alerts',
              channelDescription:
                  'Alerts when guests have been seated too long',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: false,
            ),
          ),
        );

        sentKeys.add(key);
        print('[BG] 🔔 Long-seated alert → Table $tableNum ($label)');
      }
    }
  }

  // Keep only today's keys (prevents list growing unbounded)
  final cleaned = sentKeys.where((k) => k.startsWith(today)).toList();
  await prefs.setStringList('_bg_notif_keys', cleaned);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Supabase init using AppConfig — safe to call multiple times
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _ensureSupabase() async {
  try {
    // If already initialized this is a no-op
    Supabase.instance.client;
  } catch (_) {
    // Background isolate starts fresh — initialize using AppConfig
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    print('[BG] Supabase initialized');
  }
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  BackgroundTaskService
//  Call BackgroundTaskService.initialize() from main() before runApp()
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
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );

    print('[BG] ✅ Periodic long-seated task registered (every 15 min)');
  }

  /// Call on logout
  static Future<void> cancelAll() async {
    await Workmanager().cancelByTag(kLongSeatedTag);
    print('[BG] Background tasks cancelled');
  }

  /// Call after login
  static Future<void> restart() => _register();
}
