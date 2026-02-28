// lib/screens/orders/orders_screen.dart
// FIXED: Shows all orders for admin/manager/owner/system.
// RESTART FIX: initState always calls prov.init() so businessId is
// guaranteed loaded from StorageService/Firestore on every app restart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/order_modal.dart';
import '../../providers/orders_provider.dart';
import 'new_order_screen.dart';

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
}

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
      // Always call init() — not just fetchOrders() — so that businessId is
      // guaranteed to be loaded from StorageService/Firestore on every restart.
      context.read<OrdersProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: _C.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(prov),
                _buildStatusFilter(prov),
                _buildStats(prov),
                Expanded(child: _buildBody(prov)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewOrderScreen()),
            ),
            backgroundColor: _C.primary,
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

  Widget _buildHeader(OrdersProvider prov) {
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
                    color: _C.textPri,
                  ),
                ),
                Text(
                  prov.isAdminLevel
                      ? '${prov.todayTotal} orders today (all staff)'
                      : '${prov.todayTotal} your orders today',
                  style: const TextStyle(fontSize: 11, color: _C.textSec),
                ),
              ],
            ),
          ),
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: _C.textSec,
                ),
                onPressed: () => prov.markNotificationsRead(),
              ),
              if (prov.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${prov.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Refresh
          IconButton(
            icon: prov.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _C.textSec),
            onPressed: prov.isLoading ? null : prov.fetchOrders,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(OrdersProvider prov) {
    final tabs = [
      (null, 'All (${prov.allOrders.length})'),
      (
        OrderStatus.pending,
        'Pending (${prov.countByStatus(OrderStatus.pending)})',
      ),
      (
        OrderStatus.preparing,
        'Preparing (${prov.countByStatus(OrderStatus.preparing)})',
      ),
      (OrderStatus.ready, 'Ready (${prov.countByStatus(OrderStatus.ready)})'),
      (
        OrderStatus.completed,
        'Done (${prov.countByStatus(OrderStatus.completed)})',
      ),
    ];

    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((tab) {
            final isSel = prov.filterStatus == tab.$1;
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
                    color: isSel ? _C.primary : _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab.$2,
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
    );
  }

  Widget _buildStats(OrdersProvider prov) {
    if (!prov.isAdminLevel) return const SizedBox.shrink();
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _StatChip(
            emoji: '💰',
            label: '₹${_fmt(prov.todayRevenue)}',
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '🧾',
            label: '${prov.countByStatus(OrderStatus.completed)} done',
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '⏳',
            label:
                '${prov.countByStatus(OrderStatus.pending) + prov.countByStatus(OrderStatus.preparing)} active',
            color: _C.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(OrdersProvider prov) {
    if (prov.isLoading && prov.allOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _C.primary));
    }

    if (prov.error != null && prov.allOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              prov.error!,
              style: const TextStyle(color: _C.textSec, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: prov.fetchOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final orders = prov.filteredOrders;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text(
              'No orders today',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.textPri,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + New Order to get started',
              style: TextStyle(fontSize: 13, color: _C.textSec),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: prov.fetchOrders,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.primary),
                foregroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.primary,
      onRefresh: prov.fetchOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          isAdmin: prov.isAdminLevel,
          onAdvance: () => prov.advanceOrder(orders[i].id),
          onCancel: () => _confirmCancel(orders[i], prov),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(Order order, OrdersProvider prov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text('Cancel Order #${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirm == true) await prov.cancelOrder(order.id);
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Order Card ─────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isAdmin;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.isAdmin,
    required this.onAdvance,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final canAdvance = status.nextStatus != null;
    final canCancel =
        status == OrderStatus.pending || status == OrderStatus.preparing;

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: status.bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(status.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
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
                              color: _C.textPri,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: status.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            order.orderType.emoji,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.orderType.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _C.textSec,
                            ),
                          ),
                          if (order.tableNumber != null) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: _C.textMute),
                            ),
                            Text(
                              'Table ${order.tableNumber}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _C.textSec,
                              ),
                            ),
                          ],
                          if (order.customerName != null &&
                              order.customerName!.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: _C.textMute),
                            ),
                            Flexible(
                              child: Text(
                                order.customerName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textSec,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                        color: _C.textPri,
                      ),
                    ),
                    Text(
                      order.timeLabel,
                      style: const TextStyle(fontSize: 10, color: _C.textMute),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items
          if (order.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                children: order.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: item.isVeg
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFB71C1C),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: item.isVeg
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFB71C1C),
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
                                  color: _C.textPri,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '×${item.quantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.textSec,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _C.textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Staff name (admin view only)
          if (isAdmin && order.createdByName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: _C.textMute,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'by ${order.createdByName} (${order.createdByRole})',
                    style: const TextStyle(fontSize: 10, color: _C.textMute),
                  ),
                ],
              ),
            ),

          // Actions
          if (canAdvance || canCancel)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Row(
                children: [
                  if (canCancel)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (canAdvance && canCancel) const SizedBox(width: 8),
                  if (canAdvance)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onAdvance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          status.nextLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── Small stat chip ────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String emoji, label;
  final Color color;
  const _StatChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
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
