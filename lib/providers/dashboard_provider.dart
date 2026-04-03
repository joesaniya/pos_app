// lib/providers/dashboard_provider.dart
//
// KEY FIXES IN THIS VERSION
// ─────────────────────────────────────────────────────────────────────────────
// 1. REVENUE / ORDERS — always filtered to the current user's own orders.
//    The RPC `fn_revenue_summary` now always receives `p_staff_uid = _uid`
//    regardless of role.  Admins/managers/owners see their own personal
//    stats in the KPI cards and chart, exactly like staff do.
//
// 2. CHART DATA — built only from the current user's own order rows.
//    The `rowsQuery` always has `.eq('created_by_uid', _uid)`.
//
// 3. TOP ITEMS — still company-wide (all completed orders for the business)
//    so every role sees the real best-sellers, not just their own slice.
//
// 4. STAFF PERFORMANCE — fetched via a SEPARATE dedicated query that pulls
//    every distinct `created_by_uid` across ALL orders for the business in
//    the selected period.  This is the only place the uid filter is NOT
//    applied, and it is only populated when `isAdminLevel == true`.
//    Previously the employee stats were derived from `rows` which was already
//    filtered to the current user → only 1 person appeared.  Now it reads
//    all company orders independently, so all staff (Jency, Lillashree,
//    Testio, …) are always present as long as they have at least one order.
//
// 5. TABLE STATS — unchanged, admin-only.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/utils/ist_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class DashboardStats {
  final double revenue;
  final double prevRevenue;
  final int ordersCount;
  final int prevOrdersCount;
  final double averageOrder;
  final int completedOrders;
  final int cancelledOrders;
  final int activeTables;
  final int totalTables;
  final int servedTablesToday;

  const DashboardStats({
    this.revenue = 0,
    this.prevRevenue = 0,
    this.ordersCount = 0,
    this.prevOrdersCount = 0,
    this.averageOrder = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.activeTables = 0,
    this.totalTables = 0,
    this.servedTablesToday = 0,
  });

  double get revenueChangePct =>
      prevRevenue > 0 ? ((revenue - prevRevenue) / prevRevenue * 100) : 0;
  double get ordersChangePct => prevOrdersCount > 0
      ? ((ordersCount - prevOrdersCount) / prevOrdersCount * 100)
      : 0;
  double get cancelRate =>
      ordersCount > 0 ? (cancelledOrders / ordersCount * 100) : 0;
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

class EmployeeStat {
  final String uid, name, role;
  final int orders, cancelledOrders;
  final double revenue;
  const EmployeeStat({
    required this.uid,
    required this.name,
    required this.role,
    required this.orders,
    required this.cancelledOrders,
    required this.revenue,
  });
}

