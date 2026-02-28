// lib/screens/analytics/analytics_dashboard_screen.dart
// Revenue & Analytics Dashboard — visible to manager / admin / owner roles

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens ────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFFF6F6FB);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border     = Color(0xFFEAEAF4);
  static const primary    = Color(0xFF5A3FD6);
  static const primaryL   = Color(0xFFEDE9FF);
  static const primaryD   = Color(0xFF3D2AA0);
  static const textPri    = Color(0xFF1A1A2E);
  static const textSec    = Color(0xFF6B6B86);
  static const textMute   = Color(0xFFAAABBB);
  static const green      = Color(0xFF059669);
  static const greenL     = Color(0xFFDCFCE7);
  static const red        = Color(0xFFDC2626);
  static const redL       = Color(0xFFFEF2F2);
  static const amber      = Color(0xFFD97706);
  static const amberL     = Color(0xFFFFF4E0);
  static const blue       = Color(0xFF0A7ADB);
  static const blueL      = Color(0xFFE0F0FF);
}

// ── Date range presets ───────────────────────────────────────────
enum _Range { today, week, month, custom }

extension _RangeLabel on _Range {
  String get label {
    switch (this) {
      case _Range.today:  return 'Today';
      case _Range.week:   return 'This Week';
      case _Range.month:  return 'This Month';
      case _Range.custom: return 'Custom';
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ANALYTICS DASHBOARD SCREEN
// ══════════════════════════════════════════════════════════════
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  // User context
  String _businessId   = '';
  String _businessName = '';
  String _role         = '';

  // Date range
  _Range _range = _Range.today;
  late DateTime _from;
  late DateTime _to;

  // Summary metrics
  double _totalRevenue     = 0;
  int    _totalOrders      = 0;
  double _avgOrderValue    = 0;
  int    _completedOrders  = 0;
  int    _cancelledOrders  = 0;
  double _cancelRate       = 0;

  // Order type breakdown
  int _dineIn   = 0;
  int _takeaway = 0;
  int _delivery = 0;

  // Hourly revenue (for bar chart)
  List<_HourlyData> _hourlyData = [];

  // Top items
  List<_ItemStat> _topItems = [];

  // Staff performance
  List<_StaffStat> _staffStats = [];

  // Table utilisation
  int _totalTables    = 0;
  int _occupiedNow    = 0;
  int _completedToday = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setRange(_Range.today);
    _init();
  }

  void _setRange(_Range r) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _range = r;
      switch (r) {
        case _Range.today:
          _from = today;
          _to   = today.add(const Duration(days: 1));
          break;
        case _Range.week:
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to   = _from.add(const Duration(days: 7));
          break;
        case _Range.month:
          _from = DateTime(now.year, now.month, 1);
          _to   = DateTime(now.year, now.month + 1, 1);
          break;
        case _Range.custom:
          // keep existing _from/_to
          break;
      }
    });
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _businessId   = prefs.getString('businessId')   ?? '';
    _businessName = prefs.getString('businessName') ?? '';
    _role         = prefs.getString('role')         ?? '';
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_businessId.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      await Future.wait([
        _loadOrderSummary(),
        _loadTopItems(),
        _loadStaffStats(),
        _loadTableStats(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOrderSummary() async {
    final db = Supabase.instance.client;

    final rows = await db
        .from('orders')
        .select('status, order_type, total_amount, created_at')
        .eq('business_id', _businessId)
        .gte('created_at', _from.toIso8601String())
        .lt('created_at', _to.toIso8601String());

    final list = rows as List;

    double revenue   = 0;
    int    total     = list.length;
    int    completed = 0;
    int    cancelled = 0;
    int    dineIn    = 0;
    int    takeaway  = 0;
    int    delivery  = 0;

    // Hourly map
    final Map<int, double> hourly = {};
    for (int h = 0; h < 24; h++) hourly[h] = 0;

    for (final r in list) {
      final status    = r['status'] as String? ?? '';
      final orderType = r['order_type'] as String? ?? '';
      final amount    = (r['total_amount'] as num? ?? 0).toDouble();
      final createdAt = DateTime.parse(r['created_at'] as String).toLocal();

      if (status == 'completed') {
        revenue += amount;
        completed++;
        hourly[createdAt.hour] = (hourly[createdAt.hour] ?? 0) + amount;
      }
      if (status == 'cancelled') cancelled++;
      if (orderType == 'dine_in')   dineIn++;
      if (orderType == 'takeaway')  takeaway++;
      if (orderType == 'delivery')  delivery++;
    }

    final hourlyData = hourly.entries
        .map((e) => _HourlyData(hour: e.key, revenue: e.value))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));

    setState(() {
      _totalRevenue    = revenue;
      _totalOrders     = total;
      _avgOrderValue   = completed > 0 ? revenue / completed : 0;
      _completedOrders = completed;
      _cancelledOrders = cancelled;
      _cancelRate      = total > 0 ? (cancelled / total) * 100 : 0;
      _dineIn          = dineIn;
      _takeaway        = takeaway;
      _delivery        = delivery;
      _hourlyData      = hourlyData;
    });
  }

  Future<void> _loadTopItems() async {
    final db = Supabase.instance.client;

    // Get completed order IDs in range
    final orderRows = await db
        .from('orders')
        .select('id')
        .eq('business_id', _businessId)
        .eq('status', 'completed')
        .gte('created_at', _from.toIso8601String())
        .lt('created_at', _to.toIso8601String());

    final orderIds = (orderRows as List).map((r) => r['id'] as String).toList();
    if (orderIds.isEmpty) {
      setState(() => _topItems = []);
      return;
    }

    final itemRows = await db
        .from('order_items')
        .select('item_name, quantity, subtotal')
        .inFilter('order_id', orderIds);

    // Aggregate by item name
    final Map<String, _ItemStat> agg = {};
    for (final r in (itemRows as List)) {
      final name     = r['item_name'] as String? ?? 'Unknown';
      final qty      = r['quantity'] as int? ?? 0;
      final subtotal = (r['subtotal'] as num? ?? 0).toDouble();
      if (agg.containsKey(name)) {
        agg[name] = _ItemStat(
          name:     name,
          quantity: agg[name]!.quantity + qty,
          revenue:  agg[name]!.revenue + subtotal,
        );
      } else {
        agg[name] = _ItemStat(name: name, quantity: qty, revenue: subtotal);
      }
    }

    final sorted = agg.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    setState(() => _topItems = sorted.take(8).toList());
  }

  Future<void> _loadStaffStats() async {
    final db = Supabase.instance.client;

    final rows = await db
        .from('orders')
        .select('created_by_uid, created_by_name, created_by_role, total_amount, status')
        .eq('business_id', _businessId)
        .gte('created_at', _from.toIso8601String())
        .lt('created_at', _to.toIso8601String());

    final Map<String, _StaffStat> agg = {};
    for (final r in (rows as List)) {
      final uid    = r['created_by_uid']  as String? ?? 'unknown';
      final name   = r['created_by_name'] as String? ?? 'Unknown';
      final role   = r['created_by_role'] as String? ?? 'staff';
      final status = r['status']          as String? ?? '';
      final amount = (r['total_amount']   as num? ?? 0).toDouble();

      if (!agg.containsKey(uid)) {
        agg[uid] = _StaffStat(uid: uid, name: name, role: role);
      }
      agg[uid]!.totalOrders++;
      if (status == 'completed') agg[uid]!.revenue += amount;
      if (status == 'cancelled') agg[uid]!.cancelled++;
    }

    final sorted = agg.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    setState(() => _staffStats = sorted);
  }

  Future<void> _loadTableStats() async {
    final db = Supabase.instance.client;

    final tableRows = await db
        .from('restaurant_tables')
        .select('status')
        .eq('business_id', _businessId)
        .eq('is_active', true);

    final allTables = (tableRows as List);
    final occupied  = allTables.where((r) => r['status'] == 'occupied').length;

    // Tables served today = distinct table_ids in completed orders today
    final orderRows = await db
        .from('orders')
        .select('table_id')
        .eq('business_id', _businessId)
        .eq('status', 'completed')
        .eq('order_type', 'dine_in')
        .gte('created_at', _from.toIso8601String())
        .lt('created_at', _to.toIso8601String())
        .not('table_id', 'is', null);

    final servedTables = (orderRows as List)
        .map((r) => r['table_id'] as String?)
        .whereType<String>()
        .toSet()
        .length;

    setState(() {
      _totalTables    = allTables.length;
      _occupiedNow    = occupied;
      _completedToday = servedTables;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate:  DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _C.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _range = _Range.custom;
        _from  = picked.start;
        _to    = picked.end.add(const Duration(days: 1));
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildRangePicker(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _C.primary))
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _loadData)
                      : RefreshIndicator(
                          color: _C.primary,
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              _buildSummaryCards(),
                              const SizedBox(height: 20),
                              _buildOrderTypeBreakdown(),
                              const SizedBox(height: 20),
                              _buildHourlyChart(),
                              const SizedBox(height: 20),
                              _buildTopItems(),
                              const SizedBox(height: 20),
                              _buildTableStats(),
                              const SizedBox(height: 20),
                              _buildStaffTable(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _C.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border)),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _C.textPri),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.textPri)),
                Text(_businessName,
                    style: const TextStyle(fontSize: 11, color: _C.textSec)),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _C.primaryL, borderRadius: BorderRadius.circular(10)),
            child: Text(
              _role.isEmpty ? 'Manager' : _role[0].toUpperCase() + _role.substring(1),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Range picker ───────────────────────────────────────────────
  Widget _buildRangePicker() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 10),
          Row(
            children: [
              ..._Range.values.map((r) {
                if (r == _Range.custom) return const SizedBox.shrink();
                final isSel = _range == r;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _setRange(r);
                        _loadData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? _C.primary : _C.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : _C.textSec),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _pickCustomRange,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _range == _Range.custom ? _C.primary : _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.date_range_rounded,
                        size: 14,
                        color: _range == _Range.custom ? Colors.white : _C.textSec),
                    const SizedBox(width: 4),
                    Text('Custom',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _range == _Range.custom ? Colors.white : _C.textSec)),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Overview'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MetricCard(
              emoji: '💰',
              label: 'Revenue',
              value: '₹${_fmt(_totalRevenue)}',
              color: _C.green,
              bg: _C.greenL,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              emoji: '🧾',
              label: 'Orders',
              value: '$_totalOrders',
              color: _C.primary,
              bg: _C.primaryL,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MetricCard(
              emoji: '📊',
              label: 'Avg Order',
              value: '₹${_fmt(_avgOrderValue)}',
              color: _C.blue,
              bg: _C.blueL,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              emoji: '✅',
              label: 'Completed',
              value: '$_completedOrders',
              subtitle: '${(100 - _cancelRate).toStringAsFixed(0)}% success',
              color: _C.green,
              bg: _C.greenL,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _MetricCard(
          emoji: '❌',
          label: 'Cancelled',
          value: '$_cancelledOrders orders (${_cancelRate.toStringAsFixed(1)}% cancel rate)',
          color: _C.red,
          bg: _C.redL,
          wide: true,
        ),
      ],
    );
  }

  // ── Order type breakdown ───────────────────────────────────────
  Widget _buildOrderTypeBreakdown() {
    final total = (_dineIn + _takeaway + _delivery).toDouble();
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Order Types'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border)),
          child: Column(
            children: [
              _TypeRow(emoji: '🍽️', label: 'Dine In',  count: _dineIn,   total: total, color: _C.primary),
              const SizedBox(height: 12),
              _TypeRow(emoji: '🛍️', label: 'Takeaway', count: _takeaway, total: total, color: _C.green),
              const SizedBox(height: 12),
              _TypeRow(emoji: '🚚', label: 'Delivery', count: _delivery, total: total, color: _C.amber),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hourly revenue bar chart ───────────────────────────────────
  Widget _buildHourlyChart() {
    final maxRev = _hourlyData.isEmpty
        ? 1.0
        : _hourlyData.map((d) => d.revenue).reduce((a, b) => a > b ? a : b);
    if (maxRev == 0) return const SizedBox.shrink();

    // Show only hours 8am – 11pm
    final relevant = _hourlyData.where((d) => d.hour >= 8 && d.hour <= 23).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Revenue by Hour'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border)),
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: relevant.map((d) {
                final frac = maxRev > 0 ? d.revenue / maxRev : 0.0;
                final isActive = d.revenue > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: frac.clamp(0.03, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isActive ? _C.primary : _C.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hourLabel(d.hour),
                          style: TextStyle(
                              fontSize: 8,
                              color: isActive ? _C.textSec : _C.textMute,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _hourLabel(int h) {
    if (h == 0)  return '12a';
    if (h < 12)  return '${h}a';
    if (h == 12) return '12p';
    return '${h - 12}p';
  }

  // ── Top selling items ──────────────────────────────────────────
  Widget _buildTopItems() {
    if (_topItems.isEmpty) return const SizedBox.shrink();
    final maxQty = _topItems.first.quantity.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Top Selling Items'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border)),
          child: Column(
            children: _topItems.asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              final frac = maxQty > 0 ? item.quantity / maxQty : 0.0;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 26, height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rank <= 3 ? _C.amber : _C.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                            style: TextStyle(
                                fontSize: rank <= 3 ? 14 : 11,
                                fontWeight: FontWeight.w800,
                                color: _C.textSec),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _C.textPri)),
                              const SizedBox(height: 4),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  backgroundColor: _C.surfaceAlt,
                                  valueColor: AlwaysStoppedAnimation(
                                      rank == 1 ? _C.primary : _C.blue),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${item.quantity} sold',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _C.primary)),
                            Text('₹${_fmt(item.revenue)}',
                                style: const TextStyle(fontSize: 10, color: _C.textSec)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (e.key < _topItems.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16, color: _C.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Table utilisation ──────────────────────────────────────────
  Widget _buildTableStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Table Utilisation'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MetricCard(
              emoji: '🪑',
              label: 'Total Tables',
              value: '$_totalTables',
              color: _C.primary,
              bg: _C.primaryL,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              emoji: '🍽️',
              label: 'Occupied Now',
              value: '$_occupiedNow',
              color: _C.red,
              bg: _C.redL,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              emoji: '✅',
              label: 'Served Today',
              value: '$_completedToday',
              color: _C.green,
              bg: _C.greenL,
            ),
          ),
        ]),
      ],
    );
  }

  // ── Staff performance table ────────────────────────────────────
  Widget _buildStaffTable() {
    if (_staffStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Staff Performance'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border)),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                    color: _C.surfaceAlt,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: const [
                    Expanded(flex: 3, child: Text('Staff Member', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textSec, letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text('Orders', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textSec, letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text('Revenue', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textSec, letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text('Cancelled', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textSec, letterSpacing: 0.5))),
                  ],
                ),
              ),
              ..._staffStats.asMap().entries.map((e) {
                final s = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(children: [
                              Container(
                                width: 30, height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: _C.primaryL,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _C.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _C.textPri),
                                        overflow: TextOverflow.ellipsis),
                                    Text(s.role,
                                        style: const TextStyle(
                                            fontSize: 9, color: _C.textMute)),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${s.totalOrders}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _C.textPri)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('₹${_fmt(s.revenue)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _C.green)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${s.cancelled}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: s.cancelled > 0 ? _C.red : _C.textMute)),
                          ),
                        ],
                      ),
                    ),
                    if (e.key < _staffStats.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16, color: _C.border),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Data models ───────────────────────────────────────────────────
class _HourlyData {
  final int hour;
  final double revenue;
  const _HourlyData({required this.hour, required this.revenue});
}

class _ItemStat {
  final String name;
  int quantity;
  double revenue;
  _ItemStat({required this.name, required this.quantity, required this.revenue});
}

class _StaffStat {
  final String uid, name, role;
  int totalOrders = 0;
  int cancelled   = 0;
  double revenue  = 0;
  _StaffStat({required this.uid, required this.name, required this.role});
}

// ── Reusable widgets ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _C.textMute,
        letterSpacing: 1.4),
  );
}

class _MetricCard extends StatelessWidget {
  final String emoji, label, value;
  final String? subtitle;
  final Color color, bg;
  final bool wide;
  const _MetricCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.subtitle,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: wide
          ? Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              ]),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.7),
                          fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String emoji, label;
  final int count;
  final double total;
  final Color color;
  const _TypeRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _C.textPri))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _C.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(0)}%)',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Failed to load analytics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPri)),
          const SizedBox(height: 6),
          Text(error,
              style: const TextStyle(fontSize: 12, color: _C.textSec),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}