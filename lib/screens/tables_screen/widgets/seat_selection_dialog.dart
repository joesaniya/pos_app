import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/utils/ist_utils.dart';

class SeatSelectionDialog extends StatefulWidget {
  final RestaurantTable table;

  const SeatSelectionDialog({super.key, required this.table});

  @override
  State<SeatSelectionDialog> createState() => _SeatSelectionDialogState();
}

class _SeatSelectionDialogState extends State<SeatSelectionDialog> {
  final Set<String> _selectedSeatIds = {};

  // ✅ Check if table has an active reservation (between check-in and checkout)
  bool _isReservationActive() {
    final res = widget.table.reservation;
    if (res == null) return false;

    final now = nowIST();
    final checkIn = res.checkIn;
    final checkOut = res.checkOut;

    if (checkIn == null || checkOut == null) return false;

    // Check if current time is between check-in and check-out
    return now.isAfter(checkIn) && now.isBefore(checkOut);
  }

  @override
  Widget build(BuildContext context) {
    final allSeats = widget.table.seats;
    final availableSeats = allSeats.where((s) => s.isAvailable).toList();
    final occupiedSeats = allSeats.where((s) => s.isOccupied).toList();

    // ✅ Check if reservation is currently active
    final isReservationActive = _isReservationActive();
    final res = widget.table.reservation;

    return AlertDialog(
      backgroundColor: TC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Seats',
            style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          const SizedBox(height: 4),
          if (isReservationActive)
            Text(
              '⏰ Active reservation — seats locked until ${res?.checkOut != null ? '${res!.checkOut!.hour.toString().padLeft(2, '0')}:${res.checkOut!.minute.toString().padLeft(2, '0')}' : 'checkout'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            )
          else
            Text(
              '${widget.table.tableName}  ·  ${availableSeats.length}/${allSeats.length} available',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TC.textSec,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Show lock message if reservation is active
            if (isReservationActive)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Table is locked during active reservation. Seats cannot be selected until ${res?.checkOut != null ? '${res!.checkOut!.hour.toString().padLeft(2, '0')}:${res.checkOut!.minute.toString().padLeft(2, '0')}' : 'checkout'}.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Tap seats to select. Leave empty to book entire table.',
                style: TextStyle(color: TC.textSec, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Available seats — selectable
              if (availableSeats.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSeats.map((seat) {
                    final isSelected = _selectedSeatIds.contains(seat.id);
                    return FilterChip(
                      label: Text('Seat ${seat.seatLabel}'),
                      selected: isSelected,
                      selectedColor: TC.accent.withOpacity(0.2),
                      checkmarkColor: TC.accent,
                      backgroundColor: TC.surfaceWarm,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSeatIds.add(seat.id);
                          } else {
                            _selectedSeatIds.remove(seat.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

              // Occupied seats — disabled, with customer name
              if (occupiedSeats.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Occupied',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TC.textMute,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: occupiedSeats.map((seat) {
                    return Chip(
                      label: Text(
                        'Seat ${seat.seatLabel} · ${seat.customerName ?? 'Guest'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: TC.textMute,
                        ),
                      ),
                      backgroundColor: const Color(0xFFF3F4F6),
                      side: BorderSide(color: TC.occupied.withOpacity(0.3)),
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: TC.occupied.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
        ),
        if (!isReservationActive)
          ElevatedButton(
            onPressed: availableSeats.isEmpty
                ? null
                : () {
                    Navigator.pop(context, _selectedSeatIds.toList());
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: TC.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _selectedSeatIds.isEmpty
                  ? 'Seat Whole Table (Full)'
                  : 'Seat Selected (Partial)',
            ),
          )
        else
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: TC.textMute,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Locked'),
          ),
      ],
    );
  }
}
