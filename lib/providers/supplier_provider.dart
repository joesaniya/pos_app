import 'package:flutter/material.dart';
import 'package:pos_app/models/supplier_modal.dart';


enum SupplierSort { name, pending, rating, recentDelivery }

class SupplierProvider extends ChangeNotifier {
  String _search = '';
  String _categoryFilter = 'All';
  SupplierStatus? _statusFilter;
  SupplierSort _sort = SupplierSort.name;
  bool _isLoading = false;

  final List<Supplier> _suppliers = [];
  SupplierProvider() { _seed(); }

  // ── Getters ──────────────────────────────────────────────
  String get search => _search;
  String get categoryFilter => _categoryFilter;
  SupplierStatus? get statusFilter => _statusFilter;
  SupplierSort get sort => _sort;
  bool get isLoading => _isLoading;

  List<String> get categories {
    final cats = _suppliers.map((s) => s.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  List<Supplier> get filtered {
    var list = List<Supplier>.from(_suppliers);
    if (_categoryFilter != 'All') list = list.where((s) => s.category == _categoryFilter).toList();
    if (_statusFilter != null) list = list.where((s) => s.status == _statusFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q) ||
        (s.city?.toLowerCase().contains(q) ?? false)).toList();
    }
    switch (_sort) {
      case SupplierSort.name:           list.sort((a, b) => a.name.compareTo(b.name)); break;
      case SupplierSort.pending:        list.sort((a, b) => b.totalPending.compareTo(a.totalPending)); break;
      case SupplierSort.rating:         list.sort((a, b) => b.rating.compareTo(a.rating)); break;
      case SupplierSort.recentDelivery: list.sort((a, b) {
        final da = a.deliveries.isEmpty ? DateTime(2000) : a.deliveries.first.deliveredOn;
        final db = b.deliveries.isEmpty ? DateTime(2000) : b.deliveries.first.deliveredOn;
        return db.compareTo(da);
      }); break;
    }
    return list;
  }

  double get totalPending => _suppliers.fold(0, (s, sup) => s + sup.totalPending);
  double get totalOverdue => _suppliers.fold(0, (s, sup) => s + sup.totalOverdue);
  int get activeCount => _suppliers.where((s) => s.status == SupplierStatus.active).length;
  int get alertCount => _suppliers.where((s) => s.hasExpiredDocs || s.hasExpiringDocs || s.totalOverdue > 0).length;

  // ── Setters ──────────────────────────────────────────────
  void setSearch(String v) { _search = v; notifyListeners(); }
  void setCategory(String v) { _categoryFilter = v; notifyListeners(); }
  void setStatusFilter(SupplierStatus? v) { _statusFilter = v; notifyListeners(); }
  void setSort(SupplierSort v) { _sort = v; notifyListeners(); }

