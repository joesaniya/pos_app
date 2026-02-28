// lib/screens/orders/orders_screen.dart
// Full Orders Screen — Supabase real data, realtime updates, role-aware

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/screens/new_order_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/orders_provider.dart';


// ── Design tokens ──────────────────────────────────────────────
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
  static const occupied   = Color(0xFFDC2626);
  static const reserved   = Color(0xFF7C3AED);
  static const available  = Color(0xFF059669);
}

// ══════════════════════════════════════════════════════════════
//  ORDERS SCREEN
// ══════════════════════════════════════════════════════════════
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<OrdersProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: _C.bg,
          floatingActionButton: _NewOrderFAB(prov: prov),
          body: SafeArea(
            child: Column(
              children: [
                _Header(prov: prov),
                _StatusTabs(prov: prov),
                // ── Table status summary (company-only tables/reservations) ──
                if (prov.isAdminLevel) _TableStatusBar(businessId: prov.businessId),
                Expanded(
                  child: prov.isLoading
                      ? const Center(child: CircularProgressIndicator(color: _C.primary))
                      : prov.error != null
                          ? _ErrorView(error: prov.error!, onRetry: prov.fetchOrders)
                          : prov.filteredOrders.isEmpty
                              ? const _EmptyState()
                              : _OrderList(prov: prov),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final OrdersProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _C.textPri),
                ),
              ),
              const SizedBox(width: 14),
              // Icon + title
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.textPri)),
                    Text('${prov.todayTotal} orders today', style: const TextStyle(fontSize: 11, color: _C.textSec)),
                  ],
                ),
              ),
              // Revenue chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _C.primaryL, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '₹${prov.todayRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.primary),
                    ),
                  ],
                ),
              ),
              // Notification bell
              const SizedBox(width: 8),
              _NotifBell(prov: prov),
            ],
          ),
          const SizedBox(height: 12),
          // Status summary pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OrderStatus.values.map((s) {
                final count = prov.countByStatus(s);
                if (count == 0) return const SizedBox.shrink();
                return _StatusPill(status: s, count: count);
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final OrdersProvider prov;
  const _NotifBell({required this.prov});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showNotifications(context, prov),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.notifications_outlined, size: 20, color: _C.textSec),
          ),
          if (prov.unreadCount > 0)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: _C.occupied, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${prov.unreadCount > 9 ? '9+' : prov.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, OrdersProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(prov: prov),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  final OrdersProvider prov;
  const _NotificationsSheet({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPri)),
                TextButton(
                  onPressed: () { prov.markNotificationsRead(); Navigator.pop(context); },
                  child: const Text('Mark all read', style: TextStyle(color: _C.primary, fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          if (prov.notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Text('🔔', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('No new notifications', style: TextStyle(color: _C.textSec)),
                ],
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: prov.notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
                itemBuilder: (_, i) {
                  final n = prov.notifications[i];
                  return ListTile(
                    leading: const Text('🔔', style: TextStyle(fontSize: 22)),
                    title: Text(n['title'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPri)),
                    subtitle: Text(n['body'] as String? ?? '', style: const TextStyle(fontSize: 11, color: _C.textSec)),
                    dense: true,
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Table status bar (company tables occupied/reserved count) ───
class _TableStatusBar extends StatefulWidget {
  final String businessId;
  const _TableStatusBar({required this.businessId});

  @override
  State<_TableStatusBar> createState() => _TableStatusBarState();
}

class _TableStatusBarState extends State<_TableStatusBar> {
  int occupied = 0, reserved = 0, available = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.businessId.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('restaurant_tables')
          .select('status')
          .eq('business_id', widget.businessId)
          .eq('is_active', true);

      final rows = data as List;
      setState(() {
        occupied  = rows.where((r) => r['status'] == 'occupied').length;
        reserved  = rows.where((r) => r['status'] == 'reserved').length;
        available = rows.where((r) => r['status'] == 'available').length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          const Text('Tables:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.textSec)),
          const SizedBox(width: 8),
          _TableChip(label: '$occupied Occupied', color: _C.occupied),
          const SizedBox(width: 6),
          _TableChip(label: '$reserved Reserved', color: _C.reserved),
          const SizedBox(width: 6),
          _TableChip(label: '$available Free', color: _C.available),
        ],
      ),
    );
  }
}

class _TableChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TableChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Status pill ─────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final OrderStatus status;
  final int count;
  const _StatusPill({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text('$count ${status.label}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
        ],
      ),
    );
  }
}

// ── Status tabs ─────────────────────────────────────────────────
class _StatusTabs extends StatelessWidget {
  final OrdersProvider prov;
  const _StatusTabs({required this.prov});

  @override
  Widget build(BuildContext context) {
    const tabs = <(OrderStatus?, String)>[
      (null, 'All'),
      (OrderStatus.pending, 'Pending'),
      (OrderStatus.preparing, 'Preparing'),
      (OrderStatus.ready, 'Ready'),
      (OrderStatus.completed, 'Done'),
    ];

    return Container(
      color: _C.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: _C.border),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: tabs.map((t) {
                final (status, label) = t;
                final count = status == null ? prov.todayTotal : prov.countByStatus(status);
                final isSel = prov.filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => prov.setFilter(status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? _C.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$label ($count)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : _C.textSec,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: _C.border),
        ],
      ),
    );
  }
}

// ── Order list ──────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final OrdersProvider prov;
  const _OrderList({required this.prov});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: prov.fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        itemCount: prov.filteredOrders.length,
        itemBuilder: (_, i) {
          final order = prov.filteredOrders[i];
          return _OrderCard(
            order: order,
            prov:  prov,
            onTap: () => _showDetail(context, order, prov),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext ctx, Order order, OrdersProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _OrderDetailSheet(orderId: order.id),
      ),
    );
  }
}

// ── Order card ──────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final OrdersProvider prov;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.prov, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = order.isActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? order.status.color.withOpacity(0.3) : _C.border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? order.status.color.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: order.status.bgColor, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(order.status.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('#${order.orderNumber}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.textPri)),
                            const SizedBox(width: 8),
                            _Chip(text: order.status.label, color: order.status.color, bg: order.status.bgColor),
                            const SizedBox(width: 6),
                            _Chip(text: order.orderType.emoji, color: _C.textSec, bg: _C.surfaceAlt),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (order.tableNumber != null) ...[
                              const Icon(Icons.table_restaurant_outlined, size: 12, color: _C.textMute),
                              const SizedBox(width: 3),
                              Text('Table ${order.tableNumber}', style: const TextStyle(fontSize: 11, color: _C.textSec)),
                              const SizedBox(width: 8),
                            ],
                            if (order.customerName != null) ...[
                              const Icon(Icons.person_outline, size: 12, color: _C.textMute),
                              const SizedBox(width: 3),
                              Text(order.customerName!, style: const TextStyle(fontSize: 11, color: _C.textSec)),
                            ],
                            const SizedBox(width: 8),
                            Text('by ${order.createdByName}', style: const TextStyle(fontSize: 10, color: _C.textMute)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(order.timeLabel, style: const TextStyle(fontSize: 11, color: _C.textMute)),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: _C.border),
            // Items preview
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  ...order.items.take(3).map((li) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _C.primaryL, borderRadius: BorderRadius.circular(6)),
                          child: Text('${li.quantity}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.primary)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(li.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.textPri))),
                        Text('₹${li.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textSec)),
                      ],
                    ),
                  )),
                  if (order.items.length > 3)
                    Text('+${order.items.length - 3} more items', style: const TextStyle(fontSize: 11, color: _C.textMute)),
                ],
              ),
            ),
            // Total + actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: _C.surfaceAlt,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textSec)),
                      Text('₹${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.primary)),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    _ActionButtons(order: order, prov: prov),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action buttons ──────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final Order order;
  final OrdersProvider prov;
  const _ActionButtons({required this.order, required this.prov});

  @override
  Widget build(BuildContext context) {
    final next = order.status.nextStatus;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _confirmCancel(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 6),
                  Text('Cancel', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (next != null)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => prov.advanceOrder(order.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [next.color, next.color.withOpacity(0.75)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: next.color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(next.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(order.status.nextLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel #${order.orderNumber}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This order will be marked as cancelled.', style: TextStyle(color: _C.textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep', style: TextStyle(color: _C.textSec))),
          ElevatedButton(
            onPressed: () { prov.cancelOrder(order.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }
}

// ── Order Detail Sheet ──────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final String orderId;
  const _OrderDetailSheet({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (_, prov, __) {
        final order = prov.allOrders.firstWhere((o) => o.id == orderId, orElse: () => throw Exception());

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(color: _C.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 6),
                    decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2))),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: order.status.bgColor, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(order.status.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Order #${order.orderNumber}',
                                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _C.textPri)),
                                const SizedBox(width: 8),
                                _Chip(text: order.status.label, color: order.status.color, bg: order.status.bgColor),
                              ],
                            ),
                            Text(
                              [
                                if (order.tableNumber != null) 'Table ${order.tableNumber}',
                                if (order.customerName != null) order.customerName!,
                                order.orderType.label,
                                'by ${order.createdByName}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12, color: _C.textSec),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _C.border),
                Expanded(
                  child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // Items
                      const Text('ORDER ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textMute, letterSpacing: 1.4)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(color: _C.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
                        child: Column(
                          children: order.items.asMap().entries.map((e) {
                            final li = e.value;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24, height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: _C.primaryL, borderRadius: BorderRadius.circular(6)),
                                        child: Text('${li.quantity}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _C.primary)),
                                      ),
                                      const SizedBox(width: 10),
                                      _VegDot(isVeg: li.isVeg),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(li.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.textPri)),
                                            if (li.notes != null) Text(li.notes!, style: const TextStyle(fontSize: 11, color: _C.textMute)),
                                          ],
                                        ),
                                      ),
                                      Text('₹${li.subtotal.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.textPri)),
                                    ],
                                  ),
                                ),
                                if (e.key < order.items.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: _C.border),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Bill
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _C.primaryL, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _BillRow('Subtotal', '₹${order.subtotal.toStringAsFixed(0)}'),
                            const SizedBox(height: 6),
                            _BillRow('Tax (${order.taxRate.toStringAsFixed(0)}%)', '₹${order.taxAmount.toStringAsFixed(0)}'),
                            if (order.discountAmount > 0) ...[
                              const SizedBox(height: 6),
                              _BillRow('Discount', '-₹${order.discountAmount.toStringAsFixed(0)}'),
                            ],
                            const Divider(color: _C.border, height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.primary)),
                                Text('₹${order.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8860A).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Text('📝', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.notes!, style: const TextStyle(fontSize: 13, color: _C.textSec))),
                            ],
                          ),
                        ),
                      ],
                      // Action buttons
                      if (order.isActive || order.status == OrderStatus.ready) ...[
                        const SizedBox(height: 20),
                        _ActionButtons(order: order, prov: prov),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _Chip({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _VegDot extends StatelessWidget {
  final bool isVeg;
  const _VegDot({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label, value;
  const _BillRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _C.textSec)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPri)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: _C.primaryL, shape: BoxShape.circle),
              child: const Text('🧾', style: TextStyle(fontSize: 44))),
          const SizedBox(height: 18),
          const Text('No orders here', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPri)),
          const SizedBox(height: 6),
          const Text('Tap + New Order to get started', style: TextStyle(fontSize: 13, color: _C.textSec)),
        ],
      ),
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
          const Text('Failed to load orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPri)),
          const SizedBox(height: 6),
          Text(error, style: const TextStyle(fontSize: 12, color: _C.textSec), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── FAB ─────────────────────────────────────────────────────────
class _NewOrderFAB extends StatelessWidget {
  final OrdersProvider prov;
  const _NewOrderFAB({required this.prov});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ChangeNotifierProvider.value(
            value: prov,
            child: const NewOrderScreen(),
          ),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.primary, _C.primaryD]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('New Order', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}