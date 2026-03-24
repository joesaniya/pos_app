// lib/repositories/seat_history_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT HISTORY REPOSITORY
//  Handles queries and operations for seat session history including
//  adding new sessions, updating checkout times, and retrieving analytics.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:developer';

import 'package:pos_app/database/local_database.dart';
import 'package:pos_app/models/seat_history_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeatHistoryRepository {
  SeatHistoryRepository._();
  static final instance = SeatHistoryRepository._();

  final _db = LocalDatabase.instance;
  final _sb = Supabase.instance.client;

  // ── Create new session ────────────────────────────────────────────────────

  /// Add a new seat session (when guest is seated)
  Future<SeatSessionHistory> createSession({
    required String businessId,
    required String tableId,
    required int tableNumber,
    required String section,
    required String seatLabel,
    required String sessionId,
    required String? customerName,
    int guestCount = 1,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      // Create session in local database first
      final sessionData = {
        'id': _generateId(),
        'business_id': businessId,
        'table_id': tableId,
        'table_number': tableNumber,
        'section': section,
        'seat_label': seatLabel,
        'session_id': sessionId,
        'customer_name': customerName,
        'guest_count': guestCount,
        'check_in_time': now.toIso8601String(),
        'check_out_time': null,
        'duration_seconds': null,
        'status': 'active',
        'notes': notes,
        'created_at': now.toIso8601String(),
        'updated_at': null,
      };

      await _db.insertSeatHistory(sessionData);
      log('[SeatHistory] Created new session: $sessionId');

      // If online, also sync to Supabase
      if (await _isOnline()) {
        _syncToSupabase(sessionData, 'insert');
      } else {
        await _db.addToPendingQueue(
          entityType: 'seat_history',
          action: 'insert',
          payload: sessionData,
        );
      }

      return SeatSessionHistory.fromJson(sessionData);
    } catch (e) {
      log('[SeatHistory] Error creating session: $e');
      rethrow;
    }
  }

  // ── Update session (checkout) ─────────────────────────────────────────────

  /// Update session with checkout time (when guest leaves)
  Future<SeatSessionHistory> checkoutSession({
    required String sessionId,
    DateTime? checkOutTime,
    String status = 'checked-out',
  }) async {
    try {
      final now = checkOutTime ?? DateTime.now().toUtc();

      // Find the session
      final existing = await _db.getSeatHistoryBySessionId(sessionId);
      if (existing == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Calculate duration
      final checkIn = DateTime.parse(existing['check_in_time'] as String);
      final duration = now.difference(checkIn);

      // Update in local database
      final updatedData = {
        ...existing,
        'check_out_time': now.toIso8601String(),
        'duration_seconds': duration.inSeconds,
        'status': status,
        'updated_at': now.toIso8601String(),
      };

      await _db.updateSeatHistory(sessionId, updatedData);
      log(
        '[SeatHistory] Checked out session: $sessionId (${duration.inMinutes}m)',
      );

      // If online, sync to Supabase
      if (await _isOnline()) {
        _syncToSupabase(updatedData, 'update');
      } else {
        await _db.addToPendingQueue(
          entityType: 'seat_history',
          action: 'update',
          payload: updatedData,
        );
      }

      return SeatSessionHistory.fromJson(updatedData);
    } catch (e) {
      log('[SeatHistory] Error checking out session: $e');
      rethrow;
    }
  }

  // ── Query methods ─────────────────────────────────────────────────────────

  /// Get history for a specific seat
  Future<List<SeatSessionHistory>> getSeatHistory({
    required String tableId,
    required String seatLabel,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final records = await _db.getSeatHistoryByTableAndSeat(
        tableId: tableId,
        seatLabel: seatLabel,
        limit: limit,
        offset: offset,
      );

      return records.map((r) => SeatSessionHistory.fromJson(r)).toList();
    } catch (e) {
      log('[SeatHistory] Error fetching seat history: $e');
      return [];
    }
  }

  /// Get history for a specific table across all seats
  Future<List<SeatSessionHistory>> getTableHistory({
    required String tableId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final records = await _db.getSeatHistoryByTable(
        tableId: tableId,
        limit: limit,
        offset: offset,
      );

      return records.map((r) => SeatSessionHistory.fromJson(r)).toList();
    } catch (e) {
      log('[SeatHistory] Error fetching table history: $e');
      return [];
    }
  }

  /// Get history for a specific guest (by customer name)
  Future<List<SeatSessionHistory>> getGuestHistory({
    required String businessId,
    required String customerName,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final records = await _db.getSeatHistoryByCustomer(
        businessId: businessId,
        customerName: customerName,
        limit: limit,
        offset: offset,
      );

      return records.map((r) => SeatSessionHistory.fromJson(r)).toList();
    } catch (e) {
      log('[SeatHistory] Error fetching guest history: $e');
      return [];
    }
  }

  /// Get today's sessions (walk-in analytics)
  Future<List<SeatSessionHistory>> getTodaysSessions({
    required String businessId,
  }) async {
    try {
      final records = await _db.getSeatHistoryByDate(
        businessId: businessId,
        date: DateTime.now(),
      );

      return records.map((r) => SeatSessionHistory.fromJson(r)).toList();
    } catch (e) {
      log('[SeatHistory] Error fetching today sessions: $e');
      return [];
    }
  }

  /// Get session by session ID
  Future<SeatSessionHistory?> getSessionById(String sessionId) async {
    try {
      final record = await _db.getSeatHistoryBySessionId(sessionId);
      if (record == null) return null;
      return SeatSessionHistory.fromJson(record);
    } catch (e) {
      log('[SeatHistory] Error fetching session: $e');
      return null;
    }
  }

  // ── Analytics methods ────────────────────────────────────────────────────

  /// Get seat summary analytics
  Future<SeatHistorySummary> getSeatSummary({
    required String tableId,
    required String seatLabel,
  }) async {
    try {
      final history = await getSeatHistory(
        tableId: tableId,
        seatLabel: seatLabel,
        limit: 1000,
      );

      return SeatHistorySummary(seatLabel: seatLabel, sessions: history);
    } catch (e) {
      log('[SeatHistory] Error computing seat summary: $e');
      return SeatHistorySummary(seatLabel: seatLabel, sessions: []);
    }
  }

  /// Get daily analytics for a business
  Future<Map<String, dynamic>> getDailyAnalytics({
    required String businessId,
    DateTime? date,
  }) async {
    try {
      date ??= DateTime.now();

      final sessions = await _db.getSeatHistoryByDate(
        businessId: businessId,
        date: date,
      );

      final totalSessions = sessions.length;
      final totalGuests = sessions.fold<int>(
        0,
        (sum, s) => sum + (s['guest_count'] as int? ?? 1),
      );

      Duration totalDuration = Duration.zero;
      for (final session in sessions) {
        if (session['duration_seconds'] != null) {
          totalDuration += Duration(
            seconds: session['duration_seconds'] as int,
          );
        }
      }

      final avgDuration = totalSessions > 0
          ? Duration(seconds: (totalDuration.inSeconds / totalSessions).round())
          : Duration.zero;

      return {
        'date': date,
        'total_sessions': totalSessions,
        'total_guests': totalGuests,
        'total_duration': totalDuration,
        'average_duration': avgDuration,
        'checkout_rate': totalSessions > 0
            ? (sessions.where((s) => s['check_out_time'] != null).length /
                  totalSessions *
                  100)
            : 0.0,
      };
    } catch (e) {
      log('[SeatHistory] Error computing daily analytics: $e');
      return {
        'date': date,
        'total_sessions': 0,
        'total_guests': 0,
        'total_duration': Duration.zero,
        'average_duration': Duration.zero,
        'checkout_rate': 0.0,
      };
    }
  }

  // ── Sync methods ─────────────────────────────────────────────────────────

  /// Sync session history to Supabase
  Future<void> _syncToSupabase(Map<String, dynamic> data, String action) async {
    try {
      if (action == 'insert') {
        await _sb.from('seat_history').insert(data);
      } else if (action == 'update') {
        await _sb
            .from('seat_history')
            .update(data)
            .eq('session_id', data['session_id']);
      }
      log('[SeatHistory] Synced to Supabase: ${data['session_id']}');
    } catch (e) {
      log('[SeatHistory] Sync error: $e');
      // Don't rethrow - offline queue will handle this
    }
  }

  /// Clear old sessions (older than specified days)
  Future<void> clearOldSessions({
    required String businessId,
    int daysToKeep = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .toUtc()
          .toIso8601String();

      await _db.clearOldSeatHistory(
        businessId: businessId,
        beforeDate: cutoffDate,
      );

      log('[SeatHistory] Cleared sessions older than $daysToKeep days');
    } catch (e) {
      log('[SeatHistory] Error clearing old sessions: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<bool> _isOnline() async {
    try {
      return _sb.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  String _generateId() {
    return 'sh_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}
