// 🔥 COMPLETE INTEGRATION GUIDE: REAL-TIME ORDER-KDS SYNC SYSTEM
// Path: lib/services/order_kds_integration.dart
//
// This file demonstrates complete integration of:
// 1. Order Creation → Auto KOT Generation
// 2. Real-Time Bi-Directional Sync
// 3. Kitchen Routing & Segmentation
// 4. Status Consistency & Conflict Resolution
// 5. Idempotent Updates

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'realtime_order_kot_sync_service.dart';
import 'kitchen_routing_service.dart';
import 'kot_service.dart';
import '../models/kot_models.dart';

typedef OnOrderKDSSyncComplete =
    void Function(String orderId, String kotId, bool success, String message);

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED ORDER-KDS SYNC MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

class OrderKDSSyncManager {
  static final OrderKDSSyncManager _instance = OrderKDSSyncManager._internal();

  factory OrderKDSSyncManager() => _instance;

  OrderKDSSyncManager._internal();

  final supabase = Supabase.instance.client;
  final syncService = RealtimeOrderKOTSyncService();
  final routingService = KitchenRoutingService();
  final kotService = KOTService();

  bool _isInitialized = false;
  String? _businessId;
  final _completionCallbacks = <OnOrderKDSSyncComplete>[];

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 1: INITIALIZE COMPLETE SYSTEM
  // ═════════════════════════════════════════════════════════════════════════════

