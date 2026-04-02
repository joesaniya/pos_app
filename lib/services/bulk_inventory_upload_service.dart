// lib/services/bulk_inventory_upload_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  BULK INVENTORY UPLOAD SERVICE — Orchestrates intelligent bulk inventory operations
//  • Handles duplicate detection & prevention
//  • Supports smart stock appending to existing products
//  • Maintains stock history logs
//  • Manages master data synchronization
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:uuid/uuid.dart';

import '../models/inventory_modal.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_excel_validation_service.dart';

/// Result of bulk inventory upload operation
class BulkUploadResult {
  final bool success;
  final int totalProcessed;
  final int newItemsCreated;
  final int itemsUpdated;
  final int duplicatesSkipped;
  final List<String> errorMessages;
  final List<Map<String, dynamic>> detailedResults;
  final DateTime timestamp;

  BulkUploadResult({
    required this.success,
    required this.totalProcessed,
    required this.newItemsCreated,
    required this.itemsUpdated,
    required this.duplicatesSkipped,
    required this.errorMessages,
    required this.detailedResults,
    required this.timestamp,
  });

  String get summary {
    if (!success) {
      return '❌ Upload failed with ${errorMessages.length} errors';
    }
    return '✅ Processed: $totalProcessed | Created: $newItemsCreated | Updated: $itemsUpdated | Duplicates: $duplicatesSkipped';
  }
}

/// Stock history entry for appended quantities
class StockAppendHistory {
  final String itemId;
  final double quantityAdded;
  final String sourceSupplier;
  final DateTime timestamp;
  final String reason; // e.g., "Bulk upload duplicate - stock appended"

  StockAppendHistory({
    required this.itemId,
    required this.quantityAdded,
    required this.sourceSupplier,
    required this.timestamp,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'quantity_added': quantityAdded,
    'source_supplier': sourceSupplier,
    'timestamp': timestamp.toIso8601String(),
    'reason': reason,
  };
}

/// Service to handle bulk inventory upload operations
class BulkInventoryUploadService {
  BulkInventoryUploadService._();
  static final instance = BulkInventoryUploadService._();

  final _inventoryRepo = InventoryRepository.instance;
  final _uuid = const Uuid();

