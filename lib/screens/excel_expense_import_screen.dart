import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/services/excel_template_service.dart';
import 'package:pos_app/services/excel_validation_service.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class ExcelExpenseImportScreen extends StatefulWidget {
  const ExcelExpenseImportScreen({super.key});

  @override
  State<ExcelExpenseImportScreen> createState() =>
      _ExcelExpenseImportScreenState();
}

class _ExcelExpenseImportScreenState extends State<ExcelExpenseImportScreen> {
  String? _selectedFilePath;
  bool _isProcessing = false;
  bool _isGeneratingTemplate = false;
  List<ValidatedExpenseData> _validatedExpenses = [];
  List<ExcelValidationError> _validationErrors = [];
  String _validationSummary = '';
  bool _showValidationResults = false;

  @override
  void initState() {
    super.initState();
  }

  /// Download Excel template
  Future<void> _downloadTemplate() async {
    try {
      setState(() => _isGeneratingTemplate = true);

      final provider = context.read<ExpenseProvider>();

      // Build category map for template
      final categoryMaps = provider.categories.map((cat) {
        return {
          'id': cat.id,
          'name': cat.name,
          'description': cat.description ?? '',
        };
      }).toList();

      // Generate template
      final templatePath = await ExcelTemplateService.generateTemplate(
        categories: categoryMaps,
      );

      if (templatePath != null && mounted) {
        _showSuccessSnackBar('✅ Template downloaded! Location: $templatePath');

        // Optionally open the file
        await Future.delayed(const Duration(milliseconds: 500));
        await OpenFilex.open(templatePath);
      } else if (mounted) {
        _showErrorSnackBar('Failed to generate template');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error generating template: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTemplate = false);
      }
    }
  }

  /// Select Excel file to upload
  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          setState(() {
            _selectedFilePath = filePath;
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
          _showValidationResults = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar('Validation error: $e');
      }
    }
  }

  /// Import validated expenses
  Future<void> _importExpenses() async {
    if (_validatedExpenses.isEmpty) {
      _showErrorSnackBar('No valid expenses to import');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final provider = context.read<ExpenseProvider>();

      // Import expenses with progress tracking
      final importResult = await provider.importExpensesFromExcel(
        validatedExpenses: _validatedExpenses,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        // Show import result
        _showImportResultDialog(importResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar('Import error: $e');
      }
    }
  }

  /// Show import result dialog
  void _showImportResultDialog(Map<String, dynamic> result) {
    final successCount = result['success'] as int? ?? 0;
    final failureCount = result['failed'] as int? ?? 0;
    final errors = (result['errors'] as List?)?.cast<String>() ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              failureCount == 0 ? Icons.check_circle : Icons.warning,
              color: failureCount == 0 ? AppColors.success : AppColors.warning,
              size: 28.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Import ${failureCount == 0 ? 'Successful' : 'Completed'}',
                style: AppTheme.headlineSmall,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.lightNeutral100,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('✅ Successful:', style: AppTheme.labelMedium),
                        Text(
                          '$successCount',
                          style: AppTheme.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    if (failureCount > 0) ...[
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('❌ Failed:', style: AppTheme.labelMedium),
                          Text(
                            '$failureCount',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Error list if any
              if (errors.isNotEmpty) ...[
                Text(
                  'Errors:',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  constraints: BoxConstraints(maxHeight: 200.h),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Text(
                        '• ${errors[index]}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.error,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              failureCount == 0 ? 'Done' : 'Close',
              style: AppTheme.labelMedium.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (failureCount == 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'View Expenses',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
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
            Text('Excel Expense Import', style: AppTheme.headlineSmall),
            Text(
              'Bulk upload expenses from template',
              style: AppTheme.bodySmall.copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                _buildInfoBanner(),
                SizedBox(height: 24.h),

                // Step 1: Download Template
                _buildStepCard(
                  stepNumber: 1,
                  title: '📥 Download Template',
                  description:
                      'Get the structured Excel template with all required fields',
                  content: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(
                            (0.1 * 255).toInt(),
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: AppColors.success.withAlpha(
                              (0.3 * 255).toInt(),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template includes:',
                              style: AppTheme.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            _buildFeatureItem(
                              '✓ Pre-formatted columns for all expense fields',
                            ),
                            _buildFeatureItem(
                              '✓ Data validation rules built-in',
                            ),
                            _buildFeatureItem(
                              '✓ Category reference sheet for easy selection',
                            ),
                            _buildFeatureItem(
                              '✓ Sample data showing correct format',
                            ),
                            _buildFeatureItem('✓ Detailed instructions'),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isGeneratingTemplate
                              ? null
                              : _downloadTemplate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            disabledBackgroundColor: AppColors.lightNeutral300,
                          ),
                          child: _isGeneratingTemplate
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.h,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download, size: 18.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Download Excel Template',
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
                ),
                SizedBox(height: 20.h),

                // Step 2: Upload and Validate
                _buildStepCard(
                  stepNumber: 2,
                  title: '📤 Upload & Validate',
                  description:
                      'Select your filled template and validate the data',
                  content: Column(
                    children: [
                      _buildFileUploadBox(),
                      SizedBox(height: 12.h),
                      if (_selectedFilePath != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected File:',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: AppColors.lightNeutral100,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: AppColors.lightNeutral200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    color: AppColors.primaryPurple,
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      _selectedFilePath!.split('/').last,
                                      style: AppTheme.bodySmall.copyWith(
                                        fontSize: 11.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _pickExcelFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            disabledBackgroundColor: AppColors.lightNeutral300,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                _selectedFilePath == null
                                    ? 'Select Excel File'
                                    : 'Change File',
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
                ),
                SizedBox(height: 20.h),

                // Validation Results
                if (_showValidationResults)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildValidationResultsCard(),
                      SizedBox(height: 20.h),
                    ],
                  ),

                // Step 3: Import
                if (_validatedExpenses.isNotEmpty)
                  _buildStepCard(
                    stepNumber: 3,
                    title: '✅ Import Expenses',
                    description:
                        'Click Import to add all validated expenses to your system',
                    content: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(
                              (0.1 * 255).toInt(),
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  '${_validatedExpenses.length} expense(s) ready to import',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _importExpenses,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              disabledBackgroundColor:
                                  AppColors.lightNeutral300,
                            ),
                            child: _isProcessing
                                ? SizedBox(
                                    height: 20.h,
                                    width: 20.h,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Import All Expenses',
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
                  ),

                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha((0.1 * 255).toInt()),
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha((0.3 * 255).toInt()),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primaryPurple,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Bulk Expense Import',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Import multiple expenses at once using a structured Excel template. Download the template, fill in your expense data, and upload for automatic processing.',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.primaryPurple.withAlpha((0.8 * 255).toInt()),
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String description,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.lightNeutral100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$stepNumber',
                      style: AppTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(padding: EdgeInsets.all(12.w), child: content),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: AppTheme.bodySmall.copyWith(
          color: AppColors.success,
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFileUploadBox() {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickExcelFile,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFilePath != null
                ? AppColors.success
                : AppColors.lightNeutral300,
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
                    'Choose Excel File',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'XLSX or XLS format (Max 5MB)',
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
                    'File Selected',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: _isProcessing ? null : _pickExcelFile,
                    child: Text(
                      'Change File',
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

  Widget _buildValidationResultsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _validationErrors.isEmpty
              ? AppColors.success.withAlpha((0.3 * 255).toInt())
              : AppColors.warning.withAlpha((0.3 * 255).toInt()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _validationErrors.isEmpty
                  ? AppColors.success.withAlpha((0.1 * 255).toInt())
                  : AppColors.warning.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _validationErrors.isEmpty
                      ? Icons.check_circle
                      : Icons.warning,
                  color: _validationErrors.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Validation Results',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valid Expenses',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                        Text(
                          '${_validatedExpenses.length}',
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            fontSize: 18.sp,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Errors Found',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                        Text(
                          '${_validationErrors.length}',
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _validationErrors.isEmpty
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 18.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Message
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.lightNeutral100,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    _validationSummary,
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Error details if any
                if (_validationErrors.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(
                    'Errors:',
                    style: AppTheme.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    constraints: BoxConstraints(maxHeight: 150.h),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha((0.05 * 255).toInt()),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(8.w),
                      itemCount: _validationErrors.length,
                      itemBuilder: (context, index) {
                        final error = _validationErrors[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Text(
                            '• ${error.toString()}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppColors.error,
                              fontSize: 10.sp,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
