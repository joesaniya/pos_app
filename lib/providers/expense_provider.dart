import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/repositories/expense_repository.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE PROVIDER — Enhanced with Offline/Online Support
// Pattern: Hybrid online-first with offline fallback
// ══════════════════════════════════════════════════════════════════════════════

class ExpenseProvider extends ChangeNotifier {
  // Dependencies
  late final ExpenseRepository _repository;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  // State variables
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  Expense? _selectedExpense;
  String _businessId = '';
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Offline/Online state
  bool _isOnline = true;
  final int _pendingSyncCount = 0;
  final bool _syncInProgress = false;

  // Stream subscriptions
  StreamSubscription? _connectivitySub;

  // Constructor
  ExpenseProvider() {
    // Initialize in background when provider is created
    _initializationFuture = initialize().catchError((e) {
      log('❌ Constructor initialization error: $e');
      _isInitialized = true;
    });
  }

  // Getters
  List<Expense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Expense? get selectedExpense => _selectedExpense;
  String get businessId => _businessId;

  // Offline/Online getters
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  bool get syncInProgress => _syncInProgress;

  // ════════════════════════════════════════════════════════════════════════════
  // INITIALIZATION & CLEANUP
  // ════════════════════════════════════════════════════════════════════════════

  /// Initialize provider with business ID and offline support
  Future<void> initialize() async {
    log('🚀 Initializing ExpenseProvider...');
    try {
      // 1. Load business ID
      final userData = await StorageService.instance.getUserData();
      _businessId = userData['businessId'] ?? '';

      if (_businessId.isEmpty) {
        _setError('No business ID found. Please log in again.');
        _isInitialized = true;
        return;
      }

      // 2. Initialize repository
      _repository = ExpenseRepository(
        supabase: Supabase.instance,
        connectivityService: _connectivity,
      );

      // 3. Setup connectivity monitoring
      _setupConnectivityMonitoring();

      // 4. Mark as initialized BEFORE loading data to avoid circular dependency
      _isInitialized = true;

      // 5. Load initial data (with error handling - don't fail on connection errors)
      try {
        log('📡 Checking connectivity...');
        await loadCategories();
      } catch (e) {
        log('⚠️ Failed to load categories: $e');
        // Continue anyway - allow offline mode
      }

      try {
        await loadExpenses();
      } catch (e) {
        log('⚠️ Failed to load expenses: $e');
        // Continue anyway - allow offline mode
      }

      _isOnline = _connectivity.isOnline;
      notifyListeners();
      log(
        '✅ ExpenseProvider initialized (categories: ${_categories.length}, expenses: ${_expenses.length})',
      );
    } catch (e) {
      _setError('Failed to initialize expense provider: $e');
      log('❌ Initialize error: $e');
      _isInitialized = true;
    }
  }

  /// Setup connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySub = _connectivity.onStatusChange.listen((status) {
      final wasOnline = _isOnline;
      _isOnline = status == NetworkStatus.online;

      if (!wasOnline && _isOnline) {
        log('📡 Connection restored! Reloading data...');
        // Automatically reload when connection is restored
        retryLoadData();
      }