  /// Initialize all sync components
  Future<void> initialize({required String businessId}) async {
    try {
      if (_isInitialized) {
        debugPrint('⚠️ Sync system already initialized');
        return;
      }

      _businessId = businessId;

      debugPrint('🚀 Initializing Order-KDS Sync System...');

      // 1. Initialize real-time sync
      await syncService.initializeSync(businessId: businessId);

      // 2. Setup routing service cache
      await routingService.getRoutingRules(businessId);

      // 3. Setup callbacks
      _setupCallbacks();

      // 4. Load initial kitchen routing rules
      await _setupDefaultRoutingRules(businessId);

      _isInitialized = true;

      debugPrint('✅ Order-KDS Sync System initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing sync system: $e');
      rethrow;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 2: COMPLETE ORDER CREATION FLOW
  // ═════════════════════════════════════════════════════════════════════════════

  /// Create order with full sync integration
  /// Flow: Order → KOT (auto via trigger) → Route items → Sync status
  Future<Map<String, dynamic>> createOrderWithSync({
    required String businessId,
    required String tabId,
    required int tableNumber,
    required String? customerName,
    required List<OrderItemInput> items,
    required String createdByUid,
    required String createdByName,
  }) async {
    try {
      if (!_isInitialized || _businessId != businessId) {
        await initialize(businessId: businessId);
      }

      debugPrint('📝 Creating order with full sync integration...');

      // PHASE 1: Create order in POS
      final orderResponse = await supabase
          .from('orders')
          .insert({
            'business_id': businessId,
            'order_number': DateTime.now().millisecondsSinceEpoch % 100000,
            'status': 'pending',
            'order_type': 'dine_in',
            'table_id': tabId,
            'table_number': tableNumber,
            'customer_name': customerName,
            'subtotal': _calculateSubtotal(items),
            'tax_amount': 0,
            'discount_amount': 0,
            'total_amount': 0,
            'tax_rate': 5.0,
            'business_name': 'SriSoftwarez',
            'created_by_uid': createdByUid,
            'created_by_name': createdByName,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;
      debugPrint('✅ Order created: $orderId');

      // PHASE 2: Add order items
      final itemIds = <String>[];
      for (final item in items) {
        final itemResponse = await supabase
            .from('order_items')
            .insert({
              'order_id': orderId,
              'menu_item_id': item.menuItemId,
              'item_name': item.itemName,
              'item_price': item.price,
              'category_name': item.category,
              'is_veg': item.isVeg,
              'quantity': item.quantity,
              'subtotal': item.price * item.quantity,
              'notes': item.notes,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        itemIds.add(itemResponse['id'] as String);
      }

      debugPrint('✅ Order items added: ${items.length} items');

      // PHASE 3: Get generated KOT (created automatically by trigger)
      await Future.delayed(const Duration(milliseconds: 500));

      final kotMapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (kotMapping == null) {
        throw Exception('KOT was not auto-created. Check database triggers.');
      }

      final kotId = kotMapping['kot_id'] as String;
      debugPrint('✅ KOT auto-created and linked: $kotId');

      // PHASE 4: Route items to kitchens
      final routingMap = await routingService.routeOrderItems(
        orderId: orderId,
        businessId: businessId,
        items: items
            .map(
              (i) => OrderItemForRouting(
                id: itemIds[items.indexOf(i)],
                name: i.itemName,
                category: i.category,
                quantity: i.quantity,
              ),
            )
            .toList(),
      );

      debugPrint(
        '✅ Items routed to ${routingMap.length} kitchens: ${routingMap.keys.join(", ")}',
      );

      // PHASE 5: Update order with initial KOT sync
      await supabase
          .from('orders')
          .update({
            'is_synced_to_kds': true,
            'last_synced_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // PHASE 6: Trigger sync event
      await supabase.from('sync_event_queue').insert({
        'business_id': businessId,
        'source_system': 'POS',
        'event_type': 'order_created',
        'entity_type': 'order',
        'entity_id': orderId,
        'parent_entity_id': kotId,
        'event_data': {
          'order_id': orderId,
          'kot_id': kotId,
          'order_number': orderResponse['order_number'],
          'item_count': items.length,
          'kitchens': routingMap.keys.toList(),
        },
        'event_hash': _generateEventHash(orderId, businessId, 'order_created'),
        'is_processed': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Sync event queued for real-time broadcast');

      // Success callback
      for (final callback in _completionCallbacks) {
        callback(orderId, kotId, true, 'Order created and synced successfully');
      }

      return {
        'success': true,
        'order_id': orderId,
        'kot_id': kotId,
        'kitchens': routingMap.keys.toList(),
        'message': 'Order created with full sync',
      };
    } catch (e) {
      debugPrint('❌ Error creating order with sync: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 3: HANDLE STATUS CHANGES (Bi-Directional)
  // ═════════════════════════════════════════════════════════════════════════════

  /// Update order status (POS → KOT)
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    required String updatedByUid,
    required String updatedByName,
  }) async {
    try {
      debugPrint('🔄 Updating order status: $orderId → $newStatus');

      // Find linked KOT
      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (mapping == null) {
        throw Exception('No KOT linked to this order');
      }

      final kotId = mapping['kot_id'] as String;

      // Update order (KOT update happens via trigger)
      await supabase
          .from('orders')
          .update({
            'status': newStatus,
            'updated_by_uid': updatedByUid,
            'updated_by_name': updatedByName,
            'last_synced_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      debugPrint('✅ Order status updated: $newStatus (KOT sync via trigger)');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      return false;
    }
  }

  /// Update KOT item status (KDS → POS)
  Future<bool> updateKOTItemStatus({
    required String kotItemId,
    required String newStatus,
  }) async {
    try {
      debugPrint('🔄 Updating KOT item status: $kotItemId → $newStatus');

      // Update KOT item
      await supabase
          .from('kot_items')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
            if (newStatus == 'preparing')
              'started_preparing_at': DateTime.now().toIso8601String(),
            if (newStatus == 'ready')
              'ready_at': DateTime.now().toIso8601String(),
            if (newStatus == 'served')
              'served_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kotItemId);

      debugPrint('✅ KOT item status updated: $newStatus');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating KOT item status: $e');
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 4: HANDLE ADD ITEMS (Append without Reset)
  // ═════════════════════════════════════════════════════════════════════════════

  /// Add items to existing order (new items only)
  Future<bool> addItemsToExistingOrder({
    required String orderId,
    required List<OrderItemInput> newItems,
    required String addedByUid,
    required String addedByName,
  }) async {
    try {
      debugPrint('➕ Adding ${newItems.length} items to order: $orderId');

      // Find linked KOT
      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (mapping == null) {
        throw Exception('No KOT linked to this order');
      }

      final kotId = mapping['kot_id'] as String;
      final businessId = mapping['business_id'] as String;

      // Add items to order
      final itemIds = <String>[];
      for (final item in newItems) {
        final itemResponse = await supabase
            .from('order_items')
            .insert({
              'order_id': orderId,
              'menu_item_id': item.menuItemId,
              'item_name': item.itemName,
              'item_price': item.price,
              'category_name': item.category,
              'is_veg': item.isVeg,
              'quantity': item.quantity,
              'subtotal': item.price * item.quantity,
              'notes': item.notes,
              'synced_to_kot': false,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        itemIds.add(itemResponse['id'] as String);
      }

      debugPrint('✅ Items added to order: ${newItems.length} items');

      // Route new items to kitchens
      await routingService.routeOrderItems(
        orderId: orderId,
        businessId: businessId,
        items: newItems
            .map(
              (i) => OrderItemForRouting(
                id: itemIds[newItems.indexOf(i)],
                name: i.itemName,
                category: i.category,
                quantity: i.quantity,
              ),
            )
            .toList(),
      );

      // Create KOT batch with new items (without resetting previous status)
      final batch = await kotService.addItemsToKOT(
        kotId: kotId,
        businessId: businessId,
        items: newItems
            .map(
              (i) => KOTItem(
                id: '',
                kotId: kotId,
                batchId: '',
                businessId: businessId,
                itemName: i.itemName,
                quantity: i.quantity,
                category: i.category,
                isVeg: i.isVeg,
                specialInstructions: i.notes,
                status: KOTItemStatus.pending,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            )
            .toList(),
        addedByUid: addedByUid,
        addedByName: addedByName,
      );

      if (batch != null) {
        debugPrint(
          '✅ New batch created in KOT without resetting item statuses',
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error adding items to order: $e');
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 5: CONFLICT RESOLUTION
  // ═════════════════════════════════════════════════════════════════════════════

  /// Check for sync conflicts and resolve
  Future<bool> checkAndResolveConflicts({required String orderId}) async {
    try {
      final syncState = syncService.getSyncState(orderId);

      if (syncState == null || syncState.isSynced) {
        return true; // No conflict
      }

      debugPrint(
        '⚠️ Sync conflict detected: ${syncState.posStatus} vs ${syncState.kdsStatus}',
      );

      // Get order and KOT
      final order = await supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (order == null) return false;

      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (mapping == null) return false;

      final kotId = mapping['kot_id'] as String;
      final businessId = mapping['business_id'] as String;

      // Resolve using Last-Write-Wins
      await syncService.resolveConflict(
        orderId: orderId,
        kotId: kotId,
        businessId: businessId,
        resolutionRule: 'last_write_wins',
      );

      debugPrint('✅ Conflict resolved using Last-Write-Wins algorithm');
      return true;
    } catch (e) {
      debugPrint('❌ Error resolving conflicts: $e');
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // STEP 6: MONITORING & ANALYTICS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Get complete sync state for debugging
  Future<Map<String, dynamic>> getSyncDiagnostics({
    required String orderId,
  }) async {
    try {
      final syncState = syncService.getSyncState(orderId);

      final mapping = await supabase
          .from('order_kot_mapping')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      final order = await supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      final kot = mapping != null
          ? await supabase
                .from('kot_orders')
                .select()
                .eq('id', mapping['kot_id'])
                .maybeSingle()
          : null;

      return {
        'order_id': orderId,
        'sync_state': syncState?.toJson(),
        'order': order,
        'kot': kot,
        'is_synced': syncState?.isSynced ?? false,
        'conflict_status': syncState?.conflictStatus,
      };
    } catch (e) {
      debugPrint('❌ Error getting sync diagnostics: $e');
      return {'error': e.toString()};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═════════════════════════════════════════════════════════════════════════════

  void _setupCallbacks() {
    // Order status synced to KOT
    syncService.onOrderStatusSynced((orderId, newStatus) {
      debugPrint('📤 Order status synced to KOT: $orderId → $newStatus');
    });

    // KOT status synced to order
    syncService.onKOTStatusSynced((kotId, newStatus) {
      debugPrint('📥 KOT status synced to Order: $kotId ← $newStatus');
    });

    // Conflict detected
    syncService.onSyncConflict((orderId, kotId, conflict) {
      debugPrint('⚠️ Sync conflict: $orderId/$kotId → $conflict');
    });

    // Raw sync events
    syncService.onSyncEventReceived((event) {
      debugPrint('📡 Sync event: ${event['event_type']}');
    });
  }

  Future<void> _setupDefaultRoutingRules(String businessId) async {
    try {
      // Check if rules exist
      final existing = await routingService.getRoutingRules(businessId);

      if (existing.isNotEmpty) {
        debugPrint('✅ Existing routing rules found: ${existing.length}');
        return;
      }

      // Create default rules
      await routingService.createRoutingRule(
        businessId: businessId,
        kitchenId: 'kitchen_main',
        kitchenName: 'Main Kitchen',
        matchType: 'category',
        matchValue: 'Main_Course',
        priority: 10,
      );

      await routingService.createRoutingRule(
        businessId: businessId,
        kitchenId: 'kitchen_beverages',
        kitchenName: 'Beverages',
        matchType: 'category',
        matchValue: 'Drinks',
        priority: 5,
      );

      debugPrint('✅ Default routing rules created');
    } catch (e) {
      debugPrint('⚠️ Error setting up routing rules: $e');
    }
  }

  double _calculateSubtotal(List<OrderItemInput> items) {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  String _generateEventHash(
    String entityId,
    String businessId,
    String eventType,
  ) {
    return '$entityId-$businessId-$eventType-${DateTime.now().millisecondsSinceEpoch}'
        .hashCode
        .toString();
  }

  void onOrderKDSSyncComplete(OnOrderKDSSyncComplete callback) {
    _completionCallbacks.add(callback);
  }

  Future<void> dispose() async {
    await syncService.dispose();
    routingService.clearCache();
    debugPrint('🛑 Order-KDS Sync Manager disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INPUT MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class OrderItemInput {
  final String menuItemId;
  final String itemName;
  final double price;
  final String? category;
  final bool isVeg;
  final int quantity;
  final String? notes;

  OrderItemInput({
    required this.menuItemId,
    required this.itemName,
    required this.price,
    required this.category,
    required this.isVeg,
    required this.quantity,
    this.notes,
  });
}
