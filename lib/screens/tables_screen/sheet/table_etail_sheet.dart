import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/repositories/orders_repository.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/services/reservation_notification_service.dart';
import 'package:pos_app/utils/ist_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/seated_duration_timer.dart';
import 'reservation_sheet.dart';
import 'seated_reservation_section.dart';
import 'add_edit_table_sheet.dart';
import '../widgets/seat_selection_dialog.dart';

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
  final String? tableSeatId;
  final String? seatLabel;
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
    this.tableSeatId,
    this.seatLabel,
    required this.createdByName,
    required this.createdAt,
    required this.items,
  });
}

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
      'TableDetailSheet id:${table.id} table=${table.tableNumber} status=${table.status}',
    );

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
                            // ✅ FIX: Show reservation status for seated reservations
                            if (table.status == TableStatus.occupied &&
                                table.reservation != null &&
                                table.reservation!.status == 'seated')
                              _Badge(
                                text: '🍽️ Seated',
                                color: TC.available,
                                bg: const Color(0xFFDCFCE7),
                              )
                            else
                              _Badge(
                                text: table.status.label,
                                color: sc,
                                bg: sb,
                              ),
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
                  if (table.status == TableStatus.occupied &&
                      table.reservation != null &&
                      table.reservation!.status == 'seated')
                  // ✅ FIX: Show seated reserved guest section ONLY for reserved guests who are now seated
                  ...[
                    SeatedReservationSection(table: table, prov: prov),
                  ] else if (table.status == TableStatus.occupied)
                  // ✅ FIX: Show occupied details and allow walk-in seating at remaining available seats
                  ...[
                    OccupiedSection(table: table, prov: prov),
                    const SizedBox(height: 16),
                    // Allow walk-in guests to be seated at available seats even if table is partially occupied
                    if (table.availableSeats.isNotEmpty)
                      AvailableSection(table: table, prov: prov),
                  ] else if (table.status == TableStatus.reserved) ...[
                    // ✅ FIX: Show reservation details AND allow walk-in seating at available seats
                    ReservationSection(table: table, prov: prov),
                    const SizedBox(height: 16),
                    // Allow walk-in guests to be seated at available seats even if table is reserved
                    if (table.isPartiallyOccupied ||
                        table.availableSeats.isNotEmpty)
                      AvailableSection(table: table, prov: prov),
                  ] else if (table.status == TableStatus.available) ...[
                    // Show partial occupancy details if some seats are taken
                    if (table.isPartiallyOccupied)
                      OccupiedSection(table: table, prov: prov),
                    AvailableSection(table: table, prov: prov),
                  ] else
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
      final businessId = widget.prov.businessId;
      final orders = await OrdersRepository.instance.fetchTableOrders(
        tableId: widget.table.id,
        businessId: businessId,
      );

      // ✅ FIX: Ensure ONLY active orders are displayed (filter out any completed orders)
      final activeOrders = orders
          .where(
            (o) => ['pending', 'preparing', 'ready'].contains(o.status.value),
          )
          .toList();

      final List<_OrderSummary> summaries = activeOrders.map((o) {
        // ✅ FIX: Calculate correct total (subtotal + tax) if totalAmount is 0
        final correctTotal = o.totalAmount > 0
            ? o.totalAmount
            : (o.subtotal + o.taxAmount);
        return _OrderSummary(
          id: o.id,
          orderNumber: o.orderNumber,
          status: o.status.value,
          subtotal: o.subtotal,
          taxAmount: o.taxAmount,
          total: correctTotal, // ✅ Use corrected total
          notes: o.notes,
          tableSeatId: o.tableSeatId,
          seatLabel: o.seatLabel,
          createdByName: o.createdByName,
          createdAt: o.createdAt,
          items: o.items
              .map(
                (i) => _OrderItem(
                  id: i.id,
                  name: i.itemName,
                  quantity: i.quantity,
                  unitPrice: i.itemPrice,
                  subtotal: i.subtotal,
                  isVeg: i.isVeg,
                  category: i.categoryName,
                  notes: i.notes,
                ),
              )
              .toList(),
        );
      }).toList();

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
    // ✅ FIX: Calculate grand total as sum of all order totals (each = sub + tax)
    _grandTotal = orders.fold(0.0, (s, o) => s + o.total);
    _totalItems = orders.fold(
      0,
      (s, o) => s + o.items.fold(0, (si, i) => si + i.quantity),
    );

    // ✅ FIX: Ensure grand total is correctly calculated
    // If something went wrong, fallback to subtotal + tax
    if (_grandTotal <= 0 && _grandSub > 0) {
      _grandTotal = _grandSub + _grandTax;
    }

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

  /// Shows time only if seated today, adds date if seated on a previous day.
  String _fmtSeatedSince(DateTime since) {
    final now = nowIST();
    final todayDate = DateTime(now.year, now.month, now.day);
    final sinceDate = DateTime(since.year, since.month, since.day);

    final timeStr = fmtTimeIST(since);

    if (sinceDate == todayDate) {
      return timeStr; // same day → "3:52 PM"
    }

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
    return '${months[since.month - 1]} ${since.day}, $timeStr';
  }

  String get _liveDuration {
    final since = widget.table.occupiedSince;
    if (since == null) return '—';
    final diff = elapsedIST(since);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final base = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
    if (h >= 4) return '$base ⚠️';
    return base;
  }

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
                /*DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: fmtTimeIST(widget.table.occupiedSince!),
                ),*/
                DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: _fmtSeatedSince(widget.table.occupiedSince!),
                ),
                const Divider(height: 20, color: TC.divider),
              ],
              /*  DetailRow(
                icon: '⏱️',
                label: 'Duration',
                value: widget.table.occupiedDuration,
              ),*/
              DetailRow(icon: '⏱️', label: 'Duration', value: _liveDuration),
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
              // FIX: Checkout button removed - seats are now auto-released after payment
              // No manual checkout needed anymore
              onCheckoutSeat: null,
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

        // ── Per-seat clear buttons for partial occupancy ──────────────────
        if (widget.table.isPartiallyOccupied) ...[
          const SizedBox(height: 8),
          const Text(
            'CLEAR INDIVIDUAL SEATS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: TC.textMute,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.table.occupiedSeats.map(
            (seat) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ActionBtn(
                label:
                    'Clear Seat ${seat.seatLabel} (${seat.customerName ?? 'Guest'})',
                emoji: '🪑',
                color: TC.cleaning,
                outlined: true,
                onTap: () {
                  widget.prov.clearTable(widget.table.id, seatId: seat.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],

        ActionBtn(
          label: 'Clear Entire Table (Needs Cleaning)',
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

  /// ✅ REMOVED: Checkout button no longer needed
  /// Seats are now auto-released after payment completion
  final VoidCallback? onCheckoutSeat;

  const _OrderCard({
    required this.order,
    required this.stColor,
    required this.stBg,
    required this.stEmoji,
    this.onCheckoutSeat,
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
                      Row(
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: TC.textPri,
                            ),
                          ),
                          if (order.seatLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F0FF),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '💺 Seat ${order.seatLabel}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A7ADB),
                                ),
                              ),
                            ),
                          ],
                        ],
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
    log('Building ReservationSection for table ${table.id}, res: $res');
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
                icon: '🟢',
                label: 'Check-in',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
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
            //edit issue
            /*      const SizedBox(width: 10),
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
        */
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
//  AVAILABLE SECTION — SLOT-AWARE WALK-IN
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  Future<void> _handleSeatWalkIn(BuildContext context) async {
    List<String>? selectedSeats;
    if (table.seats.isNotEmpty) {
      selectedSeats = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => SeatSelectionDialog(table: table),
      );
      if (selectedSeats == null) return; // cancelled
    }

    final check = await prov.checkWalkInAllowed(table.id);

    if (!_isMounted(context)) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be cleared '
                  'before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!_isMounted(context)) return;

      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
        seatIds: selectedSeats != null && selectedSeats.isNotEmpty
            ? selectedSeats
            : null,
      );

      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      Navigator.pop(context);
      await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
        seatIds: selectedSeats != null && selectedSeats.isNotEmpty
            ? selectedSeats
            : null,
      );
    }
  }

  // ── Cancel confirmation for upcoming reservation ──────────────────────────
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

  bool _isMounted(BuildContext context) {
    try {
      context.findRenderObject();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ────────────────────────────────────────────────────
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

        // ── Upcoming reservation info banner ───────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before ${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Reserve / Seat Walk-in row ─────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Info note + Cancel/Edit (only when upcoming reservation exists) ─
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests can be '
                    'seated now, but the table must be cleared before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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

          // ── Cancel / Edit row ──────────────────────────────────────────
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
              /*   const SizedBox(width: 10),
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
                          existing: upcomingRes,
                        ),
                      ),
                    );
                  },
                ),
              ),
           */
            ],
          ),
        ],
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


