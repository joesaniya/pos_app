import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/models/tax_slab_model.dart';

class TaxRepository {
  static final TaxRepository instance = TaxRepository._internal();
  TaxRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static const _collection = 'tax_slabs';

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new tax slab
  Future<TaxSlab?> createTaxSlab({
    required String businessId,
    required String name,
    required double percentage,
    required TaxType type,
    String? description,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
  }) async {
    try {
      if (businessId.isEmpty) {
        throw Exception('Business ID is required');
      }

      if (percentage < 0 || percentage > 100) {
        throw Exception('Tax percentage must be between 0 and 100');
      }

      final id = _uuid.v4();
      final now = DateTime.now();

      final taxSlab = TaxSlab(
        id: id,
        businessId: businessId,
        name: name,
        percentage: percentage,
        type: type,
        description: description,
        isActive: true,
        sortOrder: 0,
        createdByUid: createdByUid,
        createdByName: createdByName,
        createdByEmail: createdByEmail,
        createdByRole: createdByRole,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection(_collection).doc(id).set(taxSlab.toJson());

      log('✅ Tax slab created: $name ($percentage%)');
      return taxSlab;
    } catch (e, st) {
      log('❌ Error creating tax slab: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  READ
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all active tax slabs for a business
  Future<List<TaxSlab>> getTaxSlabsForBusiness(String businessId) async {
    try {
      if (businessId.isEmpty) return [];

      final snapshot = await _firestore
          .collection(_collection)
          .where('business_id', isEqualTo: businessId)
          .where('is_active', isEqualTo: true)
          .get();

      final slabs = snapshot.docs
          .map((doc) => TaxSlab.fromFirestore(doc))
          .toList();
      // Sort by sort_order, then by created_at in memory
      slabs.sort((a, b) {
        int sortComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortComparison != 0) return sortComparison;
        return b.createdAt.compareTo(a.createdAt); // descending
      });
      return slabs;
    } catch (e, st) {
      log('❌ Error fetching tax slabs: $e\n$st');
      return [];
    }
  }

  /// Fetch all tax slabs for a business (including inactive)
  Future<List<TaxSlab>> getAllTaxSlabsForBusiness(String businessId) async {
    try {
      if (businessId.isEmpty) return [];

      final snapshot = await _firestore
          .collection(_collection)
          .where('business_id', isEqualTo: businessId)
          .get();

      final slabs = snapshot.docs
          .map((doc) => TaxSlab.fromFirestore(doc))
          .toList();
      // Sort by sort_order, then by created_at in memory
      slabs.sort((a, b) {
        int sortComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortComparison != 0) return sortComparison;
        return b.createdAt.compareTo(a.createdAt); // descending
      });
      return slabs;
    } catch (e, st) {
      log('❌ Error fetching all tax slabs: $e\n$st');
      return [];
    }
  }

  /// Get specific tax slab by ID
  Future<TaxSlab?> getTaxSlabById(String taxSlabId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(taxSlabId).get();

      if (!doc.exists) return null;

      return TaxSlab.fromFirestore(doc);
    } catch (e, st) {
      log('❌ Error fetching tax slab by ID: $e\n$st');
      return null;
    }
  }

  /// Stream tax slabs for a business (real-time updates)
  Stream<List<TaxSlab>> watchTaxSlabsForBusiness(String businessId) {
    if (businessId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('business_id', isEqualTo: businessId)
        .where('is_active', isEqualTo: true)
        .orderBy('sort_order')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TaxSlab.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          log('❌ Stream error: $error');
          return [];
        });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Update tax slab
  Future<TaxSlab?> updateTaxSlab({
    required TaxSlab taxSlab,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
  }) async {
    try {
      final updated = taxSlab.copyWith(
        updatedByUid: updatedByUid,
        updatedByName: updatedByName,
        updatedByRole: updatedByRole,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collection)
          .doc(taxSlab.id)
          .update(updated.toJson());

      log('✅ Tax slab updated: ${taxSlab.name}');
      return updated;
    } catch (e, st) {
      log('❌ Error updating tax slab: $e\n$st');
      rethrow;
    }
  }

  /// Enable/Disable tax slab
  Future<void> toggleTaxSlabStatus({
    required String taxSlabId,
    required bool isActive,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
  }) async {
    try {
      await _firestore.collection(_collection).doc(taxSlabId).update({
        'is_active': isActive,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'updated_by_role': updatedByRole,
        'updated_at': DateTime.now().toIso8601String(),
      });

      log('✅ Tax slab status updated: $taxSlabId - isActive: $isActive');
    } catch (e, st) {
      log('❌ Error toggling tax slab status: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE
  // ══════════════════════════════════════════════════════════════════════════

  /// Delete tax slab (only owner/manager can delete)
  Future<void> deleteTaxSlab(String taxSlabId) async {
    try {
      // Check if tax slab is in use before deleting
      await _firestore.collection(_collection).doc(taxSlabId).delete();

      log('✅ Tax slab deleted: $taxSlabId');
    } catch (e, st) {
      log('❌ Error deleting tax slab: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BATCH OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Reorder tax slabs
  Future<void> reorderTaxSlabs(List<TaxSlab> taxSlabs) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < taxSlabs.length; i++) {
        final updatedTax = taxSlabs[i].copyWith(sortOrder: i);
        batch.update(_firestore.collection(_collection).doc(taxSlabs[i].id), {
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      log('✅ Tax slabs reordered');
    } catch (e, st) {
      log('❌ Error reordering tax slabs: $e\n$st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Create default tax slabs for new business
  Future<List<TaxSlab>> createDefaultTaxSlabs({
    required String businessId,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
  }) async {
    try {
      final defaultTaxes = [
        {
          'name': '5% GST',
          'percentage': 5.0,
          'type': TaxType.exclusive,
          'description': 'Standard tax rate 5%',
        },
        {
          'name': '12% GST',
          'percentage': 12.0,
          'type': TaxType.exclusive,
          'description': 'Standard tax rate 12%',
        },
        {
          'name': '18% GST',
          'percentage': 18.0,
          'type': TaxType.exclusive,
          'description': 'Standard tax rate 18%',
        },
        {
          'name': 'No Tax',
          'percentage': 0.0,
          'type': TaxType.none,
          'description': 'No tax applicable',
        },
      ];

      final createdTaxes = <TaxSlab>[];

      for (var tax in defaultTaxes) {
        final created = await createTaxSlab(
          businessId: businessId,
          name: tax['name'] as String,
          percentage: tax['percentage'] as double,
          type: tax['type'] as TaxType,
          description: tax['description'] as String?,
          createdByUid: createdByUid,
          createdByName: createdByName,
          createdByEmail: createdByEmail,
          createdByRole: createdByRole,
        );

        if (created != null) {
          createdTaxes.add(created);
        }
      }

      log('✅ Default tax slabs created: ${createdTaxes.length}');
      return createdTaxes;
    } catch (e, st) {
      log('❌ Error creating default tax slabs: $e\n$st');
      rethrow;
    }
  }
}
