import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pos_app/utils/ist_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/services/reservation_notification_service.dart';

const _kTables = 'restaurant_tables';
const _kReservations = 'table_reservations';
const _kView = 'vw_tables_with_reservation';

class _UserCtx {
  final String uid, name, role, businessId, businessName;
  final String? email;
  const _UserCtx({
    required this.uid,
    required this.name,
    this.email,
    required this.role,
    required this.businessId,
    required this.businessName,
  });
}

// ══════════════════════════════════════════════════════════════
class TablesProvider extends ChangeNotifier {
  final _sb = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final _notif = ReservationNotificationService();

  // ── State ──────────────────────────────────────────────
  TableSection? _selectedSection;
  TableStatus? _selectedStatus;
  bool _isLoading = false;
  String? _error;
  _UserCtx? _userCtx;
  final List<RestaurantTable> _tables = [];
  final List<ReservationHistoryItem> _history = [];

  // ── FIX: New cache for all upcoming active/seated reservations.
  //
  // ROOT CAUSE OF ALL CALENDAR / COUNT BUGS:
  //   _rowToTable() only attaches a Reservation to a table when isToday==true.
  //   So _tables only ever has today's reservations in memory.
  //   reservationsForDate(feb28) searched _tables → always empty.
  //   todayReservationCount / tomorrowReservationCount → always 0.
  //
  // FIX: query table_reservations directly for the next 60 days into
  //   _calendarReservations. Calendar view + counts read from this instead.
  final List<ReservationHistoryItem> _calendarReservations = [];
  bool _calendarLoading = false;

  bool _historyLoading = false;
  bool _historyHasMore = true;
  int _historyPage = 0;
  static const _pageSize = 20;
  DateTime? _historyFrom, _historyTo;

  Timer? _notifTimer;
  RealtimeChannel? _channel;

  TablesProvider() {
    _init();
  }

  // ── Getters ────────────────────────────────────────────
  TableSection? get selectedSection => _selectedSection;
  TableStatus? get selectedStatus => _selectedStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RestaurantTable> get allTables => List.unmodifiable(_tables);
  List<ReservationHistoryItem> get history => List.unmodifiable(_history);
  bool get historyLoading => _historyLoading;
  bool get historyHasMore => _historyHasMore;

  /// All upcoming active/seated reservations — used by CalendarView.
  List<ReservationHistoryItem> get calendarReservations =>
      List.unmodifiable(_calendarReservations);
  bool get calendarLoading => _calendarLoading;

  List<RestaurantTable> get filteredTables {
    return _tables.where((t) {
      if (_selectedSection != null && t.section != _selectedSection)
        return false;
      if (_selectedStatus != null && t.status != _selectedStatus) return false;
      return true;
    }).toList()..sort((a, b) {
      const p = {
        TableStatus.occupied: 0,
        TableStatus.reserved: 1,
        TableStatus.available: 2,
        TableStatus.cleaning: 3,
      };
      final pa = p[a.status] ?? 4, pb = p[b.status] ?? 4;
      if (pa != pb) return pa.compareTo(pb);
      return a.tableNumber.compareTo(b.tableNumber);
    });
  }

  int get totalAvailable =>
      _tables.where((t) => t.status == TableStatus.available).length;
  int get totalOccupied =>
      _tables.where((t) => t.status == TableStatus.occupied).length;
  int get totalReserved =>
      _tables.where((t) => t.status == TableStatus.reserved).length;
  int get totalTables => _tables.length;

