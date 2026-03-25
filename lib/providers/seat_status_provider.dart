// lib/providers/seat_status_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT STATUS PROVIDER
//  Real-time tracking of seat availability, occupancy, and duration.
//  Provides live updates for UI displaying seat-level information.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';

/// Seat status with real-time duration tracking
class SeatStatusInfo {
  final String id;
  final String seatLabel;
  final SeatDisplayStatus status;
  final String? customerName;
  final DateTime? occupiedSince;
  final Duration elapsedDuration;
  final int? activeOrderCount;

  const SeatStatusInfo({
    required this.id,
    required this.seatLabel,
    required this.status,
    this.customerName,
    this.occupiedSince,
    this.elapsedDuration = const Duration(),
    this.activeOrderCount,
  });

  /// Format duration as readable string (e.g., "2h 35m" or "45m")
  String get durationDisplay {
    if (elapsedDuration.inSeconds == 0) return '—';

    final hours = elapsedDuration.inHours;
    final minutes = elapsedDuration.inMinutes.remainder(60);
    final seconds = elapsedDuration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  /// User-friendly seat display with customer and duration
  String get displayLabel {
    final base = seatLabel;
    if (status == SeatDisplayStatus.occupied && customerName != null) {
      return '$base • $customerName ($durationDisplay)';
    } else if (status == SeatDisplayStatus.occupied) {
      return '$base • Occupied ($durationDisplay)';
    }
    return base;
  }

  /// Get status badge color
  Color get statusColor {
    switch (status) {
      case SeatDisplayStatus.available:
        return const Color(0xFF10B981); // Green
      case SeatDisplayStatus.occupied:
        return const Color(0xFF3B82F6); // Blue
      case SeatDisplayStatus.ordered:
        return const Color(0xFFEAB308); // Amber
      case SeatDisplayStatus.completed:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  /// Get status emoji
  String get statusEmoji {
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

  SeatStatusInfo copyWith({
    String? id,
    String? seatLabel,
    SeatDisplayStatus? status,
    String? customerName,
    DateTime? occupiedSince,
    Duration? elapsedDuration,
    int? activeOrderCount,
  }) {
    return SeatStatusInfo(
      id: id ?? this.id,
      seatLabel: seatLabel ?? this.seatLabel,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      occupiedSince: occupiedSince ?? this.occupiedSince,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      activeOrderCount: activeOrderCount ?? this.activeOrderCount,
    );
  }
}

/// Extended seat status enum with more granularity
enum SeatDisplayStatus { available, occupied, ordered, completed }

extension SeatDisplayStatusExt on SeatDisplayStatus {
  String get label {
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
}

/// Real-time seat availability summary
class SeatAvailabilitySummary {
  final int totalSeats;
  final int occupiedSeats;
  final int availableSeats;
  final int seatsWithOrders;
  final List<SeatStatusInfo> seatDetails;

  const SeatAvailabilitySummary({
    required this.totalSeats,
    required this.occupiedSeats,
    required this.availableSeats,
    required this.seatsWithOrders,
    required this.seatDetails,
  });

  /// Check if table can accept more guests
  bool get canAcceptGuests => availableSeats > 0;

  /// Check if all seats are occupied
  bool get isFullyOccupied => occupiedSeats >= totalSeats;

  /// Check if partially occupied
  bool get isPartiallyOccupied =>
      occupiedSeats > 0 && occupiedSeats < totalSeats;

  /// Get occupancy percentage
  double get occupancyPercentage =>
      totalSeats > 0 ? (occupiedSeats / totalSeats) * 100 : 0;

  /// Get list of available seats
  List<SeatStatusInfo> get availableSeatList => seatDetails
      .where((s) => s.status == SeatDisplayStatus.available)
      .toList();

  /// Get list of occupied seats
  List<SeatStatusInfo> get occupiedSeatList =>
      seatDetails.where((s) => s.status == SeatDisplayStatus.occupied).toList();

  SeatAvailabilitySummary copyWith({
    int? totalSeats,
    int? occupiedSeats,
    int? availableSeats,
    int? seatsWithOrders,
    List<SeatStatusInfo>? seatDetails,
  }) {
    return SeatAvailabilitySummary(
      totalSeats: totalSeats ?? this.totalSeats,
      occupiedSeats: occupiedSeats ?? this.occupiedSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      seatsWithOrders: seatsWithOrders ?? this.seatsWithOrders,
      seatDetails: seatDetails ?? this.seatDetails,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEAT STATUS PROVIDER
// ══════════════════════════════════════════════════════════════════════════════

class SeatStatusProvider extends ChangeNotifier {
  final Map<String, SeatAvailabilitySummary> _tableSeatMap = {};
  final Map<String, Timer> _durationTimers = {};

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Get availability summary for a specific table
  SeatAvailabilitySummary? getTableSeats(String tableId) =>
      _tableSeatMap[tableId];

  /// Get all tracked tables
  Map<String, SeatAvailabilitySummary> get allTableSeats => _tableSeatMap;

  // ── Seat Updates ───────────────────────────────────────────────────────────

  /// Update seat status from RestaurantTable model
  void updateTableSeats(RestaurantTable table) {
    try {
      if (table.seats.isEmpty) {
        log('[SeatStatusProvider] No seats for table ${table.id}');
        _tableSeatMap[table.id] = SeatAvailabilitySummary(
          totalSeats: table.capacity,
          occupiedSeats: 0,
          availableSeats: table.capacity,
          seatsWithOrders: 0,
          seatDetails: [],
        );
        notifyListeners();
        return;
      }

      // Convert TableSeat to SeatStatusInfo
      final seatDetails = table.seats.map((seat) {
        final status = _mapTableStatusToDisplayStatus(seat.status);
        final elapsedDuration = seat.occupiedSince != null
            ? DateTime.now().toUtc().difference(seat.occupiedSince!.toUtc())
            : Duration.zero;

        return SeatStatusInfo(
          id: seat.id,
          seatLabel: seat.seatLabel,
          status: status,
          customerName: seat.customerName,
          occupiedSince: seat.occupiedSince,
          elapsedDuration: elapsedDuration,
        );
      }).toList();

      final occupied = seatDetails
          .where((s) => s.status == SeatDisplayStatus.occupied)
          .length;
      final available = seatDetails
          .where((s) => s.status == SeatDisplayStatus.available)
          .length;
      final withOrders = seatDetails
          .where((s) => s.status == SeatDisplayStatus.ordered)
          .length;

      _tableSeatMap[table.id] = SeatAvailabilitySummary(
        totalSeats: table.capacity,
        occupiedSeats: occupied,
        availableSeats: available,
        seatsWithOrders: withOrders,
        seatDetails: seatDetails,
      );

      // Start duration timer for occupied seats
      _startDurationTimer(table.id);
      notifyListeners();
    } catch (e) {
      log('[SeatStatusProvider] Error updating table seats: $e', level: 1000);
    }
  }

  /// Mark a specific seat as occupied
  void markSeatOccupied(String tableId, String seatId, String? customerName) {
    final summary = _tableSeatMap[tableId];
    if (summary == null) return;

    final updatedDetails = summary.seatDetails.map((seat) {
      if (seat.id == seatId) {
        return seat.copyWith(
          status: SeatDisplayStatus.occupied,
          customerName: customerName,
          occupiedSince: DateTime.now(),
          elapsedDuration: Duration.zero,
        );
      }
      return seat;
    }).toList();

    _updateSeatSummary(tableId, updatedDetails);
    _startDurationTimer(tableId);
  }

  /// Mark a specific seat as having active orders
  void markSeatOrdered(String tableId, String seatId) {
    final summary = _tableSeatMap[tableId];
    if (summary == null) return;

    final updatedDetails = summary.seatDetails.map((seat) {
      if (seat.id == seatId && seat.status == SeatDisplayStatus.occupied) {
        return seat.copyWith(status: SeatDisplayStatus.ordered);
      }
      return seat;
    }).toList();

    _updateSeatSummary(tableId, updatedDetails);
  }

  /// Clear a specific seat (mark as available)
  void clearSeat(String tableId, String seatId) {
    final summary = _tableSeatMap[tableId];
    if (summary == null) return;

    final updatedDetails = summary.seatDetails.map((seat) {
      if (seat.id == seatId) {
        return SeatStatusInfo(
          id: seat.id,
          seatLabel: seat.seatLabel,
          status: SeatDisplayStatus.available,
          customerName: null,
          occupiedSince: null,
          elapsedDuration: Duration.zero,
        );
      }
      return seat;
    }).toList();

    _updateSeatSummary(tableId, updatedDetails);
  }

  /// Clear all seats in a table
  void clearAllSeats(String tableId) {
    final summary = _tableSeatMap[tableId];
    if (summary == null) return;

    final updatedDetails = summary.seatDetails.map((seat) {
      return SeatStatusInfo(
        id: seat.id,
        seatLabel: seat.seatLabel,
        status: SeatDisplayStatus.available,
        customerName: null,
        occupiedSince: null,
        elapsedDuration: Duration.zero,
      );
    }).toList();

    _updateSeatSummary(tableId, updatedDetails);
    _stopDurationTimer(tableId);
  }

  /// Remove table from tracking
  void removeTable(String tableId) {
    _tableSeatMap.remove(tableId);
    _stopDurationTimer(tableId);
    notifyListeners();
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Map TableStatus to SeatDisplayStatus
  SeatDisplayStatus _mapTableStatusToDisplayStatus(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return SeatDisplayStatus.available;
      case TableStatus.occupied:
        return SeatDisplayStatus.occupied;
      case TableStatus.reserved:
        return SeatDisplayStatus.occupied; // Treat reserved as occupied
      case TableStatus.cleaning:
        return SeatDisplayStatus.completed; // Treat cleaning as completed
    }
  }

  /// Update seat summary and recalculate counts
  void _updateSeatSummary(String tableId, List<SeatStatusInfo> updatedDetails) {
    final current = _tableSeatMap[tableId];
    if (current == null) return;

    final occupied = updatedDetails
        .where((s) => s.status == SeatDisplayStatus.occupied)
        .length;
    final available = updatedDetails
        .where((s) => s.status == SeatDisplayStatus.available)
        .length;
    final withOrders = updatedDetails
        .where((s) => s.status == SeatDisplayStatus.ordered)
        .length;

    _tableSeatMap[tableId] = current.copyWith(
      occupiedSeats: occupied,
      availableSeats: available,
      seatsWithOrders: withOrders,
      seatDetails: updatedDetails,
    );

    notifyListeners();
  }

  /// Start timer to update seat durations every second
  void _startDurationTimer(String tableId) {
    // Cancel existing timer if any
    _durationTimers[tableId]?.cancel();

    _durationTimers[tableId] = Timer.periodic(const Duration(seconds: 1), (_) {
      final summary = _tableSeatMap[tableId];
      if (summary == null) return;

      final hasOccupiedSeats = summary.seatDetails.any(
        (s) => s.status == SeatDisplayStatus.occupied,
      );

      if (!hasOccupiedSeats) {
        _stopDurationTimer(tableId);
        return;
      }

      // Update durations for all occupied seats
      final updatedDetails = summary.seatDetails.map((seat) {
        if (seat.status == SeatDisplayStatus.occupied &&
            seat.occupiedSince != null) {
          final newDuration = DateTime.now().toUtc().difference(
            seat.occupiedSince!.toUtc(),
          );
          return seat.copyWith(elapsedDuration: newDuration);
        }
        return seat;
      }).toList();

      _tableSeatMap[tableId] = summary.copyWith(seatDetails: updatedDetails);
      notifyListeners();
    });
  }

  /// Stop duration timer for a table
  void _stopDurationTimer(String tableId) {
    _durationTimers[tableId]?.cancel();
    _durationTimers.remove(tableId);
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Clear all data and timers
  void clearAll() {
    for (final timer in _durationTimers.values) {
      timer.cancel();
    }
    _durationTimers.clear();
    _tableSeatMap.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearAll();
    super.dispose();
  }
}
