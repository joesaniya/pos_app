import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/services/payment_qr_service.dart';

/// Payment status enum
enum PaymentStatus {
  pending, // QR generated, awaiting payment
  completed, // Payment successful
  failed, // Payment failed
  expired, // QR code expired
  cancelled, // Payment cancelled by user
}

/// Payment request model for storing in Firestore
class PaymentRequest {
  final String paymentId;
  final String orderId;
  final String businessId;
  final double amount;
  final String upiString;
  final String upiId;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final String? transactionId;
  final String? errorMessage;

  PaymentRequest({
    required this.paymentId,
    required this.orderId,
    required this.businessId,
    required this.amount,
    required this.upiString,
    required this.upiId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.completedAt,
    this.transactionId,
    this.errorMessage,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'businessId': businessId,
      'amount': amount,
      'upiString': upiString,
      'upiId': upiId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'transactionId': transactionId,
      'errorMessage': errorMessage,
    };
  }

  /// Create from Firestore document
  factory PaymentRequest.fromFirestore(Map<String, dynamic> data) {
    return PaymentRequest(
      paymentId: data['paymentId'] ?? '',
      orderId: data['orderId'] ?? '',
      businessId: data['businessId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      upiString: data['upiString'] ?? '',
      upiId: data['upiId'] ?? '',
      status: PaymentStatus.values.byName(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 1)),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      transactionId: data['transactionId'],
      errorMessage: data['errorMessage'],
    );
  }

