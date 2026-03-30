// lib/screens/expense_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/screens/add_expense_screen.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE DETAIL SCREEN — Read-only expense details view
// ══════════════════════════════════════════════════════════════════════════════

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({required this.expenseId, super.key});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadExpenseDetails();
  }

  void _loadExpenseDetails() {
    final provider = context.read<ExpenseProvider>();
    provider.loadExpenseDetails(widget.expenseId);
  }

  Future<void> _updatePaymentStatus(
    ExpenseProvider provider,
    ExpensePaymentStatus newStatus,
  ) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final success = await provider.updateExpensePaymentStatus(
        expenseId: widget.expenseId,
        newStatus: newStatus,
      );

      if (success && mounted) {
        // Reload expense details to ensure UI fully syncs with updated status
        await provider.loadExpenseDetails(widget.expenseId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.label}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Expense Details', style: AppTheme.headlineSmall),
        centerTitle: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddExpenseScreen(expenseId: widget.expenseId),
                    ),
                  );
                },
                tooltip: 'Edit Expense',
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          final expense = provider.selectedExpense;
          if (expense == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.sp,
                    color: AppColors.error,
                  ),
                  SizedBox(height: 16.h),
                  Text('Expense not found', style: AppTheme.labelLarge),
                ],
              ),
            );
          }

          final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                _buildHeaderCard(expense),
                SizedBox(height: 16.h),

                // Status Section
                _buildStatusSection(expense),
                SizedBox(height: 16.h),

                // Amount Section
                _buildAmountSection(expense),
                SizedBox(height: 16.h),

                // Details Section
                _buildDetailsSection(expense, dateFormat.format),
                SizedBox(height: 16.h),

                // Additional Info
                if (expense.description != null &&
                    expense.description!.isNotEmpty)
                  _buildDescriptionSection(expense),

                if (expense.invoiceNumber != null &&
                    expense.invoiceNumber!.isNotEmpty)
                  _buildInvoiceSection(expense),

                // GST Section
                if (expense.gstAmount != null && expense.gstAmount! > 0)
                  _buildGstSection(expense),

                // Payment History
                _buildPaymentHistorySection(expense),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HEADER CARD
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderCard(Expense expense) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: AppTheme.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Invoice: ${expense.invoiceNumber ?? 'N/A'}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${expense.amount.toStringAsFixed(2)}',
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: expense.status.bgColor,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      expense.status.label,
                      style: AppTheme.bodySmall.copyWith(
                        color: expense.status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STATUS SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStatusSection(Expense expense) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final isPaid = expense.paymentStatus == ExpensePaymentStatus.paid;
        final isPartial = expense.paymentStatus == ExpensePaymentStatus.partial;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.lightNeutral300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Status',
                style: AppTheme.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              // Current Status Display - Shows Completed when paid
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.success.withValues(alpha: 0.1)
                      : expense.paymentStatus.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.pending,
                      color: isPaid
                          ? AppColors.success
                          : expense.paymentStatus.color,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Current: ${isPaid ? "Completed" : expense.paymentStatus.label}',
                        style: AppTheme.bodySmall.copyWith(
                          color: isPaid
                              ? AppColors.success
                              : expense.paymentStatus.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Only show action buttons if NOT paid
              if (!isPaid) ...[
                SizedBox(height: 12.h),
                // Status Change Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _updatePaymentStatus(
                                provider,
                                ExpensePaymentStatus.paid,
                              ),
                        icon: const Icon(Icons.done),
                        label: Text(
                          _isUpdatingStatus &&
                                  expense.paymentStatus ==
                                      ExpensePaymentStatus.paid
                              ? 'Updating...'
                              : 'Mark Paid',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _updatePaymentStatus(
                                provider,
                                ExpensePaymentStatus.unpaid,
                              ),
                        icon: const Icon(Icons.close),
                        label: Text(
                          _isUpdatingStatus &&
                                  expense.paymentStatus ==
                                      ExpensePaymentStatus.unpaid
                              ? 'Updating...'
                              : 'Mark Unpaid',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Show "Complete Payment" only for partial payments
                if (isPartial) ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : () => _updatePaymentStatus(
                              provider,
                              ExpensePaymentStatus.paid,
                            ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Complete Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // When paid, show completion info
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Payment completed - Expense is finalized',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 12.h),
              Divider(color: AppColors.lightNeutral300),
              SizedBox(height: 12.h),
              _buildInfoRow(
                'Expense Status',
                isPaid ? 'Completed' : expense.status.label,
                expense.status.color,
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // AMOUNT SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAmountSection(Expense expense) {
    final progressPercent = expense.progressPercentage;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Details',
            style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          _buildAmountRow('Total Amount', expense.amount),
          SizedBox(height: 8.h),
          _buildAmountRow('Paid Amount', expense.paidAmount),
          SizedBox(height: 8.h),
          _buildAmountRow('Remaining Amount', expense.remainingAmount),
          SizedBox(height: 12.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Progress',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${progressPercent.toStringAsFixed(0)}%',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 8.h,
                  backgroundColor: AppColors.lightNeutral200,
                  valueColor: AlwaysStoppedAnimation(
                    expense.paymentStatus == ExpensePaymentStatus.paid
                        ? AppColors.success
                        : expense.paymentStatus == ExpensePaymentStatus.partial
                        ? AppColors.warning
                        : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DETAILS SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDetailsSection(
    Expense expense,
    String Function(DateTime) format,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          _buildDetailRow('Category', expense.categoryName),
          SizedBox(height: 12.h),
          _buildDetailRow('Vendor', expense.vendorName),
          SizedBox(height: 12.h),
          _buildDetailRow(
            'Expense Date',
            DateFormat('dd MMM yyyy').format(expense.expenseDate),
          ),
          SizedBox(height: 12.h),
          _buildDetailRow('Expense #', '${expense.expenseNumber}'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DESCRIPTION SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDescriptionSection(Expense expense) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          Text(
            expense.description ?? '',
            style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // INVOICE SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildInvoiceSection(Expense expense) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Information',
            style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          _buildDetailRow('Invoice #', expense.invoiceNumber ?? 'N/A'),
          if (expense.invoiceDate != null)
            Column(
              children: [
                SizedBox(height: 12.h),
                _buildDetailRow(
                  'Invoice Date',
                  DateFormat('dd MMM yyyy').format(expense.invoiceDate!),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GST SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildGstSection(Expense expense) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST Details',
            style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          _buildAmountRow('GST Amount', expense.gstAmount ?? 0),
          if (expense.gstNumber != null && expense.gstNumber!.isNotEmpty)
            Column(
              children: [
                SizedBox(height: 12.h),
                _buildDetailRow('GST #', expense.gstNumber ?? 'N/A'),
              ],
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PAYMENT HISTORY SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentHistorySection(Expense expense) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audit Information',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildDetailRow('Created By', expense.createdByName ?? 'System'),
          SizedBox(height: 12.h),
          _buildDetailRow(
            'Created At',
            DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt),
          ),
          if (expense.updatedByName != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow('Updated By', expense.updatedByName ?? ''),
            SizedBox(height: 12.h),
            _buildDetailRow(
              'Updated At',
              DateFormat('dd MMM yyyy, hh:mm a').format(expense.updatedAt),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildInfoRow(String label, String value, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primaryPurple).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: color ?? AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: AppTheme.bodySmall.copyWith(
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? AppColors.primaryPurple : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
