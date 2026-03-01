import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/utils/ist_utils.dart'; // ✅ IST utility
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/seated_duration_timer.dart';
import 'reservation_sheet.dart';
import 'add_edit_table_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  INTERNAL DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isVeg;
  final String? category;
  final String? notes;

  const _OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isVeg,
    this.category,
    this.notes,
  });
}

class _OrderSummary {
  final String id;
  final int orderNumber;
  final String status;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String? notes;
  final String createdByName;
  final DateTime createdAt; // stored as IST
  final List<_OrderItem> items;

  const _OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.notes,
    required this.createdByName,
    required this.createdAt,
    required this.items,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class TableDetailSheet extends StatelessWidget {
  final RestaurantTable table;
  const TableDetailSheet({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<TablesProvider>();
    final sc = statusColor(table.status);
    final sb = statusBg(table.status);
    final secCol = sectionColor(table.section);
    final secBg = sectionBg(table.section);

    log('TableDetailSheet: table=${table.tableNumber} status=${table.status}');

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.96,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TableIconWidget(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Table ${table.tableNumber}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (table.isPremium)
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _Badge(
                              text:
                                  '${table.section.emoji} ${table.section.label}',
                              color: secCol,
                              bg: secBg,
                            ),
                            const SizedBox(width: 6),
                            _Badge(text: table.status.label, color: sc, bg: sb),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (prov.canManageTables)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: prov,
                            child: AddEditTableSheet(
                              provider: prov,
                              editTable: table,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: TC.border),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: TC.textSec,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: TC.divider),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      InfoTile(
                        label: 'Capacity',
                        value: '${table.capacity} seats',
                        emoji: '👥',
                      ),
                      const SizedBox(width: 10),
                      InfoTile(
                        label: 'Floor',
                        value: table.section.floor,
                        emoji: '🏢',
                      ),
                      const SizedBox(width: 10),
                      InfoTile(
                        label: 'Shape',
                        value: table.shape.name.capitalize(),
                        emoji: '⬜',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (table.status == TableStatus.occupied)
                    OccupiedSection(table: table, prov: prov)
                  else if (table.status == TableStatus.reserved)
                    ReservationSection(table: table, prov: prov)
                  else if (table.status == TableStatus.available)
                    AvailableSection(table: table, prov: prov)
                  else
                    CleaningSection(table: table, prov: prov),
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
//  BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _Badge({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OCCUPIED SECTION
// ══════════════════════════════════════════════════════════════════════════════

class OccupiedSection extends StatefulWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const OccupiedSection({super.key, required this.table, required this.prov});

  @override
  State<OccupiedSection> createState() => _OccupiedSectionState();
}

class _OccupiedSectionState extends State<OccupiedSection> {
  final _db = Supabase.instance.client;

  List<_OrderSummary> _orders = [];
  bool _loading = true;
  String? _error;

  double _grandTotal = 0;
  double _grandSub = 0;
  double _grandTax = 0;
  int _totalItems = 0;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _itemsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _itemsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orderRows = await _db
          .from('orders')
          .select(
            'id, order_number, status, subtotal, tax_amount, '
            'total_amount, notes, created_at, created_by_name',
          )
          .eq('table_id', widget.table.id)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .order('created_at', ascending: true);

      final List<_OrderSummary> summaries = [];

      for (final o in (orderRows as List)) {
        final oid = o['id'] as String;

        final itemRows = await _db
            .from('order_items')
            .select(
              'id, item_name, quantity, item_price, subtotal, '
              'is_veg, category_name, notes',
            )
            .eq('order_id', oid)
            .order('created_at', ascending: true);

        final items = (itemRows as List)
            .map(
              (i) => _OrderItem(
                id: i['id'] as String? ?? '',
                name: i['item_name'] as String? ?? '—',
                quantity: (i['quantity'] as int? ?? 1),
                unitPrice: (i['item_price'] as num? ?? 0).toDouble(),
                subtotal: (i['subtotal'] as num? ?? 0).toDouble(),
                isVeg: i['is_veg'] as bool? ?? true,
                category: i['category_name'] as String?,
                notes: i['notes'] as String?,
              ),
            )
            .toList();

        summaries.add(
          _OrderSummary(
            id: oid,
            orderNumber: (o['order_number'] as int? ?? 0),
            status: o['status'] as String? ?? 'pending',
            subtotal: (o['subtotal'] as num? ?? 0).toDouble(),
            taxAmount: (o['tax_amount'] as num? ?? 0).toDouble(),
            total: (o['total_amount'] as num? ?? 0).toDouble(),
            notes: o['notes'] as String?,
            createdByName: o['created_by_name'] as String? ?? 'Staff',
            // ✅ FIX: parse created_at as UTC → IST
            createdAt: parseToIST(o['created_at'] as String),
            items: items,
          ),
        );
      }

      _recalc(summaries);

      if (mounted)
        setState(() {
          _orders = summaries;
          _loading = false;
        });
    } catch (e, st) {
      log('[OccupiedSection] load error: $e\n$st');
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _recalc(List<_OrderSummary> orders) {
    _grandSub = orders.fold(0.0, (s, o) => s + o.subtotal);
    _grandTax = orders.fold(0.0, (s, o) => s + o.taxAmount);
    _grandTotal = orders.fold(0.0, (s, o) => s + o.total);
    _totalItems = orders.fold(
      0,
      (s, o) => s + o.items.fold(0, (si, i) => si + i.quantity),
    );

    if (orders.isNotEmpty) {
      _db
          .from('restaurant_tables')
          .update({'current_order_total': _grandTotal})
          .eq('id', widget.table.id)
          .catchError((_) {});
    }
  }

  void _subscribeRealtime() {
    _ordersChannel = _db
        .channel('sheet_orders_${widget.table.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'table_id',
            value: widget.table.id,
          ),
          callback: (_) => _load(),
        )
        .subscribe();

    _itemsChannel = _db
        .channel('sheet_items_${widget.table.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Color _statusColor(String s) => switch (s) {
    'preparing' => const Color(0xFF0A7ADB),
    'ready' => const Color(0xFF1A9C5B),
    _ => const Color(0xFFE8860A),
  };

  Color _statusBg(String s) => switch (s) {
    'preparing' => const Color(0xFFE0F0FF),
    'ready' => const Color(0xFFE2F8ED),
    _ => const Color(0xFFFFF4E0),
  };

  String _statusEmoji(String s) => switch (s) {
    'preparing' => '👨‍🍳',
    'ready' => '✅',
    _ => '🕐',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Current Occupancy'),

        if (widget.table.occupiedSince != null) ...[
          SeatedDurationTimer(
            occupiedSince: widget.table.occupiedSince,
            showWarning: true,
            warningMinutes: 90,
            dangerMinutes: 150,
          ),
          const SizedBox(height: 12),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              DetailRow(
                icon: '👤',
                label: 'Customer',
                value: widget.table.currentCustomerName ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              if (widget.table.occupiedSince != null) ...[
                // ✅ FIX: occupiedSince is already IST — use fmtTimeIST directly
                DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: fmtTimeIST(widget.table.occupiedSince!),
                ),
                const Divider(height: 20, color: TC.divider),
              ],
              DetailRow(
                icon: '⏱️',
                label: 'Duration',
                value: widget.table.occupiedDuration,
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '💰',
                label: 'Bill so far',
                value: _loading
                    ? 'Loading…'
                    : '₹${_grandTotal.toStringAsFixed(0)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            const Expanded(
              child: Text(
                'LIVE ORDERS & BILL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: TC.textMute,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: TC.border),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 15,
                  color: TC.textSec,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2, color: TC.accent),
                  SizedBox(height: 10),
                  Text(
                    'Fetching live orders…',
                    style: TextStyle(fontSize: 12, color: TC.textSec),
                  ),
                ],
              ),
            ),
          )
        else if (_error != null)
          _ErrorCard(error: _error!, onRetry: _load)
        else if (_orders.isEmpty)
          _EmptyOrdersCard()
        else ...[
          ..._orders.map(
            (order) => _OrderCard(
              order: order,
              stColor: _statusColor(order.status),
              stBg: _statusBg(order.status),
              stEmoji: _statusEmoji(order.status),
            ),
          ),
          const SizedBox(height: 12),
          _GrandBillCard(
            orders: _orders,
            grandSub: _grandSub,
            grandTax: _grandTax,
            grandTotal: _grandTotal,
            totalItems: _totalItems,
          ),
          const SizedBox(height: 16),
        ],

        ActionBtn(
          label: 'Clear Table (Needs Cleaning)',
          emoji: '🧹',
          color: TC.cleaning,
          onTap: () {
            widget.prov.clearTable(widget.table.id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PER-ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final _OrderSummary order;
  final Color stColor, stBg;
  final String stEmoji;
  const _OrderCard({
    required this.order,
    required this.stColor,
    required this.stBg,
    required this.stEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: stColor.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: stBg.withOpacity(0.55),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(stEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: TC.textPri,
                        ),
                      ),
                      // ✅ FIX: createdAt is already IST — use fmtTimeIST
                      Text(
                        '${order.createdByName} · ${fmtTimeIST(order.createdAt)}',
                        style: const TextStyle(fontSize: 10, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: stBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    order.status[0].toUpperCase() + order.status.substring(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: stColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TC.divider),

          ...order.items.asMap().entries.map((e) {
            final idx = e.key;
            final item = e.value;
            final vegC = item.isVeg
                ? const Color(0xFF2E7D32)
                : const Color(0xFFB71C1C);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: vegC, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: vegC,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TC.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: TC.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TC.textPri,
                              ),
                            ),
                            if (item.category != null)
                              Text(
                                item.category!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: TC.textSec,
                                ),
                              ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Text(
                                '📝 ${item.notes}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: TC.textSec,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${item.unitPrice.toStringAsFixed(0)} each',
                            style: const TextStyle(
                              fontSize: 10,
                              color: TC.textMute,
                            ),
                          ),
                          Text(
                            '₹${item.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: TC.textPri,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (idx < order.items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: TC.divider,
                  ),
              ],
            );
          }),

          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9F9FC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Column(
              children: [
                const Divider(height: 1, color: TC.divider),
                const SizedBox(height: 8),
                _BillRow(
                  'Subtotal',
                  '₹${order.subtotal.toStringAsFixed(0)}',
                  small: true,
                ),
                const SizedBox(height: 3),
                _BillRow(
                  'Tax',
                  '₹${order.taxAmount.toStringAsFixed(0)}',
                  small: true,
                ),
                const SizedBox(height: 4),
                _BillRow(
                  'Order Total',
                  '₹${order.total.toStringAsFixed(0)}',
                  bold: true,
                  valueColor: TC.accent,
                ),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE8860A).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.notes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TC.textSec,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRAND BILL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GrandBillCard extends StatelessWidget {
  final List<_OrderSummary> orders;
  final double grandSub, grandTax, grandTotal;
  final int totalItems;
  const _GrandBillCard({
    required this.orders,
    required this.grandSub,
    required this.grandTax,
    required this.grandTotal,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final pendCount = orders.where((o) => o.status == 'pending').length;
    final prepCount = orders.where((o) => o.status == 'preparing').length;
    final readCount = orders.where((o) => o.status == 'ready').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [TC.accent.withOpacity(0.11), TC.accent.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TC.accent.withOpacity(0.28), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Bill Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: TC.textPri,
                ),
              ),
              const Spacer(),
              Text(
                '${orders.length} order${orders.length != 1 ? 's' : ''}  ·  $totalItems items',
                style: const TextStyle(fontSize: 11, color: TC.textSec),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pendCount > 0 || prepCount > 0 || readCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (pendCount > 0)
                    _Pill(
                      '$pendCount Pending',
                      const Color(0xFFE8860A),
                      const Color(0xFFFFF4E0),
                    ),
                  if (prepCount > 0)
                    _Pill(
                      '$prepCount Preparing',
                      const Color(0xFF0A7ADB),
                      const Color(0xFFE0F0FF),
                    ),
                  if (readCount > 0)
                    _Pill(
                      '$readCount Ready',
                      const Color(0xFF1A9C5B),
                      const Color(0xFFE2F8ED),
                    ),
                ],
              ),
            ),
          const Divider(height: 1, color: TC.divider),
          const SizedBox(height: 10),
          _BillRow('Subtotal', '₹${grandSub.toStringAsFixed(0)}'),
          const SizedBox(height: 5),
          _BillRow('Tax', '₹${grandTax.toStringAsFixed(0)}'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: TC.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GRAND TOTAL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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

class _Pill extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Pill(this.label, this.color, this.bg);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label, value;
  final bool small, bold;
  final Color? valueColor;
  const _BillRow(
    this.label,
    this.value, {
    this.small = false,
    this.bold = false,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    final fs = small ? 12.0 : 13.0;
    final fw = bold ? FontWeight.w900 : FontWeight.w600;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: fs, color: TC.textSec),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fs,
            fontWeight: fw,
            color: valueColor ?? TC.textPri,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR / EMPTY CARDS
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TC.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.border),
      ),
      child: const Row(
        children: [
          Text('🧾', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active orders yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TC.textPri,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Orders taken for this table will appear here in real-time.',
                  style: TextStyle(fontSize: 11, color: TC.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESERVATION SECTION
// ══════════════════════════════════════════════════════════════════════════════

class ReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const ReservationSection({
    super.key,
    required this.table,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final res = table.reservation;
    if (res == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TC.reserved.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Text('📅', style: TextStyle(fontSize: 28)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TC.reserved,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Reservation is for a different date.\nView it in the Calendar tab.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TC.textSec,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ActionBtn(
            label: 'Cancel Reservation',
            emoji: '✖️',
            color: const Color(0xFFDC2626),
            outlined: true,
            onTap: () => _confirmCancelById(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Reservation Details'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.reservedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.reserved.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              DetailRow(icon: '👤', label: 'Guest', value: res.customerName),
              const Divider(height: 20, color: TC.divider),
              DetailRow(icon: '📱', label: 'Phone', value: res.phone ?? '—'),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '👥',
                label: 'Party size',
                value: '${res.guestCount} guests',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🗓️',
                label: 'Reserved at',
                value: '${res.dateLabel} at ${res.reservationTimeLabel}',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🟢',
                label: 'Scheduled check-in',
                value: res.timeLabel,
              ),
              if (res.checkIn != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '✅',
                  label: 'Actual check-in',
                  value: res.checkInTimeLabel,
                ),
              ],
              if (res.checkOut != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🔴',
                  label: 'Check-out',
                  value: res.checkOutTimeLabel,
                ),
              ],
              const Divider(height: 20, color: TC.divider),
              DetailRow(icon: '⏰', label: 'Arrives', value: res.countdownLabel),
              if (res.createdByName != null || res.createdByRole != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🏷️',
                  label: 'Reserved by',
                  value: res.createdByName ?? res.createdByRole ?? 'Staff',
                ),
              ],
              if (res.notes != null && res.notes!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ActionBtn(
                label: 'Seat Guests',
                emoji: '🍽️',
                color: TC.available,
                onTap: () {
                  prov.seatGuests(table.id, res.customerName);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ActionBtn(
                label: 'No Show',
                emoji: '👻',
                color: const Color(0xFF6B7280),
                outlined: true,
                onTap: () => _confirmNoShow(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ActionBtn(
                label: 'Cancel',
                emoji: '✖️',
                color: const Color(0xFFDC2626),
                outlined: true,
                onTap: () => _confirmCancel(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionBtn(
                label: 'Edit',
                emoji: '✏️',
                color: TC.accent,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: prov,
                      child: ReservationSheet(
                        tableId: table.id,
                        provider: prov,
                        existing: res,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ℹ️', style: TextStyle(fontSize: 13)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"No Show" means the guest made a reservation but never arrived. '
                  'The table will be freed and the booking recorded as no-show.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TC.textSec,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmCancelById(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cancel Reservation?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: const Text(
        'This reservation is for a different date. Cancel it and free the table?',
        style: TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            prov.cancelReservation(table.id);
            Navigator.pop(ctx);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  void _confirmNoShow(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Mark as No-Show?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: Text(
        '${table.reservation?.customerName ?? 'The guest'} never arrived. '
        'The table will be freed and the booking marked as no-show.',
        style: const TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Back', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            prov.markNoShow(table.id);
            Navigator.pop(ctx);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B7280),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('No Show'),
        ),
      ],
    ),
  );

  void _confirmCancel(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cancel Reservation?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: Text(
        'The reservation for ${table.reservation?.customerName ?? 'this guest'} will be cancelled.',
        style: const TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            prov.cancelReservation(table.id);
            Navigator.pop(ctx);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel Booking'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVAILABLE SECTION
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.available.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table is Ready',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.available,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Walk-in guests can be seated now',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // \u2705 Upcoming reservation warning banner
        if (upcomingRes != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE8860A).withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u26a0\ufe0f', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Reservation',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${upcomingRes.customerName} \u00b7 ${upcomingRes.guestCount} guests',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      Text(
                        'At ${upcomingRes.timeLabel}${upcomingRes.checkOut != null ? " \u2013 ${upcomingRes.checkOutTimeLabel}" : ""}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Table auto-locks 60 min before reservation.',
                        style: TextStyle(
                          fontSize: 10, fontStyle: FontStyle.italic,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (upcomingRes == null) ...[
              Expanded(
                child: ActionBtn(
                  label: 'Reserve Table',
                  emoji: '\ud83d\udcc5',
                  color: TC.reserved,
                  outlined: true,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ChangeNotifierProvider.value(
                        value: prov,
                        child: ReservationSheet(
                          tableId: table.id,
                          provider: prov,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ActionBtn(
                label: 'Seat Walk-in',
                emoji: '\ud83d\udeb6',
                color: TC.accent,
                onTap: () {
                  prov.seatGuests(table.id, 'Walk-in Guest');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CLEANING SECTION
// ══════════════════════════════════════════════════════════════════════════════

class CleaningSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const CleaningSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.cleaningBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.cleaning.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🧹', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Being Cleaned',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.cleaning,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Staff are cleaning this table.\n'
                      'Tap "Mark as Available" once it is clean and ready for new guests.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.textSec,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ℹ️', style: TextStyle(fontSize: 13)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"Cleaning" status is automatically set when a table is cleared after guests leave. '
                  'It prevents new guests from being seated at a dirty table. '
                  'Tap the button below once the table is wiped and reset.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TC.textSec,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ActionBtn(
            label: 'Mark as Available',
            emoji: '✅',
            color: TC.available,
            onTap: () {
              prov.markAvailable(table.id);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}


/*orderimpl. and time isseu

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/seated_duration_timer.dart';
import 'reservation_sheet.dart';
import 'add_edit_table_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  INTERNAL DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _OrderItem {
  final String  id;
  final String  name;
  final int     quantity;
  final double  unitPrice;
  final double  subtotal;
  final bool    isVeg;
  final String? category;
  final String? notes;

  const _OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isVeg,
    this.category,
    this.notes,
  });
}

class _OrderSummary {
  final String          id;
  final int             orderNumber;
  final String          status;   // pending | preparing | ready
  final double          subtotal;
  final double          taxAmount;
  final double          total;
  final String?         notes;
  final String          createdByName;
  final DateTime        createdAt;
  final List<_OrderItem> items;

  const _OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.notes,
    required this.createdByName,
    required this.createdAt,
    required this.items,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class TableDetailSheet extends StatelessWidget {
  final RestaurantTable table;
  const TableDetailSheet({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final prov   = context.read<TablesProvider>();
    final sc     = statusColor(table.status);
    final sb     = statusBg(table.status);
    final secCol = sectionColor(table.section);
    final secBg  = sectionBg(table.section);

    log('TableDetailSheet: table=${table.tableNumber} status=${table.status}');

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize:     0.96,
      minChildSize:     0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: TC.border, borderRadius: BorderRadius.circular(2)),
            ),

            // ── Table header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                TableIconWidget(
                  shape: table.shape, capacity: table.capacity,
                  color: sc, bg: sb, tableName: table.tableName,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Table ${table.tableNumber}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900,
                                color: TC.textPri, letterSpacing: -0.4)),
                        const SizedBox(width: 6),
                        if (table.isPremium)
                          const Text('⭐', style: TextStyle(fontSize: 14)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        _Badge(
                          text: '${table.section.emoji} ${table.section.label}',
                          color: secCol, bg: secBg,
                        ),
                        const SizedBox(width: 6),
                        _Badge(text: table.status.label, color: sc, bg: sb),
                      ]),
                    ],
                  ),
                ),
                // Edit button
                if (prov.canManageTables)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: prov,
                          child: AddEditTableSheet(provider: prov, editTable: table),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: TC.border)),
                      child: const Icon(Icons.edit_outlined, size: 18, color: TC.textSec),
                    ),
                  ),
              ]),
            ),
            const Divider(height: 1, color: TC.divider),

            // ── Content ──────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(children: [
                    InfoTile(label: 'Capacity', value: '${table.capacity} seats', emoji: '👥'),
                    const SizedBox(width: 10),
                    InfoTile(label: 'Floor', value: table.section.floor, emoji: '🏢'),
                    const SizedBox(width: 10),
                    InfoTile(label: 'Shape', value: table.shape.name.capitalize(), emoji: '⬜'),
                  ]),
                  const SizedBox(height: 16),
                  if (table.status == TableStatus.occupied)
                    OccupiedSection(table: table, prov: prov)
                  else if (table.status == TableStatus.reserved)
                    ReservationSection(table: table, prov: prov)
                  else if (table.status == TableStatus.available)
                    AvailableSection(table: table, prov: prov)
                  else
                    CleaningSection(table: table, prov: prov),
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
//  BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color  color, bg;
  const _Badge({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OCCUPIED SECTION  — with live order items + running bill
// ══════════════════════════════════════════════════════════════════════════════

class OccupiedSection extends StatefulWidget {
  final RestaurantTable table;
  final TablesProvider  prov;
  const OccupiedSection({super.key, required this.table, required this.prov});

  @override
  State<OccupiedSection> createState() => _OccupiedSectionState();
}

class _OccupiedSectionState extends State<OccupiedSection> {

  final _db = Supabase.instance.client;

  List<_OrderSummary> _orders    = [];
  bool                _loading   = true;
  String?             _error;

  // derived
  double _grandTotal  = 0;
  double _grandSub    = 0;
  double _grandTax    = 0;
  int    _totalItems  = 0;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _itemsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _itemsChannel?.unsubscribe();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      final orderRows = await _db
          .from('orders')
          .select(
            'id, order_number, status, subtotal, tax_amount, '
            'total_amount, notes, created_at, created_by_name')
          .eq('table_id', widget.table.id)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .order('created_at', ascending: true);

      final List<_OrderSummary> summaries = [];

      for (final o in (orderRows as List)) {
        final oid = o['id'] as String;

        final itemRows = await _db
            .from('order_items')
            .select(
              'id, item_name, quantity, item_price, subtotal, '
              'is_veg, category_name, notes')
            .eq('order_id', oid)
            .order('created_at', ascending: true);

        final items = (itemRows as List).map((i) => _OrderItem(
          id:        i['id'] as String? ?? '',
          name:      i['item_name'] as String? ?? '—',
          quantity:  (i['quantity'] as int? ?? 1),
          unitPrice: (i['item_price'] as num? ?? 0).toDouble(),
          subtotal:  (i['subtotal'] as num? ?? 0).toDouble(),
          isVeg:     i['is_veg'] as bool? ?? true,
          category:  i['category_name'] as String?,
          notes:     i['notes'] as String?,
        )).toList();

        summaries.add(_OrderSummary(
          id:           oid,
          orderNumber:  (o['order_number'] as int? ?? 0),
          status:       o['status'] as String? ?? 'pending',
          subtotal:     (o['subtotal'] as num? ?? 0).toDouble(),
          taxAmount:    (o['tax_amount'] as num? ?? 0).toDouble(),
          total:        (o['total_amount'] as num? ?? 0).toDouble(),
          notes:        o['notes'] as String?,
          createdByName: o['created_by_name'] as String? ?? 'Staff',
          createdAt:    DateTime.parse(o['created_at'] as String),
          items:        items,
        ));
      }

      _recalc(summaries);

      if (mounted) setState(() { _orders = summaries; _loading = false; });
    } catch (e, st) {
      log('[OccupiedSection] load error: $e\n$st');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _recalc(List<_OrderSummary> orders) {
    _grandSub   = orders.fold(0.0, (s, o) => s + o.subtotal);
    _grandTax   = orders.fold(0.0, (s, o) => s + o.taxAmount);
    _grandTotal = orders.fold(0.0, (s, o) => s + o.total);
    _totalItems = orders.fold(0,   (s, o) => s + o.items.fold(0, (si, i) => si + i.quantity));

    // Sync running bill back to the table row so the floor view shows correct total
    if (orders.isNotEmpty) {
      _db.from('restaurant_tables')
          .update({'current_order_total': _grandTotal})
          .eq('id', widget.table.id)
          .catchError((_) {});
    }
  }

  // ── Realtime subscription ──────────────────────────────────────────────────
  void _subscribeRealtime() {
    // Watch for any order change scoped to this table
    _ordersChannel = _db
        .channel('sheet_orders_${widget.table.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'table_id',
            value:  widget.table.id,
          ),
          callback: (_) => _load(),
        )
        .subscribe();

    // Watch for item-level changes (covers item additions mid-order)
    _itemsChannel = _db
        .channel('sheet_items_${widget.table.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color  _statusColor(String s) => switch (s) {
    'preparing' => const Color(0xFF0A7ADB),
    'ready'     => const Color(0xFF1A9C5B),
    _           => const Color(0xFFE8860A),   // pending / default
  };

  Color  _statusBg(String s) => switch (s) {
    'preparing' => const Color(0xFFE0F0FF),
    'ready'     => const Color(0xFFE2F8ED),
    _           => const Color(0xFFFFF4E0),
  };

  String _statusEmoji(String s) => switch (s) {
    'preparing' => '👨‍🍳',
    'ready'     => '✅',
    _           => '🕐',
  };

  String _fmtTime(DateTime dt) {
    final h   = dt.hour;
    final m   = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Current Occupancy'),

        // Live seated timer
        if (widget.table.occupiedSince != null) ...[
          SeatedDurationTimer(
            occupiedSince:  widget.table.occupiedSince,
            showWarning:    true,
            warningMinutes: 90,
            dangerMinutes:  150,
          ),
          const SizedBox(height: 12),
        ],

        // Occupancy info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(children: [
            DetailRow(icon: '👤', label: 'Customer',
                value: widget.table.currentCustomerName ?? '—'),
            const Divider(height: 20, color: TC.divider),
            if (widget.table.occupiedSince != null) ...[
              DetailRow(icon: '🕐', label: 'Seated since',
                  value: _fmtTime(widget.table.occupiedSince!)),
              const Divider(height: 20, color: TC.divider),
            ],
            DetailRow(icon: '⏱️', label: 'Duration',
                value: widget.table.occupiedDuration),
            const Divider(height: 20, color: TC.divider),
            DetailRow(icon: '💰', label: 'Bill so far',
                value: _loading ? 'Loading…' : '₹${_grandTotal.toStringAsFixed(0)}'),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Live Orders & Bill header ──────────────────────────
        Row(children: [
          const Expanded(
            child: Text('LIVE ORDERS & BILL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                    color: TC.textMute, letterSpacing: 1.4)),
          ),
          // Refresh button
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: TC.border)),
              child: const Icon(Icons.refresh_rounded, size: 15, color: TC.textSec),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // ── States ────────────────────────────────────────────
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(strokeWidth: 2, color: TC.accent),
                SizedBox(height: 10),
                Text('Fetching live orders…',
                    style: TextStyle(fontSize: 12, color: TC.textSec)),
              ]),
            ),
          )
        else if (_error != null)
          _ErrorCard(error: _error!, onRetry: _load)
        else if (_orders.isEmpty)
          _EmptyOrdersCard()
        else ...[
          // ── Per-order cards ──────────────────────────────────
          ..._orders.map((order) => _OrderCard(
            order:       order,
            stColor:     _statusColor(order.status),
            stBg:        _statusBg(order.status),
            stEmoji:     _statusEmoji(order.status),
          )),
          const SizedBox(height: 12),

          // ── Grand bill summary ───────────────────────────────
          _GrandBillCard(
            orders:     _orders,
            grandSub:   _grandSub,
            grandTax:   _grandTax,
            grandTotal: _grandTotal,
            totalItems: _totalItems,
          ),
          const SizedBox(height: 16),
        ],

        // ── Clear table button ─────────────────────────────────
        ActionBtn(
          label: 'Clear Table (Needs Cleaning)',
          emoji: '🧹',
          color: TC.cleaning,
          onTap: () {
            widget.prov.clearTable(widget.table.id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PER-ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final _OrderSummary order;
  final Color  stColor, stBg;
  final String stEmoji;
  const _OrderCard({
    required this.order,
    required this.stColor, required this.stBg, required this.stEmoji,
  });

  String _fmtTime(DateTime dt) {
    final h = dt.hour; final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: stColor.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: stBg.withOpacity(0.55),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Text(stEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order #${order.orderNumber}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: TC.textPri)),
                Text('${order.createdByName} · ${_fmtTime(order.createdAt)}',
                    style: const TextStyle(fontSize: 10, color: TC.textSec)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(7)),
              child: Text(
                order.status[0].toUpperCase() + order.status.substring(1),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: stColor),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: TC.divider),

        // Item rows
        ...order.items.asMap().entries.map((e) {
          final idx  = e.key;
          final item = e.value;
          final vegC = item.isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                // Veg / non-veg indicator
                Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: vegC, width: 1.5)),
                  alignment: Alignment.center,
                  child: Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: vegC, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 8),

                // Qty badge
                Container(
                  width: 30, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: TC.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(7)),
                  child: Text('${item.quantity}×',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                          color: TC.accent)),
                ),
                const SizedBox(width: 8),

                // Name / category / notes
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: TC.textPri)),
                    if (item.category != null)
                      Text(item.category!,
                          style: const TextStyle(fontSize: 10, color: TC.textSec)),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text('📝 ${item.notes}',
                          style: const TextStyle(fontSize: 10, color: TC.textSec,
                              fontStyle: FontStyle.italic)),
                  ]),
                ),

                // Unit + sub
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${item.unitPrice.toStringAsFixed(0)} each',
                      style: const TextStyle(fontSize: 10, color: TC.textMute)),
                  Text('₹${item.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: TC.textPri)),
                ]),
              ]),
            ),
            if (idx < order.items.length - 1)
              const Divider(height: 1, indent: 14, endIndent: 14, color: TC.divider),
          ]);
        }),

        // Per-order totals footer
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9FC),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Column(children: [
            const Divider(height: 1, color: TC.divider),
            const SizedBox(height: 8),
            _BillRow('Subtotal', '₹${order.subtotal.toStringAsFixed(0)}', small: true),
            const SizedBox(height: 3),
            _BillRow('Tax',      '₹${order.taxAmount.toStringAsFixed(0)}', small: true),
            const SizedBox(height: 4),
            _BillRow('Order Total', '₹${order.total.toStringAsFixed(0)}',
                bold: true, valueColor: TC.accent),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8860A).withOpacity(0.3))),
                child: Row(children: [
                  const Text('📝', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.notes!,
                      style: const TextStyle(fontSize: 11, color: TC.textSec))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRAND BILL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GrandBillCard extends StatelessWidget {
  final List<_OrderSummary> orders;
  final double grandSub, grandTax, grandTotal;
  final int    totalItems;
  const _GrandBillCard({
    required this.orders, required this.grandSub, required this.grandTax,
    required this.grandTotal, required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final pendCount = orders.where((o) => o.status == 'pending').length;
    final prepCount = orders.where((o) => o.status == 'preparing').length;
    final readCount = orders.where((o) => o.status == 'ready').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [TC.accent.withOpacity(0.11), TC.accent.withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TC.accent.withOpacity(0.28), width: 1.5),
      ),
      child: Column(children: [
        // Header
        Row(children: [
          const Text('📋', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Bill Summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: TC.textPri)),
          const Spacer(),
          Text('${orders.length} order${orders.length != 1 ? 's' : ''}  ·  $totalItems items',
              style: const TextStyle(fontSize: 11, color: TC.textSec)),
        ]),
        const SizedBox(height: 10),

        // Status pills
        if (pendCount > 0 || prepCount > 0 || readCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              if (pendCount > 0) _Pill('$pendCount Pending',  const Color(0xFFE8860A), const Color(0xFFFFF4E0)),
              if (prepCount > 0) _Pill('$prepCount Preparing', const Color(0xFF0A7ADB), const Color(0xFFE0F0FF)),
              if (readCount > 0) _Pill('$readCount Ready',     const Color(0xFF1A9C5B), const Color(0xFFE2F8ED)),
            ]),
          ),

        const Divider(height: 1, color: TC.divider),
        const SizedBox(height: 10),

        _BillRow('Subtotal', '₹${grandSub.toStringAsFixed(0)}'),
        const SizedBox(height: 5),
        _BillRow('Tax',      '₹${grandTax.toStringAsFixed(0)}'),
        const SizedBox(height: 10),

        // Grand total strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: TC.accent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GRAND TOTAL',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 0.5)),
              Text('₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label; final Color color, bg;
  const _Pill(this.label, this.color, this.bg);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label, value;
  final bool   small, bold;
  final Color? valueColor;
  const _BillRow(this.label, this.value,
      {this.small = false, this.bold = false, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final fs = small ? 12.0 : 13.0;
    final fw = bold ? FontWeight.w900 : FontWeight.w600;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: fs, color: TC.textSec)),
      Text(value, style: TextStyle(fontSize: fs, fontWeight: fw,
          color: valueColor ?? TC.textPri)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR / EMPTY CARDS
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2))),
      child: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(error,
            style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)))),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(8)),
            child: const Text('Retry',
                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border)),
      child: const Row(children: [
        Text('🧾', style: TextStyle(fontSize: 22)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No active orders yet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.textPri)),
          SizedBox(height: 2),
          Text('Orders taken for this table will appear here in real-time.',
              style: TextStyle(fontSize: 11, color: TC.textSec)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESERVATION SECTION  (unchanged from v1 logic)
// ══════════════════════════════════════════════════════════════════════════════

class ReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider  prov;
  const ReservationSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    final res = table.reservation;
    if (res == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TC.reserved.withOpacity(0.2))),
          child: const Row(children: [
            Text('📅', style: TextStyle(fontSize: 28)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reserved', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.reserved)),
              SizedBox(height: 3),
              Text('Reservation is for a different date.\nView it in the Calendar tab.',
                  style: TextStyle(fontSize: 12, color: TC.textSec, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        ActionBtn(label: 'Cancel Reservation', emoji: '✖️',
            color: const Color(0xFFDC2626), outlined: true,
            onTap: () => _confirmCancelById(context)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SheetSection('Reservation Details'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: TC.reservedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.reserved.withOpacity(0.2))),
        child: Column(children: [
          DetailRow(icon: '👤', label: 'Guest',      value: res.customerName),
          const Divider(height: 20, color: TC.divider),
          DetailRow(icon: '📱', label: 'Phone',      value: res.phone ?? '—'),
          const Divider(height: 20, color: TC.divider),
          DetailRow(icon: '👥', label: 'Party size', value: '${res.guestCount} guests'),
          const Divider(height: 20, color: TC.divider),
          DetailRow(icon: '🗓️', label: 'Reserved at',
              value: '${res.dateLabel} at ${res.reservationTimeLabel}'),
          const Divider(height: 20, color: TC.divider),
          DetailRow(icon: '🟢', label: 'Scheduled check-in',
              value: res.timeLabel),
          if (res.checkIn != null) ...[
            const Divider(height: 20, color: TC.divider),
            DetailRow(icon: '✅', label: 'Actual check-in', value: res.checkInTimeLabel),
          ],
          if (res.checkOut != null) ...[
            const Divider(height: 20, color: TC.divider),
            DetailRow(icon: '🔴', label: 'Check-out', value: res.checkOutTimeLabel),
          ],
          const Divider(height: 20, color: TC.divider),
          DetailRow(icon: '⏰', label: 'Arrives',    value: res.countdownLabel),
          if (res.createdByName != null || res.createdByRole != null) ...[
            const Divider(height: 20, color: TC.divider),
            DetailRow(icon: '🏷️', label: 'Reserved by',
                value: res.createdByName ?? res.createdByRole ?? 'Staff'),
          ],
          if (res.notes != null && res.notes!.isNotEmpty) ...[
            const Divider(height: 20, color: TC.divider),
            DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(flex: 3, child: ActionBtn(
            label: 'Seat Guests', emoji: '🍽️', color: TC.available,
            onTap: () { prov.seatGuests(table.id, res.customerName); Navigator.pop(context); })),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ActionBtn(
            label: 'No Show', emoji: '👻',
            color: const Color(0xFF6B7280), outlined: true,
            onTap: () => _confirmNoShow(context))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: ActionBtn(
            label: 'Cancel', emoji: '✖️',
            color: const Color(0xFFDC2626), outlined: true,
            onTap: () => _confirmCancel(context))),
        const SizedBox(width: 10),
        Expanded(child: ActionBtn(
            label: 'Edit', emoji: '✏️', color: TC.accent, outlined: true,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(value: prov,
                    child: ReservationSheet(tableId: table.id, provider: prov, existing: res)));
            })),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ℹ️', style: TextStyle(fontSize: 13)),
          SizedBox(width: 8),
          Expanded(child: Text(
              '"No Show" means the guest made a reservation but never arrived. '
              'The table will be freed and the booking recorded as no-show.',
              style: TextStyle(fontSize: 11, color: TC.textSec, height: 1.4))),
        ]),
      ),
    ]);
  }

  void _confirmCancelById(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: TC.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Cancel Reservation?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri)),
    content: const Text('This reservation is for a different date. Cancel it and free the table?',
        style: TextStyle(color: TC.textSec)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep', style: TextStyle(color: TC.textSec))),
      ElevatedButton(
        onPressed: () { prov.cancelReservation(table.id); Navigator.pop(ctx); Navigator.pop(ctx); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text('Cancel'),
      ),
    ],
  ));

  void _confirmNoShow(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: TC.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Mark as No-Show?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri)),
    content: Text('${table.reservation?.customerName ?? 'The guest'} never arrived. '
        'The table will be freed and the booking marked as no-show.',
        style: const TextStyle(color: TC.textSec)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Back', style: TextStyle(color: TC.textSec))),
      ElevatedButton(
        onPressed: () { prov.markNoShow(table.id); Navigator.pop(ctx); Navigator.pop(ctx); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B7280),
            foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text('No Show'),
      ),
    ],
  ));

  void _confirmCancel(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: TC.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Cancel Reservation?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri)),
    content: Text('The reservation for ${table.reservation?.customerName ?? 'this guest'} will be cancelled.',
        style: const TextStyle(color: TC.textSec)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep', style: TextStyle(color: TC.textSec))),
      ElevatedButton(
        onPressed: () { prov.cancelReservation(table.id); Navigator.pop(ctx); Navigator.pop(ctx); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: const Text('Cancel Booking'),
      ),
    ],
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVAILABLE SECTION
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider  prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.available.withOpacity(0.25))),
        child: const Row(children: [
          Text('✅', style: TextStyle(fontSize: 28)),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Table is Ready',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.available)),
            SizedBox(height: 3),
            Text('Walk-in guests can be seated now',
                style: TextStyle(fontSize: 12, color: TC.textSec)),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ActionBtn(
            label: 'Reserve Table', emoji: '📅',
            color: TC.reserved, outlined: true,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(value: prov,
                    child: ReservationSheet(tableId: table.id, provider: prov)));
            })),
        const SizedBox(width: 10),
        Expanded(child: ActionBtn(
            label: 'Seat Walk-in', emoji: '🚶', color: TC.accent,
            onTap: () { prov.seatGuests(table.id, 'Walk-in Guest'); Navigator.pop(context); })),
      ]),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CLEANING SECTION
// ══════════════════════════════════════════════════════════════════════════════

class CleaningSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider  prov;
  const CleaningSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: TC.cleaningBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.cleaning.withOpacity(0.2))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🧹', style: TextStyle(fontSize: 28)),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Being Cleaned',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.cleaning)),
            SizedBox(height: 4),
            Text('Staff are cleaning this table.\n'
                'Tap "Mark as Available" once it is clean and ready for new guests.',
                style: TextStyle(fontSize: 12, color: TC.textSec, height: 1.4)),
          ])),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ℹ️', style: TextStyle(fontSize: 13)), SizedBox(width: 8),
          Expanded(child: Text(
              '"Cleaning" status is automatically set when a table is cleared after guests leave. '
              'It prevents new guests from being seated at a dirty table. '
              'Tap the button below once the table is wiped and reset.',
              style: TextStyle(fontSize: 11, color: TC.textSec, height: 1.4))),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ActionBtn(
          label: 'Mark as Available', emoji: '✅', color: TC.available,
          onTap: () { prov.markAvailable(table.id); Navigator.pop(context); })),
    ]);
  }
}

*/

/*import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:provider/provider.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/seated_duration_timer.dart';
import 'reservation_sheet.dart';
import 'add_edit_table_sheet.dart';

// ══════════════════════════════════════════════════════════════
//  TABLE DETAIL SHEET
//  Opened when a table card is tapped on the floor view.
//  Shows different sections depending on table status:
//    - occupied  → live duration timer + clear/checkout actions
//    - reserved  → reservation info + Seat / No-Show / Cancel / Edit
//    - available → quick reserve or seat walk-in
//    - cleaning  → explains cleaning state + mark available button
// ══════════════════════════════════════════════════════════════
class TableDetailSheet extends StatelessWidget {
  final RestaurantTable table;
  const TableDetailSheet({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<TablesProvider>();
    final sc = statusColor(table.status);
    final sb = statusBg(table.status);
    final secCol = sectionColor(table.section);
    final secBg = sectionBg(table.section);
    log(
      'reserved by: ${table.reservation?.createdByName} (${table.reservation?.createdByRole})==>',
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Table header ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TableIconWidget(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Table ${table.tableNumber}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (table.isPremium)
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _Badge(
                              text:
                                  '${table.section.emoji} ${table.section.label}',
                              color: secCol,
                              bg: secBg,
                            ),
                            const SizedBox(width: 6),
                            _Badge(text: table.status.label, color: sc, bg: sb),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ── Edit table button ───────────────────
                  if (prov.canManageTables)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: prov,
                            child: AddEditTableSheet(
                              provider: prov,
                              editTable: table,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: TC.border),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: TC.textSec,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: TC.divider),
            // ── Content ────────────────────────────────────
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Info tiles row ──────────────────────
                  Row(
                    children: [
                      InfoTile(
                        label: 'Capacity',
                        value: '${table.capacity} seats',
                        emoji: '👥',
                      ),
                      const SizedBox(width: 10),
                      InfoTile(
                        label: 'Floor',
                        value: table.section.floor,
                        emoji: '🏢',
                      ),
                      const SizedBox(width: 10),
                      InfoTile(
                        label: 'Shape',
                        value: table.shape.name.capitalize(),
                        emoji: '⬜',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Status-specific section ─────────────
                  if (table.status == TableStatus.occupied)
                    OccupiedSection(table: table, prov: prov)
                  else if (table.status == TableStatus.reserved)
                    ReservationSection(table: table, prov: prov)
                  else if (table.status == TableStatus.available)
                    AvailableSection(table: table, prov: prov)
                  else
                    CleaningSection(table: table, prov: prov),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small label badge ──────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _Badge({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  OCCUPIED SECTION
//  Shows who is seated, for how long (live timer), and
//  gives the option to clear the table (→ cleaning status).
// ══════════════════════════════════════════════════════════════
class OccupiedSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const OccupiedSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Current Occupancy'),

        // Live seated duration timer widget
        if (table.occupiedSince != null) ...[
          SeatedDurationTimer(
            occupiedSince: table.occupiedSince,
            showWarning: true,
            warningMinutes: 90,
            dangerMinutes: 150,
          ),
          const SizedBox(height: 12),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              DetailRow(
                icon: '👤',
                label: 'Customer',
                value: table.currentCustomerName ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🧾',
                label: 'Order',
                value: table.currentOrderId ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '💰',
                label: 'Bill so far',
                value: table.currentOrderTotal != null
                    ? '₹${table.currentOrderTotal!.toInt()}'
                    : '—',
              ),
              if (table.occupiedSince != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: _fmtTime(table.occupiedSince!),
                ),
              ],
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '⏱️',
                label: 'Duration',
                value: table.occupiedDuration,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Clear Table → moves status to "cleaning"
        ActionBtn(
          label: 'Clear Table (Needs Cleaning)',
          emoji: '🧹',
          color: TC.cleaning,
          onTap: () {
            prov.clearTable(table.id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suffix';
  }
}

// ══════════════════════════════════════════════════════════════
//  RESERVATION SECTION
//  Shown when the table status is "reserved" and a today's
//  reservation is attached.
//
//  Actions:
//    ✅ Seat Guests  — guest arrived, move to occupied
//    👻 No Show      — guest never came, free the table
//    ✖  Cancel       — staff-initiated cancellation
//    ✏  Edit         — modify reservation details
// ══════════════════════════════════════════════════════════════
class ReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const ReservationSection({
    super.key,
    required this.table,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    // Guard: reservation can be null if the table is marked reserved in DB
    // but today's reservation filter dropped it (e.g. timezone mismatch,
    // or the reservation was for a different date). Show a safe fallback.
    final res = table.reservation;
    if (res == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TC.reserved.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Text('📅', style: TextStyle(fontSize: 28)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TC.reserved,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Reservation is for a different date.\nView it in the Calendar tab.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TC.textSec,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ActionBtn(
            label: 'Cancel Reservation',
            emoji: '✖️',
            color: const Color(0xFFDC2626),
            outlined: true,
            onTap: () => _confirmCancelById(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Reservation Details'),

        // ── Reservation info card ────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.reservedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.reserved.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              DetailRow(icon: '👤', label: 'Guest', value: res.customerName),
              const Divider(height: 20, color: TC.divider),
              DetailRow(icon: '📱', label: 'Phone', value: res.phone ?? '—'),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '👥',
                label: 'Party size',
                value: '${res.guestCount} guests',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🗓️',
                label: 'Reserved at',
                value: '${res.dateLabel} at ${res.reservationTimeLabel}',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🟢',
                label: 'Scheduled check-in',
                value: res.timeLabel,
              ),
              if (res.checkIn != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '✅',
                  label: 'Actual check-in',
                  value: res.checkInTimeLabel,
                ),
              ],
              if (res.checkOut != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🔴',
                  label: 'Check-out',
                  value: res.checkOutTimeLabel,
                ),
              ],
              const Divider(height: 20, color: TC.divider),
              DetailRow(icon: '⏰', label: 'Arrives', value: res.countdownLabel),
              if (res.createdByName != null || res.createdByRole != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🏷️',
                  label: 'Reserved by',
                  value: res.createdByName ?? res.createdByRole ?? 'Staff',
                ),
              ],
              if (res.notes != null && res.notes!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Action buttons ───────────────────────────────
        // Row 1: Seat Guests (primary) + No Show
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ActionBtn(
                label: 'Seat Guests',
                emoji: '🍽️',
                color: TC.available,
                onTap: () {
                  prov.seatGuests(table.id, res.customerName);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ActionBtn(
                label: 'No Show',
                emoji: '👻',
                color: const Color(0xFF6B7280),
                outlined: true,
                onTap: () => _confirmNoShow(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Cancel + Edit
        Row(
          children: [
            Expanded(
              child: ActionBtn(
                label: 'Cancel',
                emoji: '✖️',
                color: const Color(0xFFDC2626),
                outlined: true,
                onTap: () => _confirmCancel(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionBtn(
                label: 'Edit',
                emoji: '✏️',
                color: TC.accent,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: prov,
                      child: ReservationSheet(
                        tableId: table.id,
                        provider: prov,
                        existing: res,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // ── No-show explanation hint ─────────────────────
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ℹ️', style: TextStyle(fontSize: 13)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"No Show" means the guest made a reservation but never arrived. '
                  'The table will be freed and the booking recorded as no-show.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TC.textSec,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Used when reservation is null (date mismatch) — cancel by table ID
  void _confirmCancelById(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Reservation?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: const Text(
          'This reservation is for a different date. Cancel it and free the table?',
          style: TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.cancelReservation(table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmNoShow(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mark as No-Show?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: Text(
          '${table.reservation?.customerName ?? 'The guest'} never arrived. '
          'The table will be freed and the booking marked as no-show.',
          style: const TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.markNoShow(table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7280),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('No Show'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Reservation?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: Text(
          'The reservation for ${table.reservation?.customerName ?? 'this guest'} '
          'will be cancelled.',
          style: const TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.cancelReservation(table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AVAILABLE SECTION
//  Table is clean and ready — staff can take a walk-in
//  or set a reservation for an upcoming guest.
// ══════════════════════════════════════════════════════════════
class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.available.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table is Ready',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.available,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Walk-in guests can be seated now',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // \u2705 Upcoming reservation warning banner
        if (upcomingRes != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE8860A).withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u26a0\ufe0f', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Reservation',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${upcomingRes.customerName} \u00b7 ${upcomingRes.guestCount} guests',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      Text(
                        'At ${upcomingRes.timeLabel}${upcomingRes.checkOut != null ? " \u2013 ${upcomingRes.checkOutTimeLabel}" : ""}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Table auto-locks 60 min before reservation.',
                        style: TextStyle(
                          fontSize: 10, fontStyle: FontStyle.italic,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (upcomingRes == null) ...[
              Expanded(
                child: ActionBtn(
                  label: 'Reserve Table',
                  emoji: '\ud83d\udcc5',
                  color: TC.reserved,
                  outlined: true,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ChangeNotifierProvider.value(
                        value: prov,
                        child: ReservationSheet(
                          tableId: table.id,
                          provider: prov,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ActionBtn(
                label: 'Seat Walk-in',
                emoji: '\ud83d\udeb6',
                color: TC.accent,
                onTap: () {
                  prov.seatGuests(table.id, 'Walk-in Guest');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CLEANING SECTION
//
//  What is "Cleaning"?
//  ─────────────────────────────────────────────────────────────
//  After guests leave, a table is set to "Cleaning" status.
//  This means the table is NOT yet ready for new guests —
//  staff are currently cleaning it (wiping, resetting).
//  Once cleaned, staff tap "Mark as Available" and the table
//  goes back to green (Available) so new guests can be seated.
//
//  This prevents accidentally seating new guests at a dirty table.
// ══════════════════════════════════════════════════════════════
class CleaningSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const CleaningSection({super.key, required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cleaning status banner ───────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.cleaningBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.cleaning.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🧹', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Being Cleaned',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.cleaning,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Staff are cleaning this table.\n'
                      'Tap "Mark as Available" once it is clean and ready for new guests.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.textSec,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── What does "cleaning" mean? ───────────────────
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ℹ️', style: TextStyle(fontSize: 13)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"Cleaning" status is automatically set when a table is cleared after '
                  'guests leave. It prevents new guests from being seated at a dirty table. '
                  'Tap the button below once the table is wiped and reset.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TC.textSec,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // ── Mark available button ────────────────────────
        SizedBox(
          width: double.infinity,
          child: ActionBtn(
            label: 'Mark as Available',
            emoji: '✅',
            color: TC.available,
            onTap: () {
              prov.markAvailable(table.id);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
*/