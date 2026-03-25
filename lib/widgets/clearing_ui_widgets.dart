// lib/widgets/clearing_ui_widgets.dart
// ══════════════════════════════════════════════════════════════════════════════
//  CLEARING UI WIDGETS
//  Reusable widgets for seat-level and table-level clearing operations.
//  Includes confirmation dialogs, action buttons, and real-time status displays.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/clearing_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT CLEARING BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class ClearSeatButton extends StatelessWidget {
  final String tableId;
  final String seatId;
  final String businessId;
  final String seatLabel;
  final VoidCallback? onClearingStarted;
  final VoidCallback? onClearingCompleted;
  final VoidCallback? onClearingFailed;

  const ClearSeatButton({
    Key? key,
    required this.tableId,
    required this.seatId,
    required this.businessId,
    required this.seatLabel,
    this.onClearingStarted,
    this.onClearingCompleted,
    this.onClearingFailed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isClearing = context.watch<ClearingProvider>().isLoading;

    return ElevatedButton.icon(
      onPressed: isClearing ? null : () => _showConfirmationDialog(context),
      icon: isClearing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.check_circle),
      label: Text(isClearing ? 'Clearing...' : 'Clear Seat'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final provider = context.read<ClearingProvider>();

    // Fetch seat details for preview
    await provider.fetchSeatDetails(seatId);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Seat $seatLabel?'),
        content: Consumer<ClearingProvider>(
          builder: (context, provider, _) {
            final details = provider.selectedSeatDetails;
            if (details == null) {
              return SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final seat = details['seat'] as Map<String, dynamic>?;
            final orders = details['orders'] as List?;
            final totalBill = (seat?['total_bill'] as num?)?.toDouble() ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${seat?['customer_name'] ?? 'Unassigned'}'),
                SizedBox(height: 8),
                Text('Active Orders: ${orders?.length ?? 0}'),
                SizedBox(height: 8),
                Text(
                  'Total Bill: \$${totalBill.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This action will mark the seat as available and complete all associated orders.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              onClearingStarted?.call();

              final success = await provider.clearSeat(
                tableId: tableId,
                seatId: seatId,
                businessId: businessId,
                requireConfirmation: false,
              );

              if (success) {
                onClearingCompleted?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seat $seatLabel cleared successfully'),
                    ),
                  );
                }
              } else {
                onClearingFailed?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear seat'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear Seat'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TABLE CLEARING BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class ClearTableButton extends StatelessWidget {
  final String tableId;
  final String tableNumber;
  final String businessId;
  final VoidCallback? onClearingStarted;
  final VoidCallback? onClearingCompleted;
  final VoidCallback? onClearingFailed;

  const ClearTableButton({
    Key? key,
    required this.tableId,
    required this.tableNumber,
    required this.businessId,
    this.onClearingStarted,
    this.onClearingCompleted,
    this.onClearingFailed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isClearing = context.watch<ClearingProvider>().isLoading;

    return ElevatedButton.icon(
      onPressed: isClearing ? null : () => _showConfirmationDialog(context),
      icon: isClearing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.cleaning_services),
      label: Text(isClearing ? 'Clearing...' : 'Clear Table'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final provider = context.read<ClearingProvider>();

    // Fetch table seat summaries
    await provider.fetchTableSeatSummaries(tableId);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Table $tableNumber?'),
        content: Consumer<ClearingProvider>(
          builder: (context, provider, _) {
            final summaries = provider.tableSeatSummaries;
            if (summaries.isEmpty) {
              return SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final occupiedSeats = provider.getOccupiedSeatsCount();
            final totalOrders = provider.getTableTotalOrderCount();
            final totalBill = provider.getTableTotalBill();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Occupied Seats: $occupiedSeats'),
                SizedBox(height: 8),
                Text('Total Active Orders: $totalOrders'),
                SizedBox(height: 8),
                Text(
                  'Total Bill: \$${totalBill.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Seats to Clear:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: summaries.length,
                    itemBuilder: (_, index) {
                      final seat = summaries[index];
                      final label = seat['seat_label'] as String?;
                      final customer = seat['customer_name'] as String?;
                      final status = seat['status'] as String?;

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• $label: ${customer ?? 'Unassigned'} ($status)',
                          style: TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              onClearingStarted?.call();

              final success = await provider.clearEntireTable(
                tableId: tableId,
                businessId: businessId,
                requireConfirmation: false,
              );

              if (success) {
                onClearingCompleted?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Table $tableNumber cleared successfully'),
                    ),
                  );
                }
              } else {
                onClearingFailed?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear table'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear Entire Table'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT CLEARING OPTIONS MENU
// ══════════════════════════════════════════════════════════════════════════════

class SeatClearingMenu extends StatelessWidget {
  final String tableId;
  final List<Map<String, dynamic>> seats;
  final String businessId;
  final VoidCallback? onSeatCleared;

  const SeatClearingMenu({
    Key? key,
    required this.tableId,
    required this.seats,
    required this.businessId,
    this.onSeatCleared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Seat to Clear')),
      body: ListView.builder(
        itemCount: seats.length + 1,
        itemBuilder: (context, index) {
          // Last item: Clear All
          if (index == seats.length) {
            return Padding(
              padding: EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final provider = context.read<ClearingProvider>();
                  final success = await provider.clearEntireTable(
                    tableId: tableId,
                    businessId: businessId,
                  );

                  if (success) {
                    onSeatCleared?.call();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: Icon(Icons.delete_sweep),
                label: Text('Clear All Seats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            );
          }

          final seat = seats[index];
          final seatId = seat['id'] as String?;
          final label = seat['seat_label'] as String?;
          final customer = seat['customer_name'] as String?;
          final status = seat['status'] as String?;
          final bill = (seat['total_bill'] as num?)?.toDouble() ?? 0;
          final orderCount = (seat['order_count'] as num?)?.toInt() ?? 0;

          if (status != 'occupied') {
            return Opacity(
              opacity: 0.5,
              child: ListTile(
                title: Text('$label - Unoccupied'),
                subtitle: Text('No active orders'),
                enabled: false,
              ),
            );
          }

          return ListTile(
            title: Text('$label - $customer'),
            subtitle: Text(
              '$orderCount order(s) • \$${bill.toStringAsFixed(2)}',
            ),
            trailing: Icon(Icons.arrow_forward),
            onTap: seatId == null
                ? null
                : () async {
                    final provider = context.read<ClearingProvider>();
                    final success = await provider.clearSeat(
                      tableId: tableId,
                      seatId: seatId,
                      businessId: businessId,
                    );

                    if (success) {
                      onSeatCleared?.call();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CLEARING STATUS DISPLAY
// ══════════════════════════════════════════════════════════════════════════════

class ClearingStatusIndicator extends StatelessWidget {
  final Duration displayDuration;

  const ClearingStatusIndicator({
    Key? key,
    this.displayDuration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ClearingProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        if (state.action == ClearingAction.idle) {
          return SizedBox.shrink();
        }

        String message = '';
        Color bgColor = Colors.green;
        IconData icon = Icons.check_circle;

        switch (state.action) {
          case ClearingAction.seatCleared:
            message =
                'Seat ${state.seatId} cleared (${state.remainingSeats} occupied remaining)';
            bgColor = Colors.green;
            icon = Icons.check_circle;
            break;

          case ClearingAction.tableCleared:
            message =
                'Table ${state.tableId} cleared (${state.clearedOrdersCount} orders completed)';
            bgColor = Colors.green;
            icon = Icons.check_circle;
            break;

          case ClearingAction.error:
            message = state.errorMessage ?? 'Error during clearing';
            bgColor = Colors.red;
            icon = Icons.error;
            break;

          case ClearingAction.loading:
            return SizedBox(
              height: 60,
              child: Card(
                color: Colors.blue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Processing clearing operation...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );

          default:
            return SizedBox.shrink();
        }

        // Auto-dismiss after duration
        Future.delayed(displayDuration, () {
          if (context.mounted) {
            provider.resetState();
          }
        });

        return Card(
          color: bgColor,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(message, style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
