import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
import '../models/supplier_modal.dart';
import '../repositories/supplier_repository.dart';

/// Service to handle supplier validation and automatic creation during bulk upload
class SupplierValidationService {
  SupplierValidationService._();
  static final instance = SupplierValidationService._();

  final _supplierRepo = SupplierRepository.instance;
  final _uuid = const Uuid();

  // ══════════════════════════════════════════════════════════════════════════
  //  SUPPLIER VALIDATION & AUTO-CREATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates supplier name and automatically creates if doesn't exist
  ///
  /// Parameters:
  ///   - supplierName: Name of the supplier from the inventory item
  ///   - supplierMap: Map of existing supplier names to IDs (case-sensitive, modified in place)
  ///   - businessId: Business ID for creating new suppliers
  ///
  /// Returns:
  ///   - Supplier ID (either existing or newly created)
  ///
  /// Logic:
  ///   1. If supplier name is empty/null → return null
  ///   2. Check if supplier exists (case-insensitive)
  ///   3. If exists → return existing supplier ID
  ///   4. If doesn't exist → automatically create under "Other Suppliers" category
  ///   5. Add new supplier to map for future lookups
  Future<String?> validateAndGetSupplierIdWithAutoCreation({
    required String? supplierName,
    required Map<String, String> supplierMap, // modifies this map in place
    required String businessId,
  }) async {
    // If no supplier name provided, return null
    if (supplierName == null || supplierName.trim().isEmpty) {
      return null;
    }

    final trimmedName = supplierName.trim();

    // Check if supplier exists (case-insensitive lookup)
    final existingEntry = _findSupplierCaseInsensitive(
      trimmedName,
      supplierMap,
    );
    if (existingEntry != null) {
      developer.log(
        '✅ Supplier found: "$trimmedName" → ID: ${existingEntry.value}',
        name: 'SupplierValidationService',
      );
      return existingEntry.value;
    }

    // Supplier doesn't exist → Create new one under "Other Suppliers"
    developer.log(
      '📝 Creating new supplier: "$trimmedName" under "Other Suppliers" category',
      name: 'SupplierValidationService',
    );

    try {
      final newSupplierId = _uuid.v4();
      final newSupplier = Supplier(
        id: newSupplierId,
        name: trimmedName,
        category: 'Other Suppliers', // Auto-categorize under "Other Suppliers"
        emoji: '🏢', // Default emoji for auto-created suppliers
        status: SupplierStatus.active,
        creditLimit: 0,
        creditDays: 14,
        rating: 0,
        contacts: [],
        documents: [],
        payments: [],
        deliveries: [],
        onboardedDate: DateTime.now(),
        notes:
            'Auto-created during bulk inventory upload from supplier name: "$trimmedName"',
      );

      // Create the supplier in database
      final success = await _supplierRepo.addSupplier(newSupplier, businessId);

      if (success) {
        // Add to supplier map for future lookups
        supplierMap[trimmedName] = newSupplierId;

        developer.log(
          '✅ Supplier created successfully: "$trimmedName" → ID: $newSupplierId under "Other Suppliers"',
          name: 'SupplierValidationService',
        );

        return newSupplierId;
      } else {
        developer.log(
          '⚠️ Failed to create supplier: "$trimmedName"',
          name: 'SupplierValidationService',
        );
        return null;
      }
    } catch (e) {
      developer.log(
        '❌ Error creating supplier "$trimmedName": $e',
        name: 'SupplierValidationService',
        error: e,
      );
      return null;
    }
  }

  /// Batch validate supplier names and auto-create missing ones
  ///
  /// Useful for validating multiple suppliers at once
  Future<Map<String, String>> validateAndGetSupplierMapWithAutoCreation({
    required List<String?> supplierNames,
    required Map<String, String> supplierMap,
    required String businessId,
  }) async {
    final result = Map<String, String>.from(supplierMap);

    for (final supplierName in supplierNames) {
      if (supplierName != null && supplierName.trim().isNotEmpty) {
        await validateAndGetSupplierIdWithAutoCreation(
          supplierName: supplierName,
          supplierMap: result,
          businessId: businessId,
        );
      }
    }

    return result;
  }

  /// Finds a supplier by name using case-insensitive comparison
  ///
  /// Returns the map entry if found, otherwise null
  MapEntry<String, String>? _findSupplierCaseInsensitive(
    String name,
    Map<String, String> supplierMap,
  ) {
    final lowerName = name.toLowerCase();

    try {
      return supplierMap.entries.firstWhere(
        (entry) => entry.key.toLowerCase() == lowerName,
      );
    } catch (e) {
      // Not found
      return null;
    }
  }

  /// Gets existing suppliers grouped by category
  Future<Map<String, List<MapEntry<String, String>>>> getSuppliersByCategory(
    Map<String, String> supplierMap,
  ) async {
    final grouped = <String, List<MapEntry<String, String>>>{};

    for (final entry in supplierMap.entries) {
      final key = entry.key;
      // Extract category if possible (would need to fetch from supplier objects)
      // For now, just group by first letter as fallback
      final category = key.split(' ').first;
      grouped.putIfAbsent(category, () => []).add(entry);
    }

    return grouped;
  }
}
