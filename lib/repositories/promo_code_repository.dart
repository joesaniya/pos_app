// lib/repositories/promo_code_repository.dart
// Complete repository layer for promo code management

import 'dart:developer';

import 'package:pos_app/models/promo_code_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE REPOSITORY (Singleton)
// ══════════════════════════════════════════════════════════════

class PromoCodeRepository {
  static final PromoCodeRepository _instance = PromoCodeRepository._internal();

  factory PromoCodeRepository() {
    return _instance;
  }

  PromoCodeRepository._internal();

  static PromoCodeRepository get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  //  CREATE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode> createPromoCode({
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
      final data = {
        'business_id': businessId,
        'code': code.toUpperCase().trim(),
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_order_value': minOrderValue,
        'start_date': startDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
        'applicable_items': applicableItems,
        'applicable_categories': applicableCategories,
        'customer_id': customerId,
        'created_by': createdBy,
        'is_active': true,
      };

      final response = await _supabase
          .from('promo_codes')
          .insert(data)
          .select()
          .single();

      log('[PromoCodeRepo] ✅ Created promo code: $code');
      return PromoCode.fromMap(response);
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error creating promo code: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  GET SINGLE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode?> getPromoCode(String promoCodeId) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('id', promoCodeId)
          .maybeSingle();

      if (response == null) return null;
      return PromoCode.fromMap(response);
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error fetching promo code: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  GET PROMO CODE BY CODE STRING
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode?> getPromoCodeByCode(String code, String businessId) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('business_id', businessId)
          .eq('code', code.toUpperCase().trim())
          .maybeSingle();

      if (response == null) return null;
      return PromoCode.fromMap(response);
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error fetching promo code by code: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  LIST ALL PROMO CODES FOR BUSINESS
  // ═══════════════════════════════════════════════════════════

  Future<List<PromoCode>> listPromoCodesByBusiness(
    String businessId, {
    bool activeOnly = false,
  }) async {
    try {
      late final dynamic response;

      if (activeOnly) {
        response = await _supabase
            .from('promo_codes')
            .select()
            .eq('business_id', businessId)
            .eq('is_active', true)
            .order('created_at', ascending: false);
      } else {
        response = await _supabase
            .from('promo_codes')
            .select()
            .eq('business_id', businessId)
            .order('created_at', ascending: false);
      }

      return (response as List)
          .map((item) => PromoCode.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error listing promo codes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  UPDATE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<PromoCode?> updatePromoCode(
    String promoCodeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('promo_codes')
          .update(updates)
          .eq('id', promoCodeId)
          .select()
          .single();

      log('[PromoCodeRepo] ✅ Updated promo code: $promoCodeId');
      return PromoCode.fromMap(response);
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error updating promo code: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  TOGGLE PROMO CODE STATUS
  // ═══════════════════════════════════════════════════════════

  Future<bool> togglePromoCodeStatus(String promoCodeId, bool isActive) async {
    try {
      await _supabase
          .from('promo_codes')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', promoCodeId);

      log(
        '[PromoCodeRepo] ✅ Toggled promo code status: $promoCodeId -> $isActive',
      );
      return true;
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error toggling promo code status: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DELETE PROMO CODE
  // ═══════════════════════════════════════════════════════════

  Future<bool> deletePromoCode(String promoCodeId) async {
    try {
      await _supabase.from('promo_codes').delete().eq('id', promoCodeId);

      log('[PromoCodeRepo] ✅ Deleted promo code: $promoCodeId');
      return true;
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error deleting promo code: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  VALIDATE PROMO CODE (Call DB Function)
  // ═══════════════════════════════════════════════════════════

  Future<PromoCodeValidationResult> validatePromoCode({
    required String code,
    required String businessId,
    String? customerId,
    double orderAmount = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_validate_promo_code',
        params: {
          'p_code': code.toUpperCase().trim(),
          'p_business_id': businessId,
          'p_customer_id': customerId,
          'p_order_amount': orderAmount,
        },
      );

      if (response == null || response.isEmpty) {
        return PromoCodeValidationResult(
          isValid: false,
          discountValue: 0,
          errorMessage: 'Invalid response from server',
        );
      }

      log('[PromoCodeRepo] ✅ Promo code validation result: ${response[0]}');
      return PromoCodeValidationResult.fromMap(response[0]);
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error validating promo code: $e');
      return PromoCodeValidationResult(
        isValid: false,
        discountValue: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CALCULATE DISCOUNT AMOUNT (Call DB Function)
  // ═══════════════════════════════════════════════════════════

  Future<double> calculateDiscountAmount({
    required String discountType,
    required double discountValue,
    required double orderAmount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_calculate_discount_amount',
        params: {
          'p_discount_type': discountType,
          'p_discount_value': discountValue,
          'p_order_amount': orderAmount,
        },
      );

      final discountAmount = (response ?? 0).toDouble();
      log('[PromoCodeRepo] ✅ Calculated discount: $discountAmount');
      return discountAmount;
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error calculating discount: $e');
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
      await _supabase.from('promo_code_usage').insert({
        'business_id': businessId,
        'promo_code_id': promoCodeId,
        'order_id': orderId,
        'customer_id': customerId,
        'discount_amount': discountAmount,
      });

      log(
        '[PromoCodeRepo] ✅ Recorded promo code usage: $promoCodeId -> $orderId',
      );
      return true;
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error recording promo usage: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  GET PROMO CODE USAGE HISTORY
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPromoCodeUsageHistory(
    String promoCodeId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('promo_code_usage')
          .select()
          .eq('promo_code_id', promoCodeId)
          .order('used_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error fetching usage history: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SEARCH PROMO CODES
  // ═══════════════════════════════════════════════════════════

  Future<List<PromoCode>> searchPromoCodesByCode(
    String businessId,
    String searchTerm,
  ) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('business_id', businessId)
          .textSearch('code', searchTerm.toUpperCase())
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PromoCode.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error searching promo codes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════

  Future<int> deactivateExpiredPromoCodes(String businessId) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .lt('expiry_date', DateTime.now().toIso8601String())
          .eq('business_id', businessId)
          .eq('is_active', true);

      log(
        '[PromoCodeRepo] ✅ Deactivated expired promo codes for business: $businessId',
      );
      return response;
    } catch (e) {
      log('[PromoCodeRepo] ❌ Error deactivating expired codes: $e');
      return 0;
    }
  }
}
