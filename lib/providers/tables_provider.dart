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

  // ── Calendar cache: all upcoming active/seated reservations ──
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

  /// Total active reservations across all upcoming dates (from calendar cache).
  /// Use this for the summary bar — it reflects real bookings, not just
  /// tables currently showing 'reserved' status (which is slot-windowed).
  int get totalUpcomingReservations =>
      _calendarReservations.where((r) => r.status == 'active').length;

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
  /*int get totalReserved =>
      _tables.where((t) => t.status == TableStatus.reserved).length;*/
  int get totalReserved => _calendarReservations
      .where((r) => r.status == 'active' || r.status == 'seated')
      .length;
  int get totalTables => _tables.length;

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

  int get todayReservationCount => reservationsForDate(DateTime.now()).length;
  int get tomorrowReservationCount =>
      reservationsForDate(DateTime.now().add(const Duration(days: 1))).length;

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

  Future<void> _refreshAll() async {
    await Future.wait([_fetchTables(), _fetchCalendarReservations()]);
    notifyListeners();
  }

  // ── Notification timer ─────────────────────────────────
  void _startNotifTimer() {
    _notifTimer?.cancel();
    _runPeriodicChecks();
    _notifTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _runPeriodicChecks(),
    );
  }

  // ── Runs every minute: expiry check + slot status + notifications ──────
  Future<void> _runPeriodicChecks() async {
    // 1. Auto-expire stale reservations (no check-in after slot ends)
    await _expireStaleReservations();
    // 2. Update slot-based table statuses (available ↔ reserved at 15-min window)
    await _updateSlotStatuses();
    // 3. Notification checks (long-seated, checkout warnings, walk-in warnings)
    _notif.checkAll(
      tables: _tables,
      businessName: _userCtx?.businessName ?? '',
      longSeatedMinutes: 240,
    );
  }

  // Legacy alias kept for any external callers
  void _runNotifCheck() => _notif.checkAll(
    tables: _tables,
    businessName: _userCtx?.businessName ?? '',
    longSeatedMinutes: 240,
  );

  // ── Auto-expire stale reservations via DB RPC ──────────────────────────
  // Marks 'active' reservations as 'no_show' when:
  //   - check_in IS NULL (guest never arrived)
  //   - slot end time has completely passed
  // This is the PRIMARY expiry mechanism for free-tier Supabase (no pg_cron).
  Future<void> _expireStaleReservations() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;
    try {
      final result = await _sb.rpc(
        'fn_expire_stale_reservations',
        params: {'p_business_id': bId},
      );

      final expiredCount = result?['expired_count'] as int? ?? 0;
      if (expiredCount > 0) {
        debugPrint(
          '[Expiry] ✅ Auto-expired $expiredCount stale reservation(s)',
        );

        // Send a notification for each expired reservation
        final expiredIds = (result?['expired_ids'] as List?) ?? [];
        for (final id in expiredIds) {
          await _sendExpiryNotification(id as String);
        }

        // Refresh the UI to reflect freed tables
        await _refreshAll();
      }
    } catch (e) {
      // RPC may not exist yet on older DB — fail silently
      debugPrint('[Expiry] ⚠️ fn_expire_stale_reservations error: $e');
      // Fallback: local expiry check using cached data
      await _localExpireStaleReservations();
    }
  }

  // ── Fallback local expiry (used if DB function not yet deployed) ────────
  // Reads calendar reservations already in memory — no extra DB query needed.
  Future<void> _localExpireStaleReservations() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;
    final now = DateTime.now();
    bool anyExpired = false;

    for (final res in List.of(_calendarReservations)) {
      // Skip if already seated/cancelled/completed
      if (res.status != 'active') continue;
      // Skip if guest already checked in
      if (res.checkIn != null) continue;

      // Calculate slot end time
      final slotEnd =
          res.checkOut ?? res.reservedFor.add(const Duration(hours: 2));

      // Expire if the entire slot has passed
      if (slotEnd.isBefore(now)) {
        try {
          await _sb
              .from(_kReservations)
              .update({
                'status': 'no_show',
                'updated_by_name': 'System (Auto-Expired)',
              })
              .eq('id', res.id)
              .eq('status', 'active');

          // Free the table if it's still 'reserved'
          await _sb
              .from(_kTables)
              .update({
                'status': 'available',
                'updated_by_name': 'System (Auto-Expired)',
              })
              .eq(
                'id',
                res.tableId,
              ) // NOTE: tableId is on ReservationHistoryItem
              .eq('status', 'reserved');

          debugPrint(
            '[Expiry] ✅ Local-expired reservation ${res.id} for ${res.customerName}',
          );
          anyExpired = true;

          // Send expiry notification
          await _notif.sendExpiryNotification(
            tableNumber: res.tableNumber,
            customerName: res.customerName,
            reservedFor: res.reservedFor,
            businessName: _userCtx?.businessName ?? '',
          );
        } catch (e) {
          debugPrint('[Expiry] ⚠️ Local expiry error: $e');
        }
      }
    }

    if (anyExpired) await _refreshAll();
  }

  // ── Fetch reservation details and send expiry notification ──────────────
  Future<void> _sendExpiryNotification(String reservationId) async {
    try {
      // Find in calendar cache first (faster, no extra query)
      final cached = _calendarReservations
          .where((r) => r.id == reservationId)
          .firstOrNull;

      if (cached != null) {
        await _notif.sendExpiryNotification(
          tableNumber: cached.tableNumber,
          customerName: cached.customerName,
          reservedFor: cached.reservedFor,
          businessName: _userCtx?.businessName ?? '',
        );
        return;
      }

      // Fallback: query DB for details
      final rows = await _sb
          .from(_kReservations)
          .select(
            'customer_name, reserved_for, restaurant_tables(table_number)',
          )
          .eq('id', reservationId)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        final row = rows.first as Map<String, dynamic>;
        final tableData = row['restaurant_tables'];
        await _notif.sendExpiryNotification(
          tableNumber: (tableData?['table_number'] as int?) ?? 0,
          customerName: row['customer_name'] as String? ?? 'Guest',
          reservedFor: DateTime.parse(row['reserved_for'] as String).toLocal(),
          businessName: _userCtx?.businessName ?? '',
        );
      }
    } catch (e) {
      debugPrint('[Expiry] ⚠️ Notification error: $e');
    }
  }

  // ── Update slot-based table statuses ────────────────────────────────────
  // Calls the combined DB function that handles both expiry and slot windows.
  Future<void> _updateSlotStatuses() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;
    try {
      await _sb.rpc(
        'fn_update_table_statuses_for_slots',
        params: {'p_business_id': bId},
      );
    } catch (_) {
      // Silent — local fallback in _expireStaleReservations handles it
    }
  }

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

  // ══════════════════════════════════════════════════════════════════════
  //  _rowToTable — SLOT-AWARE
  //
  //  KEY CHANGE: A reservation only affects the table UI display when it is
  //  "active right now", meaning the current time is within the reserved
  //  slot (within a 15-min buffer before the start time).
  //
  //  - If reservation starts in > 15 min  → table appears AVAILABLE
  //    (walk-ins can be seated until 15 min before the reservation)
  //  - If reservation starts in ≤ 15 min  → table appears RESERVED
  //  - If reservation is seated/ongoing   → table appears RESERVED/OCCUPIED
  //
  //  The `reservation` field is still populated so the detail sheet can
  //  show upcoming reservation info, but the TABLE STATUS on the floor
  //  grid only changes to 'reserved' when the slot is approaching.
  // ══════════════════════════════════════════════════════════════════════
  RestaurantTable _rowToTable(Map<String, dynamic> row) {
    Reservation? reservation;

    if (row['reservation_id'] != null) {
      final reservedFor = parseToIST(row['res_reserved_for'] as String);
      final resStatus = (row['res_status'] ?? 'active') as String;

      final todayIST = nowIST();
      final isToday =
          reservedFor.year == todayIST.year &&
          reservedFor.month == todayIST.month &&
          reservedFor.day == todayIST.day;

      // Show the reservation in the detail sheet if it's today
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

    // ── SLOT-AWARE STATUS OVERRIDE ────────────────────────────────────────
    // The DB status may say 'reserved' because a reservation exists, but we
    // only want to DISPLAY it as reserved when the slot is actually active
    // (i.e. within 15 min of the reservation start time).
    // Before that window, the table should appear AVAILABLE so walk-ins work.
    String rawStatus = row['status'] as String;
    TableStatus effectiveStatus = _parseStatus(rawStatus);

    if (effectiveStatus == TableStatus.reserved && reservation != null) {
      final now = nowIST();
      final minsUntilReservation = reservation.reservedFor
          .difference(now)
          .inMinutes;

      // Table only shows as RESERVED when within 15 min of reservation start
      // or if the guest has already been seated (resStatus == 'seated')
      final resStatus = (row['res_status'] ?? 'active') as String;
      if (minsUntilReservation > 15 && resStatus != 'seated') {
        // Slot is not yet active — show as available for walk-ins
        effectiveStatus = TableStatus.available;
      }
    } else if (effectiveStatus == TableStatus.reserved && reservation == null) {
      // Reserved for a different day — show as available for walk-ins today
      effectiveStatus = TableStatus.available;
    }

    return RestaurantTable(
      id: row['id'] as String,
      tableNumber: row['table_number'] as int,
      capacity: row['capacity'] as int,
      status: effectiveStatus,
      section: _parseSection(row['section'] as String),
      shape: _parseShape((row['shape'] ?? 'square') as String),
      hasWindow: row['has_window'] as bool? ?? false,
      isPremium: row['is_premium'] as bool? ?? false,
      currentCustomerName: row['current_customer_name'] as String?,
      currentOrderId: row['current_order_id'] as String?,
      currentOrderTotal: row['current_order_total'] != null
          ? (row['current_order_total'] as num).toDouble()
          : null,
      occupiedSince: row['occupied_since'] != null
          ? parseToIST(row['occupied_since'] as String)
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

  // ── SLOT-AWARE SEAT GUESTS ────────────────────────────────────────────────
  //
  // KEY CHANGE: Now uses fn_seat_guest RPC which is slot-aware.
  // The RPC only attaches today's active reservation when seating.
  //
  // For walk-ins on a table with a FUTURE reservation:
  //   - The RPC seats the guest normally (no reservation attachment)
  //   - The existing future reservation is untouched
  //   - When the walk-in session ends (clearTable), the reservation
  //     slot becomes active as normal
  //
  // Walk-in validity check: if a future reservation exists for today,
  // we warn the staff (via return value) if the walk-in might run
  // into the reserved slot. The actual overlap check is done by
  // fn_check_walkin_slot before seating.
  Future<SeatResult> seatGuests(
    String tableId,
    String customerName, {
    bool isWalkIn = false,
  }) async {
    try {
      final t = _tables.where((t) => t.id == tableId).firstOrNull;

      // ── Walk-in slot validation ───────────────────────────────────────────
      // Check if there's an upcoming reservation today that would conflict.
      // We allow the walk-in but warn about the upcoming reservation time.
      DateTime? nextReservationTime;
      if (isWalkIn) {
        nextReservationTime = await _nextReservationToday(tableId);
      }

      // Clear check-in notification keys for any existing reservation
      if (t?.reservation != null) {
        _notif.clearReservationKeys(t!.reservation!.id);
      }

      // Use fn_seat_guest RPC — slot-aware, generates session_id
      final result = await _sb.rpc(
        'fn_seat_guest',
        params: {
          'p_table_id': tableId,
          'p_customer_name': customerName,
          'p_staff_uid': _userCtx?.uid,
          'p_staff_name': _userCtx?.name,
        },
      );

      await _refreshAll();

      return SeatResult(
        success: result?['success'] == true,
        sessionId: result?['session_id'] as String?,
        reservationId: result?['reservation_id'] as String?,
        nextReservationTime: nextReservationTime,
      );
    } catch (e) {
      _error = 'Seat guests error: $e';
      notifyListeners();
      return SeatResult(success: false);
    }
  }

  // ── Check for next reservation today on a given table ───────────────────
  Future<DateTime?> _nextReservationToday(String tableId) async {
    try {
      final todayStart = DateTime.now().toUtc().toIso8601String();
      final todayEnd = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final rows = await _sb
          .from(_kReservations)
          .select('reserved_for')
          .eq('table_id', tableId)
          .eq('status', 'active')
          .gte('reserved_for', todayStart)
          .lte('reserved_for', todayEnd)
          .order('reserved_for', ascending: true)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        return parseToIST(rows.first['reserved_for'] as String);
      }
    } catch (_) {}
    return null;
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
            'session_id': null,
            'updated_by_uid': _userCtx?.uid,
            'updated_by_name': _userCtx?.name,
          })
          .eq('id', tableId);

      // After clearing, check if a reservation is starting soon
      // and restore 'reserved' status if within 15 min
      await _refreshAll();

      // Re-check and restore reserved status if needed
      await _restoreReservedIfNeeded(tableId);
    } catch (e) {
      _error = 'Clear table error: $e';
      notifyListeners();
    }
  }

  // ── After clearing a table, check if it should immediately go back ────────
  // to 'reserved' because a reservation starts within the next 15 minutes.
  Future<void> _restoreReservedIfNeeded(String tableId) async {
    try {
      final now = DateTime.now().toUtc();
      final in15 = now.add(const Duration(minutes: 15)).toIso8601String();
      final nowStr = now.toIso8601String();

      final rows = await _sb
          .from(_kReservations)
          .select('id')
          .eq('table_id', tableId)
          .eq('status', 'active')
          .gte('reserved_for', nowStr)
          .lte('reserved_for', in15)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        await _sb
            .from(_kTables)
            .update({
              'status': 'reserved',
              'updated_by_uid': _userCtx?.uid,
              'updated_by_name': _userCtx?.name,
            })
            .eq('id', tableId);
        await _fetchTables();
      }
    } catch (_) {}
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

  /// Check if a walk-in can be seated without overlapping the next reservation.
  /// Returns the latest time the walk-in should be done by (or null if no conflict).
  Future<WalkInCheckResult> checkWalkInAllowed(String tableId) async {
    try {
      final nextRes = await _nextReservationToday(tableId);
      if (nextRes == null) {
        return WalkInCheckResult(allowed: true);
      }
      final now = nowIST();
      final minsUntil = nextRes.difference(now).inMinutes;
      return WalkInCheckResult(
        allowed: minsUntil > 0,
        nextReservationTime: nextRes,
        minutesUntilReservation: minsUntil,
      );
    } catch (_) {
      return WalkInCheckResult(allowed: true);
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

      // ── SLOT-AWARE TABLE STATUS UPDATE ────────────────────────────────────
      // Only mark the table as 'reserved' if the reservation starts within
      // 15 minutes. If it's a future reservation, leave the table as-is
      // (available/occupied) so walk-ins can still use it.
      final now = nowIST();
      final minsUntil = res.reservedFor.difference(now).inMinutes;
      if (minsUntil <= 15) {
        await _sb
            .from(_kTables)
            .update({
              'status': 'reserved',
              'updated_by_uid': ctx.uid,
              'updated_by_name': ctx.name,
            })
            .eq('id', tableId);
      }
      // If minsUntil > 15, don't change the table status — it stays
      // available for walk-ins. The 1-min timer will update status
      // automatically when the 15-min window approaches.

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
    _cancelAsync(tableId, table: t);
  }

  void markNoShow(String tableId) {
    final t = _tables.where((t) => t.id == tableId).firstOrNull;
    if (t?.reservation != null) {
      _notif.clearReservationKeys(t!.reservation!.id);
      _notif.cancelReservationScheduled(t.reservation!.id, t.tableNumber);
    }
    _noShowAsync(tableId, table: t);
  }

  Future<void> _noShowAsync(String tableId, {RestaurantTable? table}) async {
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
      await _refreshAll();

      // Send no-show cancellation notification
      if (table?.reservation != null) {
        await _notif.sendCancellationNotification(
          tableNumber: table!.tableNumber,
          customerName: table.reservation!.customerName,
          reason: 'no_show',
          businessName: _userCtx?.businessName ?? '',
        );
      }
    } catch (e) {
      _error = 'No-show error: $e';
      notifyListeners();
    }
  }

  Future<void> _cancelAsync(String tableId, {RestaurantTable? table}) async {
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
      await _refreshAll();

      // Send cancellation notification
      if (table?.reservation != null) {
        await _notif.sendCancellationNotification(
          tableNumber: table!.tableNumber,
          customerName: table.reservation!.customerName,
          reason: 'cancelled',
          businessName: _userCtx?.businessName ?? '',
        );
      }
    } catch (e) {
      _error = 'Cancel reservation error: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  //  UPCOMING RESERVATION STATUS UPDATER
  //  Called every minute by the notif timer.
  //  Marks tables as 'reserved' when their slot window opens (≤15 min).
  //  This is the mechanism that auto-updates the floor grid.
  // ══════════════════════════════════════════════════════
  Future<void> _checkAndUpdateUpcomingSlots() async {
    final bId = _userCtx?.businessId;
    if (bId == null || bId.isEmpty) return;
    try {
      final now = DateTime.now().toUtc();
      final in15 = now.add(const Duration(minutes: 15)).toIso8601String();
      final nowStr = now.toIso8601String();

      // Find all active reservations starting in ≤15 min
      final rows = await _sb
          .from(_kReservations)
          .select('table_id')
          .eq('business_id', bId)
          .eq('status', 'active')
          .gte('reserved_for', nowStr)
          .lte('reserved_for', in15);

      for (final row in (rows as List)) {
        final tId = row['table_id'] as String;
        // Only update tables that are currently 'available' or 'cleaning'
        // Don't override 'occupied' — an active walk-in takes priority
        await _sb
            .from(_kTables)
            .update({
              'status': 'reserved',
              'updated_by_uid': _userCtx?.uid,
              'updated_by_name': _userCtx?.name,
            })
            .eq('id', tId)
            .inFilter('status', ['available', 'cleaning']);
      }
    } catch (_) {}
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

  Future<void> refresh() => _refreshAll();

  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';
  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

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

// ══════════════════════════════════════════════════════════════
//  RESULT TYPES
// ══════════════════════════════════════════════════════════════

/// Result of seatGuests() — contains slot conflict info for walk-ins
class SeatResult {
  final bool success;
  final String? sessionId;
  final String? reservationId;

  /// If not null, a reservation starts around this time today.
  /// Staff should ensure the walk-in finishes before this time.
  final DateTime? nextReservationTime;

  const SeatResult({
    required this.success,
    this.sessionId,
    this.reservationId,
    this.nextReservationTime,
  });

  bool get hasUpcomingReservation => nextReservationTime != null;
}

/// Result of checkWalkInAllowed()
class WalkInCheckResult {
  final bool allowed;
  final DateTime? nextReservationTime;
  final int? minutesUntilReservation;

  const WalkInCheckResult({
    required this.allowed,
    this.nextReservationTime,
    this.minutesUntilReservation,
  });
}
