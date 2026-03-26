import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/models/table_modal.dart';

/// Admin Emergency Expiry Tool
/// Use this to manually expire reservations when auto-expiry fails
class ReservationExpiryTool extends StatefulWidget {
  final String reservationId;
  final String customerName;

  const ReservationExpiryTool({
    required this.reservationId,
    required this.customerName,
    Key? key,
  }) : super(key: key);

  @override
  State<ReservationExpiryTool> createState() => _ReservationExpiryToolState();
}

class _ReservationExpiryToolState extends State<ReservationExpiryTool> {
  bool _isExpiring = false;
  String? _result;

  Future<void> _expireNow() async {
    setState(() {
      _isExpiring = true;
      _result = null;
    });

    try {
      final provider = context.read<TablesProvider>();
      final success = await provider.manuallyExpireReservation(
        widget.reservationId,
      );

      setState(() {
        _result = success
            ? '✅ Reservation expired successfully'
            : '❌ Failed to expire reservation';
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reservation for ${widget.customerName} expired'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isExpiring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manually Expire Reservation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer: ${widget.customerName}'),
          Text('ID: ${widget.reservationId}'),
          const SizedBox(height: 16),
          const Text(
            'This will immediately mark the reservation as "Expired" and free the table.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _result!.contains('✅')
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_result!, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isExpiring ? null : _expireNow,
          icon: _isExpiring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isExpiring ? 'Expiring...' : 'Expire Now'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
      ],
    );
  }
}

/// Force Refresh Button Component
/// Use this to manually trigger calendar refresh + expiry check
class ForceRefreshExpiryButton extends StatefulWidget {
  const ForceRefreshExpiryButton({Key? key}) : super(key: key);

  @override
  State<ForceRefreshExpiryButton> createState() =>
      _ForceRefreshExpiryButtonState();
}

class _ForceRefreshExpiryButtonState extends State<ForceRefreshExpiryButton> {
  bool _isRefreshing = false;

  Future<void> _forceRefresh() async {
    setState(() => _isRefreshing = true);

    try {
      final provider = context.read<TablesProvider>();
      // Force refresh calendar data
      await provider.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data refreshed and expiry check triggered'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isRefreshing ? null : _forceRefresh,
      icon: _isRefreshing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              ),
            )
          : const Icon(Icons.refresh),
      label: Text(_isRefreshing ? 'Refreshing...' : 'Force Refresh'),
    );
  }
}
