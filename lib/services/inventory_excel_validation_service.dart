import 'dart:io';
import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../models/inventory_modal.dart';
import 'supplier_validation_service.dart';
import 'fuzzy_matching_service.dart';

/// Model to represent a duplicate item that needs to be updated with appended stock
class DuplicateUpdate {
  final String existingItemId;
  final String existingItemName;
  final double newQuantity;
  final ValidatedInventoryData newItemData;
  final String? matchReason;

  DuplicateUpdate({
    required this.existingItemId,
    required this.existingItemName,
    required this.newQuantity,
    required this.newItemData,
    this.matchReason,
  });

  @override
  String toString() =>
      'Update $existingItemName: append $newQuantity ($matchReason)';
}

/// Model to represent validation errors for Excel file entries
class InventoryValidationError {
  final int rowNumber;
  final String field;
  final String error;
  final String? suggestedValue;

  InventoryValidationError({
    required this.rowNumber,
    required this.field,
    required this.error,
    this.suggestedValue,
  });

  @override
  String toString() => 'Row $rowNumber, $field: $error';
}

/// Model to represent validated inventory data from Excel
class ValidatedInventoryData {
  final String name;
  final String category;
  final String?
  originalCategory; // Original category as entered by user (for audit trail)
  final StockUnit unit;
  final double currentStock;
  final double minThreshold;
  final double maxCapacity;
  final double costPerUnit;
  final String? supplierName;
  final String?
  originalSupplierName; // Original supplier name as entered by user (for audit trail)
  final String? supplierId;
  final String?
  supplierMappingType; // 'exact', 'auto_mapped', 'fallback_mapped', 'fallback_created'
  final double?
  supplierMatchScore; // Fuzzy match score if auto-mapped (0.0-1.0)
  final String emoji;
  final String? notes;
  final String? sku; // Stock Keeping Unit for duplicate detection
  final String?
  referenceId; // Reference ID (e.g., supplier reference) for duplicate detection

  ValidatedInventoryData({
    required this.name,
    required this.category,
    this.originalCategory,
    required this.unit,
    required this.currentStock,
    required this.minThreshold,
    required this.maxCapacity,
    required this.costPerUnit,
    this.supplierName,
    this.originalSupplierName,
    this.supplierId,
    this.supplierMappingType,
    this.supplierMatchScore,
    required this.emoji,
    this.notes,
    this.sku,
    this.referenceId,
  });

  /// Gets audit trail information for this item
  String getAuditTrail() {
    final parts = <String>[];

    if (originalCategory != null && originalCategory != category) {
      parts.add('Category mapped: $originalCategory → $category');
    }

    if (originalSupplierName != null && originalSupplierName != supplierName) {
      parts.add('Supplier mapped: $originalSupplierName → $supplierName');
      if (supplierMappingType != null) {
        parts.add('(Type: $supplierMappingType)');
      }
      if (supplierMatchScore != null) {
        parts.add(
          '(Match score: ${(supplierMatchScore! * 100).toStringAsFixed(1)}%)',
        );
      }
    }

    return parts.isNotEmpty ? parts.join(' | ') : 'No mappings applied';
  }
}

/// Service to validate and parse Excel inventory bulk upload files
class InventoryExcelValidationService {
  static const String templateSheetName = 'Inventory Data';

  // Expected column headers (required columns)
  static const List<String> requiredHeaders = [
    'Item Name',
    'Category',
    'Unit',
    'Current Stock',
    'Min Threshold',
    'Max Capacity',
    'Cost Per Unit',
    'Supplier Name',
    'Emoji',
    'Notes',
  ];

  // Optional columns for enhanced duplicate detection
  static const List<String> optionalHeaders = ['SKU', 'Reference ID'];

  // All headers (required + optional)
  static List<String> get allExpectedHeaders => [
    ...requiredHeaders,
    ...optionalHeaders,
  ];

  // Valid stock units
  static const List<String> validUnits = [
    'kg',
    'g',
    'litre',
    'ml',
    'pieces',
    'dozen',
    'packet',
    'bottle',
  ];

