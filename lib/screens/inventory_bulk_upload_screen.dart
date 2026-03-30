import 'dart:developer';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
import '../services/inventory_excel_template_service.dart';
import '../services/inventory_excel_validation_service.dart';
import '../services/file_upload_service.dart';
import '../models/inventory_modal.dart';
import '../providers/inventory_provider.dart';
import '../providers/supplier_provider.dart';
import '../repositories/inventory_repository.dart';
import '../services/storage_service.dart';
import '../screens/widgets/inventory_widgets.dart';

class InventoryBulkUploadScreen extends StatefulWidget {
  const InventoryBulkUploadScreen({super.key});

  @override
  State<InventoryBulkUploadScreen> createState() =>
      _InventoryBulkUploadScreenState();
}

class _InventoryBulkUploadScreenState extends State<InventoryBulkUploadScreen> {
  String? _selectedFilePath;
  bool _isProcessing = false;
  bool _isValidating = false;
  List<InventoryValidationError> _errors = [];
  List<ValidatedInventoryData>? _validatedData;
  String _statusMessage = '';
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    return Scaffold(
      backgroundColor: IColors.bg,
      appBar: AppBar(
        backgroundColor: IColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: IColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bulk Upload Inventory',
          style: TextStyle(
            color: IColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicators
              _buildStepIndicators(),
              const SizedBox(height: 24),

              // Main content based on state
              if (_validatedData == null || _errors.isNotEmpty)
                _buildUploadSection()
              else
                _buildConfirmationSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds step indicators
  Widget _buildStepIndicators() {
    final steps = [
      ('Download Template', _validatedData == null),
      ('Upload File', _validatedData == null || _errors.isNotEmpty),
      ('Review & Confirm', _validatedData != null && _errors.isEmpty),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < (_validatedData != null ? 2 : 0)
                        ? IColors.accent
                        : IColors.divider,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i < (_validatedData != null ? 2 : 0)
                          ? IColors.surface
                          : IColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i].$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: IColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the upload section
  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Download template card
        _buildDownloadTemplateCard(),
        const SizedBox(height: 20),

        // Upload file card
        _buildFileUploadCard(),
        const SizedBox(height: 20),

        // Validation progress/errors
        if (_errors.isNotEmpty) _buildErrorsSection(),

        // Status message
        if (_statusMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _errors.isEmpty ? IColors.inStockBg : IColors.lowStockBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _errors.isEmpty ? IColors.inStock : IColors.lowStock,
              ),
            ),
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _errors.isEmpty ? IColors.inStock : IColors.lowStock,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds download template card
  Widget _buildDownloadTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IColors.divider),
        boxShadow: [
          BoxShadow(
            color: IColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.download_rounded, color: IColors.accent, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Download Template',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get the Excel template with predefined structure',
                      style: TextStyle(
                        fontSize: 12,
                        color: IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _downloadTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: IColors.accent,
                foregroundColor: IColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          IColors.surface,
                        ),
                      ),
                    )
                  : const Text(
                      'Download Excel Template',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds file upload card
  Widget _buildFileUploadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedFilePath != null ? IColors.accent : IColors.divider,
          width: _selectedFilePath != null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedFilePath != null
                ? IColors.accent.withValues(alpha: 0.1)
                : IColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: IColors.accent, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 2: Upload File',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select your filled Excel file (.xlsx or .xls)',
                      style: TextStyle(
                        fontSize: 12,
                        color: IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedFilePath == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _selectFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IColors.accentLight,
                  foregroundColor: IColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Select Excel File',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: IColors.accent),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: IColors.inStock,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFilePath!
                                  .split(io.Platform.pathSeparator)
                                  .last,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: IColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'File selected successfully',
                              style: TextStyle(
                                fontSize: 11,
                                color: IColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _validateAndProcessFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IColors.accent,
                      foregroundColor: IColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isValidating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                IColors.surface,
                              ),
                            ),
                          )
                        : const Text(
                            'Validate & Process',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _resetSelection,
                  child: const Text('Change File'),
                ),
              ],
            ),
          if (_isProcessing && _uploadProgress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 6,
                      backgroundColor: IColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        IColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: IColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds errors section
  Widget _buildErrorsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IColors.criticalBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IColors.critical),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: IColors.critical,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validation Errors (${_errors.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IColors.critical,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please fix the errors below and try again',
                      style: TextStyle(
                        fontSize: 12,
                        color: IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < _errors.length && i < 10; i++)
                    _buildErrorItem(_errors[i]),
                  if (_errors.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${_errors.length - 10} more errors...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.critical,
              foregroundColor: IColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('Try Another File')),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds individual error item
  Widget _buildErrorItem(InventoryValidationError error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: IColors.critical.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Row ${error.rowNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IColors.critical,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error.field,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              error.error,
              style: const TextStyle(
                fontSize: 11,
                color: IColors.textSecondary,
              ),
            ),
            if (error.suggestedValue != null) ...[
              const SizedBox(height: 6),
              Text(
                'Suggested: ${error.suggestedValue}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: IColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds confirmation section
  Widget _buildConfirmationSection() {
    final count = _validatedData?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IColors.inStockBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IColors.inStock),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: IColors.inStock,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ready to Import',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'All $count items are valid and ready to import. This action cannot be undone.',
                style: const TextStyle(
                  fontSize: 13,
                  color: IColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildItemsPreview(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _importItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: IColors.inStock,
              foregroundColor: IColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        IColors.surface,
                      ),
                    ),
                  )
                : const Text(
                    'Confirm & Import All Items',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isProcessing ? null : _resetAll,
            child: const Text('Cancel & Start Over'),
          ),
        ),
      ],
    );
  }

