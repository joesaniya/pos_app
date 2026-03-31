// lib/models/promo_code_model.dart
// Complete PromoCode model with validation and calculation logic

import 'dart:developer';

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  DISCOUNT TYPE ENUM
// ══════════════════════════════════════════════════════════════

enum DiscountType { percentage, fixed }

extension DiscountTypeExt on DiscountType {
  String get value {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixed:
        return 'fixed';
    }
  }

  String get label {
    switch (this) {
      case DiscountType.percentage:
        return 'Percentage (%)';
      case DiscountType.fixed:
        return 'Fixed (₹)';
    }
  }

  String get symbol {
    switch (this) {
      case DiscountType.percentage:
        return '%';
      case DiscountType.fixed:
        return '₹';
    }
  }

  static DiscountType fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'percentage':
        return DiscountType.percentage;
      case 'fixed':
        return DiscountType.fixed;
      default:
        return DiscountType.percentage;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE MODEL
// ══════════════════════════════════════════════════════════════

class PromoCode {
  final String id;
  final String businessId;
  final String code;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final DateTime startDate;
  final DateTime expiryDate;
  final List<String>? applicableItems; // Menu item IDs
  final List<String>? applicableCategories; // Category IDs
  final String? customerId; // If null, available for all customers
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoCode({
    required this.id,
    required this.businessId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.startDate,
    required this.expiryDate,
    this.applicableItems,
    this.applicableCategories,
    this.customerId,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // ═══════════════════════════════════════════════════════════
  //  STATUS & VALIDITY CHECKS
  // ═══════════════════════════════════════════════════════════

  /// Check if promo code is currently valid
  bool get isValid {
    // Use LOCAL time for comparison (dates are now stored in local timezone)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = startDate.millisecondsSinceEpoch;
    // Add 1 day to expiry so entire expiry day is considered valid
    final expiryDeadline = expiryDate.add(const Duration(days: 1));
    final expireMs = expiryDeadline.millisecondsSinceEpoch;

    final isWithinRange = nowMs >= startMs && nowMs <= expireMs;
    final result = isActive && isWithinRange;

    if (!result) {
      log(
        '[PromoCode] isValid=false for code=$code: isActive=$isActive, now=$nowMs, start=$startMs, expire=$expireMs, inRange=$isWithinRange',
      );
    }

    return result;
  }

  /// Get validity status message
  String get validityMessage {
    if (!isActive) return 'Promo code is inactive';

    // Use LOCAL time for comparison (dates are now in local timezone)
    final now = DateTime.now();
    if (now.isBefore(startDate)) {
      return 'Promo code starts ${_formatDate(startDate)}';
    }
    // Add 1 day to expiry so entire expiry day is valid
    final expiryDeadline = expiryDate.add(const Duration(days: 1));
    if (now.isAfter(expiryDeadline)) {
      return 'Promo code expired on ${_formatDate(expiryDate)}';
    }

    return 'Valid until ${_formatDate(expiryDate)}';
  }

  /// Check if promo applies to this item
  bool appliesToItem(String itemId) {
    // If no specific items defined, applies to all
    if (applicableItems == null || applicableItems!.isEmpty) {
      return true;
    }
    return applicableItems!.contains(itemId);
  }

  /// Check if promo applies to this category
  bool appliesToCategory(String categoryId) {
    // If no specific categories defined, applies to all
    if (applicableCategories == null || applicableCategories!.isEmpty) {
      return true;
    }
    return applicableCategories!.contains(categoryId);
  }

  /// Check if promo is customer-specific
  bool isCustomerSpecific(String customerId) {
    if (this.customerId == null) return false;
    return this.customerId == customerId;
  }

  /// Get list of eligible item IDs from provided items
  List<String> getEligibleItems(List<String> orderItemIds) {
    if (applicableItems == null || applicableItems!.isEmpty) {
      return orderItemIds; // Applies to all items
    }
    return orderItemIds.where((id) => applicableItems!.contains(id)).toList();
  }

  /// Get list of restricted item IDs from provided items
  List<String> getRestrictedItems(List<String> orderItemIds) {
    if (applicableItems == null || applicableItems!.isEmpty) {
      return []; // No restrictions
    }
    return orderItemIds.where((id) => !applicableItems!.contains(id)).toList();
  }

  /// Get list of eligible category IDs from provided categories
  List<String> getEligibleCategories(List<String> orderCategoryIds) {
    if (applicableCategories == null || applicableCategories!.isEmpty) {
      return orderCategoryIds; // Applies to all categories
    }
    return orderCategoryIds
        .where((id) => applicableCategories!.contains(id))
        .toList();
  }

  /// Get list of restricted category IDs from provided categories
  List<String> getRestrictedCategories(List<String> orderCategoryIds) {
    if (applicableCategories == null || applicableCategories!.isEmpty) {
      return []; // No restrictions
    }
    return orderCategoryIds
        .where((id) => !applicableCategories!.contains(id))
        .toList();
  }

  /// Check if ANY items are applicable to this promo
  bool hasApplicableItems(List<String> orderItemIds) {
    return getEligibleItems(orderItemIds).isNotEmpty;
  }

  /// Check if ALL items are applicable to this promo
  bool allItemsApplicable(List<String> orderItemIds) {
    if (applicableItems == null || applicableItems!.isEmpty) {
      return true; // Applies to all
    }
    return orderItemIds.every((id) => applicableItems!.contains(id));
  }

  /// Check if promo has item restrictions
  bool hasItemRestrictions() {
    return applicableItems != null && applicableItems!.isNotEmpty;
  }

  /// Check if promo has category restrictions
  bool hasCategoryRestrictions() {
    return applicableCategories != null && applicableCategories!.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════
  //  DISCOUNT CALCULATION
  // ═══════════════════════════════════════════════════════════

  /// Calculate discount amount based on order amount
  double calculateDiscount(double orderAmount) {
    if (discountType == DiscountType.percentage) {
      final discount = (orderAmount * discountValue) / 100;
      // Cap discount at order amount
      return discount > orderAmount ? orderAmount : discount;
    } else {
      // Fixed amount - cap at order amount
      return discountValue > orderAmount ? orderAmount : discountValue;
    }
  }

  /// Check if order meets minimum value requirement
  bool meetsMinimumOrderValue(double orderAmount) {
    return orderAmount >= minOrderValue;
  }

  /// Get formatted display text
  String get displayText {
    final symbol = discountType.symbol;
    if (discountType == DiscountType.percentage) {
      return '$discountValue$symbol off';
    } else {
      return '$symbol${discountValue.toStringAsFixed(2)} off';
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON SERIALIZATION
  // ═══════════════════════════════════════════════════════════

  factory PromoCode.fromMap(Map<String, dynamic> data) {
    return PromoCode(
      id: data['id'] ?? '',
      businessId: data['business_id'] ?? '',
      code: data['code'] ?? '',
      discountType: DiscountTypeExt.fromString(data['discount_type']),
      discountValue: (data['discount_value'] ?? 0).toDouble(),
      minOrderValue: (data['min_order_value'] ?? 0).toDouble(),
      startDate: _parseDateTime(data['start_date']),
      expiryDate: _parseDateTime(data['expiry_date']),
      applicableItems: _parseJsonArray(data['applicable_items']),
      applicableCategories: _parseJsonArray(data['applicable_categories']),
      customerId: data['customer_id'],

      isActive: data['is_active'] ?? true,
      createdBy: data['created_by'] ?? '',
      createdAt: _parseDateTime(data['created_at']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'code': code,
      'discount_type': discountType.value,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'start_date': startDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'applicable_items': applicableItems,
      'applicable_categories': applicableCategories,
      'customer_id': customerId,

      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  COPY WITH METHOD
  // ═══════════════════════════════════════════════════════════

  PromoCode copyWith({
    String? id,
    String? businessId,
    String? code,
    DiscountType? discountType,
    double? discountValue,
    double? minOrderValue,
    DateTime? startDate,
    DateTime? expiryDate,
    List<String>? applicableItems,
    List<String>? applicableCategories,
    String? customerId,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromoCode(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      applicableItems: applicableItems ?? this.applicableItems,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      customerId: customerId ?? this.customerId,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  UTILITY METHODS
  // ═══════════════════════════════════════════════════════════

  /// Parse DateTime from database - PRESERVE EXACT TIME WITHOUT TIMEZONE CONVERSION
  /// Dates stored in IST should remain as-is when retrieved
  static DateTime _parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();

    String dateString = dateStr.toString().trim();

    try {
      // Remove any timezone information and parse as local time
      // This preserves the exact time that was set in IST

      // Step 1: Replace space with T for ISO8601 format
      dateString = dateString.replaceFirst(' ', 'T');

      // Step 2: Remove all timezone information
      // - Remove +05:30
      // - Remove +00:00
      // - Remove Z
      dateString = dateString
          .replaceAll(
            RegExp(r'[+-]\d{2}:\d{2}$'),
            '',
          ) // Remove +HH:MM or -HH:MM
          .replaceAll(RegExp(r'Z$'), ''); // Remove Z

      // Step 3: Parse as local time (no timezone conversion)
      // This treats the time as-is in the device's local timezone (IST)
      DateTime parsed = DateTime.parse(dateString);

      return parsed;
    } catch (e) {
      log('[PromoCode] Error parsing date "$dateStr": $e');
      return DateTime.now();
    }
  }

  static List<String>? _parseJsonArray(dynamic json) {
    if (json == null) return null;
    if (json is List) {
      return json.cast<String>().toList();
    }
    if (json is String) {
      try {
        final decoded = json
            .replaceAll('"', '')
            .replaceAll('[', '')
            .replaceAll(']', '');
        if (decoded.isEmpty) return null;
        return decoded.split(',').map((s) => s.trim()).toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  static String _monthName(int month) {
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
    return months[month - 1];
  }

  @override
  String toString() =>
      'PromoCode(code: $code, type: ${discountType.value}, value: $discountValue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromoCode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE VALIDATION RESULT
// ══════════════════════════════════════════════════════════════

class PromoCodeValidationResult {
  final bool isValid;
  final String? promoCodeId;
  final String? discountType;
  final double discountValue;
  final String? errorMessage;

  PromoCodeValidationResult({
    required this.isValid,
    this.promoCodeId,
    this.discountType,
    required this.discountValue,
    this.errorMessage,
  });

  factory PromoCodeValidationResult.fromMap(Map<String, dynamic> data) {
    return PromoCodeValidationResult(
      isValid: data['is_valid'] ?? false,
      promoCodeId: data['promo_code_id'],
      discountType: data['discount_type'],
      discountValue: (data['discount_value'] ?? 0).toDouble(),
      errorMessage: data['error_message'],
    );
  }

  @override
  String toString() =>
      'PromoCodeValidationResult(isValid: $isValid, error: $errorMessage)';
}
