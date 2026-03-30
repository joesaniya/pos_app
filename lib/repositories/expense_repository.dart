// lib/repositories/expense_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  EXPENSE REPOSITORY — Hybrid Online-First Pattern
//  Pattern: Save local, try API if online, return with sync indicator
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';

import 'package:pos_app/models/expense_model.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ExpenseRepository {
  ExpenseRepository({
    required Supabase supabase,
    required ConnectivityService connectivityService,
  }) : _supabase = supabase,
       _connectivity = connectivityService;

  final Supabase _supabase;
  final ConnectivityService _connectivity;

  // ════════════════════════════════════════════════════════════════════════════
  // RETRY LOGIC — Automatic reconnection with exponential backoff
  // ════════════════════════════════════════════════════════════════════════════

  /// Execute query with automatic retry on connection failure
  Future<T> _withRetry<T>(
    Future<T> Function() query, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
  }) async {
    int retryCount = 0;
    Duration delay = baseDelay;

    while (true) {
      try {
        return await query();
      } catch (e) {
        retryCount++;
        final isNetworkError =
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection') ||
            e.toString().contains('refused');

        if (!isNetworkError || retryCount >= maxRetries) {
          rethrow;
        }

        log('🔄 Retry $retryCount/$maxRetries after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).toInt());
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CREATE OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Create expense (hybrid online-first pattern)
  Future<Expense?> createExpense({
    required String businessId,
    required int expenseNumber,
    required String title,
    required String categoryId,
    required String categoryName,
    required String vendorName,
    required double amount,
    required DateTime expenseDate,
    required String createdByUid,
    required String createdByName,
    DateTime? dueDate,
    String? description,
    String? notes,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? gstAmount,
    String? gstNumber,
  }) async {
    try {
      final now = DateTime.now();
      final expenseId = const Uuid().v4(); // Generate proper UUID

      final expense = Expense(
        id: expenseId,
        businessId: businessId,
        expenseNumber: expenseNumber,
        title: title,
        description: description,
        categoryId: categoryId,
        categoryName: categoryName,
        vendorName: vendorName,
        amount: amount,
        expenseDate: expenseDate,
        dueDate: dueDate,
        status: ExpenseStatus.pending,
        paymentStatus: ExpensePaymentStatus.unpaid,
        paidAmount: 0,
        remainingAmount: amount,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        gstAmount: gstAmount,
        gstNumber: gstNumber,
        notes: notes,
        createdByUid: createdByUid,
        createdByName: createdByName,
        createdAt: now,
        updatedAt: now,
      );

      // Attempt immediate API call if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.client.from('expenses').insert(expense.toJson());
          log('✅ Expense created online: ${expense.id}');
          return expense;
        } catch (e) {
          log('⚠️ Online creation failed: $e');
          // Still return expense, allow provider to handle retry
          return expense;
        }
      } else {
        log('📱 Offline mode - expense ready for sync: ${expense.id}');
        return expense;
      }
    } catch (e) {
      log('❌ Create expense error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Fetch all expenses for business
  Future<List<Expense>> getExpensesByBusiness(String businessId) async {
    return _withRetry(() async {
      final response = await _supabase.client
          .from('vw_expense_dashboard')
          .select()
          .eq('business_id', businessId)
          .order('expense_date', ascending: false);

      return (response as List).map((json) => Expense.fromJson(json)).toList();
    });
  }

  /// Fetch single expense by ID
  Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final response = await _supabase.client
          .from('expenses')
          .select()
          .eq('id', expenseId)
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      log('❌ Fetch expense error: $e');
      return null;
    }
  }

  /// Search expenses by criteria
  Future<List<Expense>> searchExpenses({
    required String businessId,
    required String query,
  }) async {
    try {
      // Search by title, vendor, or invoice number
      var results = await _supabase.client
          .from('vw_expense_dashboard')
          .select()
          .eq('business_id', businessId)
          .or(
            'title.ilike.%$query%,vendor_name.ilike.%$query%,invoice_number.ilike.%$query%',
          )
          .order('expense_date', ascending: false);

      return (results as List).map((json) => Expense.fromJson(json)).toList();
    } catch (e) {
      log('❌ Search expenses error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UPDATE OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Update expense (hybrid pattern)
  Future<void> updateExpense({
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      // Attempt API call if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.client
              .from('expenses')
              .update(updates)
              .eq('id', expenseId);
          log('✅ Expense updated online: $expenseId');
          return;
        } catch (e) {
          log('⚠️ Online update failed: $e');
          // Allow provider to handle retry
          return;
        }
      } else {
        log('📱 Offline mode - update queued for sync: $expenseId');
      }
    } catch (e) {
      log('❌ Update expense error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DELETE OPERATIONS (Soft Delete)
  // ════════════════════════════════════════════════════════════════════════════

  /// Soft delete expense (hybrid pattern)
  Future<void> deleteExpense(String expenseId) async {
    try {
      // Attempt API call if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.client
              .from('expenses')
              .update({
                'is_active': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', expenseId);
          log('✅ Expense deleted online: $expenseId');
          return;
        } catch (e) {
          log('⚠️ Online delete failed: $e');
          return;
        }
      } else {
        log('📱 Offline mode - delete queued for sync: $expenseId');
      }
    } catch (e) {
      log('❌ Delete expense error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PAYMENT OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Record payment (hybrid pattern)
  Future<ExpensePayment?> recordPayment({
    required String expenseId,
    required String businessId,
    required double paymentAmount,
    required PaymentMethod paymentMethod,
    required String recordedByUid,
    required String recordedByName,
    String? transactionId,
    String? chequeNumber,
    String? bankName,
    DateTime? paymentDate,
  }) async {
    try {
      final now = DateTime.now();
      final payment = ExpensePayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        businessId: businessId,
        expenseId: expenseId,
        paymentAmount: paymentAmount,
        paymentDate: paymentDate ?? now,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        chequeNumber: chequeNumber,
        bankName: bankName,
        paymentStatus: 'completed',
        recordedByUid: recordedByUid,
        recordedByName: recordedByName,
        createdAt: now,
        updatedAt: now,
      );

      // Attempt API call if online
      if (_connectivity.isOnline) {
        try {
          await _supabase.client
              .from('expense_payments')
              .insert(payment.toJson());

          // Update expense status
          await _updateExpensePaymentStatus(expenseId, paymentAmount);

          log('✅ Payment recorded online: ${payment.id}');
          return payment;
        } catch (e) {
          log('⚠️ Online payment failed: $e');
          // Still return payment, allow provider to handle retry
          return payment;
        }
      } else {
        log('📱 Offline mode - payment ready for sync: ${payment.id}');
        return payment;
      }
    } catch (e) {
      log('❌ Record payment error: $e');
      rethrow;
    }
  }

  /// Update expense payment status based on total paid
  Future<void> _updateExpensePaymentStatus(
    String expenseId,
    double recentPayment,
  ) async {
    try {
      // Fetch current expense
      final expense = await getExpenseById(expenseId);
      if (expense == null) {
        return;
      }

      final newPaidAmount = expense.paidAmount + recentPayment;
      final newStatus = newPaidAmount >= expense.amount
          ? ExpensePaymentStatus.paid
          : newPaidAmount > 0
          ? ExpensePaymentStatus.partial
          : ExpensePaymentStatus.unpaid;

      await updateExpense(
        expenseId: expenseId,
        updates: {
          'paid_amount': newPaidAmount,
          'payment_status': newStatus.dbValue,
        },
      );
    } catch (e) {
      log('❌ Update payment status error: $e');
    }
  }

  /// Get payment history for expense
  Future<List<ExpensePayment>> getPaymentHistory(String expenseId) async {
    try {
      final response = await _supabase.client
          .from('expense_payments')
          .select()
          .eq('expense_id', expenseId)
          .order('payment_date', ascending: false);

      return (response as List)
          .map((json) => ExpensePayment.fromJson(json))
          .toList();
    } catch (e) {
      log('❌ Fetch payment history error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ANALYTICS & REPORTING
  // ════════════════════════════════════════════════════════════════════════════

  /// Get expense statistics
  Future<Map<String, dynamic>> getExpenseStats(String businessId) async {
    try {
      final response =
          await _supabase.client.rpc(
                'fn_get_expense_stats',
                params: {'p_business_id': businessId},
              )
              as Map<String, dynamic>;

      return response;
    } catch (e) {
      log('❌ Fetch expense stats error: $e');
      rethrow;
    }
  }

  /// Get expenses by category
  Future<Map<String, dynamic>> getExpensesByCategory(String businessId) async {
    try {
      final response = await _supabase.client
          .from('expenses')
          .select('expense_category_id, category_name')
          .eq('business_id', businessId)
          .eq('is_active', true);

      // Group by category manually
      final Map<String, dynamic> grouped = {};
      for (final expense in response as List) {
        final categoryId = expense['expense_category_id'];
        if (!grouped.containsKey(categoryId)) {
          grouped[categoryId] = {
            'category_id': categoryId,
            'category_name': expense['category_name'],
            'count': 0,
            'total': 0.0,
          };
        }
        grouped[categoryId]['count']++;
      }

      return grouped;
    } catch (e) {
      log('❌ Fetch category breakdown error: $e');
      rethrow;
    }
  }

  /// Get monthly summary
  Future<List<Map<String, dynamic>>> getMonthlyExpenseSummary(
    String businessId,
  ) async {
    try {
      final response =
          await _supabase.client.rpc(
                'fn_get_monthly_expense_summary',
                params: {'p_business_id': businessId},
              )
              as List;

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('❌ Fetch monthly summary error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORIES
  // ════════════════════════════════════════════════════════════════════════════

  /// Load all global expense categories (shared across all businesses)
  Future<List<ExpenseCategory>> getCategories(String businessId) async {
    log('🔹 [ExpenseRepo] getCategories() called - businessId=$businessId');
    return _withRetry(() async {
      try {
        log(
          '🔹 [ExpenseRepo] Querying expense_categories table with is_active=true...',
        );
        final response = await _supabase.client
            .from('expense_categories')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true);

        log('🔹 [ExpenseRepo] Raw response type: ${response.runtimeType}');
        log('🔹 [ExpenseRepo] Raw response: $response');

        if (response is! List) {
          log(
            '❌ [ExpenseRepo] Response is not a List! Got ${response.runtimeType}',
          );
          return [];
        }

        log(
          '🔹 [ExpenseRepo] Response is List with ${(response as List).length} items',
        );

        final categories = (response as List).map((json) {
          try {
            final cat = ExpenseCategory.fromJson(json);
            log('✅ [ExpenseRepo] Parsed category: ${cat.name} (${cat.id})');
            return cat;
          } catch (e) {
            log('❌ [ExpenseRepo] Failed to parse category from $json: $e');
            rethrow;
          }
        }).toList();

        log(
          '✅ [ExpenseRepo] Successfully loaded ${categories.length} categories',
        );
        return categories;
      } catch (e, stackTrace) {
        log('❌ [ExpenseRepo] Error in getCategories: $e');
        log('❌ [ExpenseRepo] Stack trace: $stackTrace');
        rethrow;
      }
    });
  }
}