  // ── FIX: reservationsForDate now reads from _calendarReservations ──
  // Returns ReservationHistoryItem list (not RestaurantTable list).
  // This works for ANY date — today, tomorrow, Feb 28, March 4, etc.
  List<ReservationHistoryItem> reservationsForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _calendarReservations.where((r) {
      final rd = DateTime(
        r.reservedFor.year,
        r.reservedFor.month,
        r.reservedFor.day,
      );
      return rd == d;
    }).toList()..sort((a, b) => a.reservedFor.compareTo(b.reservedFor));
  }

  // ── FIX: counts now use _calendarReservations ──────────
  // Previously always returned 0 because _tables only has today's reservations.
  int get todayReservationCount => reservationsForDate(DateTime.now()).length;
  int get tomorrowReservationCount =>
      reservationsForDate(DateTime.now().add(const Duration(days: 1))).length;

  /// Which dates in a given month have ≥1 reservation — for calendar dot indicators.
  Set<DateTime> reservationDatesInMonth(int year, int month) {
    return _calendarReservations
        .where(
          (r) => r.reservedFor.year == year && r.reservedFor.month == month,
        )
        .map(
          (r) => DateTime(
            r.reservedFor.year,
            r.reservedFor.month,
            r.reservedFor.day,
          ),
        )
        .toSet();
  }

  List<RestaurantTable> get longSeatedTables => longOccupiedTables(240);

  Map<TableSection, int> get availablePerSection {
    final m = <TableSection, int>{};
    for (final s in TableSection.values) {
      m[s] = _tables
          .where((t) => t.section == s && t.status == TableStatus.available)
          .length;
    }
    return m;
  }

  // ── Filters ────────────────────────────────────────────
  void setSection(TableSection? s) {
    _selectedSection = s;
    notifyListeners();
  }

  void setStatus(TableStatus? s) {
    _selectedStatus = s;
    notifyListeners();
  }

  // ── Init ───────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _notif.initialize();
      _notif.resetSentKeys();
      await _loadUserCtx();
      if (_userCtx != null) {
        // FIX: fetch tables AND upcoming reservations in parallel
        await Future.wait([_fetchTables(), _fetchCalendarReservations()]);
        _subscribeRealtime();
        _startNotifTimer();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('TablesProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserCtx() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _fs.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final d = doc.data()!;
    _userCtx = _UserCtx(
      uid: user.uid,
      name: d['name'] ?? 'Staff',
      email: user.email,
      role: d['role'] ?? 'staff',
      businessId: d['businessId'] ?? '',
      businessName: d['businessName'] ?? '',
    );
  }

  // ── FIX: Fetch all active/seated reservations for calendar ─────────
  // Covers yesterday → +60 days. No isToday filter — includes ALL upcoming.
  // Returns ReservationHistoryItem (same model used by History view).
  Future<void> _fetchCalendarReservations() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;
    _calendarLoading = true;
    try {
      final from = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final to = DateTime.now()
          .add(const Duration(days: 60))
          .toUtc()
          .toIso8601String();

      final rows = await _sb
          .from(_kReservations)
          .select('*, restaurant_tables(table_number, section)')
          .eq('business_id', bId)
          .inFilter('status', ['active', 'seated'])
          .gte('reserved_for', from)
          .lte('reserved_for', to)
          .order('reserved_for', ascending: true);

      _calendarReservations
        ..clear()
        ..addAll(
          (rows as List).map(
            (r) => ReservationHistoryItem.fromMap(r as Map<String, dynamic>),
          ),
        );
    } catch (e) {
      debugPrint('Calendar reservations fetch error: $e');
    } finally {
      _calendarLoading = false;
    }
  }

  // ── Helper: refresh both together, one notifyListeners at end ─────
  Future<void> _refreshAll() async {
    await Future.wait([_fetchTables(), _fetchCalendarReservations()]);
    notifyListeners();
  }

  // ── Notification timer ─────────────────────────────────
  void _startNotifTimer() {
    _notifTimer?.cancel();
    _runNotifCheck();
    _notifTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _runNotifCheck(),
    );
  }

  void _runNotifCheck() => _notif.checkAll(
    tables: _tables,
    businessName: _userCtx?.businessName ?? '',
    longSeatedMinutes: 240,
  );

  // ── Realtime ───────────────────────────────────────────
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
          callback: (_) => _refreshAll(),
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
          // FIX: _refreshAll keeps calendar cache in sync on every change
          callback: (_) => _refreshAll(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _notifTimer?.cancel();
    super.dispose();
  }

  // ── Fetch tables (Floor view) ──────────────────────────
  // NOTE: isToday check in _rowToTable is intentional — Floor view table
  // cards only show today's reservation. Calendar uses _calendarReservations.
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
      _runNotifCheck();
    } catch (e) {
      _error = 'Fetch error: $e';
      notifyListeners();
    }
  }
  // ═══════════════════════════════════════════════════════════════
  //  PATCH FOR: lib/providers/tables_provider.dart
  //
  //  STEP 1: Add this import near the top:
  //    import 'package:pos_app/utils/ist_utils.dart';
  //
  //  STEP 2: Replace the entire _rowToTable method with this:
  // ═══════════════════════════════════════════════════════════════

  RestaurantTable _rowToTable(Map<String, dynamic> row) {
    Reservation? reservation;

    if (row['reservation_id'] != null) {
      // ✅ FIX: always parse Supabase UTC → IST explicitly
      final reservedFor = parseToIST(row['res_reserved_for'] as String);
      final resStatus = (row['res_status'] ?? 'active') as String;

      // Compare dates in IST
      final todayIST = nowIST();
      final isToday =
          reservedFor.year == todayIST.year &&
          reservedFor.month == todayIST.month &&
          reservedFor.day == todayIST.day;

      if (isToday && (resStatus == 'active' || resStatus == 'seated')) {
        reservation = Reservation(
          id: row['reservation_id'] as String,
          customerName: row['res_customer_name'] as String? ?? '',
          phone: row['res_phone'] as String?,
          guestCount: row['res_guest_count'] as int? ?? 2,
          reservedFor: reservedFor,
          checkIn: row['res_check_in'] != null
              ? parseToIST(row['res_check_in'] as String)
              : null,
          checkOut: row['res_check_out'] != null
              ? parseToIST(row['res_check_out'] as String)
              : null,
          notes: row['res_notes'] as String?,
          warningSent: row['res_warning_sent'] as bool? ?? false,
          createdAt: parseToIST(row['res_created_at'] as String),
          createdByName: row['res_created_by_name'] as String?,
          createdByRole: row['res_created_by_role'] as String?,
        );
      }
    }

    return RestaurantTable(
      id: row['id'] as String,
      tableNumber: row['table_number'] as int,
      capacity: row['capacity'] as int,
      status: _parseStatus(row['status'] as String),
      section: _parseSection(row['section'] as String),
      shape: _parseShape((row['shape'] ?? 'square') as String),
      hasWindow: row['has_window'] as bool? ?? false,
      isPremium: row['is_premium'] as bool? ?? false,
      currentCustomerName: row['current_customer_name'] as String?,
      currentOrderId: row['current_order_id'] as String?,
      currentOrderTotal: row['current_order_total'] != null
          ? (row['current_order_total'] as num).toDouble()
          : null,

      // ✅ KEY FIX: parse occupied_since as UTC → IST
      // Old code: DateTime.parse(row['occupied_since']).toLocal()
      // Problem:  .toLocal() uses DEVICE timezone — unreliable
      // Fix:      parseToIST() hardcodes +5:30 regardless of device
      occupiedSince: row['occupied_since'] != null
          ? parseToIST(row['occupied_since'] as String)
          : null,

      reservation: reservation,
    );
  }

  RestaurantTable _rowToTable_ordertimefix(Map<String, dynamic> row) {
    Reservation? reservation;
    if (row['reservation_id'] != null) {
      // ✅ FIX: parse as UTC → IST explicitly
      final reservedFor = parseToIST(row['res_reserved_for'] as String);
      final resStatus = (row['res_status'] ?? 'active') as String;
      final todayIST = nowIST();
      final isToday =
          reservedFor.year == todayIST.year &&
          reservedFor.month == todayIST.month &&
          reservedFor.day == todayIST.day;

      if (isToday && (resStatus == 'active' || resStatus == 'seated')) {
        reservation = Reservation(
          id: row['reservation_id'],
          customerName: row['res_customer_name'] ?? '',
          phone: row['res_phone'],
          guestCount: row['res_guest_count'] ?? 2,
          reservedFor: reservedFor,
          checkIn: row['res_check_in'] != null
              ? parseToIST(row['res_check_in'] as String)
              : null,
          checkOut: row['res_check_out'] != null
              ? parseToIST(row['res_check_out'] as String)
              : null,
          notes: row['res_notes'],
          warningSent: row['res_warning_sent'] ?? false,
          createdAt: parseToIST(row['res_created_at'] as String),
          createdByName: row['res_created_by_name'],
          createdByRole: row['res_created_by_role'],
        );
      }
    }

    return RestaurantTable(
      id: row['id'],
      tableNumber: row['table_number'],
      capacity: row['capacity'],
      status: _parseStatus(row['status']),
      section: _parseSection(row['section']),
      shape: _parseShape(row['shape'] ?? 'square'),
      hasWindow: row['has_window'] ?? false,
      isPremium: row['is_premium'] ?? false,
      currentCustomerName: row['current_customer_name'],
      currentOrderId: row['current_order_id'],
      currentOrderTotal: row['current_order_total'] != null
          ? (row['current_order_total'] as num).toDouble()
          : null,
      // ✅ FIX: parse occupied_since as UTC → IST
      occupiedSince: row['occupied_since'] != null
          ? parseToIST(row['occupied_since'] as String)
          : null,
      reservation: reservation,
    );
  }

  // ── Row → Model ────────────────────────────────────────
  RestaurantTable _rowToTable1(Map<String, dynamic> row) {
    Reservation? reservation;
    if (row['reservation_id'] != null) {
      final reservedFor = DateTime.parse(row['res_reserved_for']).toLocal();
      final resStatus = (row['res_status'] ?? 'active') as String;
      final today = DateTime.now();
      final isToday =
          reservedFor.year == today.year &&
          reservedFor.month == today.month &&
          reservedFor.day == today.day;

      if (isToday && (resStatus == 'active' || resStatus == 'seated')) {
        reservation = Reservation(
          id: row['reservation_id'],
          customerName: row['res_customer_name'] ?? '',
          phone: row['res_phone'],
          guestCount: row['res_guest_count'] ?? 2,
          reservedFor: reservedFor,
          checkIn: row['res_check_in'] != null
              ? DateTime.parse(row['res_check_in']).toLocal()
              : null,
          checkOut: row['res_check_out'] != null
              ? DateTime.parse(row['res_check_out']).toLocal()
              : null,
          notes: row['res_notes'],
          warningSent: row['res_warning_sent'] ?? false,
          createdAt: DateTime.parse(row['res_created_at']).toLocal(),
          createdByName: row['res_created_by_name'],
          createdByRole: row['res_created_by_role'],
        );
      }
    }
    return RestaurantTable(
      id: row['id'],
      tableNumber: row['table_number'],
      capacity: row['capacity'],
      status: _parseStatus(row['status']),
      section: _parseSection(row['section']),
      shape: _parseShape(row['shape'] ?? 'square'),
      hasWindow: row['has_window'] ?? false,
      isPremium: row['is_premium'] ?? false,
      currentCustomerName: row['current_customer_name'],
      currentOrderId: row['current_order_id'],
      currentOrderTotal: row['current_order_total'] != null
          ? (row['current_order_total'] as num).toDouble()
          : null,
      occupiedSince: row['occupied_since'] != null
          ? DateTime.parse(row['occupied_since']).toLocal()
          : null,
      reservation: reservation,
    );
  }

  TableStatus _parseStatus(String s) => TableStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableStatus.available,
  );
  TableSection _parseSection(String s) => TableSection.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableSection.ac,
  );
  TableShape _parseShape(String s) => TableShape.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableShape.square,
  );

  // ── Model → Row ────────────────────────────────────────
  Map<String, dynamic> _tableToRow(RestaurantTable t, {bool isCreate = false}) {
    final ctx = _userCtx!;
    final base = <String, dynamic>{
      'table_number': t.tableNumber,
      'capacity': t.capacity,
      'section': t.section.name,
      'shape': t.shape.name,
      'has_window': t.hasWindow,
      'is_premium': t.isPremium,
      'status': t.status.name,
      'business_id': ctx.businessId,
      'business_name': ctx.businessName,
      'updated_by_uid': ctx.uid,
      'updated_by_name': ctx.name,
      'updated_by_role': ctx.role,
    };
    if (isCreate) {
      base['created_by_uid'] = ctx.uid;
      base['created_by_name'] = ctx.name;
      base['created_by_email'] = ctx.email;
      base['created_by_role'] = ctx.role;
    }
    return base;
  }

  // ══════════════════════════════════════════════════════
  //  TABLE CRUD
  // ══════════════════════════════════════════════════════
  Future<void> addTable(RestaurantTable t) async {
    _setLoading(true);
    try {
      final row = _tableToRow(t, isCreate: true)..remove('id');
      await _sb.from(_kTables).insert(row);
      await _refreshAll();
    } catch (e) {
      _error = 'Add table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTable(RestaurantTable updated) async {
    _setLoading(true);
    try {
      await _sb
          .from(_kTables)
          .update(_tableToRow(updated))
          .eq('id', updated.id);
      await _refreshAll();
    } catch (e) {
      _error = 'Update table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTable(String id) async {
    _setLoading(true);
    try {
      await _sb
          .from(_kTables)
          .update({
            'is_active': false,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', id);
      await _refreshAll();
    } catch (e) {
      _error = 'Delete table error: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  STATUS OPS
  // ══════════════════════════════════════════════════════
  Future<void> seatGuests(String tableId, String customerName) async {
    try {
      final t = _tables.where((t) => t.id == tableId).firstOrNull;
      if (t?.reservation != null)
        _notif.clearReservationKeys(t!.reservation!.id);
      await _sb
          .from(_kTables)
          .update({
            'status': 'occupied',
            'current_customer_name': customerName,
            'occupied_since': DateTime.now().toUtc().toIso8601String(),
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _sb
          .from(_kReservations)
          .update({
            'status': 'seated',
            'check_in': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('table_id', tableId)
          .eq('status', 'active');
      await _refreshAll();
    } catch (e) {
      _error = 'Seat guests error: $e';
      notifyListeners();
    }
  }

  Future<void> clearTable(String tableId) async {
    try {
      await _sb
          .from(_kTables)
          .update({
            'status': 'cleaning',
            'current_customer_name': null,
            'current_order_id': null,
            'current_order_total': null,
            'occupied_since': null,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Clear table error: $e';
      notifyListeners();
    }
  }

  Future<void> markAvailable(String tableId) async {
    try {
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Mark available error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  RESERVATION CRUD
  // ══════════════════════════════════════════════════════
  Future<bool> checkAvailability({
    required String tableId,
    required DateTime checkIn,
    required DateTime checkOut,
    String? excludeReservationId,
  }) async {
    try {
      final result = await _sb.rpc(
        'fn_check_table_availability',
        params: {
          'p_table_id': tableId,
          'p_check_in': checkIn.toUtc().toIso8601String(),
          'p_check_out': checkOut.toUtc().toIso8601String(),
          if (excludeReservationId != null)
            'p_exclude_id': excludeReservationId,
        },
      );
      return result == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> addReservation(String tableId, Reservation res) async {
    try {
      final ctx = _userCtx!;
      await _sb.from(_kReservations).insert({
        'table_id': tableId,
        'customer_name': res.customerName,
        'phone': res.phone,
        'guest_count': res.guestCount,
        'reserved_for': res.reservedFor.toUtc().toIso8601String(),
        'check_out': res.checkOut?.toUtc().toIso8601String(),
        'notes': res.notes,
        'status': 'active',
        'business_id': ctx.businessId,
        'business_name': ctx.businessName,
        'created_by_uid': ctx.uid,
        'created_by_name': ctx.name,
        'created_by_email': ctx.email,
        'created_by_role': ctx.role,
      });
      await _sb
          .from(_kTables)
          .update({
            'status': 'reserved',
            'updated_by_uid': ctx.uid,
            'updated_by_name': ctx.name,
          })
          .eq('id', tableId);
      // FIX: _refreshAll so new reservation immediately appears in calendar
      await _refreshAll();

      final table = _tables.where((t) => t.id == tableId).firstOrNull;
      if (table != null) {
        await _notif.scheduleReservationReminders(
          table: table,
          reservation: res,
          businessName: ctx.businessName,
        );
      }
    } catch (e) {
      _error = 'Add reservation error: $e';
      notifyListeners();
    }
  }

  Future<void> updateReservation(String tableId, Reservation updated) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'customer_name': updated.customerName,
            'phone': updated.phone,
            'guest_count': updated.guestCount,
            'reserved_for': updated.reservedFor.toUtc().toIso8601String(),
            'check_out': updated.checkOut?.toUtc().toIso8601String(),
            'notes': updated.notes,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', updated.id);
      // FIX: _refreshAll so calendar shows updated date immediately
      await _refreshAll();

      final table = _tables.where((t) => t.id == tableId).firstOrNull;
      if (table != null) {
        await _notif.scheduleReservationReminders(
          table: table,
          reservation: updated,
          businessName: _userCtx?.businessName ?? '',
        );
      }
    } catch (e) {
      _error = 'Update reservation error: $e';
      notifyListeners();
    }
  }

  void cancelReservation(String tableId) {
    final t = _tables.where((t) => t.id == tableId).firstOrNull;
    if (t?.reservation != null) {
      _notif.clearReservationKeys(t!.reservation!.id);
      _notif.cancelReservationScheduled(t.reservation!.id, t.tableNumber);
    }
    _cancelAsync(tableId);
  }

  void markNoShow(String tableId) {
    final t = _tables.where((t) => t.id == tableId).firstOrNull;
    if (t?.reservation != null) {
      _notif.clearReservationKeys(t!.reservation!.id);
      _notif.cancelReservationScheduled(t.reservation!.id, t.tableNumber);
    }
    _noShowAsync(tableId);
  }

  Future<void> _noShowAsync(String tableId) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'status': 'no_show',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('table_id', tableId)
          .eq('status', 'active');
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      // FIX: _refreshAll so no-show disappears from calendar immediately
      await _refreshAll();
    } catch (e) {
      _error = 'No-show error: $e';
      notifyListeners();
    }
  }

  Future<void> _cancelAsync(String tableId) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'status': 'cancelled',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('table_id', tableId)
          .eq('status', 'active');
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      // FIX: _refreshAll so cancelled disappears from calendar immediately
      await _refreshAll();
    } catch (e) {
      _error = 'Cancel reservation error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  HISTORY
  // ══════════════════════════════════════════════════════
  void resetHistory() {
    _history.clear();
    _historyPage = 0;
    _historyHasMore = true;
    _historyFrom = _historyTo = null;
    notifyListeners();
  }

  Future<void> loadHistory({
    DateTime? from,
    DateTime? to,
    bool reset = false,
  }) async {
    if (_historyLoading) return;
    if (!_historyHasMore && !reset) return;
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;

    if (reset) {
      _history.clear();
      _historyPage = 0;
      _historyHasMore = true;
      _historyFrom = from;
      _historyTo = to;
    }
    _historyLoading = true;
    notifyListeners();

    try {
      final fromDate =
          _historyFrom ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = _historyTo ?? DateTime.now().add(const Duration(days: 60));

      final rows = await _sb
          .from(_kReservations)
          .select('*, restaurant_tables(table_number, section)')
          .eq('business_id', bId)
          .gte('reserved_for', fromDate.toUtc().toIso8601String())
          .lte('reserved_for', toDate.toUtc().toIso8601String())
          .order('reserved_for', ascending: false)
          .range(_historyPage * _pageSize, (_historyPage + 1) * _pageSize - 1);

      final items = (rows as List)
          .map((r) => ReservationHistoryItem.fromMap(r as Map<String, dynamic>))
          .toList();
      _history.addAll(items);
      _historyPage++;
      _historyHasMore = items.length == _pageSize;
    } catch (e) {
      _error = 'History error: $e';
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // FIX: refresh() now refreshes both tables AND calendar cache
  Future<void> refresh() => _refreshAll();

  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';
  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

  /// Today's reservations from cache — for TodayReservationsSheet / strip
  List<ReservationHistoryItem> get todayReservations =>
      reservationsForDate(DateTime.now());

  double get occupancyRate =>
      _tables.isEmpty ? 0 : totalOccupied / _tables.length;

  List<RestaurantTable> longOccupiedTables(int minutes) {
    final threshold = DateTime.now().subtract(Duration(minutes: minutes));
    return _tables
        .where(
          (t) =>
              t.status == TableStatus.occupied &&
              t.occupiedSince != null &&
              t.occupiedSince!.isBefore(threshold),
        )
        .toList();
  }

  /// For floor banners — uses _tables (today-only, that's fine for banners)
  List<RestaurantTable> upcomingReservations(int minutes) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(minutes: minutes));
    return _tables.where((t) {
      final r = t.reservation;
      if (r == null) return false;
      return r.reservedFor.isAfter(now) && r.reservedFor.isBefore(cutoff);
    }).toList()..sort(
      (a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor),
    );
  }

  List<RestaurantTable> get endingSoonTables =>
      _tables.where((t) => t.reservation?.isEndingSoon ?? false).toList();

  Map<TableSection, Map<String, int>> get sectionStats {
    final result = <TableSection, Map<String, int>>{};
    for (final s in TableSection.values) {
      final st = _tables.where((t) => t.section == s).toList();
      result[s] = {
        'total': st.length,
        'available': st.where((t) => t.status == TableStatus.available).length,
        'occupied': st.where((t) => t.status == TableStatus.occupied).length,
        'reserved': st.where((t) => t.status == TableStatus.reserved).length,
        'cleaning': st.where((t) => t.status == TableStatus.cleaning).length,
        'capacity': st.fold(0, (sum, t) => sum + t.capacity),
      };
    }
    return result;
  }

  bool get canManageTables =>
      _userCtx != null &&
      ['admin', 'manager', 'owner'].contains(_userCtx!.role);

  bool get canAddReservation =>
      _userCtx != null &&
      ['admin', 'manager', 'owner', 'staff'].contains(_userCtx!.role);

  String get currentUserRole => _userCtx?.role ?? 'staff';
  String get currentBusinessId => _userCtx?.businessId ?? '';
  String get currentBusinessName => _userCtx?.businessName ?? '';
}





/*import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/services/reservation_notification_service.dart';

const _kTables = 'restaurant_tables';
const _kReservations = 'table_reservations';
const _kView = 'vw_tables_with_reservation';

class _UserCtx {
  final String uid, name, role, businessId, businessName;
  final String? email;
  const _UserCtx({
    required this.uid,
    required this.name,
    this.email,
    required this.role,
    required this.businessId,
    required this.businessName,
  });
}

// ══════════════════════════════════════════════════════════════
class TablesProvider extends ChangeNotifier {
  final _sb = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final _notif = ReservationNotificationService();

  // ── State ──────────────────────────────────────────────
  TableSection? _selectedSection;
  TableStatus? _selectedStatus;
  bool _isLoading = false;
  String? _error;
  _UserCtx? _userCtx;
  final List<RestaurantTable> _tables = [];
  final List<ReservationHistoryItem> _history = [];

  bool _historyLoading = false;
  bool _historyHasMore = true;
  int _historyPage = 0;
  static const _pageSize = 20;
  DateTime? _historyFrom, _historyTo;

  Timer? _notifTimer;
  RealtimeChannel? _channel;

  TablesProvider() {
    _init();
  }

  // ── Getters ────────────────────────────────────────────
  TableSection? get selectedSection => _selectedSection;
  TableStatus? get selectedStatus => _selectedStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RestaurantTable> get allTables => List.unmodifiable(_tables);
  List<ReservationHistoryItem> get history => List.unmodifiable(_history);
  bool get historyLoading => _historyLoading;
  bool get historyHasMore => _historyHasMore;

  List<RestaurantTable> get filteredTables {
    return _tables.where((t) {
      if (_selectedSection != null && t.section != _selectedSection)
        return false;
      if (_selectedStatus != null && t.status != _selectedStatus) return false;
      return true;
    }).toList()..sort((a, b) {
      const p = {
        TableStatus.occupied: 0,
        TableStatus.reserved: 1,
        TableStatus.available: 2,
        TableStatus.cleaning: 3,
      };
      final pa = p[a.status] ?? 4, pb = p[b.status] ?? 4;
      if (pa != pb) return pa.compareTo(pb);
      return a.tableNumber.compareTo(b.tableNumber);
    });
  }

  int get totalAvailable =>
      _tables.where((t) => t.status == TableStatus.available).length;
  int get totalOccupied =>
      _tables.where((t) => t.status == TableStatus.occupied).length;
  int get totalReserved =>
      _tables.where((t) => t.status == TableStatus.reserved).length;
  int get totalTables => _tables.length;

  // ── Date-based reservation helpers ────────────────────
  List<RestaurantTable> reservationsForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _tables.where((t) {
      final r = t.reservation;
      if (r == null) return false;
      final rd = DateTime(
        r.reservedFor.year,
        r.reservedFor.month,
        r.reservedFor.day,
      );
      return rd == d;
    }).toList()..sort(
      (a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor),
    );
  }

  int get todayReservationCount => reservationsForDate(DateTime.now()).length;
  int get tomorrowReservationCount =>
      reservationsForDate(DateTime.now().add(const Duration(days: 1))).length;

  List<RestaurantTable> get longSeatedTables => longOccupiedTables(240);

  Map<TableSection, int> get availablePerSection {
    final m = <TableSection, int>{};
    for (final s in TableSection.values) {
      m[s] = _tables
          .where((t) => t.section == s && t.status == TableStatus.available)
          .length;
    }
    return m;
  }

  // ── Filters ────────────────────────────────────────────
  void setSection(TableSection? s) {
    _selectedSection = s;
    notifyListeners();
  }

  void setStatus(TableStatus? s) {
    _selectedStatus = s;
    notifyListeners();
  }

  // ── Init ───────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _notif.initialize();
      _notif.resetSentKeys();
      await _loadUserCtx();
      if (_userCtx != null) {
        await _fetchTables();
        _subscribeRealtime();
        _startNotifTimer();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('TablesProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserCtx() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _fs.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final d = doc.data()!;
    _userCtx = _UserCtx(
      uid: user.uid,
      name: d['name'] ?? 'Staff',
      email: user.email,
      role: d['role'] ?? 'staff',
      businessId: d['businessId'] ?? '',
      businessName: d['businessName'] ?? '',
    );
  }

  // ── Notification timer (long-seated — runtime only) ────
  void _startNotifTimer() {
    _notifTimer?.cancel();
    _runNotifCheck();
    _notifTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _runNotifCheck(),
    );
  }

  void _runNotifCheck() => _notif.checkAll(
    tables: _tables,
    businessName: _userCtx?.businessName ?? '',
    longSeatedMinutes: 240,
  );

  // ── Realtime ───────────────────────────────────────────
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
    _notifTimer?.cancel();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────
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
      _runNotifCheck();
    } catch (e) {
      _error = 'Fetch error: $e';
      notifyListeners();
    }
  }

  // ── Row → Model ────────────────────────────────────────
  RestaurantTable _rowToTable(Map<String, dynamic> row) {
    Reservation? reservation;
    if (row['reservation_id'] != null) {
      final reservedFor = DateTime.parse(row['res_reserved_for']).toLocal();
      final resStatus = (row['res_status'] ?? 'active') as String;
      final today = DateTime.now();
      final isToday =
          reservedFor.year == today.year &&
          reservedFor.month == today.month &&
          reservedFor.day == today.day;

      if (isToday && (resStatus == 'active' || resStatus == 'seated')) {
        reservation = Reservation(
          id: row['reservation_id'],
          customerName: row['res_customer_name'] ?? '',
          phone: row['res_phone'],
          guestCount: row['res_guest_count'] ?? 2,
          reservedFor: reservedFor,
          checkIn: row['res_check_in'] != null
              ? DateTime.parse(row['res_check_in']).toLocal()
              : null,
          checkOut: row['res_check_out'] != null
              ? DateTime.parse(row['res_check_out']).toLocal()
              : null,
          notes: row['res_notes'],
          warningSent: row['res_warning_sent'] ?? false,
          createdAt: DateTime.parse(row['res_created_at']).toLocal(),
          createdByName: row['res_created_by_name'],
          createdByRole: row['res_created_by_role'],
        );
      }
    }
    return RestaurantTable(
      id: row['id'],
      tableNumber: row['table_number'],
      capacity: row['capacity'],
      status: _parseStatus(row['status']),
      section: _parseSection(row['section']),
      shape: _parseShape(row['shape'] ?? 'square'),
      hasWindow: row['has_window'] ?? false,
      isPremium: row['is_premium'] ?? false,
      currentCustomerName: row['current_customer_name'],
      currentOrderId: row['current_order_id'],
      currentOrderTotal: row['current_order_total'] != null
          ? (row['current_order_total'] as num).toDouble()
          : null,
      occupiedSince: row['occupied_since'] != null
          ? DateTime.parse(row['occupied_since']).toLocal()
          : null,
      reservation: reservation,
    );
  }

  TableStatus _parseStatus(String s) => TableStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableStatus.available,
  );
  TableSection _parseSection(String s) => TableSection.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableSection.ac,
  );
  TableShape _parseShape(String s) => TableShape.values.firstWhere(
    (e) => e.name == s,
    orElse: () => TableShape.square,
  );

  // ── Model → Row ────────────────────────────────────────
  Map<String, dynamic> _tableToRow(RestaurantTable t, {bool isCreate = false}) {
    final ctx = _userCtx!;
    final base = <String, dynamic>{
      'table_number': t.tableNumber,
      'capacity': t.capacity,
      'section': t.section.name,
      'shape': t.shape.name,
      'has_window': t.hasWindow,
      'is_premium': t.isPremium,
      'status': t.status.name,
      'business_id': ctx.businessId,
      'business_name': ctx.businessName,
      'updated_by_uid': ctx.uid,
      'updated_by_name': ctx.name,
      'updated_by_role': ctx.role,
    };
    if (isCreate) {
      base['created_by_uid'] = ctx.uid;
      base['created_by_name'] = ctx.name;
      base['created_by_email'] = ctx.email;
      base['created_by_role'] = ctx.role;
    }
    return base;
  }

  // ══════════════════════════════════════════════════════
  //  TABLE CRUD
  // ══════════════════════════════════════════════════════
  Future<void> addTable(RestaurantTable t) async {
    _setLoading(true);
    try {
      final row = _tableToRow(t, isCreate: true)..remove('id');
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
      await _sb
          .from(_kTables)
          .update(_tableToRow(updated))
          .eq('id', updated.id);
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
      await _sb
          .from(_kTables)
          .update({
            'is_active': false,
            'updated_by_uid': _userCtx?.uid,
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

  // ══════════════════════════════════════════════════════
  //  STATUS OPS
  // ══════════════════════════════════════════════════════
  Future<void> seatGuests(String tableId, String customerName) async {
    try {
      final t = _tables.where((t) => t.id == tableId).firstOrNull;
      if (t?.reservation != null)
        _notif.clearReservationKeys(t!.reservation!.id);

      await _sb
          .from(_kTables)
          .update({
            'status': 'occupied',
            'current_customer_name': customerName,
            'occupied_since': DateTime.now().toUtc().toIso8601String(),
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _sb
          .from(_kReservations)
          .update({
            'status': 'seated',
            'check_in': DateTime.now().toUtc().toIso8601String(),
          })
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
      await _sb
          .from(_kTables)
          .update({
            'status': 'cleaning',
            'current_customer_name': null,
            'current_order_id': null,
            'current_order_total': null,
            'occupied_since': null,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Clear table error: $e';
      notifyListeners();
    }
  }

  Future<void> markAvailable(String tableId) async {
    try {
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Mark available error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  RESERVATION CRUD
  // ══════════════════════════════════════════════════════
  Future<bool> checkAvailability({
    required String tableId,
    required DateTime checkIn,
    required DateTime checkOut,
    String? excludeReservationId,
  }) async {
    try {
      final result = await _sb.rpc(
        'fn_check_table_availability',
        params: {
          'p_table_id': tableId,
          'p_check_in': checkIn.toUtc().toIso8601String(),
          'p_check_out': checkOut.toUtc().toIso8601String(),
          if (excludeReservationId != null)
            'p_exclude_id': excludeReservationId,
        },
      );
      return result == true;
    } catch (_) {
      return true;
    }
  }

  // ── Add Reservation ─────────────────────────────────────
  // After inserting, immediately schedule OS-level reminders so they fire
  // even when the app is completely closed.
  Future<void> addReservation(String tableId, Reservation res) async {
    try {
      final ctx = _userCtx!;
      await _sb.from(_kReservations).insert({
        'table_id': tableId,
        'customer_name': res.customerName,
        'phone': res.phone,
        'guest_count': res.guestCount,
        'reserved_for': res.reservedFor.toUtc().toIso8601String(),
        'check_out': res.checkOut?.toUtc().toIso8601String(),
        'notes': res.notes,
        'status': 'active',
        'business_id': ctx.businessId,
        'business_name': ctx.businessName,
        'created_by_uid': ctx.uid,
        'created_by_name': ctx.name,
        'created_by_email': ctx.email,
        'created_by_role': ctx.role,
      });
      await _sb
          .from(_kTables)
          .update({
            'status': 'reserved',
            'updated_by_uid': ctx.uid,
            'updated_by_name': ctx.name,
          })
          .eq('id', tableId);
      await _fetchTables();

      // Schedule OS-level alarms (fires even when app is killed)
      final table = _tables.where((t) => t.id == tableId).firstOrNull;
      if (table != null) {
        await _notif.scheduleReservationReminders(
          table: table,
          reservation: res,
          businessName: ctx.businessName,
        );
      }
    } catch (e) {
      _error = 'Add reservation error: $e';
      notifyListeners();
    }
  }

  // ── Update Reservation ──────────────────────────────────
  // Re-schedules OS alarms with the new times.
  Future<void> updateReservation(String tableId, Reservation updated) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'customer_name': updated.customerName,
            'phone': updated.phone,
            'guest_count': updated.guestCount,
            'reserved_for': updated.reservedFor.toUtc().toIso8601String(),
            'check_out': updated.checkOut?.toUtc().toIso8601String(),
            'notes': updated.notes,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', updated.id);
      await _fetchTables();

      // Re-schedule OS alarms with updated times
      final table = _tables.where((t) => t.id == tableId).firstOrNull;
      if (table != null) {
        await _notif.scheduleReservationReminders(
          table: table,
          reservation: updated,
          businessName: _userCtx?.businessName ?? '',
        );
      }
    } catch (e) {
      _error = 'Update reservation error: $e';
      notifyListeners();
    }
  }

  void cancelReservation(String tableId) {
    final t = _tables.where((t) => t.id == tableId).firstOrNull;
    if (t?.reservation != null) {
      _notif.clearReservationKeys(t!.reservation!.id);
      _notif.cancelReservationScheduled(t.reservation!.id, t.tableNumber);
    }
    _cancelAsync(tableId);
  }

  void markNoShow(String tableId) {
    final t = _tables.where((t) => t.id == tableId).firstOrNull;
    if (t?.reservation != null) {
      _notif.clearReservationKeys(t!.reservation!.id);
      _notif.cancelReservationScheduled(t.reservation!.id, t.tableNumber);
    }
    _noShowAsync(tableId);
  }

  Future<void> _noShowAsync(String tableId) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'status': 'no_show',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('table_id', tableId)
          .eq('status', 'active');
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'No-show error: $e';
      notifyListeners();
    }
  }

  Future<void> _cancelAsync(String tableId) async {
    try {
      await _sb
          .from(_kReservations)
          .update({
            'status': 'cancelled',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('table_id', tableId)
          .eq('status', 'active');
      await _sb
          .from(_kTables)
          .update({
            'status': 'available',
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);
      await _fetchTables();
    } catch (e) {
      _error = 'Cancel reservation error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  HISTORY
  //
  //  FIX: Default date range now includes future dates (today → +60 days)
  //  so reservations like "March 4th" are visible without custom date select.
  //  The caller can still pass custom from/to for filtering.
  // ══════════════════════════════════════════════════════
  void resetHistory() {
    _history.clear();
    _historyPage = 0;
    _historyHasMore = true;
    _historyFrom = _historyTo = null;
    notifyListeners();
  }

  Future<void> loadHistory({
    DateTime? from,
    DateTime? to,
    bool reset = false,
  }) async {
    if (_historyLoading) return;
    if (!_historyHasMore && !reset) return;
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;

    if (reset) {
      _history.clear();
      _historyPage = 0;
      _historyHasMore = true;
      _historyFrom = from;
      _historyTo = to;
    }
    _historyLoading = true;
    notifyListeners();

    try {
      // FIX: Default range is last 30 days → next 60 days so future
      // reservations (e.g. March bookings) are always included.
      final fromDate =
          _historyFrom ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = _historyTo ?? DateTime.now().add(const Duration(days: 60));

      final rows = await _sb
          .from(_kReservations)
          .select('*, restaurant_tables(table_number, section)')
          .eq('business_id', bId)
          .gte('reserved_for', fromDate.toUtc().toIso8601String())
          .lte('reserved_for', toDate.toUtc().toIso8601String())
          .order('reserved_for', ascending: false)
          .range(_historyPage * _pageSize, (_historyPage + 1) * _pageSize - 1);

      final items = (rows as List)
          .map((r) => ReservationHistoryItem.fromMap(r as Map<String, dynamic>))
          .toList();
      _history.addAll(items);
      _historyPage++;
      _historyHasMore = items.length == _pageSize;
    } catch (e) {
      _error = 'History error: $e';
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  Future<void> refresh() => _fetchTables();
  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';
  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

  List<RestaurantTable> get todayReservations =>
      reservationsForDate(DateTime.now());
  double get occupancyRate =>
      _tables.isEmpty ? 0 : totalOccupied / _tables.length;

  List<RestaurantTable> longOccupiedTables(int minutes) {
    final threshold = DateTime.now().subtract(Duration(minutes: minutes));
    return _tables
        .where(
          (t) =>
              t.status == TableStatus.occupied &&
              t.occupiedSince != null &&
              t.occupiedSince!.isBefore(threshold),
        )
        .toList();
  }

  List<RestaurantTable> upcomingReservations(int minutes) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(minutes: minutes));
    return _tables.where((t) {
      final r = t.reservation;
      if (r == null) return false;
      return r.reservedFor.isAfter(now) && r.reservedFor.isBefore(cutoff);
    }).toList()..sort(
      (a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor),
    );
  }

  List<RestaurantTable> get endingSoonTables =>
      _tables.where((t) => t.reservation?.isEndingSoon ?? false).toList();

  Map<TableSection, Map<String, int>> get sectionStats {
    final result = <TableSection, Map<String, int>>{};
    for (final s in TableSection.values) {
      final st = _tables.where((t) => t.section == s).toList();
      result[s] = {
        'total': st.length,
        'available': st.where((t) => t.status == TableStatus.available).length,
        'occupied': st.where((t) => t.status == TableStatus.occupied).length,
        'reserved': st.where((t) => t.status == TableStatus.reserved).length,
        'cleaning': st.where((t) => t.status == TableStatus.cleaning).length,
        'capacity': st.fold(0, (sum, t) => sum + t.capacity),
      };
    }
    return result;
  }

  bool get canManageTables =>
      _userCtx != null &&
      ['admin', 'manager', 'owner'].contains(_userCtx!.role);

  bool get canAddReservation =>
      _userCtx != null &&
      ['admin', 'manager', 'owner', 'staff'].contains(_userCtx!.role);

  String get currentUserRole => _userCtx?.role ?? 'staff';
  String get currentBusinessId => _userCtx?.businessId ?? '';
  String get currentBusinessName => _userCtx?.businessName ?? '';
}
*/