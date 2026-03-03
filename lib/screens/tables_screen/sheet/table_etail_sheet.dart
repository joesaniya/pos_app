import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/utils/ist_utils.dart';
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
  final String id, name;
  final int quantity;
  final double unitPrice, subtotal;
  final bool isVeg;
  final String? category, notes;
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
  final String id, status;
  final int orderNumber;
  final double subtotal, taxAmount, total;
  final String? notes;
  final String createdByName;
  final DateTime createdAt;
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
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
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
            // Body
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
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
  double _grandTotal = 0, _grandSub = 0, _grandTax = 0;
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

  // ── Load orders for THIS session only ──────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessionId = widget.table.sessionId;

      // Fetch all active orders for this table.
      // Filter by session_id in Dart so we handle nulls safely:
      //   - orders matching current session  → show
      //   - orders with null session_id      → show (pre-session orders)
      //   - orders from a different session  → hide (belong to past customer)
      final allOrderRows = await _db
          .from('orders')
          .select(
            'id, order_number, status, subtotal, tax_amount, '
            'total_amount, notes, created_at, created_by_name, session_id',
          )
          .eq('table_id', widget.table.id)
          .inFilter('status', ['pending', 'preparing', 'ready'])
          .order('created_at', ascending: true);

      // Keep orders that belong to this session or have no session yet
      final orderRows = (allOrderRows as List).where((o) {
        final orderSession = o['session_id'] as String?;
        if (orderSession == null) return true; // pre-session order
        if (sessionId == null) return true; // table has no session yet
        return orderSession == sessionId; // same session
      }).toList();

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
                quantity: i['quantity'] as int? ?? 1,
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
            orderNumber: o['order_number'] as int? ?? 0,
            status: o['status'] as String? ?? 'pending',
            subtotal: (o['subtotal'] as num? ?? 0).toDouble(),
            taxAmount: (o['tax_amount'] as num? ?? 0).toDouble(),
            total: (o['total_amount'] as num? ?? 0).toDouble(),
            notes: o['notes'] as String?,
            createdByName: o['created_by_name'] as String? ?? 'Staff',
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

  // ── Checkout confirmation ──────────────────────────────────────────────────
  void _confirmCheckout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Checkout Guest?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: Text(
          'Records actual checkout time, closes all active orders, '
          'and marks the table for cleaning.\n\n'
          'Bill: ₹${_grandTotal.toStringAsFixed(0)}',
          style: const TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.prov.checkoutTable(widget.table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TC.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.table.reservation;
    final needsCheckIn =
        res != null && res.checkIn == null && res.status == 'seated';

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

        // ── Occupancy card ─────────────────────────────────────────────────
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

              // ── Scheduled vs actual times ────────────────────────────────
              if (res != null) ...[
                const Divider(height: 20, color: TC.divider),
                // Planned check-in (from booking form)
                DetailRow(
                  icon: '📅',
                  label: 'Planned check-in',
                  value: '${res.dateLabel} at ${res.timeLabel}',
                ),
                if (res.scheduledCheckOut != null) ...[
                  const Divider(height: 20, color: TC.divider),
                  DetailRow(
                    icon: '📅',
                    label: 'Planned check-out',
                    value: res.scheduledCheckOutLabel,
                  ),
                ],
                const Divider(height: 20, color: TC.divider),
                // Actual check-in (recorded by staff)
                DetailRow(
                  icon: '🟢',
                  label: 'Actual check-in',
                  value: res.checkIn != null
                      ? res.checkInTimeLabel
                      : 'Not yet recorded',
                ),
                if (res.checkOut != null) ...[
                  const Divider(height: 20, color: TC.divider),
                  DetailRow(
                    icon: '🔴',
                    label: 'Actual check-out',
                    value: res.checkOutTimeLabel,
                  ),
                ],
              ],

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

        // ── Live orders header ─────────────────────────────────────────────
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
            (o) => _OrderCard(
              order: o,
              stColor: _statusColor(o.status),
              stBg: _statusBg(o.status),
              stEmoji: _statusEmoji(o.status),
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

        // ── Action buttons ─────────────────────────────────────────────────

        // "Mark Checked In" — only when seated but actual check-in not yet recorded
        if (needsCheckIn) ...[
          ActionBtn(
            label: 'Mark Guest Checked In',
            emoji: '🟢',
            color: TC.available,
            onTap: () {
              widget.prov.checkInGuest(widget.table.id);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F8ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TC.available.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The guest is seated but the actual check-in time has not been '
                    'recorded yet. Tap "Mark Guest Checked In" to capture the real '
                    'arrival time for billing and analytics.',
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
          const SizedBox(height: 10),
        ],

        // Checkout — ends session, closes orders, records actual departure
        ActionBtn(
          label: 'Checkout & End Session',
          emoji: '💳',
          color: TC.accent,
          onTap: () => _confirmCheckout(context),
        ),
        const SizedBox(height: 10),

        // Clear (walk-in, no formal checkout)
        ActionBtn(
          label: 'Clear Table (Needs Cleaning)',
          emoji: '🧹',
          color: TC.cleaning,
          outlined: true,
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
          // Header
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

          // Items
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

          // Order totals footer
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
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
//  ERROR / EMPTY
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
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

class _EmptyOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
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

    // Reservation exists but is for a different date
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
            onTap: () {
              prov.cancelReservation(table.id);
              Navigator.pop(context);
            },
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
              // Planned times (from booking form)
              DetailRow(
                icon: '📅',
                label: 'Planned check-in',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
              if (res.scheduledCheckOut != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '📅',
                  label: 'Planned check-out',
                  value: res.scheduledCheckOutLabel,
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
        'The reservation for ${table.reservation?.customerName ?? 'this guest'} '
        'will be cancelled and the time slot will be freed immediately.',
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ActionBtn(
                label: 'Reserve Table',
                emoji: '📅',
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
            Expanded(
              child: ActionBtn(
                label: 'Seat Walk-in',
                emoji: '🚶',
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
                  '"Cleaning" status is set automatically after checkout. '
                  'It prevents new guests from being seated at a dirty table. '
                  'Tap the button below once the table is ready.',
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
