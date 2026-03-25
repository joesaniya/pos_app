// lib/widgets/seat_management_widgets.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT MANAGEMENT WIDGETS
//  Real-time UI components for displaying seat availability, occupancy, and
//  individual seat status with duration tracking.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/seat_status_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT AVAILABILITY HEADER
//  Displays: Total Seats | Occupied | Available | Occupancy %
// ══════════════════════════════════════════════════════════════════════════════

class SeatAvailabilityHeader extends StatelessWidget {
  final String tableId;
  final int totalSeats;

  const SeatAvailabilityHeader({
    super.key,
    required this.tableId,
    required this.totalSeats,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SeatStatusProvider>(
      builder: (ctx, provider, _) {
        final summary = provider.getTableSeats(tableId);

        if (summary == null) {
          return const SizedBox.shrink();
        }

        final occupancy = summary.occupancyPercentage.toStringAsFixed(0);
        final occupancyColor = _getOccupancyColor(summary.occupancyPercentage);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Total Seats
              _AvailabilityMetric(
                label: 'Total',
                value: summary.totalSeats.toString(),
                color: Colors.grey,
              ),
              const SizedBox(width: 12),

              // Occupied
              _AvailabilityMetric(
                label: 'Occupied',
                value: summary.occupiedSeats.toString(),
                color: Colors.blue,
              ),
              const SizedBox(width: 12),

              // Available
              _AvailabilityMetric(
                label: 'Available',
                value: summary.availableSeats.toString(),
                color: Colors.green,
              ),
              const Spacer(),

              // Occupancy Percentage
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: occupancyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: occupancyColor),
                ),
                child: Text(
                  '$occupancy%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: occupancyColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getOccupancyColor(double percentage) {
    if (percentage == 0) return Colors.green;
    if (percentage < 50) return Colors.orange;
    if (percentage < 100) return Colors.blue;
    return Colors.red;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVAILABILITY METRIC CHIP
// ══════════════════════════════════════════════════════════════════════════════

class _AvailabilityMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AvailabilityMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT GRID WIDGET
//  Displays all seats with status, customer name, and occupancy duration
// ══════════════════════════════════════════════════════════════════════════════

class SeatGridWidget extends StatelessWidget {
  final String tableId;
  final VoidCallback? onSeatTap;
  final Function(SeatStatusInfo)? onSeatSelected;

  const SeatGridWidget({
    super.key,
    required this.tableId,
    this.onSeatTap,
    this.onSeatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SeatStatusProvider>(
      builder: (ctx, provider, _) {
        final summary = provider.getTableSeats(tableId);

        if (summary == null || summary.seatDetails.isEmpty) {
          return const Center(
            child: Text('No seats configured for this table'),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: summary.seatDetails.length,
          itemBuilder: (ctx, index) {
            final seat = summary.seatDetails[index];
            return _SeatCard(
              seat: seat,
              onTap: () {
                onSeatSelected?.call(seat);
                onSeatTap?.call();
              },
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INDIVIDUAL SEAT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _SeatCard extends StatelessWidget {
  final SeatStatusInfo seat;
  final VoidCallback onTap;

  const _SeatCard({required this.seat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOccupied = seat.status == SeatDisplayStatus.occupied;
    final isAvailable = seat.status == SeatDisplayStatus.available;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isAvailable
              ? Colors.grey[100]
              : isOccupied
              ? Colors.blue[50]
              : Colors.amber[50],
          border: Border.all(
            color: seat.statusColor.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isOccupied
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Emoji
                  Text(seat.statusEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),

                  // Seat Label
                  Text(
                    seat.seatLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Status Badge
                  if (isOccupied)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          seat.durationDisplay,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Customer Name (if occupied)
                  if (isOccupied && seat.customerName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        seat.customerName!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT LIST VIEW
//  Alternative to grid for detailed seat information
// ══════════════════════════════════════════════════════════════════════════════

class SeatListWidget extends StatelessWidget {
  final String tableId;
  final Function(SeatStatusInfo)? onSeatSelected;
  final VoidCallback? onClearSeat;

  const SeatListWidget({
    super.key,
    required this.tableId,
    this.onSeatSelected,
    this.onClearSeat,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SeatStatusProvider>(
      builder: (ctx, provider, _) {
        final summary = provider.getTableSeats(tableId);

        if (summary == null || summary.seatDetails.isEmpty) {
          return const Center(child: Text('No seats found'));
        }

        return ListView.separated(
          itemCount: summary.seatDetails.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, index) {
            final seat = summary.seatDetails[index];
            return _SeatListItem(
              seat: seat,
              onTap: () => onSeatSelected?.call(seat),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT LIST ITEM
// ══════════════════════════════════════════════════════════════════════════════

class _SeatListItem extends StatelessWidget {
  final SeatStatusInfo seat;
  final VoidCallback? onTap;

  const _SeatListItem({required this.seat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOccupied = seat.status == SeatDisplayStatus.occupied;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: seat.statusColor.withOpacity(0.2),
          border: Border.all(color: seat.statusColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(seat.statusEmoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
      title: Text(
        seat.seatLabel,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOccupied && seat.customerName != null)
            Text('Guest: ${seat.customerName}')
          else
            Text('Status: ${seat.status.label}'),
          if (isOccupied)
            Text(
              'Duration: ${seat.durationDisplay}',
              style: TextStyle(color: Colors.blue[700]),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: seat.statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: seat.statusColor.withOpacity(0.5)),
        ),
        child: Text(
          seat.status.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: seat.statusColor,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REAL-TIME OCCUPANCY INDICATOR
//  Circular progress indicator showing table occupancy
// ══════════════════════════════════════════════════════════════════════════════

class OccupancyIndicator extends StatelessWidget {
  final String tableId;
  final double size;
  final bool showPercentage;

  const OccupancyIndicator({
    super.key,
    required this.tableId,
    this.size = 60,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SeatStatusProvider>(
      builder: (ctx, provider, _) {
        final summary = provider.getTableSeats(tableId);

        if (summary == null) {
          return SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final percentage = summary.occupancyPercentage / 100;
        final color = _getColorForOccupancy(summary.occupancyPercentage);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
              ),

              // Progress indicator
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(color),
                  backgroundColor: Colors.grey[200],
                ),
              ),

              // Center text
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showPercentage)
                    Text(
                      '${summary.occupancyPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  Text(
                    '${summary.occupiedSeats}/${summary.totalSeats}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getColorForOccupancy(double percentage) {
    if (percentage == 0) return Colors.green;
    if (percentage < 50) return Colors.orange;
    if (percentage < 100) return Colors.blue;
    return Colors.red;
  }
}