      notifyListeners();
    });
  }

  /// Ensure provider is initialized before accessing repository
  Future<void> _ensureInitialized() async {
    if (_initializationFuture != null && !_isInitialized) {
      try {
        await _initializationFuture;
      } catch (e) {
        log('⚠️ Initialization failed: $e');
      }
    }

    if (!_isInitialized) {
      throw StateError('ExpenseProvider not initialized');
    }
  }

  /// Cleanup on dispose
  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LOADING OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Load all categories for the business
  Future<void> loadCategories() async {
    log('🔄 loadCategories() started - businessId=$_businessId');
    try {
      await _ensureInitialized();
      _setLoading(true);
      _clearError();

      log('📊 Fetching categories from repository...');
      final fetchedCategories = await _repository.getCategories(businessId);

      log('✅ Categories fetched from repo: ${fetchedCategories.length} items');
      if (fetchedCategories.isNotEmpty) {
        log(
          '📋 First category: ${fetchedCategories.first.name} (id: ${fetchedCategories.first.id})',
        );
      }

      _categories = fetchedCategories;
      log('✅ _categories updated: ${_categories.length} total');
      notifyListeners();
      log('📢 Listeners notified');
    } catch (e, stackTrace) {
      _setError('Failed to load categories: $e');
      log('❌ Category load error: $e');
      log('❌ Stack trace: $stackTrace');
    } finally {
      _setLoading(false);
    }
  }

  /// Load expenses for the business
  Future<void> loadExpenses({
    String? filterStatus,
    String? filterCategory,
  }) async {
    try {
      await _ensureInitialized();
      _setLoading(true);
      _clearError();
      _expenses = await _repository.getExpensesByBusiness(businessId);

      // Client-side filtering if needed
      if (filterStatus != null) {
        _expenses = _expenses
            .where((e) => e.status.dbValue == filterStatus)
            .toList();
      }

      if (filterCategory != null) {
        _expenses = _expenses
            .where((e) => e.categoryId == filterCategory)
            .toList();
      }

      // Sort by date descending
      _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      notifyListeners();
    } catch (e) {
      _setError('Failed to load expenses: $e');
      log('⚠️ Expense load error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Retry loading all data (useful when connection is restored)
  Future<void> retryLoadData() async {
    log('🔄 Retrying data load...');
    _clearError();
    await Future.wait([loadCategories(), loadExpenses()]);
  }

  /// Load single expense with payment history
  Future<void> loadExpenseDetails(String expenseId) async {
    try {
      await _ensureInitialized();
      _setLoading(true);
      _clearError();
      _selectedExpense = await _repository.getExpenseById(expenseId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load expense details: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Create a new expense
  Future<Expense?> createExpense({
    required String title,
    required int expenseNumber,
    required String categoryId,
    required String categoryName,
    required String vendorName,
    required double amount,
    DateTime? expenseDate,
    String? description,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? gstAmount,
    String? gstNumber,
  }) async {
    try {
      await _ensureInitialized();
      _clearError();

      // Validate businessId
      if (_businessId.isEmpty) {
        throw Exception('Business ID not found. Please log in again.');
      }

      log('💼 Creating expense for business: $_businessId');

      // Get current user credentials from storage
      final userData = await StorageService.instance.getUserData();
      final createdByUid = userData['uid'] ?? '';
      final createdByName = userData['displayName'] ?? 'Unknown';

      log('👤 Created by: $createdByName ($createdByUid)');

      final expense = await _repository.createExpense(
        businessId: _businessId,
        expenseNumber: expenseNumber,
        title: title,
        categoryId: categoryId,
        categoryName: categoryName,
        vendorName: vendorName,
        amount: amount,
        expenseDate: expenseDate ?? DateTime.now(),
        createdByUid: createdByUid,
        createdByName: createdByName,
        description: description,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        gstAmount: gstAmount,
        gstNumber: gstNumber,
      );

      if (expense != null) {
        _expenses.add(expense);
        _sortExpenses();
        notifyListeners();

        // Show status based on connectivity
        if (_isOnline) {
          log('✅ Expense created and synced: ${expense.id}');
        } else {
          log('📱 Expense created (will sync when online): ${expense.id}');
        }
      }

      return expense;
    } catch (e) {
      _setError('Failed to create expense: $e');
      log('❌ Create expense error: $e');
      return null;
    }
  }

  /// Create expense from bill upload
  Future<Expense?> createExpenseFromBill({
    required String categoryId,
    required String vendorName,
    required double amount,
    required String billFilePath,
    required String billFileName,
    required int billFileSize,
    String? invoiceNumber,
    DateTime? expenseDate,
  }) async {
    try {
      // Get category name from categories list
      final categories = _categories;
      log('cat:$categories');
      final selectedCategory = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => ExpenseCategory(
          id: categoryId,
          name: 'From Bill',
          icon: 'receipt',
          color: '#6366F1',
          isActive: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Generate expense number
      final expenseNumber = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create title from vendor and invoice
      final title = invoiceNumber != null && invoiceNumber.isNotEmpty
          ? '$vendorName - Invoice #$invoiceNumber'
          : 'Bill from $vendorName';

      // Create description with bill info
      final description =
          'Bill: $billFileName (${(billFileSize / 1024).toStringAsFixed(2)} KB)';

      // Delegate to createExpense
      return createExpense(
        title: title,
        expenseNumber: expenseNumber,
        categoryId: categoryId,
        categoryName: selectedCategory.name,
        vendorName: vendorName,
        amount: amount,
        expenseDate: expenseDate,
        description: description,
        invoiceNumber: invoiceNumber,
      );
    } catch (e) {
      _setError('Failed to create expense from bill: $e');
      log('❌ Error creating expense from bill: $e');
      return null;
    }
  }

  /// Update an existing expense
  Future<bool> updateExpense({
    required String expenseId,
    String? title,
    String? categoryId,
    String? vendorName,
    double? amount,
    DateTime? expenseDate,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    try {
      await _ensureInitialized();
      _clearError();

      final updates = <String, dynamic>{};
      if (title != null) {
        updates['title'] = title;
      }
      if (categoryId != null) {
        updates['category_id'] = categoryId;
      }
      if (vendorName != null) {
        updates['vendor_name'] = vendorName;
      }
      if (amount != null) {
        updates['amount'] = amount;
      }
      if (expenseDate != null) {
        updates['expense_date'] = expenseDate.toIso8601String();
      }
      if (invoiceNumber != null) {
        updates['invoice_number'] = invoiceNumber;
      }
      if (invoiceDate != null) {
        updates['invoice_date'] = invoiceDate.toIso8601String();
      }
      if (notes != null) {
        updates['notes'] = notes;
      }

      await _repository.updateExpense(expenseId: expenseId, updates: updates);

      // Update local cache
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index >= 0) {
        _expenses[index] = _expenses[index].copyWith(
          title: title ?? _expenses[index].title,
          categoryId: categoryId ?? _expenses[index].categoryId,
          vendorName: vendorName ?? _expenses[index].vendorName,
          amount: amount ?? _expenses[index].amount,
          expenseDate: expenseDate ?? _expenses[index].expenseDate,
        );
        _sortExpenses();
        notifyListeners();
      }

      if (_isOnline) {
        log('✅ Expense updated and synced');
      } else {
        log('📱 Expense updated (will sync when online)');
      }

      return true;
    } catch (e) {
      _setError('Failed to update expense: $e');
      return false;
    }
  }

  /// Delete (soft delete) an expense
  Future<bool> deleteExpense(String expenseId) async {
    try {
      await _ensureInitialized();
      _clearError();

      await _repository.deleteExpense(expenseId);

      // Update local cache
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();

      if (_isOnline) {
        log('✅ Expense deleted and synced');
      } else {
        log('📱 Expense deleted (will sync when online)');
      }

      return true;
    } catch (e) {
      _setError('Failed to delete expense: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PAYMENT OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Record a payment for an expense
  Future<ExpensePayment?> recordPayment({
    required String expenseId,
    required double paymentAmount,
    required PaymentMethod paymentMethod,
    String? transactionId,
    String? chequeNumber,
    String? bankName,
    DateTime? paymentDate,
  }) async {
    try {
      await _ensureInitialized();
      _clearError();

      // Get current user credentials from storage
      final userData = await StorageService.instance.getUserData();
      final recordedByUid = userData['uid'] ?? '';
      final recordedByName = userData['displayName'] ?? 'Unknown';

      final payment = await _repository.recordPayment(
        expenseId: expenseId,
        businessId: businessId,
        paymentAmount: paymentAmount,
        paymentMethod: paymentMethod,
        recordedByUid: recordedByUid,
        recordedByName: recordedByName,
        transactionId: transactionId,
        chequeNumber: chequeNumber,
        bankName: bankName,
        paymentDate: paymentDate,
      );

      if (payment != null) {
        // Update expense status
        await loadExpenseDetails(expenseId);

        if (_isOnline) {
          log('✅ Payment recorded and synced');
        } else {
          log('📱 Payment recorded (will sync when online)');
        }
      }

      return payment;
    } catch (e) {
      _setError('Failed to record payment: $e');
      return null;
    }
  }

  /// Get payment history for an expense
  Future<List<ExpensePayment>> getPaymentHistory(String expenseId) async {
    try {
      await _ensureInitialized();
      return await _repository.getPaymentHistory(expenseId);
    } catch (e) {
      log('❌ Error loading payment history: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ANALYTICS & REPORTING
  // ════════════════════════════════════════════════════════════════════════════

  /// Get expense statistics
  Future<Map<String, dynamic>> getExpenseStats() async {
    try {
      await _ensureInitialized();
      return await _repository.getExpenseStats(businessId);
    } catch (e) {
      log('❌ Error getting stats: $e');
      return {};
    }
  }

  /// Get expenses grouped by category
  Future<Map<String, dynamic>> getExpensesByCategory() async {
    try {
      await _ensureInitialized();
      return await _repository.getExpensesByCategory(businessId);
    } catch (e) {
      log('❌ Error getting category breakdown: $e');
      return {};
    }
  }

  /// Get monthly expense summary
  Future<List<Map<String, dynamic>>> getMonthlyExpenseSummary() async {
    try {
      await _ensureInitialized();
      return await _repository.getMonthlyExpenseSummary(businessId);
    } catch (e) {
      log('❌ Error getting monthly summary: $e');
      return [];
    }
  }

  /// Search expenses by title, vendor, or invoice
  Future<List<Expense>> searchExpenses(String query) async {
    try {
      if (query.isEmpty) {
        return _expenses;
      }

      return await _repository.searchExpenses(
        businessId: businessId,
        query: query,
      );
    } catch (e) {
      log('❌ Error searching expenses: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SUMMARY & STATISTICS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get total amount of all expenses
  double getTotalExpenses() {
    return _expenses.fold(0, (sum, e) => sum + e.amount);
  }

  /// Get total paid amount
  double getTotalPaid() {
    return _expenses
        .where((e) => e.paymentStatus == ExpensePaymentStatus.paid)
        .fold(0, (sum, e) => sum + e.amount);
  }

  /// Get pending/unpaid amount
  double getPendingAmount() {
    return _expenses
        .where((e) => e.paymentStatus != ExpensePaymentStatus.paid)
        .fold(0, (sum, e) => sum + e.amount);
  }

  /// Get count of unpaid expenses
  int getUnpaidCount() {
    return _expenses
        .where((e) => e.paymentStatus != ExpensePaymentStatus.paid)
        .length;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// Sort expenses by date descending
  void _sortExpenses() {
    _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  }

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
  }

  /// Set error message
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _error = null;
  }
}
