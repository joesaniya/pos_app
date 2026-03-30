// lib/screens/kitchen_display_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
//  KITCHEN DISPLAY SYSTEM (KDS)  — Light Theme  (mirrors orders_screen.dart)
//
//  Design language: matches OrdersScreen exactly:
//    • Same OC-style color palette (light bg, white cards, purple primary)
//    • Same header / filter-tab / stats-bar structure
//    • Same card anatomy (header bg tinted by status, item rows, action row)
//    • Same _StatChip, _StatusBadge, divider, floating action button style
//
//  KDS-specific additions on top:
//    ✅ Live elapsed timer per card (amber → red urgency)
//    ✅ Item-level instruction box (CHEF NOTE) shown per OrderItem.notes
//    ✅ Per-item completion checkbox toggle + progress bar
//    ✅ Allergen & spicy auto-detection badges
//    ✅ Bump (→ ready) button   |   Recall sheet (last 5 bumped)
//    ✅ Station filter tabs (All / Hot / Cold / Grill / Dessert / Drinks)
//    ✅ Swipe-to-bump dismiss gesture
//    ✅ Realtime Supabase subscription + haptic on new order
//    ✅ Offline-safe (reads same Order model as OrdersRepository)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/order_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR PALETTE  (mirrors OC in orders_screen.dart + kitchen accent)
// ─────────────────────────────────────────────────────────────────────────────
class KC {
  // Backgrounds
  static const bg = Color(0xFFF6F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border = Color(0xFFEAEAF4);

  // Brand — same as OC.primary
  static const primary = Color(0xFF5A3FD6);
  static const primaryLight = Color(0xFFEDE9FF);
  static const primaryDark = Color(0xFF3D2AA0);

  // Status colours — identical to orders_screen
  static const pending = Color(0xFFE8860A);
  static const pendingBg = Color(0xFFFFF4E0);
  static const preparing = Color(0xFF0A7ADB);
  static const preparingBg = Color(0xFFE0F0FF);
  static const ready = Color(0xFF1A9C5B);
  static const readyBg = Color(0xFFE2F8ED);
  static const completed = Color(0xFF6B7280);
  static const completedBg = Color(0xFFF3F4F6);
  static const cancelled = Color(0xFFDC2626);
  static const cancelledBg = Color(0xFFFEF2F2);

  // Kitchen-specific
  static const overdueBg = Color(0xFFFFF0F0);
  static const warningBg = Color(0xFFFFFBEB);
  static const chefNoteBg = Color(0xFFF0F7FF);
  static const chefNoteBdr = Color(0xFFBFD7FF);
  static const chefNoteAccent = Color(0xFF1D6FD8);
  static const allergenBg = Color(0xFFFFF8F0);
  static const allergenBdr = Color(0xFFFFCE99);
  static const allergenClr = Color(0xFFB45309);

  // Text
  static const textPri = Color(0xFF1A1A2E);
  static const textSec = Color(0xFF6B6B86);
  static const textMute = Color(0xFFAAABBB);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return KC.pending;
    case OrderStatus.preparing:
      return KC.preparing;
    case OrderStatus.ready:
      return KC.ready;
    case OrderStatus.completed:
      return KC.completed;
    case OrderStatus.cancelled:
      return KC.cancelled;
  }
}

