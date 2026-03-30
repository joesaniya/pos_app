import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

/// Model to represent validation errors for Excel file entries
class ExcelValidationError {
  final int rowNumber;
  final String field;
  final String error;
  final String? suggestedValue;

  ExcelValidationError({
    required this.rowNumber,
    required this.field,
    required this.error,
    this.suggestedValue,
  });

  @override
  String toString() => 'Row $rowNumber, $field: $error';
}

/// Model to represent validated expense data from Excel
class ValidatedExpenseData {
  final String title;
  final String vendorName;
  final double amount;
  final String categoryId;
  final String categoryName;
  final DateTime expenseDate;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final double? gstAmount;
  final String? gstNumber;
  final String? description;
  final String? notes;

  ValidatedExpenseData({
    required this.title,
    required this.vendorName,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.expenseDate,
    this.invoiceNumber,
    this.invoiceDate,
    this.gstAmount,
    this.gstNumber,
    this.description,
    this.notes,
  });
}

/// Service to validate and parse Excel expense templates
class ExcelValidationService {
  static const String templateSheetName = 'Template Data';

  // Expected column headers
  static const List<String> expectedHeaders = [
    'Title',
    'Vendor Name',
    'Amount',
    'Category',
    'Invoice Number',
    'Invoice Date (DD/MM/YYYY)',
    'GST Amount',
    'GST Number',
    'Expense Date (DD/MM/YYYY)',
    'Description',
    'Notes',
  ];

