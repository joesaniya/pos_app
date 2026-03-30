// 🔥 REAL-TIME ORDER-KOT SYNC SERVICE
// Bi-Directional Synchronization Engine
// Path: lib/services/realtime_order_kot_sync_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

typedef OnOrderStatusSynced = void Function(String orderId, String newStatus);
typedef OnKOTStatusSynced = void Function(String kotId, String newStatus);
typedef OnSyncConflict =
    void Function(String orderId, String kotId, Map<String, dynamic> conflict);
typedef OnSyncEventReceived = void Function(Map<String, dynamic> event);

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC STATE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

class RealtimeOrderKOTSyncService {
  static final RealtimeOrderKOTSyncService _instance =
      RealtimeOrderKOTSyncService._internal();

  factory RealtimeOrderKOTSyncService() => _instance;

  RealtimeOrderKOTSyncService._internal();

  final supabase = Supabase.instance.client;

  // Sync state tracking
  final _syncStateMap = <String, SyncState>{}; // orderId -> SyncState
  final _orderKotMapping = <String, String>{}; // orderId -> kotId

  // Real-time listeners
  RealtimeChannel? _orderSyncChannel;
  RealtimeChannel? _kotSyncChannel;
  RealtimeChannel? _eventQueueChannel;

  // Callbacks
  final _orderStatusSyncCallbacks = <OnOrderStatusSynced>[];
  final _kotStatusSyncCallbacks = <OnKOTStatusSynced>[];
  final _syncConflictCallbacks = <OnSyncConflict>[];
  final _syncEventCallbacks = <OnSyncEventReceived>[];

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. Initialize Real-Time Sync Listeners
  // ═════════════════════════════════════════════════════════════════════════════

  /// Start listening to real-time sync events
  Future<void> initializeSync({required String businessId}) async {
    try {
      debugPrint('🚀 Initializing Order-KDS Sync System for $businessId');

      // Start polling for sync events
      _startSyncEventPolling(businessId);
      _startKOTStatusPolling(businessId);
      _startOrderStatusPolling(businessId);

      debugPrint('✅ Real-time sync listeners initialized for $businessId');
    } catch (e) {
      debugPrint('❌ Error initializing sync: $e');
      rethrow;
    }
  }

