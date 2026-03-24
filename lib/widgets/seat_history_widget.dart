// lib/widgets/seat_history_widget.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT HISTORY WIDGETS
//  Display guest seat usage history with duration, analytics, and session details.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/models/seat_history_model.dart';

/// Main widget to display seat session history
class SeatHistoryView extends StatefulWidget {
  final String seatLabel;
  final String tableNumber;
  final List<SeatSessionHistory> sessions;
  final SeatHistorySummary? summary;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const SeatHistoryView({
    Key? key,
    required this.seatLabel,
    required this.tableNumber,
    required this.sessions,
    this.summary,
    this.isLoading = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<SeatHistoryView> createState() => _SeatHistoryViewState();
}

class _SeatHistoryViewState extends State<SeatHistoryView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seat ${widget.seatLabel} History'),
            Text(
              'Table ${widget.tableNumber}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
      ),
      body: widget.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                if (widget.summary != null)
                  _SeatHistorySummaryCard(summary: widget.summary!),

                // Sessions list
                Expanded(
                  child: widget.sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No session history',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => widget.onRefresh?.call(),
                          child: ListView.builder(
                            itemCount: widget.sessions.length,
                            itemBuilder: (context, index) {
                              final session = widget.sessions[index];
                              return _SeatSessionCard(
                                session: session,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) =>
                                        _SeatSessionDetails(session: session),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Summary card showing aggregate statistics
class _SeatHistorySummaryCard extends StatelessWidget {
  final SeatHistorySummary summary;

  const _SeatHistorySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seat Analytics',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'Total Visits',
                value: summary.totalSessions.toString(),
              ),
              _StatItem(
                label: 'Total Guests',
                value: summary.totalGuests.toString(),
              ),
              _StatItem(
                label: 'Avg Duration',
                value: _formatDuration(summary.averageDuration),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Total: ${_formatDuration(summary.totalDuration)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60);
      return '${d.inHours}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${d.inMinutes}m';
  }
}

/// Individual stat item in summary
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}

/// Session card in the list
class _SeatSessionCard extends StatelessWidget {
  final SeatSessionHistory session;
  final VoidCallback? onTap;

  const _SeatSessionCard({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = session.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Colors.orange.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? Icons.hourglass_bottom : Icons.check_circle,
            color: isActive ? Colors.orange : Colors.green,
          ),
        ),
        title: Text(
          session.customerName ?? 'Guest',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${session.checkInTimeFormatted} → ${session.checkOutTimeFormatted}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Guest count: ${session.guestCount}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              session.formattedDuration,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              session.dateFormatted,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed session view (bottom sheet)
class _SeatSessionDetails extends StatelessWidget {
  final SeatSessionHistory session;

  const _SeatSessionDetails({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${session.sessionId.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: session.isActive ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guest information
                  _DetailSection(
                    title: 'Guest Information',
                    items: [
                      _DetailItem(
                        label: 'Name',
                        value: session.customerName ?? 'Guest',
                      ),
                      _DetailItem(
                        label: 'Guest Count',
                        value: session.guestCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Timing information
                  _DetailSection(
                    title: 'Timing Details',
                    items: [
                      _DetailItem(
                        label: 'Check-in Time',
                        value: _formatDateTime(session.checkInTime),
                      ),
                      _DetailItem(
                        label: 'Check-out Time',
                        value: session.checkOutTime != null
                            ? _formatDateTime(session.checkOutTime!)
                            : 'Still seated / Not checked out',
                      ),
                      _DetailItem(
                        label: 'Duration',
                        value: session.formattedDuration,
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Seat information
                  _DetailSection(
                    title: 'Seat Information',
                    items: [
                      _DetailItem(
                        label: 'Table Number',
                        value: session.tableNumber.toString(),
                      ),
                      _DetailItem(
                        label: 'Seat Label',
                        value: session.seatLabel,
                      ),
                      _DetailItem(label: 'Section', value: session.section),
                    ],
                  ),

                  if (session.notes != null) ...[
                    const SizedBox(height: 24),
                    _DetailSection(
                      title: 'Notes',
                      items: [_DetailItem(label: '', value: session.notes!)],
                    ),
                  ],

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }
}

/// Detail section with title and items
class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailItem> items;

  const _DetailSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

/// Individual detail item
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DetailItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 16 : 14,
                color: highlight ? Colors.blue.shade600 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact history indicator widget (for dashboard)
class SeatHistoryIndicator extends StatelessWidget {
  final String seatLabel;
  final List<SeatSessionHistory> recentSessions;
  final VoidCallback? onTap;

  const SeatHistoryIndicator({
    Key? key,
    required this.seatLabel,
    required this.recentSessions,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (recentSessions.isEmpty) {
      return const SizedBox.shrink();
    }

    final lastSession = recentSessions.first;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'View seat history',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text(
                '${recentSessions.length} visits',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