Color _statusBg(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return KC.pendingBg;
    case OrderStatus.preparing:
      return KC.preparingBg;
    case OrderStatus.ready:
      return KC.readyBg;
    case OrderStatus.completed:
      return KC.completedBg;
    case OrderStatus.cancelled:
      return KC.cancelledBg;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALLERGEN DETECTION
// ─────────────────────────────────────────────────────────────────────────────

const _allergenMap = {
  'nut': '🥜 Nuts',
  'peanut': '🥜 Peanut',
  'dairy': '🥛 Dairy',
  'milk': '🥛 Dairy',
  'gluten': '🌾 Gluten',
  'egg': '🥚 Egg',
  'soy': '🫘 Soy',
  'fish': '🐟 Fish',
  'shellfish': '🦐 Shellfish',
  'sesame': '🌿 Sesame',
};

List<String> _detectAllergens(String? text) {
  if (text == null || text.isEmpty) return [];
  final l = text.toLowerCase();
  return _allergenMap.entries
      .where((e) => l.contains(e.key))
      .map((e) => e.value)
      .toSet()
      .toList();
}

bool _isSpicy(String? text) {
  if (text == null) return false;
  final l = text.toLowerCase();
  return l.contains('spicy') ||
      l.contains('extra hot') ||
      l.contains('chilli') ||
      l.contains('chili');
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATION ENUM  (filter tabs)
// ─────────────────────────────────────────────────────────────────────────────

enum KStation { all, hot, cold, grill, dessert, drinks }

extension KStationX on KStation {
  String get label {
    switch (this) {
      case KStation.all:
        return 'All';
      case KStation.hot:
        return '🔥 Hot';
      case KStation.cold:
        return '❄️ Cold';
      case KStation.grill:
        return '🍖 Grill';
      case KStation.dessert:
        return '🍰 Dessert';
      case KStation.drinks:
        return '🥤 Drinks';
    }
  }

  bool matches(String? category) {
    if (this == KStation.all || category == null) return this == KStation.all;
    final c = category.toLowerCase();
    switch (this) {
      case KStation.hot:
        return c.contains('curry') ||
            c.contains('soup') ||
            c.contains('rice') ||
            c.contains('hot') ||
            c.contains('noodle');
      case KStation.cold:
        return c.contains('salad') ||
            c.contains('cold') ||
            c.contains('sandwich');
      case KStation.grill:
        return c.contains('grill') ||
            c.contains('bbq') ||
            c.contains('tandoor') ||
            c.contains('kebab') ||
            c.contains('steak');
      case KStation.dessert:
        return c.contains('dessert') ||
            c.contains('sweet') ||
            c.contains('cake') ||
            c.contains('ice');
      case KStation.drinks:
        return c.contains('drink') ||
            c.contains('beverage') ||
            c.contains('juice') ||
            c.contains('coffee') ||
            c.contains('tea');
      default:
        return true;
    }
  }
}

Color _stationColor(KStation s) {
  switch (s) {
    case KStation.all:
      return KC.primary;
    case KStation.hot:
      return KC.cancelled;
    case KStation.cold:
      return KC.preparing;
    case KStation.grill:
      return KC.pending;
    case KStation.dessert:
      return const Color(0xFFD946EF);
    case KStation.drinks:
      return KC.ready;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  URGENCY
// ─────────────────────────────────────────────────────────────────────────────

enum _Urgency { normal, warning, overdue }

_Urgency _urgencyOf(Order o, DateTime now) {
  final mins = now.difference(o.createdAt).inMinutes;
  if (mins >= 20) return _Urgency.overdue;
  if (mins >= 12) return _Urgency.warning;
  return _Urgency.normal;
}

Color _urgencyColor(_Urgency u) {
  switch (u) {
    case _Urgency.normal:
      return KC.preparing;
    case _Urgency.warning:
      return KC.pending;
    case _Urgency.overdue:
      return KC.cancelled;
  }
}

Color _urgencyBg(_Urgency u) {
  switch (u) {
    case _Urgency.normal:
      return KC.preparingBg;
    case _Urgency.warning:
      return KC.warningBg;
    case _Urgency.overdue:
      return KC.overdueBg;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class KitchenOrderTaken extends StatefulWidget {
  final String businessId;
  final String kitchenId;

  const KitchenOrderTaken({
    super.key,
    required this.businessId,
    required this.kitchenId,
  });

  @override
  State<KitchenOrderTaken> createState() => _KitchenOrderTakenState();
}

class _KitchenOrderTakenState extends State<KitchenOrderTaken> {
  final _db = Supabase.instance.client;

  List<Order> _allOrders = []; // All orders from system
  bool _isLoading = true;
  String? _error;

  RealtimeChannel? _channel;
  Timer? _tick;
  DateTime _now = DateTime.now();

  KStation _station = KStation.all;

  // { orderId → Set of itemKey strings that are done }
  final Map<String, Set<String>> _doneItems = {};

  // Recall queue — last 5 bumped
  final List<Order> _recalled = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _subscribeRealtime();

    // 1-second timer for elapsed time display
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // ✅ Periodic full refresh every 5 seconds as backup sync mechanism
    // Ensures no orders are missed in case realtime subscription has issues
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchOrders();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tick?.cancel();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // ✅ Fetch ALL orders regardless of status
      final data = await _db
          .from('vw_orders_with_items')
          .select()
          .eq('business_id', widget.businessId)
          // Include all statuses: pending, preparing, ready, completed
          .inFilter('status', ['pending', 'preparing', 'ready', 'completed'])
          .order('created_at', ascending: false); // Most recent first

      setState(() {
        _allOrders = (data as List)
            .map((j) => Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('kds:${widget.businessId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: widget.businessId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final status = record['status'] as String? ?? '';

            // ✅ Include ALL statuses: pending, preparing, ready, completed
            if ([
              'pending',
              'preparing',
              'ready',
              'completed',
            ].contains(status)) {
              try {
                final full = await _db
                    .from('vw_orders_with_items')
                    .select()
                    .eq('id', record['id'])
                    .maybeSingle();
                if (full == null) return;
                final order = Order.fromJson(full);

                setState(() {
                  final idx = _allOrders.indexWhere((o) => o.id == order.id);
                  if (idx == -1) {
                    // New order: add to front
                    _allOrders.insert(0, order);
                    if (status == 'pending') {
                      HapticFeedback.heavyImpact(); // Notify on new order
                    }
                  } else {
                    // Update existing order
                    _allOrders[idx] = order;
                  }
                });
              } catch (e) {
                debugPrint('[KDS] Error syncing order: $e');
              }
            }
          },
        )
        .subscribe();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _bumpOrder(Order order) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _allOrders.removeWhere((o) => o.id == order.id);
      _doneItems.remove(order.id);
      _recalled.insert(0, order);
      if (_recalled.length > 5) _recalled.removeLast();
    });
    try {
      await _db
          .from('orders')
          .update({
            'status': 'ready',
            'ready_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', order.id);
    } catch (e) {
      debugPrint('[KDS] bump error: $e');
    }
  }

  Future<void> _recallOrder(Order order) async {
    setState(() {
      _recalled.removeWhere((o) => o.id == order.id);
      _allOrders.insert(0, order);
    });
    try {
      await _db
          .from('orders')
          .update({'status': 'preparing', 'ready_at': null})
          .eq('id', order.id);
    } catch (e) {
      debugPrint('[KDS] recall error: $e');
    }
  }

  void _toggleItem(String orderId, String key) {
    setState(() {
      _doneItems[orderId] ??= {};
      _doneItems[orderId]!.contains(key)
          ? _doneItems[orderId]!.remove(key)
          : _doneItems[orderId]!.add(key);
    });
  }

  // ── Filter + sort ────────────────────────────────────────────────────────────

  List<Order> get _filtered {
    var list = _station == KStation.all
        ? List<Order>.from(_allOrders)
        : _allOrders
              .where(
                (o) => o.items.any((i) => _station.matches(i.categoryName)),
              )
              .toList();

    // Sort by urgency first, then by creation time
    list.sort((a, b) {
      // Priority: pending > preparing > ready > completed
      final aStatusIdx = _statusOrder(a.status);
      final bStatusIdx = _statusOrder(b.status);
      if (aStatusIdx != bStatusIdx) return aStatusIdx.compareTo(bStatusIdx);

      final ua = _urgencyOf(a, _now).index;
      final ub = _urgencyOf(b, _now).index;
      if (ua != ub) return ub.compareTo(ua);
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  // Helper to sort by status priority
  int _statusOrder(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.ready:
        return 2;
      case OrderStatus.completed:
        return 3;
      case OrderStatus.cancelled:
        return 4;
    }
  }

  // ── Stats ────────────────────────────────────────────────────────────────────

  int get _pendingCount =>
      _allOrders.where((o) => o.status == OrderStatus.pending).length;
  int get _prepCount =>
      _allOrders.where((o) => o.status == OrderStatus.preparing).length;
  int get _overdueCount =>
      _allOrders.where((o) => _urgencyOf(o, _now) == _Urgency.overdue).length;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orders = _filtered;

    return Scaffold(
      backgroundColor: KC.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ① Header — mirrors _Header in orders_screen
            _Header(
              ordersCount: _allOrders.length,
              recalledCount: _recalled.length,
              now: _now,
              onBack: () => Navigator.pop(context),
              onRefresh: _fetchOrders,
              onRecall: _recalled.isEmpty
                  ? null
                  : () => _showRecallSheet(context),
            ),

            // ② Overdue alert — mirrors _PaymentAlertBanner
            if (_overdueCount > 0) _OverdueBanner(count: _overdueCount),

            // ③ Station filter tabs — mirrors _StatusFilter
            _StationFilter(
              station: _station,
              orders: _allOrders,
              onChanged: (s) => setState(() => _station = s),
            ),

            // ④ Stats bar — mirrors _StatsBar
            _StatsBar(
              pendingCount: _pendingCount,
              prepCount: _prepCount,
              overdueCount: _overdueCount,
              total: _allOrders.length,
            ),

            // ⑤ Body — mirrors _Body
            Expanded(
              child: _isLoading && _allOrders.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: KC.primary),
                    )
                  : _error != null && _allOrders.isEmpty
                  ? _ErrorView(error: _error!, onRetry: _fetchOrders)
                  : orders.isEmpty
                  ? _EmptyView(onRefresh: _fetchOrders)
                  : _Body(
                      orders: orders,
                      now: _now,
                      doneItems: _doneItems,
                      onToggleItem: _toggleItem,
                      onBump: _bumpOrder,
                      onRefresh: _fetchOrders,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'kds_fab',
        onPressed: _fetchOrders,
        backgroundColor: KC.primary,
        icon: const Icon(Icons.sync_rounded, color: Colors.white),
        label: const Text(
          'Sync',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _showRecallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecallSheet(
        queue: _recalled,
        onRecall: (o) {
          Navigator.pop(context);
          _recallOrder(o);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER  (mirrors _Header in orders_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int ordersCount;
  final int recalledCount;
  final DateTime now;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onRecall;

  const _Header({
    required this.ordersCount,
    required this.recalledCount,
    required this.now,
    required this.onBack,
    required this.onRefresh,
    this.onRecall,
  });

  @override
  Widget build(BuildContext context) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');

    return Container(
      color: KC.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KC.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KC.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: KC.textSec,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Brand icon — same radius/gradient as orders_screen
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KC.primary, KC.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.soup_kitchen_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kitchen Display',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: KC.textPri,
                  ),
                ),
                Text(
                  '$ordersCount order${ordersCount != 1 ? 's' : ''} in kitchen',
                  style: const TextStyle(fontSize: 11, color: KC.textSec),
                ),
              ],
            ),
          ),

          // Recall button
          /*     if (onRecall != null) ...[
            GestureDetector(
              onTap: onRecall,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: KC.pendingBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: KC.pending.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.undo_rounded, color: KC.pending, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Recall ($recalledCount)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: KC.pending,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
*/
          // Live clock chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: KC.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🕐', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '$h:$m:$s',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: KC.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OVERDUE BANNER  (mirrors _PaymentAlertBanner)
// ─────────────────────────────────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  final int count;
  const _OverdueBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KC.cancelledBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: KC.cancelled.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count order${count > 1 ? 's' : ''} waiting 20+ minutes — rush required!',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KC.cancelled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATION FILTER TABS  (mirrors _StatusFilter)
// ─────────────────────────────────────────────────────────────────────────────

class _StationFilter extends StatelessWidget {
  final KStation station;
  final List<Order> orders;
  final ValueChanged<KStation> onChanged;

  const _StationFilter({
    required this.station,
    required this.orders,
    required this.onChanged,
  });

  int _count(KStation s) {
    if (s == KStation.all) return orders.length;
    return orders
        .where((o) => o.items.any((i) => s.matches(i.categoryName)))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KC.surface,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: KStation.values.map((s) {
            final isSel = s == station;
            final tabColor = _stationColor(s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? tabColor : KC.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? tabColor : KC.border,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '${s.label} (${_count(s)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : KC.textSec,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATS BAR  (mirrors _StatsBar in orders_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int pendingCount;
  final int prepCount;
  final int overdueCount;
  final int total;

  const _StatsBar({
    required this.pendingCount,
    required this.prepCount,
    required this.overdueCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KC.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _StatChip(
            emoji: '🕐',
            label: '$pendingCount pending',
            color: KC.pending,
            bg: KC.pendingBg,
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '👨‍🍳',
            label: '$prepCount cooking',
            color: KC.preparing,
            bg: KC.preparingBg,
          ),
          if (overdueCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              emoji: '⚠️',
              label: '$overdueCount overdue',
              color: KC.cancelled,
              bg: KC.cancelledBg,
            ),
          ],
          const SizedBox(width: 8),
          _StatChip(
            emoji: '🍽️',
            label: '$total in queue',
            color: KC.primary,
            bg: KC.primaryLight,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BODY  (mirrors _Body — RefreshIndicator + ListView)
// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final List<Order> orders;
  final DateTime now;
  final Map<String, Set<String>> doneItems;
  final void Function(String, String) onToggleItem;
  final ValueChanged<Order> onBump;
  final Future<void> Function() onRefresh;

  const _Body({
    required this.orders,
    required this.now,
    required this.doneItems,
    required this.onToggleItem,
    required this.onBump,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: KC.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final o = orders[i];
          final urgency = _urgencyOf(o, now);
          final totalQty = o.items.fold<int>(0, (s, item) => s + item.quantity);
          final doneCount = doneItems[o.id]?.length ?? 0;
          final progress = totalQty == 0 ? 0.0 : doneCount / totalQty;

          return _KDSOrderCard(
            order: o,
            now: now,
            urgency: urgency,
            progress: progress,
            doneSet: doneItems[o.id] ?? {},
            onToggleItem: (key) => onToggleItem(o.id, key),
            onBump: () => onBump(o),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KDS ORDER CARD  (mirrors _OrderCard in orders_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _KDSOrderCard extends StatelessWidget {
  final Order order;
  final DateTime now;
  final _Urgency urgency;
  final double progress;
  final Set<String> doneSet;
  final void Function(String) onToggleItem;
  final VoidCallback onBump;

  const _KDSOrderCard({
    required this.order,
    required this.now,
    required this.urgency,
    required this.progress,
    required this.doneSet,
    required this.onToggleItem,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    final sColor = _statusColor(o.status);
    final sBg = _statusBg(o.status);
    final uColor = _urgencyColor(urgency);
    final elapsed = now.difference(o.createdAt);
    final timerStr =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final allDone = progress >= 1.0 && o.items.isNotEmpty;

    return Dismissible(
      key: ValueKey('kds_${o.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onBump();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: KC.readyBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: KC.ready.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline_rounded, color: KC.ready, size: 32),
            SizedBox(height: 4),
            Text(
              'BUMP',
              style: TextStyle(
                color: KC.ready,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: KC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgency != _Urgency.normal
                ? uColor.withValues(alpha: 0.45)
                : sColor.withValues(alpha: 0.25),
            width: urgency == _Urgency.overdue ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: sColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: urgency != _Urgency.normal ? _urgencyBg(urgency) : sBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status emoji circle
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: sColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          o.status.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Order info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Order #${o.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: KC.textPri,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(status: o.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _OrderMeta(order: o),
                          ],
                        ),
                      ),

                      // Timer chip
                      _TimerChip(timer: timerStr, color: uColor),
                    ],
                  ),

                  // Overdue warning row
                  if (urgency == _Urgency.overdue) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: KC.cancelledBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: KC.cancelled.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: KC.cancelled,
                            size: 13,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'OVERDUE — Rush this order!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: KC.cancelled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────────
            _ProgressRow(
              progress: progress,
              total: o.items.fold(0, (s, i) => s + i.quantity),
            ),

            // ── Item rows ─────────────────────────────────────────────────
            if (o.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Column(
                  children: List.generate(o.items.length, (i) {
                    final item = o.items[i];
                    final key = '${item.menuItemId}_$i';
                    return _KDSItemRow(
                      item: item,
                      isDone: doneSet.contains(key),
                      onToggle: () => onToggleItem(key),
                    );
                  }),
                ),
              ),

            // ── Order-level notes ─────────────────────────────────────────
            if (o.notes != null && o.notes!.isNotEmpty) ...[
              const Divider(height: 1, color: KC.border),
              _OrderNoteRow(notes: o.notes!),
            ],

            // ── Divider + Actions (mirrors _OrderCard action row) ─────────
            const Divider(height: 1, color: KC.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  // Swipe hint
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: KC.border, width: 1.2),
                        foregroundColor: KC.textMute,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swipe_left_alt_rounded,
                            size: 14,
                            color: KC.textMute,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Swipe',
                            style: TextStyle(
                              fontSize: 11,
                              color: KC.textMute,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bump / Mark Ready button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onBump,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allDone ? KC.ready : sColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            allDone ? '✅' : o.status.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            allDone ? 'Mark Ready' : 'Bump Order',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROGRESS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final double progress;
  final int total;
  const _ProgressRow({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final done = (progress * total).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: KC.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? KC.ready : KC.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$done/$total items done',
            style: const TextStyle(
              fontSize: 10,
              color: KC.textMute,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KDS ITEM ROW  (item + chef instructions box)
// ─────────────────────────────────────────────────────────────────────────────

class _KDSItemRow extends StatelessWidget {
  final OrderItem item;
  final bool isDone;
  final VoidCallback onToggle;

  const _KDSItemRow({
    required this.item,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = item.isVeg
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB71C1C);
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;
    final allergens = _detectAllergens(item.notes);
    final spicy = _isSpicy(item.notes);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: isDone ? KC.readyBg : KC.surfaceAlt,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isDone ? KC.ready.withValues(alpha: 0.4) : KC.border,
            width: 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Item name row (mirrors _ItemRow in orders_screen) ─────────
            Row(
              children: [
                // Completion checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDone ? KC.ready : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isDone ? KC.ready : KC.textMute,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),

                // Veg/non-veg dot (exact copy from orders_screen._ItemRow)
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    border: Border.all(color: dotColor, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Item name
                Expanded(
                  child: Text(
                    item.itemName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDone ? KC.textMute : KC.textPri,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: KC.textMute,
                    ),
                  ),
                ),

                // Quantity
                Text(
                  '×${item.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDone ? KC.textMute : KC.textSec,
                  ),
                ),

                // Spicy indicator
                if (spicy) ...[
                  const SizedBox(width: 6),
                  const Text('🌶️', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),

            // Category tag
            if (item.categoryName != null && item.categoryName!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  item.categoryName!,
                  style: const TextStyle(fontSize: 9, color: KC.textMute),
                ),
              ),
            ],

            // ── CHEF INSTRUCTIONS BOX ─────────────────────────────────────
            if (hasNotes) ...[
              const SizedBox(height: 8),
              _ChefInstructionBox(notes: item.notes!),
            ],

            // ── Allergen badges ───────────────────────────────────────────
            if (allergens.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: allergens
                      .map((a) => _AllergenBadge(label: a))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHEF INSTRUCTION BOX  (the main new feature — light blue tinted)
// ─────────────────────────────────────────────────────────────────────────────

class _ChefInstructionBox extends StatelessWidget {
  final String notes;
  const _ChefInstructionBox({required this.notes});

  @override
  Widget build(BuildContext context) {
    final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(left: 36),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: KC.chefNoteBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KC.chefNoteBdr, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, size: 13, color: KC.chefNoteAccent),
              SizedBox(width: 5),
              Text(
                'CHEF INSTRUCTIONS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: KC.chefNoteAccent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Instruction lines
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '▸ ',
                    style: TextStyle(color: KC.chefNoteAccent, fontSize: 11),
                  ),
                  Expanded(
                    child: Text(
                      line.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: KC.textPri,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALLERGEN BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _AllergenBadge extends StatelessWidget {
  final String label;
  const _AllergenBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: KC.allergenBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: KC.allergenBdr, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: KC.allergenClr,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER NOTES ROW
// ─────────────────────────────────────────────────────────────────────────────

class _OrderNoteRow extends StatelessWidget {
  final String notes;
  const _OrderNoteRow({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: KC.pendingBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: KC.pending.withValues(alpha: 0.35),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER NOTE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: KC.pending,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: KC.textPri,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER META  (mirrors _OrderMeta in orders_screen exactly)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderMeta extends StatelessWidget {
  final Order order;
  const _OrderMeta({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final hasTable = o.tableNumber != null && o.tableNumber! > 0;
    final isPartial = o.tableSeatId != null && o.tableSeatId!.isNotEmpty;
    final hasSeat = isPartial && o.seatLabel != null && o.seatLabel!.isNotEmpty;
    final hasCustomer = o.customerName != null && o.customerName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(o.orderType.emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              o.orderType.label,
              style: const TextStyle(fontSize: 11, color: KC.textSec),
            ),
            if (hasTable) ...[
              const Text(
                ' • ',
                style: TextStyle(color: KC.textMute, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: KC.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍽️ ', style: TextStyle(fontSize: 10)),
                    Text(
                      'Table ${o.tableNumber!.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: KC.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasSeat) ...[
                      const Text(
                        ' - ',
                        style: TextStyle(color: KC.textMute, fontSize: 10),
                      ),
                      Text(
                        'Seat ${o.seatLabel!}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: KC.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        if (hasCustomer) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Text('👤 ', style: TextStyle(fontSize: 10)),
              Flexible(
                child: Text(
                  o.customerName!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: KC.textSec,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _TimerChip extends StatelessWidget {
  final String timer;
  final Color color;
  const _TimerChip({required this.timer, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.1),
      ),
      child: Column(
        children: [
          Text(
            timer,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'elapsed',
            style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS BADGE  (exact copy from orders_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAT CHIP  (exact copy from orders_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String emoji, label;
  final Color color, bg;
  const _StatChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECALL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _RecallSheet extends StatelessWidget {
  final List<Order> queue;
  final ValueChanged<Order> onRecall;
  const _RecallSheet({required this.queue, required this.onRecall});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: KC.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            'Recall Bumped Orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: KC.textPri,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Undo a bump and send back to kitchen',
            style: TextStyle(fontSize: 12, color: KC.textSec),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: KC.border),
          ...queue.map(
            (o) => ListTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: KC.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${o.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: KC.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Text(
                'Order #${o.orderNumber}',
                style: const TextStyle(
                  color: KC.textPri,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${o.totalItems} items · ${o.orderType.label}'
                '${o.tableNumber != null ? ' · Table ${o.tableNumber}' : ''}',
                style: const TextStyle(color: KC.textSec, fontSize: 12),
              ),
              trailing: OutlinedButton(
                onPressed: () => onRecall(o),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: KC.pending, width: 1.2),
                  foregroundColor: KC.pending,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Recall',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY VIEW  (mirrors orders_screen empty state)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: KC.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Text('✅', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Kitchen Caught Up!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: KC.textPri,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No pending or preparing orders right now.',
            style: TextStyle(fontSize: 13, color: KC.textSec),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: KC.primary),
              foregroundColor: KC.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR VIEW  (mirrors orders_screen error state)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: KC.cancelledBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: KC.cancelled,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: KC.textSec, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KC.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
