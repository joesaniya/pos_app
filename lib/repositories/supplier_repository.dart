// lib/repositories/supplier_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SUPPLIER REPOSITORY — Offline-first
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';

class SupplierRepository {
  SupplierRepository._();
  static final instance = SupplierRepository._();

  final _local = LocalDatabase.instance;
  final _sb = Supabase.instance.client;
  final _uuid = const Uuid();
  final _connectivity = ConnectivityService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Supplier>> fetchAll(String businessId) async {
    final rows = await _local.getEntities(
      table: LocalDatabase.tSuppliers,
      businessId: businessId,
      whereExtra: 'action != ?',
      whereExtraArgs: [LocalDatabase.actionDelete],
    );
    return rows.map(_rowToSupplier).whereType<Supplier>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> refreshFromRemote(String businessId) async {
    try {
      final rows = await _sb
          .from('suppliers')
          .select(
            '*, supplier_contacts(*), supplier_payments(*), supplier_documents(*), supplier_deliveries(*)',
          )
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');
      final entities = (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();
      await _local.replaceAll(
        table: LocalDatabase.tSuppliers,
        businessId: businessId,
        entities: entities,
      );
      log('[SupplierRepo] Remote refresh: ${entities.length} suppliers cached');
    } catch (e) {
      debugPrint('[SupplierRepo] Remote refresh error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADD SUPPLIER
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addSupplier(Supplier s, String businessId) async {
    final data = s.toJson(businessId);

    await _local.upsertEntity(
      table: LocalDatabase.tSuppliers,
      id: s.id,
      businessId: businessId,
      data: data,
      syncStatus: LocalDatabase.syncPending,
      action: LocalDatabase.actionCreate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb.from('suppliers').insert(data);
        await _local.upsertEntity(
          table: LocalDatabase.tSuppliers,
          id: s.id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncSynced,
          action: LocalDatabase.actionCreate,
        );
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online addSupplier failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplier,
      entityId: s.id,
      action: LocalDatabase.actionCreate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE SUPPLIER
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> updateSupplier(Supplier s, String businessId) async {
    final data = s.toJson(businessId);

    await _local.upsertEntity(
      table: LocalDatabase.tSuppliers,
      id: s.id,
      businessId: businessId,
      data: data,
      syncStatus: _connectivity.isOnline
          ? LocalDatabase
                .syncSynced // Will update if API succeeds
          : LocalDatabase.syncPending, // Will be queued for sync
      action: LocalDatabase.actionUpdate,
    );

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('suppliers')
            .update(data)
            .eq('id', s.id)
            .eq('business_id', businessId);
        // Mark as synced after successful API call (already done above in setStatus)
        log('[SupplierRepo] ✅ Supplier updated online: ${s.id}');
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online updateSupplier failed: $e');
        // Mark as pending for retry
        await _local.upsertEntity(
          table: LocalDatabase.tSuppliers,
          id: s.id,
          businessId: businessId,
          data: data,
          syncStatus: LocalDatabase.syncPending,
          action: LocalDatabase.actionUpdate,
        );
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplier,
      entityId: s.id,
      action: LocalDatabase.actionUpdate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE SUPPLIER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteSupplier(String id, String businessId) async {
    // 1. Mark as deleted locally
    await _local.upsertEntity(
      table: LocalDatabase.tSuppliers,
      id: id,
      businessId: businessId,
      data: {'id': id, 'is_active': false},
      syncStatus: _connectivity.isOnline
          ? LocalDatabase
                .syncSynced // Will update if API succeeds
          : LocalDatabase.syncPending, // Will be queued for sync
      action: LocalDatabase.actionDelete,
    );

    // 2. Try API if online
    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('suppliers')
            .update({'is_active': false})
            .eq('id', id)
            .eq('business_id', businessId);
        log('[SupplierRepo] ✅ Supplier deleted online: $id');
        return; // Success, already marked as synced locally
      } catch (e) {
        debugPrint('[SupplierRepo] Online deleteSupplier failed: $e');
        // Mark as pending for retry
        await _local.upsertEntity(
          table: LocalDatabase.tSuppliers,
          id: id,
          businessId: businessId,
          data: {'id': id, 'is_active': false},
          syncStatus: LocalDatabase.syncPending,
          action: LocalDatabase.actionDelete,
        );
      }
    }

    // 3. Queue for sync
    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplier,
      entityId: id,
      action: LocalDatabase.actionDelete,
      payload: {'id': id, 'business_id': businessId},
      businessId: businessId,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  STATUS CHANGE (quick toggle without full update)
  // ════════════════════════════════════════════════════════════════════════════

  Future<bool> setSupplierStatus(
    String id,
    SupplierStatus status,
    String businessId,
  ) async {
    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('suppliers')
            .update({'status': status.name})
            .eq('id', id)
            .eq('business_id', businessId);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] setSupplierStatus error: $e');
        return false;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYMENTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addPayment(
    String supplierId,
    PaymentRecord payment,
    String businessId,
  ) async {
    final data = payment.toJson(supplierId, businessId);

    if (_connectivity.isOnline) {
      try {
        await _sb.from('supplier_payments').insert(data);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online addPayment failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplierPayment,
      entityId: payment.id,
      action: LocalDatabase.actionCreate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  Future<bool> markPaymentAsPaid({
    required String paymentId,
    required PaymentMode mode,
    required String transactionRef,
    required String businessId,
  }) async {
    final data = {
      'id': paymentId,
      'payment_status': PaymentStatus.paid.dbValue,
      'payment_mode': mode.dbValue,
      'transaction_ref': transactionRef.trim().isEmpty
          ? null
          : transactionRef.trim(),
      'business_id': businessId,
    };

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('supplier_payments')
            .update(data)
            .eq('id', paymentId)
            .eq('business_id', businessId);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online markPaymentAsPaid failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplierPayment,
      entityId: paymentId,
      action: LocalDatabase.actionUpdate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELIVERIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addDelivery(
    String supplierId,
    SupplierDelivery delivery,
    String businessId,
  ) async {
    final data = delivery.toJson(supplierId, businessId);

    if (_connectivity.isOnline) {
      try {
        await _sb.from('supplier_deliveries').insert(data);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online addDelivery failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplierDelivery,
      entityId: delivery.id,
      action: LocalDatabase.actionCreate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  Future<bool> updateDelivery(
    String supplierId,
    SupplierDelivery delivery,
    String businessId,
  ) async {
    final data = delivery.toJson(supplierId, businessId);

    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('supplier_deliveries')
            .update(data)
            .eq('id', delivery.id)
            .eq('business_id', businessId);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online updateDelivery failed: $e');
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplierDelivery,
      entityId: delivery.id,
      action: LocalDatabase.actionUpdate,
      payload: data,
      businessId: businessId,
    );
    return true;
  }

  Future<void> deleteDelivery(String deliveryId, String businessId) async {
    if (_connectivity.isOnline) {
      try {
        await _sb
            .from('supplier_deliveries')
            .delete()
            .eq('id', deliveryId)
            .eq('business_id', businessId);
        await refreshFromRemote(businessId);
        return;
      } catch (_) {}
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: EntityType.supplierDelivery,
      entityId: deliveryId,
      action: LocalDatabase.actionDelete,
      payload: {'id': deliveryId, 'business_id': businessId},
      businessId: businessId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCUMENTS (upload requires connectivity — queued for retry)
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  //  FILE UPLOAD
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> uploadDocumentFile({
    required String storagePath,
    required File file,
  }) async {
    if (!_connectivity.isOnline) return false;
    try {
      await _sb.storage.from('supplier-documents').upload(storagePath, file);
      return true;
    } catch (e) {
      debugPrint('[SupplierRepo] uploadDocumentFile error: $e');
      return false;
    }
  }

  Future<String?> getSignedViewUrl(
    String storagePath, {
    int expiresIn = 3600,
  }) async {
    if (!_connectivity.isOnline) return null;
    try {
      return await _sb.storage
          .from('supplier-documents')
          .createSignedUrl(storagePath, expiresIn);
    } catch (e) {
      debugPrint('[SupplierRepo] getSignedViewUrl error: $e');
      return null;
    }
  }

  Future<bool> addDocument(
    String supplierId,
    SupplierDocument doc,
    String businessId,
  ) async {
    final data = doc.toJson(supplierId, businessId);

    if (_connectivity.isOnline) {
      try {
        await _sb.from('supplier_documents').insert(data);
        await refreshFromRemote(businessId);
        return true;
      } catch (e) {
        debugPrint('[SupplierRepo] Online addDocument failed: $e');
        return false;
      }
    }
    // Documents with files require online — show appropriate message to caller
    return false;
  }

  Future<String?> getDocumentViewUrl(SupplierDocument doc) async {
    if (doc.fileRef == null || doc.fileRef!.isEmpty) return doc.fileUrl;
    try {
      return await _sb.storage
          .from('supplier-documents')
          .createSignedUrl(doc.fileRef!, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDocument(
    String supplierId,
    String docId,
    String? fileRef,
    String businessId,
  ) async {
    if (!_connectivity.isOnline) return; // Documents require online
    try {
      if (fileRef != null && fileRef.isNotEmpty) {
        await _sb.storage.from('supplier-documents').remove([fileRef]);
      }
      await _sb
          .from('supplier_documents')
          .delete()
          .eq('id', docId)
          .eq('business_id', businessId);
      await refreshFromRemote(businessId);
    } catch (e) {
      debugPrint('[SupplierRepo] deleteDocument error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════════════════════════

  void subscribeRealtime(String businessId, VoidCallback onRefresh) {
    _sb
        .channel('suppliers_rt_$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'suppliers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (_) => onRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'supplier_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (_) => onRefresh(),
        )
        .subscribe();
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  Supplier? _rowToSupplier(Map<String, dynamic> row) {
    try {
      return Supplier.fromJson(row);
    } catch (e) {
      debugPrint('[SupplierRepo] Parse error: $e');
      return null;
    }
  }
}