  /// Builds items preview
  Widget _buildItemsPreview() {
    final items = _validatedData ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IColors.divider),
        boxShadow: [
          BoxShadow(
            color: IColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview (${items.length} items)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: IColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < items.length && i < 5; i++)
                    _buildPreviewItem(items[i], i),
                  if (items.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '+${items.length - 5} more items...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds individual preview item
  Widget _buildPreviewItem(ValidatedInventoryData item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: IColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IColors.divider),
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: IColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category} • ${item.unit.label} • ₹${item.costPerUnit}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _isProcessing = true);
    try {
      // Get categories from inventory provider
      final invProvider = context.read<InventoryProvider>();
      final categories = invProvider.categories
          .where((c) => c != 'All')
          .toList();

      // Get suppliers from supplier provider
      final supplierProvider = context.read<SupplierProvider>();
      final supplierNames = supplierProvider.filtered
          .map((s) => s.name)
          .toList();
      final suppliers = supplierNames.isNotEmpty
          ? supplierNames
          : ['Local Market', 'Bulk Supplier'];

      final filePath = await InventoryExcelTemplateService.generateTemplate(
        categories: categories,
        suppliers: suppliers,
      );

      if (mounted) {
        setState(() => _statusMessage = '✅ Template downloaded successfully');
        developer.log('Template saved to: $filePath');
      }
    } catch (e) {
      log('error downloading template: $e');
      if (mounted) {
        setState(() => _statusMessage = '❌ Error downloading template: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _selectFile() async {
    try {
      final result = await FileUploadService.pickExcelFile();
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() => _selectedFilePath = filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
      }
    }
  }

  Future<void> _validateAndProcessFile() async {
    if (_selectedFilePath == null) return;

    setState(() => _isValidating = true);

    try {
      // Validate file
      final validation = FileUploadService.validateExcelFile(
        filePath: _selectedFilePath!,
      );

      if (!validation.isValid) {
        if (mounted) {
          setState(() {
            _statusMessage = '❌ ${validation.errorMessage}';
            _errors = [
              InventoryValidationError(
                rowNumber: 0,
                field: 'File',
                error: validation.errorMessage ?? 'Unknown error',
                suggestedValue: validation.suggestedAction,
              ),
            ];
          });
        }
        return;
      }

      // Get reference data from providers
      final invProvider = context.read<InventoryProvider>();
      final categories = invProvider.categories
          .where((c) => c != 'All')
          .toList();

      // Get suppliers from supplier provider
      final supplierProvider = context.read<SupplierProvider>();
      final supplierMap = {
        for (var supplier in supplierProvider.filtered)
          supplier.name: supplier.id,
      };

      // Copy file to temp directory for processing
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = await FileUploadService.copyFileToTemp(
        sourceFilePath: _selectedFilePath!,
        tempDirectory: tempDir.path,
      );

      if (tempFilePath == null) {
        if (mounted) {
          setState(
            () => _statusMessage = '❌ Error preparing file for processing',
          );
        }
        return;
      }

      // Validate Excel content
      final result =
          await InventoryExcelValidationService.parseAndValidateExcelFile(
            filePath: tempFilePath,
            validCategories: categories,
            supplierMap: supplierMap,
          );

      if (mounted) {
        setState(() {
          _validatedData = result['data'] as List<ValidatedInventoryData>;
          _errors = result['errors'] as List<InventoryValidationError>;
          _statusMessage = result['summary'] as String;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = '❌ Error validating file: $e');
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _importItems() async {
    if (_validatedData == null || _validatedData!.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Get user data from storage
      final userData = await StorageService.instance.getUserData();
      final businessId = userData['businessId'] as String? ?? '';
      final userUid = userData['uid'] as String? ?? '';
      final userName = userData['name'] as String? ?? 'System';
      final userRole = userData['role'] as String? ?? 'system';

      if (businessId.isEmpty) {
        throw 'Business ID not found';
      }

      // Convert validated data to InventoryItem objects
      final uuid = const Uuid();
      final itemsToImport = _validatedData!.map((validated) {
        return InventoryItem(
          id: uuid.v4(),
          name: validated.name,
          category: validated.category,
          emoji: validated.emoji,
          currentStock: validated.currentStock,
          minThreshold: validated.minThreshold,
          maxCapacity: validated.maxCapacity,
          unit: validated.unit,
          costPerUnit: validated.costPerUnit,
          supplier: validated.supplierName ?? 'Unknown',
          supplierId: validated.supplierId,
          lastUpdated: DateTime.now(),
          notes: validated.notes,
        );
      }).toList();

      // Bulk insert via repository
      final repo = InventoryRepository.instance;
      final (successCount, failureCount, errors) = await repo.bulkInsertItems(
        items: itemsToImport,
        businessId: businessId,
        userUid: userUid,
        userName: userName,
        userRole: userRole,
      );

      if (mounted) {
        if (successCount > 0) {
          // Refresh inventory provider
          final invProvider = context.read<InventoryProvider>();
          await invProvider.fetchItems();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Successfully imported $successCount items${failureCount > 0 ? ' ($failureCount failed)' : ''}',
              ),
              backgroundColor: IColors.inStock,
              duration: const Duration(seconds: 3),
            ),
          );

          // Close screen after success
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Import failed: ${errors.join(', ')}'),
              backgroundColor: IColors.critical,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        developer.log(
          '❌ Import error: $e',
          name: 'InventoryBulkUploadScreen',
          error: e,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error importing items: $e'),
            backgroundColor: IColors.critical,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedFilePath = null;
      _errors = [];
      _statusMessage = '';
    });
  }

  void _resetAll() {
    setState(() {
      _selectedFilePath = null;
      _validatedData = null;
      _errors = [];
      _statusMessage = '';
      _uploadProgress = 0;
    });
  }
}
