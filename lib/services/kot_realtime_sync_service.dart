// 🔥 KOT REAL-TIME SYNC SERVICE - WebSocket Integration
// lib/services/kot_realtime_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/kot_models.dart';
import 'kot_service.dart';

typedef OnConnectionChanged = void Function(bool isOnline);
typedef OnKOTUpdatedCallback = void Function(KOTOrder kot);
typedef OnItemStatusChangedCallback = void Function(KOTItem item);

class KOTRealtimeSyncService {
  static final KOTRealtimeSyncService _instance =
      KOTRealtimeSyncService._internal();

  factory KOTRealtimeSyncService() => _instance;

  KOTRealtimeSyncService._internal();

  final supabase = Supabase.instance.client;
  late KOTService kotService;

  final Map<String, RealtimeChannel> _activeChannels = {};
  final List<OnConnectionChanged> _connectionCallbacks = [];
  final List<OnKOTUpdatedCallback> _kotUpdatedCallbacks = [];
  final List<OnItemStatusChangedCallback> _itemStatusCallbacks = [];

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Event deduplication
  final Set<String> _processedEvents = {};
  static const int _maxEventCacheSize = 1000;

  /// Initialize real-time sync for a business
  Future<void> initialize({
    required String businessId,
    required String kitchenId,
  }) async {
    try {
      kotService = KOTService();

      // Subscribe to KOT orders
      _subscribeToKOTOrders(businessId);

      // Subscribe to KOT items
      _subscribeToKOTItems(businessId);

      // Subscribe to kitchen-specific broadcasts
      _subscribeToKitchenBroadcasts(kitchenId);

      // Subscribe to delay alerts
      _subscribeToDelayAlerts(businessId);

      // Set up connection monitoring
      _monitorConnection();

      debugPrint('✅ Real-time sync initialized for business: $businessId');
    } catch (e) {
      debugPrint('❌ Error initializing real-time sync: $e');
    }
  }

