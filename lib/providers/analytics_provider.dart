// lib/providers/analytics_provider.dart
//
// Revenue Analytics Provider
// ─────────────────────────────────────────────────────────────────────────────
// Fetches real order data from Supabase for Weekly / Monthly / Yearly views.
// All metrics are computed from actual order records for the signed-in user's
// business (company-wide, not filtered to one staff member — this is the
// analytics view that admin/manager/owner/system use).
//
// ACCESS GATE: Only populated for roles: admin, system, owner, manager.
// For any other role the provider stays empty and the widget should be hidden.
//
// METRICS per period:
//   • Total Revenue     — sum of total_amount for completed orders
//   • Average Revenue   — total revenue ÷ number of data-points (days/months)
//   • Highest Revenue   — max revenue in a single data-point bucket
//   • Growth Rate       — (current period total − previous period total)
//                          ÷ previous period total × 100
//   • Order Count       — total orders (all statuses) in the period
//
// CHART DATA:
//   Weekly  → 7 buckets (Mon–Sun of current week), each = day's revenue
//   Monthly → days 1–N of current month, each = day's revenue
//   Yearly  → 12 buckets (Jan–Dec of current year), each = month's revenue
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/utils/ist_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsChartPoint {
  final String label; // e.g. "Mon", "01", "Jan"
  final double revenue; // total revenue for this bucket (INR)
  final int orders; // order count for this bucket
  const AnalyticsChartPoint({
    required this.label,
    required this.revenue,
    required this.orders,
  });
}

class AnalyticsPeriodStats {
  final double totalRevenue;
  final double averageRevenue; // avg across buckets that have data
  final double highestRevenue; // max single-bucket revenue
  final double growthRate; // % vs previous equivalent period
  final int orderCount;
  final List<AnalyticsChartPoint> chartPoints;

  const AnalyticsPeriodStats({
    this.totalRevenue = 0,
    this.averageRevenue = 0,
    this.highestRevenue = 0,
    this.growthRate = 0,
    this.orderCount = 0,
    this.chartPoints = const [],
  });

