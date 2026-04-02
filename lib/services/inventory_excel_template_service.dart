import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'public_storage_service.dart';

/// Service to handle Excel template generation for bulk inventory uploads
class InventoryExcelTemplateService {
  static const String templateFileName =
      'Inventory_Bulk_Upload_Template_check.xlsx';

  // Expected column headers for inventory (required)
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

  // Optional columns for enhanced duplicate detection and data richness
  static const List<String> optionalHeaders = ['SKU', 'Reference ID'];

  // All headers (required + optional)
  static List<String> get templateHeaders => [
    ...requiredHeaders,
    ...optionalHeaders,
  ];

  // Column descriptions for user guidance
  static const Map<String, String> columnDescriptions = {
    'Item Name':
        'Name of the inventory item (e.g., "Tomatoes", "Cooking Oil") - Required',
    'Category':
        'Category of the item - must match a category from "Master Data" sheet - Required',
    'Unit':
        'Unit of measurement (kg, g, litre, ml, pieces, dozen, packet, bottle) - Required',
    'Current Stock':
        'Current quantity in stock (numeric value) - Required, cannot be negative',
    'Min Threshold':
        'Minimum stock level for alerts (numeric value) - Required, cannot be negative',
    'Max Capacity':
        'Maximum storage capacity (numeric value) - Required, must be greater than 0',
    'Cost Per Unit':
        'Cost per unit in rupees (numeric value, e.g., 150.50) - Required, cannot be negative',
    'Supplier Name':
        'Name of the primary supplier for this item - Optional but recommended',
    'Emoji':
        'Icon/emoji to represent the item (e.g., 🍅, 🍖) - Optional, improves UI',
    'Notes': 'Additional notes or remarks about the item - Optional',
    'SKU':
        'Stock Keeping Unit - Unique product identifier for duplicate detection - Optional',
    'Reference ID':
        'Reference ID (e.g., supplier product reference) for duplicate detection - Optional',
  };

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