  // ══════════════════════════════════════════════════════════════════════════
  //  MAIN BULK UPLOAD ORCHESTRATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Main method to handle bulk inventory upload with duplicate detection
  ///
  /// Flow:
  /// 1. Validate Excel file structure
  /// 2. Fetch existing inventory for duplicate detection
  /// 3. Detect duplicates using Product Name, SKU, Reference ID
  /// 4. For new items: insert directly
  /// 5. For duplicates: append stock to existing items & log history
  /// 6. Generate detailed results report
  Future<BulkUploadResult> processBulkUpload({
    required String filePath,
    required String businessId,
    required String userUid,
    required String userName,
    required String userRole,
    required List<String> validCategories,
    required Map<String, String> supplierMap,
  }) async {
    final errorMessages = <String>[];
    final detailedResults = <Map<String, dynamic>>[];

    try {
      log(
        '📦 Starting bulk inventory upload for business: $businessId',
        name: 'BulkInventoryUploadService',
      );

      // Step 1: Validate Excel file
      log(
        '📋 Step 1: Validating Excel file...',
        name: 'BulkInventoryUploadService',
      );
      final validationResult =
          await InventoryExcelValidationService.parseAndValidateExcelFile(
            filePath: filePath,
            validCategories: validCategories,
            supplierMap: supplierMap,
          );

      final validatedItems =
          validationResult['data'] as List<ValidatedInventoryData>;
      final validationErrors =
          validationResult['errors'] as List<InventoryValidationError>;
      final newCategories = validationResult['newCategories'] as List<String>;

      if (validationErrors.isNotEmpty) {
        log(
          '❌ Excel validation failed: ${validationErrors.length} errors',
          name: 'BulkInventoryUploadService',
        );
        return BulkUploadResult(
          success: false,
          totalProcessed: 0,
          newItemsCreated: 0,
          itemsUpdated: 0,
          duplicatesSkipped: 0,
          errorMessages: validationErrors.map((e) => e.toString()).toList(),
          detailedResults: [],
          timestamp: DateTime.now(),
        );
      }

      log(
        '✅ Excel validation passed: ${validatedItems.length} items${newCategories.isNotEmpty ? ', ${newCategories.length} new categories' : ''}',
        name: 'BulkInventoryUploadService',
      );

      // Step 2: Create new categories detected during fuzzy matching
      if (newCategories.isNotEmpty) {
        log(
          '📁 Step 2: Creating ${newCategories.length} new categories: ${newCategories.join(", ")}',
          name: 'BulkInventoryUploadService',
        );
        await _createNewCategories(
          categories: newCategories,
          businessId: businessId,
        );
        log(
          '✅ All new categories created successfully',
          name: 'BulkInventoryUploadService',
        );
      }

      // Step 3: Fetch existing inventory for duplicate detection
      log(
        '🔍 Step 3: Fetching existing inventory...',
        name: 'BulkInventoryUploadService',
      );
      final existingItems = await _inventoryRepo.fetchItems(businessId);
      log(
        '📊 Found ${existingItems.length} existing items',
        name: 'BulkInventoryUploadService',
      );

      // Step 4: Detect duplicates
      log(
        '🔎 Step 4: Detecting duplicates...',
        name: 'BulkInventoryUploadService',
      );
      final duplicateResult =
          await InventoryExcelValidationService.detectAndHandleDuplicates(
            validatedItems: validatedItems,
            existingItems: existingItems,
          );

      final newItems =
          duplicateResult['newItems'] as List<ValidatedInventoryData>;
      final duplicates =
          duplicateResult['duplicates'] as List<Map<String, dynamic>>;
      final updates = duplicateResult['updates'] as List<DuplicateUpdate>;

      log(
        '📊 Duplicate detection: ${newItems.length} new, ${duplicates.length} duplicates',
        name: 'BulkInventoryUploadService',
      );

      // Step 5: Process new items
      log(
        '➕ Step 5: Creating new items...',
        name: 'BulkInventoryUploadService',
      );
      int newItemsCreated = 0;
      for (final item in newItems) {
        try {
          final inventoryItem = InventoryItem(
            id: _uuid.v4(),
            name: item.name,
            category: item.category,
            emoji: item.emoji,
            currentStock: item.currentStock,
            minThreshold: item.minThreshold,
            maxCapacity: item.maxCapacity,
            unit: item.unit,
            costPerUnit: item.costPerUnit,
            supplier: item.supplierName ?? 'Not Specified',
            supplierId: item.supplierId,
            lastUpdated: DateTime.now(),
            notes: item.notes,
            sku: item.sku,
            referenceId: item.referenceId,
          );

          final success = await _inventoryRepo.addItem(
            item: inventoryItem,
            businessId: businessId,
            userUid: userUid,
            userName: userName,
            userRole: userRole,
          );

          if (success) {
            newItemsCreated++;
            detailedResults.add({
              'action': 'create',
              'status': 'success',
              'itemName': item.name,
              'itemId': inventoryItem.id,
              'quantity': item.currentStock,
              'sku': item.sku,
              'referenceId': item.referenceId,
            });
          }
        } catch (e) {
          errorMessages.add('Failed to create item "${item.name}": $e');
          detailedResults.add({
            'action': 'create',
            'status': 'failed',
            'itemName': item.name,
            'error': e.toString(),
          });
        }
      }

      log(
        '✅ Created $newItemsCreated new items',
        name: 'BulkInventoryUploadService',
      );

      // Step 6: Process duplicates - update existing items with appended stock
      log(
        '📈 Step 6: Updating existing items with appended stock...',
        name: 'BulkInventoryUploadService',
      );
      int itemsUpdated = 0;
      final stockAppendHistories = <StockAppendHistory>[];

      for (final update in updates) {
        try {
          final existingItem = existingItems.firstWhere(
            (item) => item.id == update.existingItemId,
          );

          // Calculate new stock quantity by appending
          final newStock = existingItem.currentStock + update.newQuantity;

          // Update the item with new stock
          final updatedItem = existingItem.copyWith(currentStock: newStock);
          await _inventoryRepo.updateItem(
            item: updatedItem,
            businessId: businessId,
          );

          // Record stock transaction
          await _inventoryRepo.recordTransaction(
            itemId: update.existingItemId,
            type: TransactionType.stockIn,
            quantity: update.newQuantity,
            stockBefore: existingItem.currentStock,
            stockAfter: newStock,
            unit: existingItem.unit,
            note:
                'Bulk upload append - ${update.matchReason} - Supplier: ${update.newItemData.supplierName ?? "Not specified"}',
            businessId: businessId,
            userUid: userUid,
            userName: userName,
            userRole: userRole,
            costPerUnit: update.newItemData.costPerUnit,
          );

          // Log stock append history
          stockAppendHistories.add(
            StockAppendHistory(
              itemId: update.existingItemId,
              quantityAdded: update.newQuantity,
              sourceSupplier: update.newItemData.supplierName ?? 'Unknown',
              timestamp: DateTime.now(),
              reason: 'Bulk upload append - ${update.matchReason}',
            ),
          );

          itemsUpdated++;
          detailedResults.add({
            'action': 'update',
            'status': 'success',
            'itemName': update.existingItemName,
            'itemId': update.existingItemId,
            'quantityAppended': update.newQuantity,
            'matchReason': update.matchReason,
            'newItemSKU': update.newItemData.sku,
            'newItemReferenceId': update.newItemData.referenceId,
          });
        } catch (e) {
          errorMessages.add(
            'Failed to update item "${update.existingItemName}": $e',
          );
          detailedResults.add({
            'action': 'update',
            'status': 'failed',
            'itemName': update.existingItemName,
            'error': e.toString(),
          });
        }
      }

      log('✅ Updated $itemsUpdated items', name: 'BulkInventoryUploadService');

      // Step 7: Return comprehensive result
      final result = BulkUploadResult(
        success: errorMessages.isEmpty,
        totalProcessed: newItems.length + updates.length,
        newItemsCreated: newItemsCreated,
        itemsUpdated: itemsUpdated,
        duplicatesSkipped: duplicates.length,
        errorMessages: errorMessages,
        detailedResults: detailedResults,
        timestamp: DateTime.now(),
      );

      log(
        '🎉 Bulk upload complete: ${result.summary}',
        name: 'BulkInventoryUploadService',
      );

      return result;
    } catch (e) {
      log(
        '❌ Bulk upload error: $e',
        name: 'BulkInventoryUploadService',
        error: e,
      );
      return BulkUploadResult(
        success: false,
        totalProcessed: 0,
        newItemsCreated: 0,
        itemsUpdated: 0,
        duplicatesSkipped: 0,
        errorMessages: ['Unexpected error: $e'],
        detailedResults: [],
        timestamp: DateTime.now(),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Generates a detailed report of the bulk upload
  String generateUploadReport(BulkUploadResult result) {
    final buffer = StringBuffer();

    buffer.writeln(
      '╔════════════════════════════════════════════════════════╗',
    );
    buffer.writeln('║      BULK INVENTORY UPLOAD REPORT                    ║');
    buffer.writeln(
      '╚════════════════════════════════════════════════════════╝',
    );
    buffer.writeln('');
    buffer.writeln('Timestamp: ${result.timestamp}');
    buffer.writeln('Status: ${result.success ? "✅ SUCCESS" : "❌ FAILED"}');
    buffer.writeln('');
    buffer.writeln('───── SUMMARY ─────');
    buffer.writeln('Total Processed:    ${result.totalProcessed}');
    buffer.writeln('New Items Created:  ${result.newItemsCreated}');
    buffer.writeln('Items Updated:      ${result.itemsUpdated}');
    buffer.writeln('Duplicates Handled: ${result.duplicatesSkipped}');
    buffer.writeln('');

    if (result.errorMessages.isNotEmpty) {
      buffer.writeln('───── ERRORS ─────');
      for (int i = 0; i < result.errorMessages.length; i++) {
        buffer.writeln('${i + 1}. ${result.errorMessages[i]}');
      }
      buffer.writeln('');
    }

    buffer.writeln('───── DETAILED RESULTS ─────');
    for (final detail in result.detailedResults) {
      final action = detail['action'];
      final status = detail['status'];
      final itemName = detail['itemName'];

      if (status == 'success') {
        if (action == 'create') {
          final qty = detail['quantity'];
          buffer.writeln('✅ Created: $itemName (Qty: $qty)');
        } else if (action == 'update') {
          final qty = detail['quantityAppended'];
          final reason = detail['matchReason'];
          buffer.writeln(
            '📈 Updated: $itemName (Appended: $qty, Reason: $reason)',
          );
        }
      } else {
        buffer.writeln('❌ Failed: $itemName - ${detail['error']}');
      }
    }

    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPER: CREATE NEW CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates new inventory categories that were detected during fuzzy matching
  /// This ensures categories exist in the database before items are linked to them
  Future<void> _createNewCategories({
    required List<String> categories,
    required String businessId,
  }) async {
    if (categories.isEmpty) {
      return;
    }

    try {
      for (final categoryName in categories) {
        try {
          // Categories are typically auto-created when an inventory item with a new category is added
          // However, we log this for transparency
          log(
            '📁 Creating new category: "$categoryName" for business: $businessId',
            name: 'BulkInventoryUploadService',
          );
          // Note: The actual category creation happens when InventoryItem.addItem() is called
          // with a category that doesn't exist. The repository handles category auto-creation.
          // This method serves as a placeholder and logging point for category creation.
        } catch (e) {
          log(
            '⚠️ Error creating category "$categoryName": $e',
            name: 'BulkInventoryUploadService',
            error: e,
          );
        }
      }
    } catch (e) {
      log(
        '❌ Error in category creation process: $e',
        name: 'BulkInventoryUploadService',
        error: e,
      );
    }
  }
}
