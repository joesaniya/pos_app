import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_app/repositories/supplier_repository.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:pos_app/services/connectivity_service.dart';

enum SupplierSort { name, pending, rating, recentDelivery }

class SupplierProvider extends ChangeNotifier {
  // ── Internal state ─────────────────────────────────────────────────────────
  final List<Supplier> _suppliers = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String _errorMessage = '';

  String _businessId = '';
  String _userRole = '';

  // ── Filters / sort ─────────────────────────────────────────────────────────
  String _search = '';
  String _categoryFilter = 'All';
  SupplierStatus? _statusFilter;
  SupplierSort _sort = SupplierSort.name;

  // ── DB shortcut ────────────────────────────────────────────────────────────
  // Removed direct SupabaseClient getter

  // ── Public getters ─────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get errorMessage => _errorMessage;
  SupplierSort get sort => _sort;
  String get categoryFilter => _categoryFilter;
  SupplierStatus? get statusFilter => _statusFilter;

  SupplierProvider() {
    _init();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _init() async {
    _setLoading(true);
    try {
      final userData = await StorageService.instance.getUserData();
      _businessId = userData['businessId'] as String? ?? '';
      _userRole = userData['role'] as String? ?? '';

      debugPrint(
        '[SupplierProvider] Init — businessId=$_businessId role=$_userRole',
      );

      if (_businessId.isNotEmpty) {
        await fetchAll();
        _subscribeRealtime();
      }
    } catch (e) {
      _errorMessage = 'Init failed: $e';
      debugPrint('[SupplierProvider] _init error: $e');
    }
    _isInitialized = true;
    _setLoading(false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REALTIME
  // ══════════════════════════════════════════════════════════════════════════

  void _subscribeRealtime() {
    SupplierRepository.instance.subscribeRealtime(
      _businessId,
      () => fetchAll(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchAll() async {
    try {
      final suppliers = await SupplierRepository.instance.fetchAll(_businessId);
      _suppliers.clear();
      _suppliers.addAll(suppliers);
      debugPrint('[SupplierProvider] Fetched ${_suppliers.length} suppliers');
    } catch (e) {
      _errorMessage = 'Failed to load suppliers: $e';
      debugPrint('[SupplierProvider] fetchAll error: $e');
    }
    notifyListeners();

    // ── Double-fetch for offline-first ─────────────────────────────────────────
    if (ConnectivityService.instance.isOnline && _businessId.isNotEmpty) {
      try {
        await SupplierRepository.instance.refreshFromRemote(_businessId);
        final freshSuppliers = await SupplierRepository.instance.fetchAll(_businessId);
        _suppliers.clear();
        _suppliers.addAll(freshSuppliers);
        notifyListeners();
      } catch (e) {
        debugPrint('[SupplierProvider] Remote refresh error: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTERED LIST + METRICS
  // ══════════════════════════════════════════════════════════════════════════

  List<Supplier> get filtered {
    var result = List<Supplier>.from(_suppliers);

    if (_statusFilter != null) {
      result = result.where((s) => s.status == _statusFilter).toList();
    }
    if (_categoryFilter != 'All') {
      result = result.where((s) => s.category == _categoryFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                (s.city?.toLowerCase().contains(q) ?? false) ||
                s.category.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_sort) {
      case SupplierSort.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SupplierSort.pending:
        result.sort((a, b) => b.totalPending.compareTo(a.totalPending));
        break;
      case SupplierSort.rating:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SupplierSort.recentDelivery:
        result.sort((a, b) {
          if (a.deliveries.isEmpty && b.deliveries.isEmpty) return 0;
          if (a.deliveries.isEmpty) return 1;
          if (b.deliveries.isEmpty) return -1;
          return b.deliveries.first.deliveredOn.compareTo(
            a.deliveries.first.deliveredOn,
          );
        });
        break;
    }
    return result;
  }

  List<String> get categories {
    final cats = _suppliers.map((s) => s.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  int get activeCount =>
      _suppliers.where((s) => s.status == SupplierStatus.active).length;

  double get totalPending =>
      _suppliers.fold(0, (s, sup) => s + sup.totalPending);

  double get totalOverdue =>
      _suppliers.fold(0, (s, sup) => s + sup.totalOverdue);

  // ── Filter / sort setters ──────────────────────────────────────────────────
  void setSearch(String q) {
    _search = q;
    notifyListeners();
  }

  void setCategory(String c) {
    _categoryFilter = c;
    notifyListeners();
  }

  void setStatusFilter(SupplierStatus? s) {
    _statusFilter = s;
    notifyListeners();
  }

  void setSort(SupplierSort s) {
    _sort = s;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUPPLIER CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addSupplier(Supplier s) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.addSupplier(s, _businessId);
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('addSupplier', e);
      return false;
    }
  }

  Future<bool> updateSupplier(Supplier s) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.updateSupplier(s, _businessId);
      final idx = _suppliers.indexWhere((x) => x.id == s.id);
      if (idx != -1) _suppliers[idx] = s;
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('updateSupplier', e);
      return false;
    }
  }

  Future<void> deleteSupplier(String id) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.deleteSupplier(id, _businessId);
      _suppliers.removeWhere((s) => s.id == id);
    } catch (e) {
      _handleError('deleteSupplier', e);
    }
    _setLoading(false);
  }

  // ── Status toggle ──────────────────────────────────────────────────────────

  /// Quickly change active / inactive / blacklisted without the full edit sheet.
  Future<bool> setSupplierStatus(String id, SupplierStatus status) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.setSupplierStatus(
        id,
        status,
        _businessId,
      );
      final idx = _suppliers.indexWhere((s) => s.id == id);
      if (idx != -1) {
        _suppliers[idx] = _suppliers[idx].copyWith(status: status);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('setSupplierStatus', e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYMENT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Records a new payment against [supplierId].
  ///
  /// Mandatory:
  ///   • description — always required.
  ///   • transactionRef — required for all non-cash modes (UPI, bank, cheque, credit).
  ///
  /// Auto-status resolution:
  ///   paidAmount >= amount → PaymentStatus.paid
  ///   paidAmount > 0       → PaymentStatus.partial
  ///   otherwise            → status unchanged (pending / overdue as set by caller)
  Future<bool> addPayment(String supplierId, PaymentRecord payment) async {
    if (payment.description.trim().isEmpty) {
      _errorMessage = 'Payment description is required.';
      notifyListeners();
      return false;
    }
    if (payment.mode.requiresRef &&
        (payment.transactionRef == null ||
            payment.transactionRef!.trim().isEmpty)) {
      _errorMessage =
          'Transaction reference (UTR / cheque no.) is required '
          'for ${payment.mode.label} payments.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final resolved = _resolveStatus(payment);
      await SupplierRepository.instance.addPayment(
        supplierId,
        resolved,
        _businessId,
      );
      await fetchAll();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('addPayment', e);
      return false;
    }
  }

  /// Marks an existing pending / overdue / partial payment record as fully paid.
  ///
  /// [mode] and [transactionRef] are both required (unless mode is cash).
  Future<bool> markPaymentAsPaid({
    required String paymentId,
    required PaymentMode mode,
    required String transactionRef,
  }) async {
    if (mode.requiresRef && transactionRef.trim().isEmpty) {
      _errorMessage = 'Transaction reference is required to mark as paid.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await SupplierRepository.instance.markPaymentAsPaid(
        paymentId: paymentId,
        mode: mode,
        transactionRef: transactionRef,
        businessId: _businessId,
      );

      await fetchAll();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('markPaymentAsPaid', e);
      return false;
    }
  }

  PaymentRecord _resolveStatus(PaymentRecord p) {
    if (p.paidAmount != null && p.paidAmount! >= p.amount) {
      return PaymentRecord(
        id: p.id,
        amount: p.amount,
        paidAmount: p.amount,
        status: PaymentStatus.paid,
        mode: p.mode,
        date: p.date,
        dueDate: p.dueDate,
        description: p.description,
        invoiceRef: p.invoiceRef,
        transactionRef: p.transactionRef,
      );
    }
    if (p.paidAmount != null && p.paidAmount! > 0) {
      return PaymentRecord(
        id: p.id,
        amount: p.amount,
        paidAmount: p.paidAmount,
        status: PaymentStatus.partial,
        mode: p.mode,
        date: p.date,
        dueDate: p.dueDate,
        description: p.description,
        invoiceRef: p.invoiceRef,
        transactionRef: p.transactionRef,
      );
    }
    return p;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCUMENT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Uploads [file] to Supabase Storage, then inserts a metadata row.
  /// Returns the saved [SupplierDocument] with a signed view URL, or null.
  Future<SupplierDocument?> uploadDocument({
    required String supplierId,
    required SupplierDocument doc,
    required File file,
  }) async {
    _setLoading(true);
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final storagePath =
          '$_businessId/$supplierId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupplierRepository.instance.uploadDocumentFile(
        storagePath: storagePath,
        file: file,
      );

      final signedUrl = await SupplierRepository.instance.getSignedViewUrl(
        storagePath,
      );

      final docWithRef = SupplierDocument(
        id: doc.id,
        type: doc.type,
        title: doc.title,
        uploadedOn: doc.uploadedOn,
        expiryDate: doc.expiryDate,
        fileRef: storagePath,
        fileUrl: signedUrl ?? '',
      );

      await SupplierRepository.instance.addDocument(
        supplierId,
        docWithRef,
        _businessId,
      );

      await fetchAll();
      _setLoading(false);
      return SupplierDocument.fromJson({
        ...(docWithRef.toJson(supplierId, _businessId)),
        'file_url': signedUrl,
      });
    } catch (e) {
      _handleError('uploadDocument', e);
      return null;
    }
  }

  /// Adds a document metadata record without a physical file.
  Future<bool> addDocument(String supplierId, SupplierDocument doc) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.addDocument(
        supplierId,
        doc,
        _businessId,
      );
      await fetchAll();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('addDocument', e);
      return false;
    }
  }

  /// Returns a fresh short-lived (1-hour) signed URL for viewing [doc].
  /// Always call this on "View Document" tap to avoid expired-URL errors.
  Future<String?> getDocumentViewUrl(SupplierDocument doc) async {
    if (doc.fileRef == null || doc.fileRef!.isEmpty) return doc.fileUrl;
    try {
      return await SupplierRepository.instance.getSignedViewUrl(
        doc.fileRef!,
        expiresIn: 3600,
      );
    } catch (e) {
      debugPrint('[SupplierProvider] getDocumentViewUrl error: $e');
      return null;
    }
  }

  Future<void> deleteDocument(
    String supplierId,
    String docId,
    String? fileRef,
  ) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.deleteDocument(
        supplierId,
        docId,
        fileRef,
        _businessId,
      );
      await fetchAll();
    } catch (e) {
      _handleError('deleteDocument', e);
    }
    _setLoading(false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELIVERY MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> addDelivery(String supplierId, SupplierDelivery delivery) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.addDelivery(
        supplierId,
        delivery,
        _businessId,
      );
      await fetchAll();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('addDelivery', e);
      return false;
    }
  }

  Future<bool> updateDelivery(
    String supplierId,
    SupplierDelivery delivery,
  ) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.updateDelivery(
        supplierId,
        delivery,
        _businessId,
      );
      await fetchAll();
      _setLoading(false);
      return true;
    } catch (e) {
      _handleError('updateDelivery', e);
      return false;
    }
  }

  Future<void> deleteDelivery(String deliveryId) async {
    _setLoading(true);
    try {
      await SupplierRepository.instance.deleteDelivery(deliveryId, _businessId);
      await fetchAll();
    } catch (e) {
      _handleError('deleteDelivery', e);
    }
    _setLoading(false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String generateId() => 'sup_${DateTime.now().millisecondsSinceEpoch}';

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _handleError(String method, Object e) {
    _errorMessage = '$method failed: $e';
    debugPrint('[SupplierProvider] $method error: $e');
    _isLoading = false;
    notifyListeners();
  }
}
