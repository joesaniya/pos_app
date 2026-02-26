import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/models/table_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SUPABASE TABLE KEYS
// ─────────────────────────────────────────────────────────────────────────────
const _kTables       = 'restaurant_tables';
const _kReservations = 'table_reservations';
const _kView         = 'vw_tables_with_reservation';

// ─────────────────────────────────────────────────────────────────────────────
//  USER CONTEXT  (from Firebase → passed to Supabase rows)
// ─────────────────────────────────────────────────────────────────────────────
class _UserCtx {
  final String uid;
  final String name;
  final String? email;
  final String role;
  final String businessId;
  final String businessName;

  const _UserCtx({
    required this.uid,
    required this.name,
    this.email,
    required this.role,
    required this.businessId,
    required this.businessName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
class TablesProvider extends ChangeNotifier {
  // ── Supabase client ──────────────────────────────────────
  final _sb = Supabase.instance.client;

  // ── Firebase references ──────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _fs   = FirebaseFirestore.instance;

  // ── Local state ──────────────────────────────────────────
  TableSection? _selectedSection;
  TableStatus?  _selectedStatus;
  bool _isLoading = false;
  String? _error;
  _UserCtx? _userCtx;

  final List<RestaurantTable> _tables = [];

  // ─────────────────────────────────────────────────────────
  TablesProvider() {
    _init();
  }

  // ── Getters ──────────────────────────────────────────────
  TableSection? get selectedSection => _selectedSection;
  TableStatus?  get selectedStatus  => _selectedStatus;
  bool   get isLoading => _isLoading;
  String? get error    => _error;

  List<RestaurantTable> get allTables => List.unmodifiable(_tables);

  List<RestaurantTable> get filteredTables {
    return _tables.where((t) {
      if (_selectedSection != null && t.section != _selectedSection) return false;
      if (_selectedStatus  != null && t.status  != _selectedStatus)  return false;
      return true;
    }).toList()
      ..sort((a, b) {
        const p = {
          TableStatus.occupied:  0,
          TableStatus.reserved:  1,
          TableStatus.available: 2,
          TableStatus.cleaning:  3,
        };
        final pa = p[a.status] ?? 4;
        final pb = p[b.status] ?? 4;
        if (pa != pb) return pa.compareTo(pb);
        return a.tableNumber.compareTo(b.tableNumber);
      });
  }

  int get totalAvailable => _tables.where((t) => t.status == TableStatus.available).length;
  int get totalOccupied  => _tables.where((t) => t.status == TableStatus.occupied).length;
  int get totalReserved  => _tables.where((t) => t.status == TableStatus.reserved).length;
  int get totalTables    => _tables.length;

  Map<TableSection, int> get availablePerSection {
    final m = <TableSection, int>{};
    for (final s in TableSection.values) {
      m[s] = _tables
          .where((t) => t.section == s && t.status == TableStatus.available)
          .length;
    }
    return m;
  }

  // ── Filters ──────────────────────────────────────────────
  void setSection(TableSection? s) { _selectedSection = s; notifyListeners(); }
  void setStatus(TableStatus? s)   { _selectedStatus  = s; notifyListeners(); }

  // ── INIT ─────────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadUserCtx();
      if (_userCtx != null) {
        await _fetchTables();
        _subscribeRealtime();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load businessId + role from Firestore users collection
  Future<void> _loadUserCtx() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _fs.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _userCtx = _UserCtx(
      uid:          user.uid,
      name:         data['name'] ?? data['createdByName'] ?? 'Staff',
      email:        user.email,
      role:         data['role'] ?? 'staff',
      businessId:   data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
    );
  }

  // ── Realtime subscription ─────────────────────────────────
  RealtimeChannel? _channel;

  void _subscribeRealtime() {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;

    _channel = _sb
      .channel('tables_$bId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _kTables,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_id',
          value: bId,
        ),
        callback: (_) => _fetchTables(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _kReservations,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_id',
          value: bId,
        ),
        callback: (_) => _fetchTables(),
      )
      .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── FETCH TABLES FROM SUPABASE ────────────────────────────
  Future<void> _fetchTables() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;

    try {
      final rows = await _sb
          .from(_kView)
          .select()
          .eq('business_id', bId)
          .eq('is_active', true)
          .order('table_number');

      _tables
        ..clear()
        ..addAll(rows.map(_rowToTable));
      notifyListeners();
    } catch (e) {
      _error = 'Fetch error: $e';
      notifyListeners();
    }
  }

  // ── ROW → MODEL ───────────────────────────────────────────
  RestaurantTable _rowToTable(Map<String, dynamic> row) {
    Reservation? reservation;
    if (row['reservation_id'] != null) {
      reservation = Reservation(
        id:           row['reservation_id'],
        customerName: row['res_customer_name'] ?? '',
        phone:        row['res_phone'],
        guestCount:   row['res_guest_count'] ?? 2,
        reservedFor:  DateTime.parse(row['res_reserved_for']).toLocal(),
        notes:        row['res_notes'],
        createdAt:    DateTime.parse(row['res_created_at']).toLocal(),
      );
    }

    return RestaurantTable(
      id:                    row['id'],
      tableNumber:           row['table_number'],
      capacity:              row['capacity'],
      status:                _parseStatus(row['status']),
      section:               _parseSection(row['section']),
      shape:                 _parseShape(row['shape'] ?? 'square'),
      hasWindow:             row['has_window'] ?? false,
      isPremium:             row['is_premium'] ?? false,
      currentCustomerName:   row['current_customer_name'],
      currentOrderId:        row['current_order_id'],
      currentOrderTotal:     row['current_order_total'] != null
                               ? (row['current_order_total'] as num).toDouble()
                               : null,
      occupiedSince:         row['occupied_since'] != null
                               ? DateTime.parse(row['occupied_since']).toLocal()
                               : null,
      reservation:           reservation,
    );
  }

  TableStatus  _parseStatus(String s)  => TableStatus.values.firstWhere((e) => e.name == s, orElse: () => TableStatus.available);
  TableSection _parseSection(String s) => TableSection.values.firstWhere((e) => e.name == s, orElse: () => TableSection.ac);
  TableShape   _parseShape(String s)   => TableShape.values.firstWhere((e) => e.name == s, orElse: () => TableShape.square);

  // ── MODEL → ROW ───────────────────────────────────────────
  Map<String, dynamic> _tableToRow(RestaurantTable t, {bool isCreate = false}) {
    final ctx = _userCtx!;
    final base = <String, dynamic>{
      'table_number': t.tableNumber,
      'capacity':     t.capacity,
      'section':      t.section.name,
      'shape':        t.shape.name,
      'has_window':   t.hasWindow,
      'is_premium':   t.isPremium,
      'status':       t.status.name,
      'business_id':  ctx.businessId,
      'business_name': ctx.businessName,
      'updated_by_uid':  ctx.uid,
      'updated_by_name': ctx.name,
      'updated_by_role': ctx.role,
    };
    if (isCreate) {
      base['created_by_uid']   = ctx.uid;
      base['created_by_name']  = ctx.name;
      base['created_by_email'] = ctx.email;
      base['created_by_role']  = ctx.role;
    }
    return base;
  }

  // ══════════════════════════════════════════════════════════
  //  TABLE CRUD
  // ══════════════════════════════════════════════════════════

  Future<void> addTable(RestaurantTable t) async {
    _setLoading(true);
    try {
      final row = _tableToRow(t, isCreate: true);
      row.remove('id'); // let Supabase generate UUID
      await _sb.from(_kTables).insert(row);
      await _fetchTables();
    } catch (e) {
      _error = 'Add table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTable(RestaurantTable updated) async {
    _setLoading(true);
    try {
      final row = _tableToRow(updated);
      await _sb.from(_kTables).update(row).eq('id', updated.id);
      await _fetchTables();
    } catch (e) {
      _error = 'Update table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTable(String id) async {
    _setLoading(true);
    try {
      // Soft delete
      await _sb.from(_kTables)
          .update({
            'is_active':       false,
            'updated_by_uid':  _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', id);
      await _fetchTables();
    } catch (e) {
      _error = 'Delete table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  TABLE STATUS OPERATIONS
  // ══════════════════════════════════════════════════════════

  Future<void> seatGuests(String tableId, String customerName) async {
    try {
      await _sb.from(_kTables).update({
        'status':               'occupied',
        'current_customer_name': customerName,
        'occupied_since':       DateTime.now().toUtc().toIso8601String(),
        'updated_by_uid':       _userCtx?.uid,
        'updated_by_name':      _userCtx?.name,
      }).eq('id', tableId);

      // Cancel active reservation
      await _sb.from(_kReservations)
          .update({'status': 'seated'})
          .eq('table_id', tableId)
          .eq('status', 'active');

      await _fetchTables();
    } catch (e) {
      _error = 'Seat guests error: $e';
      notifyListeners();
    }
  }

  Future<void> clearTable(String tableId) async {
    try {
      await _sb.from(_kTables).update({
        'status':               'cleaning',
        'current_customer_name': null,
        'current_order_id':      null,
        'current_order_total':   null,
        'occupied_since':        null,
        'updated_by_uid':        _userCtx?.uid,
        'updated_by_name':       _userCtx?.name,
      }).eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Clear table error: $e';
      notifyListeners();
    }
  }

  Future<void> markAvailable(String tableId) async {
    try {
      await _sb.from(_kTables).update({
        'status':          'available',
        'updated_by_uid':  _userCtx?.uid,
        'updated_by_name': _userCtx?.name,
      }).eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Mark available error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  RESERVATION CRUD
  // ══════════════════════════════════════════════════════════

  Future<void> addReservation(String tableId, Reservation res) async {
    try {
      final ctx = _userCtx!;

      // Insert reservation row
      await _sb.from(_kReservations).insert({
        'table_id':         tableId,
        'customer_name':    res.customerName,
        'phone':            res.phone,
        'guest_count':      res.guestCount,
        'reserved_for':     res.reservedFor.toUtc().toIso8601String(),
        'notes':            res.notes,
        'status':           'active',
        'business_id':      ctx.businessId,
        'business_name':    ctx.businessName,
        'created_by_uid':   ctx.uid,
        'created_by_name':  ctx.name,
        'created_by_email': ctx.email,
        'created_by_role':  ctx.role,
      });

      // Update table status → reserved
      await _sb.from(_kTables).update({
        'status':          'reserved',
        'updated_by_uid':  ctx.uid,
        'updated_by_name': ctx.name,
      }).eq('id', tableId);

      await _fetchTables();
    } catch (e) {
      _error = 'Add reservation error: $e';
      notifyListeners();
    }
  }

  Future<void> updateReservation(String tableId, Reservation updated) async {
    try {
      await _sb.from(_kReservations).update({
        'customer_name':   updated.customerName,
        'phone':           updated.phone,
        'guest_count':     updated.guestCount,
        'reserved_for':    updated.reservedFor.toUtc().toIso8601String(),
        'notes':           updated.notes,
        'updated_by_uid':  _userCtx?.uid,
        'updated_by_name': _userCtx?.name,
      }).eq('id', updated.id);
      await _fetchTables();
    } catch (e) {
      _error = 'Update reservation error: $e';
      notifyListeners();
    }
  }

  void cancelReservation(String tableId) {
    _cancelReservationAsync(tableId);
  }

  Future<void> _cancelReservationAsync(String tableId) async {
    try {
      await _sb.from(_kReservations)
          .update({
            'status':          'cancelled',
            'updated_by_uid':  _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('table_id', tableId)
          .eq('status', 'active');

      await _sb.from(_kTables).update({
        'status':          'available',
        'updated_by_uid':  _userCtx?.uid,
        'updated_by_name': _userCtx?.name,
      }).eq('id', tableId);

      await _fetchTables();
    } catch (e) {
      _error = 'Cancel reservation error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  /// Call this to manually refresh (pull-to-refresh)
  Future<void> refresh() => _fetchTables();

  /// Generate a temporary local ID (not used for Supabase inserts — UUID generated by DB)
  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';

  /// Next table number for this business (local fallback)
  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

  // ══════════════════════════════════════════════════════════
  //  ADVANCED FEATURES
  // ══════════════════════════════════════════════════════════

  /// Get today's upcoming reservations (for dashboard widget)
  List<RestaurantTable> get todayReservations {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return _tables.where((t) {
      final r = t.reservation;
      if (r == null) return false;
      return r.reservedFor.isAfter(today) && r.reservedFor.isBefore(tomorrow);
    }).toList()
      ..sort((a, b) => a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor));
  }

  /// Average occupancy rate (occupied / total)
  double get occupancyRate {
    if (_tables.isEmpty) return 0;
    return totalOccupied / _tables.length;
  }

  /// Tables that have been occupied longer than [minutes]
  List<RestaurantTable> longOccupiedTables(int minutes) {
    final threshold = DateTime.now().subtract(Duration(minutes: minutes));
    return _tables.where((t) {
      return t.status == TableStatus.occupied &&
             t.occupiedSince != null &&
             t.occupiedSince!.isBefore(threshold);
    }).toList();
  }

  /// Reservations coming up in the next [minutes]
  List<RestaurantTable> upcomingReservations(int minutes) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(minutes: minutes));
    return _tables.where((t) {
      final r = t.reservation;
      if (r == null) return false;
      return r.reservedFor.isAfter(now) && r.reservedFor.isBefore(cutoff);
    }).toList()
      ..sort((a, b) => a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor));
  }

  /// Fetch historical reservations for a date range (not cached locally)
  Future<List<Map<String, dynamic>>> fetchReservationsForRange(
    DateTime from,
    DateTime to,
  ) async {
    final bId = _userCtx?.businessId;
    if (bId == null) return [];
    try {
      final rows = await _sb
          .from(_kReservations)
          .select('*, restaurant_tables(table_number, section)')
          .eq('business_id', bId)
          .gte('reserved_for', from.toUtc().toIso8601String())
          .lte('reserved_for', to.toUtc().toIso8601String())
          .neq('status', 'cancelled')
          .order('reserved_for');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      return [];
    }
  }

  // ── Capacity stats by section ─────────────────────────────
  Map<TableSection, Map<String, int>> get sectionStats {
    final result = <TableSection, Map<String, int>>{};
    for (final s in TableSection.values) {
      final sectionTables = _tables.where((t) => t.section == s).toList();
      result[s] = {
        'total':     sectionTables.length,
        'available': sectionTables.where((t) => t.status == TableStatus.available).length,
        'occupied':  sectionTables.where((t) => t.status == TableStatus.occupied).length,
        'reserved':  sectionTables.where((t) => t.status == TableStatus.reserved).length,
        'cleaning':  sectionTables.where((t) => t.status == TableStatus.cleaning).length,
        'capacity':  sectionTables.fold(0, (sum, t) => sum + t.capacity),
      };
    }
    return result;
  }

  // ── User role helpers ─────────────────────────────────────
  bool get canManageTables =>
      _userCtx != null && ['admin', 'manager', 'owner'].contains(_userCtx!.role);

  bool get canAddReservation =>
      _userCtx != null && ['admin', 'manager', 'owner', 'staff'].contains(_userCtx!.role);

  String get currentUserRole => _userCtx?.role ?? 'staff';
  String get currentBusinessId => _userCtx?.businessId ?? '';
  String get currentBusinessName => _userCtx?.businessName ?? '';
}

/*import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';


class TablesProvider extends ChangeNotifier {
  TableSection? _selectedSection; // null = all
  TableStatus?  _selectedStatus;  // null = all
  bool _isLoading = false;

  final List<RestaurantTable> _tables = [];

  TablesProvider() { _seed(); }

  // ── Getters ──────────────────────────────────────────────
  TableSection? get selectedSection => _selectedSection;
  TableStatus?  get selectedStatus  => _selectedStatus;
  bool get isLoading => _isLoading;

  List<RestaurantTable> get allTables => List.unmodifiable(_tables);

  List<TableSection> get activeSections =>
      TableSection.values.where((s) =>
        _tables.any((t) => t.section == s)).toList();

  List<RestaurantTable> get filteredTables {
    return _tables.where((t) {
      if (_selectedSection != null && t.section != _selectedSection) return false;
      if (_selectedStatus  != null && t.status  != _selectedStatus)  return false;
      return true;
    }).toList()
      ..sort((a, b) {
        // Sort: occupied first → reserved → available → cleaning
        const p = {
          TableStatus.occupied:  0,
          TableStatus.reserved:  1,
          TableStatus.available: 2,
          TableStatus.cleaning:  3,
        };
        final pa = p[a.status] ?? 4;
        final pb = p[b.status] ?? 4;
        if (pa != pb) return pa.compareTo(pb);
        return a.tableNumber.compareTo(b.tableNumber);
      });
  }

  // Stats per section
  Map<TableSection, int> get availablePerSection {
    final m = <TableSection, int>{};
    for (final s in TableSection.values) {
      m[s] = _tables
          .where((t) => t.section == s && t.status == TableStatus.available)
          .length;
    }
    return m;
  }

  int get totalAvailable => _tables.where((t) => t.status == TableStatus.available).length;
  int get totalOccupied  => _tables.where((t) => t.status == TableStatus.occupied).length;
  int get totalReserved  => _tables.where((t) => t.status == TableStatus.reserved).length;
  int get totalTables    => _tables.length;

  // ── Filters ──────────────────────────────────────────────
  void setSection(TableSection? s) { _selectedSection = s; notifyListeners(); }
  void setStatus(TableStatus? s)   { _selectedStatus  = s; notifyListeners(); }

  // ── CRUD ─────────────────────────────────────────────────
  Future<void> addTable(RestaurantTable t) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _tables.add(t);
    _isLoading = false; notifyListeners();
  }

  Future<void> updateTable(RestaurantTable updated) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _tables.indexWhere((t) => t.id == updated.id);
    if (idx != -1) _tables[idx] = updated;
    _isLoading = false; notifyListeners();
  }

  Future<void> deleteTable(String id) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));
    _tables.removeWhere((t) => t.id == id);
    _isLoading = false; notifyListeners();
  }

  // ── Reservation ops ───────────────────────────────────────
  Future<void> addReservation(String tableId, Reservation res) async {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.reserved,
      reservation: res,
    );
    notifyListeners();
  }

  Future<void> updateReservation(String tableId, Reservation updated) async {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(reservation: updated);
    notifyListeners();
  }

  void cancelReservation(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.available,
      clearReservation: true,
    );
    notifyListeners();
  }

  void seatGuests(String tableId, String customerName) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.occupied,
      currentCustomerName: customerName,
      occupiedSince: DateTime.now(),
      clearReservation: true,
    );
    notifyListeners();
  }

  void clearTable(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.cleaning,
      clearOccupied: true,
    );
    notifyListeners();
  }

  void markAvailable(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(status: TableStatus.available);
    notifyListeners();
  }

  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';

  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

  // ── Seed ─────────────────────────────────────────────────
  void _seed() {
    _tables.addAll([
      // AC HALL – Ground Floor
      RestaurantTable(
        id: 'tbl_001', tableNumber: 1, capacity: 4, section: TableSection.ac,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Arjun & Party', currentOrderId: '#4523',
        currentOrderTotal: 1250.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 45)),
        hasWindow: true,
      ),
      RestaurantTable(
        id: 'tbl_002', tableNumber: 2, capacity: 2, section: TableSection.ac,
        status: TableStatus.available, shape: TableShape.round, hasWindow: false,
      ),
      RestaurantTable(
        id: 'tbl_003', tableNumber: 3, capacity: 6, section: TableSection.ac,
        status: TableStatus.reserved, shape: TableShape.rectangle,
        reservation: Reservation(
          id: 'res_001', customerName: 'Priya Sharma', phone: '+91 98765 43210',
          guestCount: 5, notes: 'Birthday dinner – cake arranged',
          reservedFor: DateTime.now().add(const Duration(hours: 1, minutes: 20)),
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ),
      RestaurantTable(
        id: 'tbl_004', tableNumber: 4, capacity: 4, section: TableSection.ac,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Rajesh M', currentOrderId: '#4521',
        currentOrderTotal: 2100.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 30)),
        isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_005', tableNumber: 5, capacity: 2, section: TableSection.ac,
        status: TableStatus.cleaning, shape: TableShape.round,
      ),

      // NON-AC – Ground Floor
      RestaurantTable(
        id: 'tbl_006', tableNumber: 6, capacity: 4, section: TableSection.nonAc,
        status: TableStatus.available, shape: TableShape.square,
      ),
      RestaurantTable(
        id: 'tbl_007', tableNumber: 7, capacity: 6, section: TableSection.nonAc,
        status: TableStatus.occupied, shape: TableShape.rectangle,
        currentCustomerName: 'Meena & Family', currentOrderId: '#4520',
        currentOrderTotal: 880.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 55)),
      ),
      RestaurantTable(
        id: 'tbl_008', tableNumber: 8, capacity: 4, section: TableSection.nonAc,
        status: TableStatus.reserved, shape: TableShape.square,
        reservation: Reservation(
          id: 'res_002', customerName: 'Karthik S', phone: '+91 90001 22334',
          guestCount: 3, notes: 'Window seat preferred',
          reservedFor: DateTime.now().add(const Duration(minutes: 40)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ),
      RestaurantTable(
        id: 'tbl_009', tableNumber: 9, capacity: 8, section: TableSection.nonAc,
        status: TableStatus.available, shape: TableShape.rectangle,
      ),

      // ROOFTOP – 3rd Floor
      RestaurantTable(
        id: 'tbl_010', tableNumber: 10, capacity: 2, section: TableSection.rooftop,
        status: TableStatus.available, shape: TableShape.round,
        hasWindow: true, isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_011', tableNumber: 11, capacity: 4, section: TableSection.rooftop,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Divya R', currentOrderId: '#4519',
        currentOrderTotal: 1540.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 20)),
        hasWindow: true, isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_012', tableNumber: 12, capacity: 4, section: TableSection.rooftop,
        status: TableStatus.reserved, shape: TableShape.round,
        isPremium: true,
        reservation: Reservation(
          id: 'res_003', customerName: 'Suresh & Anita', phone: '+91 95555 66778',
          guestCount: 4, notes: 'Anniversary dinner',
          reservedFor: DateTime.now().add(const Duration(hours: 2)),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ),

      // GARDEN – Ground Floor
      RestaurantTable(
        id: 'tbl_013', tableNumber: 13, capacity: 6, section: TableSection.garden,
        status: TableStatus.available, shape: TableShape.rectangle,
        hasWindow: true,
      ),
      RestaurantTable(
        id: 'tbl_014', tableNumber: 14, capacity: 4, section: TableSection.garden,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'IT Team Lunch', currentOrderId: '#4518',
        currentOrderTotal: 3200.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 38)),
      ),

      // PRIVATE – 2nd Floor
      RestaurantTable(
        id: 'tbl_015', tableNumber: 15, capacity: 12, section: TableSection.privateRoom,
        status: TableStatus.available, shape: TableShape.rectangle,
        isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_016', tableNumber: 16, capacity: 8, section: TableSection.privateRoom,
        status: TableStatus.reserved, shape: TableShape.rectangle,
        isPremium: true,
        reservation: Reservation(
          id: 'res_004', customerName: 'Corporate – TCS', phone: '+91 44000 11223',
          guestCount: 8, notes: 'Board meeting lunch, projector required',
          reservedFor: DateTime.now().add(const Duration(hours: 3)),
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ),
    ]);
  }
}

*/