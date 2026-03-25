// lib/providers/clearing_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
//  CLEARING PROVIDER
//  State management for seat-level and table-level clearing operations.
//  Provides real-time UI updates and error handling.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:pos_app/repositories/clearing_repository.dart';

enum ClearingAction { seatCleared, tableCleared, loading, error, idle }

class ClearingState {
  final ClearingAction action;
  final String? tableId;
  final String? seatId;
  final int? clearedOrdersCount;
  final int? remainingSeats;
  final String? errorMessage;
  final bool isLoading;
  final DateTime? timestamp;

  const ClearingState({
    this.action = ClearingAction.idle,
    this.tableId,
    this.seatId,
    this.clearedOrdersCount,
    this.remainingSeats,
    this.errorMessage,
    this.isLoading = false,
    this.timestamp,
  });

  ClearingState copyWith({
    ClearingAction? action,
    String? tableId,
    String? seatId,
    int? clearedOrdersCount,
    int? remainingSeats,
    String? errorMessage,
    bool? isLoading,
    DateTime? timestamp,
  }) {
    return ClearingState(
      action: action ?? this.action,
      tableId: tableId ?? this.tableId,
      seatId: seatId ?? this.seatId,
      clearedOrdersCount: clearedOrdersCount ?? this.clearedOrdersCount,
      remainingSeats: remainingSeats ?? this.remainingSeats,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
class ClearingProvider extends ChangeNotifier {
  final _clearingRepo = ClearingRepository.instance;

  // State
  ClearingState _state = const ClearingState();
  StreamSubscription? _clearingStreamSubscription;

  // UI State for seat details dialog
  Map<String, dynamic>? _selectedSeatDetails;
  List<Map<String, dynamic>> _tableSeatSummaries = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  ClearingState get state => _state;
  bool get isLoading => _state.isLoading;
  String? get error => _state.errorMessage;
  ClearingAction get lastAction => _state.action;
  Map<String, dynamic>? get selectedSeatDetails => _selectedSeatDetails;
  List<Map<String, dynamic>> get tableSeatSummaries => _tableSeatSummaries;

  // ── Constructor ────────────────────────────────────────────────────────────

  ClearingProvider() {
    _initializeRealTimeStream();
  }

  void _initializeRealTimeStream() {
    _clearingStreamSubscription = _clearingRepo.clearingStream.listen((
      updateData,
    ) {
      final action = updateData['action'] as String?;

      if (action == 'seat_cleared') {
        _state = _state.copyWith(
          action: ClearingAction.seatCleared,
          tableId: updateData['table_id'] as String?,
          seatId: updateData['seat_id'] as String?,
          remainingSeats: updateData['remaining_occupied_seats'] as int?,
          timestamp: updateData['timestamp'] as DateTime?,
        );
      } else if (action == 'table_cleared') {
        _state = _state.copyWith(
          action: ClearingAction.tableCleared,
          tableId: updateData['table_id'] as String?,
          clearedOrdersCount: updateData['orders_completed'] as int?,
          remainingSeats: 0,
          timestamp: updateData['timestamp'] as DateTime?,
        );
      }

      notifyListeners();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEAT-LEVEL CLEARING
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear a single seat with confirmation
  Future<bool> clearSeat({
    required String tableId,
    required String seatId,
    required String businessId,
    bool requireConfirmation = true,
  }) async {
    try {
      // Step 1: Show loading state
      _state = _state.copyWith(
        action: ClearingAction.loading,
        isLoading: true,
        tableId: tableId,
        seatId: seatId,
      );
      notifyListeners();

      // Step 2: Get seat details for confirmation if needed
      if (requireConfirmation) {
        await fetchSeatDetails(seatId);
        if (_selectedSeatDetails == null) {
          throw Exception('Could not fetch seat details');
        }
      }

      // Step 3: Perform the clearing
      log('[ClearingProvider] Clearing seat: $seatId from table: $tableId');

      final result = await _clearingRepo.clearSeat(
        tableId: tableId,
        seatId: seatId,
        businessId: businessId,
      );

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to clear seat');
      }

      // Step 4: Clear seat details
      _selectedSeatDetails = null;

      // Stream will handle state update to seatCleared
      _state = _state.copyWith(
        isLoading: false,
        action: ClearingAction.seatCleared,
        clearedOrdersCount: result['cleared_orders'] as int?,
        remainingSeats: result['remaining_occupied_seats'] as int?,
      );
      notifyListeners();

      log('[ClearingProvider] ✅ Seat cleared successfully');
      return true;
    } catch (e) {
      log('[ClearingProvider] ❌ Error clearing seat: $e', level: 1000);
      _state = _state.copyWith(
        action: ClearingAction.error,
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TABLE-LEVEL CLEARING
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear entire table with all seats
  Future<bool> clearEntireTable({
    required String tableId,
    required String businessId,
    bool requireConfirmation = true,
  }) async {
    try {
      // Step 1: Show loading state
      _state = _state.copyWith(
        action: ClearingAction.loading,
        isLoading: true,
        tableId: tableId,
      );
      notifyListeners();

      // Step 2: Get table summary for confirmation if needed
      if (requireConfirmation) {
        await fetchTableSeatSummaries(tableId);
      }

      // Step 3: Perform the clearing
      log('[ClearingProvider] Clearing entire table: $tableId');

      final result = await _clearingRepo.clearEntireTable(
        tableId: tableId,
        businessId: businessId,
      );

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to clear table');
      }

      // Step 4: Clear summaries
      _tableSeatSummaries = [];

      _state = _state.copyWith(
        isLoading: false,
        action: ClearingAction.tableCleared,
        clearedOrdersCount: result['orders_completed'] as int?,
        remainingSeats: 0,
      );
      notifyListeners();

      log('[ClearingProvider] ✅ Table cleared successfully');
      return true;
    } catch (e) {
      log('[ClearingProvider] ❌ Error clearing table: $e', level: 1000);
      _state = _state.copyWith(
        action: ClearingAction.error,
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DATA FETCHING
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch detailed info about a specific seat
  /// Used in confirmation dialogs before clearing
  Future<void> fetchSeatDetails(String seatId) async {
    try {
      final result = await _clearingRepo.getSeatDetails(seatId: seatId);

      if (result['success'] == true) {
        _selectedSeatDetails = result['details'] as Map<String, dynamic>?;
      } else {
        log(
          '[ClearingProvider] Error fetching seat details: ${result['error']}',
        );
        _selectedSeatDetails = null;
      }
      notifyListeners();
    } catch (e) {
      log('[ClearingProvider] Error in fetchSeatDetails: $e');
      _selectedSeatDetails = null;
    }
  }

  /// Fetch summary of all seats in a table
  /// Used for table overview and clearing options UI
  Future<void> fetchTableSeatSummaries(String tableId) async {
    try {
      _tableSeatSummaries = await _clearingRepo.getTableSeatSummaries(
        tableId: tableId,
      );
      notifyListeners();
    } catch (e) {
      log('[ClearingProvider] Error fetching seat summaries: $e');
      _tableSeatSummaries = [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get total bill from selected seat details
  double getSelectedSeatTotal() {
    final details = _selectedSeatDetails;
    if (details == null) return 0;

    final seat = details['seat'] as Map<String, dynamic>?;
    return (seat?['total_bill'] as num?)?.toDouble() ?? 0;
  }

  /// Get orders count from selected seat
  int getSelectedSeatOrderCount() {
    final details = _selectedSeatDetails;
    if (details == null) return 0;

    final orders = details['orders'] as List?;
    return orders?.length ?? 0;
  }

  /// Get customer name from selected seat
  String getSelectedSeatCustomerName() {
    final details = _selectedSeatDetails;
    if (details == null) return 'Unknown';

    final seat = details['seat'] as Map<String, dynamic>?;
    return seat?['customer_name'] as String? ?? 'Guest';
  }

  /// Get total bill for entire table from summaries
  double getTableTotalBill() {
    double total = 0;
    for (final seat in _tableSeatSummaries) {
      final bill = (seat['total_bill'] as num?)?.toDouble() ?? 0;
      total += bill;
    }
    return total;
  }

  /// Get count of occupied seats
  int getOccupiedSeatsCount() {
    return _tableSeatSummaries.where((s) => s['status'] == 'occupied').length;
  }

  /// Get count of active orders across all seats in table
  int getTableTotalOrderCount() {
    int total = 0;
    for (final seat in _tableSeatSummaries) {
      final count = (seat['order_count'] as num?)?.toInt() ?? 0;
      total += count;
    }
    return total;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Reset to idle state (call after completing UI action)
  void resetState() {
    _state = const ClearingState();
    _selectedSeatDetails = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  @override
  void dispose() {
    _clearingStreamSubscription?.cancel();
    _clearingRepo.dispose();
    super.dispose();
  }
}
