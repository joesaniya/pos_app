// lib/services/bill_extraction_service.dart
import 'dart:developer';
import 'dart:io';

// ══════════════════════════════════════════════════════════════════════════════
// BILL EXTRACTION SERVICE — Extract bill data from uploaded documents
// Supports: PDF, Images (JPG, PNG)
// ══════════════════════════════════════════════════════════════════════════════

class BillExtractionResult {
  final String? vendorName;
  final double? amount;
  final double? gstAmount;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final String? description;
  final bool isSuccessful;
  final String? errorMessage;

  BillExtractionResult({
    this.vendorName,
    this.amount,
    this.gstAmount,
    this.invoiceNumber,
    this.invoiceDate,
    this.description,
    this.isSuccessful = false,
    this.errorMessage,
  });

  @override
  String toString() =>
      'BillExtractionResult(vendor: $vendorName, amount: $amount, gst: $gstAmount, invoice: $invoiceNumber)';
}

class BillExtractionService {
  static final BillExtractionService _instance =
      BillExtractionService._internal();

  factory BillExtractionService() {
    return _instance;
  }

  BillExtractionService._internal();

  /// Extract bill data from uploaded file
  /// Supports: PDF, JPG, PNG, DOC, DOCX
  Future<BillExtractionResult> extractBillData(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return BillExtractionResult(
          isSuccessful: false,
          errorMessage: 'File not found: $filePath',
        );
      }

      log('🔍 Extracting bill data from: ${file.path}');

      // Get file extension
      final extension = filePath.split('.').last.toLowerCase();

      // For now, use mock extraction (can be replaced with real OCR)
      // In production, integrate with:
      // - Google ML Kit for on-device OCR
      // - Firebase ML Kit for cloud OCR
      // - Amazon Textract API for accurate extraction
      final result = await _extractFromDocument(file, extension);

      if (result.isSuccessful) {
        log('✅ Bill extraction successful: $result');
      } else {
        log('⚠️ Bill extraction failed: ${result.errorMessage}');
      }

