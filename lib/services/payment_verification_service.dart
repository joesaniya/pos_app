import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/services/payment_qr_service.dart';

/// Service for verifying and processing payment confirmations
/// Handles webhook callbacks and payment validation
class PaymentVerificationService {
  static const String _transactionsCollection = 'payment_transactions';
  static const double _amountTolerance = 0.01; // Maximum tolerance in ₹

  /// Process a payment confirmation
  ///
  /// Called when payment app returns confirmation
  /// Validates amount and marks payment as completed
  static Future<PaymentVerificationResult> processPaymentConfirmation({
    required String paymentId,
    required String transactionId,
    required double paidAmount,
    required String paymentMethod,
    required String orderId,
  }) async {
    try {
      // Get payment request from Firestore
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) {
        return PaymentVerificationResult(
          success: false,
          error: 'Payment request not found',
        );
      }

      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final expectedAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
      final orderId = paymentData['orderId'] as String;
      final businessId = paymentData['businessId'] as String;
      final upiId = paymentData['upiId'] as String;

      // Validate amount
      if (!PaymentQrService.validatePaymentAmount(expectedAmount, paidAmount)) {
        return PaymentVerificationResult(
          success: false,
          error:
              'Amount mismatch. Expected ₹$expectedAmount, received ₹$paidAmount',
        );
      }

      // Store transaction record
      final transactionRecord = {
        'paymentId': paymentId,
        'orderId': orderId,
        'businessId': businessId,
        'transactionId': transactionId,
        'upiId': upiId,
        'expectedAmount': expectedAmount,
        'paidAmount': paidAmount,
        'amountMatches':
            (expectedAmount - paidAmount).abs() <= _amountTolerance,
        'paymentMethod': paymentMethod,
        'status': 'completed',
        'receivedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
      };

      // Save transaction
      await FirebaseFirestore.instance
          .collection(_transactionsCollection)
          .doc(transactionId)
          .set(transactionRecord);

      // Update payment status
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
            'status': 'completed',
            'transactionId': transactionId,
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Update order with payment confirmation
      await _updateOrderPaymentStatus(
        orderId: orderId,
        paymentId: paymentId,
        transactionId: transactionId,
        amount: paidAmount,
        status: 'paid',
      );

      return PaymentVerificationResult(
        success: true,
        paymentId: paymentId,
        transactionId: transactionId,
        amount: paidAmount,
        message: 'Payment verified successfully',
      );
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        error: 'Verification failed: $e',
      );
    }
  }

  /// Handle payment failure/cancellation
  static Future<PaymentVerificationResult> handlePaymentFailure({
    required String paymentId,
    required String orderId,
    required String reason,
  }) async {
    try {
      // Update payment status
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({'status': 'failed', 'errorMessage': reason});

      // Update order
      await _updateOrderPaymentStatus(
        orderId: orderId,
        paymentId: paymentId,
        status: 'payment_failed',
        amount: 0,
      );

      return PaymentVerificationResult(
        success: true,
        message: 'Payment failure recorded',
      );
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        error: 'Failed to record payment failure: $e',
      );
    }
  }

  /// Get payment transaction record
  static Future<PaymentTransaction?> getTransaction(
    String transactionId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_transactionsCollection)
          .doc(transactionId)
          .get();

      if (!doc.exists) return null;

      return PaymentTransaction.fromFirestore(
        doc.data() as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Error fetching transaction: $e');
      return null;
    }
  }

  /// Reconcile payment with order
  static Future<bool> reconcilePayment({
    required String orderId,
    required double orderAmount,
    required String paymentId,
  }) async {
    try {
      // Get payment request
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) return false;

      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final paymentAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
      final paymentStatus = paymentData['status'] as String?;

      // Check if amounts match
      final amountsMatch =
          (orderAmount - paymentAmount).abs() <= _amountTolerance;

      // Check if payment is completed
      final isCompleted = paymentStatus == 'completed';

      if (!amountsMatch || !isCompleted) {
        return false;
      }

      // Mark order as reconciled
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'paymentReconciled': true,
            'reconciliationTime': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      debugPrint('Error reconciling payment: $e');
      return false;
    }
  }

  /// Update order payment status
  static Future<void> _updateOrderPaymentStatus({
    required String orderId,
    required String paymentId,
    String? transactionId,
    required double amount,
    required String status,
  }) async {
    try {
      final updateData = {
        'paymentStatus': status,
        'paymentId': paymentId,
        'paidAmount': amount,
        'paymentUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (transactionId != null) {
        updateData['transactionId'] = transactionId;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);
    } catch (e) {
      debugPrint('Error updating order payment status: $e');
      rethrow;
    }
  }

  /// Verify amount with tolerance
  static bool verifyAmount(double expected, double actual) {
    return (expected - actual).abs() <= _amountTolerance;
  }

  /// Format verification report
  static String getVerificationReport({
    required double expectedAmount,
    required double receivedAmount,
    required bool verified,
  }) {
    final difference = (expectedAmount - receivedAmount).abs();
    return '''
Payment Verification Report
==========================
Expected Amount: ₹$expectedAmount
Received Amount: ₹$receivedAmount
Difference: ₹${difference.toStringAsFixed(2)}
Tolerance: ₹$_amountTolerance
Status: ${verified ? 'VERIFIED ✓' : 'FAILED ✗'}
    ''';
  }
}

/// Result of payment verification
class PaymentVerificationResult {
  final bool success;
  final String? paymentId;
  final String? transactionId;
  final double? amount;
  final String message;
  final String? error;

  PaymentVerificationResult({
    required this.success,
    this.paymentId,
    this.transactionId,
    this.amount,
    this.message = '',
    this.error,
  });

  @override
  String toString() {
    if (success) {
      return 'PaymentVerificationResult(success: true, transactionId: $transactionId, amount: $amount)';
    } else {
      return 'PaymentVerificationResult(success: false, error: $error)';
    }
  }
}

/// Payment transaction record
class PaymentTransaction {
  final String transactionId;
  final String paymentId;
  final String orderId;
  final String businessId;
  final String upiId;
  final double expectedAmount;
  final double paidAmount;
  final bool amountMatches;
  final String paymentMethod;
  final String status;
  final DateTime receivedAt;
  final DateTime verifiedAt;

  PaymentTransaction({
    required this.transactionId,
    required this.paymentId,
    required this.orderId,
    required this.businessId,
    required this.upiId,
    required this.expectedAmount,
    required this.paidAmount,
    required this.amountMatches,
    required this.paymentMethod,
    required this.status,
    required this.receivedAt,
    required this.verifiedAt,
  });

  factory PaymentTransaction.fromFirestore(Map<String, dynamic> data) {
    return PaymentTransaction(
      transactionId: data['transactionId'] ?? '',
      paymentId: data['paymentId'] ?? '',
      orderId: data['orderId'] ?? '',
      businessId: data['businessId'] ?? '',
      upiId: data['upiId'] ?? '',
      expectedAmount: (data['expectedAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      amountMatches: data['amountMatches'] ?? false,
      paymentMethod: data['paymentMethod'] ?? 'upi',
      status: data['status'] ?? 'pending',
      receivedAt:
          (data['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt:
          (data['verifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'paymentId': paymentId,
      'orderId': orderId,
      'businessId': businessId,
      'upiId': upiId,
      'expectedAmount': expectedAmount,
      'paidAmount': paidAmount,
      'amountMatches': amountMatches,
      'paymentMethod': paymentMethod,
      'status': status,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'verifiedAt': Timestamp.fromDate(verifiedAt),
    };
  }
}
