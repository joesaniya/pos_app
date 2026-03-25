import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import '../widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SEATED RESERVATION SECTION — Reserved guest is now seated and dining
// ══════════════════════════════════════════════════════════════════════════════
//  Shows: Guest details, check-in time, and only Checkout/Clear Table actions
//  Used for: Reserved tables where the guest has arrived and been seated
// ══════════════════════════════════════════════════════════════════════════════

class SeatedReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;

  const SeatedReservationSection({
    super.key,
    required this.table,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final res = table.reservation;
    if (res == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSection('Seated Guest'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              DetailRow(icon: '👤', label: 'Guest', value: res.customerName),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '👥',
                label: 'Party size',
                value: '${res.guestCount} guests',
              ),
              const Divider(height: 20, color: TC.divider),
              DetailRow(
                icon: '🟢',
                label: 'Checked in',
                value: res.checkIn != null
                    ? '${_formatTime(res.checkIn!)} (${_formatDate(res.checkIn!)})'
                    : 'Just now',
              ),
              if (res.phone != null && res.phone!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(icon: '📱', label: 'Phone', value: res.phone ?? '—'),
              ],
              if (res.notes != null && res.notes!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ✅ CRITICAL: Show ONLY Checkout and Clear Table actions for seated reserved guests
        const SheetSection('Actions'),
        Row(
          children: [
            Expanded(
              child: ActionBtn(
                label: 'Checkout',
                emoji: '💳',
                color: TC.accent,
                onTap: () => _confirmCheckout(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionBtn(
                label: 'Clear Table',
                emoji: '🧹',
                color: const Color(0xFF9CA3AF),
                outlined: true,
                onTap: () => _confirmClearTable(context),
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
                  'Guest is now seated. Use "Checkout" to record the checkout time and complete the reservation. Use "Clear Table" to reset the table after guest leaves.',
                  style: TextStyle(
                    fontSize: 12,
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

  void _confirmCheckout(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Checkout Guest?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: Text(
        'Record checkout for ${table.reservation?.customerName ?? 'this guest'}.\n\nThe guest will be marked as checked out and the table can be prepared for the next reservation.',
        style: const TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            prov.clearTable(table.id);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('✓ Checkout completed'),
                duration: Duration(seconds: 2),
              ),
            );
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

  void _confirmClearTable(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Clear Table?',
        style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
      ),
      content: const Text(
        'This will reset the table to available and mark it as needing cleaning. The guest will be checked out if they haven\'t been already.',
        style: TextStyle(color: TC.textSec),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            prov.clearTable(table.id);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('✓ Table cleared'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Clear Table'),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);

  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';

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
  return '${months[dt.month - 1]} ${dt.day}';
}
