import 'dart:developer';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import '../services/inventory_excel_template_service.dart';
import '../services/inventory_excel_validation_service.dart';
import '../services/file_upload_service.dart';
import '../services/bulk_inventory_upload_service.dart';
import '../services/public_storage_service.dart';
import '../models/inventory_modal.dart';
import '../providers/inventory_provider.dart';
import '../providers/supplier_provider.dart';
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
  List<String> _newCategories = []; // Track categories that will be created
  String _statusMessage = '';
  double _uploadProgress = 0;
  BulkUploadResult? _uploadResult;

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
              if (_uploadResult != null)
                _buildUploadResultsSection()
              else if (_validatedData == null || _errors.isNotEmpty)
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
      ('Download Template', _validatedData == null && _uploadResult == null),
      (
        'Upload File',
        (_validatedData == null || _errors.isNotEmpty) && _uploadResult == null,
      ),
      (
        'Review & Confirm',
        _validatedData != null && _errors.isEmpty && _uploadResult == null,
      ),
      ('Import Complete', _uploadResult != null),
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
                    color:
                        i <
                            (_uploadResult != null
                                ? 3
                                : _validatedData != null
                                ? 2
                                : 0)
                        ? IColors.accent
                        : IColors.divider,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color:
                          i <
                              (_uploadResult != null
                                  ? 3
                                  : _validatedData != null
                                  ? 2
                                  : 0)
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
                'All $count items are valid and ready to import. Duplicates will be detected and handled by appending stock to existing items. This action cannot be undone.',
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

        // Show new categories section if any
        if (_newCategories.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IColors.warnBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: IColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_rounded, color: IColors.warning, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New Categories Will Be Created',
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
                  'The following ${_newCategories.length} new category(ies) will be automatically created:',
                  style: const TextStyle(
                    fontSize: 12,
                    color: IColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (String category in _newCategories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: IColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: IColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

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

  /// Builds upload results section - displays detailed results with duplicate handling
  Widget _buildUploadResultsSection() {
    if (_uploadResult == null) return const SizedBox.shrink();

    final result = _uploadResult!;
    final isSuccess =
        result.success && result.newItemsCreated + result.itemsUpdated > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success/Failure banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSuccess ? IColors.inStockBg : IColors.criticalBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSuccess ? IColors.inStock : IColors.critical,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: isSuccess ? IColors.inStock : IColors.critical,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSuccess ? 'Import Successful!' : 'Import Failed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSuccess
                                ? IColors.inStock
                                : IColors.critical,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: IColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Detailed results breakdown
        _buildResultsBreakdown(result),

        const SizedBox(height: 20),

        // Action buttons
        if (isSuccess)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IColors.inStock,
                foregroundColor: IColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _resetAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IColors.critical,
                    foregroundColor: IColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Builds detailed results breakdown with duplicate handling info
  Widget _buildResultsBreakdown(BulkUploadResult result) {
    final detailedResults = result.detailedResults;
    final createdItems = detailedResults
        .where((r) => r['action'] == 'create' && r['status'] == 'success')
        .toList();
    final updatedItems = detailedResults
        .where((r) => r['action'] == 'update' && r['status'] == 'success')
        .toList();
    final failedItems = detailedResults
        .where((r) => r['status'] == 'failed')
        .toList();

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
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                  icon: Icons.add_circle_rounded,
                  label: 'New Items',
                  count: result.newItemsCreated,
                  color: IColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultCard(
                  icon: Icons.update_rounded,
                  label: 'Updated',
                  count: result.itemsUpdated,
                  color: IColors.inStock,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                  icon: Icons.content_copy_rounded,
                  label: 'Duplicates',
                  count: result.duplicatesSkipped,
                  color: IColors.lowStock,
                ),
              ),
              if (result.errorMessages.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResultCard(
                    icon: Icons.error_outline_rounded,
                    label: 'Errors',
                    count: result.errorMessages.length,
                    color: IColors.critical,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Detailed items list
          if (createdItems.isNotEmpty) ...[
            _buildResultSection(
              title: '✅ New Items Created (${createdItems.length})',
              items: createdItems,
              color: IColors.accent,
            ),
            const SizedBox(height: 16),
          ],

          if (updatedItems.isNotEmpty) ...[
            _buildResultSection(
              title:
                  '📈 Existing Items Updated with Appended Stock (${updatedItems.length})',
              items: updatedItems,
              color: IColors.inStock,
            ),
            const SizedBox(height: 16),
          ],

          if (failedItems.isNotEmpty) ...[
            _buildResultSection(
              title: '❌ Failed Items (${failedItems.length})',
              items: failedItems,
              color: IColors.critical,
            ),
          ],
        ],
      ),
    );
  }

  /// Builds individual result card (stats)
  Widget _buildResultCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: IColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds result section with collapsible items
  Widget _buildResultSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            if (item.containsKey('error')) {
              // Failed item
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: IColors.critical,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['itemName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: IColors.textPrimary,
                            ),
                          ),
                          Text(
                            item['error'] ?? 'Unknown error',
                            style: const TextStyle(
                              fontSize: 10,
                              color: IColors.critical,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Success item
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: IColors.inStock,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['itemName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: IColors.textPrimary,
                            ),
                          ),
                          if (item['action'] == 'create')
                            Text(
                              'Created with quantity: ${item['quantity']}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: IColors.textSecondary,
                              ),
                            )
                          else
                            Text(
                              'Appended stock: +${item['quantityAdded']}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: IColors.inStock,
                              ),
                            ),
                          if (item['sku'] != null ||
                              item['referenceId'] != null)
                            Text(
                              'SKU: ${item['sku'] ?? '-'} | Ref ID: ${item['referenceId'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: IColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          }),
        ],
      ),
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
        if (filePath != null && filePath.isNotEmpty) {
          final fileName = filePath.split('/').last;
          final locationDescription =
              PublicStorageService.getLocationDescription(filePath);

          setState(
            () => _statusMessage =
                '✅ Template downloaded!\n$locationDescription\nFile: $fileName',
          );
          developer.log(
            'Template saved to: $filePath',
            name: 'InventoryBulkUploadScreen',
          );

          // Show detailed success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Template Ready!\n\nFile: $fileName\n\nLocation: $locationDescription',
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: IColors.inStock,
            ),
          );
        } else {
          setState(() => _statusMessage = '❌ Failed to generate template');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to generate template. Please try again.'),
              backgroundColor: IColors.critical,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      log('error downloading template: $e', name: 'InventoryBulkUploadScreen');
      if (mounted) {
        setState(() => _statusMessage = '❌ Error: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating template:\n${e.toString()}'),
            backgroundColor: IColors.critical,
            duration: const Duration(seconds: 4),
          ),
        );
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

      // Get business ID from storage
      final userData = await StorageService.instance.getUserData();
      final businessId = userData['businessId'] as String? ?? '';

      if (businessId.isEmpty) {
        if (mounted) {
          setState(() => _statusMessage = '❌ Business ID not found in session');
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

      // Validate Excel content with supplier auto-creation enabled
      final result =
          await InventoryExcelValidationService.parseAndValidateExcelFile(
            filePath: tempFilePath,
            validCategories: categories,
            supplierMap: supplierMap,
            businessId: businessId,
            enableSupplierAutoCreation: true,
          );

      if (mounted) {
        setState(() {
          _validatedData = result['data'] as List<ValidatedInventoryData>;
          _errors = result['errors'] as List<InventoryValidationError>;
          _newCategories = result['newCategories'] as List<String>;
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
    if (_validatedData == null || _validatedData!.isEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Get reference data from providers BEFORE async operations
      final invProvider = context.read<InventoryProvider>();
      final categories = invProvider.categories
          .where((c) => c != 'All')
          .toList();

      final supplierProvider = context.read<SupplierProvider>();
      final supplierMap = {
        for (var supplier in supplierProvider.filtered)
          supplier.name: supplier.id,
      };

      // Get user data from storage
      final userData = await StorageService.instance.getUserData();
      final businessId = userData['businessId'] as String? ?? '';
      final userUid = userData['uid'] as String? ?? '';
      final userName = userData['name'] as String? ?? 'System';
      final userRole = userData['role'] as String? ?? 'system';

      if (businessId.isEmpty) {
        throw 'Business ID not found';
      }

      if (_selectedFilePath == null) {
        throw 'File path not found';
      }

      developer.log(
        '🏷️ New categories detected and will be auto-created with items: ${_newCategories.length}',
        name: 'InventoryBulkUploadScreen',
      );

      developer.log(
        '🚀 Starting bulk upload with BulkInventoryUploadService',
        name: 'InventoryBulkUploadScreen',
      );

      // Use BulkInventoryUploadService for intelligent duplicate handling
      final result = await BulkInventoryUploadService.instance
          .processBulkUpload(
            filePath: _selectedFilePath!,
            businessId: businessId,
            userUid: userUid,
            userName: userName,
            userRole: userRole,
            validCategories: categories,
            supplierMap: supplierMap,
          );

      if (!mounted) return;

      developer.log(
        '📊 Bulk upload result: ${result.summary}',
        name: 'InventoryBulkUploadScreen',
      );

      // Display results
      setState(() => _uploadResult = result);

      // Refresh inventory provider
      await invProvider.fetchItems();

      if (!mounted) return;

      // Show detailed toast
      if (result.success && result.newItemsCreated + result.itemsUpdated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            backgroundColor: IColors.inStock,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (result.errorMessages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.errorMessages.first}'),
            backgroundColor: IColors.critical,
            duration: const Duration(seconds: 4),
          ),
        );
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
      _newCategories = [];
      _statusMessage = '';
      _uploadProgress = 0;
      _uploadResult = null;
    });
  }
}
