// lib/services/other_supplier_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  OTHER SUPPLIER SERVICE
//
//  When a user types a custom supplier name (or picks "Other") while adding
//  an inventory item, this service:
//    1. Checks if a supplier with that name already exists in the business.
//    2. If yes  → returns its UUID so the item can be linked.
//    3. If no   → creates a new Supplier row under category "Other" and
//                 returns the new UUID.
//
//  The result is a real supplier_id (UUID) that can safely be stored in
//  inventory_items.supplier_id without hitting a Postgres UUID cast error.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtherSupplierService {
  OtherSupplierService._();
  static final instance = OtherSupplierService._();

  final _client = Supabase.instance.client;

  // Sentinel strings that mean "no real supplier was chosen".
  // These will never be turned into a supplier record.
  static const _noSupplierSentinels = {
    '',
    'unknown',
    'unknown supplier',
    'none',
    'null',
    'undefined',
    'na',
    'n/a',
  };

  /// Returns a valid supplier UUID for [supplierName] inside [businessId].
  ///
  /// - If [supplierName] is a sentinel / blank → returns `null`.
  /// - If a supplier with that name already exists → returns its id.
  /// - Otherwise → inserts a minimal supplier row and returns the new id.
  ///
  /// [existingId] is checked first: if it already looks like a UUID it is
  /// returned immediately (fast path — no DB round-trip needed).
  Future<String?> resolveOrCreate({
    required String businessId,
    required String supplierName,
    String? existingId,
  }) async {
    // ── 1. Fast path: already a valid UUID ──────────────────────────────────
    if (_isValidUuid(existingId)) return existingId;

    // ── 2. Sentinel / blank → no supplier ───────────────────────────────────
    final trimmed = supplierName.trim();
    if (trimmed.isEmpty ||
        _noSupplierSentinels.contains(trimmed.toLowerCase())) {
      return null;
    }

    try {
      // ── 3. Look for an existing supplier with the same name (case-insensitive)
      final existing = await _client
          .from('suppliers')
          .select('id')
          .eq('business_id', businessId)
          .ilike('name', trimmed)
          .eq('is_active', true)
          .maybeSingle();

      if (existing != null) {
        final id = existing['id'] as String;
        log('[OtherSupplierService] Found existing supplier "$trimmed" → $id');
        return id;
      }

      // ── 4. Create a new supplier row ────────────────────────────────────
      final inserted = await _client
          .from('suppliers')
          .insert({
            'business_id': businessId,
            'name': trimmed,
            'category': 'Other',
            'emoji': '🏭',
            'status': 'active',
            'credit_limit': 0,
            'credit_days': 14,
            'rating': 0,
            'onboarded_date': DateTime.now().toIso8601String().substring(0, 10),
            'is_active': true,
            'notes': 'Auto-created from inventory item entry.',
          })
          .select('id')
          .single();

      final newId = inserted['id'] as String;
      log('[OtherSupplierService] Created new supplier "$trimmed" → $newId');
      return newId;
    } catch (e) {
      log('[OtherSupplierService] resolveOrCreate error: $e');
      return null;
    }
  }

  /// Lightweight UUID format check (no external package needed).
  static bool _isValidUuid(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id.trim());
  }
}