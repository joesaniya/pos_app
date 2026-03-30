import 'dart:io';
import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../models/inventory_modal.dart';

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
  final StockUnit unit;
  final double currentStock;
  final double minThreshold;
  final double maxCapacity;
  final double costPerUnit;
  final String? supplierName;
  final String? supplierId;
  final String emoji;
  final String? notes;

  ValidatedInventoryData({
    required this.name,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.minThreshold,
    required this.maxCapacity,
    required this.costPerUnit,
    this.supplierName,
    this.supplierId,
    required this.emoji,
    this.notes,
  });
}

/// Service to validate and parse Excel inventory bulk upload files
class InventoryExcelValidationService {
  static const String templateSheetName = 'Inventory Data';

  // Expected column headers
  static const List<String> expectedHeaders = [
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
  /// Returns map with 'data' (list of ValidatedInventoryData) and 'errors' (list of InventoryValidationError)
  static Future<Map<String, dynamic>> parseAndValidateExcelFile({
    required String filePath,
    required List<String> validCategories,
    required Map<String, String>
    supplierMap, // supplierName -> supplierId mapping
  }) async {
    final List<ValidatedInventoryData> validItems = [];
    final List<InventoryValidationError> errors = [];

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
            final item = _convertToInventoryData(rowData, supplierMap);
            if (item != null) {
              validItems.add(item);
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
        '✅ Validation complete: ${validItems.length} valid, ${errors.length} errors',
        name: 'InventoryExcelValidationService',
      );

      return {
        'data': validItems,
        'errors': errors,
        'summary': errors.isEmpty
            ? '✅ All ${validItems.length} items are valid and ready to import!'
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
        'summary': 'Error reading Excel file: $e',
      };
    }
  }

  /// Validates Excel file headers
  static void _validateHeaders(
    Sheet sheet,
    List<InventoryValidationError> errors,
  ) {
    for (int colIndex = 0; colIndex < expectedHeaders.length; colIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      final headerValue = _getCellStringValue(cell.value);

      if (headerValue?.trim() != expectedHeaders[colIndex]) {
        errors.add(
          InventoryValidationError(
            rowNumber: 1,
            field: 'Header Column ${colIndex + 1}',
            error:
                'Expected "${expectedHeaders[colIndex]}", got "$headerValue"',
          ),
        );
      }
    }
  }

  /// Gets indices of each header column
  static Map<String, int> _getHeaderIndices(Sheet sheet) {
    final indices = <String, int>{};
    for (int colIndex = 0; colIndex < expectedHeaders.length; colIndex++) {
      indices[expectedHeaders[colIndex]] = colIndex;
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

  /// Extracts row data into a map
  static Map<String, String> _extractRowData(
    Sheet sheet,
    int rowIndex,
    Map<String, int> headerIndices,
  ) {
    final rowData = <String, String>{};

    for (final header in expectedHeaders) {
      final colIndex = headerIndices[header]!;
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
      );
      rowData[header] = _getCellStringValue(cell.value) ?? '';
    }

    return rowData;
  }

  /// Validates a single row of data
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

    // Validate Category (required)
    final category = rowData['Category']?.trim() ?? '';
    if (category.isEmpty) {
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Category',
          error: 'Category is required',
        ),
      );
    } else {
      // Case-insensitive category matching
      final matchingCategory = validCategories.firstWhere(
        (c) => c.toLowerCase() == category.toLowerCase(),
        orElse: () => '',
      );

      if (matchingCategory.isEmpty) {
        errors.add(
          InventoryValidationError(
            rowNumber: displayRowIndex,
            field: 'Category',
            error:
                'Category "$category" not found. Valid categories: ${validCategories.join(", ")}',
          ),
        );
      }
    }

    // Validate Unit (required)
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
      errors.add(
        InventoryValidationError(
          rowNumber: displayRowIndex,
          field: 'Unit',
          error: 'Invalid unit "$unit". Valid units: ${validUnits.join(", ")}',
        ),
      );
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
}
