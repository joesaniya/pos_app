// lib/utils/promo_code_validator.dart
// Complete promo code validation utility

import 'dart:developer';

import 'package:pos_app/models/promo_code_model.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE VALIDATION ERROR ENUM
// ══════════════════════════════════════════════════════════════

enum PromoCodeValidationError {
  promoCodeNotFound,
  promoCodeInactive,
  promoCodeExpired,
  minimumOrderValueNotMet,
  notApplicableToCustomer,
  notApplicableToItems,
  notApplicableToCategories,
  businessMismatch,
}

extension PromoCodeValidationErrorExt on PromoCodeValidationError {
  String get message {
    switch (this) {
      case PromoCodeValidationError.promoCodeNotFound:
        return 'Promo code not found';
      case PromoCodeValidationError.promoCodeInactive:
        return 'Promo code is inactive';
      case PromoCodeValidationError.promoCodeExpired:
        return 'Promo code has expired';
      case PromoCodeValidationError.minimumOrderValueNotMet:
        return 'Order does not meet minimum amount required';
      case PromoCodeValidationError.notApplicableToCustomer:
        return 'Promo code is not applicable to your account';
      case PromoCodeValidationError.notApplicableToItems:
        return 'Promo code is not applicable to selected items';
      case PromoCodeValidationError.notApplicableToCategories:
        return 'Promo code is not applicable to your order categories';
      case PromoCodeValidationError.businessMismatch:
        return 'Promo code is not valid for this business';
    }
  }

