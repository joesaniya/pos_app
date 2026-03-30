// lib/services/bill_extraction_service.dart
import 'dart:developer';
import 'dart:io';

// ══════════════════════════════════════════════════════════════════════════════
// BILL EXTRACTION SERVICE — Intelligent extraction from various bill formats
// Uses context-based detection instead of rigid schema matching
// Supports: PDF, Images (JPG, PNG), Documents
// ══════════════════════════════════════════════════════════════════════════════

/// Represents a single extracted candidate with confidence score
class ExtractedCandidate<T> {
  final T value;
  final double confidence; // 0.0 to 1.0
  final String?
  source; // Where was this found (filename, content, metadata, etc.)
  final String? note; // Additional context about the extraction

  ExtractedCandidate({
    required this.value,
    required this.confidence,
    this.source,
    this.note,
  });

  @override
  String toString() =>
      'Candidate($value, confidence: ${(confidence * 100).toStringAsFixed(0)}%, source: $source)';
}

/// Intelligent bill extraction result with flexible field mapping
class BillExtractionResult {
  final String? vendorName;
  final double? vendorNameConfidence;

  final double? amount;
  final double? amountConfidence;

  final double? gstAmount;
  final double? gstAmountConfidence;

  final String? invoiceNumber;
  final double? invoiceNumberConfidence;

  final DateTime? invoiceDate;
  final double? invoiceDateConfidence;

  final String? description;
  final bool isSuccessful;
  final String? errorMessage;

  // Extraction metadata
  final String? extractionMethod; // "filename", "content", "hybrid", etc.
  final Map<String, List<ExtractedCandidate>>?
  candidateLists; // Alternative extracted values

  BillExtractionResult({
    this.vendorName,
    this.vendorNameConfidence,
    this.amount,
    this.amountConfidence,
    this.gstAmount,
    this.gstAmountConfidence,
    this.invoiceNumber,
    this.invoiceNumberConfidence,
    this.invoiceDate,
    this.invoiceDateConfidence,
    this.description,
    this.isSuccessful = false,
    this.errorMessage,
    this.extractionMethod,
    this.candidateLists,
  });

  @override
  String toString() =>
      'BillExtractionResult(vendor: $vendorName (${(vendorNameConfidence ?? 0 * 100).toStringAsFixed(0)}%), amount: $amount (${(amountConfidence ?? 0 * 100).toStringAsFixed(0)}%), invoice: $invoiceNumber (${(invoiceNumberConfidence ?? 0 * 100).toStringAsFixed(0)}%))';
}

class BillExtractionService {
  static final BillExtractionService _instance =
      BillExtractionService._internal();

  factory BillExtractionService() {
    return _instance;
  }

  BillExtractionService._internal();

  /// Extract bill data from uploaded file with intelligent context-based parsing
  /// Handles various bill formats and structures flexibly
  Future<BillExtractionResult> extractBillData(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return BillExtractionResult(
          isSuccessful: false,
          errorMessage: 'File not found: $filePath',
        );
      }

      log('🔍 Intelligent extraction starting for: ${file.path}');

      // Get file extension
      final extension = filePath.split('.').last.toLowerCase();

      // Extract text content based on file type
      // In production: integrate Google ML Kit, Firebase ML Kit, or AWS Textract
      final fallbackText = await _getFallbackTextContent(file, extension);

      // Perform intelligent context-based extraction
      final result = await _performContextBasedExtraction(
        file,
        fallbackText,
        extension,
      );

      if (result.isSuccessful) {
        log('✅ Intelligent extraction successful: $result');
      } else {
        log('⚠️ Intelligent extraction partial/failed: ${result.errorMessage}');
      }

