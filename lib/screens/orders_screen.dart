import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/menu_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class OC {
  static const bg = Color(0xFFF6F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border = Color(0xFFEAEAF4);

  static const primary = Color(0xFF5A3FD6);
  static const primaryLight = Color(0xFFEDE9FF);
  static const primaryDark = Color(0xFF3D2AA0);

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

  static const textPri = Color(0xFF1A1A2E);
  static const textSec = Color(0xFF6B6B86);
  static const textMute = Color(0xFFAAABBB);
}

Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return OC.pending;
    case OrderStatus.preparing:
      return OC.preparing;
    case OrderStatus.ready:
      return OC.ready;
    case OrderStatus.completed:
      return OC.completed;
    case OrderStatus.cancelled:
      return OC.cancelled;
  }
}

Color _statusBg(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return OC.pendingBg;
    case OrderStatus.preparing:
      return OC.preparingBg;
    case OrderStatus.ready:
      return OC.readyBg;
    case OrderStatus.completed:
      return OC.completedBg;
    case OrderStatus.cancelled:
      return OC.cancelledBg;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════════════════════
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: const _OrdersBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MAIN BODY
// ═════════════════════════════════════════════════════════════════════════════
class _OrdersBody extends StatelessWidget {
  const _OrdersBody();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<OrdersProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: OC.bg,
          floatingActionButton: _NewOrderFAB(
            onTap: () => _openNewOrder(context, prov),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _OrdersHeader(provider: prov),
                _StatusTabBar(provider: prov),
                Expanded(
                  child: prov.filteredOrders.isEmpty
                      ? const _EmptyOrders()
                      : _OrdersList(
                          orders: prov.filteredOrders,
                          provider: prov,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNewOrder(BuildContext context, OrdersProvider prov) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ChangeNotifierProvider.value(
          value: prov,
          child: const NewOrderScreen(),
        ),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _OrdersHeader extends StatelessWidget {
  final OrdersProvider provider;
  const _OrdersHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OC.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OC.primary, OC.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orders',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: OC.textPri,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      '${provider.todayTotal} total orders today',
                      style: const TextStyle(fontSize: 12, color: OC.textSec),
                    ),
                  ],
                ),
              ),
              // Revenue chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: OC.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '₹${provider.todayRevenue.toInt()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OC.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Summary pills row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OrderStatus.values.map((s) {
                final count = provider.countByStatus(s);
                if (count == 0) return const SizedBox.shrink();
                return _SummaryPill(status: s, count: count);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final OrderStatus status;
  final int count;
  const _SummaryPill({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            '$count ${status.label}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _statusColor(status),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATUS TAB BAR
// ═════════════════════════════════════════════════════════════════════════════
class _StatusTabBar extends StatelessWidget {
  final OrdersProvider provider;
  const _StatusTabBar({required this.provider});

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
      color: OC.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: OC.border),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: tabs.map((t) {
                final (status, label) = t;
                final count = status == null
                    ? provider.todayTotal
                    : provider.countByStatus(status);
                final isSel = provider.filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => provider.setFilter(status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSel ? OC.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$label ($count)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : OC.textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: OC.border),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORDERS LIST
// ═════════════════════════════════════════════════════════════════════════════
class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  final OrdersProvider provider;

  const _OrdersList({required this.orders, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(
        order: orders[i],
        provider: provider,
        onTap: () => _openDetail(context, orders[i], provider),
      ),
    );
  }

  void _openDetail(BuildContext ctx, Order order, OrdersProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _OrderDetailSheet(order: order),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORDER CARD
// ═════════════════════════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final Order order;
  final OrdersProvider provider;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final statusBg = _statusBg(order.status);
    final isActive =
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.preparing;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: OC.surface,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: statusColor.withOpacity(0.3), width: 1.5)
              : Border.all(color: OC.border),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? statusColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Row(
                children: [
                  // Status icon circle
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      order.status.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: OC.textPri,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: order.status),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: OC.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.type.emoji,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (order.tableNumber != null) ...[
                              const Icon(
                                Icons.table_restaurant_outlined,
                                size: 12,
                                color: OC.textMute,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Table ${order.tableNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OC.textSec,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (order.customerName != null) ...[
                              const Icon(
                                Icons.person_outline,
                                size: 12,
                                color: OC.textMute,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                order.customerName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OC.textSec,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    order.timeLabel,
                    style: const TextStyle(fontSize: 11, color: OC.textMute),
                  ),
                ],
              ),
            ),

            // ── Divider ───────────────────────────────────
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: OC.border,
            ),

            // ── Order items (max 3) ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  ...order.items
                      .take(3)
                      .map(
                        (li) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: OC.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${li.quantity}x',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: OC.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  li.menuItem.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: OC.textPri,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${li.subtotal.toInt()}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: OC.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (order.items.length > 3)
                    Text(
                      '+${order.items.length - 3} more items',
                      style: const TextStyle(fontSize: 11, color: OC.textMute),
                    ),
                ],
              ),
            ),

            // ── Total + actions ───────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: OC.surfaceAlt,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OC.textSec,
                        ),
                      ),
                      Text(
                        '₹${order.total.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: OC.primary,
                        ),
                      ),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    _ActionButtons(order: order, provider: provider),
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

// ═════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTONS (Start / Cancel / Complete)
// ═════════════════════════════════════════════════════════════════════════════
class _ActionButtons extends StatelessWidget {
  final Order order;
  final OrdersProvider provider;

  const _ActionButtons({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final next = order.status.nextStatus;
    return Row(
      children: [
        // Cancel
        Expanded(
          child: GestureDetector(
            onTap: () => _confirmCancel(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: OC.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OC.cancelled.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, color: OC.cancelled, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Cancel',
                    style: TextStyle(
                      color: OC.cancelled,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Advance
        if (next != null)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => provider.advanceOrder(order.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _statusColor(next),
                      _statusColor(next).withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor(next).withOpacity(0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(next.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      order.status.nextLabel,
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
        title: Text(
          'Cancel #${order.orderNumber}?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This order will be marked as cancelled.',
          style: TextStyle(color: OC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Order',
              style: TextStyle(color: OC.textSec),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.cancelOrder(order.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OC.cancelled,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATUS CHIP
// ═════════════════════════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _statusColor(status),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORDER DETAIL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<OrdersProvider>();
    final statusColor = _statusColor(order.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: OC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              decoration: BoxDecoration(
                color: OC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _statusBg(order.status),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      order.status.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: OC.textPri,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (order.tableNumber != null)
                              'Table ${order.tableNumber}',
                            if (order.customerName != null) order.customerName!,
                            order.type.label,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OC.textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OC.border),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Timeline
                  _OrderTimeline(order: order),
                  const SizedBox(height: 18),

                  // Items
                  _SectionLabel('Order Items (${order.totalItems})'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: OC.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OC.border),
                    ),
                    child: Column(
                      children: order.items.asMap().entries.map((e) {
                        final i = e.key;
                        final li = e.value;
                        return Column(
                          children: [
                            _DetailLineItem(li: li),
                            if (i < order.items.length - 1)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: OC.border,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bill summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OC.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _BillRow('Subtotal', '₹${order.subtotal.toInt()}'),
                        const SizedBox(height: 6),
                        _BillRow('Tax (5%)', '₹${order.tax.toInt()}'),
                        const Divider(color: OC.border, height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: OC.primary,
                              ),
                            ),
                            Text(
                              '₹${order.total.toInt()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: OC.primary,
                              ),
                            ),
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
                        color: OC.pendingBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OC.pending.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.notes!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: OC.textSec,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action buttons
                  if (order.status == OrderStatus.pending ||
                      order.status == OrderStatus.preparing ||
                      order.status == OrderStatus.ready) ...[
                    const SizedBox(height: 20),
                    Consumer<OrdersProvider>(
                      builder: (_, p, __) => _ActionButtons(
                        order: p.allOrders.firstWhere(
                          (o) => o.id == order.id,
                          orElse: () => order,
                        ),
                        provider: p,
                      ),
                    ),
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

class _OrderTimeline extends StatelessWidget {
  final Order order;
  const _OrderTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (OrderStatus.pending, 'Order Placed', order.createdAt),
      (OrderStatus.preparing, 'Preparing', order.startedAt),
      (OrderStatus.ready, 'Ready to Serve', null),
      (OrderStatus.completed, 'Completed', order.completedAt),
    ];

    final currentIdx = steps.indexWhere((s) => s.$1 == order.status);

    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final (status, label, time) = e.value;
        final isDone =
            i < currentIdx ||
            (i == currentIdx && order.status != OrderStatus.cancelled);
        final isCurrent = i == currentIdx;
        final color = isDone ? _statusColor(status) : OC.border;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? color.withOpacity(0.15) : OC.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? color
                              : (isDone ? color : OC.border),
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isDone
                          ? Icon(Icons.check, color: color, size: 13)
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: OC.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDone ? color : OC.textMute,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: i < currentIdx ? color : OC.border,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: OC.textMute,
      letterSpacing: 1.4,
    ),
  );
}

class _DetailLineItem extends StatelessWidget {
  final OrderLineItem li;
  const _DetailLineItem({required this.li});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OC.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${li.quantity}x',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OC.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Veg indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: li.menuItem.isVeg
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: li.menuItem.isVeg
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  li.menuItem.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OC.textPri,
                  ),
                ),
                if (li.note != null)
                  Text(
                    li.note!,
                    style: const TextStyle(fontSize: 11, color: OC.textMute),
                  ),
              ],
            ),
          ),
          Text(
            '₹${li.subtotal.toInt()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: OC.textPri,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  const _BillRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: OC.textSec)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: OC.textPri,
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: OC.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Text('🧾', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 18),
        const Text(
          'No orders here',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: OC.textPri,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap + New Order to get started',
          style: TextStyle(fontSize: 13, color: OC.textSec),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  NEW ORDER FAB
// ═════════════════════════════════════════════════════════════════════════════
class _NewOrderFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _NewOrderFAB({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OC.primary, OC.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: OC.primary.withOpacity(0.40),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'New Order',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  NEW ORDER SCREEN  — full page with menu picker + cart
// ═════════════════════════════════════════════════════════════════════════════
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({Key? key}) : super(key: key);

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, OrderLineItem> _cart = {};
  final TextEditingController _tableCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  OrderType _orderType = OrderType.dineIn;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showCart = false;
  late final TabController _tabCtrl;

  List<OrderLineItem> get cartItems => _cart.values.toList();
  double get cartTotal => cartItems.fold(0.0, (s, i) => s + i.subtotal) * 1.05;
  int get cartCount => cartItems.fold(0, (s, i) => s + i.quantity);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tableCtrl.dispose();
    _customerCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _addItem(MenuItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id] = _cart[item.id]!.copyWith(
          quantity: _cart[item.id]!.quantity + 1,
        );
      } else {
        _cart[item.id] = OrderLineItem(menuItem: item, quantity: 1);
      }
    });
  }

  void _removeItem(MenuItem item) {
    setState(() {
      if (!_cart.containsKey(item.id)) return;
      if (_cart[item.id]!.quantity <= 1) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = _cart[item.id]!.copyWith(
          quantity: _cart[item.id]!.quantity - 1,
        );
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add items to the cart first')),
      );
      return;
    }
    final prov = context.read<OrdersProvider>();
    await prov.createOrder(
      type: _orderType,
      items: cartItems,
      tableNumber: _tableCtrl.text.isEmpty ? null : _tableCtrl.text,
      customerName: _customerCtrl.text.isEmpty ? null : _customerCtrl.text,
      notes: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuProvider>(
      builder: (context, menuProv, _) {
        final categories = ['All', ...menuProv.categories.map((c) => c.name)];
        List<MenuItem> items = _selectedCategory == 'All'
            ? menuProv.allMenuItems.where((i) => i.available).toList()
            : menuProv
                  .itemsForCategory(_selectedCategory)
                  .where((i) => i.available)
                  .toList();
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          items = items
              .where(
                (i) =>
                    i.name.toLowerCase().contains(q) ||
                    i.category.toLowerCase().contains(q),
              )
              .toList();
        }

        return Scaffold(
          backgroundColor: OC.bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────
                _NewOrderHeader(
                  cartCount: cartCount,
                  cartTotal: cartTotal,
                  showCart: _showCart,
                  onCartToggle: () => setState(() => _showCart = !_showCart),
                  onBack: () => Navigator.pop(context),
                ),

                // ── Main content ───────────────────────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _showCart
                        ? _CartView(
                            key: const ValueKey('cart'),
                            cartItems: cartItems,
                            orderType: _orderType,
                            tableCtrl: _tableCtrl,
                            customerCtrl: _customerCtrl,
                            noteCtrl: _noteCtrl,
                            cartTotal: cartTotal,
                            onTypeChanged: (t) =>
                                setState(() => _orderType = t),
                            onAdd: _addItem,
                            onRemove: _removeItem,
                            onPlaceOrder: _placeOrder,
                          )
                        : _MenuPickerView(
                            key: const ValueKey('menu'),
                            items: items,
                            categories: categories,
                            selectedCategory: _selectedCategory,
                            searchCtrl: _searchCtrl,
                            cart: _cart,
                            onCategoryChanged: (c) =>
                                setState(() => _selectedCategory = c),
                            onSearchChanged: (q) =>
                                setState(() => _searchQuery = q),
                            onAdd: _addItem,
                            onRemove: _removeItem,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEW ORDER HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _NewOrderHeader extends StatelessWidget {
  final int cartCount;
  final double cartTotal;
  final bool showCart;
  final VoidCallback onCartToggle;
  final VoidCallback onBack;

  const _NewOrderHeader({
    required this.cartCount,
    required this.cartTotal,
    required this.showCart,
    required this.onCartToggle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OC.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: OC.textPri,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Order',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OC.textPri,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Select items from menu',
                  style: TextStyle(fontSize: 11, color: OC.textSec),
                ),
              ],
            ),
          ),
          // Cart toggle button
          GestureDetector(
            onTap: onCartToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: showCart ? OC.primaryLight : OC.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    showCart
                        ? Icons.menu_book_rounded
                        : Icons.shopping_cart_outlined,
                    color: showCart ? OC.primary : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showCart ? 'Menu' : 'Cart ($cartCount)',
                    style: TextStyle(
                      color: showCart ? OC.primary : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!showCart && cartTotal > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '₹${cartTotal.toInt()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
//  MENU PICKER VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _MenuPickerView extends StatelessWidget {
  final List<MenuItem> items;
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchCtrl;
  final Map<String, OrderLineItem> cart;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MenuItem> onAdd;
  final ValueChanged<MenuItem> onRemove;

  const _MenuPickerView({
    Key? key,
    required this.items,
    required this.categories,
    required this.selectedCategory,
    required this.searchCtrl,
    required this.cart,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14, color: OC.textPri),
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                hintStyle: const TextStyle(color: OC.textMute, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: OC.textMute,
                  size: 19,
                ),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: OC.textMute,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: OC.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: OC.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: OC.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: OC.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        // Category chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              final isSel = selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onCategoryChanged(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSel ? OC.primary : OC.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? OC.primary : OC.border),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : OC.textSec,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = items[i];
              final inCart = cart[item.id];
              return _MenuPickerTile(
                item: item,
                quantity: inCart?.quantity ?? 0,
                onAdd: () => onAdd(item),
                onRemove: () => onRemove(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuPickerTile extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _MenuPickerTile({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = quantity > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inCart ? OC.primary.withOpacity(0.4) : OC.border,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: inCart
            ? [
                BoxShadow(
                  color: OC.primary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Veg indicator
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: item.isVeg
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: item.isVeg
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C),
                shape: BoxShape.circle,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OC.textPri,
                  ),
                ),
                Text(
                  item.category,
                  style: const TextStyle(fontSize: 11, color: OC.textMute),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.price.toInt()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: OC.textPri,
            ),
          ),
          const SizedBox(width: 12),
          // Quantity control
          if (quantity == 0)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OC.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: OC.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: OC.primary,
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: OC.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: OC.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _CartView extends StatelessWidget {
  final List<OrderLineItem> cartItems;
  final OrderType orderType;
  final TextEditingController tableCtrl;
  final TextEditingController customerCtrl;
  final TextEditingController noteCtrl;
  final double cartTotal;
  final ValueChanged<OrderType> onTypeChanged;
  final ValueChanged<MenuItem> onAdd;
  final ValueChanged<MenuItem> onRemove;
  final VoidCallback onPlaceOrder;

  const _CartView({
    Key? key,
    required this.cartItems,
    required this.orderType,
    required this.tableCtrl,
    required this.customerCtrl,
    required this.noteCtrl,
    required this.cartTotal,
    required this.onTypeChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onPlaceOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OC.textPri,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Go back to the menu to add items',
              style: TextStyle(fontSize: 13, color: OC.textSec),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Order type selector
        _SectionLabel('Order Type'),
        const SizedBox(height: 10),
        Row(
          children: OrderType.values.map((t) {
            final isSel = orderType == t;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSel ? OC.primaryLight : OC.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? OC.primary : OC.border,
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSel ? OC.primary : OC.textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Table + customer
        if (orderType == OrderType.dineIn) ...[
          Row(
            children: [
              Expanded(
                child: _OrderField(
                  label: 'Table No.',
                  hint: 'e.g. 4',
                  ctrl: tableCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OrderField(
                  label: 'Customer',
                  hint: 'Name',
                  ctrl: customerCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ] else ...[
          _OrderField(
            label: 'Customer Name',
            hint: 'Enter name',
            ctrl: customerCtrl,
          ),
          const SizedBox(height: 14),
        ],

        // Cart items
        _SectionLabel('Cart (${cartItems.length} items)'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: OC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OC.border),
          ),
          child: Column(
            children: cartItems.asMap().entries.map((e) {
              final i = e.key;
              final li = e.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                li.menuItem.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: OC.textPri,
                                ),
                              ),
                              Text(
                                '₹${li.menuItem.price.toInt()} each',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OC.textMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${li.subtotal.toInt()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: OC.textPri,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Qty control
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => onRemove(li.menuItem),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: OC.primaryLight,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: OC.primary,
                                  size: 14,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${li.quantity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OC.primary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => onAdd(li.menuItem),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: OC.primary,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i < cartItems.length - 1)
                    const Divider(height: 1, color: OC.border),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // Note
        _OrderField(
          label: 'Order Notes',
          hint: 'Special instructions...',
          ctrl: noteCtrl,
        ),

        const SizedBox(height: 18),

        // Bill summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OC.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _BillRow('Subtotal', '₹${(cartTotal / 1.05).toInt()}'),
              const SizedBox(height: 6),
              _BillRow(
                'Tax (5%)',
                '₹${(cartTotal - cartTotal / 1.05).toInt()}',
              ),
              const Divider(color: OC.border, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: OC.primary,
                    ),
                  ),
                  Text(
                    '₹${cartTotal.toInt()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: OC.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Place order
        GestureDetector(
          onTap: onPlaceOrder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [OC.primary, OC.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: OC.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Place Order',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;

  const _OrderField({
    required this.label,
    required this.hint,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: OC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: OC.textPri,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: OC.textMute, fontSize: 13),
            filled: true,
            fillColor: OC.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: OC.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: OC.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: OC.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
