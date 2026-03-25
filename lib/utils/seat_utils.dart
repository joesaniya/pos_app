// lib/utils/seat_utils.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT UTILITIES
//  Helper functions and utilities for seat management operations
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/seat_status_provider.dart';

/// Utilities for seat-level operations
class SeatUtils {
  SeatUtils._();

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT LABEL GENERATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate standard seat labels (A, B, C, D, etc.)
  static List<String> generateSeatLabels(int count) {
    return List.generate(count, (i) {
      final label = String.fromCharCode(65 + i); // A, B, C, D, ...
      return label;
    });
  }

  /// Generate numbered seat labels (1, 2, 3, 4, etc.)
  static List<String> generateNumberedSeatLabels(int count) {
    return List.generate(count, (i) => (i + 1).toString());
  }

  /// Generate custom seat labels with prefix (e.g., "Window-A", "Corner-B")
  static List<String> generateCustomSeatLabels(int count, String prefix) {
    return List.generate(count, (i) {
      final label = String.fromCharCode(65 + i);
      return '$prefix-$label';
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  OCCUPANCY CALCULATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Calculate occupancy percentage
  static double calculateOccupancy(int occupied, int total) {
    if (total == 0) return 0;
    return (occupied / total) * 100;
  }

  /// Get occupancy level description
  static String getOccupancyLevel(double percentage) {
    if (percentage == 0) return 'Empty';
    if (percentage < 25) return 'Sparse';
    if (percentage < 50) return 'Half-Occupied';
    if (percentage < 75) return 'Busy';
    if (percentage < 100) return 'Very Busy';
    return 'Full';
  }

  /// Get occupancy color
  static Color getOccupancyColor(double percentage) {
    if (percentage == 0) return Colors.green;
    if (percentage < 50) return Colors.orange;
    if (percentage < 100) return Colors.blue;
    return Colors.red;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DURATION FORMATTING
  // ══════════════════════════════════════════════════════════════════════════

  /// Format duration for display
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  /// Format duration in short format (e.g., "2:35")
  static String formatDurationShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '0:${minutes.toString().padLeft(2, '0')}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT STATUS INFO
  // ══════════════════════════════════════════════════════════════════════════

  /// Get emoji for seat status
  static String getStatusEmoji(SeatDisplayStatus status) {
    switch (status) {
      case SeatDisplayStatus.available:
        return '✅';
      case SeatDisplayStatus.occupied:
        return '🪑';
      case SeatDisplayStatus.ordered:
        return '🍽️';
      case SeatDisplayStatus.completed:
        return '✔️';
    }
  }

  /// Get color for seat status
  static Color getStatusColor(SeatDisplayStatus status) {
    switch (status) {
      case SeatDisplayStatus.available:
        return Colors.green;
      case SeatDisplayStatus.occupied:
        return Colors.blue;
      case SeatDisplayStatus.ordered:
        return Colors.amber;
      case SeatDisplayStatus.completed:
        return Colors.purple;
    }
  }

  /// Get readable status label
  static String getStatusLabel(SeatDisplayStatus status) {
    return status.label;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  OCCUPANCY CHECKS
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if table can accept more guests
  static bool canAcceptGuests(SeatAvailabilitySummary summary) {
    return summary.availableSeats > 0;
  }

  /// Check if table is fully occupied
  static bool isFullyOccupied(SeatAvailabilitySummary summary) {
    return summary.occupiedSeats >= summary.totalSeats;
  }

  /// Check if table is partially occupied
  static bool isPartiallyOccupied(SeatAvailabilitySummary summary) {
    return summary.occupiedSeats > 0 &&
        summary.occupiedSeats < summary.totalSeats;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT MANAGEMENT HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Find available seats
  static List<SeatStatusInfo> findAvailableSeats(
    SeatAvailabilitySummary summary,
  ) {
    return summary.seatDetails
        .where((s) => s.status == SeatDisplayStatus.available)
        .toList();
  }

  /// Find occupied seats
  static List<SeatStatusInfo> findOccupiedSeats(
    SeatAvailabilitySummary summary,
  ) {
    return summary.seatDetails
        .where((s) => s.status == SeatDisplayStatus.occupied)
        .toList();
  }

  /// Find seats with orders
  static List<SeatStatusInfo> findSeatsWithOrders(
    SeatAvailabilitySummary summary,
  ) {
    return summary.seatDetails
        .where((s) => s.status == SeatDisplayStatus.ordered)
        .toList();
  }

  /// Get next available seat
  static SeatStatusInfo? getNextAvailableSeat(SeatAvailabilitySummary summary) {
    final available = findAvailableSeats(summary);
    return available.isNotEmpty ? available.first : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Validate seat can be cleared
  static bool canClearSeat(SeatStatusInfo seat) {
    return seat.status == SeatDisplayStatus.occupied ||
        seat.status == SeatDisplayStatus.ordered;
  }

  /// Validate seat can accept guest
  static bool canSeatGuest(SeatStatusInfo seat) {
    return seat.status == SeatDisplayStatus.available;
  }

  /// Validate order can be created for seat
  static bool canOrderForSeat(SeatStatusInfo seat) {
    return seat.status == SeatDisplayStatus.occupied;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Format seat info for display
  static String formatSeatInfo(SeatStatusInfo seat) {
    final customer = seat.customerName ?? 'No guest';
    final duration = seat.durationDisplay;
    return '${seat.seatLabel}: $customer ($duration)';
  }

  /// Generate seat summary text
  static String generateSeatSummary(SeatAvailabilitySummary summary) {
    return '${summary.occupiedSeats}/${summary.totalSeats} seats occupied '
        '(${summary.occupancyPercentage.toStringAsFixed(0)}%)';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPARISON HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Compare two seat summaries for changes
  static Map<String, dynamic> compareSummaries(
    SeatAvailabilitySummary? old,
    SeatAvailabilitySummary? current,
  ) {
    if (old == null || current == null) {
      return {'changed': true};
    }

    return {
      'changed':
          old.occupiedSeats != current.occupiedSeats ||
          old.availableSeats != current.availableSeats,
      'occupancy_changed': old.occupiedSeats != current.occupiedSeats,
      'previous_occupied': old.occupiedSeats,
      'current_occupied': current.occupiedSeats,
      'seats_freed': old.occupiedSeats - current.occupiedSeats,
      'seats_taken': current.occupiedSeats - old.occupiedSeats,
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT EXTENSIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Extension for SeatDisplayStatus
extension SeatDisplayStatusX on SeatDisplayStatus {
  /// Get user-friendly display name
  String get displayName {
    switch (this) {
      case SeatDisplayStatus.available:
        return 'Available';
      case SeatDisplayStatus.occupied:
        return 'Occupied';
      case SeatDisplayStatus.ordered:
        return 'Ordered';
      case SeatDisplayStatus.completed:
        return 'Completed';
    }
  }

  /// Get badge color
  Color get badgeColor {
    return SeatUtils.getStatusColor(this);
  }

  /// Get status emoji
  String get emoji {
    return SeatUtils.getStatusEmoji(this);
  }

  /// Check if can place order
  bool get canOrder {
    return this == SeatDisplayStatus.occupied;
  }

  /// Check if can clear
  bool get canClear {
    return this == SeatDisplayStatus.occupied ||
        this == SeatDisplayStatus.ordered;
  }
}

/// Extension for SeatAvailabilitySummary
extension SeatAvailabilitySummaryX on SeatAvailabilitySummary {
  /// Get occupancy status description
  String get occupancyStatus {
    return SeatUtils.getOccupancyLevel(occupancyPercentage);
  }

  /// Get occupancy color
  Color get occupancyColor {
    return SeatUtils.getOccupancyColor(occupancyPercentage);
  }

  /// Check if any seats available
  bool get hasSeatAvailable {
    return availableSeats > 0;
  }

  /// Check if all seats occupied
  bool get isAllOccupied {
    return occupiedSeats >= totalSeats;
  }

  /// Check if any seats occupied
  bool get hasOccupiedSeats {
    return occupiedSeats > 0;
  }

  /// Get available seat list
  List<SeatStatusInfo> get available {
    return SeatUtils.findAvailableSeats(this);
  }

  /// Get occupied seat list
  List<SeatStatusInfo> get occupied {
    return SeatUtils.findOccupiedSeats(this);
  }

  /// Get seat summary text
  String get summary {
    return SeatUtils.generateSeatSummary(this);
  }
}

/// Extension for SeatStatusInfo
extension SeatStatusInfoX on SeatStatusInfo {
  /// Get formatted duration display
  String get durationText {
    return durationDisplay;
  }

  /// Check if can be cleared
  bool get isClearable {
    return SeatUtils.canClearSeat(this);
  }

  /// Check if can accept guest
  bool get isAvailableForSeat {
    return SeatUtils.canSeatGuest(this);
  }

  /// Check if can have order created
  bool get isOrderable {
    return SeatUtils.canOrderForSeat(this);
  }

  /// Get full display text
  String get fullDisplay {
    return SeatUtils.formatSeatInfo(this);
  }
}