  // ── CRUD ─────────────────────────────────────────────────
  Future<void> addSupplier(Supplier s) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _suppliers.add(s);
    _isLoading = false; notifyListeners();
  }

  Future<void> updateSupplier(Supplier updated) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 350));
    final idx = _suppliers.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _suppliers[idx] = updated;
    _isLoading = false; notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _suppliers.removeWhere((s) => s.id == id);
    _isLoading = false; notifyListeners();
  }

  Future<void> addPayment(String supplierId, PaymentRecord payment) async {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx == -1) return;
    _suppliers[idx] = _suppliers[idx].copyWith(
      payments: [payment, ..._suppliers[idx].payments],
    );
    notifyListeners();
  }

  Future<void> addDocument(String supplierId, SupplierDocument doc) async {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx == -1) return;
    _suppliers[idx] = _suppliers[idx].copyWith(
      documents: [..._suppliers[idx].documents, doc],
    );
    notifyListeners();
  }

  String generateId() => 'sup_${DateTime.now().millisecondsSinceEpoch}';

  // ── Seed ─────────────────────────────────────────────────
  void _seed() {
    _suppliers.addAll([
      Supplier(
        id: 'sup_001', name: 'Sri Annapoorna Traders', category: 'Grains & Pulses',
        emoji: '🌾', status: SupplierStatus.active,
        gstNumber: '33ABCDE1234F1Z5', address: '14, Koyambedu Market', city: 'Chennai',
        creditLimit: 50000, creditDays: 30, rating: 4.8,
        onboardedDate: DateTime(2021, 4, 10),
        notes: 'Primary grain supplier. Delivers every Monday & Thursday.',
        contacts: [
          const SupplierContact(name: 'Ramesh Kumar', role: 'Owner', phone: '+91 98400 11223', email: 'ramesh@annapoorna.com'),
          const SupplierContact(name: 'Sujith R', role: 'Delivery Manager', phone: '+91 98400 44556'),
        ],
        documents: [
          SupplierDocument(id: 'd1', type: DocumentType.gst, title: 'GST Certificate 2024', uploadedOn: DateTime(2024, 1, 5), expiryDate: DateTime(2025, 3, 31)),
          SupplierDocument(id: 'd2', type: DocumentType.contract, title: 'Annual Supply Agreement', uploadedOn: DateTime(2024, 3, 1), expiryDate: DateTime(2025, 2, 28)),
          SupplierDocument(id: 'd3', type: DocumentType.invoice, title: 'INV-2025-0142', uploadedOn: DateTime.now().subtract(const Duration(days: 5))),
        ],
        payments: [
          PaymentRecord(id: 'p1', amount: 18500, status: PaymentStatus.paid, mode: PaymentMode.upi, date: DateTime.now().subtract(const Duration(days: 8)), description: 'Rice Batter & Urad Dal – Jan Batch', invoiceRef: 'INV-0141', paidAmount: 18500),
          PaymentRecord(id: 'p2', amount: 22000, status: PaymentStatus.pending, mode: PaymentMode.bank, date: DateTime.now().subtract(const Duration(days: 3)), dueDate: DateTime.now().add(const Duration(days: 12)), description: 'Feb Grain Delivery – Toor Dal + Rice', invoiceRef: 'INV-0142'),
          PaymentRecord(id: 'p3', amount: 15000, status: PaymentStatus.paid, mode: PaymentMode.cheque, date: DateTime.now().subtract(const Duration(days: 38)), description: 'Dec Batch Pulses', paidAmount: 15000),
          PaymentRecord(id: 'p4', amount: 8000, status: PaymentStatus.overdue, mode: PaymentMode.upi, date: DateTime.now().subtract(const Duration(days: 45)), dueDate: DateTime.now().subtract(const Duration(days: 5)), description: 'Mustard Seeds & Fenugreek', invoiceRef: 'INV-0138'),
        ],
        deliveries: [
          SupplierDelivery(id: 'del1', deliveredOn: DateTime.now().subtract(const Duration(days: 3)), items: ['Rice Batter 45kg', 'Urad Dal 20kg'], totalValue: 22000, onTime: true),
          SupplierDelivery(id: 'del2', deliveredOn: DateTime.now().subtract(const Duration(days: 10)), items: ['Toor Dal 35kg', 'Mustard Seeds 5kg'], totalValue: 18500, onTime: true),
          SupplierDelivery(id: 'del3', deliveredOn: DateTime.now().subtract(const Duration(days: 24)), items: ['Rice 100kg'], totalValue: 12000, onTime: false, note: 'Delayed by 2 days – transport issue'),
        ],
      ),
      Supplier(
        id: 'sup_002', name: 'Aavin Dairy Co-op', category: 'Dairy',
        emoji: '🥛', status: SupplierStatus.active,
        gstNumber: '33FGHIJ5678K2Z8', address: 'Aavin Complex, Anna Salai', city: 'Chennai',
        creditLimit: 30000, creditDays: 7, rating: 4.5,
        onboardedDate: DateTime(2020, 8, 15),
        contacts: [
          const SupplierContact(name: 'Muthu S', role: 'Area Manager', phone: '+91 94440 22334', email: 'muthu@aavin.org'),
        ],
        documents: [
          SupplierDocument(id: 'd4', type: DocumentType.contract, title: 'Dairy Supply Contract', uploadedOn: DateTime(2024, 1, 1), expiryDate: DateTime(2025, 12, 31)),
          SupplierDocument(id: 'd5', type: DocumentType.license, title: 'FSSAI License', uploadedOn: DateTime(2023, 6, 1), expiryDate: DateTime(2025, 5, 31)),
        ],
        payments: [
          PaymentRecord(id: 'p5', amount: 12000, status: PaymentStatus.paid, mode: PaymentMode.upi, date: DateTime.now().subtract(const Duration(days: 2)), description: 'Weekly Milk & Ghee', paidAmount: 12000),
          PaymentRecord(id: 'p6', amount: 9500, status: PaymentStatus.pending, mode: PaymentMode.upi, date: DateTime.now().subtract(const Duration(days: 1)), dueDate: DateTime.now().add(const Duration(days: 6)), description: 'Feb Week 2 – Milk 200L + Butter 10kg'),
        ],
        deliveries: [
          SupplierDelivery(id: 'del4', deliveredOn: DateTime.now().subtract(const Duration(days: 1)), items: ['Milk 100L', 'Ghee 5kg', 'Butter 5kg'], totalValue: 12000, onTime: true),
          SupplierDelivery(id: 'del5', deliveredOn: DateTime.now().subtract(const Duration(days: 8)), items: ['Milk 120L', 'Curd 20kg'], totalValue: 9000, onTime: true),
        ],
      ),
      Supplier(
        id: 'sup_003', name: 'Santhosh Fresh Vegetables', category: 'Vegetables',
        emoji: '🥬', status: SupplierStatus.active,
        address: 'Koyambedu Wholesale Market', city: 'Chennai',
        creditLimit: 15000, creditDays: 3, rating: 4.1,
        onboardedDate: DateTime(2022, 11, 20),
        contacts: [
          const SupplierContact(name: 'Santhosh P', role: 'Owner', phone: '+91 93800 55667'),
          const SupplierContact(name: 'Kannan M', role: 'Driver', phone: '+91 93800 77889'),
        ],
        documents: [
          SupplierDocument(id: 'd6', type: DocumentType.delivery, title: 'Delivery Note Feb 2025', uploadedOn: DateTime.now().subtract(const Duration(days: 1))),
        ],
        payments: [
          PaymentRecord(id: 'p7', amount: 4200, status: PaymentStatus.paid, mode: PaymentMode.cash, date: DateTime.now().subtract(const Duration(days: 1)), description: 'Daily veggies – Tomato, Onion, Capsicum', paidAmount: 4200),
          PaymentRecord(id: 'p8', amount: 3800, status: PaymentStatus.pending, mode: PaymentMode.cash, date: DateTime.now(), dueDate: DateTime.now().add(const Duration(days: 3)), description: 'Today\'s produce delivery'),
          PaymentRecord(id: 'p9', amount: 5100, status: PaymentStatus.overdue, mode: PaymentMode.cash, date: DateTime.now().subtract(const Duration(days: 7)), dueDate: DateTime.now().subtract(const Duration(days: 4)), description: 'Last week batch – Green chilli, Curry leaves'),
        ],
        deliveries: [
          SupplierDelivery(id: 'del6', deliveredOn: DateTime.now(), items: ['Tomatoes 20kg', 'Onions 25kg', 'Green Chilli 3kg'], totalValue: 3800, onTime: true),
          SupplierDelivery(id: 'del7', deliveredOn: DateTime.now().subtract(const Duration(days: 7)), items: ['Mixed Veggies 40kg'], totalValue: 5100, onTime: false, note: 'Late by 3 hours'),
        ],
      ),
      Supplier(
        id: 'sup_004', name: 'Gold Drop Oils & Fats', category: 'Oils',
        emoji: '🫙', status: SupplierStatus.active,
        gstNumber: '33KLMNO9012P3Z1', address: 'Industrial Area, Ambattur', city: 'Chennai',
        creditLimit: 40000, creditDays: 21, rating: 4.6,
        onboardedDate: DateTime(2021, 2, 28),
        contacts: [
          const SupplierContact(name: 'Pradeep G', role: 'Sales Manager', phone: '+91 90000 11234', email: 'pradeep@golddrop.in'),
        ],
        documents: [
          SupplierDocument(id: 'd7', type: DocumentType.gst, title: 'GST Registration', uploadedOn: DateTime(2023, 4, 1), expiryDate: DateTime(2025, 3, 31)),
          SupplierDocument(id: 'd8', type: DocumentType.license, title: 'Food Safety License', uploadedOn: DateTime(2023, 4, 1), expiryDate: DateTime(2025, 4, 30)),
          SupplierDocument(id: 'd9', type: DocumentType.invoice, title: 'INV-GD-2025-018', uploadedOn: DateTime.now().subtract(const Duration(days: 12))),
        ],
        payments: [
          PaymentRecord(id: 'p10', amount: 26000, status: PaymentStatus.paid, mode: PaymentMode.bank, date: DateTime.now().subtract(const Duration(days: 12)), description: 'Sunflower Oil 200L + Sesame Oil 20L', invoiceRef: 'INV-GD-017', paidAmount: 26000),
          PaymentRecord(id: 'p11', amount: 18500, status: PaymentStatus.partial, mode: PaymentMode.bank, date: DateTime.now().subtract(const Duration(days: 5)), dueDate: DateTime.now().add(const Duration(days: 16)), description: 'Coconut Oil 50L + Groundnut Oil 100L', invoiceRef: 'INV-GD-018', paidAmount: 10000),
        ],
        deliveries: [
          SupplierDelivery(id: 'del8', deliveredOn: DateTime.now().subtract(const Duration(days: 5)), items: ['Coconut Oil 50L', 'Groundnut Oil 100L'], totalValue: 18500, onTime: true),
          SupplierDelivery(id: 'del9', deliveredOn: DateTime.now().subtract(const Duration(days: 19)), items: ['Sunflower Oil 200L'], totalValue: 22000, onTime: true),
        ],
      ),
      Supplier(
        id: 'sup_005', name: 'Spice Garden Exports', category: 'Spices',
        emoji: '🌶️', status: SupplierStatus.inactive,
        gstNumber: '33PQRST3456U4Z2', address: 'Sowcarpet, Parrys', city: 'Chennai',
        creditLimit: 20000, creditDays: 14, rating: 3.4,
        onboardedDate: DateTime(2023, 6, 1),
        notes: 'On hold – quality issues in last 2 deliveries. Under review.',
        contacts: [
          const SupplierContact(name: 'Babu T', role: 'Owner', phone: '+91 88000 99001'),
        ],
        documents: [
          SupplierDocument(id: 'd10', type: DocumentType.license, title: 'Export License', uploadedOn: DateTime(2023, 6, 5), expiryDate: DateTime(2024, 12, 31)),
        ],
        payments: [
          PaymentRecord(id: 'p12', amount: 7200, status: PaymentStatus.paid, mode: PaymentMode.upi, date: DateTime.now().subtract(const Duration(days: 60)), description: 'Cardamom 2kg + Cinnamon 5kg', paidAmount: 7200),
        ],
        deliveries: [
          SupplierDelivery(id: 'del10', deliveredOn: DateTime.now().subtract(const Duration(days: 60)), items: ['Cardamom 2kg', 'Cinnamon 5kg', 'Pepper 3kg'], totalValue: 7200, onTime: false, note: 'Poor packaging – 300g spillage'),
        ],
      ),
    ]);
  }
}