/*import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/services/reservation_notification_service.dart';
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
            'total_amount, notes, table_seat_id, created_at, created_by_name',
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
            tableSeatId: o['table_seat_id'] as String?,
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
        else ...() {
          final Map<String?, List<_OrderSummary>> groupedOrders = {};
          for (final o in _orders) {
            groupedOrders.putIfAbsent(o.tableSeatId, () => []).add(o);
          }

          final List<Widget> children = [];
          
          for (final entry in groupedOrders.entries) {
            final seatId = entry.key;
            final seatOrders = entry.value;
            String seatName = 'Whole Table';
            if (seatId != null && widget.table.seats != null) {
              final seat = widget.table.seats!.firstWhere(
                (s) => s.id == seatId,
                orElse: () => TableSeat(id: seatId, tableId: widget.table.id, seatLabel: 'Unknown'),
              );
              seatName = 'Seat ${seat.seatLabel}';
            }

            double gSub = seatOrders.fold(0.0, (s, o) => s + o.subtotal);
            double gTax = seatOrders.fold(0.0, (s, o) => s + o.taxAmount);
            double gTot = seatOrders.fold(0.0, (s, o) => s + o.total);
            int tItems = seatOrders.fold(0, (s, o) => s + o.items.fold(0, (ss, i) => ss + i.quantity));

            children.add(
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupedOrders.length > 1 || seatId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          seatName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: TC.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ...seatOrders.map(
                      (order) => _OrderCard(
                        order: order,
                        stColor: _statusColor(order.status),
                        stBg: _statusBg(order.status),
                        stEmoji: _statusEmoji(order.status),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GrandBillCard(
                      orders: seatOrders,
                      grandSub: gSub,
                      grandTax: gTax,
                      grandTotal: gTot,
                      totalItems: tItems,
                    ),
                    const SizedBox(height: 16),
                    ActionBtn(
                      label: seatId == null ? 'Clear Whole Table' : 'Clear $seatName',
                      emoji: '🧹',
                      color: TC.cleaning,
                      onTap: () {
                        widget.prov.clearTable(widget.table.id, seatId: seatId);
                        if (seatId == null || widget.table.seats?.where((s) => s.status == TableStatus.occupied).length == 1) {
                          Navigator.pop(context);
                        } else {
                          // Allow natural refresh via realtime subscription
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (groupedOrders.length > 1) {
            children.add(
              ActionBtn(
                label: 'Clear Entire Table',
                emoji: '🧹',
                color: TC.cleaning,
                onTap: () {
                  widget.prov.clearTable(widget.table.id);
                  Navigator.pop(context);
                },
              ),
            );
          }

          return children;
        }(),
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
                icon: '🟢',
                label: 'Check-in',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
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
//  AVAILABLE SECTION — SLOT-AWARE WALK-IN
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  // ── Format DateTime as "3:00 PM" ─────────────────────────────────────────
  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  // ── Seat walk-in with slot-awareness ────────────────────────────────────
  Future<void> _handleSeatWalkIn(BuildContext context) async {
    // 1. Check if there's an upcoming reservation today
    final check = await prov.checkWalkInAllowed(table.id);

    if (!mounted(context)) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      // 2. Show warning dialog about the upcoming slot
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be cleared '
                  'before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 3. Seat the walk-in
      if (!mounted(context)) return;
      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
      );

      // 4. Send slot warning notification (fires even if app is killed)
      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      // No upcoming reservation — seat normally without dialog
      Navigator.pop(context);
      await prov.seatGuests(table.id, 'Walk-in Guest', isWalkIn: true);
    }
  }

  // Helper to safely check if widget is still mounted
  bool mounted(BuildContext context) {
    try {
      context.findRenderObject();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check for upcoming reservation to show info banner
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ────────────────────────────────────────────────────
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

        // ── Upcoming reservation info banner (shown when table has future res) ──
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before '
                        '${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Action buttons ─────────────────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Slot info note ─────────────────────────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests can be '
                    'seated now, but the table must be cleared before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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
      ],
    );
  }
}

/*
class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  Future<void> _handleSeatWalkIn(BuildContext context) async {
    final check = await prov.checkWalkInAllowed(table.id);

    if (!context.mounted) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be '
                  'cleared before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!context.mounted) return;

      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
      );

      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      Navigator.pop(context);
      await prov.seatGuests(table.id, 'Walk-in Guest', isWalkIn: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ──────────────────────────────────────────────────
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

        // ── Upcoming reservation banner ──────────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before ${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Action buttons ───────────────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Info note when upcoming reservation exists ────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests '
                    'can be seated now, but must leave before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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
      ],
    );
  }
}
*/
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
*/