      return result;
    } catch (e) {
      log('❌ Error during intelligent extraction: $e');
      return BillExtractionResult(
        isSuccessful: false,
        errorMessage: 'Extraction error: $e',
      );
    }
  }

  /// Get fallback text content from file (filename + metadata + future OCR)
  Future<String> _getFallbackTextContent(File file, String extension) async {
    try {
      final filename = file.path.split('/').last;
      final stat = file.statSync();
      final modifiedTime = stat.modified;

      // Combine multiple text sources
      final textSources = [
        filename, // Filename often contains useful info
        modifiedTime.toString(), // File metadata
      ];

      // TODO: Add real OCR here when available
      // - Google ML Kit: for on-device OCR
      // - Firebase ML Kit: for cloud OCR
      // - Amazon Textract: for advanced document parsing
      // - Python integration: for offline deep learning models

      return textSources.join(' | ');
    } catch (e) {
      log('Failed to extract fallback text: $e');
      return '';
    }
  }

  /// Perform context-based extraction with intelligent field detection
  Future<BillExtractionResult> _performContextBasedExtraction(
    File file,
    String textContent,
    String extension,
  ) async {
    try {
      log('📊 Starting context-based extraction analysis...');

      // Extract all candidate values from content
      final amountCandidates = _extractAllAmounts(textContent);
      final invoiceCandidates = _extractAllInvoiceNumbers(textContent);
      final dateCandidates = _extractAllDates(textContent);
      final vendorCandidates = _extractAllVendorNames(textContent);

      // Select best candidates based on confidence
      final bestAmount = _selectBestCandidate(amountCandidates);
      final bestInvoice = _selectBestCandidate(invoiceCandidates);
      final bestDate = _selectBestCandidate(dateCandidates);
      final bestVendor = _selectBestCandidate(vendorCandidates);

      // Log extraction details
      log('📈 Extraction results:');
      log('  Amount candidates: ${amountCandidates.length}');
      log('  Invoice candidates: ${invoiceCandidates.length}');
      log('  Date candidates: ${dateCandidates.length}');
      log('  Vendor candidates: ${vendorCandidates.length}');

      // Check if extraction was successful (at least one high-confidence field)
      final extractedSomething = [
        bestAmount?.confidence ?? 0,
        bestInvoice?.confidence ?? 0,
        bestDate?.confidence ?? 0,
        bestVendor?.confidence ?? 0,
      ].any((confidence) => confidence >= 0.5);

      if (extractedSomething) {
        log('✅ Context-based extraction successful');
        return BillExtractionResult(
          vendorName: bestVendor?.value,
          vendorNameConfidence: bestVendor?.confidence,
          amount: bestAmount?.value,
          amountConfidence: bestAmount?.confidence,
          invoiceNumber: bestInvoice?.value,
          invoiceNumberConfidence: bestInvoice?.confidence,
          invoiceDate: bestDate?.value,
          invoiceDateConfidence: bestDate?.confidence,
          isSuccessful: true,
          extractionMethod: 'context-based',
          candidateLists: {
            'amounts': amountCandidates,
            'invoices': invoiceCandidates,
            'dates': dateCandidates,
            'vendors': vendorCandidates,
          },
        );
      } else {
        log('ℹ️ No high-confidence data found in bill');
        return BillExtractionResult(
          isSuccessful: false,
          errorMessage:
              'Could not extract structured data. Please fill bill details manually.',
          extractionMethod: 'context-based',
          candidateLists: {
            'amounts': amountCandidates,
            'invoices': invoiceCandidates,
            'dates': dateCandidates,
            'vendors': vendorCandidates,
          },
        );
      }
    } catch (e) {
      log('⚠️ Context-based extraction error: $e');
      return BillExtractionResult(
        isSuccessful: false,
        errorMessage: 'Extraction error: $e. Please fill manually.',
      );
    }
  }

  /// Extract all monetary amounts from text with context-based confidence
  List<ExtractedCandidate<double>> _extractAllAmounts(String text) {
    final candidates = <ExtractedCandidate<double>>[];

    // Pattern 1: Currency symbol + amount (e.g., ₹500, $100, Rs.250)
    final currencyPattern = RegExp(
      r'([₹$Rs\.]*)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    for (final match in currencyPattern.allMatches(text)) {
      final currencySymbol = match.group(1) ?? '';
      final numStr = (match.group(2) ?? '').replaceAll(',', '');
      final amount = double.tryParse(numStr);

      if (amount != null && amount > 0) {
        // Higher confidence if currency symbol present
        final hasCurrency = currencySymbol.isNotEmpty;
        final confidence = hasCurrency ? 0.9 : 0.7;

        // Boost confidence for reasonable bill amounts (₹50 to ₹1,00,000)
        final reasonableAmount = amount >= 50 && amount <= 100000;
        final finalConfidence = reasonableAmount
            ? confidence
            : confidence * 0.7;

        candidates.add(
          ExtractedCandidate<double>(
            value: amount,
            confidence: finalConfidence,
            source: 'currency-pattern',
            note: hasCurrency ? 'Currency symbol detected' : 'Numeric value',
          ),
        );
      }
    }

    // Pattern 2: Keywords like "Total: 500" or "Amount: 1000"
    final keywordPattern = RegExp(
      r'(?:total|amount|price|cost|charges|bill|invoice\s*value|subtotal|net)\s*[:=]?\s*(₹|Rs\.|\$)?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    for (final match in keywordPattern.allMatches(text)) {
      final numStr = (match.group(2) ?? '').replaceAll(',', '');
      final amount = double.tryParse(numStr);

      if (amount != null && amount > 0) {
        candidates.add(
          ExtractedCandidate<double>(
            value: amount,
            confidence: 0.95, // Very high confidence when keyword present
            source: 'keyword-pattern',
            note: 'Keyword-based extraction: ${match.group(0)}',
          ),
        );
      }
    }

    return candidates;
  }

  /// Extract all invoice numbers from text with context-based confidence
  List<ExtractedCandidate<String>> _extractAllInvoiceNumbers(String text) {
    final candidates = <ExtractedCandidate<String>>[];

    // Pattern 1: Keywords followed by alphanumeric (Invoice: INV-2026-001)
    final keywordPattern = RegExp(
      r'(?:invoice|bill|ref(?:erence)?|order|receipt|po|po\s*no|invoice\s*no|inv|ref\s*no)\s*[#:=]?\s*([A-Za-z0-9\-/_]+)',
      caseSensitive: false,
    );
    for (final match in keywordPattern.allMatches(text)) {
      final invoiceNum = match.group(1) ?? '';
      if (invoiceNum.isNotEmpty && invoiceNum.length < 50) {
        candidates.add(
          ExtractedCandidate<String>(
            value: invoiceNum.trim(),
            confidence: 0.95, // Very high confidence for keyword-based
            source: 'keyword-pattern',
            note: 'Invoice keyword detected: ${match.group(0)}',
          ),
        );
      }
    }

    // Pattern 2: Standalone references (INV-001, #12345, REF_ABC123)
    final standalonePattern = RegExp(
      r'(?:^|[\s\(\)])([A-Z]{2,}[-_]?\d{3,}|#\d{4,}|[A-Z]+\d{2,})',
      multiLine: true,
    );
    for (final match in standalonePattern.allMatches(text)) {
      final ref = match.group(1) ?? '';
      if (ref.isNotEmpty && ref.length < 50) {
        candidates.add(
          ExtractedCandidate<String>(
            value: ref.trim(),
            confidence: 0.75, // Medium confidence for format-only matches
            source: 'format-pattern',
            note: 'Reference number format detected',
          ),
        );
      }
    }

    return candidates;
  }

  /// Extract all dates from text with context-based confidence
  List<ExtractedCandidate<DateTime>> _extractAllDates(String text) {
    final candidates = <ExtractedCandidate<DateTime>>[];

    // Pattern 1: Standard date formats (DD/MM/YYYY, YYYY-MM-DD, DD-MM-YYYY)
    final datePattern = RegExp(r'(\d{1,4})[/\-](\d{1,2})[/\-](\d{1,4})');
    for (final match in datePattern.allMatches(text)) {
      try {
        var day = int.parse(match.group(1) ?? '1');
        var month = int.parse(match.group(2) ?? '1');
        var year = int.parse(match.group(3) ?? '2024');

        // Detect date format based on value ranges
        if (year < 32) {
          // Likely DD-MM-YY format
          final temp = day;
          day = month;
          month = temp;
          year += 2000;
        } else if (year < 100) {
          // Likely YY format
          year += 2000;
        } else if (day > 31 || day < 1) {
          // Invalid day, skip
          continue;
        } else if (month > 12 || month < 1) {
          // Invalid month, skip
          continue;
        }

        final date = DateTime(year, month, day);

        // Recent dates have higher confidence
        final daysDiff = DateTime.now().difference(date).inDays.abs();
        final confidence = daysDiff <= 365 ? 0.9 : 0.7;

        candidates.add(
          ExtractedCandidate<DateTime>(
            value: date,
            confidence: confidence,
            source: 'date-pattern',
            note: 'Date detected: ${date.toString().split(' ')[0]}',
          ),
        );
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Pattern 2: Keyword-based dates (Date: 2026-03-30)
    final keywordDatePattern = RegExp(
      r'(?:date|dated|on|invoice\s*date|bill\s*date)\s*[:=]?\s*(\d{1,4})[/\-](\d{1,2})[/\-](\d{1,4})',
      caseSensitive: false,
    );
    for (final match in keywordDatePattern.allMatches(text)) {
      try {
        var day = int.parse(match.group(1) ?? '1');
        var month = int.parse(match.group(2) ?? '1');
        var year = int.parse(match.group(3) ?? '2024');

        if (year < 32) {
          final temp = day;
          day = month;
          month = temp;
          year += 2000;
        } else if (year < 100) {
          year += 2000;
        }

        if (day > 0 && day <= 31 && month > 0 && month <= 12) {
          final date = DateTime(year, month, day);
          candidates.add(
            ExtractedCandidate<DateTime>(
              value: date,
              confidence: 0.95, // Very high for keyword-based
              source: 'keyword-date-pattern',
              note: 'Date keyword detected',
            ),
          );
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return candidates;
  }

  /// Extract all vendor/company names from text with context-based confidence
  List<ExtractedCandidate<String>> _extractAllVendorNames(String text) {
    final candidates = <ExtractedCandidate<String>>[];

    // Pattern 1: Keywords (Vendor:, Company:, From:, Bill From:)
    final keywordPattern = RegExp(
      r'(?:vendor|company|store|establishment|from|billed\s*by|bill\s*from|seller|supplier)\s*[:=]?\s*([^\n|]+)',
      caseSensitive: false,
    );
    for (final match in keywordPattern.allMatches(text)) {
      var name = (match.group(1) ?? '').trim();
      // Clean up extra characters
      name = name.replaceAll(RegExp(r'[|,;].*$'), '').trim();

      if (name.isNotEmpty && name.length > 2 && name.length < 200) {
        candidates.add(
          ExtractedCandidate<String>(
            value: name,
            confidence: 0.9,
            source: 'keyword-pattern',
            note: 'Vendor keyword detected',
          ),
        );
      }
    }

    // Pattern 2: First substantial line (often company name in bills)
    final lines = text.split(RegExp(r'[|\n]'));
    for (final line in lines) {
      final trimmed = line.trim();
      // Look for lines that look like company names:
      // - Not too short, not too long
      // - Not pure numeric
      // - Not pure URLs or emails
      if (trimmed.isNotEmpty &&
          trimmed.length > 3 &&
          trimmed.length < 100 &&
          !RegExp(r'^\d+$').hasMatch(trimmed) &&
          !trimmed.contains('@') &&
          !trimmed.startsWith('http')) {
        candidates.add(
          ExtractedCandidate<String>(
            value: trimmed,
            confidence: 0.6, // Lower confidence for unconfirmed lines
            source: 'text-line',
            note: 'Found in document text',
          ),
        );
        // Only take first few candidates
        if (candidates.length >= 5) break;
      }
    }

    return candidates;
  }

  /// Select best candidate from a list based on confidence score
  ExtractedCandidate<T>? _selectBestCandidate<T>(
    List<ExtractedCandidate<T>> candidates,
  ) {
    if (candidates.isEmpty) return null;

    // Sort by confidence (descending) and return the best
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    log('📌 Best candidate selected: ${candidates.first}');
    return candidates.first;
  }
}
