import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
import '../models/supplier_modal.dart';
import '../repositories/supplier_repository.dart';
import 'fuzzy_matching_service.dart';

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

  // ══════════════════════════════════════════════════════════════════════════
  //  FUZZY MATCHING & AUTO-MAPPING WITH FALLBACK
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates supplier name with intelligent fuzzy matching and fallback
  ///
  /// Strategy (in priority order):
  /// 1. Exact match (case-insensitive) - return existing supplier
  /// 2. Fuzzy match above 80% threshold - auto-map to closest match
  /// 3. No match found - create new supplier under "Others" fallback category
  ///
  /// Parameters:
  ///   - supplierName: Name of the supplier from the inventory item
  ///   - supplierMap: Map of existing supplier names to IDs (modified in place)
  ///   - businessId: Business ID for creating new suppliers
  ///   - useAutoMapping: If true, use fuzzy matching to auto-map to closest supplier
  ///   - createFallbackSupplier: If true, create under "Other Suppliers" when no match found
  ///   - fallbackSupplierName: Name of the fallback supplier (default: "Other Suppliers")
  ///
  /// Returns:
  ///   - Map containing:
  ///     - 'id': Supplier ID (either existing, auto-mapped, or newly created)
  ///     - 'name': Actual supplier name used
  ///     - 'originalName': Original input name (for audit trail)
  ///     - 'mappedTo': Name of the supplier it was mapped to (if auto-mapped)
  ///     - 'mappingType': 'exact', 'auto_mapped', or 'created'
  ///     - 'matchScore': Fuzzy match score if auto-mapped (0.0-1.0)
  Future<Map<String, dynamic>> validateSupplierWithIntelligentMapping({
    required String? supplierName,
    required Map<String, String> supplierMap,
    required String businessId,
    bool useAutoMapping = true,
    bool createFallbackSupplier = true,
    String fallbackSupplierName = 'Other Suppliers',
  }) async {
    if (supplierName == null || supplierName.trim().isEmpty) {
      return {
        'id': null,
        'name': null,
        'originalName': null,
        'mappedTo': null,
        'mappingType': 'none',
        'matchScore': 0.0,
        'reason': 'No supplier name provided',
      };
    }

    final trimmedName = supplierName.trim();
    final originalName = trimmedName;

    // Step 1: Check for exact match (case-insensitive)
    final exactMatch = _findSupplierCaseInsensitive(trimmedName, supplierMap);
    if (exactMatch != null) {
      developer.log(
        '✅ Exact supplier match: "$trimmedName" → ID: ${exactMatch.value}',
        name: 'SupplierValidationService',
      );
      return {
        'id': exactMatch.value,
        'name': exactMatch.key,
        'originalName': originalName,
        'mappedTo': null,
        'mappingType': 'exact',
        'matchScore': 1.0,
        'reason': 'Exact match found',
      };
    }

    // Step 2: Try fuzzy matching if enabled
    if (useAutoMapping) {
      final fuzzyMatch = FuzzyMatchingService.findBestMatch(
        input: trimmedName,
        candidates: supplierMap.keys.toList(),
      );

      // Strong match (80% or above) - auto-map to this supplier
      if (fuzzyMatch != null && fuzzyMatch.isStrongMatch) {
        final matchedId = supplierMap[fuzzyMatch.matchedValue!];
        if (matchedId != null) {
          developer.log(
            '🔗 Auto-mapped supplier: "$trimmedName" → "${fuzzyMatch.matchedValue}" (${(fuzzyMatch.matchScore * 100).toStringAsFixed(1)}%) | ID: $matchedId',
            name: 'SupplierValidationService',
          );
          return {
            'id': matchedId,
            'name': fuzzyMatch.matchedValue,
            'originalName': originalName,
            'mappedTo': fuzzyMatch.matchedValue,
            'mappingType': 'auto_mapped',
            'matchScore': fuzzyMatch.matchScore,
            'reason': fuzzyMatch.reason,
          };
        }
      }
    }

    // Step 3: No match found - create new supplier or use fallback
    developer.log(
      '📝 No supplier match for "$trimmedName"',
      name: 'SupplierValidationService',
    );

    if (createFallbackSupplier) {
      return await _createOrUseFallbackSupplier(
        supplierName: trimmedName,
        supplierMap: supplierMap,
        businessId: businessId,
        fallbackSupplierName: fallbackSupplierName,
      );
    }

    return {
      'id': null,
      'name': null,
      'originalName': originalName,
      'mappedTo': null,
      'mappingType': 'no_match',
      'matchScore': 0.0,
      'reason': 'No supplier found and fallback creation disabled',
    };
  }

  /// Creates a new supplier or links to fallback supplier (e.g., "Other Suppliers")
  ///
  /// This method:
  /// 1. Tries to find the fallback supplier in existing suppliers
  /// 2. If found, returns it (supplier will be linked to fallback)
  /// 3. If not found, creates the fallback supplier and returns it
  /// 4. The original supplier name is tracked in notes for reference
  Future<Map<String, dynamic>> _createOrUseFallbackSupplier({
    required String supplierName,
    required Map<String, String> supplierMap,
    required String businessId,
    String fallbackSupplierName = 'Other Suppliers',
  }) async {
    try {
      // Try to find existing fallback supplier
      final fallbackSupplier = _findSupplierCaseInsensitive(
        fallbackSupplierName,
        supplierMap,
      );

      if (fallbackSupplier != null) {
        developer.log(
          '🔗 Mapping to existing fallback supplier: "$supplierName" → "$fallbackSupplierName" | ID: ${fallbackSupplier.value}',
          name: 'SupplierValidationService',
        );
        return {
          'id': fallbackSupplier.value,
          'name': fallbackSupplier.key,
          'originalName': supplierName,
          'mappedTo': fallbackSupplier.key,
          'mappingType': 'fallback_mapped',
          'matchScore': 0.0,
          'reason':
              'Mapped to fallback supplier for unrecognized name: "$supplierName"',
        };
      }

      // Create fallback supplier if it doesn't exist
      developer.log(
        '📝 Creating fallback supplier "$fallbackSupplierName" for unrecognized supplier "$supplierName"',
        name: 'SupplierValidationService',
      );

      final newSupplierId = _uuid.v4();
      final newSupplier = Supplier(
        id: newSupplierId,
        name: fallbackSupplierName,
        category: 'Other Suppliers',
        emoji: '🏢',
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
            'Fallback supplier for unmapped supplier names. Original unrecognized names are tracked in inventory item notes.',
      );

      final success = await _supplierRepo.addSupplier(newSupplier, businessId);
      if (success) {
        supplierMap[fallbackSupplierName] = newSupplierId;
        developer.log(
          '✅ Fallback supplier created: "$fallbackSupplierName" | ID: $newSupplierId',
          name: 'SupplierValidationService',
        );
        return {
          'id': newSupplierId,
          'name': fallbackSupplierName,
          'originalName': supplierName,
          'mappedTo': fallbackSupplierName,
          'mappingType': 'fallback_created',
          'matchScore': 0.0,
          'reason':
              'Created fallback supplier for unrecognized name: "$supplierName"',
        };
      }
    } catch (e) {
      developer.log(
        '❌ Error creating fallback supplier: $e',
        name: 'SupplierValidationService',
        error: e,
      );
    }

    return {
      'id': null,
      'name': null,
      'originalName': supplierName,
      'mappedTo': null,
      'mappingType': 'error',
      'matchScore': 0.0,
      'reason': 'Failed to create or find fallback supplier',
    };
  }

  /// Gets all fuzzy match candidates for a supplier name
  /// Useful for UI preview/confirmation of auto-mapping
  List<FuzzyMatchResult> getFuzzyMatchCandidates({
    required String supplierName,
    required List<String> existingSupplierNames,
    double minScore = 0.5,
  }) {
    if (supplierName.trim().isEmpty) {
      return [];
    }

    return FuzzyMatchingService.findAllMatches(
      input: supplierName.trim(),
      candidates: existingSupplierNames,
      minScore: minScore,
    );
  }
}
