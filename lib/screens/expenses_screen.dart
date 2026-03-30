import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/screens/add_expense_screen.dart';
import 'package:pos_app/screens/expense_detail_screen.dart';
import 'package:pos_app/screens/upload_bill_screen.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, unpaid, pending, paid

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
      backgroundColor: AppColors.lightNeutral100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Expenses', style: AppTheme.headlineSmall),
        centerTitle: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: Text(
                'Business Expense\nTracking',
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.loadExpenses(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  _buildSummaryCards(provider),
                  SizedBox(height: 24.h),

                  // Action Buttons
                  _buildActionButtons(context, provider),
                  SizedBox(height: 24.h),

                  // Search & Filter
                  _buildSearchAndFilter(provider),
                  SizedBox(height: 16.h),

                  // Tab Bar
                  _buildTabBar(),
                  SizedBox(height: 16.h),

                  // Expenses List
                  _buildExpensesList(provider),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCards(ExpenseProvider provider) {
    final totalExpenses = provider.getTotalExpenses();
    final totalPaid = provider.getTotalPaid();
    final pendingAmount = provider.getPendingAmount();
    final unpaidCount = provider.getUnpaidCount();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          // Total Expenses Card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryPurple.withAlpha((0.8 * 255).toInt()),
                  AppColors.primaryPurple,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withAlpha((0.3 * 255).toInt()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Expenses',
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white.withAlpha((0.8 * 255).toInt()),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '₹${totalExpenses.toStringAsFixed(0)}',
                      style: AppTheme.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Row: Paid, Pending, Unpaid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Paid',
                  value: '₹${totalPaid.toStringAsFixed(0)}',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _StatCard(
                  title: 'Pending',
                  value: '₹${pendingAmount.toStringAsFixed(0)}',
                  icon: Icons.schedule,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _StatCard(
                  title: 'Unpaid',
                  value: unpaidCount.toString(),
                  icon: Icons.error_outline,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(BuildContext context, ExpenseProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                );
              },
              icon: Icon(Icons.add, size: 20.sp),
              label: Text('Add Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadBillScreen()),
                );
              },
              icon: Icon(Icons.cloud_upload_outlined, size: 20.sp),
              label: Text('Upload Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SEARCH & FILTER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSearchAndFilter(ExpenseProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title, vendor, or invoice...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.clear, color: AppColors.textSecondary),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppColors.lightNeutral300),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB BAR
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _selectedFilter = ['all', 'unpaid', 'pending', 'paid'][index];
          });
        },
        labelStyle: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
        unselectedLabelStyle: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 13.sp,
        ),
        labelColor: AppColors.primaryPurple,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryPurple,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Unpaid'),
          Tab(text: 'Pending'),
          Tab(text: 'Paid'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EXPENSES LIST
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildExpensesList(ExpenseProvider provider) {
    final expenses = _getFilteredExpenses(provider);

    if (provider.isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 64.sp,
                color: AppColors.lightNeutral300,
              ),
              SizedBox(height: 16.h),
              Text(
                'No expenses found',
                style: AppTheme.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Start by adding your first expense or uploading a bill',
                style: AppTheme.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: expenses.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return _ExpenseListItem(
            expense: expenses[index],
            onTap: () {
              // Navigate to expense detail (read-only view)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ExpenseDetailScreen(expenseId: expenses[index].id),
                ),
              );
            },
            onEdit: () {
              // Navigate to edit expense
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddExpenseScreen(expenseId: expenses[index].id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Expense> _getFilteredExpenses(ExpenseProvider provider) {
    var expenses = provider.expenses;

    // Filter by status
    switch (_selectedFilter) {
      case 'unpaid':
        expenses = expenses
            .where((e) => e.paymentStatus == ExpensePaymentStatus.unpaid)
            .toList();
        break;
      case 'pending':
        expenses = expenses
            .where((e) => e.status == ExpenseStatus.pending)
            .toList();
        break;
      case 'paid':
        expenses = expenses
            .where((e) => e.paymentStatus == ExpensePaymentStatus.paid)
            .toList();
        break;
      default:
        break;
    }

    // Filter by search using client-side search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      expenses = expenses
          .where(
            (e) =>
                e.title.toLowerCase().contains(query) ||
                e.vendorName.toLowerCase().contains(query) ||
                (e.invoiceNumber?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return expenses;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAT CARD WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.lightNeutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTheme.labelSmall.copyWith(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Icon(icon, color: color, size: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTheme.labelLarge.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE LIST ITEM
// ══════════════════════════════════════════════════════════════════════════════

class _ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ExpenseListItem({
    required this.expense,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.lightNeutral300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Status, Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        expense.vendorName,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
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
                      style: AppTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: expense.status.bgColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        expense.status.label,
                        style: AppTheme.bodySmall.copyWith(
                          color: expense.status.color,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Category & Payment Status
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(
                          Icons.category,
                          size: 12.sp,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          expense.categoryName,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: expense.paymentStatus.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 12.sp,
                        color: expense.paymentStatus.color,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        expense.paymentStatus.label,
                        style: AppTheme.bodySmall.copyWith(
                          color: expense.paymentStatus.color,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Progress Bar & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paid: ₹${expense.paidAmount.toStringAsFixed(0)}',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 10.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${expense.progressPercentage.toStringAsFixed(0)}%',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          value: expense.progressPercentage / 100,
                          minHeight: 4.h,
                          backgroundColor: AppColors.lightNeutral200,
                          valueColor: AlwaysStoppedAnimation(
                            expense.paymentStatus == ExpensePaymentStatus.paid
                                ? AppColors.success
                                : expense.paymentStatus ==
                                      ExpensePaymentStatus.partial
                                ? AppColors.warning
                                : AppColors.error,
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
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: onEdit,
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16.sp),
                              SizedBox(width: 8.w),
                              const Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: onTap,
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 16.sp),
                              SizedBox(width: 8.w),
                              const Text('Details'),
                            ],
                          ),
                        ),
                      ],
                      child: Icon(Icons.more_vert, size: 16.sp),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
