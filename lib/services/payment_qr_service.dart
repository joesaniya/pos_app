import 'package:uuid/uuid.dart';

/// Service for generating UPI payment strings with locked amounts
/// This ensures the exact amount is charged when QR is scanned
class PaymentQrService {
  /// Generates a UPI payment string with locked amount
  ///
  /// Format: upi://pay?pa=UPI_ID&pn=PAYEE_NAME&am=AMOUNT&tn=DESCRIPTION&tr=REFERENCE
  ///
  /// Parameters:
  /// - [upiId]: Valid UPI ID (e.g., merchant@okhdfcbank)
  /// - [payeeName]: Name displayed in UPI app (business name)
  /// - [amount]: Exact payment amount (₹)
  /// - [orderId]: Order ID for tracking
  /// - [orderDescription]: What the payment is for (e.g., "Food Order #12345")
  static String generatePaymentUpiString({
    required String upiId,
    required String payeeName,
    required double amount,
    required String orderId,
    String? orderDescription,
  }) {
    // Validate amount
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than 0');
    }

    // Format amount to 2 decimal places
    final formattedAmount = amount.toStringAsFixed(2);

    // Clean payee name (remove special characters, limit length)
    final cleanPayeeName = payeeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .substring(0, Math.min(60, payeeName.length));

    // Create description with order reference
    final description = orderDescription ?? 'Payment for Order #$orderId';
    final cleanDescription = description
        .replaceAll(RegExp(r'[^a-zA-Z0-9 #\-\.]'), '')
        .trim()
        .substring(0, Math.min(80, description.length));

    // Generate payment reference ID
    final paymentRefId =
        'ORD${orderId}_${DateTime.now().millisecondsSinceEpoch}';

    // Build UPI string
    final upiString =
        'upi://pay'
        '?pa=${Uri.encodeComponent(upiId)}'
        '&pn=${Uri.encodeComponent(cleanPayeeName)}'
        '&am=$formattedAmount'
        '&tn=${Uri.encodeComponent(cleanDescription)}'
        '&tr=${Uri.encodeComponent(paymentRefId)}';

    return upiString;
  }

  /// Generates a QR code payload as a Map for storage/display
  static Map<String, dynamic> generatePaymentQrPayload({
    required String upiId,
    required String payeeName,
    required double amount,
    required String orderId,
    String? orderDescription,
    String? businessId,
  }) {
    final upiString = generatePaymentUpiString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      orderId: orderId,
      orderDescription: orderDescription,
    );

    return {
      'orderId': orderId,
      'upiId': upiId,
      'payeeName': payeeName,
      'amount': amount,
      'amountFormatted': amount.toStringAsFixed(2),
      'description': orderDescription ?? 'Payment for Order #$orderId',
      'upiString': upiString,
      'paymentRefId': 'ORD${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      'businessId': businessId,
      'generatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
      'status': 'pending', // pending, completed, failed, expired
      'currency': 'INR',
    };
  }

  /// Extracts payment information from UPI string
  static Map<String, String?> extractPaymentInfo(String upiString) {
    try {
      // Remove "upi://pay?" prefix
      final params = upiString.replaceFirst('upi://pay?', '');

      // Parse parameters
      final map = <String, String?>{};
      for (final param in params.split('&')) {
        final parts = param.split('=');
        if (parts.length == 2) {
          map[parts[0]] = Uri.decodeComponent(parts[1]);
        }
      }

      return {
        'upiId': map['pa'], // Payee address
        'payeeName': map['pn'], // Payee name
        'amount': map['am'], // Amount
        'description': map['tn'], // Transaction note
        'reference': map['tr'], // Transaction reference
      };
    } catch (e) {
      return {'error': 'Failed to parse UPI string: $e'};
    }
  }

  /// Validates payment amount matches the locked amount
  /// This prevents amount tampering
  static bool validatePaymentAmount(double expectedAmount, double paidAmount) {
    // Allow small rounding differences (up to 0.01)
    final difference = (expectedAmount - paidAmount).abs();
    return difference <= 0.01;
  }

  /// Generates a unique payment tracking ID
  static String generatePaymentTrackingId(String orderId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PAY_${orderId}_$timestamp';
  }

  /// Formats amount for display (₹ symbol)
  static String formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Gets expiration status
  static bool isPaymentQrExpired(DateTime expiresAt) {
    return DateTime.now().isAfter(expiresAt);
  }
}

// Helper class
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