  /// Validates and parses an Excel file
  /// Returns map with 'data' (list of ValidatedExpenseData) and 'errors' (list of ExcelValidationError)
  static Future<Map<String, dynamic>> parseAndValidateExcelFile({
    required String filePath,
    required Map<String, String>
    categoryMap, // categoryName -> categoryId mapping
  }) async {
    final List<ValidatedExpenseData> validExpenses = [];
    final List<ExcelValidationError> errors = [];

    try {
      developer.log(
        '📊 Starting Excel file validation: $filePath',
        name: 'ExcelValidationService',
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
          name: 'ExcelValidationService',
        );
        return {
          'data': <ValidatedExpenseData>[],
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
        name: 'ExcelValidationService',
      );

      for (int rowIndex = 1; rowIndex < maxRows; rowIndex++) {
        try {
          // Check if row is empty (all cells are empty)
          if (_isRowEmpty(sheet, rowIndex, headerIndices)) {
            break; // Stop at first empty row to allow spacing in template
          }

          final rowData = _extractRowData(sheet, rowIndex, headerIndices);
          final validationErrors = _validateRow(rowData, rowIndex, categoryMap);

          if (validationErrors.isEmpty) {
            // Row is valid, convert to ValidatedExpenseData
            final expense = _convertToExpenseData(rowData, categoryMap);
            if (expense != null) {
              validExpenses.add(expense);
            }
          } else {
            // Add errors for this row
            errors.addAll(validationErrors);
          }
        } catch (e) {
          errors.add(
            ExcelValidationError(
              rowNumber: rowIndex + 1,
              field: 'Row',
              error: 'Failed to parse row: $e',
            ),
          );
        }
      }

      developer.log(
        '✅ Validation complete: ${validExpenses.length} valid, ${errors.length} errors',
        name: 'ExcelValidationService',
      );

      return {
        'data': validExpenses,
        'errors': errors,
        'summary': errors.isEmpty
            ? '✅ All $validExpenses.length} expenses are valid and ready to import!'
            : '⚠️ ${validExpenses.length} valid expenses, ${errors.length} errors found',
      };
    } catch (e) {
      developer.log(
        '❌ Excel parsing error: $e',
        name: 'ExcelValidationService',
        error: e,
      );
      return {
        'data': <ValidatedExpenseData>[],
        'errors': [
          ExcelValidationError(
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
  static void _validateHeaders(Sheet sheet, List<ExcelValidationError> errors) {
    for (int colIndex = 0; colIndex < expectedHeaders.length; colIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      final headerValue = _getCellStringValue(cell.value);

      if (headerValue?.trim() != expectedHeaders[colIndex]) {
        errors.add(
          ExcelValidationError(
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
    final titleCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Title']!,
        rowIndex: rowIndex,
      ),
    );
    final vendorCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Vendor Name']!,
        rowIndex: rowIndex,
      ),
    );
    final amountCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: headerIndices['Amount']!,
        rowIndex: rowIndex,
      ),
    );

    return (_getCellStringValue(titleCell.value)?.isEmpty ?? true) &&
        (_getCellStringValue(vendorCell.value)?.isEmpty ?? true) &&
        (_getCellStringValue(amountCell.value)?.isEmpty ?? true);
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
  static List<ExcelValidationError> _validateRow(
    Map<String, String> rowData,
    int rowIndex,
    Map<String, String> categoryMap,
  ) {
    final errors = <ExcelValidationError>[];
    final displayRowIndex = rowIndex + 1;

    // Validate Title (required)
    final title = rowData['Title']?.trim() ?? '';
    if (title.isEmpty) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Title',
          error: 'Title is required',
        ),
      );
    } else if (title.length > 255) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Title',
          error: 'Title must be less than 255 characters',
        ),
      );
    }

    // Validate Vendor Name (required)
    final vendorName = rowData['Vendor Name']?.trim() ?? '';
    if (vendorName.isEmpty) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Vendor Name',
          error: 'Vendor Name is required',
        ),
      );
    }

    // Validate Amount (required, numeric)
    final amountStr = rowData['Amount']?.trim() ?? '';
    double? amount;
    if (amountStr.isEmpty) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Amount',
          error: 'Amount is required',
        ),
      );
    } else {
      try {
        amount = double.parse(amountStr);
        if (amount <= 0) {
          errors.add(
            ExcelValidationError(
              rowNumber: displayRowIndex,
              field: 'Amount',
              error: 'Amount must be greater than 0',
            ),
          );
        }
      } catch (e) {
        errors.add(
          ExcelValidationError(
            rowNumber: displayRowIndex,
            field: 'Amount',
            error: 'Amount must be a valid number (e.g., 1000.50)',
            suggestedValue: 'Numeric value only',
          ),
        );
      }
    }

    // Validate Category (required)
    final category = rowData['Category']?.trim() ?? '';
    if (category.isEmpty) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Category',
          error: 'Category is required',
        ),
      );
    } else if (!categoryMap.containsKey(category)) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Category',
          error:
              'Category "$category" not found. Valid categories: ${categoryMap.keys.join(", ")}',
        ),
      );
    }

    // Validate Expense Date (required, flexible format)
    final expenseDateStr = rowData['Expense Date (DD/MM/YYYY)']?.trim() ?? '';
    if (expenseDateStr.isEmpty) {
      errors.add(
        ExcelValidationError(
          rowNumber: displayRowIndex,
          field: 'Expense Date',
          error: 'Expense Date is required',
        ),
      );
    } else {
      try {
        _parseDate(expenseDateStr);
      } catch (e) {
        errors.add(
          ExcelValidationError(
            rowNumber: displayRowIndex,
            field: 'Expense Date',
            error:
                'Expense Date format not recognized (tried: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD)',
            suggestedValue: 'e.g., 28/03/2026 or 2026-03-28',
          ),
        );
      }
    }

    // Validate Invoice Date (optional, but must be valid if provided)
    final invoiceDateStr = rowData['Invoice Date (DD/MM/YYYY)']?.trim() ?? '';
    if (invoiceDateStr.isNotEmpty) {
      try {
        _parseDate(invoiceDateStr);
      } catch (e) {
        errors.add(
          ExcelValidationError(
            rowNumber: displayRowIndex,
            field: 'Invoice Date',
            error:
                'Invoice Date format not recognized (tried: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD) or leave empty',
            suggestedValue: 'e.g., 28/03/2026 or 2026-03-28',
          ),
        );
      }
    }

    // Validate GST Amount (optional, but must be numeric if provided)
    final gstStr = rowData['GST Amount']?.trim() ?? '';
    if (gstStr.isNotEmpty) {
      try {
        final gstAmount = double.parse(gstStr);
        if (gstAmount < 0) {
          errors.add(
            ExcelValidationError(
              rowNumber: displayRowIndex,
              field: 'GST Amount',
              error: 'GST Amount must be positive or 0',
            ),
          );
        }
      } catch (e) {
        errors.add(
          ExcelValidationError(
            rowNumber: displayRowIndex,
            field: 'GST Amount',
            error: 'GST Amount must be a valid number (or leave empty)',
          ),
        );
      }
    }

    return errors;
  }

  /// Converts validated row data to ExpenseData object
  static ValidatedExpenseData? _convertToExpenseData(
    Map<String, String> rowData,
    Map<String, String> categoryMap,
  ) {
    try {
      final title = rowData['Title']!.trim();
      final vendorName = rowData['Vendor Name']!.trim();
      final amount = double.parse(rowData['Amount']!.trim());
      final categoryName = rowData['Category']!.trim();
      final categoryId = categoryMap[categoryName]!;
      final expenseDate = _parseDate(
        rowData['Expense Date (DD/MM/YYYY)']!.trim(),
      );

      DateTime? invoiceDate;
      final invoiceDateStr = rowData['Invoice Date (DD/MM/YYYY)']?.trim();
      if (invoiceDateStr != null && invoiceDateStr.isNotEmpty) {
        invoiceDate = _parseDate(invoiceDateStr);
      }

      double? gstAmount;
      final gstStr = rowData['GST Amount']?.trim();
      if (gstStr != null && gstStr.isNotEmpty) {
        gstAmount = double.parse(gstStr);
      }

      return ValidatedExpenseData(
        title: title,
        vendorName: vendorName,
        amount: amount,
        categoryId: categoryId,
        categoryName: categoryName,
        expenseDate: expenseDate,
        invoiceNumber: rowData['Invoice Number']?.trim(),
        invoiceDate: invoiceDate,
        gstAmount: gstAmount,
        gstNumber: rowData['GST Number']?.trim(),
        description: rowData['Description']?.trim(),
        notes: rowData['Notes']?.trim(),
      );
    } catch (e) {
      developer.log(
        '❌ Error converting row data: $e',
        name: 'ExcelValidationService',
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

  /// Parses a date string in multiple flexible formats
  /// Supports: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, MM/DD/YYYY, etc.
  /// Normalizes separators and tries multiple parsing strategies
  static DateTime _parseDate(String dateStr) {
    if (dateStr.trim().isEmpty) {
      throw 'Date cannot be empty';
    }

    final cleanDate = dateStr.trim();

    // List of date format patterns to try
    // Ordered by likelihood based on context (DD/MM/YYYY is primary for expenses)
    const List<String> dateFormats = [
      'dd/MM/yyyy', // 12/03/2026
      'dd-MM-yyyy', // 12-03-2026
      'yyyy-MM-dd', // 2026-03-12
      'yyyy/MM/dd', // 2026/03/12
      'MM/dd/yyyy', // 03/12/2026
      'MM-dd-yyyy', // 03-12-2026
      'dd.MM.yyyy', // 12.03.2026
      'dd MM yyyy', // 12 03 2026
      'MMM dd, yyyy', // Mar 12, 2026
      'MMMM dd, yyyy', // March 12, 2026
      'yyyy/MM/dd HH:mm:ss', // Handle timestamps
      'dd/MM/yyyy HH:mm:ss',
    ];

    // Try each format
    for (final format in dateFormats) {
      try {
        final dateFormat = DateFormat(format);
        final parsedDate = dateFormat.parse(cleanDate);

        // Validate that the parsed date is reasonable (within ~100 years)
        final now = DateTime.now();
        if (parsedDate.year >= 1900 && parsedDate.year <= now.year + 50) {
          return parsedDate;
        }
      } catch (e) {
        // Try next format
        continue;
      }
    }

    // If all formats fail, try a more flexible string normalization approach
    try {
      return _parseFlexibleDate(cleanDate);
    } catch (e) {
      throw 'Invalid date: "$cleanDate". Accepted formats: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, or any standard date format.';
    }
  }

  /// Flexible date parser that normalizes separators and attempts parsing
  static DateTime _parseFlexibleDate(String dateStr) {
    // Normalize various separators to forward slashes
    String normalized = dateStr
        .replaceAll('-', '/')
        .replaceAll('_', '/')
        .replaceAll('.', '/')
        .replaceAll(' ', '/');

    // Remove extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Split by common separators
    final parts = normalized.split('/');

    if (parts.length < 3) {
      throw 'Date must have at least 3 parts (day, month, year)';
    }

    // Try to parse as DD/MM/YYYY or YYYY/MM/DD based on part sizes
    try {
      // Remove empty parts
      final cleanParts = parts.where((p) => p.trim().isNotEmpty).toList();

      if (cleanParts.length != 3) {
        throw 'Date must have exactly 3 parts';
      }

      int part1 = int.parse(cleanParts[0]);
      int part2 = int.parse(cleanParts[1]);
      int part3 = int.parse(cleanParts[2]);

      // Determine which part is which based on values
      int day, month, year;

      // If first part is > 31, it's likely a year (YYYY/MM/DD format)
      if (part1 > 31) {
        year = part1;
        month = part2;
        day = part3;
      } else if (part3 > 31) {
        // If last part is > 31, it's likely a year (DD/MM/YYYY format)
        day = part1;
        month = part2;
        year = part3;
      } else {
        // Ambiguous: assume DD/MM/YYYY (most common for user input)
        day = part1;
        month = part2;
        year = part3;
      }

      // Handle 2-digit years
      if (year < 100) {
        year += year < 30 ? 2000 : 1900;
      }

      // Validate date components
      if (month < 1 || month > 12) {
        throw 'Invalid month: $month';
      }

      if (day < 1 || day > 31) {
        throw 'Invalid day: $day';
      }

      // Create DateTime and let Dart validate the actual day
      final dateTime = DateTime(year, month, day);
      return dateTime;
    } catch (e) {
      throw 'Could not parse date: $dateStr. Error: $e';
    }
  }
}
