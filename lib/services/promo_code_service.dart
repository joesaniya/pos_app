// lib/services/promo_code_service.dart
// Service layer to handle promo code application and discount calculation

import 'dart:developer';

import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/providers/promo_code_provider.dart';
import 'package:pos_app/repositories/promo_code_repository.dart';
import 'package:pos_app/utils/promo_code_access_control.dart';
import 'package:pos_app/utils/promo_code_validator.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE APPLICATION RESULT
// ══════════════════════════════════════════════════════════════

class PromoApplicationResult {
  final bool success;
  final PromoCode? promoCode;
  final double discountAmount;
  final String? errorMessage;
  final String? warningMessage;

  PromoApplicationResult({
    required this.success,
    this.promoCode,
    this.discountAmount = 0,
    this.errorMessage,
    this.warningMessage,
  });

  @override
  String toString() =>
      'PromoApplicationResult(success: $success, discount: $discountAmount, error: $errorMessage)';
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE SERVICE
// ══════════════════════════════════════════════════════════════

class PromoCodeService {
  static final PromoCodeService _instance = PromoCodeService._internal();

  factory PromoCodeService() => _instance;

  PromoCodeService._internal();

  static PromoCodeService get instance => _instance;

  final PromoCodeRepository _repo = PromoCodeRepository.instance;

