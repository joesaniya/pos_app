// lib/screens/orders/orders_screen.dart
// v2: Payment-gated completion. 'ready' orders show "Collect Payment" button.
// Completed orders show "View Bill" button.

import 'package:flutter/material.dart';
import 'package:pos_app/screens/orders_bill_preview_screen.dart';
import 'package:pos_app/screens/sheet/payment_sheet.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/order_modal.dart';
import '../../providers/orders_provider.dart';
import 'new_order_screen.dart';

// ── Color palette ──────────────────────────────────────────────────────────────
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
  static const payGreen = Color(0xFF059669);
  static const payGreenBg = Color(0xFFECFDF5);
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

// ── Screen ─────────────────────────────────────────────────────────────────────
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
      context.read<OrdersProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: OC.bg,
          body: SafeArea(
            child: Column(
              children: [
                _Header(prov: prov),
                // Payment alert banner
                if (prov.pendingPaymentCount > 0)
                  _PaymentAlertBanner(count: prov.pendingPaymentCount),
                _StatusFilter(prov: prov),
                if (prov.isAdminLevel) _StatsBar(prov: prov),
                Expanded(
                  child: _Body(
                    prov: prov,
                    onCancel: _confirmCancel,
                    onCollectPayment: _openPaymentSheet,
                    onViewBill: _openBillPreview,
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewOrderScreen()),
            ),
            backgroundColor: OC.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Order',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(Order order, OrdersProvider prov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Order?',
          style: TextStyle(fontWeight: FontWeight.w800, color: OC.textPri),
        ),
        content: Text(
          'Cancel Order #${order.orderNumber}?',
          style: const TextStyle(color: OC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: OC.textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    if (confirm == true) await prov.cancelOrder(order.id);
  }

  Future<void> _openPaymentSheet(Order order) async {
    await PaymentSheet.show(context, order);
  }

  void _openBillPreview(Order order) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => BillPreviewScreen(order: order),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

// ── Payment alert banner ────────────────────────────────────────────────────────
class _PaymentAlertBanner extends StatelessWidget {
  final int count;
  const _PaymentAlertBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF059669).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count order${count > 1 ? 's' : ''} waiting for payment collection',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final OrdersProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OC.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OC.textPri,
                  ),
                ),
                Text(
                  '${prov.todayTotal} orders today',
                  style: const TextStyle(fontSize: 11, color: OC.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Filter Tabs ─────────────────────────────────────────────────────────
class _StatusFilter extends StatelessWidget {
  final OrdersProvider prov;
  const _StatusFilter({required this.prov});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (null, 'All', prov.allOrders.length),
      (OrderStatus.pending, 'Pending', prov.countByStatus(OrderStatus.pending)),
      (
        OrderStatus.preparing,
        'Preparing',
        prov.countByStatus(OrderStatus.preparing),
      ),
      (OrderStatus.ready, 'Ready', prov.countByStatus(OrderStatus.ready)),
      (
        OrderStatus.completed,
        'Done',
        prov.countByStatus(OrderStatus.completed),
      ),
    ];

    return Container(
      color: OC.surface,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((tab) {
            final isSel = prov.filterStatus == tab.$1;
            final tabColor = tab.$1 == null
                ? OC.primary
                : _statusColor(tab.$1!);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => prov.setFilter(tab.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? tabColor : OC.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? tabColor : OC.border,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '${tab.$2} (${tab.$3})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : OC.textSec,
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

// ── Stats Bar ──────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final OrdersProvider prov;
  const _StatsBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    final active =
        prov.countByStatus(OrderStatus.pending) +
        prov.countByStatus(OrderStatus.preparing);
    return Container(
      color: OC.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _StatChip(
            emoji: '💰',
            label: '₹${_fmt(prov.todayRevenue)}',
            color: OC.ready,
            bg: OC.readyBg,
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '🧾',
            label: '${prov.countByStatus(OrderStatus.completed)} done',
            color: OC.completed,
            bg: OC.completedBg,
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '⏳',
            label: '$active active',
            color: OC.primary,
            bg: OC.primaryLight,
          ),
          if (prov.pendingPaymentCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              emoji: '💳',
              label: '${prov.pendingPaymentCount} unpaid',
              color: OC.payGreen,
              bg: OC.payGreenBg,
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final OrdersProvider prov;
  final Future<void> Function(Order, OrdersProvider) onCancel;
  final Future<void> Function(Order) onCollectPayment;
  final void Function(Order) onViewBill;

  const _Body({
    required this.prov,
    required this.onCancel,
    required this.onCollectPayment,
    required this.onViewBill,
  });

  @override
  Widget build(BuildContext context) {
    if (prov.isLoading && prov.allOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: OC.primary));
    }

    if (prov.error != null && prov.allOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: OC.cancelledBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: OC.cancelled,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                prov.error!,
                style: const TextStyle(color: OC.textSec, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: prov.fetchOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OC.primary,
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

    final orders = prov.filteredOrders;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: OC.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Text('📋', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No orders today',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OC.textPri,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + New Order to get started',
              style: TextStyle(fontSize: 13, color: OC.textSec),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: prov.fetchOrders,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: OC.primary),
                foregroundColor: OC.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: OC.primary,
      onRefresh: prov.fetchOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          isAdmin: prov.isAdminLevel,
          onAdvance: () => prov.advanceOrder(orders[i].id),
          onCancel: () => onCancel(orders[i], prov),
          onCollectPayment: () => onCollectPayment(orders[i]),
          onViewBill: () => onViewBill(orders[i]),
        ),
      ),
    );
  }
}

// ── Order Card ─────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isAdmin;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;
  final VoidCallback onCollectPayment;
  final VoidCallback onViewBill;

  const _OrderCard({
    required this.order,
    required this.isAdmin,
    required this.onAdvance,
    required this.onCancel,
    required this.onCollectPayment,
    required this.onViewBill,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final payStatus = order.paymentStatus;
    final sColor = _statusColor(status);
    final sBg = _statusBg(status);

    // Kitchen flow: pending and preparing can advance (not ready)
    final canAdvanceKitchen =
        status == OrderStatus.pending || status == OrderStatus.preparing;
    final canCancel =
        status == OrderStatus.pending || status == OrderStatus.preparing;
    final needsPayment =
        status == OrderStatus.ready && payStatus == PaymentStatus.unpaid;
    final isCompleted = status == OrderStatus.completed;

    return Container(
      decoration: BoxDecoration(
        color: OC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsPayment
              ? const Color(0xFF059669).withOpacity(0.4)
              : sColor.withOpacity(0.25),
          width: needsPayment ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: sColor.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: sBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    status.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: OC.textPri,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: status),
                          const SizedBox(width: 6),
                          // Payment status badge
                          _PaymentBadge(paymentStatus: payStatus),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _OrderMeta(order: order),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: OC.textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.timeLabel,
                      style: const TextStyle(fontSize: 10, color: OC.textMute),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Items ────────────────────────────────────────────────────────
          if (order.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                children: order.items
                    .map((item) => _ItemRow(item: item))
                    .toList(),
              ),
            ),

          // ── Bill number (for completed) ────────────────────────────────
          if (isCompleted && order.billNumber != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_rounded,
                    size: 11,
                    color: OC.textMute,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.billNumber!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: OC.textMute,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (order.paidByName != null) ...[
                    const Text(
                      ' · ',
                      style: TextStyle(color: OC.textMute, fontSize: 10),
                    ),
                    Text(
                      'Billed by ${order.paidByName}',
                      style: const TextStyle(fontSize: 10, color: OC.textMute),
                    ),
                  ],
                ],
              ),
            ),

          // ── Staff label ──────────────────────────────────────────────────
          if (isAdmin && order.createdByName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: OC.textMute,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'by ${order.createdByName} (${order.createdByRole})',
                    style: const TextStyle(fontSize: 10, color: OC.textMute),
                  ),
                ],
              ),
            ),

          // ── Action Buttons ────────────────────────────────────────────────
          if (canAdvanceKitchen || canCancel || needsPayment || isCompleted)
            const Divider(height: 1, color: OC.border),

          if (canAdvanceKitchen || canCancel || needsPayment || isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  // Cancel button (only for pending/preparing)
                  if (canCancel) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: OC.cancelled,
                            width: 1.2,
                          ),
                          foregroundColor: OC.cancelled,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: OC.cancelled,
                              size: 16,
                            ),
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
                    const SizedBox(width: 8),
                  ],

                  // Kitchen advance button (pending → preparing → ready)
                  if (canAdvanceKitchen)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onAdvance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sColor,
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
                              status.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status.nextLabel,
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

                  // Collect payment button (ready + unpaid)
                  if (needsPayment)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onCollectPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💰', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text(
                              'Collect Payment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // View Bill button (completed)
                  if (isCompleted)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewBill,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: OC.primary, width: 1.5),
                          foregroundColor: OC.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_rounded,
                              size: 15,
                              color: OC.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'View Bill',
                              style: TextStyle(
                                color: OC.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Payment badge ──────────────────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  final PaymentStatus paymentStatus;
  const _PaymentBadge({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    if (paymentStatus == PaymentStatus.paid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '✓ PAID',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF059669),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
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

// ── Order Meta Row ─────────────────────────────────────────────────────────────
// Enhanced to prominently display table and seat information
class _OrderMeta extends StatelessWidget {
  final Order order;
  const _OrderMeta({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasTable = order.tableNumber != null && order.tableNumber! > 0;
    final hasSeat = order.seatLabel != null && order.seatLabel!.isNotEmpty;
    final hasCustomer =
        order.customerName != null && order.customerName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary row: Order type + Table/Seats
        Row(
          children: [
            Text(order.orderType.emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              order.orderType.label,
              style: const TextStyle(fontSize: 11, color: OC.textSec),
            ),
            // ── TABLE & SEAT INFO (Primary) ──────────────────────────────
            if (hasTable) ...[
              const Text(
                ' • ',
                style: TextStyle(color: OC.textMute, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: OC.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍽️ ', style: TextStyle(fontSize: 10)),
                    Text(
                      'Table ${order.tableNumber!.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OC.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasSeat) ...[
                      const Text(
                        ' - ',
                        style: TextStyle(color: OC.textMute, fontSize: 10),
                      ),
                      Text(
                        'Seat ${order.seatLabel!}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: OC.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (order.orderType != OrderType.dineIn) ...[
              const Text(
                ' • ',
                style: TextStyle(color: OC.textMute, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.orderType.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        // Secondary row: Customer name if available
        if (hasCustomer) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Text('👤 ', style: TextStyle(fontSize: 10)),
              Flexible(
                child: Text(
                  order.customerName!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: OC.textSec,
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

// ── Item Row ───────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final dotColor = item.isVeg
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB71C1C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
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
          Expanded(
            child: Text(
              item.itemName,
              style: const TextStyle(
                fontSize: 12,
                color: OC.textPri,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '×${item.quantity}',
            style: const TextStyle(fontSize: 12, color: OC.textSec),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${item.subtotal.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OC.textPri,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ──────────────────────────────────────────────────────────────────
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
        border: Border.all(color: color.withOpacity(0.25)),
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
