import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/services/excel_validation_service.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:pos_app/models/expense_model.dart';

class UploadBillScreen extends StatefulWidget {
  const UploadBillScreen({super.key});

  @override
  State<UploadBillScreen> createState() => _UploadBillScreenState();
}

class _UploadBillScreenState extends State<UploadBillScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;

  bool _isProcessing = false;
  bool _isImporting = false;
  double _uploadProgress = 0;

  // Validation results
  List<ValidatedExpenseData> _validatedExpenses = [];
  List<ExcelValidationError> _validationErrors = [];
  String _validationSummary = '';
  bool _showValidationResults = false;
  bool _hasValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final provider = context.read<ExpenseProvider>();
    if (provider.categories.isEmpty) {
      provider.loadCategories();
    }
  }

  /// Pick Excel file from device
  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        final fileName = result.files.first.name;

        if (filePath != null) {
          setState(() {
            _selectedFilePath = filePath;
            _selectedFileName = fileName;
            _showValidationResults = false;
            _validatedExpenses = [];
            _validationErrors = [];
            _validationSummary = '';
          });

          // Automatically validate after selection
          await _validateExcelFile();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  /// Validate selected Excel file
  Future<void> _validateExcelFile() async {
    if (_selectedFilePath == null) {
      _showErrorSnackBar('Please select a file first');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final provider = context.read<ExpenseProvider>();

      // Build category name -> ID map
      final categoryMap = <String, String>{};
      for (final category in provider.categories) {
        categoryMap[category.name] = category.id;
      }

      // Validate Excel file
      final validationResult =
          await ExcelValidationService.parseAndValidateExcelFile(
            filePath: _selectedFilePath!,
            categoryMap: categoryMap,
          );

      if (mounted) {
        setState(() {
          _validatedExpenses = validationResult['data'] ?? [];
          _validationErrors = validationResult['errors'] ?? [];
          _validationSummary = validationResult['summary'] ?? '';
          _hasValidationErrors = (_validationErrors.isNotEmpty);
          _showValidationResults = true;
          _isProcessing = false;
        });

        // Show validation summary
        if (_hasValidationErrors && _validationErrors.isNotEmpty) {
          _showWarningSnackBar(
            'Validation issues found: ${_validationErrors.length}',
          );
        } else if (_validatedExpenses.isNotEmpty) {
          _showSuccessSnackBar(
            '✅ Ready to import ${_validatedExpenses.length} expenses',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar('Validation error: $e');
      }
    }
  }

  /// Direct import of validated expenses
  Future<void> _uploadAndImportExpenses() async {
    if (_validatedExpenses.isEmpty) {
      _showErrorSnackBar('No valid expenses to import');
      return;
    }

    // Read provider before any async operations to avoid BuildContext across async gaps warning
    final provider = context.read<ExpenseProvider>();

    if (_hasValidationErrors) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Validation Warnings'),
          content: Text(
            'There are ${_validationErrors.length} validation issues.\n\n'
            'Import the valid rows anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue Import'),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    setState(() => _isImporting = true);
    _uploadProgress = 0;

    try {
      int importedCount = 0;
      int totalCount = _validatedExpenses.length;

      // Import each expense
      for (int i = 0; i < _validatedExpenses.length; i++) {
        final expense = _validatedExpenses[i];

        try {
          // Check if expense already exists by invoice number
          Expense? existing;
          try {
            existing = provider.expenses.firstWhere(
              (e) => e.invoiceNumber == expense.invoiceNumber,
            );
          } catch (e) {
            existing = null;
          }

          if (existing != null) {
            // Update existing expense
            await provider.updateExpense(
              expenseId: existing.id,
              title: expense.title,
              categoryId: expense.categoryId,
              vendorName: expense.vendorName,
              amount: expense.amount,
              expenseDate: expense.expenseDate,
              invoiceNumber: expense.invoiceNumber,
              invoiceDate: expense.invoiceDate,
              notes: expense.notes,
            );
          } else {
            // Create new expense
            await provider.createExpense(
              title: expense.title,
              expenseNumber: (provider.expenses.length + 1),
              categoryId: expense.categoryId,
              categoryName: expense.categoryName,
              vendorName: expense.vendorName,
              amount: expense.amount,
              expenseDate: expense.expenseDate,
              invoiceNumber: expense.invoiceNumber,
              invoiceDate: expense.invoiceDate,
              gstAmount: expense.gstAmount,
              gstNumber: expense.gstNumber,
              description: expense.description,
            );
          }

          importedCount++;
          if (mounted) {
            setState(() => _uploadProgress = (i + 1) / totalCount);
          }
        } catch (e) {
          // Log error but continue with other expenses
          debugPrint('Error importing expense: $e');
        }
      }

      setState(() => _isImporting = false);

      if (mounted) {
        if (importedCount == totalCount) {
          _showSuccessSnackBar(
            '✅ Successfully imported $importedCount expenses!',
          );
          // Clear and go back after short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          _showWarningSnackBar(
            '⚠️ Imported $importedCount of $totalCount expenses',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _showErrorSnackBar('Import failed: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Direct Excel Upload', style: AppTheme.headlineSmall),
            Text(
              'One-step: Upload → Auto Database Insert',
              style: AppTheme.bodySmall.copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            _buildInfoBanner(),
            SizedBox(height: 20.h),

            // File Upload Section
            _buildFileUploadBox(),
            SizedBox(height: 16.h),

            // Validation Progress (while processing)
            if (_isProcessing)
              _buildProcessingCard()
            else if (_showValidationResults)
              // Validation Results
              _buildValidationResultsCard(),

            // Import Progress (while importing)
            if (_isImporting) _buildImportProgressCard(),

            SizedBox(height: 24.h),

            // Action Buttons
            if (!_isImporting)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        side: BorderSide(color: AppColors.lightNeutral300),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (_validatedExpenses.isEmpty ||
                              _isProcessing ||
                              _selectedFilePath == null)
                          ? null
                          : _uploadAndImportExpenses,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        disabledBackgroundColor: AppColors.lightNeutral300,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'Upload Now',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha((0.1 * 255).toInt()),
        border: Border.all(
          color: AppColors.success.withAlpha((0.3 * 255).toInt()),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.success, size: 20.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Seamless Excel Workflow',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '🚀 How it works:',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.success.withAlpha((0.8 * 255).toInt()),
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.only(left: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Upload pre-filled Excel template',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.success.withAlpha((0.7 * 255).toInt()),
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '2. System validates all data',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.success.withAlpha((0.7 * 255).toInt()),
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '3. Click Upload → Direct database insertion',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.success.withAlpha((0.7 * 255).toInt()),
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '4. No manual form entry needed!',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.success.withAlpha((0.7 * 255).toInt()),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '✓ Duplicates are updated, new data is inserted',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.success.withAlpha((0.7 * 255).toInt()),
              fontSize: 10.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadBox() {
    return GestureDetector(
      onTap: (_isProcessing || _isImporting) ? null : _pickExcelFile,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFilePath != null
                ? AppColors.success
                : AppColors.lightNeutral300,
            style: BorderStyle.solid,
            width: _selectedFilePath != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
          color: _selectedFilePath != null
              ? AppColors.success.withAlpha((0.05 * 255).toInt())
              : AppColors.lightNeutral100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_selectedFilePath == null)
              Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48.sp,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Choose an Excel File',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'XLSX or XLS format only',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48.sp,
                    color: AppColors.success,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    _selectedFileName ?? 'File Selected',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_showValidationResults &&
                      _validatedExpenses.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '✓ ${_validatedExpenses.length} valid expenses',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: (_isProcessing || _isImporting)
                        ? null
                        : _pickExcelFile,
                    child: Text(
                      'Change file',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha((0.1 * 255).toInt()),
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha((0.3 * 255).toInt()),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 24.h,
            width: 24.h,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validating Excel file...',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                    color: AppColors.primaryPurple,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Checking data format and contents',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.primaryPurple.withAlpha(
                      (0.7 * 255).toInt(),
                    ),
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResultsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _hasValidationErrors
                ? AppColors.warning.withAlpha((0.1 * 255).toInt())
                : AppColors.success.withAlpha((0.1 * 255).toInt()),
            border: Border.all(
              color: _hasValidationErrors
                  ? AppColors.warning.withAlpha((0.3 * 255).toInt())
                  : AppColors.success.withAlpha((0.3 * 255).toInt()),
            ),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(
                _hasValidationErrors ? Icons.warning : Icons.check_circle,
                color: _hasValidationErrors
                    ? AppColors.warning
                    : AppColors.success,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  _validationSummary.isNotEmpty
                      ? _validationSummary
                      : '${_validatedExpenses.length} expenses ready to import',
                  style: AppTheme.bodySmall.copyWith(
                    color: _hasValidationErrors
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Errors (if any)
        if (_validationErrors.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildSectionTitle('⚠️ Validation Issues'),
          SizedBox(height: 8.h),
          Container(
            constraints: BoxConstraints(maxHeight: 200.h),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightNeutral300),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _validationErrors.length,
              itemBuilder: (context, index) {
                final error = _validationErrors[index];
                return Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Row ${error.rowNumber}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                            ),
                            Text(
                              error.error,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 9.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // Valid Data Count
        SizedBox(height: 12.h),
        _buildSectionTitle('📋 Valid Expenses'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.lightNeutral100,
            border: Border.all(color: AppColors.lightNeutral300),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            '${_validatedExpenses.length} expense records ready to import '
            '${_hasValidationErrors ? '(with ${_validationErrors.length} issues)' : '(no issues)'}',
            style: AppTheme.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportProgressCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha((0.1 * 255).toInt()),
        border: Border.all(
          color: AppColors.success.withAlpha((0.3 * 255).toInt()),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                height: 24.h,
                width: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Importing to database...',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 6.h,
              backgroundColor: AppColors.lightNeutral200,
              valueColor: AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(0)}% complete',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.success,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.labelLarge.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13.sp,
      ),
    );
  }
}
