// 🔥 KOT DELAY DETECTION SERVICE - SLA Monitoring
// lib/services/kot_delay_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/kot_models.dart';

typedef OnDelayUpdate = void Function(List<KOTDelayAlert> alerts);

class KOTDelayService {
  static final KOTDelayService _instance = KOTDelayService._internal();

  factory KOTDelayService() => _instance;

  KOTDelayService._internal();

  final supabase = Supabase.instance.client;

  // SLA configuration (in seconds)
  static const Map<SLATier, int> slaThresholds = <SLATier, int>{
    SLATier.standard: 900, // 15 minutes
    SLATier.express: 600, // 10 minutes
    SLATier.urgent: 300, // 5 minutes
  };

  static const Map<SLATier, int> warningThresholds = <SLATier, int>{
    SLATier.standard: 300, // 5 min before SLA
    SLATier.express: 180, // 3 min before SLA
    SLATier.urgent: 120, // 2 min before SLA
  };

  late Timer _delayCheckTimer;
  final List<OnDelayUpdate> _delayCallbacks = [];
  final Set<String> _acknowledgedAlerts = {};

  /// Initialize delay detection
  void initialize({Duration checkInterval = const Duration(seconds: 10)}) {
    _delayCheckTimer = Timer.periodic(checkInterval, (_) async {
      // Delay detection happens automatically
    });

    debugPrint('✅ Delay detection service initialized');
  }

  /// Get all active delay alerts for a business
  Future<List<KOTDelayAlert>> getActiveAlerts({
    required String businessId,
    String? kitchenId,
  }) async {
    try {
      var query = supabase
          .from('kot_delay_alerts')
          .select()
          .eq('business_id', businessId)
          .eq('is_resolved', false);

      if (kitchenId != null) {
        query = query.eq('kitchen_id', kitchenId);
      }

      final response = await query;

      return (response as List).map((a) => KOTDelayAlert.fromJson(a)).toList();
    } catch (e) {
      debugPrint('❌ Error getting active alerts: $e');
      return [];
    }
  }

  /// Get delay statistics for a period
  Future<DelayStatistics> getDelayStatistics({
    required String businessId,
    required DateTime startTime,
    required DateTime endTime,
    String? kitchenId,
  }) async {
    try {
      var query = supabase
          .from('kot_delay_alerts')
          .select()
          .eq('business_id', businessId)
          .gte('created_at', startTime.toIso8601String())
          .lte('created_at', endTime.toIso8601String());

      if (kitchenId != null) {
        query = query.eq('kitchen_id', kitchenId);
      }

      final alerts = await query;

      final statistics = DelayStatistics();

      for (final alert in alerts) {
        statistics.totalAlerts++;

        final alertType = (alert['alert_type'] as String?);
        if (alertType == 'warning') {
          statistics.warningAlerts++;
        } else if (alertType == 'critical') {
          statistics.criticalAlerts++;
        } else if (alertType == 'urgent') {
          statistics.urgentAlerts++;
        }

        statistics.totalDelaySeconds +=
            (alert['exceeded_by_seconds'] as int? ?? 0);
      }

      if (statistics.totalAlerts > 0) {
        statistics.avgDelaySeconds =
            statistics.totalDelaySeconds ~/ statistics.totalAlerts;
      }

      return statistics;
    } catch (e) {
      debugPrint('❌ Error getting delay statistics: $e');
      return DelayStatistics();
    }
  }