  /// Validates and parses an Excel inventory file
  /// Returns map with 'data' (list of ValidatedInventoryData), 'errors', and 'newCategories'
  ///
  /// Parameters:
  ///   - filePath: Path to the Excel file
  ///   - validCategories: List of existing category names
  ///   - supplierMap: Map of supplier names -> IDs (will be updated with newly created suppliers)
  ///   - businessId: Business ID (required for auto-creating suppliers)
  ///   - enableSupplierAutoCreation: If true, auto-creates missing suppliers under "Other Suppliers"
  static Future<Map<String, dynamic>> parseAndValidateExcelFile({
    required String filePath,
    required List<String> validCategories,
    required Map<String, String>
    supplierMap, // supplierName -> supplierId mapping (modified in place)
    String? businessId,
    bool enableSupplierAutoCreation = true,
  }) async {
    final List<ValidatedInventoryData> validItems = [];
    final List<InventoryValidationError> errors = [];
    final Set<String> newCategories =
        {}; // Track categories that will be created

    try {
      developer.log(
        '📦 Starting inventory Excel file validation: $filePath',
        name: 'InventoryExcelValidationService',
      );

      // Check file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        throw 'File not found: $filePath';
      }

      // Read Excel file
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Check if template sheet exists
      if (!excel.sheets.containsKey(templateSheetName)) {
        throw 'Sheet "$templateSheetName" not found in Excel file';
      }

      // Get the sheet
      final sheet = excel[templateSheetName];

      // Validate headers
      _validateHeaders(sheet, errors);

      if (errors.isNotEmpty) {
        developer.log(
          '❌ Header validation failed: ${errors.length} errors',
          name: 'InventoryExcelValidationService',
        );
        return {
          'data': <ValidatedInventoryData>[],
          'errors': errors,
          'newCategories': <String>[],
          'summary':
              'Invalid Excel template format. Please ensure column headers match the template.',
        };
      }

      // Get header column indices
      final headerIndices = _getHeaderIndices(sheet);

      // Parse data rows
      final maxRows = sheet.maxRows;
      developer.log(
        '📋 Processing $maxRows rows from sheet',
        name: 'InventoryExcelValidationService',
      );

      for (int rowIndex = 1; rowIndex < maxRows; rowIndex++) {
        try {
          // Check if row is empty (all cells are empty)
          if (_isRowEmpty(sheet, rowIndex, headerIndices)) {
            break; // Stop at first empty row to allow spacing in template
          }

          final rowData = _extractRowData(sheet, rowIndex, headerIndices);
          final validationErrors = _validateRow(
            rowData,
            rowIndex,
            validCategories,
            supplierMap,
          );

          if (validationErrors.isEmpty) {
            // Row is valid, convert to ValidatedInventoryData
            final item = await _convertToInventoryDataAsync(
              rowData,
              supplierMap,
              businessId,
              enableSupplierAutoCreation,
            );
            if (item != null) {
              validItems.add(item);

              // Track if this is a new category (case-insensitive check)
              final isNewCategory = !validCategories.any(
                (c) => c.toLowerCase() == item.category.toLowerCase(),
              );
              if (isNewCategory) {
                newCategories.add(item.category);
              }
            }
          } else {
            // Add errors for this row
            errors.addAll(validationErrors);
          }
        } catch (e) {
          errors.add(
            InventoryValidationError(
              rowNumber: rowIndex + 1,
              field: 'Row',
              error: 'Failed to parse row: $e',
            ),
          );
        }
      }

      developer.log(
        '✅ Validation complete: ${validItems.length} valid, ${errors.length} errors, ${newCategories.length} new categories',
        name: 'InventoryExcelValidationService',
      );

      return {
        'data': validItems,
        'errors': errors,
        'newCategories': newCategories.toList(),
        'summary': errors.isEmpty
            ? '✅ All ${validItems.length} items are valid!'
                  '${newCategories.isNotEmpty ? '\n📁 ${newCategories.length} new category(ies) will be created: ${newCategories.join(", ")}' : ''}'
            : '⚠️ ${validItems.length} valid items, ${errors.length} errors found',
      };
    } catch (e) {
      developer.log(
        '❌ Excel parsing error: $e',
        name: 'InventoryExcelValidationService',
        error: e,
      );
      return {
        'data': <ValidatedInventoryData>[],
        'errors': [
          InventoryValidationError(
            rowNumber: 0,
            field: 'File',
            error: 'Failed to parse Excel file: $e',
          ),
        ],
        'newCategories': <String>[],
        'summary': 'Error reading Excel file: $e',
      };
    }
  }

  /// Validates Excel file headers (required only, optional are flexible)
  static void _validateHeaders(
    Sheet sheet,
    List<InventoryValidationError> errors,
  ) {
    for (int colIndex = 0; colIndex < requiredHeaders.length; colIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      final headerValue = _getCellStringValue(cell.value);

      if (headerValue?.trim() != requiredHeaders[colIndex]) {
        errors.add(
          InventoryValidationError(
            rowNumber: 1,
            field: 'Header Column ${colIndex + 1}',
            error:
                'Expected "${requiredHeaders[colIndex]}", got "$headerValue"',
          ),
        );
      }
    }
  }

  /// Gets indices of each header column (including optional ones if present)
  static Map<String, int> _getHeaderIndices(Sheet sheet) {
    final indices = <String, int>{};

    // Add required headers
    for (int colIndex = 0; colIndex < requiredHeaders.length; colIndex++) {
      indices[requiredHeaders[colIndex]] = colIndex;
    }

    // Check for optional headers after required ones
    // Excel sheets can have many columns, so check up to a reasonable limit
    final maxColumnsToCheck =
        requiredHeaders.length + optionalHeaders.length + 10;
    for (
      int colIndex = requiredHeaders.length;
      colIndex < maxColumnsToCheck;
      colIndex++
    ) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      final headerValue = _getCellStringValue(cell.value)?.trim() ?? '';

      // Stop checking if we find an empty header (no more optional headers)
      if (headerValue.isEmpty) {
        break;
      }

      if (optionalHeaders.contains(headerValue)) {
        indices[headerValue] = colIndex;
      }
    }

    return indices;
  }

  /// Checks if a row is empty
  static bool _isRowEmpty(
    Sheet sheet,
    int rowIndex,
    Map<String, int> headerIndices,
  ) {
    // Check critical fields
    final nameCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Item Name']!,
        rowIndex: rowIndex,
      ),
    );
    final categoryCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Category']!,
        rowIndex: rowIndex,
      ),
    );
    final unitCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Unit']!,
        rowIndex: rowIndex,
      ),
    );

    return (_getCellStringValue(nameCell.value)?.isEmpty ?? true) &&
        (_getCellStringValue(categoryCell.value)?.isEmpty ?? true) &&
        (_getCellStringValue(unitCell.value)?.isEmpty ?? true);
  }

  /// Extracts row data into a map (including optional columns if present)
  static Map<String, String> _extractRowData(
    Sheet sheet,
    int rowIndex,
    Map<String, int> headerIndices,
  ) {
    final rowData = <String, String>{};

    // Extract required headers
    for (final header in requiredHeaders) {
      final colIndex = headerIndices[header]!;
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
      );
      rowData[header] = _getCellStringValue(cell.value) ?? '';
    }

    // Extract optional headers if they exist
    for (final header in optionalHeaders) {
      if (headerIndices.containsKey(header)) {
        final colIndex = headerIndices[header]!;
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
        );
        final value = _getCellStringValue(cell.value) ?? '';
        if (value.isNotEmpty) {
          rowData[header] = value;
        }
      }
    }

    return rowData;
  }

  /// Validates a single row of data with intelligent category/supplier matching
  static List<InventoryValidationError> _validateRow(
    Map<String, String> rowData,
    int rowIndex,
    List<String> validCategories,
    Map<String, String> supplierMap,
  ) {
    final errors = <InventoryValidationError>[];
    final displayRowIndex = rowIndex + 1;

    // Validate Item Name (required)
    final name = rowData['Item Name']?.trim() ?? '';
    if (name.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Item Name',
          error: 'Item Name is required',
        ),
      );
    } else if (name.length > 255) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Item Name',
          error: 'Item Name must be less than 255 characters',
        ),
      );
    }

    // Validate Category (required) - With fuzzy matching support
    final category = rowData['Category']?.trim() ?? '';
    String? validatedCategory;

    if (category.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Category',
          error: 'Category is required',
        ),
      );
    } else {
      // Try exact case-insensitive match first
      final exactMatch = validCategories.firstWhere(
        (c) => c.toLowerCase() == category.toLowerCase(),
        orElse: () => '',
      );

      if (exactMatch.isNotEmpty) {
        // Exact case-insensitive match found
        validatedCategory = exactMatch;
      } else {
        // Try fuzzy matching for partial/abbreviated names
        final fuzzyMatch = FuzzyMatchingService.findBestMatch(
          input: category,
          candidates: validCategories,
        );

        if (fuzzyMatch != null && fuzzyMatch.isMatch) {
          // Fuzzy match found (score >= 0.6)
          validatedCategory = fuzzyMatch.matchedValue;
          developer.log(
            '🔗 Category fuzzy matched: "$category" → "$validatedCategory" (${(fuzzyMatch.matchScore * 100).toStringAsFixed(1)}%) | ${fuzzyMatch.reason}',
            name: 'InventoryExcelValidationService',
          );
        } else {
          // No match - will create new category during import
          validatedCategory = category; // Use entered category as-is

          developer.log(
            '⚠️ Row $displayRowIndex: New category "$category" will be created during import',
            name: 'InventoryExcelValidationService',
          );
        }
      }
    }

    // Validate Unit (required) - With fuzzy matching for typos
    final unit = rowData['Unit']?.trim() ?? '';
    if (unit.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Unit',
          error: 'Unit is required',
        ),
      );
    } else if (!validUnits.contains(unit.toLowerCase())) {
      // Try fuzzy matching for unit misspellings
      final unitLower = unit.toLowerCase();
      final fuzzyUnitMatch = FuzzyMatchingService.findBestMatch(
        input: unitLower,
        candidates: validUnits,
      );

      if (fuzzyUnitMatch != null && fuzzyUnitMatch.isMatch) {
        // Fuzzy matched unit
        developer.log(
          '🔗 Unit fuzzy matched: "$unit" → "${fuzzyUnitMatch.matchedValue}"',
          name: 'InventoryExcelValidationService',
        );
      } else {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Unit',
            error:
                'Invalid unit "$unit". Valid units: ${validUnits.join(", ")}',
          ),
        );
      }
    }

    // Validate Current Stock (required, numeric, >= 0)
    final stockStr = rowData['Current Stock']?.trim() ?? '';
    double? currentStock;
    if (stockStr.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Current Stock',
          error: 'Current Stock is required',
        ),
      );
    } else {
      try {
        currentStock = double.parse(stockStr);
        if (currentStock < 0) {
          errors.add(
            InventoryValidationError(
              rowNumber: displayRowIndex,
              field: 'Current Stock',
              error: 'Current Stock cannot be negative',
            ),
          );
        }
      } catch (e) {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Current Stock',
            error: 'Current Stock must be a valid number (e.g., 50 or 100.5)',
            suggestedValue: 'Numeric value only',
          ),
        );
      }
    }

    // Validate Min Threshold (required, numeric, >= 0)
    final minStr = rowData['Min Threshold']?.trim() ?? '';
    double? minThreshold;
    if (minStr.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Min Threshold',
          error: 'Min Threshold is required',
        ),
      );
    } else {
      try {
        minThreshold = double.parse(minStr);
        if (minThreshold < 0) {
          errors.add(
            InventoryValidationError(
              rowNumber: displayRowIndex,
              field: 'Min Threshold',
              error: 'Min Threshold cannot be negative',
            ),
          );
        }
      } catch (e) {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Min Threshold',
            error: 'Min Threshold must be a valid number',
            suggestedValue: 'Numeric value only',
          ),
        );
      }
    }

    // Validate Max Capacity (required, numeric, > 0)
    final maxStr = rowData['Max Capacity']?.trim() ?? '';
    double? maxCapacity;
    if (maxStr.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Max Capacity',
          error: 'Max Capacity is required',
        ),
      );
    } else {
      try {
        maxCapacity = double.parse(maxStr);
        if (maxCapacity <= 0) {
          errors.add(
            InventoryValidationError(
              rowNumber: displayRowIndex,
              field: 'Max Capacity',
              error: 'Max Capacity must be greater than 0',
            ),
          );
        }
      } catch (e) {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Max Capacity',
            error: 'Max Capacity must be a valid number greater than 0',
            suggestedValue: 'Numeric value only',
          ),
        );
      }
    }

    // Validate Cost Per Unit (required, numeric, >= 0)
    final costStr = rowData['Cost Per Unit']?.trim() ?? '';
    double? costPerUnit;
    if (costStr.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Cost Per Unit',
          error: 'Cost Per Unit is required',
        ),
      );
    } else {
      try {
        costPerUnit = double.parse(costStr);
        if (costPerUnit < 0) {
          errors.add(
            InventoryValidationError(
              rowNumber: displayRowIndex,
              field: 'Cost Per Unit',
              error: 'Cost Per Unit cannot be negative',
            ),
          );
        }
      } catch (e) {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Cost Per Unit',
            error: 'Cost Per Unit must be a valid number (e.g., 150.50)',
            suggestedValue: 'Numeric value only',
          ),
        );
      }
    }

    // Validate logical consistency: Min Threshold should not exceed Max Capacity
    if (minThreshold != null &&
        maxCapacity != null &&
        minThreshold > maxCapacity) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Min Threshold / Max Capacity',
          error:
              'Min Threshold ($minThreshold) cannot exceed Max Capacity ($maxCapacity)',
        ),
      );
    }

    // Supplier Name is optional but validate if provided
    final supplierName = rowData['Supplier Name']?.trim();
    if (supplierName != null && supplierName.isNotEmpty) {
      // Just log the supplier name - we'll validate it exists when processing
      // For now, accept any non-empty supplier name (can be linked to existing or new)
    }

    return errors;
  }

  /// Converts validated row data to InventoryData object
  static ValidatedInventoryData? _convertToInventoryData(
    Map<String, String> rowData,
    Map<String, String> supplierMap,
  ) {
    try {
      final name = rowData['Item Name']!.trim();
      final category = rowData['Category']!.trim();
      final unitStr = rowData['Unit']!.trim().toLowerCase();
      final currentStock = double.parse(rowData['Current Stock']!.trim());
      final minThreshold = double.parse(rowData['Min Threshold']!.trim());
      final maxCapacity = double.parse(rowData['Max Capacity']!.trim());
      final costPerUnit = double.parse(rowData['Cost Per Unit']!.trim());

      // Convert unit string to StockUnit enum
      final unit = StockUnitExt.fromString(unitStr);

      // Get supplier ID if supplier name is provided and exists
      String? supplierName = rowData['Supplier Name']?.trim();
      String? supplierId;
      if (supplierName != null && supplierName.isNotEmpty) {
        supplierId = supplierMap[supplierName];
        // If supplier name doesn't match exactly, still include it for manual review
        // but suppress the ID to allow creation of new supplier relationship
      }

      // Get emoji
      final emoji = rowData['Emoji']?.trim() ?? '📦';

      // Get notes
      final notes = rowData['Notes']?.trim();

      // Get optional SKU and Reference ID
      final sku = rowData['SKU']?.trim();
      final referenceId = rowData['Reference ID']?.trim();

      return ValidatedInventoryData(
        name: name,
        category: category,
        unit: unit,
        currentStock: currentStock,
        minThreshold: minThreshold,
        maxCapacity: maxCapacity,
        costPerUnit: costPerUnit,
        supplierName: supplierName,
        supplierId: supplierId,
        emoji: emoji,
        notes: notes,
        sku: sku,
        referenceId: referenceId,
      );
    } catch (e) {
      developer.log(
        '❌ Error converting row data: $e',
        name: 'InventoryExcelValidationService',
        error: e,
      );
      return null;
    }
  }

  /// Converts validated row data to InventoryData with intelligent supplier/category mapping
  ///
  /// This version:
  /// 1. Validates/matches category with fuzzy matching
  /// 2. Validates supplier name with intelligent fuzzy matching and fallback
  /// 3. Auto-creates suppliers/categories if needed
  /// 4. Tracks original values for audit trail
  /// 5. Converts row to ValidatedInventoryData
  static Future<ValidatedInventoryData?> _convertToInventoryDataAsync(
    Map<String, String> rowData,
    Map<String, String> supplierMap,
    String? businessId,
    bool enableSupplierAutoCreation,
  ) async {
    try {
      final name = rowData['Item Name']!.trim();
      final unitStr = rowData['Unit']!.trim().toLowerCase();
      final currentStock = double.parse(rowData['Current Stock']!.trim());
      final minThreshold = double.parse(rowData['Min Threshold']!.trim());
      final maxCapacity = double.parse(rowData['Max Capacity']!.trim());
      final costPerUnit = double.parse(rowData['Cost Per Unit']!.trim());

      // Convert unit string to StockUnit enum
      final unit = StockUnitExt.fromString(unitStr);

      // ═══════════════════════════════════════════════════════════════════════
      // CATEGORY MAPPING WITH FUZZY MATCHING
      // ═══════════════════════════════════════════════════════════════════════
      String? categoryAsEntered = rowData['Category']?.trim();
      String? finalCategory = categoryAsEntered;

      // Attempt fuzzy matching for category if it doesn't exist
      // (This will be handled when category is created during inventory item insertion)

      // ═══════════════════════════════════════════════════════════════════════
      // SUPPLIER MAPPING WITH INTELLIGENT FUZZY MATCHING & FALLBACK
      // ═══════════════════════════════════════════════════════════════════════
      String? supplierName;
      String? originalSupplierName;
      String? supplierId;
      String? supplierMappingType;
      double? supplierMatchScore;

      final enteredSupplierName = rowData['Supplier Name']?.trim();

      if (enteredSupplierName != null &&
          enteredSupplierName.isNotEmpty &&
          enableSupplierAutoCreation &&
          businessId != null) {
        try {
          // Use intelligent supplier validation with fuzzy matching and fallback
          final mappingResult = await SupplierValidationService.instance
              .validateSupplierWithIntelligentMapping(
                supplierName: enteredSupplierName,
                supplierMap: supplierMap,
                businessId: businessId,
                useAutoMapping: true,
                createFallbackSupplier: true,
              );

          supplierId = mappingResult['id'] as String?;
          supplierName = mappingResult['name'] as String?;
          originalSupplierName = mappingResult['originalName'] as String?;
          supplierMappingType = mappingResult['mappingType'] as String?;
          supplierMatchScore = mappingResult['matchScore'] as double?;

          if (supplierId != null && supplierMappingType != 'exact') {
            developer.log(
              '🔗 Supplier intelligent mapping: "$enteredSupplierName" → "$supplierName" (${supplierMappingType})',
              name: 'InventoryExcelValidationService',
            );
          }
        } catch (e) {
          developer.log(
            '⚠️ Error validating supplier "$enteredSupplierName": $e',
            name: 'InventoryExcelValidationService',
            error: e,
          );
          // Continue without supplier ID - allow item creation even if supplier mapping fails
        }
      } else if (enteredSupplierName != null &&
          enteredSupplierName.isNotEmpty) {
        // If auto-creation is disabled, try to get ID from existing suppliers only
        originalSupplierName = enteredSupplierName;
        supplierId = supplierMap[enteredSupplierName];
        supplierName = enteredSupplierName;
        supplierMappingType = 'exact';
      }

      // Get emoji
      final emoji = rowData['Emoji']?.trim() ?? '📦';

      // Get notes and append audit trail information if mappings were applied
      String? notes = rowData['Notes']?.trim();
      if ((categoryAsEntered != null && categoryAsEntered != finalCategory) ||
          (originalSupplierName != null &&
              originalSupplierName != supplierName)) {
        final auditParts = <String>[];
        if (categoryAsEntered != null && categoryAsEntered != finalCategory) {
          auditParts.add(
            'Category mapped: $categoryAsEntered → $finalCategory',
          );
        }
        if (originalSupplierName != null &&
            originalSupplierName != supplierName) {
          auditParts.add(
            'Supplier mapped: $originalSupplierName → $supplierName (via $supplierMappingType)',
          );
        }
        final auditTrail = auditParts.join(' | ');
        notes = notes != null
            ? '$notes\n[AUDIT: $auditTrail]'
            : '[AUDIT: $auditTrail]';
      }

      // Get optional SKU and Reference ID
      final sku = rowData['SKU']?.trim();
      final referenceId = rowData['Reference ID']?.trim();

      return ValidatedInventoryData(
        name: name,
        category: finalCategory ?? categoryAsEntered ?? 'Uncategorized',
        originalCategory: categoryAsEntered,
        unit: unit,
        currentStock: currentStock,
        minThreshold: minThreshold,
        maxCapacity: maxCapacity,
        costPerUnit: costPerUnit,
        supplierName: supplierName,
        originalSupplierName: originalSupplierName,
        supplierId: supplierId,
        supplierMappingType: supplierMappingType,
        supplierMatchScore: supplierMatchScore,
        emoji: emoji,
        notes: notes,
        sku: sku,
        referenceId: referenceId,
      );
    } catch (e) {
      developer.log(
        '❌ Error converting row data (async): $e',
        name: 'InventoryExcelValidationService',
        error: e,
      );
      return null;
    }
  }

  /// Gets string value from a cell (handles different value types)
  static String? _getCellStringValue(dynamic cellValue) {
    if (cellValue == null) return null;

    // Handle different value types from excel package
    if (cellValue is String) {
      return cellValue;
    } else if (cellValue is int) {
      return cellValue.toString();
    } else if (cellValue is double) {
      return cellValue.toString();
    } else if (cellValue is bool) {
      return cellValue.toString();
    }

    return cellValue.toString();
  }

  /// Detects duplicate inventory items based on product name, SKU, and reference ID
  /// Returns a map of:
  /// - 'newItems': List of validated items with no duplicates
  /// - 'duplicates': List of duplicate items (with existing item info)
  /// - 'updates': List of items to update (quantity appended to existing)
  static Future<Map<String, dynamic>> detectAndHandleDuplicates({
    required List<ValidatedInventoryData> validatedItems,
    required List<InventoryItem> existingItems,
  }) async {
    final List<ValidatedInventoryData> newItems = [];
    final List<Map<String, dynamic>> duplicates = [];
    final List<DuplicateUpdate> updates = [];

    // Create lookup maps for efficient searching
    final nameMap = <String, InventoryItem>{};
    final skuMap = <String, InventoryItem>{};
    final refIdMap = <String, InventoryItem>{};

    for (final item in existingItems) {
      nameMap[item.name.toLowerCase().trim()] = item;
      if (item.sku != null && item.sku!.isNotEmpty) {
        skuMap[item.sku!.toLowerCase().trim()] = item;
      }
      if (item.referenceId != null && item.referenceId!.isNotEmpty) {
        refIdMap[item.referenceId!.toLowerCase().trim()] = item;
      }
    }

    for (final newItem in validatedItems) {
      InventoryItem? matchedExisting;
      String? matchReason;

      // Check for duplicates in order of priority: SKU > Reference ID > Product Name
      if (newItem.sku != null && newItem.sku!.isNotEmpty) {
        final key = newItem.sku!.toLowerCase().trim();
        if (skuMap.containsKey(key)) {
          matchedExisting = skuMap[key];
          matchReason = 'SKU match (${newItem.sku})';
        }
      }

      if (matchedExisting == null &&
          newItem.referenceId != null &&
          newItem.referenceId!.isNotEmpty) {
        final key = newItem.referenceId!.toLowerCase().trim();
        if (refIdMap.containsKey(key)) {
          matchedExisting = refIdMap[key];
          matchReason = 'Reference ID match (${newItem.referenceId})';
        }
      }

      if (matchedExisting == null) {
        final key = newItem.name.toLowerCase().trim();
        if (nameMap.containsKey(key)) {
          matchedExisting = nameMap[key];
          matchReason = 'Product name match (${newItem.name})';
        }
      }

      if (matchedExisting != null) {
        // Duplicate found
        duplicates.add({
          'newItem': newItem,
          'existingItem': matchedExisting,
          'matchReason': matchReason,
        });

        // Track for update (append stock quantity)
        updates.add(
          DuplicateUpdate(
            existingItemId: matchedExisting.id,
            existingItemName: matchedExisting.name,
            newQuantity: newItem.currentStock,
            newItemData: newItem,
            matchReason: matchReason,
          ),
        );
      } else {
        // New item, no duplicate
        newItems.add(newItem);
      }
    }

    developer.log(
      '🔍 Duplicate detection: ${newItems.length} new, ${duplicates.length} duplicates, ${updates.length} updates',
      name: 'InventoryExcelValidationService',
    );

    return {
      'newItems': newItems,
      'duplicates': duplicates,
      'updates': updates,
      'summary': {
        'total': validatedItems.length,
        'new': newItems.length,
        'duplicates': duplicates.length,
        'willUpdate': updates.length,
      },
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CATEGORY FUZZY MATCHING & VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates and maps a category name with intelligent fuzzy matching
  ///
  /// Strategy:
  /// 1. Exact case-insensitive match - return exact category
  /// 2. Fuzzy match with score >= 0.8 - return fuzzy matched category
  /// 3. Fuzzy match with score >= 0.6 - return fuzzy matched category
  /// 4. No match - return original name (will be created as new category)
  ///
  /// Returns a map with:
  /// - 'category': Final category name to use
  /// - 'original': Original category as entered
  /// - 'matched': True if a match was found
  /// - 'matchType': 'exact', 'fuzzy', or 'new'
  /// - 'matchScore': Match score if fuzzy matched (0.0-1.0)
  static Map<String, dynamic> validateCategoryWithFuzzyMatching({
    required String categoryName,
    required List<String> validCategories,
  }) {
    if (categoryName.trim().isEmpty) {
      return {
        'category': null,
        'original': categoryName,
        'matched': false,
        'matchType': 'none',
        'matchScore': 0.0,
      };
    }

    final trimmedCategory = categoryName.trim();

    // Step 1: Exact case-insensitive match
    final exactMatch = validCategories.firstWhere(
      (c) => c.toLowerCase() == trimmedCategory.toLowerCase(),
      orElse: () => '',
    );

    if (exactMatch.isNotEmpty) {
      return {
        'category': exactMatch,
        'original': trimmedCategory,
        'matched': true,
        'matchType': 'exact',
        'matchScore': 1.0,
      };
    }

    // Step 2: Fuzzy matching
    final fuzzyMatch = FuzzyMatchingService.findBestMatch(
      input: trimmedCategory,
      candidates: validCategories,
    );

    if (fuzzyMatch != null && fuzzyMatch.isMatch) {
      return {
        'category': fuzzyMatch.matchedValue,
        'original': trimmedCategory,
        'matched': true,
        'matchType': 'fuzzy',
        'matchScore': fuzzyMatch.matchScore,
      };
    }

    // Step 3: No match - will create as new category
    return {
      'category': trimmedCategory,
      'original': trimmedCategory,
      'matched': false,
      'matchType': 'new',
      'matchScore': 0.0,
    };
  }

  /// Gets all possible category matches sorted by match score
  static List<Map<String, dynamic>> getCategoryMatches({
    required String categoryName,
    required List<String> validCategories,
    double minScore = 0.5,
  }) {
    if (categoryName.trim().isEmpty) {
      return [];
    }

    final matches = FuzzyMatchingService.findAllMatches(
      input: categoryName.trim(),
      candidates: validCategories,
      minScore: minScore,
    );

    return matches
        .map(
          (match) => {
            'category': match.matchedValue,
            'matchScore': match.matchScore,
            'matchType': match.matchType,
            'reason': match.reason,
          },
        )
        .toList();
  }
}
