import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? expenseId; // if provided, this is edit mode

  const AddExpenseScreen({super.key, this.expenseId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _gstController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCategoryId;
  DateTime _selectedExpenseDate = DateTime.now();
  DateTime? _selectedInvoiceDate;
  String _selectedExpenseType = 'general';

  bool _isLoading = false;
  Expense? _existingExpense; // For edit mode
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.expenseId != null;
    if (_isEditMode) {
      _loadExpenseDetailsAndCategories();
    } else {
      _loadCategories();
    }
  }

  /// Load existing expense details for edit mode and categories
  void _loadExpenseDetailsAndCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final provider = context.read<ExpenseProvider>();
        log(
          '📝 [AddExpenseScreen] Loading expense for edit: ${widget.expenseId}',
        );

        // Load categories first
        if (provider.categories.isEmpty && !provider.isLoading) {
          provider.loadCategories().then((_) {
            if (mounted) setState(() {});
          });
        }

        // Load expense details
        provider
            .loadExpenseDetails(widget.expenseId!)
            .then((_) {
              if (mounted && provider.selectedExpense != null) {
                _existingExpense = provider.selectedExpense;
                _prefillFormWithExpense(_existingExpense!);
                log('✅ [AddExpenseScreen] Expense loaded and form pre-filled');
                setState(() {});
              }
            })
            .catchError((e) {
              log('❌ [AddExpenseScreen] Failed to load expense: $e');
              _showErrorSnackBar('Failed to load expense details');
            });
      } catch (e) {
        log('❌ [AddExpenseScreen] Error loading expense: $e');
      }
    });
  }

  /// Pre-fill form with existing expense details
  void _prefillFormWithExpense(Expense expense) {
    _titleController.text = expense.title;
    _descriptionController.text = expense.description ?? '';
    _vendorNameController.text = expense.vendorName;
    _amountController.text = expense.amount.toString();
    _invoiceNumberController.text = expense.invoiceNumber ?? '';
    _gstController.text = expense.gstAmount?.toString() ?? '';
    _notesController.text = expense.notes ?? '';
    _selectedCategoryId = expense.categoryId;
    _selectedExpenseDate = expense.expenseDate;
    _selectedInvoiceDate = expense.invoiceDate;
    _selectedExpenseType = expense.expenseType.dbValue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vendorNameController.dispose();
    _amountController.dispose();
    _invoiceNumberController.dispose();
    _gstController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadCategories() {
    // Use addPostFrameCallback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final provider = context.read<ExpenseProvider>();
        log('🎬 [AddExpenseScreen] _loadCategories() - reading provider');
        log(
          '🎬 [AddExpenseScreen] Provider categories count: ${provider.categories.length}',
        );
        log('🎬 [AddExpenseScreen] Provider isLoading: ${provider.isLoading}');

        if (provider.categories.isEmpty && !provider.isLoading) {
          log(
            '🎬 [AddExpenseScreen] Categories empty and not loading, calling loadCategories()',
          );
          provider
              .loadCategories()
              .then((_) {
                log(
                  '✅ [AddExpenseScreen] Categories loaded successfully - count: ${provider.categories.length}',
                );
                if (mounted) setState(() {});
              })
              .catchError((e) {
                log('❌ [AddExpenseScreen] Failed to load categories: $e');
              });
        } else {
          log(
            '🎬 [AddExpenseScreen] Categories already loaded (${provider.categories.length}) or loading in progress',
          );
        }
      } catch (e) {
        log('❌ [AddExpenseScreen] Error in _loadCategories: $e');
      }
    });
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

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ExpenseProvider>();

      if (_isEditMode && _existingExpense != null) {
        // UPDATE EXISTING EXPENSE
        log('📝 Updating expense: ${_existingExpense!.id}');

        final success = await provider.updateExpense(
          expenseId: _existingExpense!.id,
          title: _titleController.text.trim(),
          categoryId: _selectedCategoryId,
          vendorName: _vendorNameController.text.trim(),
          amount: double.parse(_amountController.text),
          expenseDate: _selectedExpenseDate,
          invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
              ? _invoiceNumberController.text.trim()
              : null,
          invoiceDate: _selectedInvoiceDate,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

        if (success && mounted) {
          _showSuccessSnackBar('Expense updated successfully!');
          log('✅ Expense updated: ${_existingExpense!.id}');
          Navigator.pop(context);
        } else if (mounted) {
          _showErrorSnackBar('Failed to update expense');
        }
      } else {
        // CREATE NEW EXPENSE
        log('✨ Creating new expense');

        final selectedCategory = provider.categories.firstWhere(
          (cat) => cat.id == _selectedCategoryId,
          orElse: () => ExpenseCategory(
            id: _selectedCategoryId ?? '',
            name: 'Uncategorized',
            icon: 'help',
            color: '#9B9B9B',
            isActive: true,
            sortOrder: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Generate expense number based on timestamp
        final expenseNumber = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final newExpense = await provider.createExpense(
          title: _titleController.text.trim(),
          expenseNumber: expenseNumber,
          categoryId: _selectedCategoryId!,
          categoryName: selectedCategory.name,
          vendorName: _vendorNameController.text.trim(),
          amount: double.parse(_amountController.text),
          expenseDate: _selectedExpenseDate,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
              ? _invoiceNumberController.text.trim()
              : null,
          invoiceDate: _selectedInvoiceDate,
          gstAmount: _gstController.text.trim().isNotEmpty
              ? double.parse(_gstController.text.trim())
              : null,
          gstNumber: null,
        );

        if (newExpense != null && mounted) {
          _showSuccessSnackBar('Expense added successfully!');
          log('✅ New expense created: ${newExpense.id}');
          Navigator.pop(context);
        } else if (mounted) {
          _showErrorSnackBar('Failed to add expense');
        }
      }
    } catch (e) {
      final action = _isEditMode ? 'update' : 'add';
      _showErrorSnackBar('Failed to $action expense: $e');
      log('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          _isEditMode ? 'Edit Expense' : 'Add Expense',
          style: AppTheme.headlineSmall,
        ),
        centerTitle: false,
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
                  // Title Section
                  _buildSectionTitle('Expense Details'),
                  SizedBox(height: 12.h),

                  // Title Field
                  _buildTextField(
                    controller: _titleController,
                    label: 'Expense Title',
                    hint: 'e.g., Building Maintenance, Event Setup',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),

                  // Category Dropdown
                  _buildCategoryDropdown(provider),
                  SizedBox(height: 12.h),

                  // Expense Type
                  _buildExpenseTypeDropdown(),
                  SizedBox(height: 12.h),

                  // Vendor Name
                  _buildTextField(
                    controller: _vendorNameController,
                    label: 'Vendor / Supplier Name',
                    hint: 'Who is providing this service?',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vendor name is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),

                  // Amount Section
                  _buildSectionTitle('Financial Details'),
                  SizedBox(height: 12.h),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _amountController,
                          label: 'Amount',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          prefixText: '₹ ',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Amount required';
                            }
                            try {
                              double.parse(value);
                              return null;
                            } catch (e) {
                              return 'Invalid amount';
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildTextField(
                          controller: _gstController,
                          label: 'GST Amount',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          prefixText: '₹ ',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Date Section
                  _buildSectionTitle('Dates'),
                  SizedBox(height: 12.h),

                  // Expense Date
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
                                'Expense Date',
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
                  SizedBox(height: 12.h),

                  // Invoice Details
                  _buildSectionTitle('Invoice Details (Optional)'),
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

                  // Additional Details
                  _buildSectionTitle('Additional Details'),
                  SizedBox(height: 12.h),

                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Add more details about this expense...',
                    maxLines: 3,
                  ),
                  SizedBox(height: 12.h),

                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Any additional notes...',
                    maxLines: 2,
                  ),
                  SizedBox(height: 24.h),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
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
                          : Text(
                              _isEditMode ? 'Update Expense' : 'Add Expense',
                              style: AppTheme.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
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
    final categories = provider.categories;
    final isLoading = provider.isLoading;

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      disabledHint: isLoading
          ? Text(
              'Loading categories...',
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : categories.isEmpty
          ? Text(
              'No categories available',
              style: AppTheme.bodySmall.copyWith(color: AppColors.error),
            )
          : null,
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
      items: categories.isEmpty
          ? []
          : categories.map((category) {
              return DropdownMenuItem(
                value: category.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16.sp,
                      color: AppColors.primaryPurple,
                    ),
                    SizedBox(width: 8.w),
                    Text(category.name),
                  ],
                ),
              );
            }).toList(),
      onChanged: isLoading || categories.isEmpty
          ? null
          : (value) {
              setState(() => _selectedCategoryId = value);
            },
      validator: (_) {
        if (_selectedCategoryId == null) return 'Please select a category';
        return null;
      },
    );
  }

  Widget _buildExpenseTypeDropdown() {
    final expenseTypes = [
      ('maintenance', 'Maintenance 🔧'),
      ('event', 'Event 🎉'),
      ('interior_work', 'Interior Work 🏠'),
      ('festival', 'Festival 🎪'),
      ('operational', 'Operational 📊'),
      ('utility', 'Utility ⚡'),
      ('general', 'General 📝'),
    ];

    return DropdownButtonFormField<String>(
      initialValue: _selectedExpenseType,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Expense Type',
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
      items: expenseTypes.map((type) {
        return DropdownMenuItem(value: type.$1, child: Text(type.$2));
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedExpenseType = value ?? 'general');
      },
    );
  }
}