class TopItem {
  final String name, categoryName;
  final int quantity;
  final double revenue;
  const TopItem({
    required this.name,
    required this.categoryName,
    required this.quantity,
    required this.revenue,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class DashboardProvider extends ChangeNotifier {
  String _uid = '';
  String _name = '';
  String _role = '';
  String _businessId = '';
  String _businessName = '';

  String _selectedPeriod = 'Today';
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _isLoading = false;
  // _isReady starts false. It flips to true after the very first successful
  // fetch completes. The UI shows a full skeleton until this is true.
  bool _isReady = false;
  String? _error;
  DashboardStats _stats = const DashboardStats();
  List<ChartPoint> _chartData = [];
  List<EmployeeStat> _employees = [];
  List<TopItem> _topItems = [];

  // ── Public getters ─────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;

  /// True only after the first successful data fetch. Use this to gate the
  /// real UI — show skeleton while false, real UI when true.
  bool get isReady => _isReady;
  String? get error => _error;
  String get selectedPeriod => _selectedPeriod;
  DashboardStats get stats => _stats;
  List<ChartPoint> get chartData => _chartData;
  List<EmployeeStat> get employees => _employees;
  List<TopItem> get topItems => _topItems;
  String get userName => _name;
  String get userRole => _role;
  String get businessId => _businessId;
  String get businessName => _businessName;

  /// Only admin / manager / owner see staff performance table.
  bool get isAdminLevel =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  // ══════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUserFromFirestore();
    await fetchDashboardData();
  }

  // ── Load user profile from Firestore ──────────────────────────────────────
  Future<void> _loadUserFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('📊 DashboardProvider: No Firebase user');
        return;
      }

      final storedData = await StorageService.instance.getUserData();
      final String canonicalUid =
          storedData['uid'] as String? ?? firebaseUser.uid;
      _uid = canonicalUid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (!doc.exists) {
        debugPrint('📊 DashboardProvider: No Firestore doc for uid=$_uid');
        return;
      }

      final data = doc.data()!;
      _name = data['name'] as String? ?? '';
      _role = data['role'] as String? ?? 'staff';
      _businessId = data['businessId'] as String? ?? '';
      _businessName = data['businessName'] as String? ?? '';

      debugPrint(
        '📊 DashboardProvider loaded: name=$_name role=$_role biz=$_businessId',
      );
    } catch (e) {
      debugPrint('📊 _loadUserFromFirestore ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PERIOD CONTROLS
  // ══════════════════════════════════════════════════════════

  Future<void> setSelectedPeriod(String p) async {
    _selectedPeriod = p;
    _customFrom = null;
    _customTo = null;
    notifyListeners();
    await fetchDashboardData();
  }

  Future<void> setCustomDateRange(DateTime from, DateTime to) async {
    _customFrom = from;
    _customTo = to;
    _selectedPeriod = 'Custom';
    notifyListeners();
    await fetchDashboardData();
  }

  // ══════════════════════════════════════════════════════════
  //  DATE RANGES
  // ══════════════════════════════════════════════════════════

  ({DateTime from, DateTime to}) _currentRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_customFrom != null && _customTo != null) {
      return (
        from: _customFrom!.toUtc(),
        to: _customTo!.add(const Duration(days: 1)).toUtc(),
      );
    }

    switch (_selectedPeriod) {
      case 'Yesterday':
        final y = today.subtract(const Duration(days: 1));
        return (from: y.toUtc(), to: today.toUtc());
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return (
          from: startOfWeek.toUtc(),
          to: startOfWeek.add(const Duration(days: 7)).toUtc(),
        );
      case 'This Month':
        return (
          from: DateTime(now.year, now.month, 1).toUtc(),
          to: DateTime(now.year, now.month + 1, 1).toUtc(),
        );
      default: // Today
        return (
          from: today.toUtc(),
          to: today.add(const Duration(days: 1)).toUtc(),
        );
    }
  }

  ({DateTime from, DateTime to}) _prevRange(DateTime f, DateTime t) {
    final d = t.difference(f);
    return (from: f.subtract(d), to: f);
  }

  // ══════════════════════════════════════════════════════════
  //  MAIN FETCH
  // ══════════════════════════════════════════════════════════

