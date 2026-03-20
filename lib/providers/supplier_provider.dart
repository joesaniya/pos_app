// lib/providers/supplier_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SUPPLIER PROVIDER
//
//  Manages the full supplier list for a business. Includes realtime
//  subscription so auto-created suppliers (from OtherSupplierService) appear
//  instantly in the Suppliers screen without a manual refresh.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/services/storage_service.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
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

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await StorageService.instance.getUserData();
      _businessId = userData['businessId'] as String? ?? '';
      _userRole = userData['role'] as String? ?? '';

      debugPrint(
        '[SupplierProvider] Init — businessId=$_businessId role=$_userRole',
      );

      if (_businessId.isNotEmpty) {
        await _fetchAll();
        _subscribeRealtime();
      }
    } catch (e) {
      _errorMessage = 'Init failed: $e';
      debugPrint('[SupplierProvider] _init error: $e');
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  // ── Realtime subscription ──────────────────────────────────────────────────
  // This picks up INSERT events from OtherSupplierService so auto-created
  // suppliers appear in the list without needing a manual pull-to-refresh.
  void _subscribeRealtime() {
    Supabase.instance.client
        .channel('suppliers_realtime_$_businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'suppliers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: _businessId,
          ),
          callback: (_) => _fetchAll(),
        )
        .subscribe();
  }

  // ── Fetch all suppliers ────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    try {
      final rows = await Supabase.instance.client
          .from('suppliers')
          .select('''
            *,
            supplier_contacts (*),
            supplier_payments (*),
            supplier_documents (*)
          ''')
          .eq('business_id', _businessId)
          .eq('is_active', true)
          .order('name');

      _suppliers.clear();
      for (final row in (rows as List)) {
        try {
          _suppliers.add(_fromJson(row as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[SupplierProvider] Parse error for row $row: $e');
        }
      }
      debugPrint('[SupplierProvider] Fetched ${_suppliers.length} suppliers');
    } catch (e) {
      _errorMessage = 'Failed to load suppliers: $e';
      debugPrint('[SupplierProvider] _fetchAll error: $e');
    }
    notifyListeners();
  }

  // ── Filtered + sorted list (used by UI) ───────────────────────────────────
  List<Supplier> get filtered {
    var result = List<Supplier>.from(_suppliers);

    // Status filter
    if (_statusFilter != null) {
      result = result.where((s) => s.status == _statusFilter).toList();
    }

    // Category filter
    if (_categoryFilter != 'All') {
      result = result.where((s) => s.category == _categoryFilter).toList();
    }

    // Search
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

    // Sort
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

  // ── Filter setters ─────────────────────────────────────────────────────────
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

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addSupplier(Supplier s) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = _toJson(s);
      final inserted = await Supabase.instance.client
          .from('suppliers')
          .insert(data)
          .select()
          .single();
      _suppliers.add(s.copyWith());
      // Realtime will trigger a full re-fetch automatically.
    } catch (e) {
      _errorMessage = 'Failed to add supplier: $e';
      debugPrint('[SupplierProvider] addSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier s) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('suppliers')
          .update(_toJson(s))
          .eq('id', s.id)
          .eq('business_id', _businessId);
      final idx = _suppliers.indexWhere((x) => x.id == s.id);
      if (idx != -1) _suppliers[idx] = s;
    } catch (e) {
      _errorMessage = 'Failed to update supplier: $e';
      debugPrint('[SupplierProvider] updateSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('suppliers')
          .update({'is_active': false})
          .eq('id', id)
          .eq('business_id', _businessId);
      _suppliers.removeWhere((s) => s.id == id);
    } catch (e) {
      _errorMessage = 'Failed to delete supplier: $e';
      debugPrint('[SupplierProvider] deleteSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPayment(String supplierId, PaymentRecord payment) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('supplier_payments').insert({
        'supplier_id': supplierId,
        'business_id': _businessId,
        'amount': payment.amount,
        'paid_amount': payment.paidAmount,
        'payment_status': payment.status.dbValue,
        'payment_mode': payment.mode.dbValue,
        'description': payment.description,
        'invoice_ref': payment.invoiceRef,
        'payment_date': payment.date.toIso8601String(),
        'due_date': payment.dueDate?.toIso8601String(),
      });
      await _fetchAll();
    } catch (e) {
      _errorMessage = 'Failed to add payment: $e';
      debugPrint('[SupplierProvider] addPayment error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDocument(String supplierId, SupplierDocument doc) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('supplier_documents').insert({
        'supplier_id': supplierId,
        'business_id': _businessId,
        'type': doc.type.dbValue,
        'title': doc.title,
        'uploaded_on': doc.uploadedOn.toIso8601String(),
        'expiry_date': doc.expiryDate?.toIso8601String(),
        'file_ref': doc.fileRef,
      });
      await _fetchAll();
    } catch (e) {
      _errorMessage = 'Failed to add document: $e';
      debugPrint('[SupplierProvider] addDocument error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  String generateId() => 'sup_${DateTime.now().millisecondsSinceEpoch}';

  // ── JSON helpers ───────────────────────────────────────────────────────────

  Map<String, dynamic> _toJson(Supplier s) => {
    'business_id': _businessId,
    'name': s.name,
    'category': s.category,
    'emoji': s.emoji,
    'status': s.status.dbValue,
    'gst_number': s.gstNumber,
    'address': s.address,
    'city': s.city,
    'credit_limit': s.creditLimit,
    'credit_days': s.creditDays,
    'rating': s.rating,
    'notes': s.notes,
    'onboarded_date': s.onboardedDate.toIso8601String().substring(0, 10),
    'is_active': true,
  };

  Supplier _fromJson(Map<String, dynamic> j) {
    // ── Contacts ──────────────────────────────────────────────────────────
    final contacts = (j['supplier_contacts'] as List<dynamic>? ?? [])
        .map(
          (c) => SupplierContact(
            name: c['name'] as String? ?? '',
            role: c['role'] as String? ?? 'Contact',
            phone: c['phone'] as String? ?? '',
            email: c['email'] as String?,
          ),
        )
        .toList();

    // ── Payments ──────────────────────────────────────────────────────────
    final payments = (j['supplier_payments'] as List<dynamic>? ?? [])
        .map(
          (p) => PaymentRecord(
            id: p['id'] as String,
            amount: (p['amount'] as num).toDouble(),
            paidAmount: p['paid_amount'] != null
                ? (p['paid_amount'] as num).toDouble()
                : null,
            status: PaymentStatusExt.fromString(
              p['payment_status'] as String? ?? 'pending',
            ),
            mode: PaymentModeExt.fromString(
              p['payment_mode'] as String? ?? 'upi',
            ),
            date: DateTime.parse(
              p['payment_date'] as String? ?? DateTime.now().toIso8601String(),
            ),
            dueDate: p['due_date'] != null
                ? DateTime.parse(p['due_date'] as String)
                : null,
            description: p['description'] as String? ?? '',
            invoiceRef: p['invoice_ref'] as String?,
          ),
        )
        .toList();

    // ── Documents ─────────────────────────────────────────────────────────
    final documents = (j['supplier_documents'] as List<dynamic>? ?? [])
        .map(
          (d) => SupplierDocument(
            id: d['id'] as String,
            type: DocumentTypeExt.fromString(d['type'] as String? ?? 'other'),
            title: d['title'] as String? ?? '',
            uploadedOn: DateTime.parse(
              d['uploaded_on'] as String? ?? DateTime.now().toIso8601String(),
            ),
            expiryDate: d['expiry_date'] != null
                ? DateTime.parse(d['expiry_date'] as String)
                : null,
            fileRef: d['file_ref'] as String?,
          ),
        )
        .toList();

    return Supplier(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String? ?? 'Other',
      emoji: j['emoji'] as String? ?? '🏭',
      status: SupplierStatusExt.fromString(j['status'] as String? ?? 'active'),
      gstNumber: j['gst_number'] as String?,
      address: j['address'] as String?,
      city: j['city'] as String?,
      creditLimit: (j['credit_limit'] as num? ?? 0).toDouble(),
      creditDays: j['credit_days'] as int? ?? 14,
      rating: (j['rating'] as num? ?? 0).toDouble(),
      contacts: contacts,
      documents: documents,
      payments: payments,
      deliveries: const [], // deliveries loaded separately if needed
      onboardedDate: j['onboarded_date'] != null
          ? DateTime.parse(j['onboarded_date'] as String)
          : DateTime.now(),
      notes: j['notes'] as String?,
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/services/storage_service.dart';

enum SupplierSort { name, pending, rating, recentDelivery }

class SupplierProvider extends ChangeNotifier {
  String _search = '';
  String _categoryFilter = 'All';
  SupplierStatus? _statusFilter;
  SupplierSort _sort = SupplierSort.name;
  bool _isLoading = false;
  String _error = '';
  String _businessId = '';

  final List<Supplier> _suppliers = [];

  SupplierProvider() {
    _init();
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    final userData = await StorageService.instance.getUserData();
    _businessId = userData['businessId'] as String? ?? '';
    if (_businessId.isNotEmpty) {
      await fetchSuppliers();
    } else {
      _seed();
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  String get search => _search;
  String get categoryFilter => _categoryFilter;
  SupplierStatus? get statusFilter => _statusFilter;
  SupplierSort get sort => _sort;
  bool get isLoading => _isLoading;
  String get error => _error;

  List<String> get categories {
    final cats = _suppliers.map((s) => s.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  List<Supplier> get filtered {
    var list = List<Supplier>.from(_suppliers);
    if (_categoryFilter != 'All')
      list = list.where((s) => s.category == _categoryFilter).toList();
    if (_statusFilter != null)
      list = list.where((s) => s.status == _statusFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.category.toLowerCase().contains(q) ||
                (s.city?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    switch (_sort) {
      case SupplierSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SupplierSort.pending:
        list.sort((a, b) => b.totalPending.compareTo(a.totalPending));
        break;
      case SupplierSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SupplierSort.recentDelivery:
        list.sort((a, b) {
          final da = a.deliveries.isEmpty
              ? DateTime(2000)
              : a.deliveries.first.deliveredOn;
          final db = b.deliveries.isEmpty
              ? DateTime(2000)
              : b.deliveries.first.deliveredOn;
          return db.compareTo(da);
        });
        break;
    }
    return list;
  }

  double get totalPending =>
      _suppliers.fold(0, (s, sup) => s + sup.totalPending);
  double get totalOverdue =>
      _suppliers.fold(0, (s, sup) => s + sup.totalOverdue);
  int get activeCount =>
      _suppliers.where((s) => s.status == SupplierStatus.active).length;
  int get alertCount => _suppliers
      .where((s) => s.hasExpiredDocs || s.hasExpiringDocs || s.totalOverdue > 0)
      .length;

  void setSearch(String v) {
    _search = v;
    notifyListeners();
  }

  void setCategory(String v) {
    _categoryFilter = v;
    notifyListeners();
  }

  void setStatusFilter(SupplierStatus? v) {
    _statusFilter = v;
    notifyListeners();
  }

  void setSort(SupplierSort v) {
    _sort = v;
    notifyListeners();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> fetchSuppliers() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final rows = await Supabase.instance.client
          .from('suppliers')
          .select('''
            *,
            supplier_contacts (*),
            supplier_documents (*),
            supplier_payments (*),
            supplier_deliveries (*)
          ''')
          .eq('business_id', _businessId)
          .eq('is_active', true)
          .order('name');

      _suppliers.clear();
      for (final row in (rows as List)) {
        _suppliers.add(_fromJson(row as Map<String, dynamic>));
      }
    } catch (e) {
      _error = 'Failed to load suppliers: $e';
      debugPrint('[SupplierProvider] fetchSuppliers error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<void> addSupplier(Supplier s) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('suppliers').insert(_toJson(s));
      await fetchSuppliers();
    } catch (e) {
      debugPrint('[SupplierProvider] addSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<void> updateSupplier(Supplier updated) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('suppliers')
          .update(_toJson(updated))
          .eq('id', updated.id);
      final idx = _suppliers.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _suppliers[idx] = updated;
    } catch (e) {
      debugPrint('[SupplierProvider] updateSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> deleteSupplier(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('suppliers')
          .update({'is_active': false})
          .eq('id', id);
      _suppliers.removeWhere((s) => s.id == id);
    } catch (e) {
      debugPrint('[SupplierProvider] deleteSupplier error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Add Payment ───────────────────────────────────────────────────────────
  Future<void> addPayment(String supplierId, PaymentRecord payment) async {
    try {
      await Supabase.instance.client.from('supplier_payments').insert({
        'supplier_id': supplierId,
        'business_id': _businessId,
        'amount': payment.amount,
        'paid_amount': payment.paidAmount,
        'payment_status': payment.status.dbValue,
        'payment_mode': payment.mode.dbValue,
        'description': payment.description,
        'invoice_ref': payment.invoiceRef,
        'payment_date': payment.date.toIso8601String(),
        'due_date': payment.dueDate?.toIso8601String(),
      });
      final idx = _suppliers.indexWhere((s) => s.id == supplierId);
      if (idx != -1) {
        _suppliers[idx] = _suppliers[idx].copyWith(
          payments: [payment, ..._suppliers[idx].payments],
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SupplierProvider] addPayment error: $e');
    }
  }

  // ── Add Document ──────────────────────────────────────────────────────────
  Future<void> addDocument(String supplierId, SupplierDocument doc) async {
    try {
      await Supabase.instance.client.from('supplier_documents').insert({
        'supplier_id': supplierId,
        'business_id': _businessId,
        'document_type': doc.type.dbValue,
        'title': doc.title,
        'file_ref': doc.fileRef,
        'expiry_date': doc.expiryDate?.toIso8601String(),
        'uploaded_on': doc.uploadedOn.toIso8601String(),
        'uploaded_by': 'Manager',
      });
      final idx = _suppliers.indexWhere((s) => s.id == supplierId);
      if (idx != -1) {
        _suppliers[idx] = _suppliers[idx].copyWith(
          documents: [..._suppliers[idx].documents, doc],
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SupplierProvider] addDocument error: $e');
    }
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────
  Map<String, dynamic> _toJson(Supplier s) => {
    'business_id': _businessId,
    'name': s.name,
    'category': s.category,
    'emoji': s.emoji,
    'status': s.status.dbValue,
    'gst_number': s.gstNumber,
    'address': s.address,
    'city': s.city,
    'credit_limit': s.creditLimit,
    'credit_days': s.creditDays,
    'rating': s.rating,
    'notes': s.notes,
    'onboarded_date': s.onboardedDate.toIso8601String(),
  };

  Supplier _fromJson(Map<String, dynamic> j) {
    final contacts = (j['supplier_contacts'] as List<dynamic>? ?? [])
        .map(
          (c) => SupplierContact(
            name: c['name'] as String,
            role: c['role'] as String,
            phone: c['phone'] as String,
            email: c['email'] as String?,
          ),
        )
        .toList();

    final documents = (j['supplier_documents'] as List<dynamic>? ?? [])
        .map(
          (d) => SupplierDocument(
            id: d['id'] as String,
            type: DocumentTypeExt.fromString(d['document_type'] ?? 'other'),
            title: d['title'] as String,
            uploadedOn: DateTime.parse(d['uploaded_on'] as String),
            expiryDate: d['expiry_date'] != null
                ? DateTime.parse(d['expiry_date'] as String)
                : null,
            fileRef: d['file_ref'] as String?,
          ),
        )
        .toList();

    final payments = (j['supplier_payments'] as List<dynamic>? ?? [])
        .map(
          (p) => PaymentRecord(
            id: p['id'] as String,
            amount: (p['amount'] as num).toDouble(),
            paidAmount: (p['paid_amount'] as num?)?.toDouble(),
            status: PaymentStatusExt.fromString(
              p['payment_status'] ?? 'pending',
            ),
            mode: PaymentModeExt.fromString(p['payment_mode'] ?? 'upi'),
            date: DateTime.parse(p['payment_date'] as String),
            dueDate: p['due_date'] != null
                ? DateTime.parse(p['due_date'] as String)
                : null,
            description: p['description'] as String,
            invoiceRef: p['invoice_ref'] as String?,
          ),
        )
        .toList();

    final deliveries = (j['supplier_deliveries'] as List<dynamic>? ?? [])
        .map(
          (d) => SupplierDelivery(
            id: d['id'] as String,
            deliveredOn: DateTime.parse(d['delivered_on'] as String),
            items: (d['items'] as List<dynamic>? ?? []).cast<String>(),
            totalValue: (d['total_value'] as num).toDouble(),
            onTime: d['on_time'] as bool? ?? true,
            note: d['note'] as String?,
          ),
        )
        .toList();

    return Supplier(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String? ?? 'Other',
      emoji: j['emoji'] as String? ?? '🏭',
      status: SupplierStatusExt.fromString(j['status'] ?? 'active'),
      gstNumber: j['gst_number'] as String?,
      address: j['address'] as String?,
      city: j['city'] as String?,
      creditLimit: (j['credit_limit'] as num? ?? 0).toDouble(),
      creditDays: j['credit_days'] as int? ?? 14,
      rating: (j['rating'] as num? ?? 0).toDouble(),
      contacts: contacts,
      documents: documents,
      payments: payments,
      deliveries: deliveries,
      onboardedDate: j['onboarded_date'] != null
          ? DateTime.parse(j['onboarded_date'] as String)
          : DateTime.now(),
      notes: j['notes'] as String?,
    );
  }

  String generateId() => 'sup_${DateTime.now().millisecondsSinceEpoch}';

  // ── Demo seed (when no Supabase) ──────────────────────────────────────────
  void _seed() {
    _suppliers.addAll([
      Supplier(
        id: 'sup_001',
        name: 'Sri Annapoorna Traders',
        category: 'Grains & Pulses',
        emoji: '🌾',
        status: SupplierStatus.active,
        gstNumber: '33ABCDE1234F1Z5',
        address: '14, Koyambedu Market',
        city: 'Chennai',
        creditLimit: 50000,
        creditDays: 30,
        rating: 4.8,
        onboardedDate: DateTime(2021, 4, 10),
        notes: 'Primary grain supplier. Delivers every Monday & Thursday.',
        contacts: const [
          SupplierContact(
            name: 'Ramesh Kumar',
            role: 'Owner',
            phone: '+91 98400 11223',
            email: 'ramesh@annapoorna.com',
          ),
        ],
        documents: [
          SupplierDocument(
            id: 'd1',
            type: DocumentType.gst,
            title: 'GST Certificate 2024',
            uploadedOn: DateTime(2024, 1, 5),
            expiryDate: DateTime(2025, 3, 31),
          ),
          SupplierDocument(
            id: 'd2',
            type: DocumentType.contract,
            title: 'Annual Supply Agreement',
            uploadedOn: DateTime(2024, 3, 1),
            expiryDate: DateTime(2025, 12, 31),
          ),
        ],
        payments: [
          PaymentRecord(
            id: 'p1',
            amount: 18500,
            status: PaymentStatus.paid,
            mode: PaymentMode.upi,
            date: DateTime.now().subtract(const Duration(days: 8)),
            description: 'Rice Batter & Urad Dal',
            paidAmount: 18500,
          ),
          PaymentRecord(
            id: 'p2',
            amount: 22000,
            status: PaymentStatus.pending,
            mode: PaymentMode.bank,
            date: DateTime.now().subtract(const Duration(days: 3)),
            dueDate: DateTime.now().add(const Duration(days: 12)),
            description: 'Feb Grain Delivery',
            invoiceRef: 'INV-0142',
          ),
          PaymentRecord(
            id: 'p3',
            amount: 8000,
            status: PaymentStatus.overdue,
            mode: PaymentMode.upi,
            date: DateTime.now().subtract(const Duration(days: 45)),
            dueDate: DateTime.now().subtract(const Duration(days: 5)),
            description: 'Mustard Seeds & Fenugreek',
            invoiceRef: 'INV-0138',
          ),
        ],
        deliveries: [
          SupplierDelivery(
            id: 'del1',
            deliveredOn: DateTime.now().subtract(const Duration(days: 3)),
            items: const ['Rice Batter 45kg', 'Urad Dal 20kg'],
            totalValue: 22000,
            onTime: true,
          ),
          SupplierDelivery(
            id: 'del2',
            deliveredOn: DateTime.now().subtract(const Duration(days: 24)),
            items: const ['Rice 100kg'],
            totalValue: 12000,
            onTime: false,
            note: 'Delayed by 2 days',
          ),
        ],
      ),
      Supplier(
        id: 'sup_002',
        name: 'Aavin Dairy Co-op',
        category: 'Dairy',
        emoji: '🥛',
        status: SupplierStatus.active,
        city: 'Chennai',
        creditLimit: 30000,
        creditDays: 7,
        rating: 4.5,
        onboardedDate: DateTime(2020, 8, 15),
        contacts: const [
          SupplierContact(
            name: 'Muthu S',
            role: 'Area Manager',
            phone: '+91 94440 22334',
          ),
        ],
        documents: [
          SupplierDocument(
            id: 'd4',
            type: DocumentType.contract,
            title: 'Dairy Supply Contract',
            uploadedOn: DateTime(2024, 1, 1),
            expiryDate: DateTime(2025, 12, 31),
          ),
        ],
        payments: [
          PaymentRecord(
            id: 'p5',
            amount: 12000,
            status: PaymentStatus.paid,
            mode: PaymentMode.upi,
            date: DateTime.now().subtract(const Duration(days: 2)),
            description: 'Weekly Milk & Ghee',
            paidAmount: 12000,
          ),
          PaymentRecord(
            id: 'p6',
            amount: 9500,
            status: PaymentStatus.pending,
            mode: PaymentMode.upi,
            date: DateTime.now().subtract(const Duration(days: 1)),
            dueDate: DateTime.now().add(const Duration(days: 6)),
            description: 'Feb Week 2 – Milk 200L',
          ),
        ],
        deliveries: [
          SupplierDelivery(
            id: 'del4',
            deliveredOn: DateTime.now().subtract(const Duration(days: 1)),
            items: const ['Milk 100L', 'Ghee 5kg'],
            totalValue: 12000,
            onTime: true,
          ),
        ],
      ),
    ]);
    notifyListeners();
  }
}

*/