  /// Poll for sync events from database
  Future<void> _startSyncEventPolling(String businessId) async {
    // Poll every 500ms for new sync events
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final events = await supabase
            .from('sync_event_queue')
            .select()
            .eq('business_id', businessId)
            .eq('is_processed', false)
            .order('created_at', ascending: true)
            .limit(10);

        if (events.isNotEmpty) {
          for (final event in events) {
            await _handleSyncEvent(event);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Sync event polling error: $e');
      }
    });
  }

  /// Poll for KOT status changes
  Future<void> _startKOTStatusPolling(String businessId) async {
    // Poll every 1s for KOT updates
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final kotUpdates = await supabase
            .from('kot_orders')
            .select()
            .eq('business_id', businessId)
            .gt(
              'updated_at',
              DateTime.now()
                  .subtract(const Duration(seconds: 2))
                  .toIso8601String(),
            )
            .limit(5);

        if (kotUpdates.isNotEmpty) {
          for (final kot in kotUpdates) {
            await _handleKOTStatusChange(kot);
          }
        }
      } catch (e) {
        debugPrint('⚠️ KOT status polling error: $e');
      }
    });
  }

  /// Poll for order status changes
  Future<void> _startOrderStatusPolling(String businessId) async {
    // Poll every 1s for order updates
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final orderUpdates = await supabase
            .from('orders')
            .select()
            .eq('business_id', businessId)
            .gt(
              'updated_at',
              DateTime.now()
                  .subtract(const Duration(seconds: 2))
                  .toIso8601String(),
            )
            .limit(5);

        if (orderUpdates.isNotEmpty) {
          for (final order in orderUpdates) {
            await _handleOrderStatusChange(order);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Order status polling error: $e');
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. Create Order → KOT Link (Automatic)
  // ═════════════════════════════════════════════════════════════════════════════

  /// Create order-KOT mapping (called automatically via database trigger)
  Future<void> createOrderKOTLink({
    required String orderId,
    required String kotId,
    required String businessId,
  }) async {
    try {
      await supabase.from('order_kot_mapping').insert({
        'order_id': orderId,
        'kot_id': kotId,
        'business_id': businessId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _orderKotMapping[orderId] = kotId;

      // Initialize sync state
      _syncStateMap[orderId] = SyncState(
        orderId: orderId,
        kotId: kotId,
        businessId: businessId,
        posStatus: 'pending',
        kdsStatus: 'pending',
        lastPOSSync: DateTime.now(),
        lastKDSSync: DateTime.now(),
        isSynced: false,
        conflictStatus: 'none',
      );

      debugPrint('✅ Order-KOT link created: $orderId ↔️ $kotId');
    } catch (e) {
      debugPrint('❌ Error creating order-KOT link: $e');
      rethrow;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 3. Handle Real-Time Events
  // ═════════════════════════════════════════════════════════════════════════════

  /// Process incoming sync events from database
  Future<void> _handleSyncEvent(Map<String, dynamic> event) async {
    try {
      final eventType = event['event_type'] as String? ?? '';
      final entityId = event['entity_id'] as String? ?? '';

      debugPrint('📡 Sync Event Received: $eventType for $entityId');

      // Emit to callbacks
      for (final callback in _syncEventCallbacks) {
        callback(event);
      }

      // Handle specific event types
      switch (eventType) {
        case 'order_status_changed':
          await _handleOrderStatusSyncEvent(event);
          break;
        case 'order_created':
          await _handleOrderCreatedEvent(event);
          break;
        case 'item_added':
          await _handleItemAddedEvent(event);
          break;
        case 'item_status_changed':
          await _handleItemStatusChangeEvent(event);
          break;
      }

      // Mark event as processed
      if (event['id'] != null) {
        try {
          await supabase
              .from('sync_event_queue')
              .update({
                'is_processed': true,
                'processed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', event['id']);
        } catch (e) {
          debugPrint('⚠️ Warning: Could not mark event as processed: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling sync event: $e');
    }
  }

  /// Handle KOT status change → sync to order
  Future<void> _handleKOTStatusChange(Map<String, dynamic> kotData) async {
    try {
      final kotId = kotData['id'] as String;
      final newStatus = kotData['status'] as String;

      // Find linked order
      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('kot_id', kotId)
          .single();

      final orderId = mapping['order_id'] as String;

      // Update order status to match KOT
      final orderStatus = _mapKOTStatusToOrder(newStatus);

      await supabase
          .from('orders')
          .update({
            'status': orderStatus,
            'last_synced_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update sync state
      _updateSyncState(orderId, kotId, orderStatus, newStatus, 'KDS');

      // Notify listeners
      for (final callback in _kotStatusSyncCallbacks) {
        callback(kotId, newStatus);
      }

      debugPrint(
        '✅ KOT status synced to Order: $orderId ← $kotId ($newStatus)',
      );
    } catch (e) {
      debugPrint('❌ Error handling KOT status change: $e');
    }
  }

  /// Handle order status change → sync to KOT
  Future<void> _handleOrderStatusChange(Map<String, dynamic> orderData) async {
    try {
      final orderId = orderData['id'] as String;
      final newStatus = orderData['status'] as String;

      // Find linked KOT
      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (mapping == null) return;

      final kotId = mapping['kot_id'] as String;

      // Map order status to KOT status
      final kotStatus = _mapOrderStatusToKOT(newStatus);

      // Update KOT status
      await supabase
          .from('kot_orders')
          .update({
            'status': kotStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kotId);

      // Update sync state
      _updateSyncState(orderId, kotId, newStatus, kotStatus, 'POS');

      // Notify listeners
      for (final callback in _orderStatusSyncCallbacks) {
        callback(orderId, newStatus);
      }

      debugPrint(
        '✅ Order status synced to KOT: $kotId ← $orderId ($newStatus)',
      );
    } catch (e) {
      debugPrint('❌ Error handling order status change: $e');
    }
  }

  /// Handle order status sync event
  Future<void> _handleOrderStatusSyncEvent(
    Map<String, dynamic> eventData,
  ) async {
    try {
      final entityId = eventData['entity_id'] as String;
      final parentEntityId = eventData['parent_entity_id'] as String?;
      final eventDataJson = eventData['event_data'] as Map<String, dynamic>?;

      if (parentEntityId != null && eventDataJson != null) {
        final newStatus = eventDataJson['new_status'] as String?;
        if (newStatus != null) {
          _updateSyncState(
            entityId,
            parentEntityId,
            newStatus,
            newStatus,
            'SYNC',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling order status sync event: $e');
    }
  }

  /// Handle order creation event
  Future<void> _handleOrderCreatedEvent(Map<String, dynamic> eventData) async {
    try {
      final orderId = eventData['entity_id'] as String;
      final kotId = eventData['parent_entity_id'] as String?;

      if (kotId != null) {
        await createOrderKOTLink(
          orderId: orderId,
          kotId: kotId,
          businessId: eventData['business_id'],
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling order created event: $e');
    }
  }

  /// Handle item added event
  Future<void> _handleItemAddedEvent(Map<String, dynamic> eventData) async {
    try {
      final orderId = eventData['parent_entity_id'] as String;
      final eventDataJson = eventData['event_data'] as Map<String, dynamic>?;
      final kitchenId = eventDataJson?['assigned_kitchen'] as String?;

      if (kitchenId != null) {
        debugPrint(
          '📦 Item added to order $orderId, routed to kitchen: $kitchenId',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling item added event: $e');
    }
  }

  /// Handle item status change event
  Future<void> _handleItemStatusChangeEvent(
    Map<String, dynamic> eventData,
  ) async {
    try {
      final itemId = eventData['entity_id'] as String;
      final eventDataJson = eventData['event_data'] as Map<String, dynamic>?;
      final newStatus = eventDataJson?['new_status'] as String?;

      if (newStatus != null) {
        debugPrint('✏️ Item $itemId status changed to: $newStatus');
      }
    } catch (e) {
      debugPrint('❌ Error handling item status change event: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 4. Status Mapping Functions
  // ═════════════════════════════════════════════════════════════════════════════

  String _mapOrderStatusToKOT(String orderStatus) {
    return {
          'pending': 'pending',
          'preparing': 'in_progress',
          'ready': 'ready',
          'completed': 'completed',
          'cancelled': 'cancelled',
        }[orderStatus] ??
        'pending';
  }

  String _mapKOTStatusToOrder(String kotStatus) {
    return {
          'pending': 'pending',
          'in_progress': 'preparing',
          'ready': 'ready',
          'completed': 'completed',
          'cancelled': 'cancelled',
        }[kotStatus] ??
        'pending';
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 5. Sync State Management
  // ═════════════════════════════════════════════════════════════════════════════

  void _updateSyncState(
    String orderId,
    String kotId,
    String posStatus,
    String kdsStatus,
    String sourceSystem,
  ) {
    if (!_syncStateMap.containsKey(orderId)) {
      _syncStateMap[orderId] = SyncState(
        orderId: orderId,
        kotId: kotId,
        businessId: '',
        posStatus: posStatus,
        kdsStatus: kdsStatus,
        lastPOSSync: DateTime.now(),
        lastKDSSync: DateTime.now(),
        isSynced: posStatus == kdsStatus,
        conflictStatus: posStatus == kdsStatus ? 'none' : 'conflict',
      );
    } else {
      final state = _syncStateMap[orderId]!;
      if (sourceSystem == 'POS') {
        state.posStatus = posStatus;
        state.lastPOSSync = DateTime.now();
      } else if (sourceSystem == 'KDS') {
        state.kdsStatus = kdsStatus;
        state.lastKDSSync = DateTime.now();
      }
      state.isSynced = state.posStatus == state.kdsStatus;
      state.conflictStatus = state.isSynced ? 'none' : 'conflict';

      if (!state.isSynced) {
        // Notify conflict
        for (final callback in _syncConflictCallbacks) {
          callback(orderId, kotId, {
            'pos_status': state.posStatus,
            'kds_status': state.kdsStatus,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    }
  }

  /// Get current sync state for an order
  SyncState? getSyncState(String orderId) => _syncStateMap[orderId];

  /// Get all sync states
  Map<String, SyncState> getAllSyncStates() => Map.from(_syncStateMap);

  // ═════════════════════════════════════════════════════════════════════════════
  // 6. Manual Conflict Resolution
  // ═════════════════════════════════════════════════════════════════════════════

  /// Manually resolve sync conflict (Last-Write-Wins)
  Future<void> resolveConflict({
    required String orderId,
    required String kotId,
    required String businessId,
    String? resolutionRule,
  }) async {
    try {
      final result = await supabase.rpc(
        'fn_resolve_sync_conflict',
        params: {
          'p_order_id': orderId,
          'p_kot_id': kotId,
          'p_business_id': businessId,
        },
      );

      debugPrint('✅ Conflict resolved: ${result['winning_system']}');
    } catch (e) {
      debugPrint('❌ Error resolving conflict: $e');
      rethrow;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 7. Callback Management
  // ═════════════════════════════════════════════════════════════════════════════

  void onOrderStatusSynced(OnOrderStatusSynced callback) {
    _orderStatusSyncCallbacks.add(callback);
  }

  void onKOTStatusSynced(OnKOTStatusSynced callback) {
    _kotStatusSyncCallbacks.add(callback);
  }

  void onSyncConflict(OnSyncConflict callback) {
    _syncConflictCallbacks.add(callback);
  }

  void onSyncEventReceived(OnSyncEventReceived callback) {
    _syncEventCallbacks.add(callback);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 8. Cleanup
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    await _orderSyncChannel?.unsubscribe();
    await _kotSyncChannel?.unsubscribe();
    await _eventQueueChannel?.unsubscribe();
    _syncStateMap.clear();
    _orderKotMapping.clear();
    debugPrint('🛑 Sync service disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC STATE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class SyncState {
  final String orderId;
  final String kotId;
  final String businessId;

  String posStatus;
  String kdsStatus;
  DateTime lastPOSSync;
  DateTime lastKDSSync;
  bool isSynced;
  String conflictStatus; // 'none', 'conflict', 'error'

  SyncState({
    required this.orderId,
    required this.kotId,
    required this.businessId,
    required this.posStatus,
    required this.kdsStatus,
    required this.lastPOSSync,
    required this.lastKDSSync,
    required this.isSynced,
    required this.conflictStatus,
  });

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'kot_id': kotId,
    'business_id': businessId,
    'pos_status': posStatus,
    'kds_status': kdsStatus,
    'last_pos_sync': lastPOSSync.toIso8601String(),
    'last_kds_sync': lastKDSSync.toIso8601String(),
    'is_synced': isSynced,
    'conflict_status': conflictStatus,
  };

  @override
  String toString() =>
      'SyncState(order:$orderId/kot:$kotId, pos:$posStatus/kds:$kdsStatus, synced:$isSynced)';
}
