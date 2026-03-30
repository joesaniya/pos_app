import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class UploadBillScreen extends StatefulWidget {
  const UploadBillScreen({super.key});

  @override
  State<UploadBillScreen> createState() => _UploadBillScreenState();
}

class _UploadBillScreenState extends State<UploadBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _invoiceNumberController = TextEditingController();

  PlatformFile? _selectedFile;
  String? _selectedCategoryId;
  DateTime _selectedExpenseDate = DateTime.now();
  DateTime? _selectedInvoiceDate;

  bool _isLoading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _amountController.dispose();
    _invoiceNumberController.dispose();
    super.dispose();
  }

  void _loadCategories() {
    final provider = context.read<ExpenseProvider>();
    if (provider.categories.isEmpty) {
      provider.loadCategories();
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  Future<void> _showDatePicker(
    DateTime currentDate,
    Function(DateTime) onDateSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onDateSelected(picked);
      setState(() {});
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }
    if (_selectedFile == null) {
      _showErrorSnackBar('Please select a bill file');
      return;
    }

    setState(() => _isLoading = true);
    _uploadProgress = 0;

    try {
      final provider = context.read<ExpenseProvider>();

      // Simulate file upload progress
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _uploadProgress = 0.3);
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _uploadProgress = 0.6);

      // Create expense from bill
      final newExpense = await provider.createExpenseFromBill(
        categoryId: _selectedCategoryId!,
        vendorName: _vendorNameController.text.trim(),
        amount: double.parse(_amountController.text),
        billFilePath: 'bills/${_selectedFile!.name}', // Simulated path
        billFileName: _selectedFile!.name,
        billFileSize: _selectedFile!.size,
        invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
            ? _invoiceNumberController.text.trim()
            : null,
        expenseDate: _selectedExpenseDate,
      );

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      if (newExpense != null && mounted) {
        _showSuccessSnackBar('Bill uploaded and expense created successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload bill: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0;
        });
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
            Text('Upload Bill', style: AppTheme.headlineSmall),
            Text(
              'Auto-generate expense from bill',
              style: AppTheme.bodySmall.copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Banner
                  _buildInfoBanner(),
                  SizedBox(height: 24.h),

                  // File Upload Section
                  _buildSectionTitle('📤 Select Bill File'),
                  SizedBox(height: 12.h),
                  _buildFileUploadBox(),
                  SizedBox(height: 24.h),

                  // Expense Details Section
                  _buildSectionTitle('📝 Expense Details'),
                  SizedBox(height: 12.h),

                  _buildTextField(
                    controller: _vendorNameController,
                    label: 'Vendor / Supplier Name',
                    hint: 'Who issued this bill?',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vendor name is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),

                  // Category Dropdown
                  _buildCategoryDropdown(provider),
                  SizedBox(height: 12.h),

                  // Amount Section
                  _buildSectionTitle('💰 Amount'),
                  SizedBox(height: 12.h),

                  _buildTextField(
                    controller: _amountController,
                    label: 'Bill Amount',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    prefixText: '₹ ',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Amount is required';
                      }
                      try {
                        double.parse(value);
                        return null;
                      } catch (e) {
                        return 'Invalid amount';
                      }
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Invoice Details
                  _buildSectionTitle('🧾 Invoice Information'),
                  SizedBox(height: 12.h),

                  _buildTextField(
                    controller: _invoiceNumberController,
                    label: 'Invoice Number',
                    hint: 'e.g., INV-2026-001',
                  ),
                  SizedBox(height: 12.h),

                  GestureDetector(
                    onTap: () => _showDatePicker(
                      _selectedInvoiceDate ?? DateTime.now(),
                      (date) => setState(() => _selectedInvoiceDate = date),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lightNeutral300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice Date',
                                style: AppTheme.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _selectedInvoiceDate == null
                                    ? 'Not selected'
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedInvoiceDate!),
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                  color: _selectedInvoiceDate == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Date Section
                  _buildSectionTitle('📅 Expense Date'),
                  SizedBox(height: 12.h),

                  GestureDetector(
                    onTap: () => _showDatePicker(_selectedExpenseDate, (date) {
                      setState(() => _selectedExpenseDate = date);
                    }),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lightNeutral300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'When did this expense occur?',
                                style: AppTheme.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(_selectedExpenseDate),
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Upload Progress
                  if (_uploadProgress > 0 && _uploadProgress < 1)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            minHeight: 6.h,
                            backgroundColor: AppColors.lightNeutral200,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.success,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.success,
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        disabledBackgroundColor: AppColors.lightNeutral300,
                      ),
                      child: _isLoading
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
                                Icon(Icons.cloud_upload_outlined, size: 18.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Upload & Create Expense',
                                  style: AppTheme.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
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
                  SizedBox(height: 24.h),
                ],
              ),
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
        color: AppColors.success.withAlpha((0.1 * 255).toInt()),
        border: Border.all(
          color: AppColors.success.withAlpha((0.3 * 255).toInt()),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.success, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Upload a bill and we\'ll automatically create an expense entry with the details from the bill.',
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.success,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadBox() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickFile,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFile != null
                ? AppColors.success
                : AppColors.lightNeutral300,
            style: BorderStyle.solid,
            width: _selectedFile != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
          color: _selectedFile != null
              ? AppColors.success.withAlpha((0.05 * 255).toInt())
              : AppColors.lightNeutral100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_selectedFile == null)
              Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48.sp,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Choose a bill file',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'PDF, JPG, PNG, DOC (Max 10MB)',
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
                    _selectedFile!.name,
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${((_selectedFile!.size / 1024) / 1024).toStringAsFixed(2)} MB',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: _isLoading ? null : _pickFile,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.labelLarge.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 14.sp,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightNeutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightNeutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildCategoryDropdown(ExpenseProvider provider) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightNeutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightNeutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
      items: provider.categories.map((category) {
        return DropdownMenuItem(
          value: category.id,
          child: Row(
            children: [
              Icon(Icons.category, size: 16.sp, color: AppColors.primaryPurple),
              SizedBox(width: 8.w),
              Text(category.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedCategoryId = value);
      },
      validator: (_) {
        if (_selectedCategoryId == null) return 'Please select a category';
        return null;
      },
    );
  }
}