  Future<void> fetchDashboardData() async {
    if (_businessId.isEmpty || _uid.isEmpty) {
      debugPrint('📊 fetchDashboardData: businessId or uid empty — skip');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cur = _currentRange();
      final prev = _prevRange(cur.from, cur.to);
      final db = Supabase.instance.client;
      final fromStr = cur.from.toIso8601String();
      final toStr = cur.to.toIso8601String();
      final prevFromStr = prev.from.toIso8601String();
      final prevToStr = prev.to.toIso8601String();

      debugPrint('📊 Fetching: $fromStr → $toStr  uid=$_uid  biz=$_businessId');

      if (!ConnectivityService.instance.isOnline) {
        await _fetchOfflineData(cur.from, cur.to, prev.from, prev.to);
      } else {
        // ── 1. KPI stats — ALWAYS scoped to current user's own orders ──────────
        //    p_staff_uid is always _uid, never null, for every role.
        //    This guarantees revenue/orders shown are only what this user handled.
        final rpcCur =
            await db.rpc(
                  'fn_revenue_summary',
                  params: {
                    'p_business_id': _businessId,
                    'p_from': fromStr,
                    'p_to': toStr,
                    'p_staff_uid': _uid, // ← always own uid
                  },
                )
                as List;

        final rpcPrev =
            await db.rpc(
                  'fn_revenue_summary',
                  params: {
                    'p_business_id': _businessId,
                    'p_from': prevFromStr,
                    'p_to': prevToStr,
                    'p_staff_uid': _uid, // ← always own uid
                  },
                )
                as List;

        final cur0 = rpcCur.isNotEmpty ? rpcCur[0] as Map<String, dynamic> : {};
        final prev0 = rpcPrev.isNotEmpty
            ? rpcPrev[0] as Map<String, dynamic>
            : {};

        final revenue = (cur0['total_revenue'] as num? ?? 0).toDouble();
        final orders = (cur0['total_orders'] as num? ?? 0).toInt();
        final avgOrder = (cur0['avg_order'] as num? ?? 0).toDouble();
        final completed = (cur0['completed'] as num? ?? 0).toInt();
        final cancelled = (cur0['cancelled'] as num? ?? 0).toInt();
        final prevRev = (prev0['total_revenue'] as num? ?? 0).toDouble();
        final prevOrders = (prev0['total_orders'] as num? ?? 0).toInt();

        // Debug: Show cancellation metrics
        final cancelRatePct = orders > 0 ? ((cancelled / orders) * 100) : 0;
        debugPrint(
          '📊 My stats: revenue=$revenue orders=$orders '
          'completed=$completed cancelled=$cancelled cancelRate=${cancelRatePct.toStringAsFixed(1)}%',
        );

        // ── 2. My order rows — for chart building only ─────────────────────────
        //    Always filtered to _uid regardless of role.
        final myRows =
            await db
                    .from('orders')
                    .select(
                      'id, status, total_amount, order_type, table_id, '
                      'created_at, created_by_uid',
                    )
                    .eq('business_id', _businessId)
                    .eq('created_by_uid', _uid) // ← always own uid
                    .gte('created_at', fromStr)
                    .lt('created_at', toStr)
                as List;

        debugPrint('📊 My order rows: ${myRows.length}');

        // Build chart from my own rows only
        _buildChart(myRows, cur.to.difference(cur.from));

        // ── 3. Top items — company-wide (best-sellers for the whole business) ──
        //    All roles see the same top-sellers.  This is intentional and separate
        //    from the personal revenue numbers above.
        final allCompletedRows =
            await db
                    .from('orders')
                    .select('id')
                    .eq('business_id', _businessId)
                    .eq('status', 'completed')
                    .gte('created_at', fromStr)
                    .lt('created_at', toStr)
                as List;

        final completedIds = allCompletedRows
            .map((r) => r['id'] as String)
            .toList();
        await _buildTopItems(db, completedIds);

        // ── 4. Staff performance — admin/manager/owner only ────────────────────
        //    Uses a SEPARATE query with NO uid filter so that every staff member
        //    who handled at least one order for this business in this period is
        //    captured.  This is independent of the personal stats above.
        if (isAdminLevel) {
          await _fetchAllStaffStats(db, fromStr, toStr);
        } else {
          _employees = [];
        }

        // ── 5. Table stats — admin/manager/owner only ──────────────────────────
        int totalTables = 0, activeTables = 0, servedToday = 0;
        if (isAdminLevel) {
          try {
            final tRows =
                await db
                        .from('restaurant_tables')
                        .select('status')
                        .eq('business_id', _businessId)
                        .eq('is_active', true)
                    as List;

            totalTables = tRows.length;
            activeTables = tRows.where((r) => r['status'] == 'occupied').length;

            // Served today = distinct tables that had at least one completed
            // order today (uses all company orders, not just mine)
            final todayStart = DateTime.now().toUtc().copyWith(
              hour: 0,
              minute: 0,
              second: 0,
            );
            final completedTableRows =
                await db
                        .from('orders')
                        .select('table_id')
                        .eq('business_id', _businessId)
                        .eq('status', 'completed')
                        .not('table_id', 'is', null)
                        .gte('created_at', todayStart.toIso8601String())
                    as List;

            servedToday = completedTableRows
                .map((r) => r['table_id'] as String)
                .toSet()
                .length;
          } catch (e) {
            debugPrint('📊 Table stats error: $e');
          }
        }

        _stats = DashboardStats(
          revenue: revenue,
          prevRevenue: prevRev,
          ordersCount: orders,
          prevOrdersCount: prevOrders,
          averageOrder: avgOrder,
          completedOrders: completed,
          cancelledOrders: cancelled,
          activeTables: activeTables,
          totalTables: totalTables,
          servedTablesToday: servedToday,
        );
      } // End of online block
    } finally {
      _isLoading = false;
      _isReady = true;
      notifyListeners();
    }
  }