  /// Subscribe to KOT order changes
  void _subscribeToKOTOrders(String businessId) {
    final channel = supabase.realtime.channel(
      'public:kot_orders:business_id=eq.$businessId',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'kot_orders',
          filter: PostgresChangeFilter(
            column: 'business_id',
            type: PostgresChangeFilterType.eq,
            value: businessId,
          ),
          callback: (payload) {
            _handleKOTOrderUpdate(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'kot_orders',
          filter: PostgresChangeFilter(
            column: 'business_id',
            type: PostgresChangeFilterType.eq,
            value: businessId,
          ),
          callback: (payload) {
            _handleKOTOrderInsert(payload);
          },
        )
        .subscribe();

    _activeChannels['kot_orders'] = channel;
  }

  /// Subscribe to KOT item status changes
  void _subscribeToKOTItems(String businessId) {
    final channel = supabase.realtime.channel(
      'public:kot_items:business_id=eq.$businessId',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'kot_items',
          filter: PostgresChangeFilter(
            column: 'business_id',
            type: PostgresChangeFilterType.eq,
            value: businessId,
          ),
          callback: (payload) {
            _handleItemStatusUpdate(payload);
          },
        )
        .subscribe();

    _activeChannels['kot_items'] = channel;
  }

  /// Subscribe to kitchen-specific broadcasts
  void _subscribeToKitchenBroadcasts(String kitchenId) {
    final channel = supabase.realtime.channel('kitchen_$kitchenId');

    channel
        .onBroadcast(
          event: 'new_items',
          callback: (payload) {
            _handleNewItemsBroadcast(payload);
          },
        )
        .onBroadcast(
          event: 'urgent_alert',
          callback: (payload) {
            _handleUrgentAlert(payload);
          },
        )
        .subscribe();

    _activeChannels['kitchen_broadcast'] = channel;
  }

  /// Subscribe to delay alerts
  void _subscribeToDelayAlerts(String businessId) {
    final channel = supabase.realtime.channel(
      'public:kot_delay_alerts:business_id=eq.$businessId',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'kot_delay_alerts',
          filter: PostgresChangeFilter(
            column: 'business_id',
            type: PostgresChangeFilterType.eq,
            value: businessId,
          ),
          callback: (payload) {
            _handleDelayAlertCreated(payload);
          },
        )
        .subscribe();

    _activeChannels['delay_alerts'] = channel;
  }

  /// Handle KOT order updates
  void _handleKOTOrderUpdate(PostgresChangePayload payload) {
    try {
      final eventId =
          '${payload.newRecord['id']}_${DateTime.now().millisecondsSinceEpoch}';

      // Prevent duplicate processing
      if (_isDuplicateEvent(eventId)) return;

      final kot = KOTOrder.fromJson(payload.newRecord);
      debugPrint('📡 KOT Order Updated: ${kot.kotNumber}');

      // Notify all registered callbacks
      _notifyKOTUpdated(kot);
    } catch (e) {
      debugPrint('❌ Error handling KOT order update: $e');
    }
  }

  /// Handle KOT order inserts
  void _handleKOTOrderInsert(PostgresChangePayload payload) {
    try {
      final eventId = '${payload.newRecord['id']}_INSERT';

      if (_isDuplicateEvent(eventId)) return;

      final kot = KOTOrder.fromJson(payload.newRecord);
      debugPrint('📡 New KOT Order: ${kot.kotNumber}');

      // Play notification sound
      _playNewOrderAlert();
    } catch (e) {
      debugPrint('❌ Error handling KOT order insert: $e');
    }
  }

  /// Handle item status updates
  void _handleItemStatusUpdate(PostgresChangePayload payload) {
    try {
      final eventId =
          '${payload.newRecord['id']}_${payload.newRecord['status']}';

      if (_isDuplicateEvent(eventId)) return;

      final item = KOTItem.fromJson(payload.newRecord);
      debugPrint('📡 Item Status Updated: ${item.itemName} → ${item.status}');

      // Flash notification
      if (item.status == KOTItemStatus.ready) {
        _playReadyAlert();
      }

      // Notify all registered callbacks
      _notifyItemStatusChanged(item);
    } catch (e) {
      debugPrint('❌ Error handling item status update: $e');
    }
  }

  /// Handle new items broadcast
  void _handleNewItemsBroadcast(Map<String, dynamic> payload) {
    try {
      debugPrint('📡 New Items Broadcast Received');

      final items =
          (payload['items'] as List?)
              ?.map((i) => KOTItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [];

      if (items.isNotEmpty) {
        _playNewItemsAlert(itemCount: items.length);
      }
    } catch (e) {
      debugPrint('❌ Error handling new items broadcast: $e');
    }
  }

  /// Handle urgent alerts
  void _handleUrgentAlert(Map<String, dynamic> payload) {
    try {
      final message = payload['message'] as String? ?? 'Urgent Alert!';
      debugPrint('📡 Urgent Alert: $message');
      _playUrgentAlert();
    } catch (e) {
      debugPrint('❌ Error handling urgent alert: $e');
    }
  }

  /// Handle delay alert creation
  void _handleDelayAlertCreated(PostgresChangePayload payload) {
    try {
      final alert = KOTDelayAlert.fromJson(payload.newRecord);
      debugPrint('📡 Delay Alert Created: ${alert.alertType}');
      _playDelayAlert();
    } catch (e) {
      debugPrint('❌ Error handling delay alert: $e');
    }
  }

  /// Monitor connection status
  void _monitorConnection() {
    // Check connection every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnection();
    });
  }

  void _checkConnection() {
    // Check if channels are still active
    bool wasOnline = _isOnline;

    _isOnline = _activeChannels.values.isNotEmpty;

    if (wasOnline != _isOnline) {
      debugPrint(_isOnline ? '🟢 Online' : '🔴 Offline');
      _notifyConnectionChange(_isOnline);
    }
  }

  /// Event deduplication
  bool _isDuplicateEvent(String eventId) {
    if (_processedEvents.contains(eventId)) {
      return true;
    }

    _processedEvents.add(eventId);

    // Keep cache size manageable
    if (_processedEvents.length > _maxEventCacheSize) {
      _processedEvents.clear();
    }

    return false;
  }

  /// Audio alerts - Implement using local_notifications or HapticFeedback
  void _playNewOrderAlert() {
    debugPrint('🔔 New Order Alert Sound');
  }

  void _playReadyAlert() {
    debugPrint('🔔 Ready Alert Sound');
  }

  void _playNewItemsAlert({required int itemCount}) {
    debugPrint('🔔 New Items Alert ($itemCount items)');
  }

  void _playUrgentAlert() {
    debugPrint('🔔 Urgent Alert Sound');
  }

  void _playDelayAlert() {
    debugPrint('🔔 Delay Alert Sound');
  }

  /// Callbacks for KOT updates
  void onKOTUpdated(OnKOTUpdatedCallback callback) {
    _kotUpdatedCallbacks.add(callback);
  }

  void onItemStatusChanged(OnItemStatusChangedCallback callback) {
    _itemStatusCallbacks.add(callback);
  }

  void _notifyKOTUpdated(KOTOrder kot) {
    for (final callback in _kotUpdatedCallbacks) {
      callback(kot);
    }
  }

  void _notifyItemStatusChanged(KOTItem item) {
    for (final callback in _itemStatusCallbacks) {
      callback(item);
    }
  }

  /// Connection callbacks
  void onConnectionChanged(OnConnectionChanged callback) {
    _connectionCallbacks.add(callback);
  }

  void _notifyConnectionChange(bool isOnline) {
    for (final callback in _connectionCallbacks) {
      callback(isOnline);
    }
  }

  /// Cleanup
  Future<void> dispose() async {
    for (final channel in _activeChannels.values) {
      await channel.unsubscribe();
    }
    _activeChannels.clear();
    debugPrint('✅ Real-time sync disposed');
  }
}
