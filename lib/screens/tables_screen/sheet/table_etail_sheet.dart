import 'dart:developer';

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