  // ═══════════════════════════════════════════════════════════
  //  MAIN METHOD: APPLY PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoApplicationResult> applyPromoCode({
    required String promoCodeString,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
    required List<String> selectedItemIds,
    List<String>? selectedCategoryIds,
  }) async {
    try {
      // ─ Step 1: Fetch promo code from database
      final promoCode = await _repo.getPromoCodeByCode(
        promoCodeString,
        businessId,
      );

      if (promoCode == null) {
        return PromoApplicationResult(
          success: false,
          errorMessage: '❌ Promo code not found',
        );
      }

      log('[PromoCodeService] ✅ Fetched promo code: ${promoCode.code}');

      // ─ Step 2: Validate promo code
      final validation = PromoCodeValidator.validatePromoCode(
        promoCode: promoCode,
        businessId: businessId,
        customerId: customerId,
        orderAmount: orderAmount,
        selectedItemIds: selectedItemIds,
        selectedCategoryIds: selectedCategoryIds,
      );

      if (!validation.isValid) {
        return PromoApplicationResult(
          success: false,
          errorMessage: validation.errorMessage,
        );
      }

      log('[PromoCodeService] ✅ Validation passed for: ${promoCode.code}');

      // ─ Step 3: Calculate discount amount
      final discountAmount = DiscountCalculator.calculateDiscount(
        discountType: promoCode.discountType,
        discountValue: promoCode.discountValue,
        orderAmount: orderAmount,
      );

      // ─ Step 4: Apply discount and return result
      return PromoApplicationResult(
        success: true,
        promoCode: promoCode,
        discountAmount: discountAmount,
      );
    } catch (e) {
      log('[PromoCodeService] ❌ Error applying promo code: $e');
      return PromoApplicationResult(
        success: false,
        errorMessage: 'Error processing promo code: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  APPLY MULTIPLE DISCOUNTS (Promo + Regular)
  // ═══════════════════════════════════════════════════════════

  /// Apply both promo code discount and regular discount
  /// Returns final discount amount (sum of both)
  Future<double> applyMultipleDiscounts({
    required String? promoCodeString,
    required double regularDiscountAmount,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
    List<String>? selectedItemIds,
    List<String>? selectedCategoryIds,
  }) async {
    double totalDiscount = regularDiscountAmount;

    // If promo code is provided, try to apply it
    if (promoCodeString != null && promoCodeString.isNotEmpty) {
      final result = await applyPromoCode(
        promoCodeString: promoCodeString,
        businessId: businessId,
        customerId: customerId,
        orderAmount: orderAmount,
        selectedItemIds: selectedItemIds ?? [],
        selectedCategoryIds: selectedCategoryIds,
      );

      if (result.success) {
        // Use the higher discount (either promo or regular)
        totalDiscount = result.discountAmount > regularDiscountAmount
            ? result.discountAmount
            : regularDiscountAmount;
      }
    }

    return totalDiscount;
  }

  // ═══════════════════════════════════════════════════════════
  //  RECORD PROMO USAGE AFTER ORDER COMPLETION
  // ═══════════════════════════════════════════════════════════

  Future<bool> recordPromoUsageAfterPayment({
    required String businessId,
    required String promoCodeId,
    required String orderId,
    String? customerId,
    double discountAmount = 0,
  }) async {
    try {
      return await _repo.recordPromoCodeUsage(
        businessId: businessId,
        promoCodeId: promoCodeId,
        orderId: orderId,
        customerId: customerId,
        discountAmount: discountAmount,
      );
    } catch (e) {
      log('[PromoCodeService] ❌ Error recording promo usage: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  VALIDATION ONLY (Without Discount Calculation)
  // ═══════════════════════════════════════════════════════════

  Future<bool> isPromoCodeValid({
    required String promoCodeString,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
    List<String>? selectedItemIds,
    List<String>? selectedCategoryIds,
  }) async {
    try {
      final result = await applyPromoCode(
        promoCodeString: promoCodeString,
        businessId: businessId,
        customerId: customerId,
        orderAmount: orderAmount,
        selectedItemIds: selectedItemIds ?? [],
        selectedCategoryIds: selectedCategoryIds,
      );

      return result.success;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  GET PROMO CODE INFO (For display)
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode?> getPromoCodeInfo(
    String promoCodeString,
    String businessId,
  ) async {
    try {
      return await _repo.getPromoCodeByCode(promoCodeString, businessId);
    } catch (e) {
      log('[PromoCodeService] ❌ Error fetching promo info: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CLEAN UP LOGIC (Optional - Call from scheduled job)
  // ═══════════════════════════════════════════════════════════

  /// Deactivate all expired promo codes for a business
  Future<int> cleanupExpiredPromoCodes(String businessId) async {
    try {
      return await _repo.deactivateExpiredPromoCodes(businessId);
    } catch (e) {
      log('[PromoCodeService] ❌ Error cleaning up expired codes: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ROLE-BASED ACCESS CONTROL (RBAC) - BACKEND VALIDATION
  // ═══════════════════════════════════════════════════════════

  /// Validate if user role is authorized to perform promo code management actions
  ///
  /// Called before any CRUD operation: Create, Read, Update, Delete
  /// Returns error string if unauthorized, null if authorized
  String? validateRoleForPromoManagement(String? userRole) {
    final error = PromoCodeAccessControl.validateAccessForBackendAction(
      userRole,
    );
    if (error != null) {
      log('[PromoCodeService] $error');
      PromoCodeAccessControl.logAccessAttempt(
        userRole,
        'promo_management_attempt',
        false,
      );
    }
    return error;
  }

  /// Authorize and log access attempt for promo code operations
  ///
  /// Returns true if authorized, false otherwise
  bool authorizePromoCodeOperation(String? userRole, String operationName) {
    final authorized = PromoCodeAccessControl.canManagePromoCodes(userRole);
    PromoCodeAccessControl.logAccessAttempt(
      userRole,
      operationName,
      authorized,
    );
    if (!authorized) {
      log(
        '[PromoCodeService] ❌ UNAUTHORIZED: '
        'User role "$userRole" attempted "$operationName"',
      );
    }
    return authorized;
  }

  /// Validate promo code view access
  bool canViewPromoCodes(String? userRole) {
    return PromoCodeAccessControl.canViewAllPromoCodes(userRole);
  }

  /// Validate promo code creation access
  bool canCreatePromoCode(String? userRole) {
    return PromoCodeAccessControl.canCreatePromoCode(userRole);
  }

  /// Validate promo code edit access
  bool canEditPromoCode(String? userRole) {
    return PromoCodeAccessControl.canEditPromoCode(userRole);
  }

  /// Validate promo code delete access
  bool canDeletePromoCode(String? userRole) {
    return PromoCodeAccessControl.canDeletePromoCode(userRole);
  }

  /// Validate promo code deactivation access
  bool canDeactivatePromoCode(String? userRole) {
    return PromoCodeAccessControl.canDeactivatePromoCode(userRole);
  }

  /// Validate analytics view access
  bool canViewPromoAnalytics(String? userRole) {
    return PromoCodeAccessControl.canViewPromoAnalytics(userRole);
  }
}
