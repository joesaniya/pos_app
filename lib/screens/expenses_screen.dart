import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/screens/excel_expense_import_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/screens/add_expense_screen.dart';
import 'package:pos_app/screens/expense_detail_screen.dart';
import 'package:pos_app/screens/upload_bill_screen.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  // Backgrounds
  static const pageBg = Color(0xFFF5F4F0); // warm off-white
  static const cardBg = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFF0EEF8);

  // Brand
  static const indigo = Color(0xFF4F46E5);
  static const indigoSoft = Color(0xFFEEEDFD);
  static const indigoText = Color(0xFF3730A3);

  // Status
  static const emerald = Color(0xFF059669);
  static const emeraldBg = Color(0xFFECFDF5);
  static const amber = Color(0xFFD97706);
  static const amberBg = Color(0xFFFFFBEB);
  static const rose = Color(0xFFE11D48);
  static const roseBg = Color(0xFFFFF1F2);

  // Text
  static const textPri = Color(0xFF111827);
  static const textSec = Color(0xFF6B7280);
  static const textTer = Color(0xFF9CA3AF);

  // Border
  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFF3F4F6);

  // Radius
  static const r8 = Radius.circular(8);
  static const r12 = Radius.circular(12);
  static const r16 = Radius.circular(16);
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSES SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final provider = context.read<ExpenseProvider>();
    provider.loadCategories();
    provider.loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            color: _T.indigo,
            onRefresh: () => provider.loadExpenses(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Sticky header ──────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 0,
                  backgroundColor: _T.pageBg,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 64.h,
                  titleSpacing: 0,
                  title: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expenses',
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _T.textPri,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Business Expense Tracking',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: _T.textSec,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // _HeaderAvatar(),
                      ],
                    ),
                  ),
                ),

                // ── Body content ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(provider),
                      SizedBox(height: 16.h),
                      _buildStatRow(provider),
                      SizedBox(height: 20.h),
                      _buildActionButtons(context),
                      SizedBox(height: 20.h),
                      _buildSearchField(),
                      SizedBox(height: 16.h),
                      _buildTabBar(),
                      SizedBox(height: 4.h),
                      _buildExpensesList(provider),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(ExpenseProvider provider) {
    final total = provider.getTotalExpenses();
    final paid = provider.getTotalPaid();
    final pct = total > 0 ? (paid / total * 100).clamp(0, 100) : 0.0;

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _T.indigo,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: _T.indigo.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 90.w,
              height: 90.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            right: 50,
            child: Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL EXPENSES',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.65),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${provider.expenses.length} records',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '₹${_fmt(total)}',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 16.h),
              // Progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid ₹${_fmt(paid)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}% cleared',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5.h,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6EE7B7)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat row ──────────────────────────────────────────────────────────────

  Widget _buildStatRow(ExpenseProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          _StatChip(
            label: 'Paid',
            value: '₹${_fmt(provider.getTotalPaid())}',
            color: _T.emerald,
            bg: _T.emeraldBg,
            icon: Icons.check_circle_rounded,
          ),
          SizedBox(width: 10.w),
          _StatChip(
            label: 'Pending',
            value: '₹${_fmt(provider.getPendingAmount())}',
            color: _T.amber,
            bg: _T.amberBg,
            icon: Icons.schedule_rounded,
          ),
          SizedBox(width: 10.w),
          _StatChip(
            label: 'Unpaid',
            value: provider.getUnpaidCount().toString(),
            color: _T.rose,
            bg: _T.roseBg,
            icon: Icons.error_outline_rounded,
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Add Expense',
              icon: Icons.add_rounded,
              color: _T.indigo,
              textColor: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _ActionButton(
              label: 'Upload Bill',
              icon: Icons.upload_file_rounded,
              color: _T.cardBg,
              textColor: _T.indigo,
              borderColor: _T.indigo.withOpacity(0.3),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      // const UploadBillScreen()
                      const ExcelExpenseImportScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          fontSize: 12.sp,
          color: _T.textPri,
        ), // slightly smaller
        decoration: InputDecoration(
          hintText: 'Search title, vendor, invoice...',
          hintStyle: TextStyle(fontSize: 12.sp, color: _T.textTer),

          isDense: true, // 🔥 reduces internal height

          prefixIcon: Icon(
            Icons.search_rounded,
            color: _T.textTer,
            size: 16.sp, // smaller icon
          ),

          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: _T.textTer,
                    size: 14.sp,
                  ),
                )
              : null,

          filled: true,
          fillColor: _T.cardBg,

          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 8.h, // 🔥 reduced from 12 → 8
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r), // slightly tighter
            borderSide: BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: _T.indigo, width: 1.2),
          ),
        ),
      ),
    );
  }
  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _T.border),
        ),
        padding: EdgeInsets.all(2.w),
        child: TabBar(
          controller: _tabController,
          onTap: (i) => setState(() {
            _selectedFilter = ['all', 'unpaid', 'pending', 'paid'][i];
          }),

          // 🔥 Reduce spacing between tabs
          labelPadding: EdgeInsets.symmetric(horizontal: 8.w),

          indicator: BoxDecoration(
            color: _T.indigo,
            borderRadius: BorderRadius.circular(8.r),
          ),

          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,

          labelColor: Colors.white,
          unselectedLabelColor: _T.textSec,

          labelStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),

          tabs: const [
            Tab(height: 30, text: 'All'), // ✅ controls height
            Tab(height: 30, text: 'Unpaid'),
            Tab(height: 30, text: 'Pending'),
            Tab(height: 30, text: 'Paid'),
          ],
        ),
      ),
    );
  }
  // ── Expenses list ─────────────────────────────────────────────────────────

  Widget _buildExpensesList(ExpenseProvider provider) {
    final expenses = _filtered(provider);

    if (provider.isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: 48.h),
        child: const Center(child: CircularProgressIndicator(color: _T.indigo)),
      );
    }

    if (expenses.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  color: _T.indigoSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 32.sp,
                  color: _T.indigo,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'No expenses found',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: _T.textPri,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Add your first expense or upload a bill',
                style: TextStyle(fontSize: 13.sp, color: _T.textSec),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, i) => _ExpenseCard(
        expense: expenses[i],
        onTap: () {
          log('Tapped expense: ${expenses[i].toJson()}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expenseId: expenses[i].id),
            ),
          );
        },
        onEdit: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddExpenseScreen(expenseId: expenses[i].id),
          ),
        ),
      ),
    );
  }

  List<Expense> _filtered(ExpenseProvider provider) {
    var list = provider.expenses;
    switch (_selectedFilter) {
      case 'unpaid':
        list = list
            .where((e) => e.paymentStatus == ExpensePaymentStatus.unpaid)
            .toList();
        break;
      case 'pending':
        list = list.where((e) => e.status == ExpenseStatus.pending).toList();
        break;
      case 'paid':
        list = list
            .where((e) => e.paymentStatus == ExpensePaymentStatus.paid)
            .toList();
        break;
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      list = list
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.vendorName.toLowerCase().contains(q) ||
                (e.invoiceNumber?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }
}

String _fmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: _T.indigoSoft,
        shape: BoxShape.circle,
        border: Border.all(color: _T.indigo.withOpacity(0.2), width: 1.5),
      ),
      child: Center(
        child: Text(
          'B',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: _T.indigo,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: _T.textSec,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(icon, size: 12.sp, color: color),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: color,
                // color: _T.textPri,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
          boxShadow: color == _T.indigo
              ? [
                  BoxShadow(
                    color: _T.indigo.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17.sp, color: textColor),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ExpenseCard({
    required this.expense,
    required this.onTap,
    required this.onEdit,
  });

  Color get _statusColor {
    switch (expense.paymentStatus) {
      case ExpensePaymentStatus.paid:
        return _T.emerald;
      case ExpensePaymentStatus.partial:
        return _T.amber;
      case ExpensePaymentStatus.unpaid:
        return _T.rose;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final pct = expense.progressPercentage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 165.h,
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _T.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left status stripe
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.only(
                    topLeft: _T.r16,
                    bottomLeft: _T.r16,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: title + amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.title,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _T.textPri,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  expense.vendorName,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: _T.textSec,
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
                                '₹${expense.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _T.indigo,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              _StatusBadge(
                                label: expense.status.label,
                                color: _statusColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Row 2: category + payment badge
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: _T.indigoSoft,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 10.sp,
                                  color: _T.indigo,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  expense.categoryName,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: _T.indigoText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _PayBadge(status: expense.paymentStatus),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Row 3: progress + date + menu
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${expense.paidAmount.toStringAsFixed(0)} paid',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: _T.textSec,
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: _statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2.r),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    minHeight: 4.h,
                                    backgroundColor: _T.borderSoft,
                                    valueColor: AlwaysStoppedAnimation(
                                      _statusColor,
                                    ),
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
                                dateFormat.format(expense.expenseDate),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: _T.textSec,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              PopupMenuButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 18.sp,
                                  color: _T.textTer,
                                ),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    onTap: onEdit,
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 15.sp),
                                        SizedBox(width: 8.w),
                                        const Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: onTap,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.visibility_outlined,
                                          size: 15.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        const Text('Details'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Payment badge ─────────────────────────────────────────────────────────────

class _PayBadge extends StatelessWidget {
  final ExpensePaymentStatus status;
  const _PayBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    switch (status) {
      case ExpensePaymentStatus.paid:
        color = _T.emerald;
        label = 'Paid';
        icon = Icons.check_circle_rounded;
        break;
      case ExpensePaymentStatus.partial:
        color = _T.amber;
        label = 'Partial';
        icon = Icons.timelapse_rounded;
        break;
      case ExpensePaymentStatus.unpaid:
        color = _T.rose;
        label = 'Unpaid';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
