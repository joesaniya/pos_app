import 'package:flutter/material.dart';
import 'package:pos_app/screens/revenue_analytics_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/analytics_provider.dart';

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 10,
  });
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _a = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(_a.value - 1, 0),
          end: Alignment(_a.value + 1, 0),
          colors: const [
            Color(0xFFEEEEF6),
            Color(0xFFF8F8FF),
            Color(0xFFEEEEF6),
          ],
        ),
      ),
    ),
  );
}

class _C {
  static const bg = Color(0xFFF6F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border = Color(0xFFEAEAF4);
  static const primary = Color(0xFF5A3FD6);
  static const primaryL = Color(0xFFEDE9FF);
  static const primaryD = Color(0xFF3D2AA0);
  static const textPri = Color(0xFF1A1A2E);
  static const textSec = Color(0xFF6B6B86);
  static const textMute = Color(0xFFAAABBB);
  static const green = Color(0xFF059669);
  static const greenL = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redL = Color(0xFFFEF2F2);
  static const amber = Color(0xFFD97706);
  static const amberL = Color(0xFFFFF4E0);
  static const blue = Color(0xFF0A7ADB);
  static const blueL = Color(0xFFE0F0FF);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().init();
      context.read<AnalyticsProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: _C.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(prov),
                _buildPeriodSelector(prov),
                Expanded(
                  child: prov.error != null && !prov.isLoading
                      ? _buildError(prov)
                      : RefreshIndicator(
                          color: _C.primary,
                          onRefresh: prov.refresh,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              // ── KPI cards: show skeleton rows while loading ──
                              // Never show a blank screen or a spinner overlay.
                              prov.isLoading
                                  ? _buildKPICardsSkeleton()
                                  : _buildKPICards(prov),
                              const SizedBox(height: 20),
                              // ── Analytics: skeleton-first inside the widget ──
                              // isLoading=true → full skeleton shown immediately.
                              // Once false, data (or empty-state) renders.
                              // Period switches use a chart-only shimmer, never
                              // blank → spinner → data.
                              EnhancedRevenueAnalytics(
                                isLoading: prov.isLoading,
                              ),
                              const SizedBox(height: 20),
                              if (!prov.isLoading && prov.isAdminLevel) ...[
                                _buildTableStats(prov),
                                const SizedBox(height: 20),
                              ],
                              if (!prov.isLoading) ...[
                                _buildTopItems(prov),
                                const SizedBox(height: 20),
                              ],
                              if (!prov.isLoading && prov.isAdminLevel) ...[
                                _buildEmployeeTable(prov),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(DashboardProvider prov) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prov.isAdminLevel ? 'Admin Dashboard' : 'My Dashboard',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _C.textPri,
                  ),
                ),
                Text(
                  prov.businessName.isEmpty ? 'Loading...' : prov.businessName,
                  style: const TextStyle(fontSize: 11, color: _C.textSec),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.primaryL,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              prov.userRole.isEmpty
                  ? ''
                  : prov.userRole[0].toUpperCase() + prov.userRole.substring(1),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Period selector ─────────────────────────────────────────
  Widget _buildPeriodSelector(DashboardProvider prov) {
    const periods = ['Today', 'Yesterday', 'This Week', 'This Month'];
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 10),
          Row(
            children: [
              ...periods.map((p) {
                final isSel = prov.selectedPeriod == p;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => prov.setSelectedPeriod(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? _C.primary : _C.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.white : _C.textSec,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // ── UPDATED: Custom date range trigger using new picker ──
              GestureDetector(
                onTap: () => _pickCustomRange(prov),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: prov.selectedPeriod == 'Custom'
                        ? const LinearGradient(
                            colors: [_C.primary, _C.primaryD],
                          )
                        : null,
                    color: prov.selectedPeriod == 'Custom'
                        ? null
                        : _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: prov.selectedPeriod == 'Custom'
                        ? [
                            BoxShadow(
                              color: _C.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 13,
                        color: prov.selectedPeriod == 'Custom'
                            ? Colors.white
                            : _C.textSec,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: prov.selectedPeriod == 'Custom'
                              ? Colors.white
                              : _C.textSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── UPDATED: Use custom date picker instead of Flutter's default ──
  Future<void> _pickCustomRange(DashboardProvider prov) async {
    final picked = await CustomDateRangePicker.show(
      context,
      primaryColor: _C.primary,
    );
    if (picked != null) {
      await prov.setCustomDateRange(picked.start, picked.end);
    }
  }

  // ── KPI Skeleton (shown on initial load, never a spinner) ──────────────────
  Widget _buildKPICardsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBox(width: 80, height: 10, radius: 6),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShimmerBox(
                width: double.infinity,
                height: 88,
                radius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShimmerBox(
                width: double.infinity,
                height: 88,
                radius: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShimmerBox(
                width: double.infinity,
                height: 88,
                radius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShimmerBox(
                width: double.infinity,
                height: 88,
                radius: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ShimmerBox(width: double.infinity, height: 56, radius: 16),
      ],
    );
  }

  // ── KPI cards ───────────────────────────────────────────────
  Widget _buildKPICards(DashboardProvider prov) {
    final s = prov.stats;
    final revChange = s.revenueChangePct;
    final ordChange = s.ordersChangePct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Overview'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                emoji: '💰',
                label: 'Revenue',
                value: '₹${_fmt(s.revenue)}',
                change: revChange,
                color: _C.green,
                bg: _C.greenL,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                emoji: '🧾',
                label: 'Orders',
                value: '${s.ordersCount}',
                change: ordChange,
                color: _C.primary,
                bg: _C.primaryL,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                emoji: '📊',
                label: 'Avg Order',
                value: '₹${_fmt(s.averageOrder)}',
                color: _C.blue,
                bg: _C.blueL,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                emoji: '✅',
                label: 'Completed',
                value: '${s.completedOrders}',
                subtitle: s.ordersCount > 0
                    ? '${((s.completedOrders / s.ordersCount) * 100).toStringAsFixed(0)}% success'
                    : '0% success',
                color: _C.green,
                bg: _C.greenL,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KpiCard(
          emoji: '❌',
          label: 'Cancelled',
          value:
              '${s.cancelledOrders} orders (${s.cancelRate.toStringAsFixed(1)}% rate)',
          color: _C.red,
          bg: _C.redL,
          wide: true,
        ),
      ],
    );
  }

  // ── Table Stats (admin) ─────────────────────────────────────
  Widget _buildTableStats(DashboardProvider prov) {
    final s = prov.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Table Utilisation'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                emoji: '🪑',
                label: 'Total Tables',
                value: '${s.totalTables}',
                color: _C.primary,
                bg: _C.primaryL,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                emoji: '🍽️',
                label: 'Occupied Now',
                value: '${s.activeTables}',
                color: _C.red,
                bg: _C.redL,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                emoji: '✅',
                label: 'Served Today',
                value: '${s.servedTablesToday}',
                color: _C.green,
                bg: _C.greenL,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Top Items ───────────────────────────────────────────────
  Widget _buildTopItems(DashboardProvider prov) {
    if (prov.topItems.isEmpty) {
      return _emptyCard('Top Selling Items', 'No completed orders yet');
    }
    final maxQty = prov.topItems.first.quantity.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Top Selling Items'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: prov.topItems.asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              final frac = maxQty > 0 ? item.quantity / maxQty : 0.0;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rank <= 3 ? _C.amberL : _C.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                            style: TextStyle(
                              fontSize: rank <= 3 ? 14 : 11,
                              fontWeight: FontWeight.w800,
                              color: _C.textSec,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _C.textPri,
                                ),
                              ),
                              if (item.categoryName.isNotEmpty)
                                Text(
                                  item.categoryName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _C.textMute,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  backgroundColor: _C.surfaceAlt,
                                  valueColor: AlwaysStoppedAnimation(
                                    rank == 1 ? _C.primary : _C.blue,
                                  ),
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
                            Text(
                              '${item.quantity} sold',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _C.primary,
                              ),
                            ),
                            Text(
                              '₹${_fmt(item.revenue)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textSec,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (e.key < prov.topItems.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: _C.border,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Employee Table (admin) ──────────────────────────────────
  Widget _buildEmployeeTable(DashboardProvider prov) {
    if (prov.employees.isEmpty) {
      return _emptyCard('Staff Performance', 'No orders found for this period');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Staff Performance'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: _C.surfaceAlt,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Staff Member',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _C.textSec,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Orders',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _C.textSec,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Revenue',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _C.textSec,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Cancelled',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _C.textSec,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...prov.employees.asMap().entries.map((e) {
                final s = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _C.primaryL,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    s.name.isNotEmpty
                                        ? s.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _C.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _C.textPri,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        s.role,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: _C.textMute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${s.orders}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _C.textPri,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${_fmt(s.revenue)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _C.green,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${s.cancelledOrders}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: s.cancelledOrders > 0
                                    ? _C.red
                                    : _C.textMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.key < prov.employees.length - 1)
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: _C.border,
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(DashboardProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _C.textPri,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              prov.error ?? '',
              style: const TextStyle(fontSize: 12, color: _C.textSec),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: prov.refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String title, String msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Center(
            child: Text(
              msg,
              style: const TextStyle(color: _C.textMute, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
      letterSpacing: 1.4,
    ),
  );
}

class _KpiCard extends StatelessWidget {
  final String emoji, label, value;
  final String? subtitle;
  final double? change;
  final Color color, bg;
  final bool wide;

  const _KpiCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.subtitle,
    this.change,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: wide
          ? Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    if (change != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: change! >= 0
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              change! >= 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 9,
                              color: change! >= 0
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${change!.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: change! >= 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 9,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:pos_app/screens/revenue_analytics_screen.dart';
// import 'package:provider/provider.dart';
// import '../../providers/dashboard_provider.dart';

// // ── Shimmer box (shared with analytics skeleton) ──────────────────────────────
// // Lightweight animated shimmer for any skeleton placeholder.
// class _ShimmerBox extends StatefulWidget {
//   final double width;
//   final double height;
//   final double radius;
//   const _ShimmerBox({
//     required this.width,
//     required this.height,
//     this.radius = 10,
//   });
//   @override
//   State<_ShimmerBox> createState() => _ShimmerBoxState();
// }

// class _ShimmerBoxState extends State<_ShimmerBox>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _c;
//   late Animation<double> _a;
//   @override
//   void initState() {
//     super.initState();
//     _c = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..repeat();
//     _a = Tween<double>(
//       begin: -2,
//       end: 2,
//     ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _c.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) => AnimatedBuilder(
//     animation: _a,
//     builder: (_, __) => Container(
//       width: widget.width,
//       height: widget.height,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(widget.radius),
//         gradient: LinearGradient(
//           begin: Alignment(_a.value - 1, 0),
//           end: Alignment(_a.value + 1, 0),
//           colors: const [
//             Color(0xFFEEEEF6),
//             Color(0xFFF8F8FF),
//             Color(0xFFEEEEF6),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// class _C {
//   static const bg = Color(0xFFF6F6FB);
//   static const surface = Color(0xFFFFFFFF);
//   static const surfaceAlt = Color(0xFFF2F2F8);
//   static const border = Color(0xFFEAEAF4);
//   static const primary = Color(0xFF5A3FD6);
//   static const primaryL = Color(0xFFEDE9FF);
//   static const primaryD = Color(0xFF3D2AA0);
//   static const textPri = Color(0xFF1A1A2E);
//   static const textSec = Color(0xFF6B6B86);
//   static const textMute = Color(0xFFAAABBB);
//   static const green = Color(0xFF059669);
//   static const greenL = Color(0xFFDCFCE7);
//   static const red = Color(0xFFDC2626);
//   static const redL = Color(0xFFFEF2F2);
//   static const amber = Color(0xFFD97706);
//   static const amberL = Color(0xFFFFF4E0);
//   static const blue = Color(0xFF0A7ADB);
//   static const blueL = Color(0xFFE0F0FF);
// }

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({Key? key}) : super(key: key);

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<DashboardProvider>().init();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<DashboardProvider>(
//       builder: (context, prov, _) {
//         return Scaffold(
//           backgroundColor: _C.bg,
//           body: SafeArea(
//             child: Column(
//               children: [
//                 _buildHeader(prov),
//                 _buildPeriodSelector(prov),
//                 Expanded(
//                   child: prov.error != null && !prov.isLoading
//                       ? _buildError(prov)
//                       : RefreshIndicator(
//                           color: _C.primary,
//                           onRefresh: prov.refresh,
//                           child: ListView(
//                             padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
//                             children: [
//                               // ── KPI cards: show skeleton rows while loading ──
//                               // Never show a blank screen or a spinner overlay.
//                               prov.isLoading
//                                   ? _buildKPICardsSkeleton()
//                                   : _buildKPICards(prov),
//                               const SizedBox(height: 20),
//                               // ── Analytics: skeleton-first inside the widget ──
//                               // isLoading=true → full skeleton shown immediately.
//                               // Once false, data (or empty-state) renders.
//                               // Period switches use a chart-only shimmer, never
//                               // blank → spinner → data.
//                               EnhancedRevenueAnalytics(
//                                 isLoading: prov.isLoading,
//                               ),
//                               const SizedBox(height: 20),
//                               if (!prov.isLoading && prov.isAdminLevel) ...[
//                                 _buildTableStats(prov),
//                                 const SizedBox(height: 20),
//                               ],
//                               if (!prov.isLoading) ...[
//                                 _buildTopItems(prov),
//                                 const SizedBox(height: 20),
//                               ],
//                               if (!prov.isLoading && prov.isAdminLevel) ...[
//                                 _buildEmployeeTable(prov),
//                                 const SizedBox(height: 20),
//                               ],
//                             ],
//                           ),
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // ── Header ──────────────────────────────────────────────────
//   Widget _buildHeader(DashboardProvider prov) {
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(11),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(
//               Icons.dashboard_rounded,
//               color: Colors.white,
//               size: 22,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   prov.isAdminLevel ? 'Admin Dashboard' : 'My Dashboard',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w900,
//                     color: _C.textPri,
//                   ),
//                 ),
//                 Text(
//                   prov.businessName.isEmpty ? 'Loading...' : prov.businessName,
//                   style: const TextStyle(fontSize: 11, color: _C.textSec),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//             decoration: BoxDecoration(
//               color: _C.primaryL,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Text(
//               prov.userRole.isEmpty
//                   ? ''
//                   : prov.userRole[0].toUpperCase() + prov.userRole.substring(1),
//               style: const TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w700,
//                 color: _C.primary,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Period selector ─────────────────────────────────────────
//   Widget _buildPeriodSelector(DashboardProvider prov) {
//     const periods = ['Today', 'Yesterday', 'This Week', 'This Month'];
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//       child: Column(
//         children: [
//           const Divider(height: 1, color: _C.border),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               ...periods.map((p) {
//                 final isSel = prov.selectedPeriod == p;
//                 return Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.only(right: 6),
//                     child: GestureDetector(
//                       onTap: () => prov.setSelectedPeriod(p),
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 150),
//                         padding: const EdgeInsets.symmetric(vertical: 8),
//                         decoration: BoxDecoration(
//                           color: isSel ? _C.primary : _C.surfaceAlt,
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           p,
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.w700,
//                             color: isSel ? Colors.white : _C.textSec,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//               // ── UPDATED: Custom date range trigger using new picker ──
//               GestureDetector(
//                 onTap: () => _pickCustomRange(prov),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 150),
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 8,
//                     horizontal: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     gradient: prov.selectedPeriod == 'Custom'
//                         ? const LinearGradient(
//                             colors: [_C.primary, _C.primaryD],
//                           )
//                         : null,
//                     color: prov.selectedPeriod == 'Custom'
//                         ? null
//                         : _C.surfaceAlt,
//                     borderRadius: BorderRadius.circular(10),
//                     boxShadow: prov.selectedPeriod == 'Custom'
//                         ? [
//                             BoxShadow(
//                               color: _C.primary.withOpacity(0.35),
//                               blurRadius: 8,
//                               offset: const Offset(0, 3),
//                             ),
//                           ]
//                         : [],
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.date_range_rounded,
//                         size: 13,
//                         color: prov.selectedPeriod == 'Custom'
//                             ? Colors.white
//                             : _C.textSec,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Custom',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w700,
//                           color: prov.selectedPeriod == 'Custom'
//                               ? Colors.white
//                               : _C.textSec,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── UPDATED: Use custom date picker instead of Flutter's default ──
//   Future<void> _pickCustomRange(DashboardProvider prov) async {
//     final picked = await CustomDateRangePicker.show(
//       context,
//       primaryColor: _C.primary,
//     );
//     if (picked != null) {
//       await prov.setCustomDateRange(picked.start, picked.end);
//     }
//   }

//   // ── KPI Skeleton (shown on initial load, never a spinner) ──────────────────
//   Widget _buildKPICardsSkeleton() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _ShimmerBox(width: 80, height: 10, radius: 6),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _ShimmerBox(
//                 width: double.infinity,
//                 height: 88,
//                 radius: 16,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _ShimmerBox(
//                 width: double.infinity,
//                 height: 88,
//                 radius: 16,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _ShimmerBox(
//                 width: double.infinity,
//                 height: 88,
//                 radius: 16,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _ShimmerBox(
//                 width: double.infinity,
//                 height: 88,
//                 radius: 16,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         _ShimmerBox(width: double.infinity, height: 56, radius: 16),
//       ],
//     );
//   }

//   // ── KPI cards ───────────────────────────────────────────────
//   Widget _buildKPICards(DashboardProvider prov) {
//     final s = prov.stats;
//     final revChange = s.revenueChangePct;
//     final ordChange = s.ordersChangePct;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Overview'),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '💰',
//                 label: 'Revenue',
//                 value: '₹${_fmt(s.revenue)}',
//                 change: revChange,
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🧾',
//                 label: 'Orders',
//                 value: '${s.ordersCount}',
//                 change: ordChange,
//                 color: _C.primary,
//                 bg: _C.primaryL,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '📊',
//                 label: 'Avg Order',
//                 value: '₹${_fmt(s.averageOrder)}',
//                 color: _C.blue,
//                 bg: _C.blueL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '✅',
//                 label: 'Completed',
//                 value: '${s.completedOrders}',
//                 subtitle: s.ordersCount > 0
//                     ? '${((s.completedOrders / s.ordersCount) * 100).toStringAsFixed(0)}% success'
//                     : '0% success',
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         _KpiCard(
//           emoji: '❌',
//           label: 'Cancelled',
//           value:
//               '${s.cancelledOrders} orders (${s.cancelRate.toStringAsFixed(1)}% rate)',
//           color: _C.red,
//           bg: _C.redL,
//           wide: true,
//         ),
//       ],
//     );
//   }

//   // ── Table Stats (admin) ─────────────────────────────────────
//   Widget _buildTableStats(DashboardProvider prov) {
//     final s = prov.stats;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Table Utilisation'),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🪑',
//                 label: 'Total Tables',
//                 value: '${s.totalTables}',
//                 color: _C.primary,
//                 bg: _C.primaryL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🍽️',
//                 label: 'Occupied Now',
//                 value: '${s.activeTables}',
//                 color: _C.red,
//                 bg: _C.redL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '✅',
//                 label: 'Served Today',
//                 value: '${s.servedTablesToday}',
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   // ── Top Items ───────────────────────────────────────────────
//   Widget _buildTopItems(DashboardProvider prov) {
//     if (prov.topItems.isEmpty) {
//       return _emptyCard('Top Selling Items', 'No completed orders yet');
//     }
//     final maxQty = prov.topItems.first.quantity.toDouble();
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Top Selling Items'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: prov.topItems.asMap().entries.map((e) {
//               final rank = e.key + 1;
//               final item = e.value;
//               final frac = maxQty > 0 ? item.quantity / maxQty : 0.0;
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 28,
//                           height: 28,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             color: rank <= 3 ? _C.amberL : _C.surfaceAlt,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Text(
//                             rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
//                             style: TextStyle(
//                               fontSize: rank <= 3 ? 14 : 11,
//                               fontWeight: FontWeight.w800,
//                               color: _C.textSec,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.name,
//                                 style: const TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w700,
//                                   color: _C.textPri,
//                                 ),
//                               ),
//                               if (item.categoryName.isNotEmpty)
//                                 Text(
//                                   item.categoryName,
//                                   style: const TextStyle(
//                                     fontSize: 10,
//                                     color: _C.textMute,
//                                   ),
//                                 ),
//                               const SizedBox(height: 4),
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(4),
//                                 child: LinearProgressIndicator(
//                                   value: frac,
//                                   backgroundColor: _C.surfaceAlt,
//                                   valueColor: AlwaysStoppedAnimation(
//                                     rank == 1 ? _C.primary : _C.blue,
//                                   ),
//                                   minHeight: 5,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               '${item.quantity} sold',
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w800,
//                                 color: _C.primary,
//                               ),
//                             ),
//                             Text(
//                               '₹${_fmt(item.revenue)}',
//                               style: const TextStyle(
//                                 fontSize: 10,
//                                 color: _C.textSec,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (e.key < prov.topItems.length - 1)
//                     const Divider(
//                       height: 1,
//                       indent: 16,
//                       endIndent: 16,
//                       color: _C.border,
//                     ),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Employee Table (admin) ──────────────────────────────────
//   Widget _buildEmployeeTable(DashboardProvider prov) {
//     if (prov.employees.isEmpty) {
//       return _emptyCard('Staff Performance', 'No orders found for this period');
//     }
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Staff Performance'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: [
//               Container(
//                 padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
//                 decoration: const BoxDecoration(
//                   color: _C.surfaceAlt,
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//                 ),
//                 child: Row(
//                   children: const [
//                     Expanded(
//                       flex: 3,
//                       child: Text(
//                         'Staff Member',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Orders',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Revenue',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Cancelled',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               ...prov.employees.asMap().entries.map((e) {
//                 final s = e.value;
//                 return Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             flex: 3,
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 32,
//                                   height: 32,
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color: _C.primaryL,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Text(
//                                     s.name.isNotEmpty
//                                         ? s.name[0].toUpperCase()
//                                         : '?',
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w900,
//                                       color: _C.primary,
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         s.name,
//                                         style: const TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w700,
//                                           color: _C.textPri,
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                       Text(
//                                         s.role,
//                                         style: const TextStyle(
//                                           fontSize: 9,
//                                           color: _C.textMute,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '${s.orders}',
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w700,
//                                 color: _C.textPri,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '₹${_fmt(s.revenue)}',
//                               textAlign: TextAlign.right,
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w800,
//                                 color: _C.green,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '${s.cancelledOrders}',
//                               textAlign: TextAlign.right,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w700,
//                                 color: s.cancelledOrders > 0
//                                     ? _C.red
//                                     : _C.textMute,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (e.key < prov.employees.length - 1)
//                       const Divider(
//                         height: 1,
//                         indent: 16,
//                         endIndent: 16,
//                         color: _C.border,
//                       ),
//                   ],
//                 );
//               }),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildError(DashboardProvider prov) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text('⚠️', style: TextStyle(fontSize: 48)),
//             const SizedBox(height: 12),
//             const Text(
//               'Failed to load dashboard',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w800,
//                 color: _C.textPri,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               prov.error ?? '',
//               style: const TextStyle(fontSize: 12, color: _C.textSec),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: prov.refresh,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _C.primary,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _emptyCard(String title, String msg) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _SectionLabel(title),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Center(
//             child: Text(
//               msg,
//               style: const TextStyle(color: _C.textMute, fontSize: 13),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   static String _fmt(double v) {
//     if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
//     if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
//     return v.toStringAsFixed(0);
//   }
// }

// // ── Reusable widgets ──────────────────────────────────────────────────────────

// class _SectionLabel extends StatelessWidget {
//   final String text;
//   const _SectionLabel(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text.toUpperCase(),
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w800,
//       color: _C.textMute,
//       letterSpacing: 1.4,
//     ),
//   );
// }

// class _KpiCard extends StatelessWidget {
//   final String emoji, label, value;
//   final String? subtitle;
//   final double? change;
//   final Color color, bg;
//   final bool wide;

//   const _KpiCard({
//     required this.emoji,
//     required this.label,
//     required this.value,
//     required this.color,
//     required this.bg,
//     this.subtitle,
//     this.change,
//     this.wide = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: wide
//           ? Row(
//               children: [
//                 Text(emoji, style: const TextStyle(fontSize: 20)),
//                 const SizedBox(width: 12),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       label,
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                         color: color.withOpacity(0.8),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       value,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w800,
//                         color: color,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(emoji, style: const TextStyle(fontSize: 20)),
//                     if (change != null)
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: change! >= 0
//                               ? const Color(0xFFD1FAE5)
//                               : const Color(0xFFFEE2E2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               change! >= 0
//                                   ? Icons.arrow_upward
//                                   : Icons.arrow_downward,
//                               size: 9,
//                               color: change! >= 0
//                                   ? const Color(0xFF059669)
//                                   : const Color(0xFFDC2626),
//                             ),
//                             const SizedBox(width: 2),
//                             Text(
//                               '${change!.abs().toStringAsFixed(1)}%',
//                               style: TextStyle(
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.w800,
//                                 color: change! >= 0
//                                     ? const Color(0xFF059669)
//                                     : const Color(0xFFDC2626),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: color.withOpacity(0.8),
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w900,
//                     color: color,
//                   ),
//                 ),
//                 if (subtitle != null)
//                   Text(
//                     subtitle!,
//                     style: TextStyle(
//                       fontSize: 9,
//                       color: color.withOpacity(0.7),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//               ],
//             ),
//     );
//   }
// }

// /*
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/dashboard_provider.dart';

// class _C {
//   static const bg = Color(0xFFF6F6FB);
//   static const surface = Color(0xFFFFFFFF);
//   static const surfaceAlt = Color(0xFFF2F2F8);
//   static const border = Color(0xFFEAEAF4);
//   static const primary = Color(0xFF5A3FD6);
//   static const primaryL = Color(0xFFEDE9FF);
//   static const primaryD = Color(0xFF3D2AA0);
//   static const textPri = Color(0xFF1A1A2E);
//   static const textSec = Color(0xFF6B6B86);
//   static const textMute = Color(0xFFAAABBB);
//   static const green = Color(0xFF059669);
//   static const greenL = Color(0xFFDCFCE7);
//   static const red = Color(0xFFDC2626);
//   static const redL = Color(0xFFFEF2F2);
//   static const amber = Color(0xFFD97706);
//   static const amberL = Color(0xFFFFF4E0);
//   static const blue = Color(0xFF0A7ADB);
//   static const blueL = Color(0xFFE0F0FF);
// }

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({Key? key}) : super(key: key);

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<DashboardProvider>().init();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<DashboardProvider>(
//       builder: (context, prov, _) {
//         return Scaffold(
//           backgroundColor: _C.bg,
//           body: SafeArea(
//             child: Column(
//               children: [
//                 _buildHeader(prov),
//                 _buildPeriodSelector(prov),
//                 Expanded(
//                   child: prov.isLoading
//                       ? const Center(
//                           child: CircularProgressIndicator(color: _C.primary),
//                         )
//                       : prov.error != null
//                       ? _buildError(prov)
//                       : RefreshIndicator(
//                           color: _C.primary,
//                           onRefresh: prov.refresh,
//                           child: ListView(
//                             padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
//                             children: [
//                               _buildKPICards(prov),
//                               const SizedBox(height: 20),
//                               _buildRevenueChart(prov),
//                               const SizedBox(height: 20),
//                               if (prov.isAdminLevel) ...[
//                                 _buildTableStats(prov),
//                                 const SizedBox(height: 20),
//                               ],
//                               _buildTopItems(prov),
//                               const SizedBox(height: 20),
//                               if (prov.isAdminLevel) ...[
//                                 _buildEmployeeTable(prov),
//                                 const SizedBox(height: 20),
//                               ],
//                             ],
//                           ),
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // ── Header ─────────────────────────────────────────────────
//   Widget _buildHeader(DashboardProvider prov) {
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(11),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(
//               Icons.dashboard_rounded,
//               color: Colors.white,
//               size: 22,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   prov.isAdminLevel ? 'Admin Dashboard' : 'My Dashboard',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w900,
//                     color: _C.textPri,
//                   ),
//                 ),
//                 Text(
//                   prov.businessName.isEmpty ? 'Loading...' : prov.businessName,
//                   style: const TextStyle(fontSize: 11, color: _C.textSec),
//                 ),
//               ],
//             ),
//           ),
//           // Role badge
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//             decoration: BoxDecoration(
//               color: _C.primaryL,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Text(
//               prov.userRole.isEmpty
//                   ? ''
//                   : prov.userRole[0].toUpperCase() + prov.userRole.substring(1),
//               style: const TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w700,
//                 color: _C.primary,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Period selector ────────────────────────────────────────
//   Widget _buildPeriodSelector(DashboardProvider prov) {
//     const periods = ['Today', 'Yesterday', 'This Week', 'This Month'];
//     return Container(
//       color: _C.surface,
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//       child: Column(
//         children: [
//           const Divider(height: 1, color: _C.border),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               ...periods.map((p) {
//                 final isSel = prov.selectedPeriod == p;
//                 return Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.only(right: 6),
//                     child: GestureDetector(
//                       onTap: () => prov.setSelectedPeriod(p),
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 150),
//                         padding: const EdgeInsets.symmetric(vertical: 8),
//                         decoration: BoxDecoration(
//                           color: isSel ? _C.primary : _C.surfaceAlt,
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           p,
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.w700,
//                             color: isSel ? Colors.white : _C.textSec,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//               GestureDetector(
//                 onTap: () => _pickCustomRange(prov),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 150),
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 8,
//                     horizontal: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     color: prov.selectedPeriod == 'Custom'
//                         ? _C.primary
//                         : _C.surfaceAlt,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.date_range_rounded,
//                         size: 13,
//                         color: prov.selectedPeriod == 'Custom'
//                             ? Colors.white
//                             : _C.textSec,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Custom',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w700,
//                           color: prov.selectedPeriod == 'Custom'
//                               ? Colors.white
//                               : _C.textSec,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickCustomRange(DashboardProvider prov) async {
//     final picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2024),
//       lastDate: DateTime.now(),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(
//           ctx,
//         ).copyWith(colorScheme: const ColorScheme.light(primary: _C.primary)),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       await prov.setCustomDateRange(picked.start, picked.end);
//     }
//   }

//   // ── KPI cards ──────────────────────────────────────────────
//   Widget _buildKPICards(DashboardProvider prov) {
//     final s = prov.stats;
//     final revChange = s.revenueChangePct;
//     final ordChange = s.ordersChangePct;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Overview'),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '💰',
//                 label: 'Revenue',
//                 value: '₹${_fmt(s.revenue)}',
//                 change: revChange,
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🧾',
//                 label: 'Orders',
//                 value: '${s.ordersCount}',
//                 change: ordChange,
//                 color: _C.primary,
//                 bg: _C.primaryL,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '📊',
//                 label: 'Avg Order',
//                 value: '₹${_fmt(s.averageOrder)}',
//                 color: _C.blue,
//                 bg: _C.blueL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '✅',
//                 label: 'Completed',
//                 value: '${s.completedOrders}',
//                 subtitle: s.ordersCount > 0
//                     ? '${((s.completedOrders / s.ordersCount) * 100).toStringAsFixed(0)}% success'
//                     : '0% success',
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         _KpiCard(
//           emoji: '❌',
//           label: 'Cancelled',
//           value:
//               '${s.cancelledOrders} orders (${s.cancelRate.toStringAsFixed(1)}% rate)',
//           color: _C.red,
//           bg: _C.redL,
//           wide: true,
//         ),
//       ],
//     );
//   }

//   // ── Revenue Chart ──────────────────────────────────────────
//   Widget _buildRevenueChart(DashboardProvider prov) {
//     if (prov.chartData.isEmpty) {
//       return _emptyCard('Revenue Chart', 'No revenue data for this period');
//     }

//     final maxVal = prov.chartData
//         .map((p) => p.value)
//         .reduce((a, b) => a > b ? a : b);
//     if (maxVal == 0)
//       return _emptyCard('Revenue Chart', 'No completed orders yet');

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Revenue Over Time'),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Total: ₹${_fmt(prov.stats.revenue)}',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w900,
//                       color: _C.primary,
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: _C.greenL,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       prov.stats.revenueChangePct >= 0
//                           ? '+${prov.stats.revenueChangePct.toStringAsFixed(1)}%'
//                           : '${prov.stats.revenueChangePct.toStringAsFixed(1)}%',
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         color: prov.stats.revenueChangePct >= 0
//                             ? _C.green
//                             : _C.red,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//               SizedBox(
//                 height: 120,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: prov.chartData.map((pt) {
//                     final frac = maxVal > 0 ? pt.value / maxVal : 0.0;
//                     final hasVal = pt.value > 0;
//                     return Expanded(
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 2),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             if (hasVal)
//                               Padding(
//                                 padding: const EdgeInsets.only(bottom: 2),
//                                 child: Text(
//                                   '₹${_fmtShort(pt.value)}',
//                                   style: const TextStyle(
//                                     fontSize: 7,
//                                     color: _C.primary,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                 ),
//                               ),
//                             Flexible(
//                               child: FractionallySizedBox(
//                                 heightFactor: frac.clamp(0.04, 1.0),
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     gradient: LinearGradient(
//                                       colors: hasVal
//                                           ? [_C.primary, _C.primaryD]
//                                           : [_C.border, _C.border],
//                                       begin: Alignment.topCenter,
//                                       end: Alignment.bottomCenter,
//                                     ),
//                                     borderRadius: const BorderRadius.vertical(
//                                       top: Radius.circular(4),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               pt.label,
//                               style: TextStyle(
//                                 fontSize: 8,
//                                 color: hasVal ? _C.textSec : _C.textMute,
//                                 fontWeight: hasVal
//                                     ? FontWeight.w700
//                                     : FontWeight.w400,
//                               ),
//                               textAlign: TextAlign.center,
//                               overflow: TextOverflow.visible,
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Table Stats (admin only) ───────────────────────────────
//   Widget _buildTableStats(DashboardProvider prov) {
//     final s = prov.stats;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Table Utilisation'),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🪑',
//                 label: 'Total Tables',
//                 value: '${s.totalTables}',
//                 color: _C.primary,
//                 bg: _C.primaryL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '🍽️',
//                 label: 'Occupied Now',
//                 value: '${s.activeTables}',
//                 color: _C.red,
//                 bg: _C.redL,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _KpiCard(
//                 emoji: '✅',
//                 label: 'Served Today',
//                 value: '${s.servedTablesToday}',
//                 color: _C.green,
//                 bg: _C.greenL,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   // ── Top Items ──────────────────────────────────────────────
//   Widget _buildTopItems(DashboardProvider prov) {
//     if (prov.topItems.isEmpty) {
//       return _emptyCard('Top Selling Items', 'No completed orders yet');
//     }

//     final maxQty = prov.topItems.first.quantity.toDouble();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Top Selling Items'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: prov.topItems.asMap().entries.map((e) {
//               final rank = e.key + 1;
//               final item = e.value;
//               final frac = maxQty > 0 ? item.quantity / maxQty : 0.0;
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 28,
//                           height: 28,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             color: rank <= 3 ? _C.amberL : _C.surfaceAlt,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Text(
//                             rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
//                             style: TextStyle(
//                               fontSize: rank <= 3 ? 14 : 11,
//                               fontWeight: FontWeight.w800,
//                               color: _C.textSec,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.name,
//                                 style: const TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w700,
//                                   color: _C.textPri,
//                                 ),
//                               ),
//                               if (item.categoryName.isNotEmpty)
//                                 Text(
//                                   item.categoryName,
//                                   style: const TextStyle(
//                                     fontSize: 10,
//                                     color: _C.textMute,
//                                   ),
//                                 ),
//                               const SizedBox(height: 4),
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(4),
//                                 child: LinearProgressIndicator(
//                                   value: frac,
//                                   backgroundColor: _C.surfaceAlt,
//                                   valueColor: AlwaysStoppedAnimation(
//                                     rank == 1 ? _C.primary : _C.blue,
//                                   ),
//                                   minHeight: 5,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               '${item.quantity} sold',
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w800,
//                                 color: _C.primary,
//                               ),
//                             ),
//                             Text(
//                               '₹${_fmt(item.revenue)}',
//                               style: const TextStyle(
//                                 fontSize: 10,
//                                 color: _C.textSec,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (e.key < prov.topItems.length - 1)
//                     const Divider(
//                       height: 1,
//                       indent: 16,
//                       endIndent: 16,
//                       color: _C.border,
//                     ),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Employee Performance (admin only) ──────────────────────
//   Widget _buildEmployeeTable(DashboardProvider prov) {
//     if (prov.employees.isEmpty) {
//       return _emptyCard('Staff Performance', 'No orders found for this period');
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const _SectionLabel('Staff Performance'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Column(
//             children: [
//               // Header
//               Container(
//                 padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
//                 decoration: const BoxDecoration(
//                   color: _C.surfaceAlt,
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//                 ),
//                 child: Row(
//                   children: const [
//                     Expanded(
//                       flex: 3,
//                       child: Text(
//                         'Staff Member',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Orders',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Revenue',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         'Cancelled',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: _C.textSec,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               ...prov.employees.asMap().entries.map((e) {
//                 final s = e.value;
//                 return Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             flex: 3,
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 32,
//                                   height: 32,
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color: _C.primaryL,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Text(
//                                     s.name.isNotEmpty
//                                         ? s.name[0].toUpperCase()
//                                         : '?',
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w900,
//                                       color: _C.primary,
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         s.name,
//                                         style: const TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w700,
//                                           color: _C.textPri,
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                       Text(
//                                         s.role,
//                                         style: const TextStyle(
//                                           fontSize: 9,
//                                           color: _C.textMute,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '${s.orders}',
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w700,
//                                 color: _C.textPri,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '₹${_fmt(s.revenue)}',
//                               textAlign: TextAlign.right,
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w800,
//                                 color: _C.green,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               '${s.cancelledOrders}',
//                               textAlign: TextAlign.right,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w700,
//                                 color: s.cancelledOrders > 0
//                                     ? _C.red
//                                     : _C.textMute,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (e.key < prov.employees.length - 1)
//                       const Divider(
//                         height: 1,
//                         indent: 16,
//                         endIndent: 16,
//                         color: _C.border,
//                       ),
//                   ],
//                 );
//               }),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildError(DashboardProvider prov) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text('⚠️', style: TextStyle(fontSize: 48)),
//             const SizedBox(height: 12),
//             const Text(
//               'Failed to load dashboard',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w800,
//                 color: _C.textPri,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               prov.error ?? '',
//               style: const TextStyle(fontSize: 12, color: _C.textSec),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: prov.refresh,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _C.primary,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _emptyCard(String title, String msg) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _SectionLabel(title),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: _C.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.border),
//           ),
//           child: Center(
//             child: Text(
//               msg,
//               style: const TextStyle(color: _C.textMute, fontSize: 13),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   static String _fmt(double v) {
//     if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
//     if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
//     return v.toStringAsFixed(0);
//   }

//   static String _fmtShort(double v) {
//     if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
//     return v.toStringAsFixed(0);
//   }
// }

// // ── Reusable widgets ──────────────────────────────────────────────────────────

// class _SectionLabel extends StatelessWidget {
//   final String text;
//   const _SectionLabel(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text.toUpperCase(),
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w800,
//       color: _C.textMute,
//       letterSpacing: 1.4,
//     ),
//   );
// }

// class _KpiCard extends StatelessWidget {
//   final String emoji, label, value;
//   final String? subtitle;
//   final double? change;
//   final Color color, bg;
//   final bool wide;

//   const _KpiCard({
//     required this.emoji,
//     required this.label,
//     required this.value,
//     required this.color,
//     required this.bg,
//     this.subtitle,
//     this.change,
//     this.wide = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: wide
//           ? Row(
//               children: [
//                 Text(emoji, style: const TextStyle(fontSize: 20)),
//                 const SizedBox(width: 12),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       label,
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                         color: color.withOpacity(0.8),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       value,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w800,
//                         color: color,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(emoji, style: const TextStyle(fontSize: 20)),
//                     if (change != null)
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: change! >= 0
//                               ? const Color(0xFFD1FAE5)
//                               : const Color(0xFFFEE2E2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               change! >= 0
//                                   ? Icons.arrow_upward
//                                   : Icons.arrow_downward,
//                               size: 9,
//                               color: change! >= 0 ? _C.green : _C.red,
//                             ),
//                             const SizedBox(width: 2),
//                             Text(
//                               '${change!.abs().toStringAsFixed(1)}%',
//                               style: TextStyle(
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.w800,
//                                 color: change! >= 0 ? _C.green : _C.red,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: color.withOpacity(0.8),
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w900,
//                     color: color,
//                   ),
//                 ),
//                 if (subtitle != null)
//                   Text(
//                     subtitle!,
//                     style: TextStyle(
//                       fontSize: 9,
//                       color: color.withOpacity(0.7),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//               ],
//             ),
//     );
//   }
// }
// */
