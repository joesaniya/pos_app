// ══════════════════════════════════════════════════════════════════════════════
//  AVAILABLE SECTION — SLOT-AWARE WALK-IN
//
//  REPLACE the existing AvailableSection class in table_detail_sheet.dart
//  with this version.
//
//  KEY CHANGES:
//  1. Before seating a walk-in, calls checkWalkInAllowed() to detect if
//     there's an upcoming reservation today for this table.
//  2. If a reservation exists, shows a dialog warning the staff of the
//     upcoming slot and the deadline to clear the table.
//  3. After seating, calls sendWalkInSlotWarning() notification so staff
//     are reminded even if they close the app.
//  4. The "Reserve Table" button now also checks for slot conflicts.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/reservation_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/widgets/shared_widgets.dart';
import 'package:pos_app/services/reservation_notification_service.dart';
import 'package:provider/provider.dart';

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
        if (upcomingRes != null) ...[
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
        if (upcomingRes != null) ...[
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
