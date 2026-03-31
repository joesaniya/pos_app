import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  static const pageBg     = Color(0xFFF5F4F0);
  static const cardBg     = Color(0xFFFFFFFF);
  static const indigoSoft = Color(0xFFEEEDFD);
  static const indigo     = Color(0xFF4F46E5);
  static const emerald    = Color(0xFF059669);
  static const emeraldBg  = Color(0xFFECFDF5);
  static const amber      = Color(0xFFD97706);
  static const amberBg    = Color(0xFFFFFBEB);
  static const rose       = Color(0xFFE11D48);
  static const roseBg     = Color(0xFFFFF1F2);
  static const textPri    = Color(0xFF111827);
  static const textSec    = Color(0xFF6B7280);
  static const textTer    = Color(0xFF9CA3AF);
  static const border     = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFF3F4F6);
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT EXPENSE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddExpenseScreen extends StatefulWidget {
  final String? expenseId;
  const AddExpenseScreen({super.key, this.expenseId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _vendorCtrl      = TextEditingController();
  final _amountCtrl      = TextEditingController();
  final _invoiceCtrl     = TextEditingController();
  final _gstCtrl         = TextEditingController();
  final _notesCtrl       = TextEditingController();

  String? _selectedCategoryId;
  DateTime _expenseDate      = DateTime.now();
  DateTime? _invoiceDate;
  String _expenseType        = 'general';
  ExpensePaymentStatus _paymentStatus = ExpensePaymentStatus.unpaid;

  bool _isLoading     = false;
  bool _isEditMode    = false;
  Expense? _existing;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.expenseId != null;
    if (_isEditMode) _loadForEdit();
    else _loadCategories();
  }

  void _loadForEdit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ExpenseProvider>();
      if (provider.categories.isEmpty && !provider.isLoading) {
        provider.loadCategories().then((_) { if (mounted) setState(() {}); });
      }
      provider.loadExpenseDetails(widget.expenseId!).then((_) {
        if (mounted && provider.selectedExpense != null) {
          _existing = provider.selectedExpense;
          _prefill(_existing!);
          setState(() {});
        }
      }).catchError((e) {
        log('❌ Failed to load expense: $e');
        _snack('Failed to load expense details', _T.rose);
      });
    });
  }

  void _prefill(Expense e) {
    _titleCtrl.text   = e.title;
    _descCtrl.text    = e.description ?? '';
    _vendorCtrl.text  = e.vendorName;
    _amountCtrl.text  = e.amount.toString();
    _invoiceCtrl.text = e.invoiceNumber ?? '';
    _gstCtrl.text     = e.gstAmount?.toString() ?? '';
    _notesCtrl.text   = e.notes ?? '';
    _selectedCategoryId = e.categoryId;
    _expenseDate        = e.expenseDate;
    _invoiceDate        = e.invoiceDate;
    _expenseType        = e.expenseType.dbValue;
    _paymentStatus      = e.paymentStatus;
  }

  void _loadCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ExpenseProvider>();
      if (provider.categories.isEmpty && !provider.isLoading) {
        provider.loadCategories().then((_) { if (mounted) setState(() {}); })
            .catchError((e) => log('❌ Categories: $e'));
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl,_descCtrl,_vendorCtrl,_amountCtrl,_invoiceCtrl,_gstCtrl,_notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(DateTime current, void Function(DateTime) onPick) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _T.indigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) { onPick(picked); setState(() {}); }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _snack('Please select a category', _T.rose); return;
    }
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ExpenseProvider>();
      if (_isEditMode && _existing != null) {
        final ok = await provider.updateExpense(
          expenseId: _existing!.id,
          title: _titleCtrl.text.trim(),
          categoryId: _selectedCategoryId,
          vendorName: _vendorCtrl.text.trim(),
          amount: double.parse(_amountCtrl.text),
          expenseDate: _expenseDate,
          invoiceNumber: _invoiceCtrl.text.trim().isNotEmpty ? _invoiceCtrl.text.trim() : null,
          invoiceDate: _invoiceDate,
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        );
        if (ok && mounted) {
          _snack('Expense updated successfully!', _T.emerald);
          if (_existing!.paymentStatus != _paymentStatus) {
            await provider.updateExpensePaymentStatus(expenseId: _existing!.id, newStatus: _paymentStatus);
          }
          Navigator.pop(context);
        } else if (mounted) {
          _snack('Failed to update expense', _T.rose);
        }
      } else {
        final cat = provider.categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => ExpenseCategory(
            id: _selectedCategoryId!, name: 'Uncategorized',
            icon: 'help', color: '#9B9B9B', isActive: true,
            sortOrder: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ),
        );
        final expNo = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final newExp = await provider.createExpense(
          title: _titleCtrl.text.trim(),
          expenseNumber: expNo,
          categoryId: _selectedCategoryId!,
          categoryName: cat.name,
          vendorName: _vendorCtrl.text.trim(),
          amount: double.parse(_amountCtrl.text),
          expenseDate: _expenseDate,
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          invoiceNumber: _invoiceCtrl.text.trim().isNotEmpty ? _invoiceCtrl.text.trim() : null,
          invoiceDate: _invoiceDate,
          gstAmount: _gstCtrl.text.trim().isNotEmpty ? double.parse(_gstCtrl.text.trim()) : null,
          gstNumber: null,
        );
        if (newExp != null && mounted) {
          _snack('Expense added successfully!', _T.emerald);
          if (_paymentStatus != ExpensePaymentStatus.unpaid) {
            await provider.updateExpensePaymentStatus(expenseId: newExp.id, newStatus: _paymentStatus);
          }
          Navigator.pop(context);
        } else if (mounted) {
          _snack('Failed to add expense', _T.rose);
        }
      }
    } catch (e) {
      _snack('Error: $e', _T.rose);
      log('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: AppBar(
        backgroundColor: _T.pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.w),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36.w, height: 36.w,
              decoration: BoxDecoration(
                color: _T.cardBg, shape: BoxShape.circle,
                border: Border.all(color: _T.border),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 18.sp, color: _T.textPri),
            ),
          ),
        ),
        title: Text(
          _isEditMode ? 'Edit Expense' : 'Add Expense',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: _T.textPri),
        ),
        centerTitle: true,
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Expense Details ────────────────────────────────────
                  _sectionLabel('Expense Details'),
                  SizedBox(height: 10.h),
                  _field(
                    controller: _titleCtrl,
                    label: 'Expense Title',
                    hint: 'e.g., Building Maintenance',
                    validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  SizedBox(height: 10.h),
                  _categoryDropdown(provider),
                  SizedBox(height: 10.h),
                  _expenseTypeDropdown(),
                  SizedBox(height: 10.h),
                  _field(
                    controller: _vendorCtrl,
                    label: 'Vendor / Supplier Name',
                    hint: 'Who is providing this service?',
                    validator: (v) => (v == null || v.isEmpty) ? 'Vendor name is required' : null,
                  ),

                  // ── Financial Details ──────────────────────────────────
                  SizedBox(height: 20.h),
                  _sectionLabel('Financial Details'),
                  SizedBox(height: 10.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          controller: _amountCtrl,
                          label: 'Amount',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          prefixText: '₹ ',
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _field(
                          controller: _gstCtrl,
                          label: 'GST Amount',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          prefixText: '₹ ',
                        ),
                      ),
                    ],
                  ),

                  // ── Payment Status ─────────────────────────────────────
                  SizedBox(height: 20.h),
                  _sectionLabel('Payment Status'),
                  SizedBox(height: 10.h),
                  _paymentStatusPicker(),

                  // ── Dates ──────────────────────────────────────────────
                  SizedBox(height: 20.h),
                  _sectionLabel('Dates'),
                  SizedBox(height: 10.h),
                  _datePicker(
                    label: 'Expense Date',
                    date: _expenseDate,
                    onTap: () => _pickDate(_expenseDate, (d) => _expenseDate = d),
                  ),

                  // ── Invoice ────────────────────────────────────────────
                  SizedBox(height: 20.h),
                  _sectionLabel('Invoice Details (Optional)'),
                  SizedBox(height: 10.h),
                  _field(controller: _invoiceCtrl, label: 'Invoice Number', hint: 'e.g., INV-2026-001'),
                  SizedBox(height: 10.h),
                  _datePicker(
                    label: 'Invoice Date',
                    date: _invoiceDate,
                    placeholder: 'Not selected',
                    onTap: () => _pickDate(_invoiceDate ?? DateTime.now(), (d) => _invoiceDate = d),
                  ),

                  // ── Additional ─────────────────────────────────────────
                  SizedBox(height: 20.h),
                  _sectionLabel('Additional Details'),
                  SizedBox(height: 10.h),
                  _field(controller: _descCtrl, label: 'Description', hint: 'Add details...', maxLines: 3),
                  SizedBox(height: 10.h),
                  _field(controller: _notesCtrl, label: 'Notes', hint: 'Any additional notes...', maxLines: 2),

                  // ── Buttons ────────────────────────────────────────────
                  SizedBox(height: 28.h),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        decoration: BoxDecoration(
                          color: _isLoading ? _T.textTer : _T.indigo,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: _isLoading ? null : [
                            BoxShadow(
                              color: _T.indigo.withOpacity(0.25),
                              blurRadius: 16, offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? SizedBox(
                                  height: 18.h, width: 18.h,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEditMode ? 'Update Expense' : 'Add Expense',
                                  style: TextStyle(
                                    fontSize: 15.sp, fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          color: _T.cardBg,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: _T.border),
                        ),
                        child: Center(
                          child: Text('Cancel',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: _T.textSec)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(label,
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700,
        color: _T.textPri, letterSpacing: -0.2));
  }

  Widget _field({
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
      style: TextStyle(fontSize: 13.sp, color: _T.textPri),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        labelStyle: TextStyle(fontSize: 13.sp, color: _T.textSec),
        hintStyle: TextStyle(fontSize: 13.sp, color: _T.textTer),
        filled: true,
        fillColor: _T.cardBg,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: _T.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: _T.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: _T.indigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: _T.rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: _T.rose, width: 1.5),
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? date,
    String? placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(fontSize: 11.sp, color: _T.textSec)),
                SizedBox(height: 3.h),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy').format(date)
                      : (placeholder ?? ''),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: date != null ? _T.textPri : _T.textTer,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today_rounded, size: 18.sp, color: _T.indigo),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown(ExpenseProvider provider) {
    final cats = provider.categories;
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      isExpanded: true,
      style: TextStyle(fontSize: 13.sp, color: _T.textPri),
      decoration: _dropDeco('Category'),
      items: cats.map((c) {
        return DropdownMenuItem(
          value: c.id,
          child: Row(children: [
            Icon(Icons.category_rounded, size: 14.sp, color: _T.indigo),
            SizedBox(width: 8.w),
            Text(c.name, style: TextStyle(fontSize: 13.sp)),
          ]),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
      validator: (_) => _selectedCategoryId == null ? 'Select a category' : null,
    );
  }

  Widget _expenseTypeDropdown() {
    final types = [
      ('maintenance', 'Maintenance'), ('event', 'Event'),
      ('interior_work', 'Interior Work'), ('festival', 'Festival'),
      ('operational', 'Operational'), ('utility', 'Utility'), ('general', 'General'),
    ];
    return DropdownButtonFormField<String>(
      value: _expenseType,
      isExpanded: true,
      style: TextStyle(fontSize: 13.sp, color: _T.textPri),
      decoration: _dropDeco('Expense Type'),
      items: types.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
      onChanged: (v) => setState(() => _expenseType = v ?? 'general'),
    );
  }

  InputDecoration _dropDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp, color: _T.textSec),
      filled: true, fillColor: _T.cardBg,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: _T.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: _T.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: _T.indigo, width: 1.5),
      ),
    );
  }

  Widget _paymentStatusPicker() {
    final statuses = [
      (ExpensePaymentStatus.unpaid,  'Unpaid',  _T.rose,    _T.roseBg),
      (ExpensePaymentStatus.partial, 'Partial', _T.amber,   _T.amberBg),
      (ExpensePaymentStatus.paid,    'Paid',    _T.emerald, _T.emeraldBg),
    ];
    return Row(
      children: statuses.map((item) {
        final (status, label, color, bg) = item;
        final selected = _paymentStatus == status;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentStatus = status),
            child: Container(
              margin: EdgeInsets.only(
                right: status == ExpensePaymentStatus.paid ? 0 : 8.w,
              ),
              padding: EdgeInsets.symmetric(vertical: 11.h),
              decoration: BoxDecoration(
                color: selected ? color : _T.cardBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: selected ? color : _T.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 8.w, height: 8.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}