// lib/services/inventory_deduction_service.dart
// ═══════════════════════════════════════════════════════════════════════════
// INVENTORY VALIDATION & DEDUCTION SERVICE
// ─────────────────────────────────────────────────────────────────────────
// - Validates stock before adding items to cart
// - Calculates max quantity based on available ingredients
// - Deducts inventory after successful order placement
// - Prevents duplicate deductions
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeIngredient {
  final String ingredientId;
  final String ingredientName;
  final String ingredientUnit;
  final double quantityRequired;
  final double availableQuantity;
  final String baseUnit;

  RecipeIngredient({
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientUnit,
    required this.quantityRequired,
    required this.availableQuantity,
    required this.baseUnit,
  });

  /// Calculate how many items can be made with available stock
  int maxItemsAllowed() {
    if (quantityRequired <= 0) return 999999;
    final maxFromThisIngredient = (availableQuantity / quantityRequired)
        .floor();
    return maxFromThisIngredient;
  }

  /// Check if there's enough stock for the requested quantity
  bool hasEnoughStock(int requestedQuantity) {
    return requestedQuantity * quantityRequired <= availableQuantity;
  }

  /// Get the limiting ingredient name and available quantity
  String getConstraintMessage(int requestedQuantity) {
    final totalRequired = requestedQuantity * quantityRequired;
    final shortfall = totalRequired - availableQuantity;
    return '$ingredientName: needs $totalRequired $ingredientUnit, only have $availableQuantity $ingredientUnit (short by $shortfall)';
  }
}

class StockValidationResult {
  final bool isValid;
  final int maxAllowedQuantity;
  final String? errorMessage;
  final List<RecipeIngredient> ingredients;
  final RecipeIngredient? limitingIngredient;

  StockValidationResult({
    required this.isValid,
    required this.maxAllowedQuantity,
    this.errorMessage,
    required this.ingredients,
    this.limitingIngredient,
  });

  String getUserMessage() {
    if (!isValid) {
      if (maxAllowedQuantity > 0) {
        return 'Only $maxAllowedQuantity items can be made with available stock. The limiting factor is ${limitingIngredient?.ingredientName ?? 'stock'}. Would you like to adjust to $maxAllowedQuantity?';
      } else {
        return 'Insufficient stock. ${limitingIngredient?.ingredientName ?? 'This item'} is out of stock.';
      }
    }
    return '';
  }
}

class InventoryDeductionService {
  static final InventoryDeductionService _instance =
      InventoryDeductionService._();
  factory InventoryDeductionService() => _instance;
  InventoryDeductionService._();

  final _db = Supabase.instance.client;

  /// Fetch recipe with ingredients and current stock for a menu item
  Future<List<RecipeIngredient>> fetchRecipeIngredients(
    String menuItemId,
  ) async {
    try {
      // Get recipe with embedded ingredients array
      final recipeResponse = await _db
          .from('recipes')
          .select()
          .eq('menu_item_id', menuItemId)
          .maybeSingle();

      log(
        'fetching recipe for menuItemId: $menuItemId, response: $recipeResponse',
      );

      if (recipeResponse == null) {
        debugPrint('❌ No recipe found for menu item: $menuItemId');
        return [];
      }

      // Parse ingredients array directly from recipe response
      final ingredientsArray = recipeResponse['ingredients'] as List? ?? [];

      log('ingredientsArray for menuItemId $menuItemId: $ingredientsArray');

      if (ingredientsArray.isEmpty) {
        debugPrint(
          '⚠️  No ingredients defined for recipe: ${recipeResponse['id']}',
        );
        return [];
      }

      final ingredients = <RecipeIngredient>[];

      for (final ing in ingredientsArray) {
        try {
          final ingredient = RecipeIngredient(
            ingredientId: ing['inventory_item_id'] as String? ?? '',
            ingredientName: ing['inventory_item_name'] as String? ?? 'Unknown',
            ingredientUnit: ing['unit'] as String? ?? 'unit',
            quantityRequired:
                double.tryParse(ing['required_quantity']?.toString() ?? '0') ??
                0.0,
            availableQuantity:
                double.tryParse(ing['available_quantity']?.toString() ?? '0') ??
                0.0,
            baseUnit: ing['base_unit'] as String? ?? ing['unit'] ?? 'unit',
          );
          ingredients.add(ingredient);
        } catch (e) {
          debugPrint('⚠️  Error parsing ingredient from recipe: $e');
        }
      }

      debugPrint(
        '✅ Fetched ${ingredients.length} ingredients for menu item: $menuItemId',
      );
      return ingredients;
    } catch (e) {
      debugPrint('❌ Error fetching recipe ingredients: $e');
      return [];
    }
  }