  bool get isEmpty => orderCount == 0 && totalRevenue == 0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsProvider extends ChangeNotifier {
  // ── User / business context ──────────────────────────────────────────────
  String _uid = '';
  String _role = '';
  String _businessId = '';

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _error;
  String _selectedPeriod = 'Weekly'; // Weekly | Monthly | Yearly

  AnalyticsPeriodStats _weeklyStats = const AnalyticsPeriodStats();
  AnalyticsPeriodStats _monthlyStats = const AnalyticsPeriodStats();
  AnalyticsPeriodStats _yearlyStats = const AnalyticsPeriodStats();

  // ── Public getters ───────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedPeriod => _selectedPeriod;
  String get userRole => _role;

  /// Only admin / system / owner / manager may see analytics.
  bool get hasAccess =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  AnalyticsPeriodStats get weeklyStats => _weeklyStats;
  AnalyticsPeriodStats get monthlyStats => _monthlyStats;
  AnalyticsPeriodStats get yearlyStats => _yearlyStats;

  /// Returns the stats for whichever period is currently selected.
  AnalyticsPeriodStats get currentStats {
    switch (_selectedPeriod) {
      case 'Monthly':
        return _monthlyStats;
      case 'Yearly':
        return _yearlyStats;
      default:
        return _weeklyStats;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUser();
    if (hasAccess) await fetchAll();
  }

  Future<void> _loadUser() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) return;
      final storedData = await StorageService.instance.getUserData();
      final String canonicalUid = storedData['uid'] as String? ?? fbUser.uid;
      _uid = canonicalUid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (!doc.exists) return;

      final d = doc.data()!;
      _role = d['role'] as String? ?? 'staff';
      _businessId = d['businessId'] as String? ?? '';

      debugPrint('📈 AnalyticsProvider: role=$_role biz=$_businessId');
    } catch (e) {
      debugPrint('📈 _loadUser ERROR: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERIOD SWITCH
  // ══════════════════════════════════════════════════════════════════════════

  /// Call this when the user taps Weekly / Monthly / Yearly.
  /// Already-fetched data is returned instantly; stale data is re-fetched
  /// only if it was never loaded.
  Future<void> setPeriod(String period) async {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    notifyListeners();

    // Re-fetch only the selected period if it hasn't been loaded yet
    final needs = switch (period) {
      'Monthly' => _monthlyStats.chartPoints.isEmpty,
      'Yearly' => _yearlyStats.chartPoints.isEmpty,
      _ => _weeklyStats.chartPoints.isEmpty,
    };

    if (needs) {
      _isLoading = true;
      notifyListeners();
      await _fetchPeriod(period);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH ALL THREE PERIODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchAll() async {
    if (!hasAccess || _businessId.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch all three in parallel
      await Future.wait([
        _fetchPeriod('Weekly'),
        _fetchPeriod('Monthly'),
        _fetchPeriod('Yearly'),
      ]);
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📈 fetchAll ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => fetchAll();

  // ══════════════════════════════════════════════════════════════════════════
  //  CORE FETCH LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchPeriod(String period) async {
    try {
      final db = Supabase.instance.client;
      // CRITICAL: Always use .toLocal() to ensure correct device timezone
      final nowLocal = DateTime.now().toLocal();

      // ── Date ranges (calculated in LOCAL timezone, then convert to UTC) ────
      final DateTime curFrom, curTo, prevFrom, prevTo;

      switch (period) {
        case 'Monthly':
          // Current month: 1st of this month (00:00 local) → 1st of next month (00:00 local)
          // NOTE: DateTime() constructor creates in LOCAL timezone, don't call .toLocal() on it!
          final firstOfMonth = DateTime(nowLocal.year, nowLocal.month, 1);
          final firstOfNextMonth = DateTime(
            nowLocal.year,
            nowLocal.month + 1,
            1,
          );

          curFrom = firstOfMonth;
          curTo = firstOfNextMonth;
          // Previous month
          final firstOfPrevMonth = DateTime(
            nowLocal.year,
            nowLocal.month - 1,
            1,
          );
          prevFrom = firstOfPrevMonth;
          prevTo = firstOfMonth;
          break;

        case 'Yearly':
          // Current year: Jan 1 (00:00 local) → Jan 1 of next year (00:00 local)
          // NOTE: DateTime() constructor creates in LOCAL timezone, don't call .toLocal() on it!
          final firstOfYear = DateTime(nowLocal.year, 1, 1);
          final firstOfNextYear = DateTime(nowLocal.year + 1, 1, 1);

          curFrom = firstOfYear;
          curTo = firstOfNextYear;
          // Previous year
          final firstOfPrevYear = DateTime(nowLocal.year - 1, 1, 1);
          prevFrom = firstOfPrevYear;
          prevTo = firstOfYear;
          break;

        default: // Weekly
          // ISO week: Monday (00:00 local) → Sunday (00:00 local next day)
          // CRITICAL: DateTime() constructor creates in LOCAL timezone
          // Don't call .toLocal() on it - that treats it as UTC and converts it backwards!
          final todayStart = DateTime(
            nowLocal.year,
            nowLocal.month,
            nowLocal.day,
          ); // Already in local timezone
          final daysSinceMonday = todayStart.weekday - 1; // 0=Mon, 6=Sun
          final monday = todayStart.subtract(Duration(days: daysSinceMonday));
          final nextMonday = monday.add(const Duration(days: 7));

          curFrom = monday;
          curTo = nextMonday;
          // Previous week
          prevFrom = monday.subtract(const Duration(days: 7));
          prevTo = monday;
          break;
      }

      // ──═════════════════════════════════════════════════════════════════════
      // CRITICAL FIX: Convert LOCAL date boundaries to UTC for database query
      // This ensures orders in the local timezone are correctly included/excluded
      // ──═════════════════════════════════════════════════════════════════════
      final curFromUtc = curFrom.toUtc();
      final curToUtc = curTo.toUtc();
      final prevFromUtc = prevFrom.toUtc();
      final prevToUtc = prevTo.toUtc();

      debugPrint(
        '📈 $period date ranges (LOCAL timezone):\n'
        '  Current:  ${curFrom.toIso8601String()} → ${curTo.toIso8601String()}\n'
        '  Previous: ${prevFrom.toIso8601String()} → ${prevTo.toIso8601String()}\n'
        '  Today: ${nowLocal.toIso8601String()}\n'
        '  UTC:      ${curFromUtc.toIso8601String()} → ${curToUtc.toIso8601String()}',
      );

      // ── Fetch current period orders ──────────────────────────────────────
      final curRows =
          await db
                  .from('orders')
                  .select('status, payment_status, total_amount, created_at')
                  .eq('business_id', _businessId)
                  .gte('created_at', curFromUtc.toIso8601String())
                  .lt('created_at', curToUtc.toIso8601String())
              as List;

      // ── Fetch previous period orders (for growth rate) ───────────────────
      final prevRows =
          await db
                  .from('orders')
                  .select('status, payment_status, total_amount, created_at')
                  .eq('business_id', _businessId)
                  .gte('created_at', prevFromUtc.toIso8601String())
                  .lt('created_at', prevToUtc.toIso8601String())
              as List;

      debugPrint(
        '📈 $period fetch: cur=${curRows.length} prev=${prevRows.length}',
      );

      // ── Compute stats ────────────────────────────────────────────────────
      final stats = _computeStats(
        period: period,
        curRows: curRows,
        prevRows: prevRows,
        curFrom: curFrom,
        curTo: curTo,
        now: nowLocal,
      );

      // Store result
      switch (period) {
        case 'Monthly':
          _monthlyStats = stats;
          break;
        case 'Yearly':
          _yearlyStats = stats;
          break;
        default:
          _weeklyStats = stats;
          break;
      }

      debugPrint(
        '📈 $period stats: total=₹${stats.totalRevenue.toStringAsFixed(0)} '
        'avg=₹${stats.averageRevenue.toStringAsFixed(0)} '
        'highest=₹${stats.highestRevenue.toStringAsFixed(0)} '
        'growth=${stats.growthRate.toStringAsFixed(1)}% '
        'orders=${stats.orderCount}',
      );
    } catch (e) {
      debugPrint('📈 _fetchPeriod($period) ERROR: $e');
    }
  }

  // ── Compute all metrics + chart points from raw rows ─────────────────────
  AnalyticsPeriodStats _computeStats({
    required String period,
    required List curRows,
    required List prevRows,
    required DateTime curFrom,
    required DateTime curTo,
    required DateTime now,
  }) {
    // ── Build bucket map ─────────────────────────────────────────────────
    // bucket key → {revenue, orders}
    final Map<String, _Bucket> buckets = {};

    // Initialise ALL expected buckets to 0 so the chart always has the
    // right number of points even for days/months with no orders.
    _initBuckets(buckets, period, curFrom, curTo, now);

    // Populate from order rows
    int totalOrders = 0;
    for (final r in curRows) {
      totalOrders++;

      // ✅ FIX: Only count completed + PAID orders for revenue
      final amount = (r['status'] == 'completed')
          ? (r['total_amount'] as num? ?? 0).toDouble()
          : 0.0;

      DateTime dt;
      try {
        // ✅ FIX: Use IST utility to parse timestamp to LOCAL time
        final rawCreatedAt = r['created_at'] as String;
        dt = parseToIST(rawCreatedAt); // Converts to local time
      } catch (_) {
        debugPrint('📈 Failed to parse timestamp: ${r['created_at']}');
        continue;
      }

      final key = _bucketKey(period, dt);
      if (buckets.containsKey(key)) {
        buckets[key]!.revenue += amount;
        buckets[key]!.orders++;
      }
    }

    // ── Derived metrics ──────────────────────────────────────────────────
    final revenues = buckets.values.map((b) => b.revenue).toList();
    final totalRevenue = revenues.fold(0.0, (a, b) => a + b);

    // Average = total ÷ number of buckets that have at least 1 order
    final activeBuckets = buckets.values.where((b) => b.orders > 0).length;
    final averageRevenue = activeBuckets > 0
        ? totalRevenue / activeBuckets
        : 0.0;

    final highestRevenue = revenues.isEmpty
        ? 0.0
        : revenues.reduce((a, b) => a > b ? a : b);

    // ✅ FIX: Growth rate calculation — only count completed orders for both periods
    double prevTotal = 0;
    for (final r in prevRows) {
      if (r['status'] == 'completed') {
        prevTotal += (r['total_amount'] as num? ?? 0).toDouble();
      }
    }
    final growthRate = prevTotal > 0
        ? ((totalRevenue - prevTotal) / prevTotal * 100)
        : (totalRevenue > 0 ? 100.0 : 0.0);

    // ── Build ordered chart points ───────────────────────────────────────
    final List<AnalyticsChartPoint> chartPoints = buckets.entries
        .map(
          (e) => AnalyticsChartPoint(
            label: e.key,
            revenue: e.value.revenue,
            orders: e.value.orders,
          ),
        )
        .toList();

    debugPrint(
      '📈 $period stats computed:\n'
      '  totalRevenue: ₹${totalRevenue.toStringAsFixed(2)}\n'
      '  averageRevenue: ₹${averageRevenue.toStringAsFixed(2)}\n'
      '  highestRevenue: ₹${highestRevenue.toStringAsFixed(2)}\n'
      '  growthRate: ${growthRate.toStringAsFixed(1)}%\n'
      '  orderCount: $totalOrders\n'
      '  activeBuckets: $activeBuckets',
    );

    return AnalyticsPeriodStats(
      totalRevenue: totalRevenue,
      averageRevenue: averageRevenue,
      highestRevenue: highestRevenue,
      growthRate: growthRate,
      orderCount: totalOrders,
      chartPoints: chartPoints,
    );
  }

  // ── Initialise all expected buckets ──────────────────────────────────────
  void _initBuckets(
    Map<String, _Bucket> buckets,
    String period,
    DateTime from,
    DateTime to,
    DateTime now,
  ) {
    switch (period) {
      case 'Weekly':
        // Mon–Sun (7 days), labelled Mon/Tue/…/Sun
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (final l in labels) {
          buckets[l] = _Bucket();
        }
        break;

      case 'Monthly':
        // Day 1 … last day of month.  Use "01", "02", … so they sort correctly.
        final daysInMonth = DateTime(from.year, from.month + 1, 0).day;
        for (int d = 1; d <= daysInMonth; d++) {
          buckets[d.toString().padLeft(2, '0')] = _Bucket();
        }
        break;

      case 'Yearly':
        // Jan … Dec
        const months = [
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
        for (final m in months) {
          buckets[m] = _Bucket();
        }
        break;
    }
  }

  // ── Map a DateTime to its bucket key ─────────────────────────────────────
  String _bucketKey(String period, DateTime dt) {
    switch (period) {
      case 'Weekly':
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1]; // weekday 1=Mon…7=Sun
      case 'Monthly':
        return dt.day.toString().padLeft(2, '0');
      case 'Yearly':
        const months = [
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
        return months[dt.month - 1];
      default:
        return '';
    }
  }
}

// ── Internal bucket accumulator ───────────────────────────────────────────────
class _Bucket {
  double revenue = 0;
  int orders = 0;
}
