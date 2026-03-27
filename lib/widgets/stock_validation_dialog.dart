// lib/widgets/stock_validation_dialog.dart
// ═══════════════════════════════════════════════════════════════════════════
// STOCK VALIDATION DIALOG
// ─────────────────────────────────────────────────────────────────────────
// - Shows insufficient stock popup with adjustment option
// - Displays limiting ingredient and max quantity that can be made
// - Allows user to auto-adjust to max possible or cancel
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/services/inventory_deduction_service.dart';

class StockValidationDialog extends StatelessWidget {
  final String itemName;
  final int requestedQuantity;
  final StockValidationResult validationResult;
  final VoidCallback? onAdjustPressed;
  final VoidCallback? onCancelPressed;

  const StockValidationDialog({
    required this.itemName,
    required this.requestedQuantity,
    required this.validationResult,
    this.onAdjustPressed,
    this.onCancelPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final limitingIng = validationResult.limitingIngredient;
    final maxAllowed = validationResult.maxAllowedQuantity;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Insufficient Stock',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cannot prepare $requestedQuantity x $itemName',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildConstraintBox(context, limitingIng),
            const SizedBox(height: 16),
            if (maxAllowed > 0)
              _buildAdjustmentOption(context, maxAllowed)
            else
              _buildOutOfStockMessage(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onCancelPressed?.call();
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
        if (maxAllowed > 0)
          ElevatedButton(
            onPressed: () {
              onAdjustPressed?.call();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Adjust to $maxAllowed'),
          ),
      ],
    );
  }

  Widget _buildConstraintBox(
    BuildContext context,
    RecipeIngredient? ingredient,
  ) {
    if (ingredient == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Item is out of stock',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final required = requestedQuantity * ingredient.quantityRequired;
    final available = ingredient.availableQuantity;
    final shortfall = required - available;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(
                  text: 'Limiting Factor: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ingredient.ingredientName,
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Required: ${required.toStringAsFixed(1)} ${ingredient.ingredientUnit}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Available: ${available.toStringAsFixed(1)} ${ingredient.ingredientUnit}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Short by: ${shortfall.toStringAsFixed(1)} ${ingredient.ingredientUnit}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentOption(BuildContext context, int maxAllowed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Good news!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                const TextSpan(text: 'You can prepare '),
                TextSpan(
                  text: '$maxAllowed items',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      ' with available stock. Click "Adjust to $maxAllowed" to proceed.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'The limiting ingredient is completely out of stock. Please try again later.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
      ),
    );
  }
}

/// Show stock validation popup and handle adjustment
/// Returns true if user chose to adjust, false if cancelled
Future<bool?> showStockValidationDialog(
  BuildContext context, {
  required String itemName,
  required int requestedQuantity,
  required StockValidationResult validationResult,
  required VoidCallback onAdjusted,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StockValidationDialog(
      itemName: itemName,
      requestedQuantity: requestedQuantity,
      validationResult: validationResult,
      onAdjustPressed: onAdjusted,
    ),
  );
}