  /// Acknowledge a delay alert
  Future<KOTDelayAlert?> acknowledgeAlert({
    required String alertId,
    required String userId,
    required String userName,
  }) async {
    try {
      final now = DateTime.now();

      await supabase
          .from('kot_delay_alerts')
          .update({
            'is_acknowledged': true,
            'acknowledged_at': now.toIso8601String(),
            'acknowledged_by_uid': userId,
            'acknowledged_by_name': userName,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', alertId);

      _acknowledgedAlerts.add(alertId);

      // Fetch and return updated alert
      final response = await supabase
          .from('kot_delay_alerts')
          .select()
          .eq('id', alertId)
          .single();

      return KOTDelayAlert.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error acknowledging alert: $e');
      return null;
    }
  }

  /// Resolve a delay alert (after item is finally served)
  Future<KOTDelayAlert?> resolveAlert({
    required String alertId,
    String? resolutionNotes,
  }) async {
    try {
      final now = DateTime.now();

      await supabase
          .from('kot_delay_alerts')
          .update({
            'is_resolved': true,
            'resolved_at': now.toIso8601String(),
            'resolution_notes': resolutionNotes,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', alertId);

      final response = await supabase
          .from('kot_delay_alerts')
          .select()
          .eq('id', alertId)
          .single();

      return KOTDelayAlert.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error resolving alert: $e');
      return null;
    }
  }

  /// Check and create delay alerts for a specific item
  Future<KOTDelayAlert?> checkItemDelay({
    required String itemId,
    required String kotId,
    required String businessId,
    String? kitchenId,
    SLATier slaTier = SLATier.standard,
  }) async {
    try {
      // Get item from database
      final response = await supabase
          .from('kot_items')
          .select()
          .eq('id', itemId)
          .single();

      final item = KOTItem.fromJson(response);

      // Skip if already served
      if (item.status == KOTItemStatus.served) {
        return null;
      }

      // Calculate elapsed time
      final startTime = item.startedPreparingAt ?? item.createdAt;
      final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
      final slaSeconds = slaThresholds[slaTier] ?? 900;

      // Check if delayed
      if (elapsedSeconds > slaSeconds) {
        final exceededBySeconds = elapsedSeconds - slaSeconds;

        // Determine alert type
        DelayAlertType alertType;
        if (exceededBySeconds > slaSeconds * 0.5) {
          alertType = DelayAlertType.urgent;
        } else if (exceededBySeconds > slaSeconds * 0.25) {
          alertType = DelayAlertType.critical;
        } else {
          alertType = DelayAlertType.warning;
        }

        // Check if alert already exists
        final existing = await supabase
            .from('kot_delay_alerts')
            .select()
            .eq('item_id', itemId)
            .eq('is_resolved', false);

        if ((existing as List).isEmpty) {
          // Create alert
          final alertData = {
            'id': '${itemId}_${DateTime.now().millisecondsSinceEpoch}',
            'kot_id': kotId,
            'item_id': itemId,
            'business_id': businessId,
            'kitchen_id': kitchenId,
            'alert_type': alertType.toString().split('.').last,
            'sla_deadline': startTime
                .add(Duration(seconds: slaSeconds))
                .toIso8601String(),
            'exceeded_by_seconds': exceededBySeconds,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await supabase.from('kot_delay_alerts').insert(alertData);

          // Mark item as delayed in main table
          await supabase
              .from('kot_items')
              .update({
                'is_sla_violated': true,
                'delay_seconds': exceededBySeconds,
              })
              .eq('id', itemId);

          final alert = KOTDelayAlert.fromJson(alertData);
          _notifyDelayUpdate([alert]);

          return alert;
        }
      } else {
        // Check if approaching warning threshold
        final warningThreshold = warningThresholds[slaTier] ?? 300;
        final timeUntilWarning = slaSeconds - elapsedSeconds;

        if (timeUntilWarning > 0 && timeUntilWarning <= warningThreshold) {
          debugPrint(
            '⚠️ Item $itemId approaching SLA (${timeUntilWarning}s remaining)',
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error checking item delay: $e');
      return null;
    }
  }

  /// Get items that are about to violate SLA
  Future<List<Map<String, dynamic>>> getItemsApproachingSLA({
    required String businessId,
    String? kitchenId,
  }) async {
    try {
      var query = supabase
          .from('kot_items')
          .select()
          .eq('business_id', businessId)
          .filter('status', 'in', '(pending,preparing)');

      if (kitchenId != null) {
        query = query.eq('assigned_kitchen_id', kitchenId);
      }

      final items = await query;

      final approaching = <Map<String, dynamic>>[];

      for (final item in items) {
        final kotItem = KOTItem.fromJson(item);
        final startTime = kotItem.startedPreparingAt ?? kotItem.createdAt;
        final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        // If > 80% of SLA consumed, it's approaching
        if (elapsedSeconds > kotItem.slaSeconds * 0.8) {
          approaching.add({
            'item': kotItem,
            'remaining_seconds': kotItem.slaSeconds - elapsedSeconds,
            'usage_percentage': (100.0 * elapsedSeconds / kotItem.slaSeconds),
          });
        }
      }

      // Sort by least remaining time first
      approaching.sort(
        (a, b) => (a['remaining_seconds'] as int).compareTo(
          b['remaining_seconds'] as int,
        ),
      );

      return approaching;
    } catch (e) {
      debugPrint('❌ Error getting approaching items: $e');
      return [];
    }
  }

  /// Callbacks
  void onDelayUpdate(OnDelayUpdate callback) {
    _delayCallbacks.add(callback);
  }

  void _notifyDelayUpdate(List<KOTDelayAlert> alerts) {
    for (final callback in _delayCallbacks) {
      callback(alerts);
    }
  }

  /// Cleanup
  void dispose() {
    _delayCheckTimer.cancel();
    debugPrint('✅ Delay service disposed');
  }
}

// ═════════════════════════════════════════════════════════════════════════════════
// DELAY STATISTICS
// ═════════════════════════════════════════════════════════════════════════════════

class DelayStatistics {
  int totalAlerts = 0;
  int warningAlerts = 0;
  int criticalAlerts = 0;
  int urgentAlerts = 0;

  int totalDelaySeconds = 0;
  int avgDelaySeconds = 0;

  double get criticalRate => totalAlerts > 0
      ? (100.0 * (criticalAlerts + urgentAlerts) / totalAlerts)
      : 0;

  String get avgDelayFormatted {
    final mins = avgDelaySeconds ~/ 60;
    final secs = avgDelaySeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'DelayStatistics(total=$totalAlerts, critical=$criticalAlerts, urgent=$urgentAlerts, avg=$avgDelayFormatted)';
}
