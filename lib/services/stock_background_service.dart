// lib/services/background_stock_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  BACKGROUND STOCK CHECK SERVICE
//  Runs via WorkManager every 15 min — fires push for critical/OOS items
//  even when app is killed. Only triggers for admin/manager roles.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pos_app/config/app_config.dart';

const kStockCheckTask = 'stock_level_check';
const kStockCheckTag  = 'stock_checks';
const _kStockSentKeys = '_stock_notif_sent_keys';

// ── Notification channels ──────────────────────────────────────────────────
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
  icon: '@mipmap/ic_launcher',
  channelShowBadge: true,
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

// ── Top-level WorkManager callback ────────────────────────────────────────────
@pragma('vm:entry-point')
void stockCheckCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    log('[StockBG] ▶ Task: $taskName');
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (taskName == kStockCheckTask) await _runStockChecks();
      log('[StockBG] ✅ Done');
      return true;
    } catch (e, st) {
      log('[StockBG] ❌ Error: $e\n$st');
      return false;
    }
  });
}

// ── Main background check ──────────────────────────────────────────────────────
Future<void> _runStockChecks() async {
  // Bootstrap
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: const DarwinInitializationSettings(),
    ),
  );

  // Load context
  final prefs      = await SharedPreferences.getInstance();
  final businessId = prefs.getString('businessId') ?? '';
  final role       = prefs.getString('role') ?? '';
  log('[StockBG] businessId=$businessId role=$role');

  // Role gate — only admin/manager
  if (!['admin', 'manager'].contains(role.toLowerCase())) {
    log('[StockBG] Role "$role" not eligible — skipping');
    return;
  }
  if (businessId.isEmpty) {
    log('[StockBG] No businessId — skipping');
    return;
  }

  // Dedup
  final today    = _todayKey();
  final rawKeys  = prefs.getStringList(_kStockSentKeys) ?? [];
  final sentKeys = rawKeys.where((k) => k.startsWith(today)).toSet();

  // Supabase
  await _ensureSupabase();
  final sb = Supabase.instance.client;

  // Fetch stock_notifications inserted in last 30 mins that haven't been fired
  final since = DateTime.now().subtract(const Duration(minutes: 30))
      .toUtc().toIso8601String();

  final rows = await sb
      .from('stock_notifications')
      .select()
      .eq('business_id', businessId)
      .eq('is_read', false)
      .inFilter('notification_type', ['low_stock','critical','out_of_stock'])
      .gte('created_at', since)
      .order('created_at', ascending: false)
      .limit(20);

  final List<String> processedIds = [];

  for (final row in (rows as List)) {
    final notifId  = row['id'] as String? ?? '';
    final itemName = row['item_name'] as String? ?? 'Unknown';
    final type     = row['notification_type'] as String? ?? 'low_stock';
    final title    = row['title'] as String? ?? 'Stock Alert';
    final body     = row['body'] as String? ?? '';
    final severity = row['severity'] as String? ?? 'warning';

    final key = '${today}_stockbg_$notifId';
    if (sentKeys.contains(key)) continue;
    sentKeys.add(key);

    final notifLocalId = 30000 + (itemName.hashCode.abs() % 1000);

    final (android, ios) = severity == 'critical'
        ? (_chCritical, _iosCritical)
        : (_chWarning, _iosWarning);

    await plugin.show(
      id: notifLocalId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: 'stock_notif:$notifId',
    );
    log('[StockBG] 🔔 Sent: $title (type=$type)');
    processedIds.add(notifId);
  }

  // Also directly check inventory for critical items (belt-and-suspenders)
  final criticalItems = await sb
      .from('inventory_items')
      .select('id, name, current_stock, min_threshold, unit, stock_status')
      .eq('business_id', businessId)
      .eq('is_active', true)
      .inFilter('stock_status', ['critical','out_of_stock']);

  for (final item in (criticalItems as List)) {
    final itemId   = item['id'] as String;
    final name     = item['name'] as String? ?? 'Unknown';
    final status   = item['stock_status'] as String? ?? 'critical';
    final stock    = (item['current_stock'] as num? ?? 0).toDouble();
    final minStock = (item['min_threshold'] as num? ?? 0).toDouble();
    final unit     = item['unit'] as String? ?? 'kg';

    final key = '${today}_stockdirect_${itemId}_$status';
    if (sentKeys.contains(key)) continue;
    sentKeys.add(key);

    final (title, body, android, ios) = status == 'out_of_stock'
        ? (
            '❌ Out of Stock: $name',
            '$name is completely out of stock. Immediate reorder needed.',
            _chCritical, _iosCritical,
          )
        : (
            '🔴 Critical Stock: $name',
            '$name is critically low: ${stock.toStringAsFixed(1)} $unit (Min: ${minStock.toInt()} $unit)',
            _chCritical, _iosCritical,
          );

    await plugin.show(
      id: 31000 + (itemId.hashCode.abs() % 1000),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: 'stock:$itemId',
    );
    log('[StockBG] 🚨 Critical direct: $name ($status)');
  }

  // Persist dedup keys
  final cleaned = sentKeys.where((k) => k.startsWith(today)).toList();
  await prefs.setStringList(_kStockSentKeys, cleaned);
  log('[StockBG] 💾 Saved ${cleaned.length} sent-keys');
}

Future<void> _ensureSupabase() async {
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    log('[StockBG] Supabase initialized');
  }
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
}

// ── BackgroundStockService ─────────────────────────────────────────────────────
class BackgroundStockService {
  BackgroundStockService._();

  /// Call from main() before runApp(), AFTER the existing background task init.
  static Future<void> initialize() async {
    // Note: If you already call Workmanager().initialize() elsewhere,
    // you need a single callbackDispatcher that handles all tasks.
    // Merge stockCheckCallbackDispatcher logic into your existing dispatcher.
    await Workmanager().initialize(stockCheckCallbackDispatcher, isInDebugMode: false);
    await _register();
  }

  static Future<void> _register() async {
    await Workmanager().cancelByTag(kStockCheckTag);
    await Workmanager().registerPeriodicTask(
      kStockCheckTask,
      kStockCheckTask,
      tag: kStockCheckTag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
    log('[StockBG] ✅ Registered (15 min) stock level check');
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelByTag(kStockCheckTag);
    log('[StockBG] Cancelled stock background tasks');
  }

  static Future<void> restart() => _register();
}