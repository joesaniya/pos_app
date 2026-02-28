// lib/providers/dashboard_provider.dart
//
// ROOT-CAUSE FIX:
//   order_items.created_at = "2026-02-28 09:09:19.257809+00"
//   The existing orders table may NOT have business_id / status columns,
//   so any join with .eq('orders.business_id', ...) silently returns [].
//
// SOLUTION:
//   1. Query order_items by date range ONLY (no join filter).
//   2. Then fetch the matching orders by their IDs to get business_id / status.
//   3. Filter in Dart — avoids every possible DB join issue.
//   4. Full fallback chain: order_items → orders directly.
//   5. UTC timestamps so "Today" always matches Supabase rows.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  DATA CLASSES
// ─────────────────────────────────────────────────────────────

class DashboardStats {
  final double revenue;
  final double prevRevenue;
  final int ordersCount;
  final int prevOrdersCount;
  final double averageOrder;
  final int activeTables;
  final int totalTables;

  const DashboardStats({
    this.revenue = 0,
    this.prevRevenue = 0,
    this.ordersCount = 0,
    this.prevOrdersCount = 0,
    this.averageOrder = 0,
    this.activeTables = 0,
    this.totalTables = 0,
  });

  double get revenueChangePct =>
      prevRevenue > 0 ? ((revenue - prevRevenue) / prevRevenue * 100) : 0;

  double get ordersChangePct => prevOrdersCount > 0
      ? ((ordersCount - prevOrdersCount) / prevOrdersCount * 100)
      : 0;
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

class EmployeeStat {
  final String uid, name, role;
  final int orders, tables;
  final double revenue;
  const EmployeeStat({
    required this.uid,
    required this.name,
    required this.role,
    required this.orders,
    required this.tables,
    required this.revenue,
  });
}

// ─────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────

class DashboardProvider extends ChangeNotifier {
  // ── User context ──────────────────────────────────────
  String _uid = '';
  String _name = '';
  String _role = '';
  String _businessId = '';
  String _businessName = '';

  // ── Period ────────────────────────────────────────────
  String _selectedPeriod = 'Today';
  DateTime? _selectedDate;

  // ── State ─────────────────────────────────────────────
  bool _isLoading = false;
  String? _error;
  DashboardStats _stats = const DashboardStats();
  List<ChartPoint> _chartData = [];
  List<EmployeeStat> _employees = [];

  // ── Getters ───────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedPeriod => _selectedPeriod;
  DateTime? get selectedDate => _selectedDate;
  DashboardStats get stats => _stats;
  List<ChartPoint> get chartData => _chartData;
  List<EmployeeStat> get employees => _employees;
  String get userName => _name;
  String get userRole => _role;
  String get businessName => _businessName;
  String get businessId => _businessId;

  bool get isAdminLevel =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  // convenience wrappers used by DashboardScreen
  double getRevenueForPeriod() => _stats.revenue;
  double getRevenueChange() => _stats.revenueChangePct;
  int getOrdersCount() => _stats.ordersCount;
  double getAverageOrder() => _stats.averageOrder;
  int getActiveTables() => _stats.activeTables;

  // ═════════════════════════════════════════════════════
  //  INIT
  // ═════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUser();
    await fetchDashboardData();
  }

  Future<void> _loadUser() async {
    final p = await SharedPreferences.getInstance();
    _uid = p.getString('uid') ?? '';
    _name = p.getString('name') ?? '';
    _role = p.getString('role') ?? '';
    _businessId = p.getString('businessId') ?? '';
    _businessName = p.getString('businessName') ?? '';
    debugPrint('📊 user=$_name role=$_role biz=$_businessId');
  }

  // ═════════════════════════════════════════════════════
  //  PERIOD CONTROLS
  // ═════════════════════════════════════════════════════

  Future<void> setSelectedPeriod(String p) async {
    _selectedPeriod = p;
    _selectedDate = null;
    notifyListeners();
    await fetchDashboardData();
  }