/*new entire  import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/services/reservation_notification_service.dart';
import 'package:pos_app/utils/ist_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/seated_duration_timer.dart';
import 'reservation_sheet.dart';
import 'add_edit_table_sheet.dart';

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

  /// Shows time only if seated today, adds date if seated on a previous day.
  String _fmtSeatedSince(DateTime since) {
    final now = nowIST();
    final todayDate = DateTime(now.year, now.month, now.day);
    final sinceDate = DateTime(since.year, since.month, since.day);

    final timeStr = fmtTimeIST(since);

    if (sinceDate == todayDate) {
      return timeStr; // same day → "3:52 PM"
    }

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
    return '${months[since.month - 1]} ${since.day}, $timeStr';
  }

  String get _liveDuration {
    final since = widget.table.occupiedSince;
    if (since == null) return '—';
    final diff = elapsedIST(since);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final base = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
    if (h >= 4) return '$base ⚠️';
    return base;
  }

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
                /*DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: fmtTimeIST(widget.table.occupiedSince!),
                ),*/
                DetailRow(
                  icon: '🕐',
                  label: 'Seated since',
                  value: _fmtSeatedSince(widget.table.occupiedSince!),
                ),
                const Divider(height: 20, color: TC.divider),
              ],
              /*  DetailRow(
                icon: '⏱️',
                label: 'Duration',
                value: widget.table.occupiedDuration,
              ),*/
              DetailRow(icon: '⏱️', label: 'Duration', value: _liveDuration),
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

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }

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
                icon: '🟢',
                label: 'Check-in',
                // value: '${_fmtDate(res.dateLabel)} at ${res.timeLabel}',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
              if (res.checkOut != null) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(
                  icon: '🔴',
                  label: 'Check-out',
                  // value: '${_fmtTime(res.checkOutTimeLabel.to)}',
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
            //edit issue
            /*      const SizedBox(width: 10),
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
        */
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
//  AVAILABLE SECTION — SLOT-AWARE WALK-IN
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  Future<void> _handleSeatWalkIn(BuildContext context) async {
    final check = await prov.checkWalkInAllowed(table.id);

    if (!_isMounted(context)) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be cleared '
                  'before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!_isMounted(context)) return;

      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
      );

      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      Navigator.pop(context);
      await prov.seatGuests(table.id, 'Walk-in Guest', isWalkIn: true);
    }
  }

  // ── Cancel confirmation for upcoming reservation ──────────────────────────
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

  bool _isMounted(BuildContext context) {
    try {
      context.findRenderObject();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ────────────────────────────────────────────────────
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

        // ── Upcoming reservation info banner ───────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before ${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Reserve / Seat Walk-in row ─────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Info note + Cancel/Edit (only when upcoming reservation exists) ─
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests can be '
                    'seated now, but the table must be cleared before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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

          // ── Cancel / Edit row ──────────────────────────────────────────
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
              /*   const SizedBox(width: 10),
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
                          existing: upcomingRes,
                        ),
                      ),
                    );
                  },
                ),
              ),
           */
            ],
          ),
        ],
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


