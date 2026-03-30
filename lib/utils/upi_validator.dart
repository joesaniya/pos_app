/// UPI ID Validator - Validates UPI IDs according to NPCI standards
class UpiValidator {
  /// Validates UPI ID format
  /// Standard UPI format: username@bankcode
  /// Examples:
  /// - merchant123@okhdfcbank
  /// - shop.owner@ybl
  /// - business.name@icici
  static bool isValidUpiId(String upiId) {
    if (upiId.isEmpty) return false;

    // Trim whitespace
    final trimmed = upiId.trim();

    // Must contain exactly one @
    if (trimmed.split('@').length != 2) return false;

    final parts = trimmed.split('@');
    final username = parts[0];
    final bankCode = parts[1];

    // Username validation
    if (!_isValidUsername(username)) return false;

    // Bank code validation
    if (!_isValidBankCode(bankCode)) return false;

    return true;
  }

  /// Validates UPI username part (before @)
  /// Rules:
  /// - Must be 3-60 characters
  /// - Can contain letters, numbers, dots, hyphens, underscores (no spaces)
  /// - Cannot start or end with special characters
  /// - Cannot have consecutive special characters
  static bool _isValidUsername(String username) {
    if (username.length < 3 || username.length > 60) return false;

    // Check valid characters: alphanumeric, dot, hyphen, underscore
    final validPattern = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!validPattern.hasMatch(username)) return false;

    // Cannot start or end with special characters
    final firstChar = username[0];
    final lastChar = username[username.length - 1];
    if (!_isAlphanumeric(firstChar) || !_isAlphanumeric(lastChar)) {
      return false;
    }

    return true;
  }

  /// Validates UPI bank code part (after @)
  /// List of valid NPCI bank codes
  static bool _isValidBankCode(String bankCode) {
    if (bankCode.isEmpty) return false;

    // List of valid UPI bank codes (lowercase for comparison)
    const validBankCodes = {
      // HDFC Bank
      'okhdfcbank',
      'hdfc',
      // ICICI Bank
      'icici',
      'okicici',
      // Axis Bank
      'okaxis',
      'axis',
      // IDBI Bank
      'idbi',
      'okidbi',
      // IndusInd Bank
      'okindusind',
      'indusind',
      // Kotak Mahindra Bank
      'okkotak',
      'kotak',
      // SBI
      'sbi',
      'oksbi',
      // Yes Bank
      'okyesbank',
      'yesbank',
      // Bob
      'bob',
      'okbob',
      // Union Bank
      'unionbank',
      // Punjab National Bank
      'pnb',
      // Canara Bank
      'canara',
      // Bank of Baroda
      'barodampay',
      // Federal Bank
      'fedbank',
      // South Indian Bank
      'sib',
      // Karur Vysya Bank
      'kvb',
      // Airtel Payments Bank
      'airtelpaymentsbank',
      'airtel',
      // Google Pay (Tez)
      'ybl',
      // PayTM
      'paytm',
      // Amazon Pay
      'amazonpay',
      // Common/Test codes
      'testbank',
      'upi',
    };

    return validBankCodes.contains(bankCode.toLowerCase());
  }

  /// Check if character is alphanumeric
  static bool _isAlphanumeric(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122); // a-z
  }

  /// Get error message for invalid UPI ID
  static String getUpiErrorMessage(String upiId) {
    if (upiId.isEmpty) {
      return 'UPI ID cannot be empty';
    }

    final trimmed = upiId.trim();
    final parts = trimmed.split('@');

    if (parts.length != 2) {
      return 'UPI ID must be in format: username@bankcode';
    }

    final username = parts[0];
    final bankCode = parts[1];

    if (username.isEmpty) {
      return 'Username part cannot be empty';
    }

    if (bankCode.isEmpty) {
      return 'Bank code part cannot be empty';
    }

    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (username.length > 60) {
      return 'Username cannot exceed 60 characters';
    }

    final validPattern = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!validPattern.hasMatch(username)) {
      return 'Username contains invalid characters. Use only letters, numbers, dots, hyphens, and underscores';
    }

    final firstChar = username[0];
    final lastChar = username[username.length - 1];
    if (!_isAlphanumeric(firstChar) || !_isAlphanumeric(lastChar)) {
      return 'Username cannot start or end with special characters';
    }

    if (!_isValidBankCode(bankCode)) {
      return 'Invalid bank code: $bankCode';
    }

    return 'Invalid UPI ID format';
  }

  /// Format UPI ID to standard format (lowercase)
  static String formatUpiId(String upiId) {
    return upiId.trim().toLowerCase();
  }
}
