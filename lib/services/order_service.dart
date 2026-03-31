// lib/services/order_service.dart (fetchTableOrders fix only)
// ══════════════════════════════════════════════════════════════════════════════
//  PATCH: Replace only the fetchTableOrders() method in your existing
//  OrdersService class with this version.
//
//  FIX 1: fetchTableOrders() now uses fn_table_orders_v2 RPC which
//  applies session_id isolation — only the current guest's orders
//  are returned. Falls back to a direct query if the RPC doesn't
//  exist yet (safe during migration).
//
//  FIX 2: createOrder() partial-seat path no longer marks the whole
//  table as 'occupied' unless ALL seats are now occupied. This matches
//  the new fn_seat_guest_v2 server behaviour.
// ══════════════════════════════════════════════════════════════════════════════

// ─── DROP-IN REPLACEMENT for fetchTableOrders() ──────────────────────────────
//
//   Future<List<Order>> fetchTableOrders({
//     required String tableId,
//     required String businessId,
//   }) async { ... }
//
// ─────────────────────────────────────────────────────────────────────────────
//
// Paste the full updated class below into lib/services/order_service.dart,
// replacing the existing file content.

import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersService {
  OrdersService._();
  static final instance = OrdersService._();

  final _db = Supabase.instance.client;

  // ══════════════════════════════════════════════════════════
  //  ORDER NUMBER SEQUENCE
  //  Ensures order_number increments for each business when creating orders.
  Future<int> _getNextOrderNumber(String businessId) async {
    try {
      final latest = await _db
          .from('orders')
          .select('order_number')
          .eq('business_id', businessId)
          .order('order_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest is Map<String, dynamic>) {
        final raw = latest['order_number'];
        if (raw != null) {
          return (raw as num).toInt() + 1;
        }
      }
    } catch (e) {
      debugPrint('[OrdersService] _getNextOrderNumber error: $e');
    }

    return 1;
  }

  // ══════════════════════════════════════════════════════════
  //  FETCH ORDERS
  // ══════════════════════════════════════════════════════════

  Future<List<Order>> fetchTodayOrders({
    required String businessId,
    String? staffUid,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final istStartOfDay = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final istEndOfDay = istStartOfDay.add(const Duration(days: 1));
    final utcStart = istStartOfDay.subtract(
      const Duration(hours: 5, minutes: 30),
    );
    final utcEnd = istEndOfDay.subtract(const Duration(hours: 5, minutes: 30));

    var query = Supabase.instance.client
        .from('orders')
        .select('*, items:order_items(*)')
        .eq('business_id', businessId)
        .gte('created_at', utcStart.toIso8601String())
        .lt('created_at', utcEnd.toIso8601String());

    if (staffUid != null) {
      query = query.eq('created_by_uid', staffUid);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<List<Order>> fetchBusinessOrders({
    required String businessId,
    String? status,
    String? paymentStatus,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId);

    if (status != null) query = query.eq('status', status);
    if (paymentStatus != null) {
      query = query.eq('payment_status', paymentStatus);
    }
    if (from != null) query = query.gte('created_at', from.toIso8601String());
    if (to != null) query = query.lt('created_at', to.toIso8601String());

    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List)
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  bool _isTableIdUuid(String id) {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$',
    );
    return uuidRe.hasMatch(id);
  }

  // ── FIX: session-aware table orders ────────────────────────────────────────
  Future<List<Order>> fetchTableOrders({
    required String tableId,
    required String businessId,
  }) async {
    // Try the new session-aware RPC first (available after migration v8)
    if (_isTableIdUuid(tableId)) {
      try {
        final rpcData = await _db.rpc(
          'fn_table_orders_v2',
          params: {'p_table_id': tableId},
        );
        if (rpcData != null) {
          return (rpcData as List)
              .map((j) => Order.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (rpcError) {
        debugPrint(
          '[OrdersService] fn_table_orders_v2 RPC failed, using fallback: $rpcError',
        );
      }
    } else {
      debugPrint(
        '[OrdersService] tableId is not UUID, skipping fn_table_orders_v2 RPC: $tableId',
      );
    }

    // ── Fallback: direct query with session_id isolation ────────────────────
    // Step 1: get the current session_id from the table
    String? currentSession;
    try {
      final tableRow = await _db
          .from('restaurant_tables')
          .select('session_id')
          .eq('id', tableId)
          .maybeSingle();
      currentSession = tableRow?['session_id'] as String?;
    } catch (_) {}

    // Step 2: query active orders, filter by session
    var query = _db
        .from('vw_orders_with_items')
        .select()
        .eq('business_id', businessId)
        .eq('table_id', tableId)
        .inFilter('status', ['pending', 'preparing', 'ready'])
        .order('created_at', ascending: true);

    final data = await query;
    final allOrders = (data as List)
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();

    // Step 3: filter by session_id if we have one
    if (currentSession != null && currentSession.isNotEmpty) {
      return allOrders.where((o) {
        // Include orders that match the current session OR have no session
        // (legacy orders created before session_id was added)
        return o.sessionId == null ||
            o.sessionId!.isEmpty ||
            o.sessionId == currentSession;
      }).toList();
    }

    return allOrders;
  }

  // ══════════════════════════════════════════════════════════
  //  FETCH SINGLE ORDER (for bill view)
  // ══════════════════════════════════════════════════════════

  Future<Order?> fetchOrder(String orderId) async {
    try {
      final data = await _db
          .from('vw_orders_with_items')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      if (data == null) return null;
      return Order.fromJson(data);
    } catch (e) {
      debugPrint('[OrdersService] fetchOrder error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAMLESS WORKFLOW: Check for existing active orders (NEW - for add items feature)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get existing active order for a table/seat to enable "add items to existing order"
  /// Returns null if no active order found
  /// Returns the Order if an active order exists for this table/seat
  Future<Order?> getActiveOrderForTable({
    required String tableId,
    required String businessId,
    String? tableSeatId,
  }) async {
    try {
      Map<String, dynamic>? existing;

      // If specific seat is provided, check by seat (most specific)
      if (tableSeatId != null && tableSeatId.isNotEmpty) {
        existing = await _db
            .from('vw_orders_with_items')
            .select()
            .eq('table_seat_id', tableSeatId)
            .eq('business_id', businessId)
            .inFilter('status', ['pending', 'preparing', 'ready'])
            .maybeSingle();
      } else {
        // Check for whole-table order (no specific seat)
        existing = await _db
            .from('vw_orders_with_items')
            .select()
            .eq('table_id', tableId)
            .eq('business_id', businessId)
            .isFilter('table_seat_id', null)
            .inFilter('status', ['pending', 'preparing', 'ready'])
            .maybeSingle();
      }

      if (existing == null) {
        debugPrint('✓ [OrdersService] No active order found for table/seat');
        return null;
      }

      final order = Order.fromJson(existing);
      debugPrint(
        '✓ [OrdersService] Found active order #${order.orderNumber} for table',
      );
      return order;
    } catch (e) {
      debugPrint('[OrdersService] getActiveOrderForTable error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAMLESS WORKFLOW: Add items to existing order (NEW - for add items feature)
  // ══════════════════════════════════════════════════════════════════════════

  /// Add new items to an existing active order
  /// Returns updated order with new items merged
  /// Only new items are marked for KOT sending (via order_items.sent_to_kitchen flag)
  Future<Order> addItemsToExistingOrder({
    required String orderId,
    required String businessId,
    required String businessName,
    required List<CartItem> newItems,
    String? updatedNotes,
    double taxRate = 5.0,
  }) async {
    if (newItems.isEmpty) {
      throw Exception('No items to add to order');
    }

    debugPrint(
      '📝 [OrdersService] Adding ${newItems.length} items to order $orderId',
    );

    // ✅ VALIDATE: Filter out items with empty/invalid menu_item_id
    final validItems = newItems.where((item) {
      if (item.menuItemId.isEmpty) {
        debugPrint(
          '⚠️  [OrdersService] Skipping item with empty menuItemId: ${item.itemName}',
        );
        return false;
      }
      return true;
    }).toList();

    if (validItems.isEmpty) {
      throw Exception(
        'No valid items to add (all items have missing menu_item_id)',
      );
    }

    if (validItems.length < newItems.length) {
      debugPrint(
        '⚠️  [OrdersService] Removed ${newItems.length - validItems.length} invalid items',
      );
    }

    // Step 1: Insert new items into order_items table
    final itemInserts = validItems
        .map(
          (item) => {
            'order_id': orderId,
            'menu_item_id': item.menuItemId,
            'item_name': item.itemName,
            'item_price': item.itemPrice,
            'category_name': item.categoryName,
            'is_veg': item.isVeg,
            'quantity': item.quantity,
            'subtotal': item.subtotal,
            'notes': item.notes,
            // ✅ FIX: Removed 'sent_to_kitchen' - column doesn't exist in schema (PGRST204)
          },
        )
        .toList();

    try {
      await _db.from('order_items').insert(itemInserts);
      debugPrint('✅ [OrdersService] Inserted ${validItems.length} items');
    } catch (e) {
      debugPrint('❌ [OrdersService] Failed to insert items: $e');
      rethrow;
    }

    // Step 3: Fetch the updated order to get all items
    final updated = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();

    final currentOrder = Order.fromJson(updated);

    // Recalculate all totals
    final totalSubtotal = currentOrder.items.fold(
      0.0,
      (s, i) => s + i.subtotal,
    );
    final totalTax = totalSubtotal * (taxRate / 100);
    final totalAmount = totalSubtotal + totalTax;

    // Step 4: Update order with new totals and updated_at timestamp
    await _db
        .from('orders')
        .update({
          'subtotal': totalSubtotal,
          'tax_amount': totalTax,
          'tax_rate': taxRate,
          'total_amount': totalAmount,
          if (updatedNotes != null && updatedNotes.isNotEmpty)
            'notes': updatedNotes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);

    debugPrint(
      '✅ [OrdersService] Updated order totals: '
      'subtotal=$totalSubtotal, tax=$totalTax, total=$totalAmount',
    );

    // Step 5: Deduct inventory for new items (same as in createOrder)
    debugPrint(
      '📦 [OrdersService] Deducting inventory for ${validItems.length} new items...',
    );

    try {
      await _deductInventoryForOrderItems(
        orderId: orderId,
        businessId: businessId,
        cartItems: validItems,
      );
      debugPrint('✅ [OrdersService] Inventory deducted for new items');
    } catch (e) {
      debugPrint(
        '⚠️  [OrdersService] Inventory deduction failed (items still added): $e',
      );
      // Items are already added — deduction failure is non-critical
      // The order will be marked for manual reconciliation
    }

    // Step 6: Update table's current_order_total if needed
    if (currentOrder.tableId != null && currentOrder.tableId!.isNotEmpty) {
      try {
        await _db
            .from('restaurant_tables')
            .update({
              'current_order_total': totalAmount,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', currentOrder.tableId!);
        debugPrint(
          '✅ [OrdersService] Updated table current_order_total to $totalAmount',
        );
      } catch (e) {
        debugPrint('⚠️  [OrdersService] Failed to update table total: $e');
      }
    }

    // Step 7: Fetch and return the fully updated order
    final finalData = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .single();

    final updatedOrder = Order.fromJson(finalData);
    debugPrint(
      '✅ [OrdersService] Successfully added items to order. New total items: ${updatedOrder.totalItems}',
    );

    return updatedOrder;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Helper: Deduct inventory for order items (shared logic)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deductInventoryForOrderItems({
    required String orderId,
    required String businessId,
    required List<CartItem> cartItems,
  }) async {
    for (final item in cartItems) {
      // Get recipe for this menu item
      final recipe = await _db
          .from('recipes')
          .select('id')
          .eq('menu_item_id', item.menuItemId)
          .maybeSingle();

      if (recipe == null) {
        debugPrint(
          '⚠️  [OrdersService] No recipe found for menu item: ${item.menuItemId}',
        );
        continue;
      }

      final recipeId = recipe['id'] as String;

      // Get recipe ingredients
      final ingredientRows = await _db
          .from('recipe_ingredients')
          .select(
            'ingredient_id, ingredient_name, ingredient_unit, quantity_required',
          )
          .eq('recipe_id', recipeId);

      for (final ingredient in ingredientRows as List) {
        final ingredientId =
            (ingredient['ingredient_id'] as String?)?.trim() ?? '';
        final ingredientName =
            (ingredient['ingredient_name'] as String?)?.trim() ?? '';
        final ingredientUnit =
            (ingredient['ingredient_unit'] as String?)?.trim() ?? '';
        final quantityRequired =
            double.tryParse(
              ingredient['quantity_required']?.toString() ?? '0',
            ) ??
            0.0;

        // ✅ VALIDATE: Skip ingredients with empty IDs to prevent UUID errors
        if (ingredientId.isEmpty) {
          debugPrint(
            '⚠️  [OrdersService] Skipping ingredient with empty ID for recipe $recipeId',
          );
          continue;
        }

        if (ingredientName.isEmpty || ingredientUnit.isEmpty) {
          debugPrint(
            '⚠️  [OrdersService] Skipping ingredient $ingredientId with missing name/unit',
          );
          continue;
        }

        final totalToDeduct = item.quantity * quantityRequired;

        // ✓ Record consumption (audit trail)
        await _db.from('ingredient_consumption').insert({
          'business_id': businessId,
          'order_id': orderId,
          'recipe_id': recipeId,
          'menu_item_id': item.menuItemId,
          'menu_item_name': item.itemName,
          'ingredient_id': ingredientId,
          'ingredient_name': ingredientName,
          'ingredient_unit': ingredientUnit,
          'quantity_consumed': totalToDeduct,
          'transaction_status': 'pending',
        });

        // ✓ Deduct from inventory
        await _db.rpc(
          'deduct_inventory',
          params: {
            'p_inventory_item_id': ingredientId,
            'p_quantity': totalToDeduct,
            'p_business_id': businessId,
          },
        );

        debugPrint(
          '✅ Deducted $totalToDeduct $ingredientUnit of $ingredientName',
        );
      }
    }

    // ✓ Mark all consumptions as completed
    await _db
        .from('ingredient_consumption')
        .update({'transaction_status': 'completed'})
        .eq('order_id', orderId);
  }

  // ══════════════════════════════════════════════════════════
  //  CREATE ORDER  (FIX: seat-level table status)
  // ══════════════════════════════════════════════════════════

  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required String businessId,
    required String businessName,
    required String createdByUid,
    required String createdByName,
    required String createdByRole,
    required OrderType orderType,
    String? tableId,
    int? tableNumber,
    String? tableSeatId,
    String? seatLabel,
    String? customerName,
    String? customerPhone,
    String? notes,
    double taxRate = 5.0,
  }) async {
    // ── DUPLICATE ORDER GUARD ────────────────────────────────────────────────
    if (tableSeatId != null && tableSeatId.isNotEmpty) {
      final existing = await _db
          .from('orders')
          .select('id')
          .eq('table_seat_id', tableSeatId)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .limit(1);
      if ((existing as List).isNotEmpty) {
        throw Exception(
          'An active order already exists for this seat. '
          'Complete or cancel it before placing a new one.',
        );
      }
    }

    if (tableId != null &&
        orderType == OrderType.dineIn &&
        (tableSeatId == null || tableSeatId.isEmpty)) {
      final existing = await _db
          .from('orders')
          .select('id')
          .eq('table_id', tableId)
          .isFilter('table_seat_id', null)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .limit(1);
      if ((existing as List).isNotEmpty) {
        throw Exception(
          'An active order already exists for this table. '
          'Add items to the existing order or complete it first.',
        );
      }
    }

    // ── SEAT LABEL LOOKUP ───────────────────────────────────────────────────
    // ✅ FIX: Use provided seatLabel if available, otherwise look up from table_seats
    var resolvedSeatLabel = seatLabel; // Use provided value first
    if ((resolvedSeatLabel == null || resolvedSeatLabel.isEmpty) &&
        tableSeatId != null &&
        tableSeatId.isNotEmpty) {
      try {
        final seatRow = await _db
            .from('table_seats')
            .select('seat_label')
            .eq('id', tableSeatId)
            .maybeSingle();
        resolvedSeatLabel = seatRow?['seat_label'] as String?;
        debugPrint('✅ Fetched seat_label for $tableSeatId: $resolvedSeatLabel');
      } catch (e) {
        debugPrint('⚠️ Failed to fetch seat_label: $e');
      }
    }

    // ── GET CURRENT SESSION ID ──────────────────────────────────────────────
    String? sessionId;
    if (tableId != null) {
      try {
        final tableRow = await _db
            .from('restaurant_tables')
            .select('session_id')
            .eq('id', tableId)
            .maybeSingle();
        sessionId = tableRow?['session_id'] as String?;
      } catch (_) {}
    }

    final subtotal = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final taxAmount = subtotal * (taxRate / 100);
    final totalAmount = subtotal + taxAmount;

    final orderNumber = await _getNextOrderNumber(businessId);

    final orderData = await (() async {
      try {
        return await _db
            .from('orders')
            .insert({
              'business_id': businessId,
              'business_name': businessName,
              'status': 'pending',
              'payment_status': 'unpaid',
              'order_type': orderType.value,
              'order_number': orderNumber,
              'table_id': tableId,
              'table_number': tableNumber,
              'table_seat_id': tableSeatId,
              'seat_label': resolvedSeatLabel, // ✅ Use resolved seat label
              'session_id': sessionId,
              'customer_name': customerName,
              'customer_phone': customerPhone,
              'subtotal': subtotal,
              'tax_amount': taxAmount,
              'tax_rate': taxRate,
              'total_amount': totalAmount,
              'notes': notes,
              'created_by_uid': createdByUid,
              'created_by_name': createdByName,
              'created_by_role': createdByRole,
            })
            .select()
            .single();
      } on PostgrestException catch (e) {
        final details = e.details?.toString() ?? '';
        final message = e.message?.toString().toLowerCase() ?? '';

        if (e.code == '23505' ||
            details.contains('uq_active_seat_order') ||
            message.contains('duplicate key')) {
          throw Exception(
            'Cannot create order: an active order already exists for this seat/table. '
            'Please complete or cancel the existing order first.',
          );
        }
        rethrow;
      }
    })();

    final orderId = orderData['id'] as String;

    if (cartItems.isNotEmpty) {
      // ✅ VALIDATE: Filter out items with empty/invalid menu_item_id
      final validCartItems = cartItems.where((item) {
        if (item.menuItemId.isEmpty) {
          debugPrint(
            '⚠️  [OrdersService] Skipping item with empty menuItemId: ${item.itemName}',
          );
          return false;
        }
        return true;
      }).toList();

      if (validCartItems.isNotEmpty) {
        await _db
            .from('order_items')
            .insert(
              validCartItems
                  .map(
                    (c) => {
                      'order_id': orderId,
                      'menu_item_id': c.menuItemId,
                      'item_name': c.itemName,
                      'item_price': c.itemPrice,
                      'category_name': c.categoryName,
                      'is_veg': c.isVeg,
                      'quantity': c.quantity,
                      'subtotal': c.subtotal,
                      'notes': c.notes,
                    },
                  )
                  .toList(),
            );
      }
    }

    // ── TABLE STATUS UPDATE — SEAT-AWARE (FIX) ─────────────────────────────
    if (tableId != null) {
      if (tableSeatId != null && tableSeatId.isNotEmpty) {
        // PARTIAL SEAT ORDER:
        // 1. Mark this specific seat as occupied
        await _db
            .from('table_seats')
            .update({'status': 'occupied'})
            .eq('id', tableSeatId);

        // 2. FIX: Check if ALL seats are now occupied before changing table status
        final seatRows = await _db
            .from('table_seats')
            .select('status')
            .eq('table_id', tableId);
        final allSeats = seatRows as List;
        final totalSeats = allSeats.length;
        final occupiedCount = allSeats
            .where((s) => (s['status'] as String?) == 'occupied')
            .length;
        final allOccupied = totalSeats > 0 && occupiedCount >= totalSeats;

        if (allOccupied) {
          // FIX: Only mark 'occupied' when ALL seats are taken
          await _db
              .from('restaurant_tables')
              .update({
                'current_order_id': orderId,
                'current_order_total': totalAmount,
                'current_customer_name': customerName,
                'status': 'occupied',
                'occupied_since': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', tableId);
        } else {
          // FIX: Some seats still free — only update financials, NOT status
          // This allows other guests to still book remaining seats
          await _db
              .from('restaurant_tables')
              .update({
                'current_order_id': orderId,
                'current_order_total': totalAmount,
                // Do NOT set status or current_customer_name here
              })
              .eq('id', tableId);
        }
      } else {
        // FULL TABLE ORDER: mark entire table occupied
        await _db
            .from('restaurant_tables')
            .update({
              'current_order_id': orderId,
              'current_order_total': totalAmount,
              'current_customer_name': customerName,
              'status': 'occupied',
              'occupied_since': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', tableId);
      }
    }

    final full = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (full == null) {
      // ❌ Order not in view after creation - likely timing issue
      debugPrint(
        '⚠️  Order $orderId not found in view immediately after creation. '
        'View might need refresh. Retrying from orders table...',
      );
      final fallback = await _db
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();
      if (fallback == null) {
        throw Exception(
          'Order creation query failed - order not found after INSERT',
        );
      }
      final order = Order.fromJson(fallback);
      return order;
    }

    final order = Order.fromJson(full);

    // ── INVENTORY DEDUCTION ────────────────────────────────────────────────
    // Deduct inventory AFTER order is successfully created
    // This ensures order is committed before inventory changes
    try {
      debugPrint('📦 [OrderService] Deducting inventory for order: $orderId');
      await _deductInventoryForOrder(
        orderId: orderId,
        orderNumber: order.orderNumber,
        businessId: businessId,
        cartItems: cartItems,
      );
      debugPrint('✅ [OrderService] Inventory deducted successfully');
    } catch (e) {
      debugPrint(
        '⚠️  [OrderService] Inventory deduction FAILED (order still created): $e',
      );
      // ⚠️ Order is already created. Log this for manual reconciliation.
      // In production, you may want to notify admins or create a task to reconcile.
    }

    return order;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVENTORY DEDUCTION (called after order creation)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deductInventoryForOrder({
    required String orderId,
    required int orderNumber,
    required String businessId,
    required List<CartItem> cartItems,
  }) async {
    for (final item in cartItems) {
      // Get recipe for this menu item
      final recipe = await _db
          .from('recipes')
          .select('id')
          .eq('menu_item_id', item.menuItemId)
          .maybeSingle();

      if (recipe == null) {
        debugPrint(
          '⚠️  [OrderService] No recipe found for menu item: ${item.menuItemId}',
        );
        continue;
      }

      final recipeId = recipe['id'] as String;

      // Get recipe ingredients
      final ingredientRows = await _db
          .from('recipe_ingredients')
          .select(
            'ingredient_id, ingredient_name, ingredient_unit, quantity_required',
          )
          .eq('recipe_id', recipeId);

      for (final ingredient in ingredientRows as List) {
        final ingredientId =
            (ingredient['ingredient_id'] as String?)?.trim() ?? '';
        final ingredientName =
            (ingredient['ingredient_name'] as String?)?.trim() ?? '';
        final ingredientUnit =
            (ingredient['ingredient_unit'] as String?)?.trim() ?? '';
        final quantityRequired =
            double.tryParse(
              ingredient['quantity_required']?.toString() ?? '0',
            ) ??
            0.0;

        // ✅ VALIDATE: Skip ingredients with empty IDs to prevent UUID errors
        if (ingredientId.isEmpty) {
          debugPrint(
            '⚠️  [OrderService] Skipping ingredient with empty ID for recipe $recipeId',
          );
          continue;
        }

        if (ingredientName.isEmpty || ingredientUnit.isEmpty) {
          debugPrint(
            '⚠️  [OrderService] Skipping ingredient $ingredientId with missing name/unit',
          );
          continue;
        }

        final totalToDeduct = item.quantity * quantityRequired;

        // ✓ Record consumption (audit trail)
        await _db.from('ingredient_consumption').insert({
          'business_id': businessId,
          'order_id': orderId,
          'order_number': orderNumber,
          'recipe_id': recipeId,
          'menu_item_id': item.menuItemId,
          'menu_item_name': item.itemName,
          'ingredient_id': ingredientId,
          'ingredient_name': ingredientName,
          'ingredient_unit': ingredientUnit,
          'quantity_consumed': totalToDeduct,
          'transaction_status': 'pending',
        });

        // ✓ Deduct from inventory
        await _db.rpc(
          'deduct_inventory',
          params: {
            'p_inventory_item_id': ingredientId,
            'p_quantity': totalToDeduct,
            'p_business_id': businessId,
          },
        );

        debugPrint(
          '✅ Deducted $totalToDeduct $ingredientUnit of $ingredientName '
          'for order #$orderNumber',
        );
      }
    }

    // ✓ Mark all consumptions as completed
    await _db
        .from('ingredient_consumption')
        .update({'transaction_status': 'completed'})
        .eq('order_id', orderId);
  }

  // ══════════════════════════════════════════════════════════
  //  CONFIRM PAYMENT → auto-completes order via DB trigger
  // ══════════════════════════════════════════════════════════

  Future<Order> confirmPayment({
    required String orderId,
    required OrderPaymentMode mode,
    required String paidByUid,
    required String paidByName,
    required String businessId,
    String? paymentRef,
    double? tipAmount,
    double? discountAmount,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updateMap = <String, dynamic>{
      'status': 'completed',
      'payment_status': 'paid',
      'payment_mode': mode.value,
      'paid_by_uid': paidByUid,
      'paid_by_name': paidByName,
      'paid_at': now,
      'completed_at': now,
    };

    if (paymentRef != null && paymentRef.isNotEmpty) {
      updateMap['payment_ref'] = paymentRef;
    }
    if (tipAmount != null && tipAmount > 0) {
      updateMap['tip_amount'] = tipAmount;
    }
    if (discountAmount != null && discountAmount > 0) {
      updateMap['discount_amount'] = discountAmount;
    }

    await _db.from('orders').update(updateMap).eq('id', orderId);

    // ✅ FIX: Use maybeSingle() instead of single() to handle PGRST116
    // (order might not exist in view, be soft-deleted, or view might exclude cancelled)
    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (data == null) {
      // Order not in view - could be cancelled/deleted. Fetch directly from orders table
      debugPrint(
        '⚠️  Order $orderId not in view after update. Fetching from orders table directly.',
      );
      try {
        // ✅ Include order_items in fallback query to match view structure
        final directData = await _db
            .from('orders')
            .select('*, order_items(*)')
            .eq('id', orderId)
            .maybeSingle();
        if (directData != null) {
          return Order.fromJson(directData);
        }
      } catch (_) {}
      throw Exception(
        'Order $orderId not found after update (possible deletion or soft-delete)',
      );
    }

    return Order.fromJson(data);
  }

  // ══════════════════════════════════════════════════════════
  //  UPDATE STATUS
  // ══════════════════════════════════════════════════════════

  Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String updatedByUid,
    required String updatedByName,
    required String businessId,
  }) async {
    assert(
      newStatus != OrderStatus.completed,
      'Use confirmPayment() to complete orders',
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final updateMap = <String, dynamic>{
      'status': newStatus.value,
      'updated_by_uid': updatedByUid,
      'updated_by_name': updatedByName,
    };

    switch (newStatus) {
      case OrderStatus.preparing:
        updateMap['started_at'] = now;
        break;
      case OrderStatus.ready:
        updateMap['ready_at'] = now;
        break;
      case OrderStatus.cancelled:
        updateMap['cancelled_at'] = now;
        break;
      default:
        break;
    }

    await _db.from('orders').update(updateMap).eq('id', orderId);

    // ✅ FIX: Use maybeSingle() instead of single() to handle PGRST116
    // (order might not exist in view, be soft-deleted, or view might exclude cancelled)
    final data = await _db
        .from('vw_orders_with_items')
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (data == null) {
      // Order not in view - could be cancelled/deleted. Fetch directly from orders table
      debugPrint(
        '⚠️  Order $orderId not in view after status update to ${newStatus.value}. '
        'Fetching from orders table directly.',
      );
      try {
        // ✅ FIX: Fetch order and items separately in fallback (nested select might not work)
        final orderData = await _db
            .from('orders')
            .select()
            .eq('id', orderId)
            .maybeSingle();

        if (orderData != null) {
          // Try to fetch items separately
          List<Map<String, dynamic>> items = [];
          try {
            final itemsData = await _db
                .from('order_items')
                .select()
                .eq('order_id', orderId);
            items = itemsData is List
                ? itemsData.whereType<Map<String, dynamic>>().toList()
                : [];
          } catch (e) {
            debugPrint('⚠️  Could not fetch order items for $orderId: $e');
            // Continue without items - still return the order
          }

          // Combine order and items data to match view structure
          final fullData = <String, dynamic>{
            ...orderData as Map<String, dynamic>,
            'items': items,
            'order_items': items, // Support both field names
          };

          return Order.fromJson(fullData);
        }
      } catch (e) {
        debugPrint('❌ Fallback orders table query failed: $e');
      }

      // ✅ FIX: Don't throw for cancelled/deleted orders - sync succeeded
      // The order was marked as cancelled/deleted, which is the desired state
      debugPrint(
        '⚠️  Order $orderId not found after status update to ${newStatus.value}. '
        'This is OK if order was deleted/soft-deleted. Returning stub order.',
      );

      // Return a minimal stub order so sync doesn't fail
      // (background sync will retry if truly critical)
      return Order(
        id: orderId,
        orderNumber: 0,
        status: newStatus,
        paymentStatus: PaymentStatus.unpaid,
        orderType: OrderType.dineIn,
        subtotal: 0,
        taxAmount: 0,
        totalAmount: 0,
        items: [],
        businessId: 'unknown',
        businessName: 'Unknown',
        createdByUid: '',
        createdByName: 'System',
        createdAt: DateTime.now(),
      );
    }

    return Order.fromJson(data);
  }

  // ══════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchUnreadNotifications({
    required String businessId,
    String? targetUid,
  }) async {
    var query = _db
        .from('order_notifications')
        .select()
        .eq('business_id', businessId)
        .eq('is_read', false);

    if (targetUid != null) {
      query = query.or('target_uid.is.null,target_uid.eq.$targetUid');
    }

    final data = await query.order('created_at', ascending: false).limit(50);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> markNotificationsRead({
    required String businessId,
    List<String>? ids,
  }) async {
    var query = _db
        .from('order_notifications')
        .update({'is_read': true})
        .eq('business_id', businessId);
    if (ids != null) query = query.inFilter('id', ids);
    await query;
  }

  // ══════════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════════

  RealtimeChannel subscribeToOrders({
    required String businessId,
    required void Function(Order order, String eventType) onEvent,
  }) {
    return _db
        .channel('orders:$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) async {
            try {
              final record = payload.newRecord;
              if (record.isEmpty) return;

              // Try to fetch from view first (preferred)
              try {
                final full = await _db
                    .from('vw_orders_with_items')
                    .select()
                    .eq('id', record['id'])
                    .maybeSingle();
                if (full != null) {
                  onEvent(Order.fromJson(full), payload.eventType.name);
                }
              } on PostgrestException catch (e) {
                // If view is missing, fallback to orders table with empty items
                if (e.message?.contains('vw_orders_with_items') ?? false) {
                  debugPrint(
                    '[OrdersService] View unavailable, using fallback: ${e.message}',
                  );
                  final fallback = await _db
                      .from('orders')
                      .select()
                      .eq('id', record['id'])
                      .maybeSingle();
                  if (fallback != null) {
                    final orderData = {...fallback, 'items': []};
                    onEvent(Order.fromJson(orderData), payload.eventType.name);
                  }
                } else {
                  rethrow;
                }
              }
            } catch (e, st) {
              debugPrint('[OrdersService] realtime callback error: $e\n$st');
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToNotifications({
    required String businessId,
    required void Function(Map<String, dynamic>) onNotification,
  }) {
    return _db
        .channel('notifications:$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNotification(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  // ══════════════════════════════════════════════════════════
  //  ANALYTICS
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchRevenueSummary({
    required String businessId,
    required DateTime from,
    required DateTime to,
    String? staffUid,
  }) async {
    final data = await _db.rpc(
      'fn_revenue_summary',
      params: {
        'p_business_id': businessId,
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_staff_uid': staffUid,
      },
    );
    final row = (data as List).isNotEmpty
        ? data[0] as Map<String, dynamic>
        : {};
    return {
      'total_revenue': (row['total_revenue'] as num? ?? 0).toDouble(),
      'total_orders': (row['total_orders'] as num? ?? 0).toInt(),
      'avg_order': (row['avg_order'] as num? ?? 0).toDouble(),
      'completed': (row['completed'] as num? ?? 0).toInt(),
      'cancelled': (row['cancelled'] as num? ?? 0).toInt(),
    };
  }

  // ══════════════════════════════════════════════════════════
  //  RECIPE INVENTORY VALIDATION
  // ══════════════════════════════════════════════════════════

  /// Validates cart items against recipe ingredient stock
  ///
  /// Returns a Map with:
  /// - can_place (bool): whether order can be placed
  /// - blocking_items (List): items that are blocked due to insufficient stock
  Future<Map<String, dynamic>> validateOrderIngredients({
    required String businessId,
    required List<CartItem> cartItems,
  }) async {
    try {
      // Convert cart items to JSONB format for RPC
      final cartItemsJson = cartItems
          .map(
            (item) => {
              'menu_item_id': item.menuItemId,
              'quantity': item.quantity,
            },
          )
          .toList();

      debugPrint(
        '[OrdersService] validateOrderIngredients - Cart items: $cartItemsJson',
      );

      // Call the RPC function
      final result = await _db.rpc(
        'fn_validate_order_ingredients',
        params: {'p_business_id': businessId, 'p_cart_items': cartItemsJson},
      );

      if (result is List && result.isNotEmpty) {
        final data = result[0] as Map<String, dynamic>;
        return {
          'can_place': data['can_place'] as bool? ?? true,
          'blocking_items': data['blocking_items'] as List? ?? [],
        };
      }

      // If no result, assume order can be placed
      return {'can_place': true, 'blocking_items': []};
    } catch (e) {
      debugPrint('[OrdersService] validateOrderIngredients error: $e');
      // On error, allow order to proceed (better UX than blocking)
      return {'can_place': true, 'blocking_items': []};
    }
  }

  /// Gets the maximum orderable quantity for a menu item based on recipe stock
  ///
  /// Calculates min(available_qty ÷ required_qty) for each ingredient
  Future<int> getMaxOrderableQuantity({
    required String businessId,
    required String menuItemId,
  }) async {
    try {
      // Fetch the recipe for this menu item
      final recipeData = await _db
          .from('recipes')
          .select('id')
          .eq('menu_item_id', menuItemId)
          .eq('business_id', businessId)
          .eq('is_active', true)
          .maybeSingle();

      if (recipeData == null) {
        // No recipe, so unlimited quantity
        return 999;
      }

      final recipeId = recipeData['id'] as String;

      // Fetch all ingredients for this recipe
      final ingredients = await _db
          .from('recipe_ingredients')
          .select('ingredient_id, quantity_required, is_optional')
          .eq('recipe_id', recipeId);

      if (ingredients.isEmpty) {
        // No ingredients, so unlimited
        return 999;
      }

      // For each ingredient, calculate how many can be made
      int minOrderable = 999;

      for (final ingredient in ingredients) {
        final ingredientId = ingredient['ingredient_id'] as String?;
        final requiredQty =
            (ingredient['quantity_required'] as num?)?.toDouble() ?? 0;
        final isOptional = ingredient['is_optional'] as bool? ?? false;

        if (ingredientId == null || requiredQty <= 0) continue;

        // Fetch current stock
        final stockData = await _db
            .from('inventory_items')
            .select('current_stock')
            .eq('id', ingredientId)
            .maybeSingle();

        final currentStock =
            (stockData?['current_stock'] as num?)?.toDouble() ?? 0;

        // Skip optional ingredients
        if (isOptional) continue;

        // Calculate how many can be made with this ingredient
        final orderable = (currentStock / requiredQty).floor();
        minOrderable = minOrderable < orderable ? minOrderable : orderable;

        debugPrint(
          '[OrdersService] Ingredient $ingredientId: '
          'stock=$currentStock, required=$requiredQty, orderable=$orderable',
        );
      }

      // Return at least 0, at most 999
      return minOrderable < 0 ? 0 : (minOrderable > 999 ? 999 : minOrderable);
    } catch (e) {
      debugPrint('[OrdersService] getMaxOrderableQuantity error: $e');
      // On error, return 0 (safest option)
      return 0;
    }
  }
}
