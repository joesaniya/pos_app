// lib/providers/promo_code_provider.dart
// Complete provider layer for promo code management using Provider package

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/repositories/promo_code_repository.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE PROVIDER (ChangeNotifier)
// ══════════════════════════════════════════════════════════════

class PromoCodeProvider extends ChangeNotifier {
  final PromoCodeRepository _repo = PromoCodeRepository.instance;

  // ═══════════════════════════════════════════════════════════
  //  STATE VARIABLES
  // ═══════════════════════════════════════════════════════════

  List<PromoCode> _promoCodes = [];
  PromoCode? _selectedPromoCode;
  bool _isLoading = false;
  String? _error;

  // ═══════════════════════════════════════════════════════════
  //  GETTERS
  // ═══════════════════════════════════════════════════════════

  List<PromoCode> get promoCodes => _promoCodes;
  PromoCode? get selectedPromoCode => _selectedPromoCode;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get active promo codes only
  List<PromoCode> get activePromoCodes =>
      _promoCodes.where((p) => p.isActive && p.isValid).toList();

  /// Get expired promo codes
  List<PromoCode> get expiredPromoCodes =>
      _promoCodes.where((p) => !p.isValid).toList();

  /// Get all promo codes count
  int get totalCount => _promoCodes.length;

  /// Get active count
  int get activeCount => activePromoCodes.length;

  // ═══════════════════════════════════════════════════════════
  //  INITIALIZATION & LOADING
  // ═══════════════════════════════════════════════════════════