  /// Create a copy with modified fields
  PaymentRequest copyWith({
    String? paymentId,
    String? orderId,
    String? businessId,
    double? amount,
    String? upiString,
    String? upiId,
    PaymentStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? completedAt,
    String? transactionId,
    String? errorMessage,
  }) {
    return PaymentRequest(
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      businessId: businessId ?? this.businessId,
      amount: amount ?? this.amount,
      upiString: upiString ?? this.upiString,
      upiId: upiId ?? this.upiId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      completedAt: completedAt ?? this.completedAt,
      transactionId: transactionId ?? this.transactionId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for managing payment QR requests
class PaymentRequestProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'payment_requests';

  final Map<String, PaymentRequest> _paymentRequests = {};
  String? _currentPaymentId;
  String? _error;

  // Getters
  Map<String, PaymentRequest> get paymentRequests => _paymentRequests;
  PaymentRequest? get currentPayment =>
      _currentPaymentId != null ? _paymentRequests[_currentPaymentId] : null;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Generate payment QR for an order
  Future<PaymentRequest?> generatePaymentQr({
    required String orderId,
    required String businessId,
    required double orderAmount,
    required String upiId,
    required String payeeName,
    required String orderDescription,
  }) async {
    try {
      _error = null;

      // Validate inputs
      if (orderId.isEmpty || businessId.isEmpty) {
        _error = 'Invalid order or business ID';
        notifyListeners();
        return null;
      }

      if (orderAmount <= 0) {
        _error = 'Order amount must be greater than 0';
        notifyListeners();
        return null;
      }

      if (upiId.isEmpty || payeeName.isEmpty) {
        _error = 'UPI ID or payee name is missing';
        notifyListeners();
        return null;
      }

      // Generate payment QR data
      final paymentId = const Uuid().v4();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      final upiString = PaymentQrService.generatePaymentUpiString(
        upiId: upiId,
        payeeName: payeeName,
        amount: orderAmount,
        orderId: orderId,
        orderDescription: orderDescription,
      );

      final paymentRequest = PaymentRequest(
        paymentId: paymentId,
        orderId: orderId,
        businessId: businessId,
        amount: orderAmount,
        upiString: upiString,
        upiId: upiId,
        status: PaymentStatus.pending,
        createdAt: now,
        expiresAt: expiresAt,
      );

      // Store in Firestore
      await _firestore
          .collection(_collection)
          .doc(paymentId)
          .set(paymentRequest.toFirestore());

      // Update local state
      _paymentRequests[paymentId] = paymentRequest;
      _currentPaymentId = paymentId;

      notifyListeners();
      return paymentRequest;
    } catch (e) {
      _error = 'Failed to generate payment QR: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  /// Fetch payment request by ID
  Future<PaymentRequest?> fetchPaymentRequest(String paymentId) async {
    try {
      _error = null;

      final doc = await _firestore.collection(_collection).doc(paymentId).get();

      if (!doc.exists) {
        _error = 'Payment request not found';
        notifyListeners();
        return null;
      }

      final paymentRequest = PaymentRequest.fromFirestore(
        doc.data() as Map<String, dynamic>,
      );
      _paymentRequests[paymentId] = paymentRequest;
      _currentPaymentId = paymentId;

      notifyListeners();
      return paymentRequest;
    } catch (e) {
      _error = 'Failed to fetch payment request: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  /// Mark payment as completed
  Future<bool> markPaymentCompleted({
    required String paymentId,
    required double paidAmount,
    String? transactionId,
  }) async {
    try {
      _error = null;

      final payment = _paymentRequests[paymentId];
      if (payment == null) {
        _error = 'Payment request not found';
        notifyListeners();
        return false;
      }

      // Validate amount
      final isValid = PaymentQrService.validatePaymentAmount(
        payment.amount,
        paidAmount,
      );

      if (!isValid) {
        _error =
            'Payment amount mismatch. Expected ${PaymentQrService.formatAmount(payment.amount)}, got ${PaymentQrService.formatAmount(paidAmount)}';
        notifyListeners();
        return false;
      }

      // Update payment status
      final updatedPayment = payment.copyWith(
        status: PaymentStatus.completed,
        completedAt: DateTime.now(),
        transactionId: transactionId,
      );

      await _firestore
          .collection(_collection)
          .doc(paymentId)
          .update(updatedPayment.toFirestore());

      _paymentRequests[paymentId] = updatedPayment;
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to mark payment as completed: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Mark payment as failed
  Future<bool> markPaymentFailed({
    required String paymentId,
    String? errorMessage,
  }) async {
    try {
      _error = null;

      final payment = _paymentRequests[paymentId];
      if (payment == null) {
        _error = 'Payment request not found';
        notifyListeners();
        return false;
      }

      final updatedPayment = payment.copyWith(
        status: PaymentStatus.failed,
        errorMessage: errorMessage ?? 'Payment failed',
      );

      await _firestore
          .collection(_collection)
          .doc(paymentId)
          .update(updatedPayment.toFirestore());

      _paymentRequests[paymentId] = updatedPayment;
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to mark payment as failed: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Mark payment as expired
  Future<bool> markPaymentExpired(String paymentId) async {
    try {
      _error = null;

      final payment = _paymentRequests[paymentId];
      if (payment == null) {
        _error = 'Payment request not found';
        notifyListeners();
        return false;
      }

      final updatedPayment = payment.copyWith(status: PaymentStatus.expired);

      await _firestore
          .collection(_collection)
          .doc(paymentId)
          .update(updatedPayment.toFirestore());

      _paymentRequests[paymentId] = updatedPayment;
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to mark payment as expired: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Fetch all payments for an order
  Future<List<PaymentRequest>> fetchPaymentsByOrderId(String orderId) async {
    try {
      _error = null;

      final snapshot = await _firestore
          .collection(_collection)
          .where('orderId', isEqualTo: orderId)
          .orderBy('createdAt', descending: true)
          .get();

      final payments = snapshot.docs
          .map((doc) => PaymentRequest.fromFirestore(doc.data()))
          .toList();

      for (final payment in payments) {
        _paymentRequests[payment.paymentId] = payment;
      }

      notifyListeners();
      return payments;
    } catch (e) {
      _error = 'Failed to fetch payments by order ID: $e';
      debugPrint(_error);
      notifyListeners();
      return [];
    }
  }

  /// Refresh current payment status
  Future<bool> refreshPaymentStatus(String paymentId) async {
    try {
      _error = null;

      final doc = await _firestore.collection(_collection).doc(paymentId).get();

      if (!doc.exists) {
        _error = 'Payment request not found';
        notifyListeners();
        return false;
      }

      final payment = PaymentRequest.fromFirestore(
        doc.data() as Map<String, dynamic>,
      );
      _paymentRequests[paymentId] = payment;

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to refresh payment status: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Clear current payment
  void clearCurrentPayment() {
    _currentPaymentId = null;
    _error = null;
    notifyListeners();
  }

  /// Clear all cached payments
  void clearCache() {
    _paymentRequests.clear();
    _currentPaymentId = null;
    _error = null;
    notifyListeners();
  }

  /// Get payment status string
  static String getStatusString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.expired:
        return 'Expired';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Get payment status color
  static Color getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return const Color(0xFF0EA472); // Green
      case PaymentStatus.completed:
        return const Color(0xFF0EA472); // Green
      case PaymentStatus.failed:
        return const Color(0xFFE11D48); // Red
      case PaymentStatus.expired:
        return const Color(0xFFD97706); // Orange
      case PaymentStatus.cancelled:
        return const Color(0xFF9CA3AF); // Gray
    }
  }

  /// Get payment status icon
  static IconData getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Icons.hourglass_bottom_rounded;
      case PaymentStatus.completed:
        return Icons.check_circle_rounded;
      case PaymentStatus.failed:
        return Icons.error_rounded;
      case PaymentStatus.expired:
        return Icons.schedule_rounded;
      case PaymentStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }
}