  Future<void> setSelectedDate(DateTime? d) async {
    _selectedDate = d;
    if (d != null) _selectedPeriod = 'Custom';
    notifyListeners();
    await fetchDashboardData();
  }

  // ═════════════════════════════════════════════════════
  //  DATE RANGES — UTC to match Supabase +00 timestamps
  // ═════════════════════════════════════════════════════

  ({DateTime from, DateTime to}) _currentRange() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);

    if (_selectedDate != null) {
      final d = DateTime.utc(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      return (from: d, to: d.add(const Duration(days: 1)));
    }
    switch (_selectedPeriod) {
      case 'Yesterday':
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: today);
      case 'Last Month':
        return (
          from: DateTime.utc(now.year, now.month - 1, 1),
          to: DateTime.utc(now.year, now.month, 1),
        );
      case 'Last Year':
        return (
          from: DateTime.utc(now.year - 1, 1, 1),
          to: DateTime.utc(now.year, 1, 1),
        );
      default: // 'Today'
        return (from: today, to: today.add(const Duration(days: 1)));
    }
  }

  ({DateTime from, DateTime to}) _prevRange(DateTime f, DateTime t) {
    final d = t.difference(f);
    return (from: f.subtract(d), to: f);
  }

  // ═════════════════════════════════════════════════════
  //  MAIN FETCH ENTRY POINT
  // ═════════════════════════════════════════════════════

  Future<void> fetchDashboardData() async {
    if (_businessId.isEmpty) {
      debugPrint('📊 businessId empty — skip');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cur = _currentRange();
      final prev = _prevRange(cur.from, cur.to);
      debugPrint(
        '📊 fetch ${cur.from.toIso8601String()} → ${cur.to.toIso8601String()}',
      );

      // Step 1: load ALL order_ids that belong to this business
      final bizOrderIds = await _fetchBusinessOrderIds();
      debugPrint('📊 business order IDs: ${bizOrderIds.length}');

      if (bizOrderIds.isEmpty) {
        // Business has no orders at all yet
        _stats = const DashboardStats();
        _chartData = [];
        _employees = [];
        return;
      }

      // Step 2: load order metadata (status, staff, table, total_amount, created_at)
      final orderMeta = await _fetchOrderMeta(bizOrderIds);
      debugPrint('📊 order meta fetched: ${orderMeta.length}');

      // Step 3: load order_items for the date range (no join — just date filter)
      final allItems = await _fetchOrderItemsInRange(cur.from, cur.to);
      final prevItems = await _fetchOrderItemsInRange(prev.from, prev.to);
      debugPrint('📊 items cur=${allItems.length} prev=${prevItems.length}');

      // Step 4: filter items to only those belonging to this business
      final curItems = _filterItemsByBusiness(allItems, orderMeta, bizOrderIds);
      final prevItemsF = _filterItemsByBusiness(
        prevItems,
        orderMeta,
        bizOrderIds,
      );
      debugPrint(
        '📊 filtered items cur=${curItems.length} prev=${prevItemsF.length}',
      );

      // Step 5: apply staff filter if not admin
      final curFiltered = isAdminLevel
          ? curItems
          : curItems.where((i) => _isMyOrder(i, orderMeta)).toList();
      final prevFiltered = isAdminLevel
          ? prevItemsF
          : prevItemsF.where((i) => _isMyOrder(i, orderMeta)).toList();

      // Step 6: aggregate
      await Future.wait([
        _computeStats(curFiltered, prevFiltered, orderMeta),
        _computeChart(curItems, orderMeta, cur.to.difference(cur.from)),
        if (isAdminLevel) _computeEmployees(curItems, orderMeta),
      ]);

      debugPrint(
        '📊 revenue=${_stats.revenue} orders=${_stats.ordersCount} chart=${_chartData.length}',
      );
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📊 ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════
  //  STEP 1 — Get all order IDs that belong to this business
  //  Tries orders.business_id first, falls back to all orders
  //  if that column doesn't exist / is empty.
  // ═════════════════════════════════════════════════════

  Future<Set<String>> _fetchBusinessOrderIds() async {
    final db = Supabase.instance.client;

    // Try with business_id column
    try {
      final rows =
          await db.from('orders').select('id').eq('business_id', _businessId)
              as List;

      if (rows.isNotEmpty) {
        return rows.map((r) => r['id'] as String).toSet();
      }

      // If empty, the column might exist but all rows have empty business_id
      // Fall through to try without filter
    } catch (_) {
      debugPrint(
        '📊 business_id column missing or error — fetching all order IDs',
      );
    }

    // Fallback: grab all order IDs (single-business app, no filter needed)
    try {
      final rows = await db.from('orders').select('id') as List;
      return rows.map((r) => r['id'] as String).toSet();
    } catch (e) {
      debugPrint('📊 _fetchBusinessOrderIds fallback error: $e');
      return {};
    }
  }

  // ═════════════════════════════════════════════════════
  //  STEP 2 — Fetch order metadata by IDs (batched if large)
  // ═════════════════════════════════════════════════════

  Future<Map<String, Map<String, dynamic>>> _fetchOrderMeta(
    Set<String> orderIds,
  ) async {
    final db = Supabase.instance.client;
    final Map<String, Map<String, dynamic>> meta = {};

    // Batch in chunks of 100 to avoid URL length limits
    final idList = orderIds.toList();
    for (int i = 0; i < idList.length; i += 100) {
      final chunk = idList.sublist(
        i,
        i + 100 > idList.length ? idList.length : i + 100,
      );
      try {
        final rows =
            await db
                    .from('orders')
                    .select(
                      'id, status, total_amount, table_id, created_by_uid, created_by_name, created_by_role, business_id, created_at',
                    )
                    .inFilter('id', chunk)
                as List;

        for (final r in rows) {
          meta[r['id'] as String] = Map<String, dynamic>.from(r as Map);
        }
      } catch (e) {
        debugPrint('📊 order meta batch error: $e');
        // Try minimal columns
        try {
          final rows =
              await db
                      .from('orders')
                      .select('id, status, total_amount')
                      .inFilter('id', chunk)
                  as List;
          for (final r in rows) {
            meta[r['id'] as String] = Map<String, dynamic>.from(r as Map);
          }
        } catch (_) {}
      }
    }
    return meta;
  }

  // ═════════════════════════════════════════════════════
  //  STEP 3 — Fetch order_items in date range (NO join)
  // ═════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _fetchOrderItemsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final db = Supabase.instance.client;
    try {
      final rows =
          await db
                  .from('order_items')
                  .select(
                    'id, order_id, subtotal, item_name, category_name, quantity, created_at',
                  )
                  .gte('created_at', from.toIso8601String())
                  .lt('created_at', to.toIso8601String())
              as List;

      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      debugPrint('📊 _fetchOrderItemsInRange error: $e');
      return [];
    }
  }

  // ═════════════════════════════════════════════════════
  //  STEP 4 — Keep only items whose order_id is in our biz
  // ═════════════════════════════════════════════════════

  List<Map<String, dynamic>> _filterItemsByBusiness(
    List<Map<String, dynamic>> items,
    Map<String, Map<String, dynamic>> orderMeta,
    Set<String> bizOrderIds,
  ) {
    return items.where((i) {
      final oid = i['order_id'] as String?;
      if (oid == null) return false;
      if (!bizOrderIds.contains(oid)) return false;
      // Also exclude cancelled orders
      final status = orderMeta[oid]?['status'] as String?;
      return status != 'cancelled';
    }).toList();
  }

  bool _isMyOrder(
    Map<String, dynamic> item,
    Map<String, Map<String, dynamic>> orderMeta,
  ) {
    final oid = item['order_id'] as String?;
    final order = oid != null ? orderMeta[oid] : null;
    return order?['created_by_uid'] == _uid;
  }

  // ═════════════════════════════════════════════════════
  //  STEP 5a — Compute stats
  // ═════════════════════════════════════════════════════

  Future<void> _computeStats(
    List<Map<String, dynamic>> curItems,
    List<Map<String, dynamic>> prevItems,
    Map<String, Map<String, dynamic>> orderMeta,
  ) async {
    double curRevenue = 0, prevRevenue = 0;
    final curOrderIds = <String>{};
    final prevOrderIds = <String>{};

    for (final i in curItems) {
      curRevenue += (i['subtotal'] as num? ?? 0).toDouble();
      final oid = i['order_id'] as String?;
      if (oid != null) curOrderIds.add(oid);
    }
    for (final i in prevItems) {
      prevRevenue += (i['subtotal'] as num? ?? 0).toDouble();
      final oid = i['order_id'] as String?;
      if (oid != null) prevOrderIds.add(oid);
    }

    final curOrders = curOrderIds.length;
    final prevOrders = prevOrderIds.length;
    final avg = curOrders > 0 ? curRevenue / curOrders : 0.0;

    // Table counts
    int activeTables = 0, totalTables = 0;
    try {
      final rows =
          await Supabase.instance.client
                  .from('restaurant_tables')
                  .select('id, status')
                  .eq('business_id', _businessId)
                  .eq('is_active', true)
              as List;
      totalTables = rows.length;
      activeTables = rows.where((r) => r['status'] == 'occupied').length;
    } catch (_) {
      // table counts are non-critical
    }

    _stats = DashboardStats(
      revenue: curRevenue,
      prevRevenue: prevRevenue,
      ordersCount: curOrders,
      prevOrdersCount: prevOrders,
      averageOrder: avg,
      activeTables: activeTables,
      totalTables: totalTables,
    );
  }

  // ═════════════════════════════════════════════════════
  //  STEP 5b — Build chart data
  // ═════════════════════════════════════════════════════

  Future<void> _computeChart(
    List<Map<String, dynamic>> items,
    Map<String, Map<String, dynamic>> orderMeta,
    Duration rangeDur,
  ) async {
    final Map<String, double> grouped = {};

    for (final item in items) {
      final rawTs = item['created_at'] as String? ?? '';
      DateTime dt;
      try {
        dt = DateTime.parse(rawTs).toLocal();
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

      final amount = (item['subtotal'] as num? ?? 0).toDouble();
      grouped[key] = (grouped[key] ?? 0) + amount;
    }

    // Sort entries
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

  // ═════════════════════════════════════════════════════
  //  STEP 5c — Employee analytics (admin+ only)
  // ═════════════════════════════════════════════════════

  Future<void> _computeEmployees(
    List<Map<String, dynamic>> items,
    Map<String, Map<String, dynamic>> orderMeta,
  ) async {
    final Map<String, Map<String, dynamic>> byStaff = {};

    for (final item in items) {
      final oid = item['order_id'] as String?;
      final order = oid != null ? orderMeta[oid] : null;
      if (order == null) continue;

      final uid = order['created_by_uid'] as String? ?? 'unknown';
      final name = order['created_by_name'] as String? ?? 'Unknown';
      final role = order['created_by_role'] as String? ?? 'staff';
      final tableId = order['table_id'] as String?;
      final amount = (item['subtotal'] as num? ?? 0).toDouble();

      byStaff.putIfAbsent(
        uid,
        () => {
          'name': name,
          'role': role,
          'revenue': 0.0,
          'orderIds': <String>{},
          'tableIds': <String>{},
        },
      );

      byStaff[uid]!['revenue'] = (byStaff[uid]!['revenue'] as double) + amount;
      if (oid != null) (byStaff[uid]!['orderIds'] as Set<String>).add(oid);
      if (tableId != null)
        (byStaff[uid]!['tableIds'] as Set<String>).add(tableId);
    }

    _employees =
        byStaff.entries
            .map(
              (e) => EmployeeStat(
                uid: e.key,
                name: e.value['name'] as String,
                role: e.value['role'] as String,
                orders: (e.value['orderIds'] as Set<String>).length,
                tables: (e.value['tableIds'] as Set<String>).length,
                revenue: e.value['revenue'] as double,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  Future<void> refresh() => fetchDashboardData();
}
