// lib/providers/dashboard_provider.dart
// ROOT FIX: User profile loaded from Firebase Firestore (not SharedPreferences)
// so businessId is always correct when querying Supabase.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _error;
  DashboardStats _stats = const DashboardStats();
  List<ChartPoint> _chartData = [];
  List<EmployeeStat> _employees = [];
  List<TopItem> _topItems = [];

  bool get isLoading => _isLoading;
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

  bool get isAdminLevel =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  // ══════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUserFromFirestore();
    await fetchDashboardData();
  }

  // ── Load user from Firebase Firestore ────────────────────────────────────
  Future<void> _loadUserFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('📊 DashboardProvider: No Firebase user');
        return;
      }

      _uid = firebaseUser.uid;

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
        '📊 DashboardProvider loaded: name=$_name role=$_role '
        'biz=$_businessId',
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
  //  MAIN FETCH — uses fn_revenue_summary RPC for efficiency
  // ══════════════════════════════════════════════════════════

  Future<void> fetchDashboardData() async {
    if (_businessId.isEmpty) {
      debugPrint('📊 fetchDashboardData: businessId empty — skip');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cur = _currentRange();
      final prev = _prevRange(cur.from, cur.to);
      final db = Supabase.instance.client;

      debugPrint('📊 Fetching: ${cur.from} → ${cur.to} biz=$_businessId');

      // ── Current period stats via RPC ─────────────────────────────────────
      final rpcCur =
          await db.rpc(
                'fn_revenue_summary',
                params: {
                  'p_business_id': _businessId,
                  'p_from': cur.from.toIso8601String(),
                  'p_to': cur.to.toIso8601String(),
                  'p_staff_uid': isAdminLevel ? null : _uid,
                },
              )
              as List;

      final rpcPrev =
          await db.rpc(
                'fn_revenue_summary',
                params: {
                  'p_business_id': _businessId,
                  'p_from': prev.from.toIso8601String(),
                  'p_to': prev.to.toIso8601String(),
                  'p_staff_uid': isAdminLevel ? null : _uid,
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

      debugPrint(
        '📊 RPC result: revenue=$revenue orders=$orders '
        'completed=$completed cancelled=$cancelled',
      );

      // ── Full order rows for chart + employee stats ────────────────────────
      var rowsQuery = db
          .from('orders')
          .select(
            'id, status, total_amount, order_type, table_id, '
            'created_at, created_by_uid, created_by_name, created_by_role',
          )
          .eq('business_id', _businessId)
          .gte('created_at', cur.from.toIso8601String())
          .lt('created_at', cur.to.toIso8601String());

      if (!isAdminLevel) {
        rowsQuery = rowsQuery.eq('created_by_uid', _uid);
      }

      final rows = await rowsQuery as List;

      _buildChart(rows, cur.to.difference(cur.from));
      if (isAdminLevel) _buildEmployeeStats(rows);

      // ── Top items — ALWAYS company-wide, never filtered by staff uid ────────
      // Every role (staff/manager/owner) sees the same top sellers for the
      // business, not just items from their own orders.
      final allCompletedRows =
          await db
                  .from('orders')
                  .select('id')
                  .eq('business_id', _businessId)
                  .eq('status', 'completed')
                  .gte('created_at', cur.from.toIso8601String())
                  .lt('created_at', cur.to.toIso8601String())
              as List;

      final completedIds = allCompletedRows
          .map((r) => r['id'] as String)
          .toList();
      await _buildTopItems(db, completedIds);

      // ── Table stats ───────────────────────────────────────────────────────
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
          servedToday = rows
              .where((r) => r['status'] == 'completed' && r['table_id'] != null)
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
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📊 fetchDashboardData ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Chart ──────────────────────────────────────────────────────────────────
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

  // ── Top items ──────────────────────────────────────────────────────────────
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

  // ── Employee stats ─────────────────────────────────────────────────────────
  void _buildEmployeeStats(List rows) {
    final Map<String, _EmpAgg> agg = {};
    for (final r in rows) {
      final uid = r['created_by_uid'] as String? ?? 'unknown';
      final name = r['created_by_name'] as String? ?? 'Unknown';
      final role = r['created_by_role'] as String? ?? 'staff';
      agg.putIfAbsent(uid, () => _EmpAgg(uid: uid, name: name, role: role));
      agg[uid]!.orders++;
      if (r['status'] == 'completed') {
        agg[uid]!.revenue += (r['total_amount'] as num? ?? 0).toDouble();
      }
      if (r['status'] == 'cancelled') agg[uid]!.cancelled++;
    }
    _employees =
        (agg.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue)))
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
  }

  Future<void> refresh() => fetchDashboardData();
}

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
