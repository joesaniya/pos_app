import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

/// Service to handle Excel template generation and management
class ExcelTemplateService {
  static const String templateFileName = 'Expense_Template.xlsx';

  // Template column headers
  static const List<String> templateHeaders = [
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

  // Column descriptions for info sheet
  static const Map<String, String> columnDescriptions = {
    'Title':
        'Brief title of the expense (e.g., "Office Supplies", "Bill from XYZ")',
    'Vendor Name': 'Name of the vendor or supplier who issued the bill',
    'Amount': 'Total expense amount in rupees (numeric value only)',
    'Category': 'Expense category - select from the Category Reference sheet',
    'Invoice Number': 'Invoice/Bill number (optional)',
    'Invoice Date (DD/MM/YYYY)':
        'Date on the invoice in DD/MM/YYYY format (optional)',
    'GST Amount': 'GST/Tax amount if applicable (numeric value only)',
    'GST Number': 'GST registration number of the vendor (optional)',
    'Expense Date (DD/MM/YYYY)':
        'Date when the expense occurred in DD/MM/YYYY format',
    'Description': 'Detailed description of the expense',
    'Notes': 'Additional notes or remarks',
  };

  /// Generates an Excel template with instructions and sample data
  /// Returns the file path of the generated template
  static Future<String?> generateTemplate({
    required List<Map<String, String>> categories,
  }) async {
    try {
      developer.log(
        '📋 Generating Excel expense template...',
        name: 'ExcelTemplateService',
      );

      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // 1. Create template sheet
      _createTemplateSheet(excel, categories);

      // 2. Create category reference sheet
      _createCategoryReferenceSheet(excel, categories);

      // 3. Create instructions sheet
      _createInstructionsSheet(excel);

      // 4. Create sample data sheet
      _createSampleDataSheet(excel, categories);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final templateFilePath = '${directory.path}/$templateFileName';
      final file = File(templateFilePath);

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);

        developer.log(
          '✅ Template generated successfully: $templateFilePath',
          name: 'ExcelTemplateService',
        );
        return templateFilePath;
      } else {
        developer.log(
          '❌ Failed to encode Excel file',
          name: 'ExcelTemplateService',
        );
        return null;
      }
    } catch (e) {
      developer.log(
        '❌ Error generating template: $e',
        name: 'ExcelTemplateService',
        error: e,
      );
      return null;
    }
  }

  /// Creates the main template sheet with headers and formatting
  static void _createTemplateSheet(
    Excel excel,
    List<Map<String, String>> categories,
  ) {
    final sheet = excel['Template Data'];

    // Add header row with styling
    for (int i = 0; i < templateHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(templateHeaders[i]);

      // Style header
      cell.cellStyle = CellStyle(
        bold: true,
        textWrapping: TextWrapping.WrapText,
      );
    }

    // Add 20 empty rows with alternating background for data entry
    for (int row = 1; row <= 20; row++) {
      for (int col = 0; col < templateHeaders.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );

        // Row styling for data entry
        cell.cellStyle = CellStyle();
      }
    }

    // Set column widths
    sheet.setColumnWidth(0, 25); // Title
    sheet.setColumnWidth(1, 25); // Vendor Name
    sheet.setColumnWidth(2, 15); // Amount
    sheet.setColumnWidth(3, 20); // Category
    sheet.setColumnWidth(4, 18); // Invoice Number
    sheet.setColumnWidth(5, 20); // Invoice Date
    sheet.setColumnWidth(6, 15); // GST Amount
    sheet.setColumnWidth(7, 18); // GST Number
    sheet.setColumnWidth(8, 20); // Expense Date
    sheet.setColumnWidth(9, 35); // Description
    sheet.setColumnWidth(10, 30); // Notes

    // Freeze pane is handled by some Excel packages, skip if not available
  }

  /// Creates a category reference sheet showing all available categories
  static void _createCategoryReferenceSheet(
    Excel excel,
    List<Map<String, String>> categories,
  ) {
    final sheet = excel['Category Reference'];

    // Add headers
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Category Name');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('Category ID');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
        TextCellValue('Description');

    // Style headers
    for (int i = 0; i < 3; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = CellStyle(bold: true);
    }

    // Add category data
    for (int row = 0; row < categories.length; row++) {
      final category = categories[row];
      final rowIndex = row + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        category['name'] ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        category['id'] ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        category['description'] ?? '',
      );
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 40);
  }

  /// Creates an instructions sheet
  static void _createInstructionsSheet(Excel excel) {
    final sheet = excel['Instructions'];

    int rowIndex = 0;

    // Title
    var titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = TextCellValue('EXPENSE TEMPLATE INSTRUCTIONS');
    titleCell.cellStyle = CellStyle(fontSize: 16, bold: true);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
    );
    rowIndex += 2;

    // Instructions
    final instructions = [
      '1. FILL OUT THE "Template Data" SHEET:',
      '   • Enter expense details in each row',
      '   • Each row represents one expense',
      '   • Required fields: Title, Vendor Name, Amount, Category, Expense Date',
      '',
      '2. COLUMN GUIDELINES:',
      '   • Title: Brief name of the expense',
      '   • Vendor Name: Who issued the bill',
      '   • Amount: Numeric value only (e.g., 5000 NOT 5000/-)',
      '   • Category: Must match a category from "Category Reference" sheet',
      '   • Invoice Number: Optional, for reference',
      '   • Invoice Date & Expense Date: Use DD/MM/YYYY format',
      '   • GST Amount: Optional, only if applicable',
      '   • Description: Details about the expense',
      '',
      '3. VALIDATION RULES:',
      '   • All required fields must be filled',
      '   • Amount must be a valid number (no currency symbols)',
      '   • Dates must be in DD/MM/YYYY format',
      '   • Category must exist in the Category Reference sheet',
      '   • No empty rows between data entries',
      '',
      '4. BEFORE UPLOADING:',
      '   • Review all entries for accuracy',
      '   • Check that all dates are in correct format',
      '   • Verify category names match reference sheet',
      '   • Ensure all amounts are numeric values',
      '',
      '5. UPLOAD:',
      '   • Save this file with your data filled in',
      '   • Upload it using the "Upload Excel Template" option in the app',
      '   • The system will validate and process all entries automatically',
    ];

    for (final instruction in instructions) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(instruction);
      cell.cellStyle = CellStyle(
        fontSize: 11,
        textWrapping: TextWrapping.WrapText,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      sheet.setRowHeight(rowIndex, 25);
      rowIndex++;
    }

    sheet.setColumnWidth(0, 80);
  }

  /// Creates a sample data sheet with example entries
  static void _createSampleDataSheet(
    Excel excel,
    List<Map<String, String>> categories,
  ) {
    final sheet = excel['Sample Data'];

    // Add header row
    for (int i = 0; i < templateHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(templateHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Add sample data rows
    final sampleData = [
      [
        'Office Stationery',
        'ABC Supplies Ltd',
        '2500',
        categories.isNotEmpty ? categories[0]['name'] ?? 'General' : 'General',
        'INV-2026-001',
        '28/03/2026',
        '450',
        '18AABCA1234B1Z0',
        '28/03/2026',
        'Monthly office supplies purchase',
        'Ordered in bulk for Q2',
      ],
      [
        'Internet Bill',
        'Internet Provider Co',
        '1500',
        categories.length > 1 ? categories[1]['name'] ?? 'Utility' : 'Utility',
        'BILL-2026-03',
        '01/03/2026',
        '225',
        '18ABCDE5678C1Z0',
        '01/03/2026',
        'Monthly internet service',
        'High-speed connection - 1 Mbps',
      ],
      [
        'Equipment Maintenance',
        'Service Center XYZ',
        '8000',
        categories.length > 2
            ? categories[2]['name'] ?? 'Maintenance'
            : 'Maintenance',
        'SR-2026-1234',
        '25/03/2026',
        '1200',
        '',
        '25/03/2026',
        'Air conditioner servicing and repair',
        'Annual maintenance contract',
      ],
    ];

    for (int rowIdx = 0; rowIdx < sampleData.length; rowIdx++) {
      final rowData = sampleData[rowIdx];
      final actualRowIndex = rowIdx + 1;

      for (int colIdx = 0; colIdx < rowData.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIdx,
            rowIndex: actualRowIndex,
          ),
        );
        cell.value = TextCellValue(rowData[colIdx]);
        cell.cellStyle = CellStyle();
      }
    }

    // Set column widths
    for (int i = 0; i < templateHeaders.length; i++) {
      sheet.setColumnWidth(i, 25);
    }
  }
}