  // ── Offline Fallback Data Fetch ───────────────────────────────────────────
  Future<void> _fetchOfflineData(
    DateTime curFrom,
    DateTime curTo,
    DateTime prevFrom,
    DateTime prevTo,
  ) async {
    // Skip offline data fetch on web — web is always online
    if (kIsWeb) {
      _isLoading = false;
      _isReady = true;
      notifyListeners();
      return;
    }

    try {
      final local = LocalDatabase.instance;
      final rows = await local.getEntities(
        table: LocalDatabase.tOrders,
        businessId: _businessId,
        whereExtra: 'action != ?',
        whereExtraArgs: [LocalDatabase.actionDelete],
      );

      double revenue = 0, prevRev = 0, avgOrder = 0;
      int orders = 0, prevOrders = 0, completed = 0, cancelled = 0;
      List<Map<String, dynamic>> myRows = [];

      final allCompletedForTopItems = <String>[];
      final Map<String, _EmpAgg> empAgg = {};

      for (final r in rows) {
        final j = r;
        final createdBy = j['created_by_uid'] as String?;
        final status = j['status'] as String?;
        final dtRaw = j['created_at'] as String?;
        if (dtRaw == null || status == null) continue;

        final dt = parseToIST(dtRaw).toUtc();
        final amount = (j['total_amount'] as num? ?? 0).toDouble();

        // Previous Period
        if (dt.isAfter(prevFrom) && dt.isBefore(prevTo)) {
          if (createdBy == _uid) {
            prevOrders++;
            if (status == 'completed') prevRev += amount;
          }
        }

        // Current Period
        if (dt.isAfter(curFrom) && dt.isBefore(curTo)) {
          if (createdBy == _uid) {
            orders++;
            myRows.add(j);
            if (status == 'completed') {
              revenue += amount;
              completed++;
            } else if (status == 'cancelled') {
              cancelled++;
            }
          }

          // Company wide tracking
          if (status == 'completed') {
            allCompletedForTopItems.add(j['id'] as String);
          }

          if (isAdminLevel) {
            final u = createdBy ?? 'unknown';
            if (u != 'unknown' && u.isNotEmpty) {
              empAgg.putIfAbsent(
                u,
                () => _EmpAgg(
                  uid: u,
                  name: j['created_by_name'] as String? ?? 'Unknown',
                  role: j['created_by_role'] as String? ?? 'staff',
                ),
              );
              empAgg[u]!.orders++;
              if (status == 'completed') empAgg[u]!.revenue += amount;
              if (status == 'cancelled') empAgg[u]!.cancelled++;
            }
          }
        }
      }

      avgOrder = orders > 0 ? revenue / orders : 0;
      _buildChart(myRows, curTo.difference(curFrom));

      // Offline top items
      final Map<String, _ItemAgg> itemAgg = {};
      for (final r in rows) {
        if (!allCompletedForTopItems.contains(r['id'])) continue;
        final itemsList =
            r['items'] as List<dynamic>? ??
            r['order_items'] as List<dynamic>? ??
            [];
        for (final itemRaw in itemsList) {
          final ir = itemRaw as Map<String, dynamic>;
          final name = ir['item_name'] as String? ?? 'Unknown';
          itemAgg.putIfAbsent(
            name,
            () => _ItemAgg(
              name: name,
              category: ir['category_name'] as String? ?? '',
            ),
          );
          itemAgg[name]!.quantity += (ir['quantity'] as num? ?? 0).toInt();
          itemAgg[name]!.revenue += (ir['subtotal'] as num? ?? 0).toDouble();
        }
      }
      _topItems =
          (itemAgg.values.toList()
                ..sort((a, b) => b.quantity.compareTo(a.quantity)))
              .take(8)
              .map(
                (a) => TopItem(
                  name: a.name,
                  categoryName: a.category,
                  quantity: a.quantity,
                  revenue: a.revenue,
                ),
              )
              .toList();

      if (isAdminLevel) {
        final sorted = empAgg.values.toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
        _employees = sorted
            .map(
              (e) => EmployeeStat(
                uid: e.uid,
                name: e.name,
                role: e.role,
                orders: e.orders,
                cancelledOrders: e.cancelled,
                revenue: e.revenue,
              ),
            )
            .toList();
      } else {
        _employees = [];
      }

      int totalTables = 0, activeTables = 0, servedToday = 0;
      if (isAdminLevel) {
        final tRows = await local.getEntities(
          table: LocalDatabase.tTables,
          businessId: _businessId,
        );
        totalTables = tRows.length;
        activeTables = tRows.where((r) => r['status'] == 'occupied').length;
        final todayStart = DateTime.now().toUtc().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
        );
        servedToday = rows
            .where(
              (r) =>
                  r['status'] == 'completed' &&
                  r['table_id'] != null &&
                  parseToIST(
                    r['created_at'] as String,
                  ).toUtc().isAfter(todayStart),
            )
            .map((r) => r['table_id'] as String)
            .toSet()
            .length;
      }

      _stats = DashboardStats(
        revenue: revenue,
        prevRevenue: prevRev,
        ordersCount: orders,
        prevOrdersCount: prevOrders,
        averageOrder: avgOrder,
        completedOrders: completed,
        cancelledOrders: cancelled,
        activeTables: activeTables,
        totalTables: totalTables,
        servedTablesToday: servedToday,
      );
    } catch (e) {
      debugPrint('📊 Offline fetch error: $e');
    }
  }

  // ── 4a. Fetch ALL staff stats for the business ─────────────────────────────
  //
  // Root cause of the "only 2 staff shown" bug:
  // Previously _buildEmployeeStats() was called on `rows` which was already
  // filtered with .eq('created_by_uid', _uid) so it only ever contained the
  // current user's orders → only 1 employee appeared, or at best however
  // many orders were in that already-filtered list.
  //
  // Now we do a fresh dedicated query with NO uid filter, pulling all orders
  // for the business in the period.  Every distinct created_by_uid becomes a
  // row in the staff table.
  Future<void> _fetchAllStaffStats(
    dynamic db,
    String fromStr,
    String toStr,
  ) async {
    try {
      // Pull all order rows for the company — no uid filter here
      final allRows =
          await db
                  .from('orders')
                  .select(
                    'status, total_amount, created_by_uid, '
                    'created_by_name, created_by_role',
                  )
                  .eq('business_id', _businessId)
                  .gte('created_at', fromStr)
                  .lt('created_at', toStr)
              as List;

      debugPrint(
        '📊 All company order rows for staff stats: ${allRows.length}',
      );

      final Map<String, _EmpAgg> agg = {};

      for (final r in allRows) {
        final uid = r['created_by_uid'] as String? ?? 'unknown';
        // Skip rows where uid could not be determined
        if (uid == 'unknown' || uid.isEmpty) continue;

        final name = r['created_by_name'] as String? ?? 'Unknown';
        final role = r['created_by_role'] as String? ?? 'staff';

        agg.putIfAbsent(uid, () => _EmpAgg(uid: uid, name: name, role: role));

        agg[uid]!.orders++;

        if (r['status'] == 'completed') {
          agg[uid]!.revenue += (r['total_amount'] as num? ?? 0).toDouble();
        }
        if (r['status'] == 'cancelled') {
          agg[uid]!.cancelled++;
        }
      }

      // Sort by revenue descending so top performer appears first
      final sorted = agg.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      _employees = sorted
          .map(
            (e) => EmployeeStat(
              uid: e.uid,
              name: e.name,
              role: e.role,
              orders: e.orders,
              cancelledOrders: e.cancelled,
              revenue: e.revenue,
            ),
          )
          .toList();

      debugPrint(
        '📊 Staff performance rows built: ${_employees.length} '
        '(${_employees.map((e) => e.name).join(', ')})',
      );
    } catch (e) {
      debugPrint('📊 _fetchAllStaffStats ERROR: $e');
      _employees = [];
    }
  }

  // ── Chart builder — only called with current user's own rows ──────────────
  void _buildChart(List rows, Duration rangeDur) {
    final Map<String, double> grouped = {};

    for (final r in rows) {
      if (r['status'] != 'completed') continue;

      DateTime dt;
      try {
        dt = DateTime.parse(r['created_at'] as String).toLocal();
      } catch (_) {
        continue;
      }

      String key;
      if (rangeDur.inDays <= 1) {
        key = '${dt.hour.toString().padLeft(2, '0')}:00';
      } else if (rangeDur.inDays <= 31) {
        key = '${dt.month}/${dt.day}';
      } else {
        const m = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        key = m[dt.month - 1];
      }

      grouped[key] =
          (grouped[key] ?? 0) + (r['total_amount'] as num? ?? 0).toDouble();
    }

    final entries = grouped.entries.toList();
    if (rangeDur.inDays <= 1) {
      entries.sort((a, b) {
        final ah = int.tryParse(a.key.split(':')[0]) ?? 0;
        final bh = int.tryParse(b.key.split(':')[0]) ?? 0;
        return ah.compareTo(bh);
      });
    }

    _chartData = entries.map((e) => ChartPoint(e.key, e.value)).toList();
  }

  // ── Top items builder ──────────────────────────────────────────────────────
  Future<void> _buildTopItems(dynamic db, List<String> orderIds) async {
    if (orderIds.isEmpty) {
      _topItems = [];
      return;
    }
    try {
      final Map<String, _ItemAgg> agg = {};
      for (int i = 0; i < orderIds.length; i += 100) {
        final chunk = orderIds.sublist(i, (i + 100).clamp(0, orderIds.length));
        final rows =
            await db
                    .from('order_items')
                    .select('item_name, category_name, quantity, subtotal')
                    .inFilter('order_id', chunk)
                as List;

        for (final r in rows) {
          final name = r['item_name'] as String? ?? 'Unknown';
          agg.putIfAbsent(
            name,
            () => _ItemAgg(
              name: name,
              category: r['category_name'] as String? ?? '',
            ),
          );
          agg[name]!.quantity += (r['quantity'] as num? ?? 0).toInt();
          agg[name]!.revenue += (r['subtotal'] as num? ?? 0).toDouble();
        }
      }

      _topItems =
          (agg.values.toList()
                ..sort((a, b) => b.quantity.compareTo(a.quantity)))
              .take(8)
              .map(
                (a) => TopItem(
                  name: a.name,
                  categoryName: a.category,
                  quantity: a.quantity,
                  revenue: a.revenue,
                ),
              )
              .toList();
    } catch (e) {
      debugPrint('📊 topItems error: $e');
      _topItems = [];
    }
  }

  Future<void> refresh() => fetchDashboardData();
}

// ─────────────────────────────────────────────────────────────────────────────
//  INTERNAL AGGREGATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _ItemAgg {
  final String name, category;
  int quantity = 0;
  double revenue = 0;
  _ItemAgg({required this.name, required this.category});
}

class _EmpAgg {
  final String uid, name, role;
  int orders = 0, cancelled = 0;
  double revenue = 0;
  _EmpAgg({required this.uid, required this.name, required this.role});
}