/*import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/services/reservation_notification_service.dart';
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
                icon: '🟢',
                label: 'Check-in',
                value: '${res.dateLabel} at ${res.timeLabel}',
              ),
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
//  AVAILABLE SECTION — SLOT-AWARE WALK-IN
// ══════════════════════════════════════════════════════════════════════════════

class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  // ── Format DateTime as "3:00 PM" ─────────────────────────────────────────
  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  // ── Seat walk-in with slot-awareness ────────────────────────────────────
  Future<void> _handleSeatWalkIn(BuildContext context) async {
    // 1. Check if there's an upcoming reservation today
    final check = await prov.checkWalkInAllowed(table.id);

    if (!mounted(context)) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      // 2. Show warning dialog about the upcoming slot
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be cleared '
                  'before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 3. Seat the walk-in
      if (!mounted(context)) return;
      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
      );

      // 4. Send slot warning notification (fires even if app is killed)
      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      // No upcoming reservation — seat normally without dialog
      Navigator.pop(context);
      await prov.seatGuests(table.id, 'Walk-in Guest', isWalkIn: true);
    }
  }

  // Helper to safely check if widget is still mounted
  bool mounted(BuildContext context) {
    try {
      context.findRenderObject();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check for upcoming reservation to show info banner
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ────────────────────────────────────────────────────
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

        // ── Upcoming reservation info banner (shown when table has future res) ──
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before '
                        '${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Action buttons ─────────────────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Slot info note ─────────────────────────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests can be '
                    'seated now, but the table must be cleared before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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
      ],
    );
  }
}

/*
class AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const AvailableSection({super.key, required this.table, required this.prov});

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  Future<void> _handleSeatWalkIn(BuildContext context) async {
    final check = await prov.checkWalkInAllowed(table.id);

    if (!context.mounted) return;

    if (check.nextReservationTime != null) {
      final reservationTime = check.nextReservationTime!;
      final timeStr = _fmtTime(reservationTime);
      final minsUntil = check.minutesUntilReservation ?? 0;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TC.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '⚠️ Upcoming Reservation',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table ${table.tableNumber} has a reservation at $timeStr '
                '($minsUntil min from now).',
                style: const TextStyle(
                  color: TC.textPri,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8860A).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'You can seat a walk-in guest, but the table MUST be '
                  'cleared before $timeStr.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A reminder will be sent 15 minutes before the reservation.',
                style: TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TC.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Seat Walk-in Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!context.mounted) return;

      Navigator.pop(context);
      final result = await prov.seatGuests(
        table.id,
        'Walk-in Guest',
        isWalkIn: true,
      );

      if (result.success) {
        await ReservationNotificationService().sendWalkInSlotWarning(
          tableNumber: table.tableNumber,
          customerName: 'Walk-in Guest',
          reservationTime: reservationTime,
          businessName: prov.currentBusinessName,
        );
      }
    } else {
      Navigator.pop(context);
      await prov.seatGuests(table.id, 'Walk-in Guest', isWalkIn: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcomingRes = table.reservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status card ──────────────────────────────────────────────────
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

        // ── Upcoming reservation banner ──────────────────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TC.reservedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.reserved.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved at ${upcomingRes.timeLabel} for '
                        '${upcomingRes.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TC.reserved,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walk-ins must leave before ${upcomingRes.timeLabel}',
                        style: const TextStyle(fontSize: 11, color: TC.textSec),
                      ),
                    ],
                  ),
                ),
                Text(
                  upcomingRes.countdownLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.reserved,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Action buttons ───────────────────────────────────────────────
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
                label: upcomingRes != null ? 'Seat Walk-in ⚠️' : 'Seat Walk-in',
                emoji: '🚶',
                color: upcomingRes != null
                    ? const Color(0xFFE8860A)
                    : TC.accent,
                onTap: () => _handleSeatWalkIn(context),
              ),
            ),
          ],
        ),

        // ── Info note when upcoming reservation exists ────────────────────
        if (upcomingRes != null && upcomingRes.countdownLabel != 'Overdue') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This table has an upcoming reservation. Walk-in guests '
                    'can be seated now, but must leave before the reserved slot. '
                    'Staff will receive a 15-minute reminder automatically.',
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
      ],
    );
  }
}
*/
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
*/*/