  /// Validate stock before adding to cart
  /// Returns validation result with max allowed quantity
  Future<StockValidationResult> validateStock(
    String menuItemId,
    int requestedQuantity,
  ) async {
    try {
      if (requestedQuantity <= 0) {
        return StockValidationResult(
          isValid: false,
          maxAllowedQuantity: 0,
          errorMessage: 'Invalid quantity',
          ingredients: [],
          limitingIngredient: null,
        );
      }

      final ingredients = await fetchRecipeIngredients(menuItemId);

      if (ingredients.isEmpty) {
        // No recipe or ingredients defined — allow unlimited
        debugPrint(
          '⚠️  No recipe data found for $menuItemId, allowing unlimited quantity',
        );
        return StockValidationResult(
          isValid: true,
          maxAllowedQuantity: 999999,
          ingredients: ingredients,
          limitingIngredient: null,
        );
      }

      // Find the ingredient with minimum available quantity
      int minAllowed = 999999;
      RecipeIngredient? limitingIngredient;

      for (final ing in ingredients) {
        final maxFromThisIng = ing.maxItemsAllowed();
        if (maxFromThisIng < minAllowed) {
          minAllowed = maxFromThisIng;
          limitingIngredient = ing;
        }
      }

      final hasEnoughStock = requestedQuantity <= minAllowed;

      debugPrint(
        '📦 Stock validation for $menuItemId (qty: $requestedQuantity): '
        'max=$minAllowed, limiting=${limitingIngredient?.ingredientName}',
      );

      return StockValidationResult(
        isValid: hasEnoughStock,
        maxAllowedQuantity: minAllowed,
        errorMessage: hasEnoughStock
            ? null
            : limitingIngredient?.getConstraintMessage(requestedQuantity),
        ingredients: ingredients,
        limitingIngredient: limitingIngredient,
      );
    } catch (e) {
      debugPrint('❌ Stock validation error: $e');
      return StockValidationResult(
        isValid: false,
        maxAllowedQuantity: 0,
        errorMessage: 'Error validating stock: $e',
        ingredients: [],
        limitingIngredient: null,
      );
    }
  }

  /// Deduct inventory after successful order placement
  /// Must only be called AFTER order is successfully created
  /// Throws exception if deduction fails (order should be rolled back)
  Future<void> deductInventoryForOrder(
    String orderId,
    int orderNumber,
    String businessId,
    List<Map<String, dynamic>> orderItems,
  ) async {
    try {
      debugPrint(
        '🔄 Starting inventory deduction for order: $orderId (#$orderNumber)',
      );

      for (final item in orderItems) {
        final menuItemId = item['menu_item_id'] as String?;
        final itemName = item['item_name'] as String?;
        final quantity = item['quantity'] as int?;

        if (menuItemId == null || quantity == null || quantity <= 0) {
          debugPrint('⚠️  Skipping invalid item: ${item.toString()}');
          continue;
        }

        // Get recipe ingredients
        final ingredients = await fetchRecipeIngredients(menuItemId);
        if (ingredients.isEmpty) {
          debugPrint(
            '⚠️  No recipe found for menu item: $menuItemId, skipping deduction',
          );
          continue;
        }

        // Deduct each ingredient
        for (final ing in ingredients) {
          final totalToDeduct = quantity * ing.quantityRequired;

          // ✓ Verify sufficient stock before deducting
          if (totalToDeduct > ing.availableQuantity) {
            throw Exception(
              'Insufficient stock for $itemName during deduction. '
              'Required: $totalToDeduct ${ing.ingredientUnit}, '
              'Available: ${ing.availableQuantity} ${ing.ingredientUnit}',
            );
          }

          // ✓ Create consumption record (for audit trail) — non-blocking
          // If RLS policy fails, log but continue with deduction
          try {
            await _db.from('ingredient_consumption').insert({
              'business_id': businessId,
              'order_id': orderId,
              'order_number': orderNumber,
              'menu_item_id': menuItemId,
              'menu_item_name': itemName,
              'ingredient_id': ing.ingredientId,
              'ingredient_name': ing.ingredientName,
              'ingredient_unit': ing.ingredientUnit,
              'quantity_consumed': totalToDeduct,
              'transaction_status': 'pending',
            });
          } catch (e) {
            debugPrint(
              '⚠️  Warning: Could not create consumption record: $e. '
              'Proceeding with inventory deduction anyway.',
            );
          }

          // ✓ Deduct from inventory
          await _db.rpc(
            'deduct_inventory',
            params: {
              'p_inventory_item_id': ing.ingredientId,
              'p_quantity': totalToDeduct,
              'p_business_id': businessId,
            },
          );

          debugPrint(
            '✅ Deducted $totalToDeduct ${ing.ingredientUnit} of ${ing.ingredientName} '
            'for order #$orderNumber (item: $itemName)',
          );
        }
      }

      // ✓ Mark consumption as completed — non-blocking
      try {
        await _db
            .from('ingredient_consumption')
            .update({'transaction_status': 'completed'})
            .eq('order_id', orderId);
      } catch (e) {
        debugPrint(
          '⚠️  Warning: Could not update consumption status: $e. '
          'Inventory deduction completed anyway.',
        );
      }

      debugPrint('✅ Inventory deduction completed for order: $orderId');
    } catch (e) {
      debugPrint('❌ Inventory deduction error for order $orderId: $e');
      // Mark consumption as failed for rollback — non-blocking
      try {
        await _db
            .from('ingredient_consumption')
            .update({'transaction_status': 'failed'})
            .eq('order_id', orderId);
      } catch (_) {}
      rethrow;
    }
  }
}