  /// Generates an Excel template for inventory bulk upload with dynamic master data dropdowns
  /// Parameters:
  /// - categories: List of valid category names (fetched from system)
  /// - suppliers: List of valid supplier names (fetched from system)
  /// - tags: Optional list of tags for tagging inventory items
  /// - subCategories: Optional list of sub-categories for nested categorization
  ///
  /// Returns the file path of the generated template
  static Future<String?> generateTemplate({
    required List<String> categories,
    required List<String> suppliers,
    List<String>? tags,
    List<String>? subCategories,
  }) async {
    try {
      developer.log(
        '📦 Generating Excel inventory template with dynamic master data...',
        name: 'InventoryExcelTemplateService',
      );

      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // 1. Create template sheet
      _createTemplateSheet(excel);

      // 2. Create master data reference sheet
      _createMasterDataReferenceSheet(
        excel,
        categories,
        suppliers,
        tags ?? [],
        subCategories ?? [],
      );

      // 3. Create units reference sheet
      _createUnitsReferenceSheet(excel);

      // 4. Create instructions sheet
      _createInstructionsSheet(excel);

      // 5. Create sample data sheet
      _createSampleDataSheet(excel, categories, suppliers);

      // Encode Excel file to bytes
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        developer.log(
          '❌ Failed to encode Excel file',
          name: 'InventoryExcelTemplateService',
        );
        return null;
      }

      // Save to public Downloads folder using PublicStorageService
      final filePath = await PublicStorageService.saveFileToPublicDownloads(
        fileName: templateFileName,
        fileBytes: fileBytes,
      );

      if (filePath != null && filePath.isNotEmpty) {
        developer.log(
          '✅ Inventory template generated successfully: $filePath',
          name: 'InventoryExcelTemplateService',
        );
        return filePath;
      } else {
        developer.log(
          '❌ Failed to save Excel file',
          name: 'InventoryExcelTemplateService',
        );
        return null;
      }
    } catch (e) {
      developer.log(
        '❌ Error generating template: $e',
        name: 'InventoryExcelTemplateService',
        error: e,
      );
      return null;
    }
  }

  /// Creates the main template sheet with headers and formatting
  static void _createTemplateSheet(Excel excel) {
    final sheet = excel['Inventory Data'];

    // Add header row with styling
    for (int i = 0; i < templateHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(templateHeaders[i]);

      // Style header - bold and wrapped
      cell.cellStyle = CellStyle(
        bold: true,
        textWrapping: TextWrapping.WrapText,
      );
    }

    // Add 100 empty rows for data entry
    for (int row = 1; row <= 100; row++) {
      for (int col = 0; col < templateHeaders.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.cellStyle = CellStyle();
      }
    }

    // Set column widths for better readability
    sheet.setColumnWidth(0, 25); // Item Name
    sheet.setColumnWidth(1, 20); // Category
    sheet.setColumnWidth(2, 15); // Unit
    sheet.setColumnWidth(3, 15); // Current Stock
    sheet.setColumnWidth(4, 15); // Min Threshold
    sheet.setColumnWidth(5, 15); // Max Capacity
    sheet.setColumnWidth(6, 15); // Cost Per Unit
    sheet.setColumnWidth(7, 25); // Supplier Name
    sheet.setColumnWidth(8, 10); // Emoji
    sheet.setColumnWidth(9, 30); // Notes
    sheet.setColumnWidth(10, 15); // SKU
    sheet.setColumnWidth(11, 15); // Reference ID
  }

  /// Creates unified master data reference sheet with all dynamic master data
  static void _createMasterDataReferenceSheet(
    Excel excel,
    List<String> categories,
    List<String> suppliers,
    List<String> tags,
    List<String> subCategories,
  ) {
    final sheet = excel['Master Data'];

    int colIndex = 0;

    // ─── CATEGORIES ───
    {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      cell.value = TextCellValue('Categories');
      cell.cellStyle = CellStyle(bold: true);

      for (int row = 0; row < categories.length; row++) {
        final dataCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row + 1),
        );
        dataCell.value = TextCellValue(categories[row]);
      }
      sheet.setColumnWidth(colIndex, 20);
      colIndex++;
    }

    // ─── SUPPLIERS ───
    {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      cell.value = TextCellValue('Suppliers');
      cell.cellStyle = CellStyle(bold: true);

      for (int row = 0; row < suppliers.length; row++) {
        final dataCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row + 1),
        );
        dataCell.value = TextCellValue(suppliers[row]);
      }
      sheet.setColumnWidth(colIndex, 25);
      colIndex++;
    }

    // ─── UNITS ───
    {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      cell.value = TextCellValue('Units');
      cell.cellStyle = CellStyle(bold: true);

      for (int row = 0; row < validUnits.length; row++) {
        final dataCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row + 1),
        );
        dataCell.value = TextCellValue(validUnits[row]);
      }
      sheet.setColumnWidth(colIndex, 15);
      colIndex++;
    }

    // ─── TAGS (if provided) ───
    if (tags.isNotEmpty) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      cell.value = TextCellValue('Tags');
      cell.cellStyle = CellStyle(bold: true);

      for (int row = 0; row < tags.length; row++) {
        final dataCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row + 1),
        );
        dataCell.value = TextCellValue(tags[row]);
      }
      sheet.setColumnWidth(colIndex, 15);
      colIndex++;
    }

    // ─── SUB-CATEGORIES (if provided) ───
    if (subCategories.isNotEmpty) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
      );
      cell.value = TextCellValue('Sub-Categories');
      cell.cellStyle = CellStyle(bold: true);

      for (int row = 0; row < subCategories.length; row++) {
        final dataCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row + 1),
        );
        dataCell.value = TextCellValue(subCategories[row]);
      }
      sheet.setColumnWidth(colIndex, 20);
    }
  }

  /// Creates a units reference sheet
  static void _createUnitsReferenceSheet(Excel excel) {
    final sheet = excel['Units Reference'];

    // Add header
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Valid Units');

    final headerCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    headerCell.cellStyle = CellStyle(bold: true);

    // Add valid units
    for (int row = 0; row < validUnits.length; row++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1),
      );
      cell.value = TextCellValue(validUnits[row]);
    }

    sheet.setColumnWidth(0, 20);
  }

  /// Creates an instructions sheet
  static void _createInstructionsSheet(Excel excel) {
    final sheet = excel['Instructions'];

    int rowIndex = 0;

    // Title
    var titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = TextCellValue(
      'INVENTORY BULK UPLOAD TEMPLATE - INSTRUCTIONS',
    );
    titleCell.cellStyle = CellStyle(fontSize: 14, bold: true);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
    );
    rowIndex += 2;

    // Instructions
    final instructions = [
      '📋 SECTION 1: HOW TO USE THIS TEMPLATE',
      '',
      '1. FILL OUT THE "Inventory Data" SHEET:',
      '   • Enter one inventory item per row',
      '   • Start from row 2 (row 1 contains headers)',
      '   • Required fields: Item Name, Category, Unit, Current Stock, Min Threshold, Max Capacity, Cost Per Unit',
      '   • Optional fields: Supplier Name, Emoji, Notes',
      '',
      '2. COLUMN DESCRIPTIONS:',
      '   • Item Name: Name of the inventory item (e.g., "Tomatoes", "Cooking Oil")',
      '   • Category: Must match exactly from "Categories Reference" sheet (case-insensitive)',
      '   • Unit: Select from "Units Reference" sheet (kg, g, litre, ml, pieces, dozen, packet, bottle)',
      '   • Current Stock: Current quantity (numeric, e.g., 50, 100.5)',
      '   • Min Threshold: Stock alert level (numeric, cannot exceed Max Capacity)',
      '   • Max Capacity: Maximum storage capacity (numeric, must be > 0)',
      '   • Cost Per Unit: Price per unit in rupees (numeric, e.g., 150.50)',
      '   • Supplier Name: Primary supplier (optional, no validation)',
      '   • Emoji: Item icon for UI (optional, any emoji like 🍅)',
      '   • Notes: Additional details (optional)',
      '',
      '3. DATA ENTRY RULES - CRITICAL:',
      '   ✅ All REQUIRED fields must be filled',
      '   ✅ All numeric fields must be numeric (no text or currency symbols)',
      '   ✅ Current Stock ≥ 0 (cannot be negative)',
      '   ✅ Min Threshold ≥ 0 ',
      '   ✅ Max Capacity > 0 (must be positive)',
      '   ✅ Cost Per Unit ≥ 0',
      '   ✅ Category values must EXACTLY match the Categories Reference sheet',
      '   ✅ Unit values must be exactly as listed in Units Reference sheet',
      '   ✅ No empty rows between data entries (system stops at first empty row)',
      '',
      '4. VALIDATION FLOW:',
      '   Step 1: Upload the file using the app',
      '   Step 2: System validates file format (.xlsx or .xls only)',
      '   Step 3: System parses data and normalizes formats',
      '   Step 4: System validates against reference data and rules',
      '   Step 5: You receive success or detailed error report',
      '',
      '5. ERROR HANDLING:',
      '   • If ANY row has errors, NO items are imported (to maintain consistency)',
      '   • You will receive a detailed error report with:',
      '     - Row number with error',
      '     - Field name',
      '     - Error description',
      '     - Suggested fix',
      '   • Fix errors and re-upload',
      '',
      '6. TIPS FOR SUCCESS:',
      '   • Use Categories Reference to copy exact category names into Inventory Data',
      '   • Use Units Reference to select valid units',
      '   • Use Suppliers Reference as a guide (not mandatory)',
      '   • Review sample data in "Sample Data" sheet if unsure',
      '   • Start with 5-10 items first to ensure format is correct',
      '   • Do not modify template headers',
      '   • Save file before uploading',
      '',
      '7. WHAT HAPPENS AFTER UPLOAD:',
      '   ✅ Valid items are instantly added to your inventory database',
      '   ✅ Stock values are synced across all devices',
      '   ✅ Min/Max thresholds are used for low-stock alerts',
      '   ✅ Supplier links are created automatically if supplier exists',
      '',
      '❓ QUESTIONS?',
      '   • Check the "Sample Data" sheet for examples',
      '   • Refer to reference sheets for valid values',
      '   • Contact support if you encounter validation errors',
    ];

    for (final instruction in instructions) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(instruction);
      cell.cellStyle = CellStyle(
        fontSize: 10,
        textWrapping: TextWrapping.WrapText,
      );

      // Merge cells for better readability
      if (instruction.startsWith('📋') || instruction.startsWith(' ✅')) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
        );
      }

      sheet.setRowHeight(rowIndex, instruction.contains('\n') ? 40 : 20);
      rowIndex++;
    }

    sheet.setColumnWidth(0, 100);
  }

  /// Creates a sample data sheet with example entries including SKU and Reference ID
  static void _createSampleDataSheet(
    Excel excel,
    List<String> categories,
    List<String> suppliers,
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

    // Sample data - 5 realistic examples with SKU and Reference ID
    final sampleData = [
      [
        'Tomatoes',
        categories.isNotEmpty ? categories[0] : 'Vegetables',
        'kg',
        '50',
        '10',
        '100',
        '45.50',
        suppliers.isNotEmpty ? suppliers[0] : 'Local Market',
        '🍅',
        'Fresh red tomatoes, daily supply',
        'ITEM-001-TOM',
        'FARM-2026-TMAT-001',
      ],
      [
        'Cooking Oil',
        categories.length > 1 ? categories[1] : 'Oils & Spices',
        'litre',
        '20',
        '5',
        '50',
        '250',
        suppliers.length > 1 ? suppliers[1] : 'Premium Food Supplier',
        '🛢️',
        'Refined vegetable oil',
        'ITEM-002-OIL',
        'SUPP-2026-OIL-COOK',
      ],
      [
        'Chicken Breast',
        categories.isNotEmpty ? categories[0] : 'Meat & Poultry',
        'kg',
        '30',
        '5',
        '75',
        '350',
        suppliers.isNotEmpty ? suppliers[0] : 'Fresh Meat Co',
        '🍗',
        'Fresh boneless chicken breast',
        'ITEM-003-CHIC',
        'FARM-2026-CHIC-001',
      ],
      [
        'Basmati Rice',
        categories.length > 1 ? categories[1] : 'Grains & Rice',
        'kg',
        '100',
        '20',
        '200',
        '85',
        suppliers.length > 1 ? suppliers[1] : 'Bulk Supplier',
        '🍚',
        'Premium quality basmati rice',
        'ITEM-004-RICE',
        'SUPP-2026-RICE-BASM',
      ],
      [
        'All-Purpose Flour',
        categories.isNotEmpty ? categories[0] : 'Flours & Grains',
        'kg',
        '75',
        '15',
        '150',
        '35.50',
        suppliers.isNotEmpty ? suppliers.first : 'General Supplier',
        '🌾',
        'Refined all-purpose flour',
        'ITEM-005-FLOUR',
        'MILL-2026-FLOUR-APT',
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
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 25);
    sheet.setColumnWidth(8, 10);
    sheet.setColumnWidth(9, 30);
    sheet.setColumnWidth(10, 15);
    sheet.setColumnWidth(11, 15);
  }
}
