// 🔥 KITCHEN ROUTING & SEGMENTATION SERVICE
// Multi-Kitchen Order Routing Engine
// Path: lib/services/kitchen_routing_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart' show Uuid;

typedef OnItemRouted = void Function(String itemId, String kitchenId);
typedef OnKitchenAssigned =
    void Function(String orderId, List<String> kitchenIds);

// ═══════════════════════════════════════════════════════════════════════════════
// KITCHEN ROUTING SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class KitchenRoutingService {
  static final KitchenRoutingService _instance =
      KitchenRoutingService._internal();

  factory KitchenRoutingService() => _instance;

  KitchenRoutingService._internal();

  final supabase = Supabase.instance.client;

  // Caching
  final _routingRulesCache = <String, List<KitchenRoutingRule>>{};
  final _orderKitchensCache =
      <String, Set<String>>{}; // orderId -> Set<kitchenId>

  // Callbacks
  final _itemRoutedCallbacks = <OnItemRouted>[];
  final _kitchenAssignedCallbacks = <OnKitchenAssigned>[];

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. Setup Kitchen Routing Rules
  // ═════════════════════════════════════════════════════════════════════════════

  /// Create kitchen routing rule
  Future<void> createRoutingRule({
    required String businessId,
    required String kitchenId,
    required String kitchenName,
    required String matchType, // 'category', 'keyword', 'supplier'
    required String matchValue,
    int priority = 1,
  }) async {
    try {
      final uuid = Uuid();

      await supabase.from('kitchen_routing_rules').insert({
        'id': uuid.v4(),
        'business_id': businessId,
        'kitchen_id': kitchenId,
        'kitchen_name': kitchenName,
        'match_type': matchType,
        'match_value': matchValue,
        'rule_priority': priority,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Clear cache
      _routingRulesCache.remove(businessId);

      debugPrint('✅ Routing rule created: $matchType=$matchValue → $kitchenId');
    } catch (e) {
      debugPrint('❌ Error creating routing rule: $e');
      rethrow;
    }
  }

  /// Get all active routing rules for business
  Future<List<KitchenRoutingRule>> getRoutingRules(String businessId) async {
    try {
      // Check cache first
      if (_routingRulesCache.containsKey(businessId)) {
        return _routingRulesCache[businessId]!;
      }

      final response = await supabase
          .from('kitchen_routing_rules')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('rule_priority', ascending: false);

      final rules = (response as List)
          .map((r) => KitchenRoutingRule.fromJson(r))
          .toList();

      _routingRulesCache[businessId] = rules;
      return rules;
    } catch (e) {
      debugPrint('❌ Error getting routing rules: $e');
      return [];
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. Route Items to Kitchens
  // ═════════════════════════════════════════════════════════════════════════════

  /// Route individual item to kitchen
  Future<String> routeItemToKitchen({
    required String orderId,
    required String orderItemId,
    required String itemName,
    required String? categoryName,
    required String businessId,
  }) async {
    try {
      // Get routing rules
      final rules = await getRoutingRules(businessId);

      String assignedKitchen = 'default_kitchen';

      // Find matching rule
      for (final rule in rules) {
        bool matches = false;

        if (rule.matchType == 'category' && categoryName == rule.matchValue) {
          matches = true;
        } else if (rule.matchType == 'keyword' &&
            itemName.toLowerCase().contains(rule.matchValue.toLowerCase())) {
          matches = true;
        }

        if (matches) {
          assignedKitchen = rule.kitchenId;
          break;
        }
      }

      // Track kitchen for order
      if (!_orderKitchensCache.containsKey(orderId)) {
        _orderKitchensCache[orderId] = {};
      }
      _orderKitchensCache[orderId]!.add(assignedKitchen);

      // Notify item routed
      for (final callback in _itemRoutedCallbacks) {
        callback(orderItemId, assignedKitchen);
      }

      debugPrint(
        '📍 Item routed: $itemName ($categoryName) → $assignedKitchen',
      );

      return assignedKitchen;
    } catch (e) {
      debugPrint('❌ Error routing item: $e');
      return 'default_kitchen';
    }
  }

  /// Route all items in an order to kitchens
  Future<Map<String, List<String>>> routeOrderItems({
    required String orderId,
    required String businessId,
    required List<OrderItemForRouting> items,
  }) async {
    try {
      final routing = <String, List<String>>{};

      for (final item in items) {
        final kitchenId = await routeItemToKitchen(
          orderId: orderId,
          orderItemId: item.id,
          itemName: item.name,
          categoryName: item.category,
          businessId: businessId,
        );

        routing.putIfAbsent(kitchenId, () => []).add(item.id);
      }

      // Notify kitchens assigned
      final kitchens = routing.keys.toList();
      for (final callback in _kitchenAssignedCallbacks) {
        callback(orderId, kitchens);
      }

      debugPrint('🏢 Order routed to ${kitchens.length} kitchens: $kitchens');

      return routing;
    } catch (e) {
      debugPrint('❌ Error routing order items: $e');
      return {};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 3. Kitchen-Level Item Tracking
  // ═════════════════════════════════════════════════════════════════════════════

  /// Get all items assigned to a kitchen for a specific order
  Future<List<KitchenItem>> getKitchenItems({
    required String businessId,
    required String kitchenId,
    required String? orderId,
    bool onlyActive = true,
  }) async {
    try {
      var query = supabase
          .from('order_item_kitchen_map')
          .select('''
            id,
            order_item_id,
            kot_item_id,
            order_id,
            kitchen_id,
            created_at,
            order_items:order_item_id (
              id,
              item_name,
              quantity,
              subtotal,
              notes
            ),
            kot_items:kot_item_id (
              id,
              status,
              started_preparing_at,
              ready_at
            )
          ''')
          .eq('business_id', businessId)
          .eq('kitchen_id', kitchenId);

      if (orderId != null) {
        query = query.eq('order_id', orderId);
      }

      final response = await query;

      final items = (response as List)
          .map((r) => KitchenItem.fromJson(r))
          .toList();

      if (onlyActive) {
        return items.where((item) => item.kotStatus != 'completed').toList();
      }

      return items;
    } catch (e) {
      debugPrint('❌ Error getting kitchen items: $e');
      return [];
    }
  }

  /// Get summary of kitchens for an order
  Future<Map<String, KitchenSummary>> getOrderKitchensSummary({
    required String orderId,
    required String businessId,
  }) async {
    try {
      final response = await supabase
          .from('order_item_kitchen_map')
          .select('kitchen_id')
          .eq('order_id', orderId)
          .eq('business_id', businessId);

      final kitchens = <String>{};
      for (final row in response as List) {
        kitchens.add(row['kitchen_id'] as String);
      }

      final summary = <String, KitchenSummary>{};

      for (final kitchenId in kitchens) {
        final items = await getKitchenItems(
          businessId: businessId,
          kitchenId: kitchenId,
          orderId: orderId,
          onlyActive: false,
        );

        final total = items.length;
        final completed = items.where((i) => i.kotStatus == 'completed').length;
        final ready = items.where((i) => i.kotStatus == 'ready').length;
        final preparing = items.where((i) => i.kotStatus == 'preparing').length;

        summary[kitchenId] = KitchenSummary(
          kitchenId: kitchenId,
          orderId: orderId,
          totalItems: total,
          completedItems: completed,
          readyItems: ready,
          preparingItems: preparing,
          completionPercentage: total > 0
              ? (completed / total * 100).toInt()
              : 0,
        );
      }

      return summary;
    } catch (e) {
      debugPrint('❌ Error getting kitchen summary: $e');
      return {};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 4. Callbacks
  // ═════════════════════════════════════════════════════════════════════════════

  void onItemRouted(OnItemRouted callback) {
    _itemRoutedCallbacks.add(callback);
  }

  void onKitchenAssigned(OnKitchenAssigned callback) {
    _kitchenAssignedCallbacks.add(callback);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 5. Cache Management
  // ═════════════════════════════════════════════════════════════════════════════

  void clearCache() {
    _routingRulesCache.clear();
    _orderKitchensCache.clear();
  }

  void invalidateRulesCache(String businessId) {
    _routingRulesCache.remove(businessId);
  }

  Set<String> getOrderKitchens(String orderId) =>
      _orderKitchensCache[orderId] ?? {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class KitchenRoutingRule {
  final String id;
  final String businessId;
  final String kitchenId;
  final String kitchenName;
  final int priority;
  final String matchType; // 'category', 'keyword', 'supplier'
  final String matchValue;
  final bool isActive;
  final DateTime createdAt;

  KitchenRoutingRule({
    required this.id,
    required this.businessId,
    required this.kitchenId,
    required this.kitchenName,
    required this.priority,
    required this.matchType,
    required this.matchValue,
    required this.isActive,
    required this.createdAt,
  });

  factory KitchenRoutingRule.fromJson(Map<String, dynamic> json) =>
      KitchenRoutingRule(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        kitchenId: json['kitchen_id'] as String,
        kitchenName: json['kitchen_name'] as String? ?? 'Unknown',
        priority: json['rule_priority'] as int? ?? 1,
        matchType: json['match_type'] as String,
        matchValue: json['match_value'] as String,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  String toString() => 'Rule($matchType=$matchValue → $kitchenName)';
}

class OrderItemForRouting {
  final String id;
  final String name;
  final String? category;
  final int quantity;

  OrderItemForRouting({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
  });
}

class KitchenItem {
  final String id;
  final String orderItemId;
  final String kotItemId;
  final String kitchenId;
  final String itemName;
  final int quantity;
  final String kotStatus;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final String? notes;

  KitchenItem({
    required this.id,
    required this.orderItemId,
    required this.kotItemId,
    required this.kitchenId,
    required this.itemName,
    required this.quantity,
    required this.kotStatus,
    required this.startedAt,
    required this.readyAt,
    required this.notes,
  });

  factory KitchenItem.fromJson(Map<String, dynamic> json) {
    final orderItemData = (json['order_items'] as Map<String, dynamic>?) ?? {};
    final kotItemData = (json['kot_items'] as Map<String, dynamic>?) ?? {};

    return KitchenItem(
      id: json['id'] as String,
      orderItemId: json['order_item_id'] as String,
      kotItemId: json['kot_item_id'] as String,
      kitchenId: json['kitchen_id'] as String,
      itemName: orderItemData['item_name'] as String? ?? 'Unknown',
      quantity: orderItemData['quantity'] as int? ?? 1,
      kotStatus: kotItemData['status'] as String? ?? 'pending',
      startedAt: kotItemData['started_preparing_at'] != null
          ? DateTime.parse(kotItemData['started_preparing_at'] as String)
          : null,
      readyAt: kotItemData['ready_at'] != null
          ? DateTime.parse(kotItemData['ready_at'] as String)
          : null,
      notes: orderItemData['notes'] as String?,
    );
  }

  int get preparationTimeSeconds {
    if (startedAt == null) return 0;
    final endTime = readyAt ?? DateTime.now();
    return endTime.difference(startedAt!).inSeconds;
  }

  @override
  String toString() => 'KitchenItem($itemName x$quantity, status:$kotStatus)';
}

class KitchenSummary {
  final String kitchenId;
  final String orderId;
  final int totalItems;
  final int completedItems;
  final int readyItems;
  final int preparingItems;
  final int completionPercentage;

  KitchenSummary({
    required this.kitchenId,
    required this.orderId,
    required this.totalItems,
    required this.completedItems,
    required this.readyItems,
    required this.preparingItems,
    required this.completionPercentage,
  });

  int get pendingItems =>
      totalItems - completedItems - readyItems - preparingItems;

  bool get isComplete => completionPercentage == 100;

  @override
  String toString() =>
      'Kitchen($kitchenId): $completedItems/$totalItems complete ($completionPercentage%)';
}