  String get emoji {
    switch (this) {
      case PromoCodeValidationError.promoCodeNotFound:
        return '🔍';
      case PromoCodeValidationError.promoCodeInactive:
        return '🚫';
      case PromoCodeValidationError.promoCodeExpired:
        return '⏰';
      case PromoCodeValidationError.minimumOrderValueNotMet:
        return '💰';
      case PromoCodeValidationError.notApplicableToCustomer:
        return '👤';
      case PromoCodeValidationError.notApplicableToItems:
        return '🍽️';
      case PromoCodeValidationError.notApplicableToCategories:
        return '📂';
      case PromoCodeValidationError.businessMismatch:
        return '🏪';
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE VALIDATOR UTILITY
// ══════════════════════════════════════════════════════════════

class PromoCodeValidator {
  /// Validate promo code with all checks
  static PromoCodeValidationResult validatePromoCode({
    required PromoCode promoCode,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
    List<String>? selectedItemIds,
    List<String>? selectedCategoryIds,
  }) {
    // ─ Check if business matches
    if (promoCode.businessId != businessId) {
      return _createErrorResult(PromoCodeValidationError.businessMismatch);
    }

    // ─ Check if promo code is active
    if (!promoCode.isActive) {
      return _createErrorResult(PromoCodeValidationError.promoCodeInactive);
    }

    // ─ Check if promo code is within validity period
    // Use LOCAL timezone for comparison (dates are parsed as local time)
    final now = DateTime.now();
    final startDate = promoCode.startDate;
    // Add 1 day to expiry date so entire expiry day is valid
    final expiryDeadline = promoCode.expiryDate.add(const Duration(days: 1));

    // Detailed logging for debugging (show local time)
    log('[PromoCodeValidator] Date comparison for code: ${promoCode.code}');
    log('[PromoCodeValidator] Now (Local): $now');
    log('[PromoCodeValidator] Start Date (Local): $startDate');
    log('[PromoCodeValidator] Expiry Date (Local): ${promoCode.expiryDate}');
    log('[PromoCodeValidator] Expiry Deadline (Local): $expiryDeadline');
    log('[PromoCodeValidator] Is before start? ${now.isBefore(startDate)}');
    log('[PromoCodeValidator] Is after expiry? ${now.isAfter(expiryDeadline)}');

    if (now.isBefore(startDate)) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthName = months[startDate.month - 1];
      return _createErrorResult(
        PromoCodeValidationError.promoCodeExpired,
        additionalMessage:
            'Promo code starts from ${startDate.day} $monthName ${startDate.year}',
      );
    }

    if (now.isAfter(expiryDeadline)) {
      return _createErrorResult(PromoCodeValidationError.promoCodeExpired);
    }

    // ─ Check minimum order value
    if (promoCode.minOrderValue > 0 && orderAmount < promoCode.minOrderValue) {
      return _createErrorResult(
        PromoCodeValidationError.minimumOrderValueNotMet,
      );
    }

    // ─ Check customer-specific promo code
    if (promoCode.customerId != null && promoCode.customerId != customerId) {
      return _createErrorResult(
        PromoCodeValidationError.notApplicableToCustomer,
      );
    }

    // ─ Check if applicable to selected items
    if (selectedItemIds != null &&
        selectedItemIds.isNotEmpty &&
        promoCode.applicableItems != null &&
        promoCode.applicableItems!.isNotEmpty) {
      final hasApplicableItem = selectedItemIds.any(
        (itemId) => promoCode.appliesToItem(itemId),
      );

      if (!hasApplicableItem) {
        final restrictedCount = selectedItemIds.length;
        return _createErrorResult(
          PromoCodeValidationError.notApplicableToItems,
          additionalMessage:
              'All $restrictedCount items in this order are restricted',
        );
      }

      // Check if some items are restricted (warning case)
      final restrictedItems = promoCode.getRestrictedItems(selectedItemIds);
      if (restrictedItems.isNotEmpty) {
        log(
          '[PromoCodeValidator] ⚠️  Promo has ${restrictedItems.length} restricted items',
        );
      }
    }

    // ─ Check if applicable to selected categories
    if (selectedCategoryIds != null &&
        selectedCategoryIds.isNotEmpty &&
        promoCode.applicableCategories != null &&
        promoCode.applicableCategories!.isNotEmpty) {
      final hasApplicableCategory = selectedCategoryIds.any(
        (catId) => promoCode.appliesToCategory(catId),
      );

      if (!hasApplicableCategory) {
        final restrictedCount = selectedCategoryIds.length;
        return _createErrorResult(
          PromoCodeValidationError.notApplicableToCategories,
          additionalMessage: 'All $restrictedCount categories are restricted',
        );
      }

      // Check if some categories are restricted (warning case)
      final restrictedCats = promoCode.getRestrictedCategories(
        selectedCategoryIds,
      );
      if (restrictedCats.isNotEmpty) {
        log(
          '[PromoCodeValidator] ⚠️  Promo has ${restrictedCats.length} restricted categories',
        );
      }
    }

    // ─ All validations passed
    log(
      '[PromoCodeValidator] ✅ Promo code validation successful: ${promoCode.code}',
    );
    return PromoCodeValidationResult(
      isValid: true,
      promoCodeId: promoCode.id,
      discountType: promoCode.discountType.value,
      discountValue: promoCode.discountValue,
      errorMessage: null,
    );
  }

  /// Validate order amount against minimum requirement
  static bool validateMinimumOrderAmount(
    PromoCode promoCode,
    double orderAmount,
  ) {
    return promoCode.meetsMinimumOrderValue(orderAmount);
  }

  /// Validate customer eligibility
  static bool validateCustomerEligibility(
    PromoCode promoCode,
    String? customerId,
  ) {
    if (promoCode.customerId == null) return true;
    return promoCode.customerId == customerId;
  }

  /// Validate item applicability
  static bool validateItemApplicability(
    PromoCode promoCode,
    List<String> itemIds,
  ) {
    if (promoCode.applicableItems == null ||
        promoCode.applicableItems!.isEmpty) {
      return true; // Applies to all items
    }

    return itemIds.any((itemId) => promoCode.appliesToItem(itemId));
  }

  /// Validate category applicability
  static bool validateCategoryApplicability(
    PromoCode promoCode,
    List<String> categoryIds,
  ) {
    if (promoCode.applicableCategories == null ||
        promoCode.applicableCategories!.isEmpty) {
      return true; // Applies to all categories
    }

    return categoryIds.any((catId) => promoCode.appliesToCategory(catId));
  }

  /// Validate if promo code is currently active (time-based)
  static bool validateTimeValidity(PromoCode promoCode) {
    final now = DateTime.now();
    return now.isAfter(promoCode.startDate) &&
        now.isBefore(promoCode.expiryDate);
  }

  /// Check all validation errors for a promo code
  static List<PromoCodeValidationError> checkAllValidationErrors({
    required PromoCode promoCode,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
    List<String>? selectedItemIds,
    List<String>? selectedCategoryIds,
  }) {
    final errors = <PromoCodeValidationError>[];

    // Business check
    if (promoCode.businessId != businessId) {
      errors.add(PromoCodeValidationError.businessMismatch);
    }

    // Active check
    if (!promoCode.isActive) {
      errors.add(PromoCodeValidationError.promoCodeInactive);
    }

    // Time validity check
    if (!validateTimeValidity(promoCode)) {
      errors.add(PromoCodeValidationError.promoCodeExpired);
    }

    // Minimum order value check
    if (!validateMinimumOrderAmount(promoCode, orderAmount)) {
      errors.add(PromoCodeValidationError.minimumOrderValueNotMet);
    }

    // Customer eligibility check
    if (!validateCustomerEligibility(promoCode, customerId)) {
      errors.add(PromoCodeValidationError.notApplicableToCustomer);
    }

    // Item applicability check
    if (selectedItemIds != null &&
        selectedItemIds.isNotEmpty &&
        !validateItemApplicability(promoCode, selectedItemIds)) {
      errors.add(PromoCodeValidationError.notApplicableToItems);
    }

    // Category applicability check
    if (selectedCategoryIds != null &&
        selectedCategoryIds.isNotEmpty &&
        !validateCategoryApplicability(promoCode, selectedCategoryIds)) {
      errors.add(PromoCodeValidationError.notApplicableToCategories);
    }

    return errors;
  }

  // ─────────────────────────────────────────────────────────
  //  UTILITY METHODS
  // ─────────────────────────────────────────────────────────

  static PromoCodeValidationResult _createErrorResult(
    PromoCodeValidationError error, {
    String? additionalMessage,
  }) {
    final baseMessage = error.message;
    final fullMessage = additionalMessage != null
        ? '$baseMessage\n$additionalMessage'
        : baseMessage;
    log('[PromoCodeValidator] ❌ Validation failed: ${error.message}');
    return PromoCodeValidationResult(
      isValid: false,
      discountValue: 0,
      errorMessage: fullMessage,
    );
  }

  /// Format validation error for display
  static String formatValidationError(
    PromoCodeValidationError error, {
    bool includeEmoji = true,
  }) {
    final emoji = includeEmoji ? '${error.emoji} ' : '';
    return '$emoji${error.message}';
  }

  /// Get all validation error messages
  static String formatAllValidationErrors(
    List<PromoCodeValidationError> errors, {
    bool includeEmoji = true,
  }) {
    if (errors.isEmpty) return 'Unknown error';

    return errors
        .map((e) => formatValidationError(e, includeEmoji: includeEmoji))
        .join('\n');
  }
}

// ══════════════════════════════════════════════════════════════
//  DISCOUNT CALCULATION UTILITY
// ══════════════════════════════════════════════════════════════

class DiscountCalculator {
  /// Calculate discount amount
  static double calculateDiscount({
    required DiscountType discountType,
    required double discountValue,
    required double orderAmount,
  }) {
    if (discountType == DiscountType.percentage) {
      final discount = (orderAmount * discountValue) / 100;
      return _sanitizeAmount(discount);
    } else {
      // Fixed amount
      return _sanitizeAmount(
        discountValue > orderAmount ? orderAmount : discountValue,
      );
    }
  }

  /// Calculate final amount after discount
  static double calculateFinalAmount({
    required double orderAmount,
    required double discountAmount,
  }) {
    return _sanitizeAmount(orderAmount - discountAmount);
  }

  /// Validate discount amount
  static bool validateDiscountAmount(
    double discountAmount,
    double orderAmount,
  ) {
    return discountAmount >= 0 && discountAmount <= orderAmount;
  }

  /// Format discount for display
  static String formatDiscount({
    required DiscountType discountType,
    required double discountValue,
    bool showSymbol = true,
  }) {
    if (discountType == DiscountType.percentage) {
      final symbol = showSymbol ? '%' : '';
      return '$discountValue$symbol off';
    } else {
      final symbol = showSymbol ? '₹' : '';
      return '$symbol${discountValue.toStringAsFixed(2)} off';
    }
  }

  /// Calculate percentage discount from amounts
  static double calculatePercentageFromAmounts({
    required double originalAmount,
    required double discountAmount,
  }) {
    if (originalAmount == 0) return 0;
    return (discountAmount / originalAmount) * 100;
  }

  /// Sanitize amount (round to 2 decimals, prevent negative)
  static double _sanitizeAmount(double amount) {
    final rounded = double.parse(amount.toStringAsFixed(2));
    return rounded < 0 ? 0 : rounded;
  }
}
