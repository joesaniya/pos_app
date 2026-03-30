// 🔥 KITCHEN ORDER TOKEN (KOT) SERVICE - Core Operations
// lib/services/kot_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/kot_models.dart';

typedef OnKOTUpdated = void Function(KOTOrder kot);
typedef OnItemStatusChanged = void Function(KOTItem item);
typedef OnBatchAdded = void Function(KOTBatch batch);
typedef OnDelayDetected = void Function(KOTDelayAlert alert);

class KOTService {
  static final KOTService _instance = KOTService._internal();

  factory KOTService() => _instance;

  KOTService._internal();

  final supabase = Supabase.instance.client;
  final _kotCache = <String, KOTOrder>{};
  final _batchCache = <String, List<KOTBatch>>{};

  // Callbacks
  final _kotUpdatedCallbacks = <OnKOTUpdated>[];
  final _itemStatusCallbacks = <OnItemStatusChanged>[];
  final _batchAddedCallbacks = <OnBatchAdded>[];
  final _delayCallbacks = <OnDelayDetected>[];

  // ═════════════════════════════════════════════════════════════════════════════════
  // 1. CREATE KOT FROM ORDER
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Create a new KOT order from a POS order
  Future<KOTOrder?> createKOT({
    required String businessId,
    required String orderId,
    required List<KOTItem> items,
    KOTPriority priority = KOTPriority.normal,
    int? tableNumber,
    String? customerName,
    String? notes,
    String? createdByUid,
    String? createdByName,
  }) async {
    try {
      // Generate KOT ID
      const uuid = Uuid();
      final kotId = uuid.v4();
      final batchId = uuid.v4();

      // Create KOT order
      final kotData = {
        'id': kotId,
        'business_id': businessId,
        'order_id': orderId,
        'status': 'pending',
        'priority': priority.toString().split('.').last,
        'total_items': items.length,
        'kot_created_at': DateTime.now().toIso8601String(),
        'sent_to_kitchen_at': DateTime.now().toIso8601String(),
        'table_number': tableNumber,
        'customer_name': customerName,
        'notes': notes,
        'created_by_uid': createdByUid,
        'created_by_name': createdByName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('kot_orders').insert(kotData);

      // Create initial batch
      final batchData = {
        'id': batchId,
        'kot_id': kotId,
        'business_id': businessId,
        'batch_number': 1,
        'is_new_item_batch': false,
        'batch_added_at': DateTime.now().toIso8601String(),
        'item_count': items.length,
        'batch_status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('kot_item_batches').insert(batchData);

      // Add items
      for (var i = 0; i < items.length; i++) {
        final itemData = {
          'id': uuid.v4(),
          'kot_id': kotId,
          'batch_id': batchId,
          'business_id': businessId,
          'item_name': items[i].itemName,
          'quantity': items[i].quantity,
          'category': items[i].category,
          'is_veg': items[i].isVeg,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('kot_items').insert(itemData);
      }

      // Log audit
      await _logAuditEvent(
        businessId: businessId,
        kotId: kotId,
        action: 'KOT_CREATED',
        details: 'KOT created with ${items.length} items',
        userId: createdByUid,
        userName: createdByName,
      );

      // Fetch and return full KOT
      return getKOT(kotId: kotId, businessId: businessId);
    } catch (e) {
      debugPrint('❌ Error creating KOT: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 2. ADD ITEMS TO EXISTING KOT
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Add items to an existing KOT (creates new batch)
  Future<KOTBatch?> addItemsToKOT({
    required String kotId,
    required String businessId,
    required List<KOTItem> items,
    String? notes,
    String? addedByUid,
    String? addedByName,
  }) async {
    try {
      const uuid = Uuid();

      // Get current KOT to find next batch number
      final kot = await getKOT(kotId: kotId, businessId: businessId);
      if (kot == null) throw 'KOT not found';

      final nextBatchNumber = (kot.currentBatchNumber) + 1;
      final batchId = uuid.v4();

      // Create new batch (marked as new items)
      final batchData = {
        'id': batchId,
        'kot_id': kotId,
        'business_id': businessId,
        'batch_number': nextBatchNumber,
        'is_new_item_batch': true,
        'batch_added_at': DateTime.now().toIso8601String(),
        'item_count': items.length,
        'batch_status': 'active',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('kot_item_batches').insert(batchData);

      // Add items to new batch
      for (final item in items) {
        final itemData = {
          'id': uuid.v4(),
          'kot_id': kotId,
          'batch_id': batchId,
          'business_id': businessId,
          'item_name': item.itemName,
          'quantity': item.quantity,
          'category': item.category,
          'is_veg': item.isVeg,
          'special_instructions': item.specialInstructions,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('kot_items').insert(itemData);
      }

      // Update KOT
      await supabase
          .from('kot_orders')
          .update({
            'current_batch_number': nextBatchNumber,
            'batch_count': nextBatchNumber,
            'status': 'in_progress',
            'total_items': (kot.totalItems + items.length),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kotId);

      // Log audit
      await _logAuditEvent(
        businessId: businessId,
        kotId: kotId,
        action: 'ITEMS_ADDED_TO_KOT',
        details: '${items.length} items added as batch #$nextBatchNumber',
        userId: addedByUid,
        userName: addedByName,
      );

      // Notify
      _notifyBatchAdded(
        KOTBatch(
          id: batchId,
          kotId: kotId,
          businessId: businessId,
          batchNumber: nextBatchNumber,
          isNewItemBatch: true,
          batchAddedAt: DateTime.now(),
          itemCount: items.length,
          preparedCount: 0,
          completionPercentage: 0,
          items: items,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Clear cache
      _kotCache.remove(kotId);

      return getBatch(batchId: batchId, businessId: businessId);
    } catch (e) {
      debugPrint('❌ Error adding items to KOT: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 3. UPDATE ITEM STATUS
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Update status of a single item
  Future<KOTItem?> updateItemStatus({
    required String itemId,
    required String kotId,
    required String businessId,
    required KOTItemStatus newStatus,
    String? updatedByUid,
    String? updatedByName,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'status': newStatus.toString().split('.').last,
        'updated_at': now.toIso8601String(),
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
      };

      // Set status-specific timestamps
      if (newStatus == KOTItemStatus.preparing) {
        updateData['started_preparing_at'] = now.toIso8601String();
      } else if (newStatus == KOTItemStatus.ready) {
        updateData['ready_at'] = now.toIso8601String();
      } else if (newStatus == KOTItemStatus.served) {
        updateData['served_at'] = now.toIso8601String();
      }

      await supabase.from('kot_items').update(updateData).eq('id', itemId);

      // Get updated item
      final response = await supabase
          .from('kot_items')
          .select()
          .eq('id', itemId)
          .single();

      final updatedItem = KOTItem.fromJson(response);

      // Log audit
      await _logAuditEvent(
        businessId: businessId,
        kotId: kotId,
        action: 'ITEM_STATUS_UPDATED',
        details:
            'Item $itemId status changed to ${newStatus.toString().split('.').last}',
        userId: updatedByUid,
        userName: updatedByName,
      );

      // Notify
      _notifyItemStatusChanged(updatedItem);

      // Clear cache
      _kotCache.remove(kotId);

      return updatedItem;
    } catch (e) {
      debugPrint('❌ Error updating item status: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 4. ROUTE ITEMS TO KITCHENS
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Auto-route items to kitchens based on category
  Future<Map<String, List<KOTItem>>> routeItemsToKitchens({
    required String kotId,
    required String businessId,
    required List<KOTItem> items,
    Map<String, String>? customRouting, // itemId -> kitchenId
  }) async {
    try {
      final routing = <String, List<KOTItem>>{};

      // Get kitchen routing rules
      final rules = await supabase
          .from('kitchen_routing_rules')
          .select()
          .eq('business_id', businessId)
          .order('rule_priority', ascending: false);

      for (final item in items) {
        String? kitchenId = customRouting?[item.id];

        if (kitchenId == null) {
          // Find matching rule
          for (final rule in rules) {
            final matchType = rule['match_type'] as String;
            final matchValue = rule['match_value'] as String;

            if (matchType == 'category' && item.category == matchValue) {
              kitchenId = rule['target_kitchen_id'];
              break;
            } else if (matchType == 'keyword' &&
                (item.itemName.toLowerCase().contains(
                  matchValue.toLowerCase(),
                ))) {
              kitchenId = rule['target_kitchen_id'];
              break;
            }
          }
        }

        if (kitchenId != null) {
          // Update item with kitchen assignment
          await supabase
              .from('kot_items')
              .update({'assigned_kitchen_id': kitchenId})
              .eq('id', item.id);

          routing.putIfAbsent(kitchenId, () => []).add(item);
        }
      }

      // Log audit
      await _logAuditEvent(
        businessId: businessId,
        kotId: kotId,
        action: 'ITEMS_ROUTED',
        details: 'Routed ${items.length} items to ${routing.length} kitchens',
      );

      // Real-time sync handled by KOTRealtimeSyncService subscriptions
      // Kitchen displays will receive updates through Postgres change events

      return routing;
    } catch (e) {
      debugPrint('❌ Error routing items: $e');
      return {};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 5. DETECT DELAYED ITEMS
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Detect and create delay alerts for SLA violations
  Future<List<KOTDelayAlert>> detectDelayedItems({
    required String businessId,
    required String? kitchenId,
  }) async {
    try {
      const uuid = Uuid();
      final alerts = <KOTDelayAlert>[];

      // Validate businessId
      if (businessId.isEmpty) {
        return [];
      }

      // Get all items that might be delayed
      var query = supabase
          .from('kot_items')
          .select()
          .eq('business_id', businessId);

      // Only filter by kitchen if provided and not "all"
      if (kitchenId != null &&
          kitchenId.isNotEmpty &&
          kitchenId.toLowerCase() != 'all') {
        query = query.eq('assigned_kitchen_id', kitchenId);
      }

      final items = await query;

      // Filter client-side for status and other conditions
      final filteredItems = (items as List)
          .map((i) => KOTItem.fromJson(i))
          .where(
            (item) =>
                item.status == KOTItemStatus.preparing &&
                item.startedPreparingAt != null,
          )
          .toList();
      for (final kotItem in filteredItems) {
        final startTime = kotItem.startedPreparingAt ?? kotItem.createdAt;
        final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
        final slaSeconds = kotItem.slaSeconds;

        if (elapsedSeconds > slaSeconds) {
          final exceededBy = elapsedSeconds - slaSeconds;

          // Determine alert type
          DelayAlertType alertType;
          if (exceededBy > slaSeconds * 0.5) {
            alertType = DelayAlertType.urgent;
          } else if (exceededBy > slaSeconds * 0.25) {
            alertType = DelayAlertType.critical;
          } else {
            alertType = DelayAlertType.warning;
          }

          // Check if alert already exists
          final existing = await supabase
              .from('kot_delay_alerts')
              .select()
              .eq('item_id', kotItem.id)
              .eq('is_resolved', false);

          if ((existing as List).isEmpty) {
            // Create alert
            final alertId = uuid.v4();
            final alertData = {
              'id': alertId,
              'kot_id': kotItem.kotId,
              'item_id': kotItem.id,
              'business_id': businessId,
              'kitchen_id': kotItem.assignedKitchenId,
              'alert_type': alertType.toString().split('.').last,
              'sla_deadline': startTime
                  .add(Duration(seconds: slaSeconds))
                  .toIso8601String(),
              'exceeded_by_seconds': exceededBy,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };

            await supabase.from('kot_delay_alerts').insert(alertData);

            final alert = KOTDelayAlert.fromJson(alertData);
            alerts.add(alert);
            _notifyDelayDetected(alert);
          }
        }
      }

      return alerts;
    } catch (e) {
      debugPrint('❌ Error detecting delays: $e');
      return [];
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 6. GET KOT METHODS
  // ═════════════════════════════════════════════════════════════════════════════════

  /// Get complete KOT with all batches and items
  Future<KOTOrder?> getKOT({
    required String kotId,
    required String businessId,
  }) async {
    try {
      // Check cache first
      if (_kotCache.containsKey(kotId)) {
        return _kotCache[kotId];
      }

      // Fetch from database
      final kotResponse = await supabase
          .from('kot_orders')
          .select()
          .eq('id', kotId)
          .eq('business_id', businessId)
          .single();

      final kot = KOTOrder.fromJson(kotResponse);

      // Fetch batches
      final batchesResponse = await supabase
          .from('kot_item_batches')
          .select()
          .eq('kot_id', kotId)
          .order('batch_number');

      final batches = <KOTBatch>[];
      for (final batchData in batchesResponse) {
        // Fetch items for this batch
        final itemsResponse = await supabase
            .from('kot_items')
            .select()
            .eq('batch_id', batchData['id']);

        final items = (itemsResponse as List)
            .map((i) => KOTItem.fromJson(i))
            .toList();

        final batch = KOTBatch.fromJson(batchData);
        batches.add(batch.copyWith(items: items));
      }

      final kotWithBatches = kot.copyWith(batches: batches);

      // Cache
      _kotCache[kotId] = kotWithBatches;

      return kotWithBatches;
    } catch (e) {
      debugPrint('❌ Error getting KOT: $e');
      return null;
    }
  }

  /// Get all active KOTs for a kitchen
  Future<List<KOTOrder>> getActiveKOTsForKitchen({
    required String businessId,
    required String kitchenId,
  }) async {
    try {
      // Validate businessId
      if (businessId.isEmpty) {
        return [];
      }

      // Validate kitchenId - handle "all" or empty
      if (kitchenId.isEmpty || kitchenId.toLowerCase() == 'all') {
        // Get all active KOTs for the business (any kitchen)
        final response = await supabase
            .from('kot_orders')
            .select()
            .eq('business_id', businessId);

        final allOrders = (response as List)
            .map((k) => KOTOrder.fromJson(k))
            .toList();
        return allOrders
            .where(
              (k) =>
                  k.status == KOTOrderStatus.pending ||
                  k.status == KOTOrderStatus.inProgress ||
                  k.status == KOTOrderStatus.ready,
            )
            .toList();
      }

      // If kitchenId is provided and not "all", query specific kitchen
      final response = await supabase
          .from('kot_orders')
          .select()
          .eq('business_id', businessId)
          .eq('primary_kitchen_id', kitchenId);

      // Filter statuses client-side
      final allOrders = (response as List)
          .map((k) => KOTOrder.fromJson(k))
          .toList();
      return allOrders
          .where(
            (k) =>
                k.status == KOTOrderStatus.pending ||
                k.status == KOTOrderStatus.inProgress ||
                k.status == KOTOrderStatus.ready,
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting active KOTs: $e');
      return [];
    }
  }

  /// Get batch details
  Future<KOTBatch?> getBatch({
    required String batchId,
    required String businessId,
  }) async {
    try {
      final response = await supabase
          .from('v_batch_summary')
          .select()
          .eq('id', batchId)
          .eq('business_id', businessId)
          .single();

      return KOTBatch.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error getting batch: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 7. CALLBACK MANAGEMENT
  // ═════════════════════════════════════════════════════════════════════════════════

  void onKOTUpdated(OnKOTUpdated callback) {
    _kotUpdatedCallbacks.add(callback);
  }

  void onItemStatusChanged(OnItemStatusChanged callback) {
    _itemStatusCallbacks.add(callback);
  }

  void onBatchAdded(OnBatchAdded callback) {
    _batchAddedCallbacks.add(callback);
  }

  void onDelayDetected(OnDelayDetected callback) {
    _delayCallbacks.add(callback);
  }

  void _notifyItemStatusChanged(KOTItem item) {
    for (final callback in _itemStatusCallbacks) {
      callback(item);
    }
  }

  void _notifyBatchAdded(KOTBatch batch) {
    for (final callback in _batchAddedCallbacks) {
      callback(batch);
    }
  }

  void _notifyDelayDetected(KOTDelayAlert alert) {
    for (final callback in _delayCallbacks) {
      callback(alert);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 8. AUDIT LOGGING
  // ═════════════════════════════════════════════════════════════════════════════════

  Future<void> _logAuditEvent({
    required String businessId,
    String? kotId,
    required String action,
    String? details,
    String? userId,
    String? userName,
  }) async {
    try {
      const uuid = Uuid();
      final logData = {
        'id': uuid.v4(),
        'kot_id': kotId,
        'business_id': businessId,
        'action': action,
        'details': details,
        'user_id': userId,
        'user_name': userName,
        'device_id': null, // Set from platform
        'action_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('kot_audit_logs').insert(logData);
    } catch (e) {
      debugPrint('⚠️ Error logging audit event: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════════
  // 9. CLEAR CACHE
  // ═════════════════════════════════════════════════════════════════════════════════

  void clearCache() {
    _kotCache.clear();
    _batchCache.clear();
  }

  void clearKOTCache(String kotId) {
    _kotCache.remove(kotId);
  }
}