  /// Load all promo codes for a business
  Future<void> loadPromoCodesByBusiness(
    String businessId, {
    bool activeOnly = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _promoCodes = await _repo.listPromoCodesByBusiness(
        businessId,
        activeOnly: activeOnly,
      );

      log('[PromoCodeProvider] ✅ Loaded ${_promoCodes.length} promo codes');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load promo codes: $e';
      log('[PromoCodeProvider] ❌ Error loading promo codes: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load a single promo code
  Future<void> loadPromoCode(String promoCodeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _selectedPromoCode = await _repo.getPromoCode(promoCodeId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load promo code: $e';
      log('[PromoCodeProvider] ❌ Error loading promo code: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CREATE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode?> createPromoCode({
    required String businessId,
    required String code,
    required String discountType,
    required double discountValue,
    required double minOrderValue,
    required DateTime startDate,
    required DateTime expiryDate,
    required String createdBy,
    List<String>? applicableItems,
    List<String>? applicableCategories,
    String? customerId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final newPromoCode = await _repo.createPromoCode(
        businessId: businessId,
        code: code,
        discountType: discountType,
        discountValue: discountValue,
        minOrderValue: minOrderValue,
        startDate: startDate,
        expiryDate: expiryDate,
        createdBy: createdBy,
        applicableItems: applicableItems,
        applicableCategories: applicableCategories,
        customerId: customerId,
      );

      _promoCodes.add(newPromoCode);
      _isLoading = false;
      notifyListeners();

      return newPromoCode;
    } catch (e) {
      _error = 'Failed to create promo code: $e';
      log('[PromoCodeProvider] ❌ Error creating promo code: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  UPDATE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<bool> updatePromoCode(
    String promoCodeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updated = await _repo.updatePromoCode(promoCodeId, updates);

      if (updated != null) {
        final index = _promoCodes.indexWhere((p) => p.id == promoCodeId);
        if (index != -1) {
          _promoCodes[index] = updated;
        }
        if (_selectedPromoCode?.id == promoCodeId) {
          _selectedPromoCode = updated;
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update promo code: $e';
      log('[PromoCodeProvider] ❌ Error updating promo code: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  TOGGLE PROMO CODE STATUS
  // ═══════════════════════════════════════════════════════════

  Future<bool> togglePromoCodeStatus(String promoCodeId, bool isActive) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _repo.togglePromoCodeStatus(promoCodeId, isActive);

      if (success) {
        final index = _promoCodes.indexWhere((p) => p.id == promoCodeId);
        if (index != -1) {
          _promoCodes[index] = _promoCodes[index].copyWith(isActive: isActive);
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to toggle promo code status: $e';
      log('[PromoCodeProvider] ❌ Error toggling status: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DELETE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<bool> deletePromoCode(String promoCodeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _repo.deletePromoCode(promoCodeId);

      if (success) {
        _promoCodes.removeWhere((p) => p.id == promoCodeId);
        if (_selectedPromoCode?.id == promoCodeId) {
          _selectedPromoCode = null;
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to delete promo code: $e';
      log('[PromoCodeProvider] ❌ Error deleting promo code: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  VALIDATE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoCodeValidationResult> validatePromoCode({
    required String code,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
  }) async {
    try {
      final result = await _repo.validatePromoCode(
        code: code,
        businessId: businessId,
        customerId: customerId,
        orderAmount: orderAmount,
      );

      if (!result.isValid) {
        _error = result.errorMessage;
      }

      return result;
    } catch (e) {
      log('[PromoCodeProvider] ❌ Error validating promo code: $e');
      return PromoCodeValidationResult(
        isValid: false,
        discountValue: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CALCULATE DISCOUNT AMOUNT
  // ═══════════════════════════════════════════════════════════

  Future<double> calculateDiscountAmount({
    required String discountType,
    required double discountValue,
    required double orderAmount,
  }) async {
    try {
      return await _repo.calculateDiscountAmount(
        discountType: discountType,
        discountValue: discountValue,
        orderAmount: orderAmount,
      );
    } catch (e) {
      log('[PromoCodeProvider] ❌ Error calculating discount: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  RECORD PROMO CODE USAGE
  // ═══════════════════════════════════════════════════════════

  Future<bool> recordPromoCodeUsage({
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
      _error = 'Failed to record promo usage: $e';
      log('[PromoCodeProvider] ❌ Error recording usage: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SEARCH & FILTER OPERATIONS
  // ═══════════════════════════════════════════════════════════

  /// Filter promo codes by search term
  List<PromoCode> filterBySearchTerm(String searchTerm) {
    if (searchTerm.isEmpty) return _promoCodes;

    final term = searchTerm.toLowerCase();
    return _promoCodes.where((p) {
      return p.code.toLowerCase().contains(term) ||
          p.displayText.toLowerCase().contains(term);
    }).toList();
  }

  /// Filter promo codes by discount type
  List<PromoCode> filterByDiscountType(DiscountType discountType) {
    return _promoCodes.where((p) => p.discountType == discountType).toList();
  }

  /// Filter customer-specific promo codes
  List<PromoCode> getCustomerSpecificPromoCodes(String customerId) {
    return _promoCodes
        .where((p) => p.customerId == null || p.customerId == customerId)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  UTILITY METHODS
  // ═══════════════════════════════════════════════════════════

  /// Select a promo code
  void selectPromoCode(PromoCode? promo) {
    _selectedPromoCode = promo;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all state
  void reset() {
    _promoCodes.clear();
    _selectedPromoCode = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Check if promo code exists
  bool promoCodeExists(String code) {
    return _promoCodes.any((p) => p.code == code.toUpperCase());
  }

  /// Get promo code by code string
  PromoCode? getPromoCodeByCode(String code) {
    return _promoCodes.firstWhere(
      (p) => p.code == code.toUpperCase(),
      orElse: () => PromoCode(
        id: '',
        businessId: '',
        code: '',
        discountType: DiscountType.percentage,
        discountValue: 0,
        minOrderValue: 0,
        startDate: DateTime.now(),
        expiryDate: DateTime.now(),
        isActive: false,
        createdBy: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════

  /// Deactivate all expired promo codes
  Future<int> deactivateExpiredPromoCodes(String businessId) async {
    try {
      final count = await _repo.deactivateExpiredPromoCodes(businessId);

      // Reload promo codes
      await loadPromoCodesByBusiness(businessId);

      return count;
    } catch (e) {
      _error = 'Failed to deactivate expired codes: $e';
      log('[PromoCodeProvider] ❌ Error deactivating expired codes: $e');
      return 0;
    }
  }
}