      return result;
    } catch (e) {
      log('❌ Error during bill extraction: $e');
      return BillExtractionResult(
        isSuccessful: false,
        errorMessage: 'Extraction error: $e',
      );
    }
  }

  /// Internal extraction logic (mock implementation)
  /// TODO: Replace with real OCR implementation
  Future<BillExtractionResult> _extractFromDocument(
    File file,
    String extension,
  ) async {
    try {
      switch (extension) {
        case 'pdf':
          return await _extractFromPDF(file);
        case 'jpg':
        case 'jpeg':
        case 'png':
          return await _extractFromImage(file);
        case 'doc':
        case 'docx':
          return await _extractFromDocument(file, extension);
        default:
          return BillExtractionResult(
            isSuccessful: false,
            errorMessage: 'Unsupported file format: $extension',
          );
      }
    } catch (e) {
      return BillExtractionResult(
        isSuccessful: false,
        errorMessage: 'Extraction error: $e',
      );
    }
  }

  /// Extract data from PDF
  /// Uses file metadata and filename parsing for extraction
  Future<BillExtractionResult> _extractFromPDF(File file) async {
    log('📄 Processing PDF: ${file.path}');
    return _extractFromFilename(file);
  }

  /// Extract data from Image (JPG, PNG)
  /// Uses file metadata and filename parsing for extraction
  Future<BillExtractionResult> _extractFromImage(File file) async {
    log('🖼️ Processing Image: ${file.path}');
    return _extractFromFilename(file);
  }

  /// Extract data from filename and file properties
  /// Heuristic-based approach that works without OCR
  Future<BillExtractionResult> _extractFromFilename(File file) async {
    try {
      final filename = file.path.split('/').last;
      final fileSize = file.lengthSync();
      final stat = file.statSync();

      log('📋 Extracting from filename: $filename');
      log('📊 File size: $fileSize bytes');

      // Heuristic extraction from filename patterns
      // Common patterns: "vendor_amount_invoice.pdf" or "bill_2026-03-30.pdf"

      String? vendorName;
      double? amount;
      String? invoiceNumber;
      DateTime? invoiceDate;

      // Look for common filename patterns
      final filenamePattern = filename.toLowerCase();

      // Try to find vendor name (usually first part before underscore or special char)
      final parts = filename
          .replaceAll(RegExp(r'\.[^.]*$'), '')
          .split(RegExp(r'[-_\s]'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        vendorName = parts.first;
      }

      // Try to find amount (look for numbers that could be amounts)
      final amountRegex = RegExp(r'(\d+\.?\d*)');
      final amountMatches = amountRegex.allMatches(filenamePattern);
      if (amountMatches.isNotEmpty) {
        // Take the first large number as amount
        for (final match in amountMatches) {
          final num = double.tryParse(match.group(1) ?? '0');
          if (num != null && num > 50) {
            // Assume amounts > 50 are bill amounts
            amount = num;
            break;
          }
        }
      }

      // Try to find date in filename
      final dateRegex = RegExp(r'(\d{4})[_-](\d{2})[_-](\d{2})');
      final dateMatch = dateRegex.firstMatch(filenamePattern);
      if (dateMatch != null) {
        try {
          final year = int.parse(dateMatch.group(1) ?? '2026');
          final month = int.parse(dateMatch.group(2) ?? '3');
          final day = int.parse(dateMatch.group(3) ?? '30');
          invoiceDate = DateTime(year, month, day);
        } catch (e) {
          log('Date parsing error: $e');
        }
      }

      // Try to find invoice number
      final invoiceRegex = RegExp(r'(?:inv|#|invoice)[-_]?(\w+)');
      final invoiceMatch = invoiceRegex.firstMatch(filenamePattern);
      if (invoiceMatch != null) {
        invoiceNumber = invoiceMatch.group(1);
      }

      // Determine success based on what we extracted
      final extractedSomething =
          vendorName != null || amount != null || invoiceNumber != null;

      if (extractedSomething) {
        log('✅ Heuristic extraction successful');
        log(
          '📍 Found: vendor=$vendorName, amount=$amount, invoice=$invoiceNumber',
        );
        return BillExtractionResult(
          vendorName: vendorName,
          amount: amount,
          invoiceNumber: invoiceNumber,
          invoiceDate: invoiceDate,
          isSuccessful: true,
        );
      } else {
        // If no data found, allow user to fill manually but don't fail
        log('ℹ️ No structured data found in filename');
        return BillExtractionResult(
          vendorName: vendorName ?? 'From Bill',
          isSuccessful: false,
          errorMessage:
              'Could not auto-extract data. Please fill details manually or use a filename with pattern: vendor_amount_invoicenumber.pdf',
        );
      }
    } catch (e) {
      log('⚠️ Heuristic extraction error: $e');
      return BillExtractionResult(
        isSuccessful: false,
        errorMessage: 'Extraction error: $e. Please fill manually.',
      );
    }
  }

  /// Helper: Extract numbers from text
  static double? extractAmount(String text) {
    final regex = RegExp(
      r'(?:total|amount|price|cost)[\s:]*₹?\s*([\d,]+\.?\d*)',
    );
    final match = regex.firstMatch(text.toLowerCase());
    if (match != null) {
      final numberStr = match.group(1)?.replaceAll(',', '') ?? '';
      return double.tryParse(numberStr);
    }
    return null;
  }

  /// Helper: Extract invoice number from text
  static String? extractInvoiceNumber(String text) {
    final regex = RegExp(r'(?:invoice|inv|ref|bill)\s*[#:]?\s*(\w+[\w\d-]*)');
    final match = regex.firstMatch(text.toLowerCase());
    return match?.group(1);
  }

  /// Helper: Extract date from text
  static DateTime? extractDate(String text) {
    // Common date patterns: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
    final regex = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
    final match = regex.firstMatch(text);

    if (match != null) {
      try {
        final day = int.parse(match.group(1) ?? '1');
        final month = int.parse(match.group(2) ?? '1');
        final year = int.parse(match.group(3) ?? '2024');
        return DateTime(year, month, day);
      } catch (e) {
        log('Failed to parse date: $e');
      }
    }
    return null;
  }

  /// Helper: Extract vendor/company name
  static String? extractVendorName(String text) {
    // Look for common vendor name patterns
    final lines = text.split('\n');
    // First non-empty line is often the vendor name
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length > 3 && trimmed.length < 100) {
        return trimmed;
      }
    }
    return null;
  }
}
