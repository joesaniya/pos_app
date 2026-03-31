import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/screens/add_expense_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (shared across all screens – import from a tokens file in prod)
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  static const pageBg     = Color(0xFFF5F4F0);
  static const cardBg     = Color(0xFFFFFFFF);
  static const indigoSoft = Color(0xFFEEEDFD);
  static const indigo     = Color(0xFF4F46E5);
  static const indigoText = Color(0xFF3730A3);
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
// EXPENSE DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

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
    context.read<ExpenseProvider>().loadExpenseDetails(widget.expenseId);
  }

  Future<void> _updateStatus(ExpenseProvider provider, ExpensePaymentStatus s) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final ok = await provider.updateExpensePaymentStatus(
        expenseId: widget.expenseId,
        newStatus: s,
      );
      if (ok && mounted) {
        await provider.loadExpenseDetails(widget.expenseId);
        _snack('Status updated to ${s.label}', _T.emerald);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
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
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: _T.indigo));
          }

          final expense = provider.selectedExpense;
          if (expense == null) {
            return _buildNotFound();
          }

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(expense, provider),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAmountHero(expense),
                    SizedBox(height: 16.h),
                    _buildPaymentStatusCard(expense, provider),
                    SizedBox(height: 12.h),
                    _buildAmountBreakdown(expense),
                    SizedBox(height: 12.h),
                    _buildDetailsCard(expense),
                    if (expense.description != null && expense.description!.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _buildDescCard(expense),
                    ],
                    if (expense.invoiceNumber != null && expense.invoiceNumber!.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _buildInvoiceCard(expense),
                    ],
                    if (expense.gstAmount != null && expense.gstAmount! > 0) ...[
                      SizedBox(height: 12.h),
                      _buildGstCard(expense),
                    ],
                    SizedBox(height: 12.h),
                    _buildAuditCard(expense),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Sliver app bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(Expense expense, ExpenseProvider provider) {
    return SliverAppBar(
      pinned: true,
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
              color: _T.cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: _T.border),
            ),
            child: Icon(Icons.arrow_back_rounded, size: 18.sp, color: _T.textPri),
          ),
        ),
      ),
      title: Text('Expense Details',
        style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: _T.textPri)),
      centerTitle: true,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddExpenseScreen(expenseId: widget.expenseId),
              ),
            ),
            child: Container(
              width: 36.w, height: 36.w,
              decoration: BoxDecoration(
                color: _T.indigoSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_rounded, size: 16.sp, color: _T.indigo),
            ),
          ),
        ),
      ],
    );
  }

  // ── Amount hero ───────────────────────────────────────────────────────────

  Widget _buildAmountHero(Expense expense) {
    final isPaid = expense.paymentStatus == ExpensePaymentStatus.paid;
    final statusColor = _statusColor(expense.paymentStatus);

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _T.border),
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
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: _T.textPri, letterSpacing: -0.3),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Invoice: ${expense.invoiceNumber ?? 'N/A'}',
                      style: TextStyle(fontSize: 11.sp, color: _T.textSec),
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
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: _T.indigo,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  _Badge(
                    label: isPaid ? 'Completed' : expense.status.label,
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment progress',
                style: TextStyle(fontSize: 11.sp, color: _T.textSec)),
              Text('${expense.progressPercentage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: statusColor)),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: expense.progressPercentage / 100,
              minHeight: 6.h,
              backgroundColor: _T.borderSoft,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment status card ───────────────────────────────────────────────────

  Widget _buildPaymentStatusCard(Expense expense, ExpenseProvider provider) {
    final isPaid    = expense.paymentStatus == ExpensePaymentStatus.paid;
    final isPartial = expense.paymentStatus == ExpensePaymentStatus.partial;
    final sc        = _statusColor(expense.paymentStatus);

    return _Section(
      title: 'Payment Status',
      child: Column(
        children: [
          // Current status banner
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: sc.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                  color: sc, size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    isPaid ? 'Payment completed – Expense is finalized' : 'Current: ${expense.paymentStatus.label}',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: sc),
                  ),
                ),
              ],
            ),
          ),

          if (!isPaid) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _OutlineBtn(
                    label: _isUpdatingStatus ? 'Updating...' : 'Mark Paid',
                    icon: Icons.check_rounded,
                    color: _T.emerald,
                    onTap: _isUpdatingStatus ? null : () => _updateStatus(provider, ExpensePaymentStatus.paid),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _OutlineBtn(
                    label: _isUpdatingStatus ? 'Updating...' : 'Mark Unpaid',
                    icon: Icons.close_rounded,
                    color: _T.rose,
                    onTap: _isUpdatingStatus ? null : () => _updateStatus(provider, ExpensePaymentStatus.unpaid),
                  ),
                ),
              ],
            ),
            if (isPartial) ...[
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: _OutlineBtn(
                  label: 'Complete Payment',
                  icon: Icons.check_circle_rounded,
                  color: _T.amber,
                  onTap: _isUpdatingStatus ? null : () => _updateStatus(provider, ExpensePaymentStatus.paid),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Amount breakdown ──────────────────────────────────────────────────────

  Widget _buildAmountBreakdown(Expense expense) {
    return _Section(
      title: 'Amount Details',
      child: Column(
        children: [
          _AmountRow('Total Amount', expense.amount),
          _divider(),
          _AmountRow('Paid Amount', expense.paidAmount, valueColor: _T.emerald),
          _divider(),
          _AmountRow('Remaining', expense.remainingAmount, valueColor: _T.rose),
        ],
      ),
    );
  }

  // ── Details card ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard(Expense expense) {
    return _Section(
      title: 'Details',
      child: Column(
        children: [
          _DetailRow('Category', expense.categoryName),
          _divider(),
          _DetailRow('Vendor', expense.vendorName),
          _divider(),
          _DetailRow('Expense Date', DateFormat('dd MMM yyyy').format(expense.expenseDate)),
          _divider(),
          _DetailRow('Expense #', '${expense.expenseNumber}'),
        ],
      ),
    );
  }

  Widget _buildDescCard(Expense expense) {
    return _Section(
      title: 'Description',
      child: Text(expense.description ?? '',
        style: TextStyle(fontSize: 13.sp, color: _T.textSec, height: 1.5)),
    );
  }

  Widget _buildInvoiceCard(Expense expense) {
    return _Section(
      title: 'Invoice Information',
      child: Column(
        children: [
          _DetailRow('Invoice #', expense.invoiceNumber ?? 'N/A'),
          if (expense.invoiceDate != null) ...[
            _divider(),
            _DetailRow('Invoice Date', DateFormat('dd MMM yyyy').format(expense.invoiceDate!)),
          ],
        ],
      ),
    );
  }

  Widget _buildGstCard(Expense expense) {
    return _Section(
      title: 'GST Details',
      child: Column(
        children: [
          _AmountRow('GST Amount', expense.gstAmount ?? 0),
          if (expense.gstNumber != null && expense.gstNumber!.isNotEmpty) ...[
            _divider(),
            _DetailRow('GSTIN', expense.gstNumber ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditCard(Expense expense) {
    return _Section(
      title: 'Audit Information',
      child: Column(
        children: [
          _DetailRow('Created By', expense.createdByName ?? 'System'),
          _divider(),
          _DetailRow('Created At', DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt)),
          if (expense.updatedByName != null) ...[
            _divider(),
            _DetailRow('Updated By', expense.updatedByName ?? ''),
            _divider(),
            _DetailRow('Updated At', DateFormat('dd MMM yyyy, hh:mm a').format(expense.updatedAt)),
          ],
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72.w, height: 72.w,
            decoration: const BoxDecoration(color: Color(0xFFFFF1F2), shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, size: 32.sp, color: _T.rose),
          ),
          SizedBox(height: 16.h),
          Text('Expense not found',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: _T.textPri)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: _T.borderSoft);

  Color _statusColor(ExpensePaymentStatus s) {
    switch (s) {
      case ExpensePaymentStatus.paid:    return _T.emerald;
      case ExpensePaymentStatus.partial: return _T.amber;
      case ExpensePaymentStatus.unpaid:  return _T.rose;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
            child: Text(title,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700,
                color: _T.textSec, letterSpacing: 0.3)),
          ),
          Divider(height: 1, thickness: 1, color: _T.borderSoft),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? valueColor;
  const _AmountRow(this.label, this.amount, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, color: _T.textSec)),
          Text('₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _T.textPri,
            )),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, color: _T.textSec)),
          Flexible(
            child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: _T.textPri),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15.sp, color: color),
            SizedBox(width: 5.w),
            Text(label,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}