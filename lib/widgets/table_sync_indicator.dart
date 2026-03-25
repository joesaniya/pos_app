// lib/widgets/table_sync_indicator.dart
// ══════════════════════════════════════════════════════════════════════════════
//  TABLE SYNC STATUS INDICATOR
//  Displays real-time synchronization status for table occupancy and orders.
//  Shows warnings when offline and helps users understand data freshness.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/services/connectivity_service.dart';

class TableSyncIndicator extends StatelessWidget {
  final bool isLoading;
  final bool isOnline;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const TableSyncIndicator({
    Key? key,
    this.isLoading = false,
    this.isOnline = true,
    this.lastSyncTime,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);

  String _syncStatusText() {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return '⚠️ Sync error';
    }
    if (!isOnline) {
      return '📴 Offline mode';
    }
    if (isLoading) {
      return '🔄 Syncing...';
    }
    if (lastSyncTime != null) {
      final now = DateTime.now();
      final diff = now.difference(lastSyncTime!);
      if (diff.inSeconds < 60) {
        return '✅ Just synced';
      } else if (diff.inMinutes < 60) {
        return '✅ Synced ${diff.inMinutes}m ago';
      } else {
        return '✅ Synced ${diff.inHours}h ago';
      }
    }
    return '✅ In sync';
  }

  Color _statusColor() {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Colors.red;
    }
    if (!isOnline) {
      return Colors.orange;
    }
    if (isLoading) {
      return Colors.blue;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor().withValues(alpha: 0.1),
        border: Border.all(
          color: _statusColor().withValues(alpha: 0.3),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _syncStatusText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _statusColor(),
            ),
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  TABLE OCCUPANCY STATUS BADGE
// ──────────────────────────────────────────────────────────────────────────────

class TableOccupancyBadge extends StatelessWidget {
  final int availableSeats;
  final int totalSeats;
  final bool isPartiallyOccupied;
  final Color? customColor;

  const TableOccupancyBadge({
    Key? key,
    required this.availableSeats,
    required this.totalSeats,
    this.isPartiallyOccupied = false,
    this.customColor,
  }) : super(key: key);

  Color _getBadgeColor() {
    if (customColor != null) return customColor!;
    if (availableSeats == totalSeats) return const Color(0xFF059669); // Green
    if (availableSeats == 0) return const Color(0xFFDC2626); // Red
    return const Color(0xFFF59E0B); // Amber for partial
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBadgeColor().withValues(alpha: 0.15),
        border: Border.all(
          color: _getBadgeColor().withValues(alpha: 0.3),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            availableSeats == totalSeats
                ? '✓ Available'
                : availableSeats == 0
                ? '✕ Occupied'
                : '⚡ $availableSeats free',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getBadgeColor(),
            ),
          ),
          if (isPartiallyOccupied) ...[
            const SizedBox(width: 4),
            Text(
              '($availableSeats/$totalSeats)',
              style: TextStyle(
                fontSize: 9,
                color: _getBadgeColor().withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  OFFLINE MODE BANNER
// ──────────────────────────────────────────────────────────────────────────────

class OfflineModeBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const OfflineModeBanner({Key? key, this.message, this.onRetry})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Offline Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message ??
                        'You\'re offline. Orders will sync when connection is restored.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
